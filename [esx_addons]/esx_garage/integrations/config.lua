-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
-- Loaded inside the job resource after its own config, on both sides.
local resource = GetCurrentResourceName()
local locations = resource == 'esx_policejob' and Config.PoliceStations
    or resource == 'esx_ambulancejob' and Config.Hospitals

for _, location in pairs(locations or {}) do
    for _, group in ipairs({ 'Vehicles', 'Helicopters', 'Planes', 'Boats' }) do
        for _, garage in ipairs(location[group] or {}) do
            garage.GaragePoint = garage.GaragePoint or garage.Spawner
            -- The old marker now opens only the purchase shop, away from the NUI marker.
            garage.Spawner = garage.ShopPoint or (garage.GaragePoint + vector3(-6.0, 0.0, 0.0))
        end
    end
end

if resource == 'esx_taxijob' then
    Config.Zones.VehicleSpawner.Type = -1
    Config.Zones.VehicleDeleter.Type = -1
elseif resource == 'esx_mechanicjob' then
    Config.Zones.VehicleDeleter.Type = -1
end
