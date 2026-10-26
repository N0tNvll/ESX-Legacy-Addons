-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@class FuelHose
---@field pump integer
---@field pumpCoords vector3
---@field nozzle integer
---@field rope integer?

---@class FuelPumpTarget
---@field type "vehicle"|"can"
---@field vehicle? integer
---@field kind string
---@field capacity number
---@field liters number

---@class FuelPumpState
---@field hose FuelHose?
---@field filling boolean
---@field cancelFilling boolean
---@field uiTarget FuelPumpTarget?
Pump = {
    hose = nil,
    filling = false,
    cancelFilling = false,
    uiTarget = nil
}
