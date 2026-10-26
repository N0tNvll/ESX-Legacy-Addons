-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local INTERACT_KEY <const> = 38
local DELIVERY_RANGE <const> = 12.0

if not Config.Stock.Enabled then
    return
end

---@param coords vector3
---@return boolean
local function isAtStation(coords)
    for i = 1, #Config.Stations do
        if #(coords - Config.Stations[i]) <= DELIVERY_RANGE then
            return true
        end
    end

    return false
end

local delivering = false

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local text

        if not delivering and not IsPedInAnyVehicle(ped, false) and not Fuel.isBusy() then
            local count = Fuel.getItemCount(Config.Stock.DeliveryItem)

            if count > 0 and isAtStation(GetEntityCoords(ped)) then
                sleep = 0
                text = _U("text_deliver", count)

                if Fuel.isShown("stock") and IsControlJustReleased(0, INTERACT_KEY) then
                    delivering = true
                    Fuel.hint("stock", nil)

                    CreateThread(function()
                        local called, ok, result, liters, pay = pcall(xLib.callback.await, "esx_fuel:deliver", false)

                        if not called then
                            ESX.ShowNotification(_U("error_invalid"))
                        elseif ok then
                            ESX.ShowNotification(_U("delivered", result, liters, pay))
                        else
                            ESX.ShowNotification(_U(("error_%s"):format(result or "invalid")))
                        end

                        delivering = false
                    end)
                end
            end
        end

        Fuel.hint("stock", text)
        Wait(sleep)
    end
end)
