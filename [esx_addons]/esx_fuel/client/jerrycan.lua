-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local PETROLCAN <const> = `WEAPON_PETROLCAN`
local CAN_MAX_AMMO <const> = 4500
local POUR_DICT <const> = "weapon@w_sp_jerrycan"
local POUR_ANIM <const> = "fire"
local INTERACT_KEY <const> = 38

if not Config.JerryCan.Enabled then
    return
end

local pouring = false
local cancelPouring = false

---@return table
local function getCanFuel()
    local metadata = ESX.PlayerData.metadata or {}

    return Fuel.getFuelType(metadata.fuelCan) or Config.FuelTypes[1]
end

---@param vehicle integer
local function pour(vehicle)
    local ped = PlayerPedId()

    pouring = true
    cancelPouring = false
    Fuel.setBusy("can", true)

    if not Fuel.requestControl(vehicle) then
        pouring = false
        Fuel.setBusy("can", false)
        return ESX.ShowNotification(_U("error_vehicle"))
    end

    Fuel.loadLevel(vehicle)

    local fuel = getCanFuel()
    local capacity = Fuel.getCapacity(vehicle)
    local startLiters = capacity * Fuel.getLevel(vehicle) / 100.0
    local startMix = Fuel.getMix(vehicle)
    local canLiters = Config.JerryCan.Liters * GetAmmoInPedWeapon(ped, PETROLCAN) / CAN_MAX_AMMO
    local poured = 0.0

    RequestAnimDict(POUR_DICT)

    local deadline = GetGameTimer() + 2000

    while not HasAnimDictLoaded(POUR_DICT) and GetGameTimer() < deadline do
        Wait(0)
    end

    TaskPlayAnim(ped, POUR_DICT, POUR_ANIM, 2.0, 8.0, -1, 50, 0, false, false, false)

    local lastTick = GetGameTimer()

    while not cancelPouring and poured < canLiters and startLiters + poured < capacity do
        Wait(100)

        if not DoesEntityExist(vehicle) or GetSelectedPedWeapon(ped) ~= PETROLCAN or #(GetEntityCoords(ped) - Fuel.getTankCoords(vehicle)) > Config.Refuel.TankDistance + 1.0 then
            break
        end

        local now = GetGameTimer()
        local step = math.min(canLiters - poured, capacity - startLiters - poured, (now - lastTick) / 1000.0 * Config.JerryCan.PourLitersPerSecond)
        lastTick = now
        poured = poured + step

        Fuel.setLevel(vehicle, (startLiters + poured) / capacity * 100.0, false)
        SetPedAmmo(ped, PETROLCAN, math.max(1, math.floor((canLiters - poured) / Config.JerryCan.Liters * CAN_MAX_AMMO)))
    end

    StopAnimTask(ped, POUR_DICT, POUR_ANIM, 1.0)
    RemoveAnimDict(POUR_DICT)

    if DoesEntityExist(vehicle) then
        Fuel.setLevel(vehicle, (startLiters + poured) / capacity * 100.0, true)
        Fuel.setMix(vehicle, FuelMix.add(startMix, startLiters, poured, fuel))
    end

    TriggerServerEvent("esx_fuel:syncCan", GetAmmoInPedWeapon(ped, PETROLCAN))
    pouring = false
    Fuel.setBusy("can", false)
    ESX.ShowNotification(_U("can_poured", math.floor(poured + 0.5)))
end

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local pressed = Fuel.isShown("can") and IsControlJustReleased(0, INTERACT_KEY)
        local text

        if pouring then
            sleep = 0
            text = _U("text_stop")

            if pressed then
                cancelPouring = true
            end
        elseif not IsPedInAnyVehicle(ped, false) and GetSelectedPedWeapon(ped) == PETROLCAN and GetAmmoInPedWeapon(ped, PETROLCAN) > 1 and not Fuel.isBusy() then
            local vehicle = Fuel.getVehicleAtTank(GetEntityCoords(ped))

            if vehicle and Fuel.getKind(vehicle) ~= "electric" then
                sleep = 0
                text = _U("text_pour")

                if pressed then
                    pouring = true
                    Fuel.hint("can", nil)
                    CreateThread(function()
                        pour(vehicle)
                    end)
                end
            end
        end

        Fuel.hint("can", text)
        Wait(sleep)
    end
end)
