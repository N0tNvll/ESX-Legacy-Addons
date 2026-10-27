-- SPDX-License-Identifier: GPL-3.0-only
local count = 0
local function test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ': ' .. tostring(failure))
    count = count + 1
    print('PASS ' .. name)
end
local function noop() end
local function loadSource(name, e)
    assert(load(SOURCES[name], '@' .. name, 't', e))()
end
local function private(fn, key, value)
    for i = 1, 100 do
        local name = debug.getupvalue(fn, i)
        if not name then break end
        if name == key then debug.setupvalue(fn, i, value); return end
    end
    error('Missing upvalue: ' .. key)
end
local vector = {}
local function vec(x, y, z) return setmetatable({ x = x, y = y, z = z }, vector) end
vector.__sub = function(a, b) return vec(a.x-b.x, a.y-b.y, a.z-b.z) end
vector.__len = function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
local function fixture()
    local e = setmetatable({}, { __index = _G })
    e.events, e.threads, e.commands, e.nui = {}, {}, {}, {}
    e.time, e.shown, e.hidden, e.messages = 1000, {}, 0, {}
    e.resource, e.position = 'test', vec(100, 0, 0)
    e.Config = { EnableControls = false, Marker = {}, Zones = {}, CircleZones = {} }
    e.ESX = {
        PlayerLoaded = true, PlayerData = { dead = false, job = { name = 'taxi' } },
        TextUI = function(message) e.shown[#e.shown+1] = message end,
        HideUI = function() e.hidden = e.hidden+1 end,
        CloseContext = noop, ShowNotification = noop,
    }
    e.AddEventHandler = function(name, callback)
        e.events[name] = e.events[name] or {}
        table.insert(e.events[name], callback)
    end
    e.RegisterNetEvent = function(name, callback) if callback then e.AddEventHandler(name, callback) end end
    e.ESX.SecureNetEvent = e.RegisterNetEvent
    e.fire = function(name, ...) for _, callback in ipairs(e.events[name] or {}) do callback(...) end end
    e.CreateThread = function(callback) e.threads[#e.threads+1] = callback end
    e.Wait = coroutine.yield
    e.RegisterCommand = function(name, callback) e.commands[name] = callback end
    e.RegisterKeyMapping = noop
    e.RegisterNUICallback = function(name, callback) e.nui[name] = callback end
    e.GetCurrentResourceName = function() return e.resource end
    e.GetGameTimer = function() return e.time end
    e.PlayerPedId = function() return 1 end
    e.GetEntityCoords = function() return e.position end
    e.vector3, e.vec3 = vec, vec
    e.IsControlJustReleased, e.IsControlJustPressed = function() return false end, function() return false end
    e.TranslateCap = function(key) return key end
    e.TriggerEvent = function(name, ...) e.fire(name, ...) end
    e.xLib = { game = { deleteObject = noop }, nui = { register = function(name, callback) e.nui[name] = callback end } }
    return e
end
local function step(thread)
    local ok, delay = coroutine.resume(thread)
    assert(ok, delay)
    return delay
end
local function loopAfter(e, name, marker)
    local start = assert(SOURCES[name]:find(marker, 1, true))
    local _, line = SOURCES[name]:sub(1, start):gsub('\n', '')
    for _, fn in ipairs(e.threads) do
        if debug.getinfo(fn, 'S').linedefined >= line then return fn end
    end
    error('Missing loop: ' .. name)
end

for _, name in ipairs({ 'accessories', 'taxi', 'dmv' }) do
    test(name .. ' caches prompts, updates changed messages and cleans focus hints', function()
        local e = fixture()
        e.resource = name == 'accessories' and 'esx_accessories' or name == 'taxi' and 'esx_taxijob' or 'esx_dmvschool'
        if name == 'dmv' then e.Config.Zones = { DMVSchool = { Pos = vec(0,0,0), Type = -1, Size = { x = 1 } } } end
        loadSource(name, e)
        local fn = loopAfter(e, name, name == 'dmv' and '-- Display markers' or name == 'taxi' and '-- Key Controls' or '-- Key controls')
        private(fn, 'CurrentAction', 'test')
        private(fn, 'CurrentActionMsg', 'first')
        local thread = coroutine.create(fn)
        for _ = 1, 10 do step(thread) end
        assert(#e.shown == 1 and e.shown[1] == 'first')
        private(fn, 'CurrentActionMsg', 'second')
        step(thread)
        assert(#e.shown == 2 and e.shown[2] == 'second')
        e.fire('onResourceStop', 'other')
        assert(e.hidden == 0)
        e.fire('onResourceStop', e.resource)
        assert(e.hidden == 1)
        step(thread)
        assert(#e.shown == 3)
        e.ESX.PlayerData.dead = true
        step(thread)
        assert(e.hidden == 2)
        e.ESX.PlayerData.dead = false
        step(thread)
        e.ESX.PlayerLoaded = false
        e.fire('esx:onPlayerLogout')
        assert(e.hidden == 3)
        step(thread)
        assert(#e.shown == 4)
    end)
end

test('taxi job change immediately hides the previous interaction', function()
    local e = fixture()
    loadSource('taxi', e)
    local fn = loopAfter(e, 'taxi', '-- Key Controls')
    private(fn, 'CurrentAction', 'test'); private(fn, 'CurrentActionMsg', 'taxi')
    local thread = coroutine.create(fn)
    step(thread)
    e.fire('esx:setJob', { name = 'unemployed' })
    assert(e.hidden == 1)
    step(thread)
    assert(#e.shown == 1)
end)

test('drug dealer prompt shows once and is cleared on death and logout', function()
    local e = fixture()
    loadSource('drugs', e)
    local fn = loopAfter(e, 'drugs', '--main loop')
    private(fn, 'inZoneDrugShop', true)
    local thread = coroutine.create(fn)
    for _ = 1, 10 do step(thread) end
    assert(#e.shown == 1)
    e.ESX.PlayerData.dead = true; step(thread); assert(e.hidden == 1)
    e.ESX.PlayerData.dead = false; step(thread)
    e.ESX.PlayerLoaded = false; e.fire('esx:onPlayerLogout')
    assert(e.hidden == 2)
    step(thread); assert(#e.shown == 2)
end)

test('weed processing prompt is cached and cleared when leaving, logging out or stopping', function()
    local e = fixture()
    e.resource = 'esx_drugs'
    e.Config.CircleZones.WeedProcessing = { coords = e.position }
    loadSource('weed', e)
    local thread = coroutine.create(e.threads[2])
    for _ = 1, 10 do step(thread) end
    assert(#e.shown == 1)
    e.position = vec(1000, 0, 0); step(thread); assert(e.hidden == 1)
    e.position = e.Config.CircleZones.WeedProcessing.coords; step(thread)
    e.ESX.PlayerLoaded = false; e.fire('esx:onPlayerLogout'); assert(e.hidden == 2)
    step(thread); assert(#e.shown == 2)
    e.ESX.PlayerLoaded = true; step(thread)
    e.fire('onResourceStop', e.resource); assert(e.hidden == 3)
end)

test('weed pickup prompt is hidden while picking up, dead or logged out', function()
    local e = fixture()
    e.resource = 'esx_drugs'
    e.IsPedOnFoot = function() return true end
    loadSource('weed', e)
    local fn = e.threads[3]
    private(fn, 'weedPlants', { 7 })
    local thread = coroutine.create(fn)
    for _ = 1, 10 do step(thread) end
    assert(#e.shown == 1)
    private(fn, 'isPickingUp', true); step(thread); assert(e.hidden == 1)
    private(fn, 'isPickingUp', false); step(thread)
    e.ESX.PlayerData.dead = true; step(thread); assert(e.hidden == 2)
    e.ESX.PlayerData.dead = false; step(thread)
    e.ESX.PlayerLoaded = false; e.fire('esx:onPlayerLogout'); assert(e.hidden == 3)
    step(thread); assert(#e.shown == 3)
end)

local function workshop()
    local e = fixture()
    e.time, e.tasks, e.notifications = 0, {}, {}
    e.inventory = { fixtool = 5, fixkit = 0, gazbottle = 0 }
    e.allowed, e.near, e.capacity = true, true, true
    e.identifier = 'character:one'
    e.SetTimeout = function(delay, callback) e.tasks[#e.tasks+1] = { at = e.time+delay, fn = callback } end
    e.advance = function(ms)
        e.time = e.time+ms
        local tasks = e.tasks; e.tasks = {}
        for _, task in ipairs(tasks) do
            if task.at <= e.time then task.fn() else e.tasks[#e.tasks+1] = task end
        end
    end
    e.TriggerClientEvent = function(_, _, message) e.notifications[#e.notifications+1] = message end
    e.print = function(message) e.warning = message end
    local methods = {
        getIdentifier = function() return e.identifier end,
        getInventoryItem = function(item) return { count = e.inventory[item] or 0 } end,
        canCarryItem = function() return e.capacity and e.carry ~= false end,
        canSwapItem = function() return e.capacity end,
        removeInventoryItem = function(item, amount)
            if e.failRemove or (e.inventory[item] or 0) < amount then return false end
            e.inventory[item] = e.inventory[item]-amount; return true
        end,
        addInventoryItem = function(item, amount)
            if (item == 'fixkit' and e.failOutput) or (item == 'fixtool' and e.failRefund) then return false end
            e.inventory[item] = (e.inventory[item] or 0)+amount; return true
        end,
    }
    e.ESXMechanicJob = {
        PlayerWorkStates = {},
        rejectRateLimited = function() return e.limited end,
        isPlayerNearZone = function() return e.near end,
        getWorkshopMechanicPlayer = function()
            -- ESX.Player returns a fresh proxy on each call.
            if e.allowed then return setmetatable({}, { __index = methods }) end
        end,
    }
    e.RegisterServerEvent = noop
    loadSource('workshop', e)
    e.start = function() e.source = 1; e.fire('esx_mechanicjob:startCraft2') end
    e.stop = function() e.source = 1; e.fire('esx_mechanicjob:stopCraft2') end
    return e
end

test('crafting without materials never starts a timer or assembling notification', function()
    local e = workshop(); e.inventory.fixtool = 0; e.start()
    assert(#e.tasks == 0 and #e.notifications == 1 and e.notifications[1] == 'not_enough_repair_tools')
    assert(e.ESXMechanicJob.PlayerWorkStates[1] == nil)
end)
test('duplicate crafting starts keep one active timer', function()
    local e = workshop(); e.start(); e.start()
    assert(#e.tasks == 1 and #e.notifications == 1)
end)
test('crafting uses fresh ESX proxies and consumes exactly one material per product', function()
    local e = workshop(); e.start(); e.advance(4000)
    assert(e.inventory.fixtool == 4 and e.inventory.fixkit == 1 and #e.tasks == 1)
end)
test('materials are rechecked at the end of the crafting interval', function()
    local e = workshop(); e.start(); e.inventory.fixtool = 0; e.advance(4000)
    assert(e.inventory.fixkit == 0 and #e.tasks == 0 and not e.ESXMechanicJob.PlayerWorkStates[1])
end)
test('failed inventory removal cannot grant a free product', function()
    local e = workshop(); e.failRemove = true; e.start(); e.advance(4000)
    assert(e.inventory.fixtool == 5 and e.inventory.fixkit == 0 and #e.tasks == 0)
end)
test('failed product insertion restores its material and stops crafting', function()
    local e = workshop(); e.failOutput = true; e.start(); e.advance(4000)
    assert(e.inventory.fixtool == 5 and e.inventory.fixkit == 0 and #e.tasks == 0)
end)
test('a failed material refund is logged and cannot loop', function()
    local e = workshop(); e.failOutput, e.failRefund = true, true; e.start(); e.advance(4000)
    assert(e.inventory.fixkit == 0 and e.warning and #e.tasks == 0)
end)
test('inventory capacity is checked before consuming materials', function()
    local e = workshop(); e.capacity = false; e.start(); e.advance(4000)
    assert(e.inventory.fixtool == 5 and e.inventory.fixkit == 0 and #e.tasks == 0)
end)
test('a full inventory can still swap its input for a product that fits', function()
    local e = workshop(); e.carry = false; e.start(); e.advance(4000)
    assert(e.inventory.fixtool == 4 and e.inventory.fixkit == 1)
end)
test('harvesting respects both the per-item limit and inventory capacity', function()
    for _, full in ipairs({ 'limit', 'capacity' }) do
        local e = workshop()
        if full == 'limit' then e.inventory.gazbottle = 5 else e.capacity = false end
        local before = e.inventory.gazbottle
        e.source = 1; e.fire('esx_mechanicjob:startHarvest'); e.advance(4000)
        assert(e.inventory.gazbottle == before and #e.tasks == 0)
    end
end)
test('stop and immediate restart cannot let an old timer craft early or duplicate the loop', function()
    local e = workshop(); e.start(); e.advance(1000); e.stop(); e.start()
    e.advance(3000); assert(e.inventory.fixkit == 0)
    e.advance(1000); assert(e.inventory.fixkit == 1 and #e.tasks == 1)
    e.advance(4000); assert(e.inventory.fixkit == 2 and #e.tasks == 1)
end)
for _, reason in ipairs({ 'zone', 'job', 'character', 'disconnect' }) do
    test('crafting stops after ' .. reason .. ' changes', function()
        local e = workshop(); e.start()
        if reason == 'zone' then e.near = false elseif reason == 'job' then e.allowed = false
        elseif reason == 'character' then e.identifier = 'character:two'
        else e.source = 1; e.fire('playerDropped'); e.ESXMechanicJob.PlayerWorkStates[1] = nil end
        e.advance(4000)
        assert(e.inventory.fixkit == 0 and #e.tasks == 0)
    end)
end
test('permission, distance and rate limiting are checked before crafting starts', function()
    for _, reason in ipairs({ 'job', 'zone', 'limit' }) do
        local e = workshop()
        if reason == 'job' then e.allowed = false elseif reason == 'zone' then e.near = false else e.limited = true end
        e.start(); assert(#e.tasks == 0 and #e.notifications == 0)
    end
end)

local function pause()
    local e = fixture()
    e.resource = 'esx_pausemenu'
    e.Config = { Debug = false, ScreenBlurMs = 0, Controls = { pause = 199, pauseAlt = 200 }, Brand = {}, Links = {}, News = {}, PeopleCommand = '' }
    e.Locales = { en = {} }
    e.ESX.GetConfig = function() return { Locale = 'en' } end
    e.ESX.TriggerServerCallback = function(_, callback) callback({}) end
    e.GetConvar = function(_, default) return default end
    e.GetClockHours, e.GetClockMinutes, e.GetClockDayOfMonth, e.GetClockMonth, e.GetClockYear = function() return 1 end, function() return 1 end, function() return 1 end, function() return 1 end, function() return 2026 end
    e.GetStreetNameAtCoord = function() return 0 end
    e.GetStreetNameFromHashKey, e.GetNameOfZone, e.GetLabelText = function() return '' end, function() return '' end, function() return '' end
    e.Translate = function(key) return key end
    e.xLib.colors = { getESXTheme = function() return {} end }
    e.xLib.nui = {
        register = function(name, callback) e.nui[name] = callback end,
        close = function() e.order[#e.order+1] = 'release' end,
        open = noop, send = noop, focus = noop,
        ok = function() return true end, fail = function() return false end,
    }
    e.order = {}
    e.IsPauseMenuActive = function() return e.nativeActive or false end
    e.IsPauseMenuRestarting = function() return false end
    e.SetPauseMenuActive = function(active) e.nativeActive = active end
    e.ActivateFrontendMenu = function() e.nativeActive = true end
    e.SetFrontendActive = function(active) e.nativeActive = active end
    e.PauseMenuceptionGoDeeper = noop
    e.GetHashKey = function() return 1 end
    e.DisableControlAction = noop
    e.IsDisabledControlJustReleased = function() return e.closePressed or false end
    e.TriggerScreenblurFadeIn, e.TriggerScreenblurFadeOut = noop, noop
    e.SetTimeout = noop
    loadSource('pause', e)
    local stop = assert(SOURCES.death:find('local function remaining()', 1, true))
    e.SetNuiFocus = function(focus) e.order[#e.order+1] = focus and 'death focus' or 'death release' end
    e.SetNuiFocusKeepInput, e.SendNUIMessage = noop, noop
    assert(load(SOURCES.death:sub(1, stop-1), '@death-focus', 't', e))()
    e.deathHandler = e.events['esx_pausemenu:closed'][1]
    private(e.deathHandler, 'dead', true)
    return e
end
test('resuming pause releases its focus before restoring the death cursor', function()
    local e = pause(); e.commands.esx_pausemenu(); e.nui.resume()
    assert(e.order[1] == 'release' and e.order[2] == 'death focus')
end)
for _, mode in ipairs({ 'openMap', 'openSettings' }) do
    test(mode .. ' restores death focus only after native pause closes', function()
        local e = pause(); e.commands.esx_pausemenu(); e.nui[mode]()
        local thread = coroutine.create(e.threads[#e.threads])
        assert(step(thread) == 120 and #e.order == 1)
        step(thread); assert(e.nativeActive and #e.order == 1)
        if mode == 'openMap' then e.closePressed = true else e.nativeActive = false end
        step(thread)
        assert(not e.nativeActive and e.order[2] == 'death focus')
    end)
end
for _, reason in ipairs({ 'alive', 'recovering', 'logout', 'native pause' }) do
    test('death focus is not restored while ' .. reason, function()
        local e = pause()
        if reason == 'alive' then private(e.deathHandler, 'dead', false)
        elseif reason == 'recovering' then private(e.deathHandler, 'recovering', true)
        elseif reason == 'logout' then e.ESX.PlayerLoaded = false
        else e.nativeActive = true end
        e.fire('esx_pausemenu:closed')
        assert(#e.order == 0)
    end)
end
print(('TOTAL %d upstream behavior tests passed'):format(count))
