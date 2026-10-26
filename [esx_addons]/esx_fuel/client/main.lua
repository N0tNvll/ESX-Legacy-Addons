-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Fuel = {}

local FUEL_BAG <const> = "fuel"
local NO_FUEL_CLASSES <const> = { [13] = true }

local lastSynced = {}

local TANK_BONES <const> = { "petrolcap", "petroltank", "petroltank_l", "petroltank_r" }
local SCAN_INTERVAL <const> = 250
local HINT_ORDER <const> = { "pump", "can", "charger", "stock", "drain" }

local hints = {}
local shownHint
local shownSource
local busy = {}
local scanCoords
local scanAt = 0
local scanVehicle

---@param source string
---@param text string?
function Fuel.hint(source, text)
    hints[source] = text

    local selected
    shownSource = nil

    for i = 1, #HINT_ORDER do
        if hints[HINT_ORDER[i]] then
            selected = hints[HINT_ORDER[i]]
            shownSource = HINT_ORDER[i]
            break
        end
    end

    if selected == shownHint then
        return
    end

    shownHint = selected

    if selected then
        ESX.TextUI(selected)
    else
        ESX.HideUI()
    end
end

---@param source string
---@return boolean
function Fuel.isShown(source)
    return shownSource == source
end

---@param source string
---@param value boolean
function Fuel.setBusy(source, value)
    busy[source] = value or nil
end

---@return boolean
function Fuel.isBusy()
    return next(busy) ~= nil
end

---@param vehicle integer
---@return vector3
function Fuel.getTankCoords(vehicle)
    for i = 1, #TANK_BONES do
        local bone = GetEntityBoneIndexByName(vehicle, TANK_BONES[i])

        if bone ~= -1 then
            return GetWorldPositionOfEntityBone(vehicle, bone)
        end
    end

    return GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -1.5, 0.3)
end

---@param coords vector3
---@return integer?
function Fuel.getVehicleAtTank(coords)
    local now = GetGameTimer()

    if now - scanAt < SCAN_INTERVAL and scanCoords and #(scanCoords - coords) < 0.5 then
        return scanVehicle and DoesEntityExist(scanVehicle) and scanVehicle or nil
    end

    scanAt = now
    scanCoords = coords
    scanVehicle = nil

    for _, vehicle in ipairs(GetGamePool("CVehicle")) do
        if #(coords - GetEntityCoords(vehicle)) <= 6.0 and Fuel.usesFuel(vehicle) and #(coords - Fuel.getTankCoords(vehicle)) <= Config.Refuel.TankDistance then
            scanVehicle = vehicle
            break
        end
    end

    return scanVehicle
end

---@param vehicle integer
---@return boolean
function Fuel.requestControl(vehicle)
    local deadline = GetGameTimer() + 3000

    while NetworkGetEntityOwner(vehicle) ~= PlayerId() and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(vehicle)
        Wait(50)
    end

    return NetworkGetEntityOwner(vehicle) == PlayerId()
end

---@param name string
---@return table?
function Fuel.getFuelType(name)
    for i = 1, #Config.FuelTypes do
        if Config.FuelTypes[i].name == name then
            return Config.FuelTypes[i]
        end
    end
end

---@param name string
---@return integer
function Fuel.getItemCount(name)
    for _, item in ipairs(ESX.PlayerData.inventory or {}) do
        if item.name == name then
            return item.count
        end
    end

    return 0
end

---@param vehicle integer
---@return "petrol"|"diesel"|"electric"
function Fuel.getKind(vehicle)
    local model = GetEntityModel(vehicle)

    for name, kind in pairs(Config.ModelFuel) do
        if joaat(name) == model then
            return kind
        end
    end

    if GetIsVehicleElectric and GetIsVehicleElectric(model) then
        return "electric"
    end

    if Config.DieselClasses[GetVehicleClass(vehicle)] then
        return "diesel"
    end

    return "petrol"
end

---@param vehicle integer
---@return boolean
function Fuel.usesFuel(vehicle)
    return vehicle ~= 0 and DoesEntityExist(vehicle) and not NO_FUEL_CLASSES[GetVehicleClass(vehicle)]
end

---@param vehicle integer
---@return number liters
function Fuel.getCapacity(vehicle)
    local capacity = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fPetrolTankVolume")

    if not capacity or capacity <= 0.0 then
        return 65.0
    end

    return capacity
end

---@param vehicle integer
---@return number percent
function Fuel.getLevel(vehicle)
    if NetworkGetEntityIsNetworked(vehicle) and NetworkGetEntityOwner(vehicle) ~= PlayerId() then
        local stored = Entity(vehicle).state[FUEL_BAG]

        if type(stored) == "number" then
            return stored
        end
    end

    return GetVehicleFuelLevel(vehicle)
end

---@param vehicle integer
---@param level number percent
---@param publish? boolean
function Fuel.setLevel(vehicle, level, publish)
    level = math.max(0.0, math.min(100.0, level + 0.0))
    SetVehicleFuelLevel(vehicle, level)

    if publish ~= false and NetworkGetEntityIsNetworked(vehicle) and NetworkGetEntityOwner(vehicle) == PlayerId() then
        Entity(vehicle).state:set(FUEL_BAG, level, true)
        lastSynced[vehicle] = level
    end
end

---@param vehicle integer
function Fuel.loadLevel(vehicle)
    local stored = Entity(vehicle).state[FUEL_BAG]

    if type(stored) == "number" then
        Fuel.setLevel(vehicle, stored, false)
        lastSynced[vehicle] = stored
        return
    end

    Fuel.setLevel(vehicle, GetVehicleFuelLevel(vehicle), true)
end

---@param vehicle integer
---@return number
local function getUsage(vehicle)
    local rpm = GetVehicleCurrentRpm(vehicle)
    local multiplier = Config.ClassMultiplier[GetVehicleClass(vehicle)] or 1.0

    if Config.Damage.Enabled then
        local engine = GetVehicleEngineHealth(vehicle)

        if engine < Config.Damage.WornEngineHealth then
            multiplier = multiplier * (1.0 + (Config.Damage.WornEngineHealth - math.max(0.0, engine)) / Config.Damage.WornEngineHealth * Config.Damage.WornEngineConsumption)
        end
    end

    return (Config.Consumption.Idle + rpm * rpm * Config.Consumption.Load) * multiplier
end

---@param vehicle integer
---@return number percent lost per second
local function getLeak(vehicle)
    if not Config.Damage.Enabled then
        return 0.0
    end

    local tank = GetVehiclePetrolTankHealth(vehicle)

    if tank >= Config.Damage.LeakTankHealth then
        return 0.0
    end

    return (Config.Damage.LeakTankHealth - math.max(0.0, tank)) / Config.Damage.LeakTankHealth * Config.Damage.LeakPercentPerSecond
end

CreateThread(function()
    local currentVehicle = 0

    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and Fuel.usesFuel(vehicle) then
            if vehicle ~= currentVehicle then
                currentVehicle = vehicle
                Fuel.loadLevel(vehicle)
            end

            local level = GetVehicleFuelLevel(vehicle)

            local usage = getLeak(vehicle)

            if GetIsVehicleEngineRunning(vehicle) then
                usage = usage + getUsage(vehicle)
            end

            if usage > 0.0 and level > 0.0 then
                level = math.max(0.0, level - usage)
                SetVehicleFuelLevel(vehicle, level)

                if math.abs((lastSynced[vehicle] or 0.0) - level) >= Config.Consumption.SyncEvery or level == 0.0 then
                    Fuel.setLevel(vehicle, level, true)
                end
            end

            if level <= 0.0 then
                SetVehicleEngineOn(vehicle, false, true, true)
            end
        else
            if currentVehicle ~= 0 and DoesEntityExist(currentVehicle) and NetworkGetEntityOwner(currentVehicle) == PlayerId() then
                Fuel.setLevel(currentVehicle, GetVehicleFuelLevel(currentVehicle), true)
            end

            currentVehicle = 0
        end

        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        Wait(30000)

        for vehicle in pairs(lastSynced) do
            if not DoesEntityExist(vehicle) then
                lastSynced[vehicle] = nil
            end
        end
    end
end)

local UI_KEYS <const> = {
    "ui_price_per_liter", "ui_quantity", "ui_vehicle_fuel", "ui_total", "ui_your_money", "ui_cash", "ui_bank",
    "ui_fill_up", "ui_confirm", "ui_cancel", "ui_filling", "ui_vehicle_type", "ui_kind_petrol", "ui_kind_diesel",
    "ui_kind_electric", "ui_station_stock", "ui_jerrycan"
}

---@return table<string, string>
function Fuel.getUILocale()
    local strings = {}

    for i = 1, #UI_KEYS do
        strings[UI_KEYS[i]] = _(UI_KEYS[i])
    end

    return strings
end

if Config.ShowBlips then
    CreateThread(function()
        for i = 1, #Config.Stations do
            local station = Config.Stations[i]
            local blip = AddBlipForCoord(station.x, station.y, station.z)
            SetBlipSprite(blip, 361)
            SetBlipScale(blip, 0.7)
            SetBlipColour(blip, 1)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(_("blip_name"))
            EndTextCommandSetBlipName(blip)
        end
    end)
end

exports("GetFuel", function(vehicle)
    return Fuel.getLevel(vehicle)
end)

exports("SetFuel", function(vehicle, level)
    if type(level) == "number" and vehicle and DoesEntityExist(vehicle) then
        Fuel.setLevel(vehicle, level, true)
    end
end)
