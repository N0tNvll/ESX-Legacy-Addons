-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local PETROLCAN <const> = `WEAPON_PETROLCAN`
local CAN_MAX_AMMO <const> = 4500

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

---@param target FuelPumpTarget
local function openPump(target)
    local fuels, station = getFuelsFor(target.kind)
    local money, bank = getWallet()

    Pump.uiTarget = target
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

function Pump.closeUi()
    Pump.uiTarget = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
end

---@param vehicle integer
function Pump.openForVehicle(vehicle)
    local capacity = Fuel.getCapacity(vehicle)

    openPump({
        type = "vehicle",
        vehicle = vehicle,
        kind = Fuel.getKind(vehicle),
        capacity = capacity,
        liters = capacity * Fuel.getLevel(vehicle) / 100.0
    })
end

function Pump.openForCan()
    local ammo = GetAmmoInPedWeapon(PlayerPedId(), PETROLCAN)

    openPump({
        type = "can",
        kind = "petrol",
        capacity = Config.JerryCan.Liters,
        liters = Config.JerryCan.Liters * ammo / CAN_MAX_AMMO
    })
end

---@param fuel table
---@param account string
local function buyCan(fuel, account)
    local called, ok, result, granted = pcall(xLib.callback.await, "esx_fuel:buyCan", false, fuel.name, account)

    if not called or not ok then
        return ESX.ShowNotification(_U(("error_%s"):format(called and result or "invalid")))
    end

    SetPedAmmo(PlayerPedId(), PETROLCAN, CAN_MAX_AMMO)
    ESX.ShowNotification(_U("can_filled", math.floor(granted + 0.5), result))
end

---@param target FuelPumpTarget
---@param fuel table
---@param liters any
---@param account string
local function buyRefuel(target, fuel, liters, account)
    local vehicle = target.vehicle
    liters = math.floor(tonumber(liters) or 0)

    if liters < 1 or not vehicle or not DoesEntityExist(vehicle) then
        return
    end

    local called, ok, result = pcall(xLib.callback.await, "esx_fuel:startRefuel", false, NetworkGetNetworkIdFromEntity(vehicle), fuel.name, liters, account)

    if not called or not ok then
        return ESX.ShowNotification(_U(("error_%s"):format(called and result or "invalid")))
    end

    Pump.fillVehicle(vehicle, fuel, liters, result)
end

RegisterNUICallback("close", function(_, cb)
    Pump.closeUi()
    cb({ ok = true })
end)

RegisterNUICallback("confirm", function(data, cb)
    cb({ ok = true })

    local target = Pump.uiTarget
    Pump.closeUi()

    if type(data) ~= "table" or Pump.filling or not target then
        return
    end

    local fuel = Fuel.getFuelType(data.fuel)

    if not fuel then
        return
    end

    if target.type == "can" then
        buyCan(fuel, data.account)
    else
        buyRefuel(target, fuel, data.liters, data.account)
    end
end)
