-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Config = Config.Driving

if Config.Cruise.Enable then
    xLib.addKeybind({
        name = 'esx_cruisecontrol:Enable',
        description = Translate('driving_cruiseControl'),
        defaultMapper = 'keyboard',
        defaultKey = Config.Cruise.Key,
        onPressed = function()
            if CC.cruiseActive then
                CC:Reset()
                return
            end

            CC:Enable()
        end,
    })

    xLib.addKeybind({
        name = 'esx_cruisecontrol:IncreaseSpeed',
        description = Translate('driving_increaseSpeed'),
        defaultMapper = 'keyboard',
        defaultKey = 'ADD',
        onPressed = function()
            if not Utils.vehicle then
                return
            end

            CC:ChangeSpeed(true)
        end,
    })

    xLib.addKeybind({
        name = 'esx_cruisecontrol:DecreaseSpeed',
        description = Translate('driving_decreaseSpeed'),
        defaultMapper = 'keyboard',
        defaultKey = 'SUBTRACT',
        onPressed = function()
            if not Utils.vehicle then
                return
            end

            CC:ChangeSpeed(false)
        end,
    })
end

if Config.Seatbelt.Enable then
    xLib.addKeybind({
        name = 'esx_cruisecontrol:ToggleSeatbelt',
        description = Translate('driving_toggleSeatbelt'),
        defaultMapper = 'keyboard',
        defaultKey = Config.Seatbelt.Key,
        onPressed = function()
            if not Utils.vehicle then
                return
            end

            if not SB:SetState(not SB.seatbelt) then
                return
            end

            ESX.ShowNotification(Translate('driving_' .. (SB.seatbelt and 'seatbeltOn' or 'seatbeltOff')), 5000, 'info')
        end,
    })
end
