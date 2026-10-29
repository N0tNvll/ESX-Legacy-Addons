-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
-- Legacy names delegate to the same quote/settlement service. No legacy handler moves money
-- independently.
local D = VehicleShop

local function legacy(name, handler, fallback)
    if fallback == nil then
        local emptyLists = {
            ['esx_vehicleshop:getCommercialVehicles'] = true,
            ['esx_vehicleshop:getRentedVehicles'] = true,
            ['esx_vehicleshop:getSoldVehicles'] = true,
            ['esx_vehicleshop:getStockItems'] = true,
        }
        fallback = emptyLists[name] and {}
            or name == 'esx_vehicleshop:getPlayerInventory' and { items = {} }
            or false
    end

    xLib.callback.registerCompat(name, function(source, cb, ...)
        local player = ESX.GetPlayerFromId(source)

        if not D.ready then
            return cb(fallback, 'not_ready')
        end

        local values = table.pack(pcall(handler, source, ...))

        if not values[1] then
            local code = type(values[2]) == 'table' and values[2].shopError or 'operation_failed'

            return cb(fallback, code)
        end

        if player and not D.current(player) then
            return cb(fallback, 'session_closing')
        end

        cb(table.unpack(values, 2, values.n))
    end)
end

local function purchase(source, request, account)
    local quote = D.quote(source, request)
    local result = D.execute(source, quote.id, account)

    return result.complete, nil, result.plate
end

local function stock(source)
    local player, shop = D.playerShop(source, Config.LegacyDealershipId, nil, true)

    return player, shop
end

local function findShop(source, predicate)
    local player = ESX.GetPlayerFromId(source)

    for _, shop in pairs(D.shops) do
        if predicate(shop) and D.canAccess(player, shop) and D.location(source, shop) then
            return shop
        end
    end

    D.fail('not_near_shop')
end

legacy('esx_vehicleshop:buyVehicle', function(source, model, ignoredPlate, account)
    return purchase(
        source,
        { shopId = Config.LegacyDealershipId, model = model, reference = ignoredPlate },
        account
    )
end)

legacy('esx_vehicleshop:buyCarDealerVehicle', function(source, model)
    return purchase(
        source,
        { shopId = Config.LegacyDealershipId, model = model, kind = 'stock' },
        'society'
    )
end)

legacy('esx_vehicleshop:getCommercialVehicles', function(source)
    local _, shop = stock(source)

    local rows = MySQL.query.await(
        (
            'SELECT id, vehicle, price FROM cardealer_vehicles WHERE shop_id = '
            .. '? AND available = 1 ORDER BY '
            .. 'vehicle'
        ),
        { shop.id }
    )
    stock(source)
    return rows
end)

legacy('esx_vehicleshop:getRentedVehicles', function(source)
    local _, shop = stock(source)
    local result = {}

    for _, row in
        ipairs(
            MySQL.query.await(
                'SELECT * FROM rented_vehicles WHERE shop_id = ? ORDER BY player_name',
                { shop.id }
            )
        )
    do
        result[#result + 1] =
            { name = row.vehicle, plate = row.plate, playerName = row.player_name }
    end

    stock(source)
    return result
end)

legacy('esx_vehicleshop:getSoldVehicles', function(source, page)
    local _, shop = stock(source)

    page = tonumber(page) or 1
    D.assert(page >= 1 and page <= 10000 and page % 1 == 0, 'invalid_page')

    local rows = MySQL.query.await(
        (
            'SELECT client, model, plate, soldby, date FROM vehicle_sold WHERE '
            .. 'shop_id = ? ORDER BY date DESC, plate DESC LIMIT 51 OFFSET '
            .. '?'
        ),
        { shop.id, (page - 1) * 50 }
    )

    local more = #rows > 50

    stock(source)

    rows[51] = nil
    return rows, more, page
end)

legacy('esx_vehicleshop:giveBackVehicle', function(source, plate)
    return purchase(
        source,
        { shopId = Config.LegacyDealershipId, kind = 'return', plate = plate },
        'money'
    )
end)

legacy('esx_vehicleshop:resellVehicle', function(source, plate)
    return purchase(
        source,
        { shopId = Config.LegacyDealershipId, kind = 'resale', plate = plate },
        'money'
    )
end)

legacy('esx_vehicleshop:isPlateTaken', function(_, plate)
    plate = xLib.vehiclePlate.normalize(plate)

    if not plate then
        return true
    end

    return MySQL.scalar.await(
        (
            'SELECT plate FROM owned_vehicles WHERE plate = ? UNION SELECT '
            .. 'plate FROM rented_vehicles WHERE plate = ?\n        UNION SELECT '
            .. 'plate FROM vehicle_sold WHERE plate = ? UNION SELECT '
            .. 'reserved_plate FROM esx_vehicle_orders WHERE reserved_plate = ? '
            .. 'LIMIT '
            .. '1'
        ),
        { plate, plate, plate, plate }
    ) ~= nil
end, true)

legacy('esx_vehicleshop:getStockItems', function(source)
    return D.callbacks.getInventory(source, Config.LegacyDealershipId).society or {}
end)

legacy('esx_vehicleshop:getPlayerInventory', function(source)
    local player = D.playerShop(source, Config.LegacyDealershipId, 'inventory', true)

    return { items = player.getInventory(false) }
end)

local function event(name, handler)
    RegisterNetEvent(name, function(...)
        if not D.ready then
            return
        end

        local ok, err = pcall(handler, source, ...)

        if not ok then
            print(
                ('[esx_vehicleshop] Legacy %s rejected: %s'):format(
                    name,
                    type(err) == 'table' and err.shopError or tostring(err)
                )
            )
        end
    end)
end

event('esx_vehicleshop:setVehicleOwnedPlayerId', function(source, target, ignoredProps, model)
    D.quote(
        source,
        { shopId = Config.LegacyDealershipId, kind = 'purchase', model = model, targetId = target }
    )
end)

event('esx_vehicleshop:rentVehicle', function(source, model, ignoredPlate, ignoredPrice, target)
    D.quote(
        source,
        { shopId = Config.LegacyDealershipId, kind = 'rent', model = model, targetId = target }
    )
end)

event('esx_vehicleshop:returnProvider', function(source, model)
    local _, shop = stock(source)
    local id = MySQL.scalar.await(
        (
            'SELECT id FROM cardealer_vehicles WHERE shop_id = ? AND vehicle = '
            .. '? AND available = 1 ORDER BY id LIMIT '
            .. '1'
        ),
        { shop.id, model }
    )
    purchase(source, { shopId = shop.id, kind = 'provider', stockId = id }, 'society')
end)

event('esx_vehicleshop:getStockItem', function(source, item, count)
    D.callbacks.moveInventory(source, Config.LegacyDealershipId, item, count, false)
end)

event('esx_vehicleshop:putStockItems', function(source, item, count)
    D.callbacks.moveInventory(source, Config.LegacyDealershipId, item, count, true)
end)

event('esx_vehicleshop:getVehiclesAndCategories', function(source)
    local player = ESX.GetPlayerFromId(source)
    local shop = D.shops[Config.LegacyDealershipId]

    if not D.canAccess(player, shop) then
        return
    end

    local rows, index = D.catalogFor(shop, player), {}

    for _, row in ipairs(rows) do
        index[row.model] = row
    end

    TriggerClientEvent(
        'esx_vehicleshop:updateVehiclesAndCategories',
        source,
        rows,
        D.categories,
        index
    )
end)

legacy('esx_boat:buyBoat', function(source, props, account)
    local hash = type(props) == 'table' and tonumber(props.model)
    local shop = findShop(source, function(value)
        return D.contains(value.vehicleTypes, 'boat')
    end)

    for model in pairs(D.members[shop.id] or {}) do
        if hash and joaat(model) % 4294967296 == hash % 4294967296 then
            return purchase(
                source,
                { shopId = shop.id, model = model, reference = props.plate },
                account
            )
        end
    end

    D.fail('invalid_vehicle')
end)

legacy('esx_boat:buyBoatLicense', function(source, account)
    local shop = findShop(source, function(value)
        return value.license == 'boat'
    end)

    return purchase(source, { shopId = shop.id, kind = 'license' }, account)
end)

for _, job in ipairs({ 'police', 'ambulance' }) do
    legacy('esx_' .. job .. 'job:buyJobVehicle', function(source, props, kind, account)
        local hash = type(props) == 'table' and tonumber(props.model)
        local vehicleType = kind == 'helicopter' and 'helicopter' or 'car'
        local shop = findShop(source, function(value)
            return value.ownershipJob == job and D.contains(value.vehicleTypes, vehicleType)
        end)

        for model in pairs(D.members[shop.id] or {}) do
            if hash and joaat(model) % 4294967296 == hash % 4294967296 then
                return purchase(
                    source,
                    { shopId = shop.id, model = model, reference = props.plate },
                    account
                )
            end
        end

        D.fail('invalid_vehicle')
    end)
end

exports('legacyPurchase', function(source, request, account)
    D.assert(GetInvokingResource(), 'server_only')
    return purchase(source, request, account)
end)

function SQLVehiclesAndCategories()
    if D.ready then
        D.reloadCatalog()
        TriggerClientEvent('esx_vehicleshop:dealershipsChanged', -1)
    end
end

function getVehicleFromModel(model)
    return D.catalog[type(model) == 'string' and model:lower() or '']
end
