-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local NOZZLE_MODEL <const> = `prop_cs_fuel_nozle`
local HAND_BONE <const> = 18905

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

function Pump.releaseHose()
    local hose = Pump.hose

    if not hose then
        return
    end

    if hose.rope and DoesRopeExist(hose.rope) then
        DeleteRope(hose.rope)
    end

    if DoesEntityExist(hose.nozzle) then
        DeleteEntity(hose.nozzle)
    end

    Pump.hose = nil
    Fuel.setBusy("hose", false)
end

---@param pump integer
function Pump.takeNozzle(pump)
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

    Pump.hose = { pump = pump, pumpCoords = pumpCoords, nozzle = nozzle, rope = rope }
    Fuel.setBusy("hose", true)
end
