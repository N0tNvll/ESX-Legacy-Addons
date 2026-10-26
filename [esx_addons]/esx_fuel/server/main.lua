-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local MAX_VEHICLE_DISTANCE <const> = 8.0
local PETROLCAN <const> = "WEAPON_PETROLCAN"
local CAN_MAX_AMMO <const> = 4500
local MIX_BAG <const> = "fuelMix"
local MIX_SAVE_DELAY <const> = 5000
local MAX_PENDING_MIX_SAVES <const> = 3
local SESSION_SWEEP_MS <const> = 30000

---@class FuelSession
---@field netId integer
---@field fuel string
---@field liters integer
---@field pricePerLiter number
---@field paid integer
---@field account string
---@field station integer?
---@field expiresAt integer

---@type table<number, FuelSession>
local sessions = {}

---@type table<string, table>
local mixes = {}
local pendingMixSaves = {}
local pendingMixSavesByPlayer = {}

---@class FuelStation
---@field stock integer
---@field reserved integer
---@field priceMultiplier number

---@type table<integer, FuelStation>
local stations = {}

local fuelTypes = {}

for i = 1, #Config.FuelTypes do
    fuelTypes[Config.FuelTypes[i].name] = Config.FuelTypes[i]
end

local payAccounts = {}

for i = 1, #Config.Refuel.PayWith do
    payAccounts[Config.Refuel.PayWith[i]] = true
end

---@param plate any
---@return string?
local function normalizePlate(plate)
    if type(plate) ~= "string" then
        return nil
    end

    plate = plate:upper():match("^%s*(.-)%s*$")

    return plate ~= "" and plate or nil
end

---@param index integer
---@return FuelStation
local function getStation(index)
    local station = stations[index]

    if not station then
        station = { stock = Config.Stock.Default, reserved = 0, priceMultiplier = 1.0 }
        stations[index] = station
    end

    return station
end

---@param index integer
local function saveStation(index)
    local station = getStation(index)

    MySQL.prepare("INSERT INTO esx_fuel_stations (id, stock, price_multiplier) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE stock = VALUES(stock), price_multiplier = VALUES(price_multiplier)", {
        index, station.stock, station.priceMultiplier
    })
end

---@param playerId number
---@return integer? stationIndex
---@return boolean atCharger
local function getLocation(playerId)
    local coords = GetEntityCoords(GetPlayerPed(playerId))

    for i = 1, #Config.Stations do
        if #(coords - Config.Stations[i]) <= Config.StationRadius then
            return i, false
        end
    end

    for i = 1, #Config.Chargers do
        local charger = Config.Chargers[i]

        if #(coords - charger.coords) <= (charger.radius or 6.0) + 2.0 then
            return nil, true
        end
    end

    return nil, false
end

---@param playerId number
---@param netId any
---@return integer?
local function getNearbyVehicle(playerId, netId)
    netId = tonumber(netId)

    if not netId then
        return nil
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)

    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
        return nil
    end

    if #(GetEntityCoords(GetPlayerPed(playerId)) - GetEntityCoords(vehicle)) > MAX_VEHICLE_DISTANCE then
        return nil
    end

    return vehicle
end

---@param society string
---@param amount integer
local function creditSociety(society, amount)
    if amount <= 0 then
        return
    end

    TriggerEvent("esx_addonaccount:getSharedAccount", society, function(account)
        if account then
            account.addMoney(amount)
        end
    end)
end

---@param society string
---@param amount integer
---@return boolean
local function debitSociety(society, amount)
    local paid = false

    TriggerEvent("esx_addonaccount:getSharedAccount", society, function(account)
        if account and account.money >= amount then
            account.removeMoney(amount)
            paid = true
        end
    end)

    return paid
end

---@param playerId number
---@param session FuelSession
---@param delivered any
---@return integer refund
local function closeSession(playerId, session, delivered)
    sessions[playerId] = nil

    delivered = math.max(0.0, math.min(tonumber(delivered) or 0.0, session.liters))
    local refund = math.min(session.paid, math.floor((session.liters - delivered) * session.pricePerLiter))

    if refund > 0 then
        local xPlayer = ESX.GetPlayerFromId(playerId)

        if xPlayer then
            xPlayer.addAccountMoney(session.account, refund, "Fuel refund")
        end
    end

    if Config.Stock.Enabled and session.station then
        local station = getStation(session.station)
        station.reserved = math.max(0, station.reserved - session.liters)
        station.stock = math.max(0, station.stock - math.ceil(delivered - 1e-9))
        saveStation(session.station)

        local owner = Config.Stock.Owners[session.station]

        if owner then
            creditSociety(owner, session.paid - refund)
        end
    end

    return refund
end

xLib.callback.register("esx_fuel:getStation", function(source)
    local index = getLocation(source)

    if not index then
        return { priceMultiplier = 1.0 }
    end

    local station = getStation(index)

    return {
        priceMultiplier = station.priceMultiplier,
        stock = Config.Stock.Enabled and station.stock - station.reserved or nil
    }
end)

xLib.callback.register("esx_fuel:startRefuel", function(source, netId, fuelName, liters, account)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        return false, "invalid"
    end

    local current = sessions[source]

    if current then
        if GetGameTimer() < current.expiresAt then
            return false, "busy"
        end

        closeSession(source, current, current.liters)
    end

    local fuel = fuelTypes[fuelName]
    liters = tonumber(liters)
    liters = liters and math.tointeger(liters)

    if not fuel or not liters or liters < 1 or liters > Config.Refuel.MaxLitersPerPurchase or not payAccounts[account] then
        return false, "invalid"
    end

    local stationIndex, atCharger = getLocation(source)

    if (not stationIndex and not (atCharger and fuel.kind == "electric")) or not getNearbyVehicle(source, netId) then
        return false, "too_far"
    end

    local multiplier = stationIndex and getStation(stationIndex).priceMultiplier or 1.0
    local stocked = Config.Stock.Enabled and stationIndex ~= nil and fuel.kind ~= "electric"

    if stocked and getStation(stationIndex).stock - getStation(stationIndex).reserved < liters then
        return false, "out_of_stock"
    end

    local price = math.ceil(liters * fuel.price * multiplier - 1e-9)
    local balance = xPlayer.getAccount(account)

    if not balance or balance.money < price then
        return false, "no_money"
    end

    xPlayer.removeAccountMoney(account, price, "Fuel purchase")

    if stocked then
        local station = getStation(stationIndex)
        station.reserved = station.reserved + liters
    end

    sessions[source] = {
        netId = tonumber(netId),
        fuel = fuel.name,
        liters = liters,
        pricePerLiter = price / liters,
        paid = price,
        account = account,
        station = stocked and stationIndex or nil,
        expiresAt = GetGameTimer() + math.ceil(liters / math.min(Config.Refuel.LitersPerSecond, Config.Refuel.ChargePerSecond) * 1000) + 30000
    }

    return true, price
end)

xLib.callback.register("esx_fuel:finishRefuel", function(source, delivered)
    local session = sessions[source]

    if not session then
        return false
    end

    return true, closeSession(source, session, delivered)
end)

xLib.callback.register("esx_fuel:buyCan", function(source, fuelName, account)
    local xPlayer = ESX.GetPlayerFromId(source)
    local fuel = fuelTypes[fuelName]

    if not xPlayer or not Config.JerryCan.Enabled or not fuel or fuel.kind == "electric" or not payAccounts[account] then
        return false, "invalid"
    end

    local stationIndex = getLocation(source)

    if not stationIndex then
        return false, "too_far"
    end

    local _, weapon = xPlayer.getWeapon(PETROLCAN)

    if not weapon then
        return false, "no_can"
    end

    local current = Config.JerryCan.Liters * math.max(0, math.min(CAN_MAX_AMMO, tonumber(weapon.ammo) or 0)) / CAN_MAX_AMMO
    local liters = Config.JerryCan.Liters - current

    if liters < 0.5 then
        return false, "can_full"
    end

    local station = getStation(stationIndex)

    if Config.Stock.Enabled and station.stock - station.reserved < liters then
        return false, "out_of_stock"
    end

    local price = math.ceil(liters * fuel.price * station.priceMultiplier - 1e-9)
    local balance = xPlayer.getAccount(account)

    if not balance or balance.money < price then
        return false, "no_money"
    end

    xPlayer.removeAccountMoney(account, price, "Jerry can")
    xPlayer.updateWeaponAmmo(PETROLCAN, CAN_MAX_AMMO)
    xPlayer.setMeta("fuelCan", fuel.name)

    if Config.Stock.Enabled then
        station.stock = station.stock - math.ceil(liters)
        saveStation(stationIndex)

        local owner = Config.Stock.Owners[stationIndex]

        if owner then
            creditSociety(owner, price)
        end
    end

    return true, price, liters
end)

RegisterNetEvent("esx_fuel:syncCan", function(ammo)
    local xPlayer = ESX.GetPlayerFromId(source)
    ammo = tonumber(ammo)

    if not xPlayer or not ammo then
        return
    end

    local _, weapon = xPlayer.getWeapon(PETROLCAN)

    ammo = math.max(1, math.floor(ammo))

    if weapon and ammo < (tonumber(weapon.ammo) or 0) then
        xPlayer.updateWeaponAmmo(PETROLCAN, ammo)
    end
end)

xLib.callback.register("esx_fuel:deliver", function(source)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not Config.Stock.Enabled then
        return false, "invalid"
    end

    local stationIndex = getLocation(source)

    if not stationIndex then
        return false, "too_far"
    end

    local item = xPlayer.getInventoryItem(Config.Stock.DeliveryItem)
    local station = getStation(stationIndex)
    local space = Config.Stock.Capacity - station.stock
    local count = math.min(item and item.count or 0, math.floor(space / Config.Stock.LitersPerItem))

    if count < 1 then
        return false, space < Config.Stock.LitersPerItem and "stock_full" or "nothing_to_deliver"
    end

    local pay = count * Config.Stock.DeliveryPay
    local owner = Config.Stock.Owners[stationIndex]

    if owner and pay > 0 and not debitSociety(owner, pay) then
        return false, "society_no_money"
    end

    xPlayer.removeInventoryItem(Config.Stock.DeliveryItem, count)
    station.stock = station.stock + count * Config.Stock.LitersPerItem
    saveStation(stationIndex)

    if pay > 0 then
        xPlayer.addAccountMoney("money", pay, "Fuel delivery")
    end

    return true, count, count * Config.Stock.LitersPerItem, pay
end)

xLib.callback.register("esx_fuel:getMix", function(source, netId)
    local vehicle = getNearbyVehicle(source, netId)

    if not vehicle then
        return nil
    end

    return mixes[normalizePlate(GetVehicleNumberPlateText(vehicle)) or ""]
end)

---@param xPlayer table
---@return boolean
local function isDrainJob(xPlayer)
    local job = xPlayer.getJob()
    local minimum = Config.Drain.Enabled and Config.Drain.Jobs[job.name]

    return type(minimum) == "number" and (tonumber(job.grade) or 0) >= minimum
end

---@param entity integer
---@param plate string
local function saveMix(entity, plate)
    if not DoesEntityExist(entity) or normalizePlate(GetVehicleNumberPlateText(entity)) ~= plate then
        return
    end

    local value = Entity(entity).state[MIX_BAG]
    local clearing = type(value) ~= "table"

    if clearing and not mixes[plate] then
        return
    end

    local xPlayer = ESX.GetPlayerFromId(NetworkGetEntityOwner(entity))

    if not xPlayer then
        return
    end

    if not (clearing and isDrainJob(xPlayer)) then
        local ok, owner = pcall(MySQL.scalar.await, "SELECT owner FROM owned_vehicles WHERE plate = ?", { plate })

        if not ok or owner ~= xPlayer.getIdentifier() then
            return
        end
    end

    if clearing then
        mixes[plate] = nil
        MySQL.prepare("DELETE FROM esx_fuel_vehicles WHERE plate = ?", { plate })
    else
        mixes[plate] = FuelMix.sanitize(value, "petrol")
        MySQL.prepare("INSERT INTO esx_fuel_vehicles (plate, mix) VALUES (?, ?) ON DUPLICATE KEY UPDATE mix = VALUES(mix)", { plate, json.encode(mixes[plate]) })
    end
end

AddStateBagChangeHandler(MIX_BAG, nil, function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)

    if entity == 0 or GetEntityType(entity) ~= 2 then
        return
    end

    local plate = normalizePlate(GetVehicleNumberPlateText(entity))

    if not plate or pendingMixSaves[plate] or (type(value) ~= "table" and not mixes[plate]) then
        return
    end

    local playerId = NetworkGetEntityOwner(entity)
    local pending = pendingMixSavesByPlayer[playerId] or 0

    if pending >= MAX_PENDING_MIX_SAVES then
        return
    end

    pendingMixSaves[plate] = true
    pendingMixSavesByPlayer[playerId] = pending + 1

    SetTimeout(MIX_SAVE_DELAY, function()
        local left = (pendingMixSavesByPlayer[playerId] or 1) - 1
        pendingMixSaves[plate] = nil
        pendingMixSavesByPlayer[playerId] = left > 0 and left or nil
        saveMix(entity, plate)
    end)
end)

ESX.RegisterCommand("fuelprice", "user", function(xPlayer, args, showError)
    local stationIndex = getLocation(xPlayer.source)
    local owner = stationIndex and Config.Stock.Owners[stationIndex]
    local job = xPlayer.getJob()

    if not Config.Stock.Enabled or not owner or owner ~= ("society_%s"):format(job.name) or job.grade_name ~= "boss" then
        return showError(TranslateCap("error_not_owner"))
    end

    local percent = tonumber(args.percent)

    if not percent or percent < 50 or percent > 200 then
        return showError(TranslateCap("error_price_range"))
    end

    getStation(stationIndex).priceMultiplier = math.floor(percent) / 100
    saveStation(stationIndex)
    xPlayer.showNotification(TranslateCap("price_set", math.floor(percent)))
end, false, {
    help = TranslateCap("command_fuelprice"),
    validate = false,
    arguments = { { name = "percent", help = "50 - 200", type = "any" } }
})

AddEventHandler("playerDropped", function()
    local session = sessions[source]

    if session then
        closeSession(source, session, session.liters)
    end
end)

CreateThread(function()
    while true do
        Wait(SESSION_SWEEP_MS)

        local now = GetGameTimer()

        for playerId, session in pairs(sessions) do
            if now >= session.expiresAt then
                closeSession(playerId, session, session.liters)
            end
        end
    end
end)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS esx_fuel_vehicles (
            plate VARCHAR(12) NOT NULL PRIMARY KEY,
            mix LONGTEXT NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS esx_fuel_stations (
            id INT NOT NULL PRIMARY KEY,
            stock INT NOT NULL DEFAULT 0,
            price_multiplier DECIMAL(4, 2) NOT NULL DEFAULT 1.00
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    for _, row in ipairs(MySQL.query.await("SELECT plate, mix FROM esx_fuel_vehicles") or {}) do
        local ok, mix = pcall(json.decode, row.mix)

        if ok and type(mix) == "table" then
            mixes[row.plate] = FuelMix.sanitize(mix, "petrol")
        end
    end

    for _, row in ipairs(MySQL.query.await("SELECT id, stock, price_multiplier FROM esx_fuel_stations") or {}) do
        stations[row.id] = { stock = row.stock, reserved = 0, priceMultiplier = tonumber(row.price_multiplier) or 1.0 }
    end
end)

exports("GetFuelTypes", function()
    return Config.FuelTypes
end)
