-- SPDX-License-Identifier: GPL-3.0-only
local count = 0

local function test(name, callback)
    local ok, failure = pcall(callback)
    assert(ok, name .. ': ' .. tostring(failure))
    count = count + 1
    print('PASS ' .. name)
end

local function loadSource(name, environment)
    assert(load(SOURCES[name], '@' .. name, 't', environment))()
end

local function environment()
    local e = setmetatable({}, { __index = _G })
    local function noop() end
    e.events, e.nui, e.payments, e.messages, e.notifications = {}, {}, {}, {}, {}
    e.CreateThread = noop
    e.AddEventHandler = function(name, callback) e.events[name] = callback end
    e.TranslateCap = function(key) return key end
    e.GetCurrentResourceName = function() return 'esx_weaponshop' end
    e.PlayerPedId = function() return 1 end
    e.ClearPedProp, e.SetPedComponentVariation, e.SetPedPropIndex = noop, noop, noop
    e.ESX = {
        SecureNetEvent = e.AddEventHandler,
        HideUI = noop,
        TextUI = noop,
        ShowNotification = function(message) e.notifications[#e.notifications + 1] = message end,
        CloseContext = function() e.contextCloses = (e.contextCloses or 0) + 1 end,
        OpenContext = function() e.contextOpens = (e.contextOpens or 0) + 1 end,
        Math = { GroupDigits = tostring },
    }
    e.Config = { Marker = {}, LicensePrices = { weed_processing = { price = 100, label = 'Weed' } } }
    e.PaymentGateway = {
        NotifyFailure = function(reason) e.failure = reason end,
        Pay = function(request, callbackName, callback, ...)
            e.payments[#e.payments + 1] = { request = request, name = callbackName, done = callback, args = { ... } }
        end,
    }
    return e
end

local function menuOpen(e)
    for i = 1, 20 do
        local name, value = debug.getupvalue(e.OpenBuyLicenseMenu, i)
        if name == 'menuOpen' then return value end
    end
    error('menuOpen upvalue missing')
end

for _, reason in ipairs({ 'cancelled', 'busy', 'insufficient_funds', 'unconfirmed', 'payment_unavailable' }) do
    test('drug license clears interaction after ' .. reason, function()
        local e = environment()
        loadSource('drugs', e)
        e.OpenBuyLicenseMenu('weed_processing')
        assert(menuOpen(e))
        e.payments[1].done(false, reason)
        assert(not menuOpen(e) and e.failure == reason)
        e.OpenBuyLicenseMenu('weed_processing')
        assert(#e.payments == 2, 'The player must be able to retry without leaving the zone')
    end)
end

test('drug license success clears state without closing another context', function()
    local e = environment()
    loadSource('drugs', e)
    e.OpenBuyLicenseMenu('weed_processing')
    e.payments[1].done(true)
    assert(not menuOpen(e) and #e.notifications == 1 and e.contextCloses == nil)
end)

test('invalid and duplicate drug license requests do not open extra payments', function()
    local e = environment()
    loadSource('drugs', e)
    e.OpenBuyLicenseMenu('unknown')
    assert(#e.payments == 0 and not menuOpen(e))
    e.OpenBuyLicenseMenu('weed_processing')
    e.OpenBuyLicenseMenu('weed_processing')
    assert(#e.payments == 1)
end)

test('logout invalidates drug license replies without clearing a newer request', function()
    local e = environment()
    loadSource('drugs', e)
    e.OpenBuyLicenseMenu('weed_processing')
    e.events['esx:onPlayerLogout']()
    assert(not menuOpen(e))
    e.OpenBuyLicenseMenu('weed_processing')
    e.payments[1].done(true)
    assert(menuOpen(e) and #e.notifications == 0)
    e.payments[2].done(false, 'cancelled')
    assert(not menuOpen(e))
end)

local function weaponFixture()
    local e = environment()
    e.Config = {
        Type = 1,
        LicensePrice = 100,
        Zones = { A = { Legal = true, Locations = { 'A' } }, B = { Legal = true, Locations = { 'B' } } },
        Size = {}, Color = { r = 1, g = 1, b = 1 },
    }
    e.markerHandlers, e.opened, e.awaitCalls = {}, {}, 0
    e.BuildShopItems = function() return {} end
    e.BuildCategories = function() return {} end
    e.GetShopLocales = function() return {} end
    e.GetWeaponShopFallbackImage = function() return '' end
    e.xLib = {
        markerZone = { create = function(options) e.markerHandlers[options.coords] = options; return {} end },
        nui = {
            register = function(name, callback) e.nui[name] = callback end,
            focus = function(focus) e.focus = focus end,
            close = function() e.focus = false end,
            send = function(message)
                if message.type == 'openShop' then e.opened[#e.opened + 1] = message end
            end,
        },
    }
    e.PaymentGateway.Await = function()
        e.awaitCalls = e.awaitCalls + 1
        return coroutine.yield('payment')
    end
    loadSource('weapons', e)
    loadSource('markers', e)
    loadSource('weaponMain', e)
    e.RegisterWeaponShopMarkers()
    e.markerHandlers.A.onEnter()
    return e
end

local function startPayment(callback)
    local thread = coroutine.create(callback)
    local ok, state = coroutine.resume(thread)
    assert(ok and state == 'payment', tostring(state))
    return thread
end

local function reply(thread, success)
    local ok, failure = coroutine.resume(thread, success)
    assert(ok and coroutine.status(thread) == 'dead', tostring(failure))
end

test('weapon license pending state blocks repeated interaction', function()
    local e = weaponFixture()
    local thread = startPayment(function() e.OpenBuyLicenseMenu('A') end)
    assert(e.IsUIOpen())
    e.OpenBuyLicenseMenu('A')
    assert(e.awaitCalls == 1)
    reply(thread, true)
    assert(#e.opened == 1 and e.GetCurrentShop() == 'A' and e.focus)
end)

test('cancelled weapon license leaves no active shop or focus', function()
    local e = weaponFixture()
    local thread = startPayment(function() e.OpenBuyLicenseMenu('A') end)
    reply(thread, false)
    assert(not e.IsUIOpen() and e.GetCurrentShop() == nil and not e.focus and #e.opened == 0)
end)

for _, action in ipairs({ 'close', 'exit', 'logout', 'resource stop' }) do
    test('late weapon license approval cannot reopen after ' .. action, function()
        local e = weaponFixture()
        local thread = startPayment(function() e.OpenBuyLicenseMenu('A') end)
        if action == 'close' then e.CloseShop()
        elseif action == 'exit' then e.markerHandlers.A.onExit()
        elseif action == 'logout' then e.events['esx:onPlayerLogout']()
        else e.events.onResourceStop('esx_weaponshop') end
        assert(not e.IsUIOpen())
        reply(thread, true)
        assert(#e.opened == 0 and e.GetCurrentShop() == nil and not e.focus)
    end)
end

test('returning to the same marker does not revive an old license request', function()
    local e = weaponFixture()
    local thread = startPayment(function() e.OpenBuyLicenseMenu('A') end)
    e.markerHandlers.A.onExit()
    e.markerHandlers.A.onEnter()
    reply(thread, true)
    assert(#e.opened == 0 and not e.IsUIOpen())
end)

test('an old license reply leaves a newer shop and its focus alone', function()
    local e = weaponFixture()
    local thread = startPayment(function() e.OpenBuyLicenseMenu('A') end)
    e.markerHandlers.A.onExit()
    e.markerHandlers.B.onEnter()
    e.OpenShop('B')
    reply(thread, true)
    assert(#e.opened == 1 and e.GetCurrentShop() == 'B' and e.IsUIOpen() and e.focus)
end)

test('weapon license cannot open for an unknown or remote shop', function()
    local e = weaponFixture()
    e.OpenBuyLicenseMenu('unknown')
    e.OpenBuyLicenseMenu('B')
    assert(e.awaitCalls == 0 and not e.IsUIOpen())
end)

test('legacy weapon license callback also rejects a late shop reopen', function()
    local e = weaponFixture()
    e.OpenShop('A')
    local acknowledged
    local thread = startPayment(function()
        e.nui.buyLicense({}, function(result) acknowledged = result.ok end)
    end)
    e.CloseShop()
    reply(thread, true)
    assert(acknowledged and #e.opened == 1 and not e.IsUIOpen() and not e.focus)
end)

local function skinFixture(resource)
    local e = environment()
    e.Config = { Price = 100, Locale = 'en', EnableControls = false }
    e.Locales = { en = { save_failed = 'save_failed' } }
    e.originalSkin = { sex = 0, torso_1 = 1 }
    e.selectedSkin = { sex = 0, torso_1 = 2 }
    e.skin = e.originalSkin
    e.TriggerEvent = function(name, ...)
        local args = { ... }
        if name == 'skinchanger:getSkin' then args[1](e.skin)
        elseif name == 'esx_skin:openRestrictedMenu' then e.submit, e.cancel = args[1], args[2]
        elseif name == 'esx_skin:getLastSkin' then args[1](e.originalSkin)
        elseif name == 'skinchanger:loadSkin' then e.restored = args[1]
        elseif name == 'esx_skin:setLastSkin' then e.saved = args[1] end
    end
    e.TriggerServerEvent = function(name) e.savedEvent = name end
    e.xLib = { callback = function(_, _, callback) callback(false) end }
    loadSource(resource, e)
    e.OpenShopMenu(resource == 'accessories' and 'Helmet' or nil)
    e.skin = e.selectedSkin
    e.submit({}, { close = function() end })
    assert(#e.payments == 1 and not e.contextOpens, 'Go straight from preview to the payment gateway')
    return e
end

for _, resource in ipairs({ 'accessories', 'barber', 'clothes' }) do
    test(resource .. ' restores preview when the payment is cancelled', function()
        local e = skinFixture(resource)
        e.payments[1].done(false, 'cancelled')
        assert(e.restored == e.originalSkin and not e.saved and not e.savedEvent)
    end)
    test(resource .. ' persists the selected appearance only after payment', function()
        local e = skinFixture(resource)
        e.payments[1].done(true)
        if resource == 'accessories' then assert(e.savedEvent == 'esx_accessories:save')
        else assert(e.saved == e.selectedSkin) end
        assert(not e.restored)
    end)
end

test('boat license opens the gateway directly and opens the shop only after success', function()
    local e = environment()
    e.Config = { LicensePrice = 100 }
    loadSource('boats', e)
    e.OpenBoatShop = function(shop) e.shop = shop end
    e.OpenLicenceMenu('marina')
    assert(#e.payments == 1 and not e.contextOpens)
    e.payments[1].done(false, 'cancelled')
    assert(not e.shop)
    e.OpenLicenceMenu('marina')
    e.payments[2].done(true)
    assert(e.shop == 'marina')
end)

test('payment compatibility fails closed when the core charge API is absent', function()
    local e = environment()
    e.IsDuplicityVersion = function() return true end
    e.print = function() end
    loadSource('imports', e)
    local paid, reason = e.PaymentGateway.Charge({ isCurrent = function() return true end }, 'money', 100)
    assert(paid == false and reason == 'payment_unavailable')
    local charged = 0
    local player = { isCurrent = function() return true end, chargeAccount = function(_, amount) charged = charged + amount; return true end }
    assert(e.PaymentGateway.Charge(player, 'bank', 100))
    assert(charged == 100 and not e.PaymentGateway.Charge(player, 'black_money', 100))
end)

test('vehicle shop keeps yes/no translations used by its remaining confirmation menus', function()
    local checked = 0
    for name, source in pairs(SOURCES) do
        local language = name:match('^vehicleLocale:(.+)$')
        if language then
            local e = environment()
            e.Locales = {}
            assert(load(source, '@' .. name, 't', e))()
            local strings = assert(e.Locales[language])
            assert(type(strings.yes) == 'string' and type(strings.no) == 'string', language)
            checked = checked + 1
        end
    end
    assert(checked >= 13)
end)

print(('TOTAL %d purchase confirmation tests passed'):format(count))
