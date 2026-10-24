-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local NOZZLE_MODEL <const> = `prop_cs_fuel_nozle`
local PETROLCAN <const> = `WEAPON_PETROLCAN`
local CAN_MAX_AMMO <const> = 4500
local HAND_BONE <const> = 18905
local FILL_DICT <const> = "timetable@gardener@filling_can"
local FILL_ANIM <const> = "gar_ig_5_filling_can"
local PUMP_RANGE <const> = 2.0
local PUMP_SCAN_MS <const> = 250
local INTERACT_KEY <const> = 38

local pumpHashes = {}

for i = 1, #Config.PumpModels do
    pumpHashes[i] = joaat(Config.PumpModels[i])
end

---@class FuelHose
---@field pump integer
---@field pumpCoords vector3
---@field nozzle integer
---@field rope integer?

---@type FuelHose?
local hose

local filling = false
local cancelFilling = false
local uiTarget

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

---@param model integer
---@return boolean
local function requestModel(model)
    RequestModel(model)

    local deadline = GetGameTimer() + 5000

    while not HasModelLoaded(model) and GetGameTimer() < deadline do
        Wait(0)
    end

    return HasModelLoaded(model)
end

local function releaseHose()
    if not hose then
        return
    end

    if hose.rope and DoesRopeExist(hose.rope) then
        DeleteRope(hose.rope)
    end

    if DoesEntityExist(hose.nozzle) then
        DeleteEntity(hose.nozzle)
    end

    hose = nil
    Fuel.setBusy("hose", false)
end

---@param pump integer
local function takeNozzle(pump)
    if not requestModel(NOZZLE_MODEL) then
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local nozzle = CreateObject(NOZZLE_MODEL, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(NOZZLE_MODEL)
    AttachEntityToEntity(nozzle, ped, GetPedBoneIndex(ped, HAND_BONE), 0.11, 0.02, 0.02, -80.0, -90.0, 15.0, true, true, false, true, 1, true)

    local pumpCoords = GetEntityCoords(pump)
    local rope

    RopeLoadTextures()

    local deadline = GetGameTimer() + 2000

    while not RopeAreTexturesLoaded() and GetGameTimer() < deadline do
        Wait(0)
    end

    if RopeAreTexturesLoaded() then
        rope = AddRope(pumpCoords.x, pumpCoords.y, pumpCoords.z + 1.4, 0.0, 0.0, 0.0, Config.Refuel.HoseLength, 1, Config.Refuel.HoseLength, 0.0, 1.0, false, false, false, 1.0, true)
        ActivatePhysics(rope)

        local nozzleCoords = GetOffsetFromEntityInWorldCoords(nozzle, 0.0, -0.033, -0.195)
        AttachEntitiesToRope(rope, pump, nozzle, pumpCoords.x, pumpCoords.y, pumpCoords.z + 1.4, nozzleCoords.x, nozzleCoords.y, nozzleCoords.z, Config.Refuel.HoseLength, false, false, nil, nil)
    end

    hose = { pump = pump, pumpCoords = pumpCoords, nozzle = nozzle, rope = rope }
    Fuel.setBusy("hose", true)
end

---@return number money
---@return number bank
local function getWallet()
    local money, bank = 0, 0

    for _, account in ipairs(ESX.PlayerData.accounts or {}) do
        if account.name == "money" then
            money = account.money
        elseif account.name == "bank" then
            bank = account.money
        end
    end

    return money, bank
end

---@param kind string
---@return table[] fuels
---@return table station
local function getFuelsFor(kind)
    local fuels = {}
    local ok, station = pcall(xLib.callback.await, "esx_fuel:getStation", false)
    station = ok and type(station) == "table" and station or {}
    local multiplier = tonumber(station.priceMultiplier) or 1.0

    for i = 1, #Config.FuelTypes do
        local fuel = Config.FuelTypes[i]

        if (kind == "electric") == (fuel.kind == "electric") then
            fuels[#fuels + 1] = {
                name = fuel.name,
                kind = fuel.kind,
                octane = fuel.octane,
                price = fuel.price * multiplier,
                label = _(("fuel_%s"):format(fuel.name))
            }
        end
    end

    return fuels, station
end

local function closeUi()
    uiTarget = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
end

---@param target { type: "vehicle"|"can", vehicle?: integer, kind: string, capacity: number, liters: number }
local function openPump(target)
    local fuels, station = getFuelsFor(target.kind)
    local money, bank = getWallet()

    uiTarget = target
    Fuel.hint("pump", nil)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "open",
        vehicle = {
            kind = target.kind,
            capacity = target.capacity,
            liters = target.liters,
            unit = target.kind == "electric" and "kWh" or "L",
            can = target.type == "can"
        },
        fuels = fuels,
        stock = target.kind ~= "electric" and station.stock or nil,
        wallet = { money = money, bank = bank },
        accounts = Config.Refuel.PayWith,
        maxLiters = Config.Refuel.MaxLitersPerPurchase,
        locale = Fuel.getUILocale(),
        theme = xLib.colors.getESXTheme()
    })
end

---@param vehicle integer
local function openForVehicle(vehicle)
    local capacity = Fuel.getCapacity(vehicle)

    openPump({
        type = "vehicle",
        vehicle = vehicle,
        kind = Fuel.getKind(vehicle),
        capacity = capacity,
        liters = capacity * Fuel.getLevel(vehicle) / 100.0
    })
end

local function openForCan()
    local ammo = GetAmmoInPedWeapon(PlayerPedId(), PETROLCAN)

    openPump({
        type = "can",
        kind = "petrol",
        capacity = Config.JerryCan.Liters,
        liters = Config.JerryCan.Liters * ammo / CAN_MAX_AMMO
    })
end

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
local function fillVehicle(vehicle, fuel, liters, price)
    filling = true
    cancelFilling = false
    Fuel.setBusy("filling", true)

    if not Fuel.requestControl(vehicle) then
        pcall(xLib.callback.await, "esx_fuel:finishRefuel", false, 0)
        filling = false
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

    while delivered < liters and not cancelFilling do
        Wait(100)

        if not DoesEntityExist(vehicle) or (hose == nil and fuel.kind ~= "electric") or #(GetEntityCoords(ped) - Fuel.getTankCoords(vehicle)) > Config.Refuel.TankDistance + 2.0 then
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
    filling = false
    Fuel.setBusy("filling", false)

    local unit = fuel.kind == "electric" and "kWh" or "L"

    if called and ok and refund and refund > 0 then
        ESX.ShowNotification(_U("refuel_refund", math.floor(delivered + 0.5), unit, refund))
    else
        ESX.ShowNotification(_U("refuel_done", math.floor(delivered + 0.5), unit))
    end
end

RegisterNUICallback("close", function(_, cb)
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback("confirm", function(data, cb)
    cb({ ok = true })

    local target = uiTarget
    closeUi()

    if type(data) ~= "table" or filling or not target then
        return
    end

    local fuel = Fuel.getFuelType(data.fuel)

    if not fuel then
        return
    end

    if target.type == "can" then
        local called, ok, result, granted = pcall(xLib.callback.await, "esx_fuel:buyCan", false, fuel.name, data.account)

        if not called or not ok then
            return ESX.ShowNotification(_U(("error_%s"):format(called and result or "invalid")))
        end

        SetPedAmmo(PlayerPedId(), PETROLCAN, CAN_MAX_AMMO)
        return ESX.ShowNotification(_U("can_filled", math.floor(granted + 0.5), result))
    end

    local vehicle = target.vehicle
    local liters = math.floor(tonumber(data.liters) or 0)

    if liters < 1 or not vehicle or not DoesEntityExist(vehicle) then
        return
    end

    local called, ok, result = pcall(xLib.callback.await, "esx_fuel:startRefuel", false, NetworkGetNetworkIdFromEntity(vehicle), fuel.name, liters, data.account)

    if not called or not ok then
        result = called and result or "invalid"

        return ESX.ShowNotification(_U(("error_%s"):format(result or "invalid")))
    end

    fillVehicle(vehicle, fuel, liters, result)
end)

CreateThread(function()
    local pumpScanAt = 0
    local nearPump

    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local pressed = Fuel.isShown("pump") and IsControlJustReleased(0, INTERACT_KEY)
        local text

        if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then
            releaseHose()
        elseif not uiTarget then
            local coords = GetEntityCoords(ped)

            if hose then
                sleep = 0

                if not DoesEntityExist(hose.pump) or #(coords - hose.pumpCoords) > Config.Refuel.HoseLength + 1.0 then
                    releaseHose()
                    ESX.ShowNotification(_U("hose_dropped"))
                elseif filling then
                    text = _U("text_stop")

                    if pressed then
                        cancelFilling = true
                    end
                else
                    local vehicle = Fuel.getVehicleAtTank(coords)

                    if vehicle then
                        text = Fuel.getKind(vehicle) == "electric" and _U("text_charge") or _U("text_refuel")

                        if pressed then
                            openForVehicle(vehicle)
                        end
                    elseif #(coords - hose.pumpCoords) <= PUMP_RANGE then
                        text = _U("text_return")

                        if pressed then
                            releaseHose()
                        end
                    end
                end
            elseif filling then
                sleep = 0
                text = _U("text_stop")

                if pressed then
                    cancelFilling = true
                end
            elseif not Fuel.isBusy() then
                local now = GetGameTimer()

                if now >= pumpScanAt then
                    nearPump = findPump(coords)
                    pumpScanAt = now + PUMP_SCAN_MS
                end

                if nearPump and DoesEntityExist(nearPump) then
                    sleep = 0

                    if Config.JerryCan.Enabled and GetSelectedPedWeapon(ped) == PETROLCAN then
                        text = _U("text_fill_can")

                        if pressed then
                            openForCan()
                        end
                    else
                        text = _U("text_take")

                        if pressed then
                            takeNozzle(nearPump)
                        end
                    end
                elseif #Config.Chargers > 0 and isAtCharger(coords) then
                    local vehicle = Fuel.getVehicleAtTank(coords)

                    if vehicle and Fuel.getKind(vehicle) == "electric" then
                        sleep = 0
                        text = _U("text_charge")

                        if pressed then
                            openForVehicle(vehicle)
                        end
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

    releaseHose()

    if uiTarget then
        SetNuiFocus(false, false)
    end

    ESX.HideUI()
end)
