-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local integrations = { esx_taxijob = 'taxi', esx_mechanicjob = 'mechanic' }
local preparing = {}
local ledgerReady = false

local function modelHash(model)
    local value = tonumber(model) or (type(model) == 'string' and GetHashKey(model))

    if type(value) ~= 'number' or value ~= value or value == 0 or math.abs(value) == math.huge then
        return nil
    end

    return math.floor(value < 0 and value + 4294967296 or value)
end

local function properties(row)
    local ok, props = pcall(json.decode, row.vehicle or '')

    return ok and type(props) == 'table' and props or nil
end

local function record(slot, job, plate, props)
    local transaction = {}

    if props then
        local encoded = json.encode(props)

        assert(#encoded <= 16384, 'Oversized legacy fleet properties')
        transaction[#transaction + 1] = {
            query = (
                'INSERT INTO `owned_vehicles` (`owner`, `plate`, `vehicle`, '
                .. '`type`, `job`, `stored`) VALUES (?, ?, ?, ?, ?, '
                .. '1)'
            ),
            values = { 'society:' .. job, plate, encoded, 'car', job },
        }
    end

    transaction[#transaction + 1] = {
        query = 'INSERT INTO `esx_garage_fleet_imports` (`slot`, `job`, `plate`) VALUES (?, ?, ?)',
        values = { slot, job, plate },
    }
    assert(MySQL.transaction.await(transaction), 'Fleet persistence failed')
end

local function completed(slot)
    return MySQL.scalar.await(
        'SELECT `plate` FROM `esx_garage_fleet_imports` WHERE `slot` = ?',
        { slot }
    ) ~= nil
end

local function prepare(job, vehicles, datastore)
    local engine = MySQL.scalar.await(
        (
            'SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA = '
            .. 'DATABASE() AND TABLE_NAME = '
            .. '?'
        ),
        { 'owned_vehicles' }
    )
    assert(
        type(engine) == 'string' and engine:lower() == 'innodb',
        (
            'Fleet import requires transactional owned_vehicles (InnoDB); no '
            .. 'automatic engine conversion is '
            .. 'performed'
        )
    )

    if not ledgerReady then
        MySQL.query.await(
            (
                'CREATE TABLE IF NOT EXISTS `esx_garage_fleet_imports` (\n         '
                .. '   `slot` VARCHAR(160) NOT NULL PRIMARY KEY, `job` VARCHAR(20) '
                .. 'NOT NULL, `plate` VARCHAR(12) NOT NULL\n        ) ENGINE=InnoDB '
                .. 'DEFAULT CHARSET=utf8mb4'
            )
        )
        ledgerReady = true
    end

    local data = MySQL.scalar.await(
        'SELECT `data` FROM `datastore_data` WHERE `name` = ? AND `owner` IS NULL LIMIT 1',
        { datastore }
    )

    if data then
        local ok, decoded = pcall(json.decode, data)

        assert(ok and type(decoded) == 'table', 'Invalid legacy society datastore')

        for _, props in ipairs(decoded.garage or {}) do
            local plate = type(props) == 'table'
                and xLib.vehiclePlate.normalize(props.plate, { maxLength = 12 })
            local model = type(props) == 'table' and modelHash(props.model)

            assert(plate and model, 'Invalid legacy society vehicle; original datastore retained')

            local slot = 'legacy:' .. datastore .. ':' .. plate

            if not completed(slot) then
                local row = MySQL.single.await(
                    (
                        'SELECT `owner`, `job`, `plate`, `vehicle` FROM '
                        .. '`owned_vehicles` WHERE `plate` = ? LIMIT '
                        .. '1'
                    ),
                    { plate }
                )

                if row then
                    local old = properties(row)

                    assert(
                        row.job == job and old and modelHash(old.model) == model,
                        'Legacy fleet plate conflicts with an existing vehicle: ' .. plate
                    )
                    record(slot, job, row.plate)
                else
                    props.plate, props.model = plate, model
                    record(slot, job, plate, props)
                end
            end
        end
    end

    assert(type(vehicles) == 'table' and #vehicles <= 32, 'Invalid configured fleet')

    for _, entry in ipairs(vehicles) do
        local model, count = modelHash(entry.model), tonumber(entry.count or 1)

        assert(
            model and count and count >= 0 and count <= 32 and count % 1 == 0,
            'Invalid fleet model/count'
        )

        local rows = MySQL.query.await(
            'SELECT `plate`, `vehicle` FROM `owned_vehicles` WHERE `job` = ? ORDER BY `plate`',
            { job }
        ) or {}

        local existing = {}
        local used = {}

        for _, imported in
            ipairs(
                MySQL.query.await(
                    'SELECT `plate` FROM `esx_garage_fleet_imports` WHERE `job` = ?',
                    { job }
                ) or {}
            )
        do
            used[imported.plate] = true
        end

        for _, row in ipairs(rows) do
            local props = properties(row)

            if props and modelHash(props.model) == model and not used[row.plate] then
                existing[#existing + 1] = row.plate
            end
        end

        for index = 1, count do
            local slot = ('seed:%s:%s:%s'):format(job, model, index)

            if not completed(slot) then
                if #existing > 0 then
                    record(slot, job, table.remove(existing, 1))
                else
                    local plate = xLib.vehiclePlate.generateUnique(
                        { prefix = 'JF', letters = 2, numbers = 4 },
                        function(candidate)
                            return MySQL.scalar.await(
                                'SELECT `plate` FROM `owned_vehicles` WHERE `plate` = ?',
                                { candidate }
                            ) ~= nil
                        end
                    )
                    assert(plate, 'Unable to allocate a unique fleet plate')
                    record(slot, job, plate, { model = model, plate = plate })
                end
            end
        end
    end
end

exports('prepareJobFleet', function(job, vehicles, datastore)
    local resource = GetInvokingResource()

    if integrations[resource] ~= job or datastore ~= 'society_' .. job or preparing[job] then
        return false
    end

    local waited = 0

    while not GarageReady and waited < 10000 do
        Wait(50)
        waited = waited + 50
    end

    if not GarageReady then
        return false
    end

    preparing[job] = true

    local ok, err = pcall(prepare, job, vehicles, datastore)

    preparing[job] = nil

    if not ok then
        print(('[esx_garage] %s fleet initialization failed: %s'):format(job, tostring(err)))
    end

    return ok
end)
