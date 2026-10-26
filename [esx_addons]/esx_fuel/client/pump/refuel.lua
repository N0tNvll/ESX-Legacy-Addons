-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local FILL_DICT <const> = "timetable@gardener@filling_can"
local FILL_ANIM <const> = "gar_ig_5_filling_can"

---@param ped integer
local function playFillAnim(ped)
    RequestAnimDict(FILL_DICT)

    local deadline = GetGameTimer() + 2000

    while not HasAnimDictLoaded(FILL_DICT) and GetGameTimer() < deadline do
        Wait(0)
    end

    TaskPlayAnim(ped, FILL_DICT, FILL_ANIM, 2.0, 8.0, -1, 50, 0, false, false, false)
end

---@param ped integer
local function stopFillAnim(ped)
    StopAnimTask(ped, FILL_DICT, FILL_ANIM, 1.0)
    RemoveAnimDict(FILL_DICT)
end

---@param vehicle integer
---@param fuel table
---@param liters integer
---@param price integer
function Pump.fillVehicle(vehicle, fuel, liters, price)
    Pump.filling = true
    Pump.cancelFilling = false
    Fuel.setBusy("filling", true)

    if not Fuel.requestControl(vehicle) then
        pcall(xLib.callback.await, "esx_fuel:finishRefuel", false, 0)
        Pump.filling = false
        Fuel.setBusy("filling", false)
        return ESX.ShowNotification(_U("error_control"))
    end

    Fuel.loadLevel(vehicle)

    local ped = PlayerPedId()
    local capacity = Fuel.getCapacity(vehicle)
    local startLiters = capacity * Fuel.getLevel(vehicle) / 100.0
    local startMix = Fuel.getMix(vehicle)
    local rate = fuel.kind == "electric" and Config.Refuel.ChargePerSecond or Config.Refuel.LitersPerSecond
    local delivered = 0.0

    if fuel.kind ~= "electric" then
        playFillAnim(ped)
    end

    local lastTick = GetGameTimer()

    SendNUIMessage({ action = "filling", target = liters, price = price, unit = fuel.kind == "electric" and "kWh" or "L" })

    while delivered < liters and not Pump.cancelFilling do
        Wait(100)

        if not DoesEntityExist(vehicle) or (Pump.hose == nil and fuel.kind ~= "electric") or #(GetEntityCoords(ped) - Fuel.getTankCoords(vehicle)) > Config.Refuel.TankDistance + 2.0 then
            break
        end

        local now = GetGameTimer()
        local step = math.min(liters - delivered, (now - lastTick) / 1000.0 * rate)
        lastTick = now

        local current = startLiters + delivered

        if current + step >= capacity then
            delivered = delivered + math.max(0.0, capacity - current)
            break
        end

        delivered = delivered + step
        Fuel.setLevel(vehicle, (startLiters + delivered) / capacity * 100.0, false)
        SendNUIMessage({ action = "progress", delivered = delivered })
    end

    stopFillAnim(ped)

    if DoesEntityExist(vehicle) then
        Fuel.setLevel(vehicle, math.min(capacity, startLiters + delivered) / capacity * 100.0, true)
        Fuel.setMix(vehicle, FuelMix.add(startMix, startLiters, delivered, fuel))
    end

    local called, ok, refund = pcall(xLib.callback.await, "esx_fuel:finishRefuel", false, delivered)

    SendNUIMessage({ action = "done" })
    Pump.filling = false
    Fuel.setBusy("filling", false)

    local unit = fuel.kind == "electric" and "kWh" or "L"

    if called and ok and refund and refund > 0 then
        ESX.ShowNotification(_U("refuel_refund", math.floor(delivered + 0.5), unit, refund))
    else
        ESX.ShowNotification(_U("refuel_done", math.floor(delivered + 0.5), unit))
    end
end
