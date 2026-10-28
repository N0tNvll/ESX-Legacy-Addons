-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@type table<string, Garage>
Garages = {}
local garageResources = {}

---@type table<string, Impound>
Impounds = {}

local CALLBACK_COOLDOWNS <const> = {
    ["esx_garage:getGarages"] = 1500,
    ["esx_garage:getVehicles"] = 1500,
    ["esx_garage:retrieveVehicle"] = 1500,
    ["esx_garage:storeVehicle"] = 1500,
    ["esx_garage:toggleFavorite"] = 1000,
    ["esx_garage:renameVehicle"] = 1000,
    ["esx_garage:transferVehicle"] = 1500,
    ["esx_garage:giveKeys"] = 1000,
}

local callbackLimiters = {}

---@return integer
local function defaultImpoundFee()
    local fee = tonumber(Config.Settings.defaultImpoundFee) or 0
    return math.max(0, math.floor(fee))
end

---@param impound Impound
---@return integer
local function configuredImpoundCost(impound)
    local cost = tonumber(impound.cost)
    if cost == nil then
        return defaultImpoundFee()
    end

    return math.max(0, math.floor(cost))
end

---@param source integer
---@param cb function
---@param callbackName string
---@return boolean
function rejectRateLimited(source, cb, callbackName)
    local cooldown = CALLBACK_COOLDOWNS[callbackName]
    if not cooldown then
        return false
    end

    local limiter = callbackLimiters[callbackName]
    if not limiter then
        limiter = xLib.rateLimiter({
            capacity = 1,
            refill = 1,
            interval = cooldown,
            staleMs = math.max(60000, cooldown * 4)
        })
        callbackLimiters[callbackName] = limiter
    end

    if not limiter:consume(source) then
        cb({ success = false, error = "rate_limited" })
        return true
    end

    return false
end

for i = 1, #Config.Garages do
    local garage = Config.Garages[i]
    Garages[garage.id] = garage
end

for i = 1, #Config.Impounds do
    local impound = Config.Impounds[i]
    impound.cost = configuredImpoundCost(impound)
    Impounds[impound.id] = impound
end

---@param source integer
---@param garage Garage
---@return boolean
function CanAccessGarage(source, garage)
    local access = garage.access
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false
    end

    if garage.type == 'job' then
        if garage.shared ~= nil and type(garage.shared) ~= 'boolean' then return false end
        local job = xPlayer.job
        local name = job and job.name
        local allowed = name and access and access.jobs and access.jobs[name]
        if not name or (garage.job and garage.job ~= name)
            or (not garage.job and allowed == nil)
            or (access and access.jobs and allowed == nil) then
            return false
        end
        local grade = tonumber(job.grade)
        local minimum = tonumber(garage.minGrade or 0)
        local accessMinimum = tonumber(allowed or 0)
        if not grade or not minimum or not accessMinimum or grade ~= grade or minimum ~= minimum
            or accessMinimum ~= accessMinimum or grade == math.huge or minimum < 0 or accessMinimum < 0
            or minimum % 1 ~= 0 or accessMinimum % 1 ~= 0
            or grade < math.max(minimum, accessMinimum) then
            return false
        end
        -- Custom checks can further restrict a fleet, never bypass its job/grade.
        if access and access.authorize then
            local ok, result = pcall(access.authorize, source, garage)
            local currentJob = xPlayer.job
            return ok and result == true and ESX.GetPlayerFromId(source) == xPlayer
                and currentJob and currentJob.name == name
                and tonumber(currentJob.grade) and tonumber(currentJob.grade) >= math.max(minimum, accessMinimum)
        end
        return true
    end

    if not access then return true end

    if access.jobs then
        local minGrade = access.jobs[xPlayer.job.name]
        if minGrade and xPlayer.job.grade >= minGrade then
            return true
        end
    end

    if access.authorize then
        local ok, result = pcall(access.authorize, source, garage)
        if not ok then
            print(("[esx_garage] garage %s: access.authorize errored: %s"):format(tostring(garage.id), tostring(result)))
            return false
        end

        return result == true and ESX.GetPlayerFromId(source) == xPlayer
    end

    return false
end

---Resolve ownership from server configuration, never from a client-supplied job.
---An impound can select an authorized job garage as its fleet context.
---@return table?, string?
function ResolveGarageScope(source, garageId, fleetGarageId)
    local player = ESX.GetPlayerFromId(source)
    if not player then return nil, 'player' end
    local garage = type(garageId) == 'string' and Garages[garageId]
    local impound = type(garageId) == 'string' and Impounds[garageId]
    if not garage and not impound then return nil, 'no_location' end
    local fleet
    if fleetGarageId ~= nil then
        if not impound or type(fleetGarageId) ~= 'string' then return nil, 'not_allowed' end
        fleet = Garages[fleetGarageId]
        if not fleet or fleet.type ~= 'job' then return nil, 'not_allowed' end
    elseif garage and garage.type == 'job' then
        fleet = garage
    end
    if garage and not CanAccessGarage(source, garage) then return nil, 'not_allowed' end
    if fleet and not CanAccessGarage(source, fleet) then return nil, 'not_allowed' end
    return {
        kind = fleet and 'job' or 'personal',
        job = fleet and player.job.name or nil,
        owner = (not fleet or fleet.shared == false) and player.identifier or nil,
        source = source, player = player, garageId = garageId, fleetGarageId = fleetGarageId,
        location = garage or impound, garage = garage, impound = impound,
    }
end

---Recheck the session and permissions after yielding database/spawn operations.
function CanUseGarageScope(scope)
    if ESX.GetPlayerFromId(scope.source) ~= scope.player then return false end
    if not scope.garageId then return scope.kind == 'personal' end
    local current = ResolveGarageScope(scope.source, scope.garageId, scope.fleetGarageId)
    if current == nil or current.kind ~= scope.kind or current.job ~= scope.job or current.owner ~= scope.owner then return false end
    if scope.vehicle then
        for _, location in ipairs({ current.location, current.fleetGarageId and Garages[current.fleetGarageId] }) do
            if not GarageCategories.accepts(location, scope.vehicle)
                or not GarageCategories.acceptsModel(location, scope.vehicle, scope.source) then return false end
        end
    end
    return true
end

---@param v any
---@return boolean
local function hasXYZ(v)
    local t = type(v)
    if t ~= "table" and t ~= "vector3" and t ~= "vector4" then
        return false
    end

    return tonumber(v.x) ~= nil and tonumber(v.y) ~= nil and tonumber(v.z) ~= nil
end

---@param v vector3 | vector4
---@return table
local function vec3t(v)
    return { x = v.x, y = v.y, z = v.z }
end

---@param v vector4
---@return table
local function vec4t(v)
    return { x = v.x, y = v.y, z = v.z, w = v.w }
end

---@param spawns vector4[]
---@return table[]
local function spawnsT(spawns)
    local out = {}
    for i = 1, #spawns do
        out[i] = vec4t(spawns[i])
    end
    return out
end

---@param ped GaragePed?
---@return table?
local function pedT(ped)
    if not ped then
        return nil
    end
    return { model = ped.model, z = ped.z, heading = ped.heading, snapToGround = ped.snapToGround }
end

---@param garage Garage
---@return table
local function garagePayload(garage)
    return {
        id = garage.id,
        label = garage.label,
        type = garage.type,
        entryPoint = vec3t(garage.entryPoint),
        storePoint = garage.storePoint and vec3t(garage.storePoint) or nil,
        spawns = spawnsT(garage.spawns),
        blip = garage.blip,
        ped = pedT(garage.ped),
        logo = garage.logo,
        color = garage.color,
        pound = garage.pound,
        job = garage.type == 'job' and garage.job or nil,
        vehicleCategories = garage.vehicleCategories,
        exitPoint = garage.exitPoint and vec4t(garage.exitPoint) or nil,
    }
end

---@param impound Impound
---@return table
local function impoundPayload(impound)
    return {
        id = impound.id,
        label = impound.label,
        getOutPoint = vec3t(impound.getOutPoint),
        spawns = spawnsT(impound.spawns),
        blip = impound.blip,
        ped = pedT(impound.ped),
        cost = impound.cost,
        vehicleCategories = impound.vehicleCategories,
    }
end

---@param source integer
---@return { garages: table[], impounds: table[] }
local function accessiblePayload(source)
    local garages = {}

    for _, garage in pairs(Garages) do
        if CanAccessGarage(source, garage) then
            garages[#garages + 1] = garagePayload(garage)
        end
    end

    local impounds = {}

    for _, impound in pairs(Impounds) do
        impounds[#impounds + 1] = impoundPayload(impound)
    end

    return { garages = garages, impounds = impounds }
end

xLib.callback.registerCompat("esx_garage:getGarages", function(source, cb)
    if rejectRateLimited(source, cb, "esx_garage:getGarages") then
        return
    end

    local payload = accessiblePayload(source)

    cb(payload)
end)

---@param def Garage
local function registerGarage(def)
    assert(type(def) == "table" and type(def.id) == "string", "registerGarage: a garage table with a string id is required")
    GarageCategories.validate(def)
    assert(not def.reserve or def.release, 'registerGarage: reserve requires a matching release callback')
    if def.type == 'job' then
        assert((type(def.job) == 'string' and def.job ~= '') or (def.access and type(def.access.jobs) == 'table' and next(def.access.jobs)),
            'registerGarage: a job garage needs job or access.jobs')
        local grade = tonumber(def.minGrade or 0)
        assert(grade and grade == grade and grade >= 0 and grade < math.huge and grade % 1 == 0,
            'registerGarage: minGrade must be a non-negative integer')
    end
    assert(hasXYZ(def.entryPoint), ("registerGarage: garage %s needs a valid entryPoint (x, y, z)"):format(def.id))

    if def.storePoint ~= nil then
        assert(hasXYZ(def.storePoint), ("registerGarage: garage %s has an invalid storePoint (x, y, z)"):format(def.id))
    end

    assert(type(def.spawns) == "table" and #def.spawns > 0, ("registerGarage: garage %s needs at least one spawn"):format(def.id))

    for i = 1, #def.spawns do
        assert(hasXYZ(def.spawns[i]), ("registerGarage: garage %s spawn #%d is not a valid coordinate"):format(def.id, i))
    end

    Garages[def.id] = def
    garageResources[def.id] = GetInvokingResource()
    TriggerClientEvent("esx_garage:refresh", -1)
end

AddEventHandler('onResourceStop', function(resource)
    local changed = false
    for id, owner in pairs(garageResources) do
        if owner == resource then Garages[id] = nil; garageResources[id] = nil; changed = true end
    end
    if changed then TriggerClientEvent('esx_garage:refresh', -1) end
end)

---@param registry table<string, table>
---@return table[]
local function asList(registry)
    local out = {}
    for _, entry in pairs(registry) do
        out[#out + 1] = entry
    end
    return out
end

exports("getGarages", function()
    return asList(Garages)
end)

exports("getImpounds", function()
    return asList(Impounds)
end)

exports("registerGarage", registerGarage)

exports("registerGarages", function(list)
    assert(type(list) == "table", "registerGarages: expected a list of garages")
    for i = 1, #list do
        registerGarage(list[i])
    end
end)

exports("unregisterGarage", function(id)
    Garages[id] = nil
    TriggerClientEvent("esx_garage:refresh", -1)
end)
