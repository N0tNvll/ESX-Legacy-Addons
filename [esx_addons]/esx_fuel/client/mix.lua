-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local MIX_BAG <const> = "fuelMix"
local DRAIN_DICT <const> = "mini@repair"
local DRAIN_ANIM <const> = "fixing_a_ped"
local DRAIN_KEY <const> = 47
local FAILURE_RESOURCE <const> = "esx_vehiclefailure"
local MODIFIER_KEY <const> = "esx_fuel"

local requested = {}
local powered = 0
local poweredSpeed = 1.0
local baseSpeed = 0.0

---@param vehicle integer
---@return FuelMixData
function Fuel.getMix(vehicle)
    return FuelMix.sanitize(Entity(vehicle).state[MIX_BAG], Fuel.getKind(vehicle))
end

---@param vehicle integer
---@param mix FuelMixData
---@return boolean published
function Fuel.setMix(vehicle, mix)
    if not NetworkGetEntityIsNetworked(vehicle) or NetworkGetEntityOwner(vehicle) ~= PlayerId() then
        return false
    end

    local kind = Fuel.getKind(vehicle)
    mix = FuelMix.sanitize(mix, kind)
    Entity(vehicle).state:set(MIX_BAG, not FuelMix.isClean(mix, kind) and mix or nil, true)

    return true
end

---@param vehicle integer
function Fuel.loadMix(vehicle)
    if Entity(vehicle).state[MIX_BAG] ~= nil or requested[vehicle] then
        return
    end

    requested[vehicle] = true

    CreateThread(function()
        local ok, mix = pcall(xLib.callback.await, "esx_fuel:getMix", false, NetworkGetNetworkIdFromEntity(vehicle))

        if not ok or (type(mix) == "table" and DoesEntityExist(vehicle) and not Fuel.setMix(vehicle, mix)) then
            requested[vehicle] = nil
        end
    end)
end

---@return boolean
local function hasFailure()
    return GetResourceState(FAILURE_RESOURCE) == "started"
end

---@param vehicle integer
local function resetPower(vehicle)
    if hasFailure() then
        exports[FAILURE_RESOURCE]:SetModifier(vehicle, MODIFIER_KEY)
    elseif poweredSpeed < 1.0 and DoesEntityExist(vehicle) then
        SetVehicleMaxSpeed(vehicle, 0.0)
    end

    powered, poweredSpeed = 0, 1.0
end

---@param vehicle integer
---@param speed number
---@param torque number
---@return boolean applyTorque
local function setPower(vehicle, speed, torque)
    if powered ~= vehicle then
        if powered ~= 0 then
            resetPower(powered)
        end

        powered = vehicle
        baseSpeed = GetVehicleEstimatedMaxSpeed(vehicle)
    end

    local neutral = speed >= 1.0 and torque == 1.0

    if hasFailure() then
        if neutral then
            exports[FAILURE_RESOURCE]:SetModifier(vehicle, MODIFIER_KEY)
        else
            exports[FAILURE_RESOURCE]:SetModifier(vehicle, MODIFIER_KEY, speed, torque)
        end

        poweredSpeed = 1.0
        return false
    end

    if speed ~= poweredSpeed then
        SetVehicleMaxSpeed(vehicle, speed < 1.0 and baseSpeed * speed or 0.0)
        poweredSpeed = speed
    end

    return torque ~= 1.0
end

---@param vehicle integer
---@param wear number
local function wearEngine(vehicle, wear)
    if hasFailure() then
        exports[FAILURE_RESOURCE]:AddEngineWear(vehicle, wear)
    else
        SetVehicleEngineHealth(vehicle, math.max(100.0, GetVehicleEngineHealth(vehicle) - wear))
    end
end

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and Fuel.usesFuel(vehicle) then
            local kind = Fuel.getKind(vehicle)
            local mix = Fuel.getMix(vehicle)
            local bad = FuelMix.wrongShare(mix, kind)
            local speed, torque = 1.0, 1.0

            Fuel.loadMix(vehicle)

            if bad > Config.WrongFuel.Tolerance then
                speed = 1.0 - bad * Config.WrongFuel.PowerLoss

                if GetIsVehicleEngineRunning(vehicle) then
                    if math.random() < bad * Config.WrongFuel.StallChance then
                        SetVehicleEngineOn(vehicle, false, false, true)
                    end

                    wearEngine(vehicle, bad * Config.WrongFuel.EngineDamage)
                end
            elseif kind == "petrol" and mix.octane > Config.DefaultOctane then
                torque = 1.0 + (mix.octane - Config.DefaultOctane) * Config.OctaneBonus
            end

            if setPower(vehicle, speed, torque) then
                local deadline = GetGameTimer() + 1000

                while GetGameTimer() < deadline and GetVehiclePedIsIn(ped, false) == vehicle do
                    SetVehicleEngineTorqueMultiplier(vehicle, torque)
                    Wait(0)
                end

                sleep = 0
            end
        elseif powered ~= 0 then
            resetPower(powered)
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(60000)

        for vehicle in pairs(requested) do
            if not DoesEntityExist(vehicle) then
                requested[vehicle] = nil
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() and powered ~= 0 then
        resetPower(powered)
    end
end)

if Config.Drain.Enabled then
    ---@return boolean
    local function canDrain()
        local job = ESX.PlayerData.job
        local minimum = job and Config.Drain.Jobs[job.name]

        return minimum ~= nil and (tonumber(job.grade) or 0) >= minimum
    end

    ---@param message string
    local function stopDrain(message)
        ClearPedTasks(PlayerPedId())
        RemoveAnimDict(DRAIN_DICT)
        Fuel.setBusy("drain", false)
        ESX.ShowNotification(_U(message))
    end

    ---@param vehicle integer
    local function drain(vehicle)
        local ped = PlayerPedId()

        Fuel.setBusy("drain", true)

        if not Fuel.requestControl(vehicle) then
            return stopDrain("error_vehicle")
        end

        RequestAnimDict(DRAIN_DICT)

        local deadline = GetGameTimer() + 2000

        while not HasAnimDictLoaded(DRAIN_DICT) and GetGameTimer() < deadline do
            Wait(0)
        end

        TaskPlayAnim(ped, DRAIN_DICT, DRAIN_ANIM, 2.0, 8.0, Config.Drain.Duration, 1, 0, false, false, false)

        local finish = GetGameTimer() + Config.Drain.Duration

        while GetGameTimer() < finish do
            Wait(100)

            if not DoesEntityExist(vehicle) or #(GetEntityCoords(ped) - Fuel.getTankCoords(vehicle)) > Config.Refuel.TankDistance + 1.0 then
                return stopDrain("drain_cancelled")
            end
        end

        if not Fuel.requestControl(vehicle) then
            return stopDrain("error_vehicle")
        end

        Fuel.setLevel(vehicle, 0.0, true)
        Fuel.setMix(vehicle, FuelMix.default(Fuel.getKind(vehicle)))
        stopDrain("drain_done")
    end

    CreateThread(function()
        while true do
            local sleep = 1000
            local vehicle

            if canDrain() and not Fuel.isBusy() and not IsPedInAnyVehicle(PlayerPedId(), false) then
                vehicle = Fuel.getVehicleAtTank(GetEntityCoords(PlayerPedId()))

                if vehicle and Fuel.getKind(vehicle) == "electric" then
                    vehicle = nil
                end
            end

            if vehicle then
                sleep = 0
                Fuel.hint("drain", _U("text_drain"))

                if IsControlJustReleased(0, DRAIN_KEY) then
                    Fuel.hint("drain", nil)
                    drain(vehicle)
                end
            else
                Fuel.hint("drain", nil)
            end

            Wait(sleep)
        end
    end)
end
