-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
local D = VehicleShop

local function index(tableName, name, columns)
    local count = MySQL.scalar.await(
        (
            'SELECT COUNT(*) FROM information_schema.STATISTICS WHERE '
            .. 'TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = '
            .. '?'
        ),
        { tableName, name }
    )
    assert(tonumber(count), 'Unable to inspect dealership indexes')

    if tonumber(count) == 0 then
        MySQL.query.await(('ALTER TABLE `%s` ADD INDEX `%s` (%s)'):format(tableName, name, columns))
    end
end

function D.migrate()
    D.legacySchema()

    local legacy = Config.LegacyDealershipId

    assert(D.shops[legacy] and legacy:match('^[%w_%-:]+$'), 'A legacy dealership id is required')

    for _, name in ipairs({ 'cardealer_vehicles', 'rented_vehicles', 'vehicle_sold' }) do
        xLib.schema.ensureColumn(
            name,
            'shop_id',
            ("VARCHAR(64) NOT NULL DEFAULT '%s'"):format(legacy)
        )
    end

    xLib.schema.ensureColumn(
        'rented_vehicles',
        'society_account',
        "VARCHAR(64) NULL DEFAULT 'society_cardealer'"
    )
    xLib.schema.ensureColumn('cardealer_vehicles', 'source_order', 'VARCHAR(36) NULL DEFAULT NULL')
    xLib.schema.ensureColumn('cardealer_vehicles', 'available', 'TINYINT(1) NOT NULL DEFAULT 1')
    xLib.schema.ensureColumn('cardealer_vehicles', 'return_plate', 'VARCHAR(12) NULL DEFAULT NULL')

    local addedType =
        xLib.schema.ensureColumn('vehicles', 'type', "VARCHAR(20) NOT NULL DEFAULT 'car'")
    xLib.schema.ensureColumn('vehicles', 'enabled', 'TINYINT(1) NOT NULL DEFAULT 1')

    if addedType then
        MySQL.update.await("UPDATE vehicles SET type = 'motorcycle' WHERE category = 'motorcycles'")
    end

    index('cardealer_vehicles', 'idx_dealer_stock_shop_model', '`shop_id`, `vehicle`, `id`')
    index('vehicle_sold', 'idx_dealer_sales_shop_date', '`shop_id`, `date`, `plate`')
    index('rented_vehicles', 'idx_dealer_rentals_shop_owner', '`shop_id`, `owner`, `plate`')

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS dealership_vehicles (
        shop_id VARCHAR(64) NOT NULL, model VARCHAR(60) NOT NULL,
        price INT NULL, vehicle_type VARCHAR(20) NULL, enabled TINYINT(1) NOT NULL DEFAULT 1,
        min_grade INT NOT NULL DEFAULT 0, license VARCHAR(60) NULL, props LONGTEXT NULL,
        PRIMARY KEY (shop_id, model)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    MySQL.query.await(
        (
            'CREATE TABLE IF NOT EXISTS esx_vehicle_orders (\n        id '
            .. 'VARCHAR(36) NOT NULL PRIMARY KEY, owner VARCHAR(60) NOT NULL,\n       '
            .. ' shop_id VARCHAR(64) NOT NULL, kind VARCHAR(20) NOT NULL, model '
            .. 'VARCHAR(60) NULL,\n        plate VARCHAR(12) NULL, reserved_plate '
            .. 'VARCHAR(12) NULL UNIQUE, request_key CHAR(64) NULL UNIQUE, amount INT '
            .. 'NOT NULL, payload LONGTEXT NOT NULL,\n        state VARCHAR(20) NOT '
            .. 'NULL, payment VARCHAR(16) NULL, created_at INT NOT NULL, expires_at '
            .. 'INT NOT NULL,\n        delivery_state VARCHAR(20) NOT NULL DEFAULT '
            .. "'pending',\n        KEY idx_dealer_orders_owner (owner, state, "
            .. 'created_at)\n    ) ENGINE=InnoDB DEFAULT '
            .. 'CHARSET=utf8mb4'
        )
    )

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS esx_vehicle_movements (
        order_id VARCHAR(36) NOT NULL PRIMARY KEY, owner VARCHAR(60) NOT NULL,
        shop_id VARCHAR(64) NOT NULL, kind VARCHAR(20) NOT NULL, plate VARCHAR(12) NULL,
        amount INT NOT NULL, payment VARCHAR(16) NOT NULL, created_at INT NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    for _, name in ipairs({
        'users',
        'vehicles',
        'dealership_vehicles',
        'esx_vehicle_orders',
        'esx_vehicle_movements',
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

    MySQL.update.await(
        (
            "UPDATE esx_vehicle_orders o SET state = 'complete'\n        "
            .. "WHERE state = 'processing' AND EXISTS (SELECT 1 FROM "
            .. 'esx_vehicle_movements m WHERE m.order_id = '
            .. 'o.id)'
        )
    )

    MySQL.update.await(
        (
            "UPDATE esx_vehicle_orders o SET state = 'failed'\n        WHERE "
            .. "state = 'processing' AND NOT EXISTS (SELECT 1 FROM "
            .. 'esx_vehicle_movements m WHERE m.order_id = '
            .. 'o.id)'
        )
    )
end

function D.reconcileRentals()
    local cursor = ''

    while true do
        local rows = MySQL.query.await(
            'SELECT * FROM rented_vehicles WHERE plate > ? ORDER BY plate LIMIT 100',
            { cursor }
        )
        assert(type(rows) == 'table', 'Unable to inspect historical rentals')

        if #rows == 0 then
            break
        end

        for _, rental in ipairs(rows) do
            local owned = MySQL.single.await(
                'SELECT owner, vehicle FROM owned_vehicles WHERE plate = ?',
                { rental.plate }
            )

            if owned then
                local ok, props = pcall(json.decode, owned.vehicle or '')
                local hash = ok
                    and props
                    and (
                        tonumber(props.model)
                        or (type(props.model) == 'string' and joaat(props.model))
                    )
                local expected = joaat(rental.vehicle)
                local job = MySQL.scalar.await(
                    'SELECT job FROM owned_vehicles WHERE plate = ?',
                    { rental.plate }
                )
                assert(
                    owned.owner == rental.owner
                        and (not job or job == '')
                        and hash
                        and (hash % 4294967296 == expected % 4294967296),
                    'Historical rental plate conflict: ' .. rental.plate .. '; records preserved'
                )
            else
                local vehicle = D.catalog[rental.vehicle:lower()]
                local active, expected = false, joaat(rental.vehicle)

                for _, entity in ipairs(GetAllVehicles()) do
                    if
                        DoesEntityExist(entity)
                        and xLib.vehiclePlate.normalize(GetVehicleNumberPlateText(entity))
                            == xLib.vehiclePlate.normalize(rental.plate)
                    then
                        assert(
                            GetEntityModel(entity) % 4294967296 == expected % 4294967296,
                            'Historical rental entity conflict: ' .. rental.plate
                        )
                        active = true
                    end
                end

                MySQL.insert.await(
                    (
                        'INSERT INTO owned_vehicles (owner, plate, vehicle, '
                        .. 'type, stored)\n                    SELECT owner, '
                        .. 'plate, ?, ?, ? FROM rented_vehicles WHERE plate = ? '
                        .. 'AND owner = '
                        .. '?'
                    ),
                    {
                        json.encode({ model = joaat(rental.vehicle), plate = rental.plate }),
                        vehicle and vehicle.type or 'car',
                        active and 0 or 1,
                        rental.plate,
                        rental.owner,
                    }
                )
            end
        end

        cursor = rows[#rows].plate

        if #rows < 100 then
            break
        end

        Wait(0)
    end
end
