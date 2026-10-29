-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
-- Runs in the job's environment: uses its actual coordinates, grades and shop config.
local resource = GetCurrentResourceName()
local jobs = {
    esx_policejob = 'police',
    esx_ambulancejob = 'ambulance',
    esx_taxijob = 'taxi',
    esx_mechanicjob = 'mechanic',
}

local job = assert(jobs[resource], 'Unsupported garage job integration')
local registering, pending = false, false

local function onDuty(source)
    local player = ESX.GetPlayerFromId(source)

    if not player or not player.job or player.job.name ~= job or player.job.onDuty == false then
        return false
    end

    if Config.EnableESXService then
        return GetResourceState('esx_service') == 'started'
            and exports['esx_service']:IsInService(job, source) == true
    end

    return true
end

local function register()
    if registering then
        pending = true
        return
    end

    if GetResourceState('esx_garage') ~= 'started' then
        return
    end

    registering = true

    local ok, err = pcall(function()
        ESXCatalog.awaitReady()

        local settings, definitions = Config.GarageIntegration or {}, {}
        local labels = settings.labels
            or { ground = 'Garage', boat = 'Marina', helicopter = 'Helipad', plane = 'Hangar' }
        local locations = resource == 'esx_policejob' and Config.PoliceStations
            or resource == 'esx_ambulancejob' and Config.Hospitals
        local categories =
            { Vehicles = 'ground', Helicopters = 'helicopter', Planes = 'plane', Boats = 'boat' }

        for key, location in pairs(locations or {}) do
            for group, category in pairs(categories) do
                for index, garage in ipairs(location[group] or {}) do
                    local spawns = {}
                    local spawnPoints = garage.SpawnPoints or {}

                    for _, spawn in ipairs(spawnPoints) do
                        spawns[#spawns + 1] = vector4(
                            spawn.coords.x,
                            spawn.coords.y,
                            spawn.coords.z,
                            spawn.heading or 0
                        )
                    end

                    definitions[#definitions + 1] = {
                        id = ('%s_%s_%s_%s'):format(job, key, group:lower(), index),
                        label = garage.GarageLabel
                            or ('%s - %s'):format(
                                location.label or location.Label or key,
                                labels[category] or category
                            ),
                        type = 'job',
                        job = job,
                        shared = settings.shared ~= false,
                        minGrade = garage.GarageMinGrade or settings.minGrade or 0,
                        vehicleCategories = { category },
                        entryPoint = garage.GaragePoint,
                        storePoint = garage.StorePoint
                            or (spawnPoints[1] and spawnPoints[1].coords),
                        spawns = spawns,
                        pound = garage.Pound or settings.pound,
                        access = { authorize = onDuty },
                    }
                end
            end
        end

        if job == 'taxi' or job == 'mechanic' then
            local zones = Config.Zones
            local entry = job == 'taxi' and zones.VehicleSpawner.Pos
                or (zones.MechanicActions.Pos + vector3(0, 6, 0))
            entry = vector3(entry.x, entry.y, entry.z)

            local spawn = zones.VehicleSpawnPoint
            local models

            if job == 'taxi' and not Config.EnableSocietyOwnedVehicles then
                models = {}

                for _, vehicle in ipairs(Config.AuthorizedVehicles or {}) do
                    models[#models + 1] = vehicle.model
                end
            end

            if job == 'mechanic' and not Config.EnableSocietyOwnedVehicles then
                models = function(source)
                    local allowed = { 'flatbed', 'towtruck2' }
                    local player = ESX.GetPlayerFromId(source)
                    local grade = player and player.job and player.job.grade_name

                    if
                        Config.EnablePlayerManagement
                        and (grade == 'boss' or grade == 'chief' or grade == 'experimente')
                    then
                        allowed[#allowed + 1] = 'slamvan3'
                    end

                    return allowed
                end
            end

            definitions[#definitions + 1] = {
                id = job .. '_fleet',
                label = settings.label or (job:sub(1, 1):upper() .. job:sub(2) .. ' Garage'),
                type = 'job',
                job = job,
                shared = settings.shared ~= false,
                minGrade = settings.minGrade or 0,
                vehicleCategories = { 'ground' },
                models = models,
                entryPoint = entry,
                storePoint = vector3(
                    zones.VehicleDeleter.Pos.x,
                    zones.VehicleDeleter.Pos.y,
                    zones.VehicleDeleter.Pos.z
                ),
                spawns = { vector4(spawn.Pos.x, spawn.Pos.y, spawn.Pos.z, spawn.Heading or 90.0) },
                pound = settings.pound,
                access = { authorize = onDuty },
            }

            if Config.MaxInService ~= -1 and not Config.EnableSocietyOwnedVehicles then
                local definition = definitions[#definitions]

                definition.reserve = function(source)
                    if GetResourceState('esx_service') ~= 'started' then
                        return false
                    end

                    local allowed, acquired = exports['esx_service']:TryEnableService(job, source)

                    return allowed and { acquired = acquired } or false
                end

                definition.release = function(source, token)
                    if token.acquired then
                        exports['esx_service']:DisableService(job, source)
                    end
                end

                definition.onStored = function(source)
                    exports['esx_service']:DisableService(job, source)
                end
            end

            local fleet = Config.EnableSocietyOwnedVehicles and {} or Config.GarageFleet or {}

            if job == 'taxi' and not Config.EnableSocietyOwnedVehicles then
                fleet = {}

                for _, vehicle in ipairs(Config.AuthorizedVehicles or {}) do
                    fleet[#fleet + 1] = {
                        model = vehicle.model,
                        count = vehicle.garageCount or settings.vehiclesPerModel or 4,
                    }
                end
            end

            assert(
                exports['esx_garage']:prepareJobFleet(job, fleet, 'society_' .. job),
                'Fleet initialization failed'
            )
        end

        exports['esx_garage']:registerGarages(definitions)
    end)

    registering = false

    if not ok then
        print(('[%s] Unified garage initialization failed: %s'):format(resource, tostring(err)))
    end

    if pending then
        pending = false
        register()
    end
end

MySQL.ready(register)
AddEventHandler('esx_garage:ready', register)
AddEventHandler('onResourceStart', function(name)
    if name == 'esx_garage' then
        register()
    end
end)
