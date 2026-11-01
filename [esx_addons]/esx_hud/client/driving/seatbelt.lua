-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Config = Config.Driving

SB = {
    cacheVeh = nil,
    generation = 0,
    running = false,
    isRagdoll = false,
    carArray = { 0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 17, 18, 19, 20 },
    seatbelt = false,
    vehSpeed = 0.0,
    previousVelocity = vector3(0, 0, 0),
    Reset = function(self)
        self.generation = self.generation + 1
        self.cacheVeh = nil
        self.running = false
        self.seatbelt = false
        self.vehSpeed = 0.0
        self.previousVelocity = vector3(0, 0, 0)
        self.isRagdoll = false

        if Utils.ped ~= 0 then
            SetPedConfigFlag(Utils.ped, 32, true)
        end

        Utils:SetHudState(false, true)
    end,
    SupportsVehicle = function(self, vehicle)
        if not vehicle or not DoesEntityExist(vehicle) then
            return false
        end

        local class = GetVehicleClass(vehicle)

        for _, allowed in ipairs(self.carArray) do
            if allowed == class then
                return true
            end
        end

        return false
    end,
    EjectSeat = function(self)
        local ped, generation = Utils.ped, self.generation
        local position = GetEntityCoords(ped)

        SetEntityCoords(ped, position.x, position.y, position.z - 0.47, true, true, true, false)
        SetEntityVelocity(ped, self.previousVelocity.x, self.previousVelocity.y, self.previousVelocity.z)
        self.isRagdoll = true

        CreateThread(function()
            while self.isRagdoll and self.generation == generation and Utils.ped == ped do
                SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false)
                Wait(0)
            end
        end)

        Citizen.SetTimeout((Config.Seatbelt.RagdollTime or 1) * 1000, function()
            if self.generation == generation and Utils.ped == ped then
                self:Reset()
            end
        end)
    end,
    Logic = function(self)
        local previousSpeed = self.vehSpeed

        self.vehSpeed = GetEntitySpeed(self.cacheVeh)
        SetPedConfigFlag(Utils.ped, 32, not self.seatbelt)

        if self.seatbelt or self.isRagdoll then
            return
        end

        local movingForward = GetEntitySpeedVector(self.cacheVeh, true).y > 1.0
        local acceleration = (previousSpeed - self.vehSpeed) / math.max(GetFrameTime(), 0.001)
        local aboveEjectSpeed = previousSpeed > ((Config.Seatbelt.EjectCheckSpeed or 45) / 2.237)

        if movingForward and aboveEjectSpeed and acceleration > (100 * 9.81) then
            self:EjectSeat()
        else
            self.previousVelocity = GetEntityVelocity(self.cacheVeh)
        end
    end,
    Thread = function(self)
        local vehicle = Utils.vehicle

        if not Config.Seatbelt.Enable or not self:SupportsVehicle(vehicle) then
            self:Reset()
            return
        end

        if self.running and self.cacheVeh == vehicle then
            return
        end

        self:Reset()
        self.cacheVeh = vehicle
        self.running = true

        local generation = self.generation

        CreateThread(function()
            while self.generation == generation and Utils.vehicle == vehicle and DoesEntityExist(vehicle) do
                self:Logic()
                Wait(200)
            end

            if self.generation == generation then
                self:Reset()
            end
        end)
    end,
    DisableExit = function(self)
        local generation, vehicle = self.generation, self.cacheVeh

        CreateThread(function()
            while self.seatbelt and self.generation == generation and Utils.vehicle == vehicle and DoesEntityExist(vehicle) do
                SetPedConfigFlag(Utils.ped, 32, false)
                DisableControlAction(0, 75, true)
                Wait(0)
            end
        end)
    end,
    SetState = function(self, state)
        if not Config.Seatbelt.Enable or not self:SupportsVehicle(Utils.vehicle) then
            return false
        end

        if self.cacheVeh ~= Utils.vehicle then
            self:Thread()
        end

        local previous = self.seatbelt

        self.seatbelt = state == true
        SetPedConfigFlag(Utils.ped, 32, not self.seatbelt)
        Utils:SetHudState(self.seatbelt, true)

        if self.seatbelt and not previous then
            self:DisableExit()
        end

        return true
    end,
}

local function isSeatbeltOn()
    return SB.seatbelt
end

exports('isSeatbeltOn', isSeatbeltOn)

AddEventHandler('__cfx_export_esx_cruisecontrol_isSeatbeltOn', function(setCallback)
    setCallback(isSeatbeltOn)
end)
