-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
local D = VehicleShop

function D.cleanupTrade(order)
    local clear = true

    for _, entity in ipairs(GetAllVehicles()) do
        if
            DoesEntityExist(entity)
            and xLib.vehiclePlate.normalize(GetVehicleNumberPlateText(entity)) == order.plate
        then
            local managed = ESX.GetExtendedVehicleFromPlate(order.plate)

            if managed then
                pcall(function()
                    managed:delete()
                end)
            else
                pcall(DeleteEntity, entity)
            end

            local deadline = GetGameTimer() + 2000

            while DoesEntityExist(entity) and GetGameTimer() < deadline do
                Wait(20)
            end

            if DoesEntityExist(entity) then
                clear = false
            end
        end
    end

    if not clear then
        return false
    end

    MySQL.update.await(
        (
            'UPDATE cardealer_vehicles SET available = 1, return_plate = NULL '
            .. 'WHERE source_order = ? AND available = '
            .. '0'
        ),
        { order.id }
    )
    MySQL.update.await(
        (
            "UPDATE esx_vehicle_orders SET delivery_state = 'complete' WHERE "
            .. 'id = ? AND state = '
            .. "'complete'"
        ),
        { order.id }
    )
    return true
end

function D.recoverTradeEntities()
    local rows = MySQL.query.await(
        (
            'SELECT id, plate FROM esx_vehicle_orders\n        WHERE state = '
            .. "'complete' AND kind IN ('return', 'resale') AND "
            .. "delivery_state = 'pending' LIMIT "
            .. '100'
        )
    ) or {}

    for _, row in ipairs(rows) do
        local ok, result = pcall(D.cleanupTrade, row)

        if not ok or not result then
            print('[esx_vehicleshop] Returned entity cleanup pending: ' .. row.id)
        end
    end

    for _, row in
        ipairs(
            MySQL.query.await(
                (
                    'SELECT id, return_plate FROM cardealer_vehicles WHERE '
                    .. 'available = 0 AND return_plate IS NOT NULL LIMIT '
                    .. '100'
                )
            ) or {}
        )
    do
        local clear = true

        for _, entity in ipairs(GetAllVehicles()) do
            if
                DoesEntityExist(entity)
                and xLib.vehiclePlate.normalize(GetVehicleNumberPlateText(entity))
                    == row.return_plate
            then
                local managed = ESX.GetExtendedVehicleFromPlate(row.return_plate)

                if managed then
                    pcall(function()
                        managed:delete()
                    end)
                else
                    pcall(DeleteEntity, entity)
                end

                if DoesEntityExist(entity) then
                    clear = false
                end
            end
        end

        if clear then
            MySQL.update.await(
                (
                    'UPDATE cardealer_vehicles SET available = 1, return_plate '
                    .. '= NULL WHERE id = ? AND available = '
                    .. '0'
                ),
                { row.id }
            )
        end
    end
end

D.register('getDealerships', function(source)
    local player = ESX.GetPlayerFromId(source)
    local result = {}

    for _, shop in pairs(D.shops) do
        if D.canAccess(player, shop) then
            result[#result + 1] = D.shopPayload(shop, player)
        end
    end

    return result
end)

D.register('getDealership', function(source, id, page)
    local player, shop = D.playerShop(source, id)
    local vehicles = D.catalogFor(shop, player)

    D.assert(D.canAccess(player, shop) and D.location(source, shop), 'purchase_invalidated')

    local result = { shop = D.shopPayload(shop, player), vehicles = vehicles }

    result.orders = MySQL.query.await(
        (
            'SELECT id, kind, model, plate, amount, state FROM '
            .. 'esx_vehicle_orders WHERE owner = ? AND shop_id = ? ORDER BY '
            .. 'created_at DESC LIMIT '
            .. '10'
        ),
        { player.getIdentifier(), id }
    ) or {}

    if D.employee(player, shop) then
        page = math.max(1, math.min(10000, math.floor(tonumber(page) or 1)))
        result.stock = MySQL.query.await(
            (
                'SELECT id, vehicle, price, available FROM cardealer_vehicles '
                .. 'WHERE shop_id = ? ORDER BY vehicle, id LIMIT 51 OFFSET '
                .. '?'
            ),
            { id, (page - 1) * 50 }
        ) or {}
        result.rentals = MySQL.query.await(
            (
                'SELECT vehicle, plate, player_name, rent_price FROM '
                .. 'rented_vehicles WHERE shop_id = ? ORDER BY player_name, plate '
                .. 'LIMIT 51 OFFSET '
                .. '?'
            ),
            { id, (page - 1) * 50 }
        ) or {}
        result.stockMore = #result.stock > 50
        result.stock[51] = nil
        result.rentalsMore = #result.rentals > 50
        result.rentals[51] = nil
        result.sales = MySQL.query.await(
            (
                'SELECT client, model, plate, soldby, date FROM vehicle_sold '
                .. 'WHERE shop_id = ? ORDER BY date DESC, plate DESC LIMIT 51 '
                .. 'OFFSET '
                .. '?'
            ),
            { id, (page - 1) * 50 }
        ) or {}
        result.salesMore = #result.sales > 50
        result.sales[51] = nil
        result.salesPage = page

        if D.employee(player, shop, true) then
            TriggerEvent('esx_addonaccount:getSharedAccount', shop.societyAccount, function(account)
                result.societyBalance = account and account.money
            end)
        end

        D.assert(
            D.current(player) and D.employee(player, shop) and D.location(source, shop),
            'purchase_invalidated'
        )
    end

    D.assert(D.canAccess(player, shop) and D.location(source, shop), 'purchase_invalidated')
    return result
end)

D.register('quote', D.quote)
D.register('executeOrder', D.execute)
D.register('orderStatus', function(source, id)
    local player = D.assert(ESX.GetPlayerFromId(source), 'player')
    local order = D.assert(
        MySQL.single.await(
            'SELECT * FROM esx_vehicle_orders WHERE id = ? AND owner = ?',
            { id, player.getIdentifier() }
        ),
        'invalid_order'
    )

    local movement =
        MySQL.single.await('SELECT * FROM esx_vehicle_movements WHERE order_id = ?', { id })

    if not movement and order.state == 'processing' and not D.locks['buyer:' .. order.owner] then
        movement = D.reconcileOrder(id)
        order = D.assert(
            MySQL.single.await(
                'SELECT * FROM esx_vehicle_orders WHERE id = ? AND owner = ?',
                { id, player.getIdentifier() }
            ),
            'invalid_order'
        )
    end

    D.assert(D.current(player), 'session_closing')

    if movement then
        return D.orderResult(order, movement, true)
    end

    return {
        id = id,
        complete = false,
        state = order.state,
        expired = order.expires_at < os.time(),
    }
end)

D.register('getOffer', function(source, id)
    local player = D.assert(ESX.GetPlayerFromId(source), 'player')
    local order = D.assert(
        MySQL.single.await(
            (
                'SELECT * FROM esx_vehicle_orders WHERE id = ? AND owner = ? '
                .. "AND state = 'quoted' AND expires_at >= "
                .. '?'
            ),
            { id, player.getIdentifier(), os.time() }
        ),
        'order_expired'
    )

    local payload, shop =
        json.decode(order.payload), D.assert(D.shops[order.shop_id], 'invalid_shop')
    D.validateOrder(player, shop, order, payload)
    return {
        id = id,
        kind = order.kind,
        model = order.model,
        name = order.model,
        amount = order.amount,
        rentPrice = payload.rentPrice,
        paymentMethods = D.orderMethods(shop, order.kind),
        plate = order.plate,
    }
end)

D.register('getInventory', function(source, id)
    local player, shop = D.playerShop(source, id, 'inventory', true)

    if Config.OxInventory then
        return { ox = true, stash = shop.societyInventory }
    end

    local inventory

    TriggerEvent('esx_addoninventory:getSharedInventory', shop.societyInventory, function(value)
        inventory = value
    end)

    D.assert(inventory, 'inventory_unavailable')
    return { society = inventory.items, player = player.getInventory(false) }
end)

D.register('moveInventory', function(source, id, item, count, deposit)
    local player, shop = D.playerShop(source, id, 'inventory', true)

    count = xLib.validation.count(count)
    D.assert(
        type(item) == 'string' and count and type(deposit) == 'boolean' and not Config.OxInventory,
        'invalid_item'
    )

    local inventory

    TriggerEvent('esx_addoninventory:getSharedInventory', shop.societyInventory, function(value)
        inventory = value
    end)

    D.assert(inventory, 'inventory_unavailable')

    local from = deposit and player.getInventoryItem(item) or inventory.getItem(item)

    D.assert(from and from.count >= count, 'not_enough_items')

    if not deposit then
        D.assert(player.canCarryItem(item, count), 'inventory_full')
    end

    D.assert(
        D.current(player) and D.employee(player, shop) and D.location(source, shop),
        'purchase_invalidated'
    )

    if deposit then
        D.assert(player.removeInventoryItem(item, count) ~= false, 'inventory_failed')

        if inventory.addItem(item, count) == false then
            player.addInventoryItem(item, count)
            D.fail('inventory_failed')
        end
    else
        D.assert(inventory.removeItem(item, count) ~= false, 'inventory_failed')

        if player.addInventoryItem(item, count) == false then
            inventory.addItem(item, count)
            D.fail('inventory_failed')
        end
    end

    return true
end)

exports('registerDealership', function(id, definition)
    local resource = D.assert(GetInvokingResource(), 'server_only')

    if D.shops[id] and D.shops[id].resource == 'config' then
        return id
    end

    D.addShop(id, definition, resource)

    if D.ready then
        D.reloadCatalog()
        D.registerSocieties()
        TriggerClientEvent('esx_vehicleshop:dealershipsChanged', -1)
    end

    return id
end)

AddEventHandler('onResourceStop', function(resource)
    local changed = false

    for id, shop in pairs(D.shops) do
        if shop.resource == resource then
            D.shops[id] = nil
            changed = true
        end
    end

    if changed then
        TriggerClientEvent('esx_vehicleshop:dealershipsChanged', -1)
    end
end)
