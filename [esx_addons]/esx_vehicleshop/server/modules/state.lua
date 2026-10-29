-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
VehicleShop = {
    ready = false,
    shops = {},
    catalog = {},
    categories = {},
    members = {},
    locks = {},
    callbacks = {},
    sequence = 0,
}

local D = VehicleShop

function D.fail(code)
    error({ shopError = code }, 0)
end

function D.assert(value, code)
    if not value then
        D.fail(code)
    end

    return value
end

function D.money(value, allowZero)
    value = tonumber(value)
    return value
            and value == value
            and value >= (allowZero and 0 or 1)
            and value <= 2147483647
            and value % 1 == 0
            and value
        or nil
end

function D.identifier(player)
    return player.getIdentifier()
end

function D.modelHash(value)
    local hash = tonumber(value) or (D.normalizeModel(value) and joaat(value))

    return hash and hash == hash and hash % 1 == 0 and hash % 4294967296 or nil
end

function D.current(player)
    return player and ESX.GetPlayerFromId(player.source) == player and player.isCurrent() == true
end

function D.contains(values, value)
    for _, candidate in ipairs(values or {}) do
        if candidate == value then
            return true
        end
    end

    return false
end

function D.copy(value)
    return json.decode(json.encode(value))
end

function D.point(value)
    if not value then
        return nil
    end

    local heading = (type(value) == 'table' or type(value) == 'vector4') and value.w or nil

    return { x = value.x, y = value.y, z = value.z, w = heading }
end

function D.near(source, point, distance)
    return point ~= nil
        and xLib.player.isNearCoords(
                source,
                vector3(point.x, point.y, point.z),
                distance or 8.0
            )
            == true
end

function D.normalizeModel(model)
    return type(model) == 'string' and #model <= 60 and model:match('^[%w_%-]+$') and model:lower()
        or nil
end

function D.safeProps(props, model, plate)
    local result = type(props) == 'table' and D.copy(props) or {}

    result.model, result.plate = joaat(model), plate
    D.assert(#json.encode(result) <= 16384, 'invalid_properties')
    return result
end

function D.lock(key, action)
    if D.locks[key] then
        return nil, 'busy'
    end

    D.locks[key] = true

    local ok, result = pcall(action)

    D.locks[key] = nil

    if not ok then
        if type(result) == 'table' and result.shopError then
            return nil, result.shopError
        end

        print(('[esx_vehicleshop] operation failed (%s): %s'):format(key, tostring(result)))
        return nil, 'operation_failed'
    end

    return result
end

function D.register(name, handler)
    D.callbacks[name] = handler

    local limiter = xLib.rateLimiter({ capacity = 2, refill = 1, interval = 500 })

    xLib.callback.registerCompat('esx_vehicleshop:' .. name, function(source, cb, ...)
        if not D.ready then
            return cb({ success = false, error = 'not_ready' })
        end

        if not limiter:consume(source) then
            return cb({ success = false, error = 'busy' })
        end

        local ok, result = pcall(handler, source, ...)

        if not ok then
            local code = type(result) == 'table' and result.shopError or 'operation_failed'

            if code == 'operation_failed' then
                print('[esx_vehicleshop] ' .. tostring(result))
            end

            return cb({ success = false, error = code })
        end

        cb({ success = true, data = result })
    end)
end

function D.uuid()
    return assert(MySQL.scalar.await('SELECT UUID()'), 'Unable to allocate an operation id')
end

function D.plate()
    return xLib.vehiclePlate.generateUnique({
        letters = Config.PlateLetters,
        numbers = Config.PlateNumbers,
        useSpace = Config.PlateUseSpace,
    }, function(plate)
        return MySQL.scalar.await(
            (
                'SELECT plate FROM owned_vehicles WHERE plate = ? UNION SELECT '
                .. 'plate FROM rented_vehicles WHERE plate = ?\n            UNION '
                .. 'SELECT plate FROM vehicle_sold WHERE plate = ? UNION SELECT '
                .. 'reserved_plate AS plate FROM esx_vehicle_orders WHERE '
                .. 'reserved_plate = ? UNION SELECT plate FROM esx_vehicle_rentals '
                .. 'WHERE plate = ? LIMIT '
                .. '1'
            ),
            { plate, plate, plate, plate, plate }
        ) ~= nil
    end)
end

function D.addShop(id, definition, resource)
    D.assert(
        type(id) == 'string'
            and #id <= 64
            and id:match('^[%w_%-:]+$')
            and type(definition) == 'table',
        'invalid_shop'
    )
    D.assert(not D.shops[id] or D.shops[id].resource == resource, 'shop_id_conflict')
    definition.id, definition.resource = id, resource
    definition.mode = definition.mode or definition.type or 'public'

    if definition.mode == 'job' then
        definition.mode = 'public'
    end

    D.assert(definition.mode == 'public' or definition.mode == 'managed', 'invalid_shop_mode')
    D.assert(
        type(definition.vehicleTypes) == 'table' and #definition.vehicleTypes > 0,
        'invalid_vehicle_types'
    )

    for _, kind in ipairs(definition.vehicleTypes) do
        D.assert(VehicleShopTypes[kind], 'invalid_vehicle_type')
    end

    definition.paymentMethods = definition.paymentMethods or { 'money', 'bank' }

    for _, method in ipairs(definition.paymentMethods) do
        D.assert(method == 'money' or method == 'bank' or method == 'society', 'invalid_account')
    end

    definition.delivery = definition.delivery or { mode = 'garage' }
    definition.stockMode = definition.stockMode
        or (definition.mode == 'managed' and 'limited' or 'unlimited')
    D.assert(
        definition.stockMode == 'limited' or definition.stockMode == 'unlimited',
        'invalid_stock_mode'
    )

    if definition.mode == 'managed' then
        D.assert(
            definition.management
                and type(definition.management.job) == 'string'
                and type(definition.societyAccount) == 'string',
            'invalid_management'
        )
        definition.societyInventory = definition.societyInventory or definition.societyAccount
    end

    if definition.rentals and definition.rentals.enabled then
        D.assert(
            definition.mode == 'managed'
                and not definition.ownershipJob
                and definition.returnPoint
                and definition.stockMode == 'limited',
            'invalid_rental_configuration'
        )
    end

    D.shops[id] = definition
end

for id, definition in pairs(Config.Dealerships) do
    D.addShop(id, definition, 'config')
end
