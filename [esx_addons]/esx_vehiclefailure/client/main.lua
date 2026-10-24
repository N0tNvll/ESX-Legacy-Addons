-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local TICK_MS <const> = 50
local TYRES <const> = { 0, 1, 4, 5 }
local CONTROL_LEAN_LR <const> = 59
local CONTROL_LEAN_UD <const> = 60
local BIKE_CLASS <const> = 8
local FLIP_ROLL <const> = 75.0
local NO_MODIFIERS <const> = {}

---@class FailureState
---@field vehicle integer
---@field engine number
---@field body number
---@field tank number
---@field baseSpeed number
---@field speed number
---@field torque number
---@field limp boolean
---@field failed boolean

---@class FailureModifier
---@field speed number
---@field torque number

---@type FailureState?
local current

---@type table<integer, table<string, FailureModifier>>
local modifiers = {}

---@param vehicle integer
---@return number?
local function getClassMultiplier(vehicle)
    local multiplier = Config.ClassMultiplier[GetVehicleClass(vehicle)]

    if multiplier == false then
        return nil
    end

    return multiplier or 1.0
end

---@param key string
local function notify(key)
    if Config.Notify then
        ESX.ShowNotification(_U(key))
    end
end

---@param vehicle integer
---@return FailureState
local function track(vehicle)
    local engine = GetVehicleEngineHealth(vehicle)

    if engine > Config.Engine.FailureHealth then
        SetVehicleUndriveable(vehicle, false)
    end

    return {
        vehicle = vehicle,
        engine = engine,
        body = GetVehicleBodyHealth(vehicle),
        tank = GetVehiclePetrolTankHealth(vehicle),
        baseSpeed = GetVehicleEstimatedMaxSpeed(vehicle),
        speed = 1.0,
        torque = 1.0,
        limp = false,
        failed = false
    }
end

---@param state FailureState
local function release(state)
    if state.speed < 1.0 and DoesEntityExist(state.vehicle) then
        SetVehicleMaxSpeed(state.vehicle, 0.0)
    end

    modifiers[state.vehicle] = nil
end

---@param state FailureState
---@param multiplier number
local function applyCollisionDamage(state, multiplier)
    local vehicle = state.vehicle
    local engine = GetVehicleEngineHealth(vehicle)
    local body = GetVehicleBodyHealth(vehicle)
    local tank = GetVehiclePetrolTankHealth(vehicle)

    local engineLoss = math.max(0.0, state.engine - engine)
    local bodyLoss = math.max(0.0, state.body - body)
    local tankLoss = math.max(0.0, state.tank - tank)

    if engineLoss > 0.0 then
        engine = math.max(0.0, state.engine - engineLoss * Config.DamageMultiplier.Engine * multiplier)
        SetVehicleEngineHealth(vehicle, engine)
    end

    if bodyLoss > 0.0 then
        body = math.max(0.0, state.body - bodyLoss * Config.DamageMultiplier.Body * multiplier)
        SetVehicleBodyHealth(vehicle, body)
    end

    if tankLoss > 0.0 then
        tank = math.max(1.0, state.tank - tankLoss * Config.DamageMultiplier.Tank * multiplier)
        SetVehiclePetrolTankHealth(vehicle, tank)
    end

    if Config.TyreBurst.Enabled and engineLoss + bodyLoss >= Config.TyreBurst.MinImpact and math.random() < Config.TyreBurst.Chance then
        SetVehicleTyreBurst(vehicle, TYRES[math.random(#TYRES)], true, 1000.0)
    end

    state.engine, state.body, state.tank = engine, body, tank
end

---@param state FailureState
---@param seconds number
local function applyEngineState(state, seconds)
    local vehicle = state.vehicle
    local engine = state.engine
    local running = GetIsVehicleEngineRunning(vehicle)

    if running and engine > Config.Engine.FailureHealth and engine < Config.Engine.CascadeHealth then
        engine = math.max(0.0, engine - Config.Engine.CascadeRate * seconds)
        SetVehicleEngineHealth(vehicle, engine)
        state.engine = engine
    end

    if engine <= Config.Engine.FailureHealth then
        if not state.failed then
            state.failed = true
            notify("engine_failed")
        end

        SetVehicleEngineOn(vehicle, false, true, true)
        SetVehicleUndriveable(vehicle, true)
    elseif state.failed then
        state.failed = false
        SetVehicleUndriveable(vehicle, false)
    end

    local limp = not state.failed and engine < Config.Engine.LimpHealth

    if limp and not state.limp then
        notify("limp_mode")
    end

    state.limp = limp

    if limp and running and math.random() < Config.Engine.StallChance * seconds then
        SetVehicleEngineOn(vehicle, false, false, true)
    end
end

---@param state FailureState
local function applyPower(state)
    local speed = state.limp and Config.Engine.LimpSpeed or 1.0
    local torque = state.limp and Config.Engine.LimpTorque or 1.0

    for _, modifier in pairs(modifiers[state.vehicle] or NO_MODIFIERS) do
        speed = math.min(speed, modifier.speed)
        torque = torque * modifier.torque
    end

    if speed ~= state.speed then
        SetVehicleMaxSpeed(state.vehicle, speed < 1.0 and state.baseSpeed * speed or 0.0)
        state.speed = speed
    end

    state.torque = torque
end

---@param vehicle integer
---@return boolean
local function shouldBlockFlip(vehicle)
    return Config.PreventFlipControl and GetVehicleClass(vehicle) ~= BIKE_CLASS and (IsEntityUpsidedown(vehicle) or math.abs(GetEntityRoll(vehicle)) > FLIP_ROLL)
end

CreateThread(function()
    local lastTick = GetGameTimer()

    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            if not current or current.vehicle ~= vehicle then
                if current then
                    release(current)
                end

                current = track(vehicle)
                lastTick = GetGameTimer()
            end

            local multiplier = getClassMultiplier(vehicle)
            local now = GetGameTimer()

            if now - lastTick >= TICK_MS then
                local seconds = (now - lastTick) / 1000.0
                lastTick = now

                if multiplier then
                    local engine = GetVehicleEngineHealth(vehicle)

                    if engine > current.engine + 1.0 then
                        current.engine = engine
                        current.body = GetVehicleBodyHealth(vehicle)
                        current.tank = GetVehiclePetrolTankHealth(vehicle)
                    end

                    applyCollisionDamage(current, multiplier)
                    applyEngineState(current, seconds)
                end

                applyPower(current)
            end

            sleep = TICK_MS

            if current.torque ~= 1.0 then
                SetVehicleEngineTorqueMultiplier(vehicle, current.torque)
                sleep = 0
            end

            if multiplier and shouldBlockFlip(vehicle) then
                DisableControlAction(0, CONTROL_LEAN_LR, true)
                DisableControlAction(0, CONTROL_LEAN_UD, true)
                sleep = 0
            end
        elseif current then
            release(current)
            current = nil
        end

        Wait(sleep)
    end
end)

exports("AddEngineWear", function(vehicle, amount)
    amount = tonumber(amount)

    if not amount or amount <= 0.0 or not vehicle or not DoesEntityExist(vehicle) then
        return
    end

    local health = GetVehicleEngineHealth(vehicle)
    local engine = math.max(math.min(health, Config.Engine.FailureHealth), health - amount)
    SetVehicleEngineHealth(vehicle, engine)

    if current and current.vehicle == vehicle then
        current.engine = engine
    end
end)

exports("SetModifier", function(vehicle, key, speed, torque)
    speed, torque = tonumber(speed), tonumber(torque)

    if not vehicle or type(key) ~= "string" then
        return
    end

    local list = modifiers[vehicle]

    if not speed and not torque then
        if list then
            list[key] = nil
            modifiers[vehicle] = next(list) and list or nil
        end

        return
    end

    if not list then
        list = {}
        modifiers[vehicle] = list
    end

    local modifier = list[key]

    if not modifier then
        modifier = {}
        list[key] = modifier
    end

    modifier.speed = math.max(0.0, math.min(1.0, speed or 1.0))
    modifier.torque = math.max(0.0, torque or 1.0)
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() and current then
        release(current)
    end
end)
