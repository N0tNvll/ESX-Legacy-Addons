-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {}

Config.Locale = GetConvar("esx:locale", "en")

-- For legacy rows whose type is only "aircraft", map each model to helicopter/plane.
-- e.g. { maverick = "helicopter", luxor = "plane" }. No owner/type data is rewritten.
Config.VehicleCategoryOverrides = {}

---@type GarageSettings
Config.Settings = {
	interactionDistance = 3.0,
	restrictToGarage = false,
	defaultImpoundFee = 400,
	vehicleKeys = false,
	storeMarkerOnlyInVehicle = true,
	showMarker = true,
	vehiclesPerPage = 30,
	maxVehiclesPerMenu = 100,
}

---@type Garage[]
Config.Garages = {
	-- Job garages register from each job config; ownership and category are independent.
	{
		id = "vespucci_boulevard",
		label = "Vespucci Boulevard",
		type = "public",
		vehicleCategories = { "ground" },
		entryPoint = vec3(-285.2, -886.5, 31.0),
		storePoint = vec3(-298.8, -889.7, 31.0),
		spawns = {
			vec4(-309.3, -897.0, 31.0, 351.8),
		},
		blip = { sprite = 357, scale = 0.8, color = 3 },
		ped = { model = `s_m_m_gentransport`, z = 30.73, heading = 72.7597 },
		pound = "los_santos",
	},
	{
		id = "san_andreas_avenue",
		label = "San Andreas Avenue",
		type = "public",
		vehicleCategories = { "ground" },
		entryPoint = vec3(216.29, -808.96, 30.73),
		storePoint = vec3(220.1, -805.2, 30.8),
		spawns = {
			vec4(225.7, -801.9, 30.5, 250.0),
		},
		blip = { sprite = 357, scale = 0.8, color = 3 },
		ped = { model = `s_m_m_gentransport`, z = 30.73, heading = 250.0 },
		pound = "los_santos",
	},
	{
		id = 'boat_port_1', label = 'Marina 1', type = 'public', vehicleCategories = { 'boat' },
		entryPoint = vec3(-772.4, -1430.9, 0.5), storePoint = vec3(-798.4, -1456.0, 0.0),
		spawns = { vec4(-785.39, -1426.3, 0.0, 146.0) }, exitPoint = vec4(-791.4, -1452.5, 1.5, 318.9), pound = 'marine_impound',
		blip = { sprite = 356, scale = 0.8, color = 3 },
	},
	{
		id = 'boat_port_2', label = 'Marina 2', type = 'public', vehicleCategories = { 'boat' },
		entryPoint = vec3(3864.9, 4463.9, 1.6), storePoint = vec3(3857.0, 4446.9, 0.0),
		spawns = { vec4(3854.4, 4477.2, 0.0, 273.0) }, exitPoint = vec4(3854.7, 4458.6, 1.8, 355.3), pound = 'marine_impound',
		blip = { sprite = 356, scale = 0.8, color = 3 },
	},
	{
		id = 'boat_port_3', label = 'Marina 3', type = 'public', vehicleCategories = { 'boat' },
		entryPoint = vec3(-1614.0, 5260.1, 2.8), storePoint = vec3(-1600.3, 5261.9, 0.0),
		spawns = { vec4(-1622.5, 5247.1, 0.0, 21.0) }, exitPoint = vec4(-1605.7, 5259.0, 2.0, 25.0), pound = 'marine_impound',
		blip = { sprite = 356, scale = 0.8, color = 3 },
	},
	{
		id = 'boat_port_4', label = 'Marina 4', type = 'public', vehicleCategories = { 'boat' },
		entryPoint = vec3(712.6, 4093.3, 33.7), storePoint = vec3(705.1, 4110.1, 30.2),
		spawns = { vec4(712.8, 4080.2, 29.3, 181.0) }, exitPoint = vec4(711.9, 4110.5, 31.3, 180.0), pound = 'marine_impound',
		blip = { sprite = 356, scale = 0.8, color = 3 },
	},
	{
		id = 'boat_port_5', label = 'Marina 5', type = 'public', vehicleCategories = { 'boat' },
		entryPoint = vec3(23.8, -2806.8, 4.8), storePoint = vec3(-1.0, -2799.2, 0.5),
		spawns = { vec4(23.3, -2828.6, 0.8, 181.0) }, exitPoint = vec4(12.6, -2793.8, 2.5, 355.2), pound = 'marine_impound',
		blip = { sprite = 356, scale = 0.8, color = 3 },
	},
	{
		id = 'boat_port_6', label = 'Marina 6', type = 'public', vehicleCategories = { 'boat' },
		entryPoint = vec3(-3427.3, 956.9, 7.3), storePoint = vec3(-3436.5, 946.6, 0.3),
		spawns = { vec4(-3448.9, 953.8, 0.0, 75.0) }, exitPoint = vec4(-3427.0, 952.6, 8.3, 0.0), pound = 'marine_impound',
		blip = { sprite = 356, scale = 0.8, color = 3 },
	},
	{
		id = 'civil_helipad', label = 'Vespucci Helipad', type = 'public', vehicleCategories = { 'helicopter' },
		entryPoint = vec3(-745.5, -1468.6, 5.0), storePoint = vec3(-724.7, -1444.0, 5.0),
		spawns = { vec4(-724.7, -1444.0, 5.0, 140.0) }, pound = 'helicopter_impound',
		blip = { sprite = 43, scale = 0.8, color = 3 },
	},
	{
		id = 'civil_hangar', label = 'LSIA Hangar', type = 'public', vehicleCategories = { 'plane' },
		entryPoint = vec3(-1617.1, -3154.0, 13.9), storePoint = vec3(-1656.0, -3144.0, 13.9),
		spawns = { vec4(-1656.0, -3144.0, 13.9, 330.0) }, pound = 'plane_impound',
		blip = { sprite = 90, scale = 0.8, color = 3 },
	},
}

---@type Impound[]
-- `cost` is optional. When omitted, Config.Settings.defaultImpoundFee is used.
Config.Impounds = {
	{
		id = "los_santos",
		label = "Los Santos Impound",
		getOutPoint = vec3(400.7, -1630.5, 29.3),
		spawns = {
			vec4(401.9, -1647.4, 29.2, 323.3),
		},
		blip = { sprite = 524, scale = 0.8, color = 1 },
		cost = 3000,
	},
	{
		id = "paleto_bay",
		label = "Paleto Bay Impound",
		getOutPoint = vec3(-211.4, 6206.5, 31.4),
		spawns = {
			vec4(-204.6, 6221.6, 30.5, 227.2),
		},
		blip = { sprite = 524, scale = 0.8, color = 1 },
		cost = 3000,
	},
	{
		id = "sandy_shores",
		label = "Sandy Shores Impound",
		getOutPoint = vec3(1728.2, 3709.3, 33.2),
		spawns = {
			vec4(1722.7, 3713.6, 33.2, 19.9),
		},
		blip = { sprite = 524, scale = 0.8, color = 1 },
		cost = 3000,
	},
	{ id = 'marine_impound', label = 'Marine Impound', vehicleCategories = { 'boat' },
		getOutPoint = vec3(-772.4, -1430.9, 0.5), spawns = { vec4(-785.39, -1426.3, 0.0, 146.0) },
		blip = { sprite = 356, scale = 0.8, color = 1 }, cost = 3000 },
	{ id = 'helicopter_impound', label = 'Helicopter Impound', vehicleCategories = { 'helicopter' },
		getOutPoint = vec3(-761.1, -1454.0, 5.0), spawns = { vec4(-745.0, -1468.0, 5.0, 140.0) },
		blip = { sprite = 43, scale = 0.8, color = 1 }, cost = 3000 },
	{ id = 'plane_impound', label = 'Aircraft Impound', vehicleCategories = { 'plane' },
		getOutPoint = vec3(-980.0, -2994.0, 13.9), spawns = { vec4(-1004.0, -3007.0, 13.9, 60.0) },
		blip = { sprite = 90, scale = 0.8, color = 1 }, cost = 3000 },
}
