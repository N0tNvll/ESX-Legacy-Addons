-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
local D = VehicleShop
local quoteLimiter = xLib.rateLimiter({ capacity = 1, refill = 1, interval = 800 })

function D.orderMethods(shop, kind)
    if kind == 'stock' or kind == 'provider' then
        return { 'society' }
    end

    if kind == 'deposit' or kind == 'withdraw' then
        return { 'bank' }
    end

    if kind == 'resale' or kind == 'return' then
        return { 'money' }
    end

    return shop.paymentMethods
end

local function closeTo(a, b)
    local ap, bp = GetPlayerPed(a.source), GetPlayerPed(b.source)

    return ap > 0
        and bp > 0
        and #(GetEntityCoords(ap) - GetEntityCoords(bp)) <= 8
        and GetPlayerRoutingBucket(a.source) == GetPlayerRoutingBucket(b.source)
end

function D.validateOrder(player, shop, order, payload)
    D.assert(
        D.canAccess(player, shop) and D.location(player.source, shop, order.kind),
        'purchase_invalidated'
    )

    if payload.seller then
        local seller = ESX.GetPlayerFromId(payload.seller.source)

        D.assert(
            D.current(seller)
                and seller.getIdentifier() == payload.seller.owner
                and D.employee(seller, shop)
                and closeTo(player, seller),
            'seller_unavailable'
        )
    end

    if order.kind == 'stock' or order.kind == 'provider' then
        D.assert(D.employee(player, shop), 'employee_required')
    end

    if order.kind == 'deposit' or order.kind == 'withdraw' then
        D.assert(D.employee(player, shop, true), 'boss_required')
    end

    if order.kind == 'purchase' or order.kind == 'rent' or order.kind == 'stock' then
        local offer = D.offer(shop, order.model, player)

        D.assert(
            offer and offer.price == payload.price and offer.type == payload.vehicleType,
            'quote_changed'
        )

        if order.kind ~= 'stock' then
            D.validBuyer(player, shop, offer)
        end

        if order.kind == 'purchase' and shop.mode == 'managed' then
            D.assert(payload.seller, 'employee_required')
        end

        if order.kind == 'rent' then
            D.assert(
                shop.rentals
                    and shop.rentals.enabled
                    and payload.seller
                    and D.money(payload.rentPrice),
                'rentals_disabled'
            )
            D.assert(
                D.rentalPaymentsReady
                    and GetResourceState('cron') == 'started'
                    and GetResourceState('esx_addonaccount') == 'started',
                'rentals_unavailable'
            )

            local rentalAccount

            TriggerEvent('esx_addonaccount:getSharedAccount', shop.societyAccount, function(value)
                rentalAccount = value
            end)

            D.assert(rentalAccount and rentalAccount.withPersistence, 'society_unavailable')
        end
    elseif order.kind == 'license' then
        D.assert(
            shop.license and shop.license == payload.license and shop.licensePrice == order.amount,
            'quote_changed'
        )
        D.assert(GetResourceState('esx_license') == 'started', 'license_unavailable')

        for _, name in ipairs({ 'licenses', 'user_licenses' }) do
            local engine = MySQL.scalar.await(
                (
                    'SELECT ENGINE FROM information_schema.TABLES WHERE '
                    .. 'TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '
                    .. '?'
                ),
                { name }
            )
            D.assert(type(engine) == 'string' and engine:upper() == 'INNODB', 'license_unavailable')
        end

        D.assert(not D.hasLicense(player, payload.license), 'already_owned')

        local unique = MySQL.scalar.await([[SELECT COUNT(*) FROM (
            SELECT INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_NAME = 'user_licenses' AND NON_UNIQUE = 0 GROUP BY INDEX_NAME
            HAVING COUNT(*) = 2 AND SUM(SUB_PART IS NOT NULL) = 0
            AND GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) IN ('owner,type', 'type,owner')
        ) AS unique_license_keys]])
        D.assert(tonumber(unique) and tonumber(unique) > 0, 'license_unavailable')
        D.assert(
            MySQL.scalar.await('SELECT 1 FROM licenses WHERE type = ?', { payload.license }),
            'license_unavailable'
        )
    elseif order.kind == 'resale' or order.kind == 'return' then
        local row = MySQL.single.await(
            'SELECT * FROM owned_vehicles WHERE owner = ? AND plate = ?',
            { order.owner, order.plate }
        )
        D.assert(
            row and (row.job == nil or row.job == '') and row.vehicle == payload.originalVehicle,
            'vehicle_changed'
        )

        local rental = MySQL.single.await(
            'SELECT * FROM rented_vehicles WHERE owner = ? AND plate = ?',
            { order.owner, order.plate }
        )

        if order.kind == 'return' then
            D.assert(rental and rental.shop_id == shop.id, 'not_rented')
        else
            D.assert(
                not rental
                    and not MySQL.scalar.await(
                        'SELECT 1 FROM rented_vehicles WHERE plate = ?',
                        { order.plate }
                    ),
                'rented_vehicle'
            )
        end

        local entity = D.entity(player.source, order.plate)

        if tonumber(row.stored) ~= 1 then
            D.assert(
                entity and GetPedInVehicleSeat(entity, -1) == GetPlayerPed(player.source),
                'vehicle_required'
            )

            local props = json.decode(row.vehicle)

            D.assert(
                GetEntityModel(entity) % 4294967296 == D.modelHash(props.model),
                'vehicle_changed'
            )
        else
            D.assert(not entity, 'vehicle_active')
        end

        D.assert(row.pound == nil or row.pound == '', 'vehicle_impounded')
    end

    D.assert(
        D.canAccess(player, shop) and D.location(player.source, shop, order.kind),
        'purchase_invalidated'
    )

    if order.kind == 'purchase' or order.kind == 'rent' or order.kind == 'stock' then
        local finalOffer = D.offer(shop, order.model, player)

        D.assert(
            finalOffer
                and finalOffer.price == payload.price
                and finalOffer.type == payload.vehicleType,
            'quote_changed'
        )
        payload.props = finalOffer.props
        D.assert(
            D.canAccess(player, shop) and D.location(player.source, shop, order.kind),
            'purchase_invalidated'
        )
    end

    if payload.seller then
        local seller = ESX.GetPlayerFromId(payload.seller.source)

        D.assert(
            D.current(seller)
                and seller.getIdentifier() == payload.seller.owner
                and D.employee(seller, shop)
                and closeTo(player, seller),
            'seller_unavailable'
        )
    end

    if order.kind == 'stock' or order.kind == 'provider' then
        D.assert(D.employee(player, shop), 'employee_required')
    end

    if order.kind == 'deposit' or order.kind == 'withdraw' then
        D.assert(D.employee(player, shop, true), 'boss_required')
    end
end

function D.quote(source, request)
    D.assert(type(request) == 'table' and quoteLimiter:consume(source), 'busy')

    local kind = request.kind or 'purchase'

    D.assert(
        D.contains({
            'purchase',
            'stock',
            'provider',
            'rent',
            'resale',
            'return',
            'license',
            'deposit',
            'withdraw',
        }, kind),
        'invalid_action'
    )

    local actor, shop = D.playerShop(
        source,
        request.shopId,
        kind,
        kind == 'stock' or kind == 'provider' or kind == 'rent'
    )

    local buyer, payload, amount, model, plate = actor, {}, 0

    if kind == 'purchase' and shop.mode == 'managed' or kind == 'rent' then
        D.assert(D.employee(actor, shop), 'employee_required')
        buyer = ESX.GetPlayerFromId(tonumber(request.targetId))
        D.assert(D.current(buyer) and closeTo(actor, buyer), 'buyer_unavailable')
        payload.seller = { source = source, owner = actor.getIdentifier(), name = actor.getName() }
    end

    local requestKey = ''

    if
        type(request.reference) == 'string'
        and #request.reference > 0
        and #request.reference <= 80
    then
        requestKey = D.assert(
            MySQL.scalar.await(
                'SELECT SHA2(?, 256)',
                { json.encode({ buyer.getIdentifier(), shop.id, kind, request.reference }) }
            ),
            'quote_unavailable'
        )

        local previous = MySQL.single.await(
            'SELECT * FROM esx_vehicle_orders WHERE request_key = ? AND owner = ?',
            { requestKey, buyer.getIdentifier() }
        )

        if previous then
            D.assert(previous.model == (D.normalizeModel(request.model) or ''), 'request_conflict')
            return {
                id = previous.id,
                kind = previous.kind,
                model = previous.model,
                name = previous.model,
                amount = previous.amount,
                plate = previous.plate,
                paymentMethods = D.orderMethods(shop, previous.kind),
            }
        end
    end

    D.assert(
        not MySQL.scalar.await(
            "SELECT id FROM esx_vehicle_orders WHERE owner = ? AND state = 'processing' LIMIT 1",
            { buyer.getIdentifier() }
        ),
        'order_pending'
    )

    if kind == 'purchase' or kind == 'rent' or kind == 'stock' then
        model = D.normalizeModel(request.model)

        local offer = D.assert(D.offer(shop, model, buyer), 'invalid_vehicle')

        payload.price, payload.vehicleType, payload.props = offer.price, offer.type, offer.props
        amount = offer.price

        if kind ~= 'stock' then
            D.validBuyer(buyer, shop, offer)
        end

        if shop.stockMode == 'limited' and kind ~= 'stock' then
            local row = MySQL.single.await(
                (
                    'SELECT id, price FROM cardealer_vehicles WHERE shop_id = '
                    .. '? AND vehicle = ? AND available = 1 ORDER BY id LIMIT '
                    .. '1'
                ),
                { shop.id, model }
            )
            D.assert(row, 'out_of_stock')
            payload.stockId, payload.stockPrice = row.id, row.price
        end

        if kind == 'rent' then
            payload.rentPrice = math.max(
                shop.rentals.minimum or 1,
                ESX.Math.Round((payload.stockPrice or amount) * (shop.rentals.multiplier or 0.05))
            )
            amount = 0 -- Existing rentals bill daily, without an additional initial charge.
        end

        if kind ~= 'stock' then
            plate = D.assert(D.plate(), 'plate_unavailable')
        end
    elseif kind == 'provider' then
        local row = MySQL.single.await(
            (
                'SELECT id, vehicle, price FROM cardealer_vehicles WHERE '
                .. 'shop_id = ? AND id = ? AND available = '
                .. '1'
            ),
            { shop.id, tonumber(request.stockId) or 0 }
        )
        D.assert(row, 'out_of_stock')
        model, payload.stockId, payload.stockPrice = row.vehicle, row.id, row.price
        amount = ESX.Math.Round(row.price * (shop.providerReturnPercentage or 75) / 100)
    elseif kind == 'license' then
        payload.license = shop.license
        amount = D.assert(D.money(shop.licensePrice), 'license_unavailable')
    elseif kind == 'deposit' or kind == 'withdraw' then
        D.assert(D.employee(actor, shop, true), 'boss_required')
        amount = D.assert(D.money(request.amount), 'invalid_price')
    else
        plate = xLib.vehiclePlate.normalize(request.plate)

        local row = plate
            and MySQL.single.await(
                'SELECT * FROM owned_vehicles WHERE owner = ? AND plate = ?',
                { buyer.getIdentifier(), plate }
            )
        D.assert(row, 'not_owned')

        local ok, props = pcall(json.decode, row.vehicle or '')

        D.assert(ok and type(props) == 'table' and D.modelHash(props.model), 'invalid_vehicle')

        for candidate, vehicle in pairs(D.catalog) do
            if joaat(candidate) % 4294967296 == D.modelHash(props.model) then
                model = candidate
                break
            end
        end

        payload.originalVehicle = row.vehicle

        if kind == 'return' then
            local rental = MySQL.single.await(
                'SELECT * FROM rented_vehicles WHERE owner = ? AND plate = ? AND shop_id = ?',
                { buyer.getIdentifier(), plate, shop.id }
            )
            D.assert(rental, 'not_rented')
            payload.stockPrice = rental.base_price
            model = rental.vehicle
            D.assert(joaat(model) % 4294967296 == D.modelHash(props.model), 'vehicle_changed')
        else
            D.assert(model, 'invalid_vehicle')
            D.assert(shop.resale and shop.resale.enabled, 'resale_disabled')

            local offer = D.assert(D.offer(shop, model, buyer), 'invalid_vehicle')

            amount = ESX.Math.Round(offer.price * (shop.resale.percentage or 50) / 100)
            payload.stockPrice = amount
        end
    end

    D.assert(D.money(amount, true), 'invalid_price')
    payload.buyerName = buyer.getName()

    local id = D.uuid()
    local order = {
        id = id,
        shop_id = shop.id,
        kind = kind,
        model = model,
        plate = plate,
        amount = amount,
        owner = buyer.getIdentifier(),
    }
    D.validateOrder(buyer, shop, order, payload)

    local reserved = false

    for attempt = 1, 5 do
        local ok, inserted = pcall(
            MySQL.insert.await,
            (
                'INSERT INTO esx_vehicle_orders (id, owner, shop_id, kind, '
                .. 'model, plate, reserved_plate, request_key, amount, payload, '
                .. 'state, created_at, expires_at)\n            VALUES (?, ?, ?, '
                .. "?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), ?, ?, 'quoted', "
                .. '?, '
                .. '?)'
            ),
            {
                id,
                order.owner,
                shop.id,
                kind,
                model or '',
                plate or '',
                (kind == 'purchase' or kind == 'rent') and plate or '',
                requestKey,
                amount,
                json.encode(payload),
                os.time(),
                os.time() + 120,
            }
        )

        if ok and inserted then
            reserved = true
            break
        end

        if kind ~= 'purchase' and kind ~= 'rent' then
            break
        end

        plate = D.assert(D.plate(), 'plate_unavailable')
        order.plate = plate
    end

    D.assert(reserved, 'quote_unavailable')

    local result = {
        id = id,
        kind = kind,
        model = model,
        amount = amount,
        plate = plate,
        rentPrice = payload.rentPrice,
        name = model and (D.catalog[model] and D.catalog[model].name or model) or shop.license,
        paymentMethods = D.orderMethods(shop, kind),
    }

    if buyer.source ~= source then
        TriggerClientEvent('esx_vehicleshop:offer', buyer.source, shop.id, result)
        return { offered = true, target = buyer.getName() }
    end

    return result
end

function D.execute(source, orderId, account)
    D.assert(type(orderId) == 'string' and #orderId <= 36, 'invalid_order')

    local player = D.assert(ESX.GetPlayerFromId(source), 'player')
    local result, failure = D.lock('buyer:' .. player.getIdentifier(), function()
        local order = MySQL.single.await(
            'SELECT * FROM esx_vehicle_orders WHERE id = ? AND owner = ?',
            { orderId, player.getIdentifier() }
        )
        D.assert(order, 'invalid_order')

        local movement = MySQL.single.await(
            'SELECT * FROM esx_vehicle_movements WHERE order_id = ?',
            { orderId }
        )

        if movement then
            return D.orderResult(order, movement, true)
        end

        D.assert(order.state == 'quoted' and order.expires_at >= os.time(), 'order_expired')

        local payload, shop =
            json.decode(order.payload), D.assert(D.shops[order.shop_id], 'invalid_shop')

        local function perform()
            D.validateOrder(player, shop, order, payload)

            if order.kind == 'deposit' or order.kind == 'withdraw' then
                D.assert(account == 'bank', 'invalid_account')
            elseif order.kind == 'stock' then
                D.assert(account == 'society', 'invalid_account')
            elseif order.kind == 'return' or order.kind == 'provider' or order.kind == 'resale' then
                account = order.kind == 'provider' and 'society' or 'money'
            else
                D.assert(D.contains(shop.paymentMethods, account), 'invalid_account')
            end

            if account == 'society' and order.kind ~= 'provider' then
                D.assert(
                    (order.kind == 'stock' and D.employee(player, shop))
                        or (
                            shop.ownershipJob
                            and player.job.name == shop.ownershipJob
                            and player.job.grade >= (shop.societyMinGrade or 0)
                        ),
                    'not_allowed'
                )
            end

            local changed = MySQL.update.await(
                (
                    "UPDATE esx_vehicle_orders SET state = 'processing', "
                    .. 'payment = ? WHERE id = ? AND owner = ? AND state = '
                    .. "'quoted' AND expires_at >= "
                    .. '?'
                ),
                { account, order.id, order.owner, os.time() }
            )
            D.assert(changed == 1, 'busy')

            local executed, problem = D.settle(player, shop, order, payload, account)

            D.assert(executed, problem or 'transaction_failed')

            local value = D.orderResult(order, executed, false)

            if order.kind == 'purchase' or order.kind == 'rent' then
                local ok, problem = pcall(D.deliver, player, shop, order, payload)

                if not ok then
                    print(
                        '[esx_vehicleshop] Delivery deferred for '
                            .. order.id
                            .. ': '
                            .. tostring(problem)
                    )
                end
            elseif order.kind == 'return' or order.kind == 'resale' then
                local ok, cleaned = pcall(D.cleanupTrade, order)

                value.cleanupPending = not ok or not cleaned
            end

            return value
        end

        local value, err = D.lock(
            'stock:' .. shop.id .. ':' .. (order.model or order.kind),
            function()
                if order.kind == 'return' or order.kind == 'resale' then
                    local locked, problem =
                        exports['esx_garage']:withVehicleOperation(order.plate, perform)
                    D.assert(locked, problem or 'busy')
                    return locked
                end

                return perform()
            end
        )
        D.assert(value, err)
        return value
    end)

    D.assert(result, failure)
    return result
end

function D.orderResult(order, movement, replay)
    return {
        id = order.id,
        complete = true,
        replay = replay == true,
        kind = order.kind,
        plate = movement.plate,
        amount = movement.amount,
        shopId = order.shop_id,
    }
end

function D.deliver(player, shop, order, payload)
    if not shop.delivery or shop.delivery.mode ~= 'spawn' or not shop.delivery.coords then
        return
    end

    local claimed = MySQL.update.await(
        (
            "UPDATE esx_vehicle_orders SET delivery_state = 'attempted' "
            .. "WHERE id = ? AND state = 'complete' AND delivery_state = "
            .. "'pending'"
        ),
        { order.id }
    )

    if claimed ~= 1 or not D.current(player) then
        return
    end

    local ok, delivered = pcall(function()
        local anchor = D.near(player.source, shop.coords, 13) and shop.coords
            or shop.preview
            or shop.managementPoint
        return exports['esx_garage']:deliverPurchasedVehicle(
            player.source,
            order.plate,
            D.point(anchor),
            D.point(shop.delivery.coords)
        )
    end)

    if ok and delivered and delivered.success then
        TriggerClientEvent('esx_vehicleshop:delivery', player.source, delivered.data.netId)
    end -- Failed or interrupted delivery leaves an owned vehicle recoverable through esx_garage.
end
