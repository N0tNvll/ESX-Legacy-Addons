-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Config = Config.Driving

Utils = {
    ped = 0,
    vehicle = nil,
    driver = false,
    RefreshVehicle = function(self)
        self.ped = PlayerPedId()

        local vehicle = GetVehiclePedIsIn(self.ped, false)

        self.vehicle = vehicle ~= 0 and vehicle or nil
    end,
    DriverCheck = function(self)
        if not self.vehicle then
            return false
        end

        if not DoesEntityExist(self.vehicle) then
            return false
        end

        if GetPedInVehicleSeat(self.vehicle, -1) == self.ped then
            return true
        end
        return false
    end,
    SetHudState = function(self, state, seatbelt)
        local settings = seatbelt and Config.Seatbelt or Config.Cruise

        if not settings.Enable then
            return
        end

        HUD:SetDrivingState(state, seatbelt)

        if seatbelt then
            return
        end

        ESX.ShowNotification(Translate('driving_' .. (state and 'activated' or 'deactivated')), 5000, 'info')
    end,
    IsSteering = function(self)
        return math.abs(GetVehicleSteeringAngle(self.vehicle)) > 10.0
    end,
    GetSpeed = function(self)
        if not self:DriverCheck() then
            return
        end
        return GetEntitySpeed(self.vehicle)
    end,
}
