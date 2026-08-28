--- @module client.main
--- Main client entry point for the scoreboard resource

local ScoreboardModule = xLib.require "client.module.main"

local RESOURCE_NAME <const> = GetCurrentResourceName()

--- Register NUI callback to close scoreboard from UI
RegisterNUICallback("closeScoreboard", function(data, cb)
  ScoreboardModule.CloseScoreboard()
  TriggerServerEvent("esx_scoreboard:server:close")
  cb({})
end)

--- Send theme update to NUI
local function SendThemeUpdate()
  SendNUIMessage({
    type = "updateTheme",
    primaryColor = GetConvar("esx:ui:primaryColor", "#FB9B04"),
    secondaryColor = GetConvar("esx:ui:secondaryColor", "#252525"),
    backgroundColor = GetConvar("esx:ui:backgroundColor", "#161616"),
    accentColor = GetConvar("esx:ui:accentColor", "#383838"),
    logoUrl = GetConvar("esx:ui:logoUrl", "")
  })
end

--- Register NUI callback for when the UI is fully mounted
RegisterNUICallback("nuiReady", function(data, cb)
  cb({})
  SendThemeUpdate()
end)

CreateThread(function()
  while true do
    Wait(100)
    if IsControlJustReleased(0, Config.OpenKey) then
      ScoreboardModule.ToggleScoreboard()
    end
  end
end)

-- Disable controls only when open
CreateThread(function()
  while true do
    Wait(0)
    if ScoreboardModule.IsOpen() then
      DisableControlAction(0, 1, true)   -- look left/right
      DisableControlAction(0, 2, true)   -- look up/down
      DisableControlAction(0, 142, true) -- melee attack
      DisableControlAction(0, 18, true)  -- attack
      DisableControlAction(0, 322, true) -- ESC (already handled by disabled check)
      DisableControlAction(0, 106, true) -- mouse click in vehicle
      if IsDisabledControlJustReleased(0, 322) then
        ScoreboardModule.CloseScoreboard()
      end
    end
  end
end)

--- Thread to periodically refresh scoreboard data
CreateThread(function()
  while true do
    Wait(Config.UpdateInterval)

    if ScoreboardModule.IsOpen() then
      ScoreboardModule.RefreshData()
    end
  end
end)

--- Handle resource stop
AddEventHandler("onResourceStop", function(resourceName)
  if resourceName ~= RESOURCE_NAME then return end
  ScoreboardModule.CloseScoreboard()
end)