-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {}

Config.Locale = GetConvar("esx:locale", "en")

-- Damage taken in a collision is multiplied by these values.
Config.DamageMultiplier = {
    Engine = 1.5,
    Body = 1.0,
    Tank = 1.2
}

-- Extra multiplier per vehicle class. Classes missing here use 1.0, classes set to false are ignored.
-- 13 cycles, 14 boats, 15 helicopters, 16 planes and 21 trains are ignored by default.
Config.ClassMultiplier = {
    [0] = 1.0, [1] = 1.0, [2] = 0.8, [3] = 1.0, [4] = 1.1, [5] = 1.1, [6] = 1.2, [7] = 1.3,
    [8] = 1.2, [9] = 0.8, [10] = 0.7, [11] = 0.9, [12] = 0.9, [17] = 0.8, [18] = 0.7, [19] = 0.6, [20] = 0.7, [22] = 1.0,
    [13] = false, [14] = false, [15] = false, [16] = false, [21] = false
}

-- Engine health goes from 1000 (new) to 0. Below each threshold the matching effect starts.
Config.Engine = {
    CascadeHealth = 400, -- the engine keeps losing health on its own
    CascadeRate = 1.5, -- health lost per second below CascadeHealth
    LimpHealth = 300, -- limp mode: lower top speed and torque
    LimpSpeed = 0.45, -- share of the top speed kept in limp mode
    LimpTorque = 0.5, -- share of the torque kept in limp mode
    StallChance = 0.02, -- stall chance per second in limp mode
    FailureHealth = 100 -- the engine dies and the vehicle cannot be driven until repaired
}

-- Tyres can burst on a hard hit. Impact is the body + engine health lost in one hit.
Config.TyreBurst = {
    Enabled = true,
    MinImpact = 150.0,
    Chance = 0.25
}

-- Stops players from rolling a flipped vehicle back on its wheels with the air controls.
Config.PreventFlipControl = true

Config.Notify = true
