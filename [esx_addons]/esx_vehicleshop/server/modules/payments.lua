-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
local D = VehicleShop

local function append(target, values)
    for _, value in ipairs(values) do
        target[#target + 1] = value
    end
end

local function societyAccount(name)
    if not name or GetResourceState('esx_addonaccount') ~= 'started' then
        return nil
    end

    local account

    TriggerEvent('esx_addonaccount:getSharedAccount', name, function(value)
        account = value
    end)

    return account and account.withPersistence and account or nil
end

-- A locking barrier waits for a delayed original transaction. Absence from a nonlocking
-- SELECT alone is not proof of rollback: that transaction might still be running.
function D.reconcileOrder(id)
    while true do
        local ok, result = pcall(function()
            local committed = MySQL.transaction.await({
                {
                    query = 'SELECT id FROM esx_vehicle_orders WHERE id = ? FOR UPDATE',
                    values = { id },
                },
                {
                    query = (
                        'UPDATE esx_vehicle_orders SET state = CASE WHEN '
                        .. 'EXISTS\n                    (SELECT 1 FROM '
                        .. 'esx_vehicle_movements WHERE order_id = ?) THEN '
                        .. "'complete' ELSE 'failed' END\n                    "
                        .. 'WHERE id = ? AND state = '
                        .. "'processing'"
                    ),
                    values = { id, id },
                },
            })
            assert(committed, 'Order reconciliation not confirmed')
            return MySQL.single.await(
                'SELECT * FROM esx_vehicle_movements WHERE order_id = ?',
                { id }
            ) or false
        end)

        if ok then
            return result
        end

        print(
            ('[esx_vehicleshop] Waiting to reconcile economic order %s: %s'):format(
                id,
                tostring(result)
            )
        )
        Wait(5000)
    end
end

local function plan(
    order,
    payload,
    shop,
    accountName,
    rawAccounts,
    rawSociety,
    newAccounts,
    newSociety
)
    local statements, conditions, params =
        {}, { 'o.id = ?', 'o.owner = ?', "o.state = 'processing'" }, { order.id, order.owner }

    local function sql(query, values)
        statements[#statements + 1] = { query = query, values = values or {} }
    end

    sql('SELECT id FROM esx_vehicle_orders WHERE id = ? FOR UPDATE', { order.id })

    if rawSociety ~= nil then
        sql(
            'SELECT id FROM addon_account_data WHERE account_name = ? AND owner IS NULL FOR UPDATE',
            { shop.societyAccount }
        )
        conditions[#conditions + 1] = (
            'EXISTS (SELECT 1 FROM addon_account_data a WHERE '
            .. 'a.account_name = ? AND a.owner IS NULL AND a.money = '
            .. '?)'
        )
        append(params, { shop.societyAccount, rawSociety })
    end

    sql('SELECT identifier FROM users WHERE identifier = ? FOR UPDATE', { order.owner })
    conditions[#conditions + 1] =
        'EXISTS (SELECT 1 FROM users u WHERE u.identifier = ? AND u.accounts = ?)'
    append(params, { order.owner, rawAccounts })

    if payload.stockId then
        sql('SELECT id FROM cardealer_vehicles WHERE id = ? FOR UPDATE', { payload.stockId })
        conditions[#conditions + 1] = (
            'EXISTS (SELECT 1 FROM cardealer_vehicles s WHERE s.id = ? AND '
            .. 's.shop_id = ? AND s.vehicle = ? AND s.price = ? AND '
            .. 's.available = '
            .. '1)'
        )
        append(params, { payload.stockId, shop.id, order.model, payload.stockPrice })
    end

    if order.kind == 'return' or order.kind == 'resale' then
        sql('SELECT plate FROM owned_vehicles WHERE plate = ? FOR UPDATE', { order.plate })
        conditions[#conditions + 1] = (
            'EXISTS (SELECT 1 FROM owned_vehicles v WHERE v.owner = ? AND '
            .. 'v.plate = ? AND v.vehicle = ? AND (v.job IS NULL OR v.job = '
            .. "''))"
        )
        append(params, { order.owner, order.plate, payload.originalVehicle })

        if order.kind == 'return' then
            sql('SELECT plate FROM rented_vehicles WHERE plate = ? FOR UPDATE', { order.plate })
            conditions[#conditions + 1] = (
                'EXISTS (SELECT 1 FROM rented_vehicles r WHERE r.owner = ? '
                .. 'AND r.plate = ? AND r.shop_id = '
                .. '?)'
            )
            append(params, { order.owner, order.plate, shop.id })
        else
            conditions[#conditions + 1] =
                'NOT EXISTS (SELECT 1 FROM rented_vehicles r WHERE r.plate = ?)'
            params[#params + 1] = order.plate
        end
    elseif order.kind == 'license' then
        sql(
            'SELECT id FROM user_licenses WHERE owner = ? AND type = ? FOR UPDATE',
            { order.owner, payload.license }
        )
        conditions[#conditions + 1] =
            'NOT EXISTS (SELECT 1 FROM user_licenses l WHERE l.owner = ? AND l.type = ?)'
        append(params, { order.owner, payload.license })
    end

    local movementParams = { order.amount, accountName, os.time() }

    append(movementParams, params)
    sql(
        (
            (
                'INSERT INTO esx_vehicle_movements (order_id, owner, shop_id, '
                .. 'kind, plate, amount, payment, created_at)\n        SELECT o.id, '
                .. 'o.owner, o.shop_id, o.kind, o.plate, ?, ?, ? FROM '
                .. 'esx_vehicle_orders o WHERE '
                .. '%s'
            )
        ):format(table.concat(conditions, ' AND ')),
        movementParams
    )

    local exists = 'EXISTS (SELECT 1 FROM esx_vehicle_movements WHERE order_id = ?)'

    if order.kind == 'purchase' or order.kind == 'rent' then
        local props = D.safeProps(payload.props, order.model, order.plate)

        sql(
            ([[INSERT INTO owned_vehicles (owner, plate, vehicle, type, job, stored, parking, pound)
            SELECT ?, ?, ?, ?, NULLIF(?, ''), 1, NULLIF(?, ''), NULL WHERE %s]]):format(
                exists
            ),
            {
                order.owner,
                order.plate,
                json.encode(props),
                payload.vehicleType,
                shop.ownershipJob or '',
                shop.delivery.garage or '',
                order.id,
            }
        )

        if order.kind == 'rent' then
            sql(
                (
                    (
                        'INSERT INTO rented_vehicles (vehicle, plate, player_name, '
                        .. 'base_price, rent_price, owner, shop_id, '
                        .. 'society_account)\n                SELECT ?, ?, ?, ?, ?, '
                        .. '?, ?, ? WHERE '
                        .. '%s'
                    )
                ):format(exists),
                {
                    order.model,
                    order.plate,
                    payload.buyerName,
                    payload.stockPrice or payload.price,
                    payload.rentPrice,
                    order.owner,
                    shop.id,
                    shop.societyAccount,
                    order.id,
                }
            )
        else
            sql(
                ([[INSERT INTO vehicle_sold (client, model, plate, soldby, date, shop_id)
                SELECT ?, ?, ?, ?, CURRENT_TIMESTAMP, ? WHERE %s]]):format(exists),
                {
                    payload.buyerName,
                    order.model,
                    order.plate,
                    payload.seller and payload.seller.name or shop.label,
                    shop.id,
                    order.id,
                }
            )
        end

        if payload.stockId then
            sql(
                ('DELETE FROM cardealer_vehicles WHERE id = ? AND %s'):format(exists),
                { payload.stockId, order.id }
            )
        end
    elseif order.kind == 'stock' then
        sql(
            ([[INSERT INTO cardealer_vehicles (vehicle, price, shop_id, source_order, available)
            SELECT ?, ?, ?, ?, 1 WHERE %s]]):format(exists),
            { order.model, order.amount, shop.id, order.id, order.id }
        )
    elseif order.kind == 'provider' then
        sql(
            ('DELETE FROM cardealer_vehicles WHERE id = ? AND shop_id = ? AND %s'):format(exists),
            { payload.stockId, shop.id, order.id }
        )
    elseif order.kind == 'resale' or order.kind == 'return' then
        if order.kind == 'return' or shop.stockMode == 'limited' then
            sql(
                (
                    (
                        'INSERT INTO cardealer_vehicles (vehicle, price, shop_id, '
                        .. 'source_order, available, return_plate)\n                '
                        .. 'SELECT ?, ?, ?, ?, 0, ? WHERE '
                        .. '%s'
                    )
                ):format(exists),
                { order.model, payload.stockPrice, shop.id, order.id, order.plate, order.id }
            )
        end

        sql(
            ('DELETE FROM owned_vehicles WHERE owner = ? AND plate = ? AND %s'):format(exists),
            { order.owner, order.plate, order.id }
        )

        if order.kind == 'return' then
            sql(
                (
                    (
                        'DELETE FROM rented_vehicles WHERE owner = ? AND plate = ? '
                        .. 'AND shop_id = ? AND '
                        .. '%s'
                    )
                ):format(exists),
                { order.owner, order.plate, shop.id, order.id }
            )
        end
    elseif order.kind == 'license' then
        sql(
            ('INSERT INTO user_licenses (type, owner) SELECT ?, ? WHERE %s'):format(exists),
            { payload.license, order.owner, order.id }
        )
    end

    if newAccounts then
        sql(
            ('UPDATE users SET accounts = ? WHERE identifier = ? AND %s'):format(exists),
            { newAccounts, order.owner, order.id }
        )
    end

    if newSociety then
        sql(
            (
                (
                    'UPDATE addon_account_data SET money = ? WHERE account_name = '
                    .. '? AND owner IS NULL AND '
                    .. '%s'
                )
            ):format(exists),
            { newSociety, shop.societyAccount, order.id }
        )
    end

    sql(
        ("UPDATE esx_vehicle_orders SET state = 'complete' WHERE id = ? AND %s"):format(exists),
        { order.id, order.id }
    )
    return statements
end

function D.settle(player, shop, order, payload, accountName)
    local kind, amount = order.kind, D.assert(D.money(order.amount, true), 'invalid_price')
    local playerDelta, companyDelta = 0, 0

    if kind == 'deposit' then
        playerDelta, companyDelta = -amount, amount
    elseif kind == 'withdraw' then
        playerDelta, companyDelta = amount, -amount
    elseif kind == 'stock' then
        companyDelta = -amount
    elseif kind == 'provider' then
        companyDelta = amount
    elseif kind == 'resale' then
        playerDelta = amount

        if shop.mode == 'managed' then
            companyDelta = -amount
        end
    elseif kind ~= 'return' and kind ~= 'rent' then
        if accountName == 'society' then
            companyDelta = -amount
        else
            playerDelta = -amount
        end

        if kind == 'purchase' and shop.mode == 'managed' then
            companyDelta = companyDelta + amount
        end
    end

    local company = companyDelta ~= 0 and societyAccount(shop.societyAccount) or nil

    local function failBefore(reason)
        MySQL.update.await(
            "UPDATE esx_vehicle_orders SET state = 'failed' WHERE id = ? AND state = 'processing'",
            { order.id }
        )
        return nil, reason
    end

    if companyDelta ~= 0 and not company then
        return failBefore('society_unavailable')
    end

    if company then
        local engine = MySQL.scalar.await(
            (
                'SELECT ENGINE FROM information_schema.TABLES WHERE '
                .. 'TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '
                .. '?'
            ),
            { 'addon_account_data' }
        )

        if type(engine) ~= 'string' or engine:upper() ~= 'INNODB' then
            return failBefore('society_unavailable')
        end
    end

    local outcome, failure

    local function run()
        return exports.es_extended:WithPlayerPersistence(order.owner, function(current)
            if
                not D.current(player)
                or not D.current(current)
                or current.source ~= player.source
                or current.getIdentifier() ~= order.owner
            then
                failure = 'session_closing'
                failBefore(failure)
                return false
            end

            local reservedPlayer, reservedCompany, attempted = false, false, false
            local ok, result = pcall(function()
                local rawAccounts = D.assert(
                    MySQL.scalar.await(
                        'SELECT accounts FROM users WHERE identifier = ?',
                        { order.owner }
                    ),
                    'player'
                )

                local rawSociety = company
                        and MySQL.scalar.await(
                            (
                                'SELECT money FROM addon_account_data WHERE '
                                .. 'account_name = ? AND owner IS '
                                .. 'NULL'
                            ),
                            { shop.societyAccount }
                        )
                    or nil

                if company then
                    D.assert(type(rawSociety) == 'number', 'society_unavailable')
                end

                local accounts = player.getAccounts(true)
                local playerAccount = accountName == 'society' and 'money' or accountName

                D.assert(playerAccount == 'money' or playerAccount == 'bank', 'invalid_account')

                local balance = accounts[playerAccount]

                D.assert(
                    type(balance) == 'number'
                        and balance + playerDelta >= 0
                        and balance + playerDelta <= 9007199254740991,
                    'insufficient_funds'
                )

                if company then
                    D.assert(
                        company.money + companyDelta >= 0
                            and company.money + companyDelta <= 2147483647,
                        'insufficient_funds'
                    )
                end

                D.validateOrder(player, shop, order, payload)

                if playerDelta < 0 then
                    local charged, reason = PaymentGateway.Charge(
                        player,
                        playerAccount,
                        -playerDelta,
                        'Vehicle dealership ' .. order.id
                    )
                    D.assert(charged, reason or 'insufficient_funds')
                    reservedPlayer = true
                end

                if companyDelta < 0 then
                    D.assert(company.removeMoney(-companyDelta) == true, 'insufficient_funds')
                    reservedCompany = true
                end

                accounts = player.getAccounts(true)

                if playerDelta > 0 then
                    accounts[playerAccount] = accounts[playerAccount] + playerDelta
                end

                local encoded = playerDelta ~= 0 and json.encode(accounts) or nil
                local companyAfter = company
                        and (company.money + (companyDelta > 0 and companyDelta or 0))
                    or nil
                local statements = plan(
                    order,
                    payload,
                    shop,
                    accountName,
                    rawAccounts,
                    rawSociety,
                    encoded,
                    companyAfter
                )
                attempted = true

                local committed, confirmed = pcall(MySQL.transaction.await, statements)

                if not committed or not confirmed then
                    print('[esx_vehicleshop] Reconciling order ' .. order.id)
                end

                local movement = D.reconcileOrder(order.id)

                if not movement then
                    failure = 'transaction_failed'
                    return false
                end

                if playerDelta > 0 then
                    D.assert(
                        player.addAccountMoney(
                            playerAccount,
                            playerDelta,
                            'Vehicle dealership ' .. order.id
                        ) == true,
                        'credit_unconfirmed'
                    )
                end

                if companyDelta > 0 then
                    D.assert(company.addMoney(companyDelta) == true, 'credit_unconfirmed')
                end

                outcome = movement
                return true
            end)

            if not ok then
                failure = type(result) == 'table' and result.shopError or 'transaction_failed'

                if attempted then
                    local movement = D.reconcileOrder(order.id)
                    -- Never refund a committed operation or allow an old cache to overwrite its
                    -- balances.
                    if movement then
                        error('Committed order requires cache reconciliation: ' .. order.id)
                    end
                end
            end

            if outcome then
                return true
            end

            if reservedPlayer then
                D.assert(
                    PaymentGateway.Refund(
                        player,
                        accountName,
                        -playerDelta,
                        'Vehicle dealership refund ' .. order.id
                    ),
                    'refund_unconfirmed'
                )
            end

            if reservedCompany then
                D.assert(company.addMoney(-companyDelta) == true, 'refund_unconfirmed')
            end

            MySQL.update.await(
                (
                    "UPDATE esx_vehicle_orders SET state = 'failed' WHERE id "
                    .. '= ? AND state = '
                    .. "'processing'"
                ),
                { order.id }
            )
            return false
        end, true)
    end

    if company then
        company.withPersistence(function()
            return run(), 0
        end)
    else
        run()
    end

    return outcome, failure
end
