-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Rental.DB = {}

function Rental.DB.initialize()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS esx_vehicle_rentals (
            identifier VARCHAR(80) NOT NULL,
            branch VARCHAR(64) NOT NULL,
            model VARCHAR(64) NOT NULL,
            plate VARCHAR(8) NOT NULL,
            plan VARCHAR(64) NOT NULL,
            account VARCHAR(32) NOT NULL,
            price INT UNSIGNED NOT NULL,
            expires_at BIGINT UNSIGNED NOT NULL,
            status VARCHAR(16) NOT NULL DEFAULT 'pending',
            PRIMARY KEY (identifier),
            UNIQUE KEY uq_rental_plate (plate),
            KEY idx_rental_expiry (expires_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    local engine = MySQL.scalar.await([[SELECT ENGINE FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'esx_vehicle_rentals']])
    assert(engine and engine:upper() == 'INNODB', 'esx_vehicle_rentals must use InnoDB')

    MySQL.update.await(
        "DELETE FROM esx_vehicle_rentals WHERE status = 'pending' OR expires_at <= ?",
        { os.time() }
    )

    local rows = MySQL.query.await(
        "SELECT identifier, branch, model, plate, plan, account, price, expires_at FROM esx_vehicle_rentals WHERE status = 'active'"
    )
    assert(type(rows) == 'table', 'Unable to load rental contracts')

    for _, row in ipairs(rows) do
        Rental.leases[row.identifier] = {
            identifier = row.identifier,
            branch = row.branch,
            model = row.model,
            plate = row.plate,
            plan = row.plan,
            account = row.account,
            price = tonumber(row.price),
            expires = assert(tonumber(row.expires_at), 'Invalid rental expiry'),
        }
    end
end

function Rental.DB.activate(lease)
    local rows = MySQL.update.await(
        "UPDATE esx_vehicle_rentals SET status = 'active' WHERE identifier = ? AND plate = ? AND status = 'pending'",
        { lease.identifier, lease.plate }
    )

    assert(rows == 1, 'Unable to activate rental contract')
end

function Rental.DB.insert(lease)
    local result = MySQL.insert.await(
        [[
        INSERT INTO esx_vehicle_rentals
            (identifier, branch, model, plate, plan, account, price, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]],
        {
            lease.identifier,
            lease.branch,
            lease.model,
            lease.plate,
            lease.plan,
            lease.account,
            lease.price,
            lease.expires,
        }
    )

    -- A table without an AUTO_INCREMENT column returns insertId 0 on a successful insert.
    assert(type(result) == 'number', 'Unable to persist rental contract')
end

function Rental.DB.delete(lease)
    local result = MySQL.update.await(
        'DELETE FROM esx_vehicle_rentals WHERE identifier = ? AND plate = ?',
        { lease.identifier, lease.plate }
    )

    assert(type(result) == 'number', 'Unable to close rental contract')
end

function Rental.DB.plateExists(plate)
    if
        MySQL.scalar.await(
            'SELECT plate FROM esx_vehicle_rentals WHERE plate = ? LIMIT 1',
            { plate }
        )
    then
        return true
    end

    if
        MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE plate = ? LIMIT 1', { plate })
    then
        return true
    end

    for _, entity in ipairs(GetAllVehicles()) do
        if xLib.vehiclePlate.matchesVehicle(entity, plate) then
            return true
        end
    end

    return false
end
