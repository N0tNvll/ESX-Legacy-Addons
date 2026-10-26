-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local PETROLCAN <const> = `WEAPON_PETROLCAN`
local PUMP_RANGE <const> = 2.0
local PUMP_SCAN_MS <const> = 250
local INTERACT_KEY <const> = 38

local pumpHashes = {}

for i = 1, #Config.PumpModels do
    pumpHashes[i] = joaat(Config.PumpModels[i])
end

---@param coords vector3
---@return integer?
local function findPump(coords)
    for i = 1, #pumpHashes do
        local pump = GetClosestObjectOfType(coords.x, coords.y, coords.z, PUMP_RANGE, pumpHashes[i], false, false, false)

        if pump ~= 0 then
            return pump
        end
    end

    return nil
end

---@param coords vector3
---@return boolean
local function isAtCharger(coords)
    for i = 1, #Config.Chargers do
        local charger = Config.Chargers[i]

        if #(coords - charger.coords) <= (charger.radius or 6.0) then
            return true
        end
    end

    return false
end

---@param pressed boolean
---@return string
local function handleFilling(pressed)
    if pressed then
        Pump.cancelFilling = true
    end

    return _U("text_stop")
end

---@param hose FuelHose
---@param coords vector3
---@param pressed boolean
---@return string?
local function handleHose(hose, coords, pressed)
    if not DoesEntityExist(hose.pump) or #(coords - hose.pumpCoords) > Config.Refuel.HoseLength + 1.0 then
        Pump.releaseHose()
        ESX.ShowNotification(_U("hose_dropped"))
        return nil
    end

    if Pump.filling then
        return handleFilling(pressed)
    end

    local vehicle = Fuel.getVehicleAtTank(coords)

    if vehicle then
        if pressed then
            Pump.openForVehicle(vehicle)
        end

        return Fuel.getKind(vehicle) == "electric" and _U("text_charge") or _U("text_refuel")
    end

    if #(coords - hose.pumpCoords) <= PUMP_RANGE then
        if pressed then
            Pump.releaseHose()
        end

        return _U("text_return")
    end

    return nil
end

---@param ped integer
---@param pump integer
---@param pressed boolean
---@return string
local function handlePump(ped, pump, pressed)
    if Config.JerryCan.Enabled and GetSelectedPedWeapon(ped) == PETROLCAN then
        if pressed then
            Pump.openForCan()
        end

        return _U("text_fill_can")
    end

    if pressed then
        Pump.takeNozzle(pump)
    end

    return _U("text_take")
end

---@param coords vector3
---@param pressed boolean
---@return string?
local function handleCharger(coords, pressed)
    local vehicle = Fuel.getVehicleAtTank(coords)

    if not vehicle or Fuel.getKind(vehicle) ~= "electric" then
        return nil
    end

    if pressed then
        Pump.openForVehicle(vehicle)
    end

    return _U("text_charge")
end

CreateThread(function()
    local pumpScanAt = 0
    local nearPump

    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local pressed = Fuel.isShown("pump") and IsControlJustReleased(0, INTERACT_KEY)
        local text

        if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then
            Pump.releaseHose()
        elseif not Pump.uiTarget then
            local coords = GetEntityCoords(ped)

            if Pump.hose then
                sleep = 0
                text = handleHose(Pump.hose, coords, pressed)
            elseif Pump.filling then
                sleep = 0
                text = handleFilling(pressed)
            elseif not Fuel.isBusy() then
                local now = GetGameTimer()

                if now >= pumpScanAt then
                    nearPump = findPump(coords)
                    pumpScanAt = now + PUMP_SCAN_MS
                end

                if nearPump and DoesEntityExist(nearPump) then
                    sleep = 0
                    text = handlePump(ped, nearPump, pressed)
                elseif #Config.Chargers > 0 and isAtCharger(coords) then
                    text = handleCharger(coords, pressed)

                    if text then
                        sleep = 0
                    end
                end
            end
        end

        Fuel.hint("pump", text)
        Wait(sleep)
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    Pump.releaseHose()

    if Pump.uiTarget then
        SetNuiFocus(false, false)
    end

    ESX.HideUI()
end)
