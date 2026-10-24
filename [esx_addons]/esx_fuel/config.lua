-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {}

Config.Locale = GetConvar("esx:locale", "en")

-- Fuel consumption, in percent of the tank per second at full throttle.
-- Final usage = (Idle + RPM^2 * Load) * ClassMultiplier[vehicle class]
Config.Consumption = {
    Idle = 0.004,
    Load = 0.11,
    SyncEvery = 2.0, -- publish the level to the `fuel` state bag when it moved by this many percent
}

Config.ClassMultiplier = {
    [0] = 1.0, [1] = 1.0, [2] = 1.2, [3] = 1.0, [4] = 1.1, [5] = 1.1, [6] = 1.2, [7] = 1.4,
    [8] = 0.6, [9] = 1.2, [10] = 1.4, [11] = 1.0, [12] = 1.2, [13] = 0.0, [14] = 1.0, [15] = 1.0,
    [16] = 1.0, [17] = 1.1, [18] = 1.1, [19] = 1.3, [20] = 1.4, [21] = 1.0, [22] = 1.0
}

-- Fuel sold at the pumps. `price` is per liter, `octane` is only used by petrol.
Config.FuelTypes = {
    { name = "regular", kind = "petrol", octane = 87, price = 1.55 },
    { name = "plus", kind = "petrol", octane = 89, price = 1.70 },
    { name = "premium", kind = "petrol", octane = 91, price = 1.90 },
    { name = "diesel", kind = "diesel", price = 1.60 },
    { name = "electric", kind = "electric", price = 0.45 }
}

-- Octane of a petrol tank when nothing is known about it.
Config.DefaultOctane = 87

-- Wrong fuel. The effect scales with the share of wrong fuel in the tank (0 to 1).
Config.WrongFuel = {
    Tolerance = 0.1, -- below this share nothing happens
    PowerLoss = 0.6, -- share of the top speed lost at 100% wrong fuel
    StallChance = 0.04, -- stall chance per second at 100% wrong fuel
    EngineDamage = 3.0 -- engine health lost per second at 100% wrong fuel
}

-- Links with vehicle damage. A damaged tank leaks, a worn engine burns more fuel.
-- Install esx_vehiclefailure to also make wrong fuel wear the engine through its failure thresholds.
Config.Damage = {
    Enabled = true,
    LeakTankHealth = 650, -- the tank starts leaking below this health (1000 = new)
    LeakPercentPerSecond = 0.08, -- leak at 0 tank health, in percent of the tank per second
    WornEngineHealth = 600, -- the engine burns more fuel below this health
    WornEngineConsumption = 0.6 -- extra consumption at 0 engine health (0.6 = +60%)
}

-- Torque bonus per octane point above Config.DefaultOctane
Config.OctaneBonus = 0.01

-- Mechanics can drain a tank to get rid of the wrong fuel.
Config.Drain = {
    Enabled = true,
    Jobs = { mechanic = 0 }, -- job name = minimum grade
    Duration = 10000
}

Config.JerryCan = {
    Enabled = true,
    Liters = 20.0,
    PourLitersPerSecond = 2.0
}

-- Extra charging spots for electric vehicles, on top of the gas station pumps.
-- { coords = vector3(x, y, z), radius = 6.0 }
Config.Chargers = {}

-- Station stock. Disabled by default, pumps never run dry.
Config.Stock = {
    Enabled = false,
    Capacity = 2000, -- liters per station
    Default = 1000, -- liters for a station seen for the first time
    DeliveryItem = "petrol_raffin",
    LitersPerItem = 50,
    DeliveryPay = 20, -- paid per item, by the owning society when there is one
    Owners = {} -- [station index in Config.Stations] = "society_name"
}

-- Vehicle classes running on diesel. Everything else uses petrol, electric vehicles are detected by the game.
Config.DieselClasses = { [10] = true, [11] = true, [17] = true, [20] = true }

-- Force the fuel of a model: ["model_name"] = "petrol" | "diesel" | "electric"
Config.ModelFuel = {}

Config.Refuel = {
    LitersPerSecond = 4.0,
    MaxLitersPerPurchase = 200,
    HoseLength = 6.0,
    TankDistance = 1.6,
    ChargePerSecond = 1.5,
    PayWith = { "money", "bank" }
}

Config.PumpModels = {
    "prop_gas_pump_1a",
    "prop_gas_pump_1b",
    "prop_gas_pump_1c",
    "prop_gas_pump_1d",
    "prop_gas_pump_old2",
    "prop_gas_pump_old3",
    "prop_vintage_pump"
}

-- The server only accepts purchases within StationRadius of one of these stations.
Config.StationRadius = 35.0
Config.ShowBlips = true

Config.Stations = {
    vector3(49.41, 2778.79, 58.04),
    vector3(263.89, 2606.46, 44.98),
    vector3(1039.96, 2671.13, 39.55),
    vector3(1207.26, 2660.18, 37.90),
    vector3(2539.69, 2594.19, 37.94),
    vector3(2679.86, 3263.95, 55.24),
    vector3(2005.06, 3773.89, 32.40),
    vector3(1687.16, 4929.39, 42.08),
    vector3(1701.31, 6416.03, 32.76),
    vector3(179.86, 6602.84, 31.87),
    vector3(-94.46, 6419.59, 31.49),
    vector3(-2555.00, 2334.40, 33.08),
    vector3(-1800.38, 803.66, 138.65),
    vector3(-1437.62, -276.75, 46.21),
    vector3(-2096.24, -320.29, 13.17),
    vector3(-724.62, -935.16, 19.21),
    vector3(-526.02, -1211.00, 18.18),
    vector3(-70.21, -1761.79, 29.53),
    vector3(265.65, -1261.31, 29.29),
    vector3(819.65, -1028.85, 26.40),
    vector3(1208.95, -1402.57, 35.22),
    vector3(1181.38, -330.85, 69.32),
    vector3(620.84, 269.10, 103.09),
    vector3(2581.32, 362.04, 108.47),
    vector3(176.63, -1562.03, 29.26),
    vector3(-319.29, -1471.72, 30.55),
    vector3(1784.32, 3330.55, 41.25)
}
