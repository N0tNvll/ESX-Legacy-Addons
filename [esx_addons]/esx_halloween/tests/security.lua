-- Deterministic, offline contract tests. These do not simulate OneSync or GTA rendering.
local count = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ': ' .. tostring(err)) end
    count = count + 1
    print('PASS ' .. name)
end
local meta = {}
local function vec(x, y, z) return setmetatable({ x = x, y = y, z = z }, meta) end
meta.__sub = function(a, b) return vec(a.x - b.x, a.y - b.y, a.z - b.z) end
meta.__len = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
local function loadIn(e, name) assert(load(SOURCES[name], '@' .. name, 't', e))() end
local function fixture(change, client)
    local e = setmetatable({}, { __index = _G })
    e._G = e
    e.time, e.handlers, e.commands, e.tasks, e.events, e.sent = 100000.0, {}, {}, {}, {}, {}
    e.players, e.states, e.positions, e.buckets, e.inventory = {}, {}, {}, {}, {}
    e.exportsList, e.logs, e.nui, e.scans = {}, {}, {}, 0
    e.math = setmetatable({ random = function(a, b) return b and a or (e.roll or 1) end }, { __index = math })
    e.vector3, e.vec3 = vec, vec
    e.GetGameTimer = function() return e.time end
    e.GetResourceState = function() return 'started' end
    e.IsDuplicityVersion = function() return not client end
    e.GetCurrentResourceName = function() return 'esx_halloween' end
    e.GetInvokingResource = function() return e.invoking or 'esx_death' end
    e.GetPlayerRoutingBucket = function(src) return e.buckets[src] or 0 end
    e.GetPlayers = function() local ids = {}; for id in pairs(e.players) do ids[#ids + 1] = tostring(id) end; return ids end
    e.GetPlayerPed = function(src) return src end
    e.GetEntityCoords = function(ped) e.scans = e.scans + 1; return e.positions[ped] or vec(0, 0, 0) end
    e.GetEntityHealth = function() return 200 end
    e.DoesEntityExist = function(id) return id ~= 0 end
    e.GetPlayerName = function() return 'Test player' end
    e.print = function(...) e.logs[#e.logs + 1] = { ... } end
    e.AddEventHandler = function(name, fn)
        e.handlers[name] = e.handlers[name] or {}; table.insert(e.handlers[name], fn)
    end
    e.RegisterNetEvent = function(name, fn) if fn then e.AddEventHandler(name, fn) end end
    e.RegisterCommand = function(name, fn) e.commands[name] = fn end
    e.TriggerClientEvent = function(name, target, ...)
        e.events[#e.events + 1] = { name = name, target = target, args = { ... } }
    end
    e.TriggerServerEvent = function(name, ...) e.sent[#e.sent + 1] = { name = name, args = { ... } } end
    e.CreateThread = function(fn) e.tasks[#e.tasks + 1] = { co = coroutine.create(fn), wake = e.time } end
    e.Wait = function(ms) coroutine.yield(ms) end
    e.SetTimeout = function(ms, fn) e.tasks[#e.tasks + 1] = { co = coroutine.create(fn), wake = e.time + ms } end
    e.step = function(ms)
        e.time = e.time + (ms or 0)
        local index = 1
        while index <= #e.tasks do
            local task = e.tasks[index]
            if coroutine.status(task.co) == 'dead' then table.remove(e.tasks, index)
            else
                if task.wake <= e.time then
                    local ok, delay = coroutine.resume(task.co)
                    assert(ok, delay)
                    task.wake = e.time + (delay or 0)
                end
                index = index + 1
            end
        end
    end
    e.fire = function(name, src, ...)
        e.source = src
        for _, fn in ipairs(e.handlers[name] or {}) do fn(...) end
    end
    e.last = function(name, target)
        for index = #e.events, 1, -1 do
            local event = e.events[index]
            if event.name == name and (target == nil or target == event.target) then return event end
        end
    end
    local function makePlayer(id)
        local items = { medikit = { count = 0 }, diamond = { count = 0 } }
        e.inventory[id] = items
        local player
        player = {
            source = id,
            isCurrent = function() return e.players[id] == player end,
            getGroup = function() return id == 9 and 'admin' or 'user' end,
            getInventoryItem = function(item) return items[item] end,
            canCarryItem = function() return e.carry ~= false end,
            addInventoryItem = function(item, amount)
                if e.addMode == 'yield' then e.Wait(100) end
                if e.addMode == 'false' then return false end
                if e.addMode == 'throw' then error('Adapter failed') end
                items[item].count = items[item].count + amount
                if e.addMode == 'throw_after' then error('Hook failed after delivery') end
                if e.addMode ~= 'nil' then return true end
            end
        }
        return player
    end
    for _, id in ipairs({ 1, 2, 9 }) do
        e.players[id], e.states[id] = makePlayer(id), { dead = false, earlyRemaining = 0 }
    end
    e.makePlayer = makePlayer
    e.ESX = {
        GetPlayerFromId = function(id) return e.players[id] end,
        GetItems = function() return { medikit = {}, diamond = {} } end,
        GetConfig = function() return nil end,
        SetTimeout = e.SetTimeout, ClearTimeout = function() end,
        PlayerData = { dead = false }, PlayerLoaded = true,
        ShowNotification = function() end,
        Game = { GetClosestPlayer = function() return 2, 1 end }
    }
    e.exports = setmetatable({
        esx_death = { GetDeathState = function(_, id) return e.states[id] end },
        ox_inventory = { Items = function() return e.ESX.GetItems() end }
    }, { __call = function(_, name, fn) e.exportsList[name] = fn end })
    e.TriggerEvent = function(name, callback)
        if name == 'skinchanger:getSkin' then callback({ sex = 0 }) end
    end
    loadIn(e, 'shared/events.lua'); loadIn(e, 'configs/trickortreat.lua'); loadIn(e, 'config.lua')
    if change then change(e.Config) end
    loadIn(e, 'shared/config.lua')
    if client then
        local noop = function() end
        for _, name in ipairs({ 'DoScreenFadeOut', 'DoScreenFadeIn', 'SetRunSprintMultiplierForPlayer',
            'SetPlayerInvincible', 'SetEntityInvincible', 'ResetEntityAlpha', 'SetEntityVisible',
            'SetPedCanRagdoll', 'RequestModel', 'SetModelAsNoLongerNeeded', 'SetPlayerModel',
            'SetEntityHealth', 'SetPedArmour', 'SetEntityAlpha', 'SetNuiFocus', 'SendNUIMessage',
            'DisablePlayerFiring', 'DisableControlAction', 'ShakeGameplayCam', 'RequestCollisionAtCoord',
            'SetEntityAsMissionEntity', 'SetBlockingOfNonTemporaryEvents', 'FreezeEntityPosition',
            'SetBlipAsShortRange', 'SetBlipSprite', 'SetBlipColour', 'SetBlipScale',
            'BeginTextCommandSetBlipName', 'AddTextComponentString', 'EndTextCommandSetBlipName',
            'BeginTextCommandDisplayHelp', 'EndTextCommandDisplayHelp' }) do e[name] = noop end
        e.RegisterNUICallback = function(name, fn) e.nui[name] = fn end
        e.PlayerId, e.PlayerPedId = function() return 1 end, function() return 1 end
        e.GetPlayerServerId, e.GetPlayerFromServerId = function(id) return id end, function(id) return id end
        e.GetHashKey, e.GetEntityModel = function() return 123 end, function() return 456 end
        e.GetPedArmour = function() return 10 end
        e.HasModelLoaded, e.IsModelInCdimage, e.IsModelValid, e.IsModelAPed = function() return true end,
            function() return true end, function() return true end, function() return true end
        e.IsScreenFadedOut = function() return true end
        e.IsEntityDead = function() return false end
        e.IsControlJustPressed = function(_, key) assert(type(key) == 'number'); return e.exitPressed and key == 73 end
        e.IsControlJustReleased = function() return false end
        e.GetGroundZFor_3dCoord = function() return true, 137.42 end
        e.CreatePed = function(_, _, _, _, z) assert(type(z) == 'number'); e.spawnZ = z; return 1234 end
        e.AddBlipForCoord = function() return 42 end
        e.DeleteEntity = function() e.deleted = (e.deleted or 0) + 1 end
        e.RemoveBlip = function() end
        loadIn(e, 'client/respawn.lua'); loadIn(e, 'client/ghost.lua'); loadIn(e, 'client/trickortreat.lua')
    else
        loadIn(e, 'server/runtime.lua'); loadIn(e, 'server/config_validator.lua'); loadIn(e, 'server/main.lua')
        loadIn(e, 'server/ghost.lua'); loadIn(e, 'server/trickortreat.lua'); loadIn(e, 'server/commands.lua')
    end
    e.step(0)
    return e
end
local function start(e)
    e.commands.startround(0)
    return assert(e.last(e.Events.ROUND_START, 1)).args[1].roundId
end
local function begin(e, src, house, roundId)
    e.positions[src] = e.Config.TrickOrTreat.houses[house].coords
    e.fire(e.Events.HOUSE_INTERACT_REQUEST, src, house, roundId)
    return assert(e.last(e.Events.HOUSE_INTERACT_RESPONSE, src)).args[1].token
end
local function finish(e, src, house, roundId, token)
    e.step(e.Config.TrickOrTreat.interaction.duration)
    e.fire(e.Events.HOUSE_COLLECT_REQUEST, src, house, roundId, token)
end
local function ghost(e, src)
    assert(e.Halloween.OfferGhost(src, true))
    local token = e.last(e.Events.SHOW_GHOST_CHOICE, src).args[2].token
    e.fire(e.Events.REQUEST_GHOST_MODE, src, 'ghost', token)
    e.fire(e.Events.GHOST_READY, src, token, 'prepared')
    e.fire(e.Events.GHOST_READY, src, token, 'active')
    assert(e.exportsList.IsPlayerGhost(src))
    return token
end

test('requests without a server ghost offer are rejected and rate limited', function()
    local e = fixture()
    for _ = 1, 100 do e.fire(e.Events.REQUEST_GHOST_MODE, 1, 'ghost', 1) end
    assert(not e.exportsList.IsPlayerGhost(1))
    assert(#e.events == 1)
end)
test('ghost handshake works without dropping a low-latency acknowledgement', function()
    local e = fixture(); ghost(e, 1)
    assert(e.last(e.Events.SYNC_GHOST_STATE).args[2] == true)
end)
test('offers cannot be replayed by another player or after expiry', function()
    local e = fixture(); assert(e.Halloween.OfferGhost(1, true))
    local token = e.last(e.Events.SHOW_GHOST_CHOICE).args[2].token
    e.fire(e.Events.REQUEST_GHOST_MODE, 2, 'ghost', token)
    assert(not e.exportsList.IsPlayerGhost(2))
    e.step(e.Config.Ghost.security.offerTimeout + 1)
    e.fire(e.Events.REQUEST_GHOST_MODE, 1, 'ghost', token)
    assert(not e.exportsList.IsPlayerGhost(1))
end)
test('disabled ghost features and concurrent reservations are enforced', function()
    local off = fixture(function(c) c.Ghost.enabled = false end)
    assert(not off.Halloween.OfferGhost(1, true))
    local e = fixture(function(c) c.Ghost.security.maxConcurrentGhosts = 1 end)
    ghost(e, 1); assert(e.Halloween.OfferGhost(2, true))
    local token = e.last(e.Events.SHOW_GHOST_CHOICE, 2).args[2].token
    e.fire(e.Events.REQUEST_GHOST_MODE, 2, 'ghost', token)
    assert(not e.exportsList.IsPlayerGhost(2))
end)
test('ghost state expires on the server; preparation timeout frees capacity', function()
    local e = fixture(); ghost(e, 1)
    e.step(e.Config.Ghost.maxDuration + 1)
    assert(not e.exportsList.IsPlayerGhost(1))
    assert(e.Halloween.OfferGhost(2, true))
    local token = e.last(e.Events.SHOW_GHOST_CHOICE, 2).args[2].token
    e.fire(e.Events.REQUEST_GHOST_MODE, 2, 'ghost', token)
    e.step(e.Config.Ghost.security.requestTimeout + 1)
    assert(not e.exportsList.IsPlayerGhost(2))
end)
test('scares enforce buckets, feature flags, distance and cooldown', function()
    local e = fixture(); ghost(e, 1)
    e.buckets[2] = 1; e.fire(e.Events.TRIGGER_SCARE, 1, 2); assert(not e.last(e.Events.RECEIVE_SCARE))
    e.buckets[2] = 0; e.step(250); e.positions[2] = vec(100, 0, 0)
    e.fire(e.Events.TRIGGER_SCARE, 1, 2); assert(not e.last(e.Events.RECEIVE_SCARE))
    e.step(250); e.positions[2] = vec(0, 0, 0); e.Config.Ghost.abilities.scare.enabled = false
    e.fire(e.Events.TRIGGER_SCARE, 1, 2); assert(not e.last(e.Events.RECEIVE_SCARE))
    e.step(250); e.Config.Ghost.abilities.scare.enabled = true; e.fire(e.Events.TRIGGER_SCARE, 1, 2)
    local previous = e.last(e.Events.RECEIVE_SCARE); assert(previous)
    e.step(250); e.fire(e.Events.TRIGGER_SCARE, 1, 2); assert(e.last(e.Events.RECEIVE_SCARE) == previous)
end)
test('death offers originate in esx_death and wait for normal respawn eligibility', function()
    local e = fixture(function(c) c.Ghost.spawnChance = 100 end)
    e.states[1] = { dead = true, earlyRemaining = 60 }
    e.invoking = 'client'; e.fire('esx_death:stateChanged', 1, 1, true, 'death'); e.step(60000)
    assert(not e.last(e.Events.SHOW_GHOST_CHOICE))
    e.invoking = 'esx_death'; e.fire('esx_death:stateChanged', 0, 1, true, 'death')
    e.step(2000); assert(not e.last(e.Events.SHOW_GHOST_CHOICE))
    e.states[1].earlyRemaining = 0; e.step(60000)
    local token = assert(e.last(e.Events.SHOW_GHOST_CHOICE)).args[2].token
    e.fire(e.Events.REQUEST_GHOST_MODE, 1, 'ghost', token)
    assert(e.last(e.Events.GHOST_MODE_RESPONSE).args[3].phase == 'respawn')
    e.states[1].dead = false; e.fire('esx_death:stateChanged', 0, 1, false, 'respawn'); e.step(0)
    assert(not e.last('esx_death:recover'))
    e.states[1].recovery = { point = vec(1, 2, 3) }; e.step(100)
    assert(e.last('esx_death:recover'))
    assert(e.last(e.Events.GHOST_MODE_RESPONSE).args[3].phase == 'preparing')
end)
test('disconnect and a reused source invalidate old tokens', function()
    local e = fixture(); local token = ghost(e, 1)
    e.fire('playerDropped', 1); e.players[1] = e.makePlayer(1)
    e.fire(e.Events.GHOST_READY, 1, token, 'active')
    assert(not e.exportsList.IsPlayerGhost(1))
end)
test('a direct reward event cannot bypass interaction or distance', function()
    local e = fixture(); local id = start(e)
    e.fire(e.Events.HOUSE_COLLECT_REQUEST, 1, 1, id, 1)
    assert(e.inventory[1].medikit.count == 0)
    e.fire(e.Events.HOUSE_INTERACT_REQUEST, 1, 1, id)
    assert(not e.last(e.Events.HOUSE_INTERACT_RESPONSE, 1))
end)
test('interaction duration and shared single collection are enforced', function()
    local e = fixture(); local id = start(e); local token = begin(e, 1, 1, id)
    e.fire(e.Events.HOUSE_COLLECT_REQUEST, 1, 1, id, token); assert(e.inventory[1].medikit.count == 0)
    finish(e, 1, 1, id, token); assert(e.inventory[1].medikit.count == 3)
    e.step(1000); e.fire(e.Events.HOUSE_COLLECT_REQUEST, 1, 1, id, token)
    assert(e.inventory[1].medikit.count == 3)
    e.positions[2] = e.positions[1]; e.fire(e.Events.HOUSE_INTERACT_REQUEST, 2, 1, id)
    assert(not e.last(e.Events.HOUSE_INTERACT_RESPONSE, 2))
end)
test('negative rewards consume the house without calling a missing xPlayer method', function()
    local e = fixture(); e.roll = 100; local id = start(e); local token = begin(e, 1, 1, id)
    finish(e, 1, 1, id, token)
    assert(e.last(e.Events.TRIGGER_TRICK, 1))
    assert(e.last(e.Events.HOUSE_COLLECT_RESPONSE, 1).args[1].success)
    e.step(1000); e.fire(e.Events.HOUSE_INTERACT_REQUEST, 2, 1, id)
    assert(not e.last(e.Events.HOUSE_INTERACT_RESPONSE, 2))
end)
test('full inventory cannot reroll a reward', function()
    local e = fixture(); e.roll = 80; e.carry = false
    local id = start(e); local token = begin(e, 1, 1, id); finish(e, 1, 1, id, token)
    assert(not e.last(e.Events.HOUSE_COLLECT_RESPONSE, 1).args[1].success)
    e.carry, e.roll = true, 1; token = begin(e, 1, 1, id); finish(e, 1, 1, id, token)
    assert(e.inventory[1].diamond.count == 1 and e.inventory[1].medikit.count == 0)
end)
test('failed delivery is reported; old adapters returning nil are verified by count', function()
    local e = fixture(); e.addMode = 'false'; local id = start(e); local token = begin(e, 1, 1, id)
    finish(e, 1, 1, id, token); assert(not e.last(e.Events.HOUSE_COLLECT_RESPONSE, 1).args[1].success)
    e.addMode = 'nil'; token = begin(e, 1, 1, id); finish(e, 1, 1, id, token)
    assert(e.last(e.Events.HOUSE_COLLECT_RESPONSE, 1).args[1].success and e.inventory[1].medikit.count == 3)
end)
test('adapter error after payment never reopens a paid house', function()
    local e = fixture(); e.addMode = 'throw_after'; local id = start(e); local token = begin(e, 1, 1, id)
    finish(e, 1, 1, id, token); assert(e.inventory[1].medikit.count == 3)
    e.positions[2] = e.positions[1]; e.fire(e.Events.HOUSE_INTERACT_REQUEST, 2, 1, id)
    assert(not e.last(e.Events.HOUSE_INTERACT_RESPONSE, 2))
end)
test('yielding delivery holds a reservation and blocks administrative reset', function()
    local e = fixture(); e.addMode = 'yield'; local id = start(e); local token = begin(e, 1, 1, id)
    e.step(1500)
    e.CreateThread(function() e.fire(e.Events.HOUSE_COLLECT_REQUEST, 1, 1, id, token) end); e.step(0)
    e.positions[2] = e.positions[1]; e.fire(e.Events.HOUSE_INTERACT_REQUEST, 2, 1, id)
    assert(not e.last(e.Events.HOUSE_INTERACT_RESPONSE, 2))
    e.commands.resetcooldowns(0); assert(e.last(e.Events.ROUND_START, 1).args[1].roundId == id)
    e.step(100); assert(e.inventory[1].medikit.count == 3 and e.inventory[2].medikit.count == 0)
end)
test('disabled, dead, ghost and other-bucket players cannot collect', function()
    local off = fixture(function(c) c.TrickOrTreat.enabled = false end)
    off.commands.startround(0); assert(not off.last(off.Events.ROUND_START))
    local e = fixture(); local id = start(e); e.positions[1] = e.Config.TrickOrTreat.houses[1].coords
    e.states[1].dead = true; e.fire(e.Events.HOUSE_INTERACT_REQUEST, 1, 1, id)
    assert(not e.last(e.Events.HOUSE_INTERACT_RESPONSE, 1))
    e.states[1].dead = false; e.buckets[1] = 1; e.step(1000); e.fire(e.Events.HOUSE_INTERACT_REQUEST, 1, 1, id)
    assert(not e.last(e.Events.HOUSE_INTERACT_RESPONSE, 1))
    e.buckets[1] = 0; ghost(e, 1); e.step(1000); e.fire(e.Events.HOUSE_INTERACT_REQUEST, 1, 1, id)
    assert(not e.last(e.Events.HOUSE_INTERACT_RESPONSE, 1))
end)
test('spam and malformed indices do not trigger repeated coordinate work', function()
    local e = fixture(); local id = start(e); e.scans = 0
    for _ = 1, 100 do e.fire(e.Events.HOUSE_INTERACT_REQUEST, 1, 1, id) end
    assert(e.scans == 1)
    for _, index in ipairs({ 1.5, -1, math.huge, '1', {} }) do
        e.step(1000); e.fire(e.Events.HOUSE_INTERACT_REQUEST, 1, index, id)
    end
    assert(not e.last(e.Events.HOUSE_INTERACT_RESPONSE, 1))
end)
test('round deadline is checked in the handler, not only by the timer', function()
    local e = fixture(); local id = start(e); local token = begin(e, 1, 1, id)
    e.time = e.time + e.Config.TrickOrTreat.roundDurationMinutes * 60000 + 1
    e.fire(e.Events.HOUSE_COLLECT_REQUEST, 1, 1, id, token)
    assert(e.inventory[1].medikit.count == 0)
end)
test('snapshots remove consumed houses and admin reset invalidates old tickets', function()
    local e = fixture(); local id = start(e); local token = begin(e, 1, 1, id); finish(e, 1, 1, id, token)
    e.Halloween.SyncRound(2)
    for _, house in ipairs(e.last(e.Events.ROUND_START, 2).args[1].activeHouseIds) do assert(house ~= 1) end
    e.commands.resetcooldowns(0)
    local data = e.last(e.Events.ROUND_START, 1).args[1]
    assert(data.roundId ~= id and data.currentHouses == 0)
    e.fire(e.Events.HOUSE_COLLECT_REQUEST, 1, 1, id, token)
    assert(e.inventory[1].medikit.count == 3)
end)
test('normal exhaustion ends a round and permissions stay server-side', function()
    local e = fixture(function(c) c.TrickOrTreat.doorsPerRound = 1 end)
    e.commands.startround(1); assert(not e.last(e.Events.ROUND_START))
    local id = start(e); local token = begin(e, 1, 1, id); finish(e, 1, 1, id, token)
    assert(e.last(e.Events.ROUND_END).args[1].totalCollected == 1)
    e.commands.ghost(1, { '2' }); assert(not e.last(e.Events.SHOW_GHOST_CHOICE))
    e.commands.ghost(0, { '2' }); assert(e.last(e.Events.SHOW_GHOST_CHOICE, 2))
end)
test('malformed configuration fails closed without crashing', function()
    local e = fixture(function(c) c.Ghost = nil; c.TrickOrTreat.rewards = nil end)
    assert(not e.Config.Ghost.enabled and not e.Config.TrickOrTreat.enabled)
    local bad = fixture(function(c) c.TrickOrTreat.rewards.candy.chance = 0 / 0 end)
    assert(not bad.Config.TrickOrTreat.enabled)
end)
test('client ghost keys, activation and duration cleanup execute correctly', function()
    local e = fixture(nil, true)
    e.fire(e.Events.GHOST_MODE_RESPONSE, 65535, true, nil, { token = 1, phase = 'preparing', duration = 600000 })
    e.step(0); assert(e.Halloween.ClientGhost())
    e.fire(e.Events.GHOST_MODE_RESPONSE, 65535, true, nil, { token = 1, phase = 'active', duration = 600000 })
    e.step(500); e.step(0) -- Control loop checks numeric key bindings.
    e.step(600001); assert(not e.Halloween.ClientGhost())
end)
test('spoofed client events and invalid models cannot grant ghost mode', function()
    local e = fixture(nil, true)
    e.fire(e.Events.GHOST_MODE_RESPONSE, 1, true, nil, { token = 1, phase = 'preparing' })
    assert(not e.Halloween.ClientGhost())
    e.IsModelValid = function() return false end
    e.fire(e.Events.GHOST_MODE_RESPONSE, 65535, true, nil, { token = 1, phase = 'preparing' })
    e.step(0); assert(not e.Halloween.ClientGhost())
end)
test('client NPC uses numeric ground height and snapshots do not duplicate loops', function()
    local e = fixture(nil, true); e.positions[1] = e.Config.TrickOrTreat.houses[1].coords
    local data = { active = true, roundId = 1, totalHouses = 12, currentHouses = 0,
        timeRemaining = 300000, activeHouseIds = { 1 } }
    local threads = #e.tasks
    for _ = 1, 10 do e.fire(e.Events.ROUND_START, 65535, data) end
    assert(#e.tasks == threads)
    e.step(500); assert(e.spawnZ == 137.42)
    data.activeHouseIds, data.currentHouses = {}, 1
    e.fire(e.Events.ROUND_START, 65535, data); assert(e.deleted == 1)
end)
test('serialized xPlayer copies keep rate limits and session checks intact', function()
    local e = fixture()
    e.ESX.GetPlayerFromId = function(id)
        local original = e.players[id]
        if not original then return nil end
        local copy = {}; for key, value in pairs(original) do copy[key] = value end
        return copy
    end
    e.fire('esx:playerLogout', 0, 1)
    local player = e.Halloween.Player(1)
    assert(player ~= e.players[1] and e.Halloween.Current(1, player))
    assert(e.Halloween.Player(1) == player)
    ghost(e, 1)
    e.players[1] = e.makePlayer(1)
    assert(not e.Halloween.Current(1, player) and not e.exportsList.IsPlayerGhost(1))
end)
test('cancelled ghost request still completes an authorized normal respawn exactly once', function()
    local e = fixture()
    e.states[1] = { dead = true, earlyRemaining = 0 }
    assert(e.Halloween.OfferGhost(1, true))
    local token = e.last(e.Events.SHOW_GHOST_CHOICE).args[2].token
    e.fire(e.Events.REQUEST_GHOST_MODE, 1, 'ghost', token)
    e.fire(e.Events.EXIT_GHOST_MODE, 1, token)
    e.states[1] = { dead = false, recovery = { point = vec(1, 2, 3) } }
    e.fire('esx_death:stateChanged', 0, 1, false, 'respawn'); e.step(0)
    local recovery = assert(e.last('esx_death:recover'))
    e.fire(e.Events.GHOST_READY, 1, token, 'respawned')
    assert(e.last('esx_death:recover') == recovery and not e.exportsList.IsPlayerGhost(1))
end)
test('a reserved house cannot be renewed with repeated start requests', function()
    local e = fixture(); local id = start(e); local token = begin(e, 1, 1, id)
    e.step(1000); e.fire(e.Events.HOUSE_INTERACT_REQUEST, 1, 1, id)
    assert(e.last(e.Events.HOUSE_INTERACT_RESPONSE, 1).args[1].token == token)
    e.step(500); e.fire(e.Events.HOUSE_COLLECT_REQUEST, 1, 1, id, token)
    assert(e.inventory[1].medikit.count == 3)
end)
test('movement, stale tickets and impossible travel cannot collect', function()
    local e = fixture(); local id = start(e); local token = begin(e, 1, 1, id)
    e.positions[1] = vec(0, 0, 0); finish(e, 1, 1, id, token)
    assert(e.inventory[1].medikit.count == 0)
    token = begin(e, 1, 1, id); finish(e, 1, 1, id, token)
    e.step(1000); e.positions[1] = e.Config.TrickOrTreat.houses[2].coords
    local previous = e.last(e.Events.HOUSE_INTERACT_RESPONSE, 1)
    e.fire(e.Events.HOUSE_INTERACT_REQUEST, 1, 2, id)
    assert(e.last(e.Events.HOUSE_INTERACT_RESPONSE, 1) == previous)
end)
test('catalog validation disables unknown reward items and supports ox inventory', function()
    local e = fixture()
    e.ESX.GetItems = function() return { medikit = {} } end
    assert(e.Halloween.ValidateItems() and not e.Config.TrickOrTreat.enabled)
    local ox = fixture()
    ox.ESX.GetConfig = function() return 'ox' end
    assert(ox.Halloween.ValidateItems() and ox.Config.TrickOrTreat.enabled)
end)
test('round snapshots outside the configured bucket reveal no active houses', function()
    local e = fixture(); start(e); e.buckets[2] = 3; e.Halloween.SyncRound(2)
    assert(e.last(e.Events.ROUND_START, 2).args[1].active == false)
end)
test('partial or unconfirmed inventory writes fail closed', function()
    local e = fixture(); local id = start(e)
    e.players[1].addInventoryItem = function(item) e.inventory[1][item].count = 1; return false end
    local token = begin(e, 1, 1, id); finish(e, 1, 1, id, token)
    assert(not e.last(e.Events.HOUSE_COLLECT_RESPONSE, 1).args[1].success)
    e.positions[2] = e.positions[1]; e.fire(e.Events.HOUSE_INTERACT_REQUEST, 2, 1, id)
    assert(not e.last(e.Events.HOUSE_INTERACT_RESPONSE, 2))
end)
test('server authority is rechecked after a yielding inventory capacity check', function()
    local e = fixture(); local id = start(e)
    e.players[1].canCarryItem = function() e.Wait(100); return true end
    local token = begin(e, 1, 1, id); e.step(1500)
    e.CreateThread(function() e.fire(e.Events.HOUSE_COLLECT_REQUEST, 1, 1, id, token) end); e.step(0)
    e.buckets[1] = 3; e.step(100)
    assert(e.inventory[1].medikit.count == 0)
end)
test('elapsed timers remain valid across a 32-bit clock wrap', function()
    local e = fixture(); e.time = 5
    assert(e.Halloween.Elapsed(4294967290.0) == 11)
end)
test('medical recovery closes a pending death offer', function()
    local e = fixture(); e.states[1] = { dead = true, earlyRemaining = 0 }
    assert(e.Halloween.OfferGhost(1, true))
    local token = e.last(e.Events.SHOW_GHOST_CHOICE).args[2].token
    e.states[1].dead = false; e.fire('esx_death:stateChanged', 0, 1, false, 'medic')
    assert(e.last(e.Events.FORCE_GHOST_EXIT, 1).args[1] == token)
    e.fire(e.Events.REQUEST_GHOST_MODE, 1, 'ghost', token)
    assert(not e.exportsList.IsPlayerGhost(1))
end)
test('ghost revocation during death restores appearance only after recovery', function()
    local e = fixture(nil, true)
    e.fire(e.Events.GHOST_MODE_RESPONSE, 65535, true, nil, { token = 1, phase = 'preparing' }); e.step(0)
    e.fire(e.Events.GHOST_MODE_RESPONSE, 65535, true, nil, { token = 1, phase = 'active', duration = 600000 })
    local restored = 0; e.SetPlayerModel = function() restored = restored + 1 end
    e.ESX.PlayerData.dead = true; e.fire(e.Events.FORCE_GHOST_EXIT, 65535, 1)
    assert(restored == 0 and not e.Halloween.ClientGhost())
    e.ESX.PlayerData.dead = false; e.fire('esx_death:recovered', 0)
    assert(restored == 1)
end)
test('resource stop clears active ghost state immediately without waiting', function()
    local e = fixture(nil, true)
    e.fire(e.Events.GHOST_MODE_RESPONSE, 65535, true, nil, { token = 1, phase = 'preparing' }); e.step(0)
    e.fire(e.Events.GHOST_MODE_RESPONSE, 65535, true, nil, { token = 1, phase = 'active', duration = 600000 })
    e.IsScreenFadedOut = function() return false end
    e.fire('onResourceStop', 0, 'esx_halloween')
    assert(not e.Halloween.ClientGhost())
end)
print(('TOTAL %d tests passed'):format(count))
