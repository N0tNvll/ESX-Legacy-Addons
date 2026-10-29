-- SPDX-License-Identifier: GPL-3.0-only
-- A receipt commits the rent, both balances and any eviction in one transaction.
local D = VehicleShop
local ready, running = false, false

MySQL.ready(function()
    local ok, problem = pcall(function()
        ESXCatalog.awaitReady()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS vehicle_rental_payments (
            plate VARCHAR(12) NOT NULL, billing_date DATE NOT NULL,
            owner VARCHAR(60) NOT NULL, amount INT NOT NULL,
            operation_id VARCHAR(100) NOT NULL, state VARCHAR(16) NOT NULL,
            PRIMARY KEY (plate, billing_date), UNIQUE KEY (operation_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

        for _, name in ipairs({
            'users',
            'rented_vehicles',
            'owned_vehicles',
            'cardealer_vehicles',
            'addon_account_data',
            'vehicle_rental_payments',
        }) do
            local engine = MySQL.scalar.await(
                (
                    'SELECT ENGINE FROM information_schema.TABLES WHERE '
                    .. 'TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '
                    .. '?'
                ),
                { name }
            )
            assert(engine and engine:upper() == 'INNODB', name .. ' must use InnoDB')
        end
    end)

    ready = ok
    D.rentalPaymentsReady = ok

    if not ok then
        print('[esx_vehicleshop] Rental payments disabled: ' .. tostring(problem))
    end
end)

local function receipt(rental, day, token)
    while true do
        local ok, row = pcall(function()
            -- Wait for an in-flight debit. If it never started, a cancellation receipt
            -- prevents that delayed transaction from charging after a refund.
            assert(
                MySQL.transaction.await({
                    {
                        query = 'SELECT identifier FROM users WHERE identifier = ? FOR UPDATE',
                        values = { rental.owner },
                    },
                    {
                        query = (
                            'INSERT IGNORE INTO vehicle_rental_payments '
                            .. '(plate, billing_date, owner, amount, '
                            .. 'operation_id, state)\n                    VALUES '
                            .. '(?, ?, ?, 0, ?, '
                            .. "'cancelled')"
                        ),
                        values = { rental.plate, day, rental.owner, token .. ':cancel' },
                    },
                }),
                'Rental reconciliation not confirmed'
            )
            return MySQL.single.await(
                (
                    'SELECT operation_id, amount, state FROM '
                    .. 'vehicle_rental_payments WHERE plate = ? AND billing_date '
                    .. '= '
                    .. '?'
                ),
                { rental.plate, day }
            ) or false
        end)

        if ok then
            return row and row.operation_id == token and row or nil
        end

        print('[esx_vehicleshop] Waiting to reconcile rental payment ' .. token)
        Wait(5000)
    end
end

local function charge(rental, day, society)
    return society.withPersistence(function(societyBalance)
        local delta = 0
        local success = exports.es_extended:WithPlayerPersistence(rental.owner, function(player)
            if
                MySQL.scalar.await(
                    'SELECT 1 FROM vehicle_rental_payments WHERE plate = ? AND billing_date = ?',
                    { rental.plate, day }
                )
            then
                return false
            end

            local raw = MySQL.scalar.await(
                'SELECT accounts FROM users WHERE identifier = ?',
                { rental.owner }
            )

            local rawSociety = MySQL.scalar.await(
                'SELECT money FROM addon_account_data WHERE account_name = ? AND owner IS NULL',
                { rental.society_account }
            )

            local ok, accounts = pcall(json.decode, raw or '')
            local price = D.money(rental.rent_price)

            if not ok or type(accounts) ~= 'table' or not price or type(rawSociety) ~= 'number' then
                print('[esx_vehicleshop] Invalid rental/user data: ' .. rental.plate)
                return false
            end

            if player then
                accounts = player.getAccounts(true)
            end

            local bank = accounts.bank

            if type(bank) ~= 'number' or bank ~= bank or bank < 0 or bank > 9007199254740991 then
                return false
            end

            local amount = bank >= price and price or 0

            if societyBalance + amount > 2147483647 then
                return false
            end

            local state, token = amount > 0 and 'paid' or 'evicted', D.uuid()

            if
                player
                and amount > 0
                and player.removeAccountMoney('bank', amount, 'Vehicle Rental') ~= true
            then
                return false
            end

            if player then
                accounts = player.getAccounts(true)
            else
                accounts.bank = bank - amount
            end

            local encoded = json.encode(accounts)
            local committed, problem = pcall(MySQL.transaction.await, {
                {
                    query = 'SELECT identifier FROM users WHERE identifier = ? FOR UPDATE',
                    values = { rental.owner },
                },
                {
                    query = (
                        'SELECT id FROM addon_account_data WHERE account_name '
                        .. '= ? AND owner IS NULL FOR '
                        .. 'UPDATE'
                    ),
                    values = { rental.society_account },
                },
                {
                    query = 'SELECT plate FROM rented_vehicles WHERE plate = ? FOR UPDATE',
                    values = { rental.plate },
                },
                {
                    query = (
                        'INSERT INTO vehicle_rental_payments (plate, '
                        .. 'billing_date, owner, amount, operation_id, state)\n   '
                        .. '                 SELECT r.plate, ?, r.owner, ?, ?, ? '
                        .. 'FROM rented_vehicles r\n                    JOIN '
                        .. 'users u ON u.identifier = r.owner\n                   '
                        .. ' JOIN addon_account_data a ON a.account_name = '
                        .. 'r.society_account AND a.owner IS NULL\n               '
                        .. '     WHERE r.plate = ? AND r.owner = ? AND '
                        .. 'r.rent_price = ? AND r.shop_id = ?\n                  '
                        .. '  AND r.society_account = ? AND r.vehicle = ? AND '
                        .. 'r.base_price = ? AND u.accounts = ? AND a.money = '
                        .. '?'
                    ),
                    values = {
                        day,
                        amount,
                        token,
                        state,
                        rental.plate,
                        rental.owner,
                        price,
                        rental.shop_id,
                        rental.society_account,
                        rental.vehicle,
                        rental.base_price,
                        raw,
                        rawSociety,
                    },
                },
                {
                    query = (
                        'UPDATE users SET accounts = ? WHERE identifier = ? '
                        .. 'AND EXISTS\n                    (SELECT 1 FROM '
                        .. 'vehicle_rental_payments WHERE operation_id = ? AND '
                        .. 'state = '
                        .. "'paid')"
                    ),
                    values = { encoded, rental.owner, token },
                },
                {
                    query = (
                        'UPDATE addon_account_data SET money = ? WHERE '
                        .. 'account_name = ? AND owner IS NULL AND EXISTS\n       '
                        .. '             (SELECT 1 FROM vehicle_rental_payments '
                        .. 'WHERE operation_id = ? AND state = '
                        .. "'paid')"
                    ),
                    values = { societyBalance + amount, rental.society_account, token },
                },
                {
                    query = (
                        'INSERT INTO cardealer_vehicles (vehicle, price, '
                        .. 'shop_id, source_order, available, return_plate)\n     '
                        .. '               SELECT r.vehicle, r.base_price, '
                        .. 'r.shop_id, ?, 0, r.plate FROM rented_vehicles r\n     '
                        .. '               WHERE r.plate = ? AND r.owner = ? AND '
                        .. 'EXISTS\n                    (SELECT 1 FROM '
                        .. 'vehicle_rental_payments WHERE operation_id = ? AND '
                        .. "state = 'evicted')"
                    ),
                    values = { token, rental.plate, rental.owner, token },
                },
                {
                    query = (
                        'DELETE FROM owned_vehicles WHERE owner = ? AND plate '
                        .. '= ? AND EXISTS\n                    (SELECT 1 FROM '
                        .. 'vehicle_rental_payments WHERE operation_id = ? AND '
                        .. "state = 'evicted')"
                    ),
                    values = { rental.owner, rental.plate, token },
                },
                {
                    query = (
                        'DELETE FROM rented_vehicles WHERE owner = ? AND plate '
                        .. '= ? AND shop_id = ? AND EXISTS\n                    '
                        .. '(SELECT 1 FROM vehicle_rental_payments WHERE '
                        .. 'operation_id = ? AND state = '
                        .. "'evicted')"
                    ),
                    values = { rental.owner, rental.plate, rental.shop_id, token },
                },
            })

            if not committed or problem ~= true then
                print('[esx_vehicleshop] Rental transaction unconfirmed: ' .. tostring(problem))
            end

            local paid = receipt(rental, day, token)

            if not paid then
                if player and amount > 0 then
                    assert(
                        player.addAccountMoney('bank', amount, 'Vehicle Rental Refund') == true,
                        'Rental refund unconfirmed'
                    )
                end

                return false
            end

            delta = paid.amount

            if player then
                pcall(
                    player.showNotification,
                    TranslateCap(
                        paid.state == 'paid' and 'paid_rental' or 'paid_rental_evicted',
                        ESX.Math.GroupDigits(price),
                        rental.plate
                    )
                )
            end

            return true
        end, true)
        return success, delta
    end)
end

function PayRent()
    if not ready or not D.ready or running then
        return
    end

    running = true

    local started, day = GetGameTimer(), os.date('%Y-%m-%d')
    local ok, problem = pcall(function()
        local cursor = ''

        while true do
            local rentals = MySQL.query.await(
                [[SELECT owner, rent_price, plate, shop_id, society_account, vehicle, base_price
                FROM rented_vehicles WHERE plate > ? ORDER BY plate LIMIT 50]],
                { cursor }
            )

            if #rentals == 0 then
                break
            end

            for _, rental in ipairs(rentals) do
                local society

                if rental.society_account and GetResourceState('esx_addonaccount') == 'started' then
                    TriggerEvent(
                        'esx_addonaccount:getSharedAccount',
                        rental.society_account,
                        function(account)
                            society = account
                        end
                    )
                end

                if society and society.withPersistence then
                    -- Shares the garage's plate lock with retrieval, return, resale and eviction.
                    local locked, err = exports['esx_garage']:withVehicleOperation(
                        rental.plate,
                        function()
                            return charge(rental, day, society)
                        end
                    )

                    if not locked and err then
                        print(
                            '[esx_vehicleshop] Rental deferred '
                                .. rental.plate
                                .. ': '
                                .. tostring(err)
                        )
                    end
                else
                    print(
                        '[esx_vehicleshop] Rental account unavailable; preserved: ' .. rental.plate
                    )
                end

                cursor = rental.plate
                Wait(0)
            end
        end
    end)

    running = false

    if not ok then
        print('[esx_vehicleshop] Rental run failed: ' .. tostring(problem))
    end

    print(('[esx_vehicleshop] Rental payments finished in %s ms'):format(GetGameTimer() - started))
end

TriggerEvent('cron:runAt', 22, 0, PayRent)
