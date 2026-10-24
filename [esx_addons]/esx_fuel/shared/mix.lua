-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

FuelMix = {}

---@class FuelMixData
---@field diesel number share of diesel in the tank, 0 to 1
---@field octane number average octane of the petrol part

---@param kind "petrol"|"diesel"|"electric"
---@return FuelMixData
function FuelMix.default(kind)
    return { diesel = kind == "diesel" and 1.0 or 0.0, octane = Config.DefaultOctane }
end

---@param mix any
---@param kind "petrol"|"diesel"|"electric"
---@return FuelMixData
function FuelMix.sanitize(mix, kind)
    if type(mix) ~= "table" then
        return FuelMix.default(kind)
    end

    local diesel = tonumber(mix.diesel)
    local octane = tonumber(mix.octane)

    if not diesel or diesel ~= diesel then
        diesel = FuelMix.default(kind).diesel
    end

    if not octane or octane ~= octane then
        octane = Config.DefaultOctane
    end

    return { diesel = math.max(0.0, math.min(1.0, diesel)), octane = math.max(80.0, math.min(100.0, octane)) }
end

---@param mix FuelMixData
---@param currentLiters number
---@param addedLiters number
---@param fuel { kind: string, octane?: number }
---@return FuelMixData
function FuelMix.add(mix, currentLiters, addedLiters, fuel)
    currentLiters = math.max(0.0, currentLiters)
    addedLiters = math.max(0.0, addedLiters)

    if fuel.kind == "electric" or addedLiters <= 0.0 then
        return mix
    end

    local total = currentLiters + addedLiters
    local addedDiesel = fuel.kind == "diesel" and addedLiters or 0.0
    local diesel = (currentLiters * mix.diesel + addedDiesel) / total

    local currentPetrol = currentLiters * (1.0 - mix.diesel)
    local addedPetrol = fuel.kind == "petrol" and addedLiters or 0.0
    local octane = mix.octane

    if currentPetrol + addedPetrol > 0.0 and addedPetrol > 0.0 then
        octane = (currentPetrol * mix.octane + addedPetrol * (fuel.octane or Config.DefaultOctane)) / (currentPetrol + addedPetrol)
    end

    return { diesel = diesel, octane = octane }
end

---@param mix FuelMixData
---@param kind "petrol"|"diesel"|"electric"
---@return number share of fuel the engine does not run on, 0 to 1
function FuelMix.wrongShare(mix, kind)
    if kind == "petrol" then
        return mix.diesel
    end

    if kind == "diesel" then
        return 1.0 - mix.diesel
    end

    return 0.0
end

---@param mix FuelMixData
---@param kind "petrol"|"diesel"|"electric"
---@return boolean
function FuelMix.isClean(mix, kind)
    return FuelMix.wrongShare(mix, kind) < 0.001 and (kind ~= "petrol" or math.abs(mix.octane - Config.DefaultOctane) < 0.05)
end
