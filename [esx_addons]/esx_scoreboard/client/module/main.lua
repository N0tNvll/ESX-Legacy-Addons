--- @module client.module.main
--- Client-side scoreboard module

local ScoreboardClass = xLib.require "client.module.class"

--- Module exports table
local ScoreboardModule = {}

--- Current scoreboard instance
local currentScoreboard = nil

--- Check if scoreboard is currently open
--- @return boolean
function ScoreboardModule.IsOpen()
  return currentScoreboard ~= nil and currentScoreboard:IsOpen()
end

--- Open the scoreboard
function ScoreboardModule.OpenScoreboard()
  if ScoreboardModule.IsOpen() then return end

  currentScoreboard = ScoreboardClass:new()
  currentScoreboard:Open()

  ScoreboardModule.RefreshData()

  SendNUIMessage({ type = "show" })
  SetNuiFocus(true, true)
end

--- Close the scoreboard
function ScoreboardModule.CloseScoreboard()
  if not ScoreboardModule.IsOpen() then return end

  SendNUIMessage({ type = "hide" })
  SetNuiFocus(false, false)

  if currentScoreboard then
    currentScoreboard:Close()
    currentScoreboard = nil
  end
end

--- Toggle scoreboard visibility
function ScoreboardModule.ToggleScoreboard()
  if ScoreboardModule.IsOpen() then
    ScoreboardModule.CloseScoreboard()
  else
    ScoreboardModule.OpenScoreboard()
  end
end

--- Refresh scoreboard data from server
function ScoreboardModule.RefreshData()
  if not ScoreboardModule.IsOpen() then return end

  TriggerServerEvent("esx_scoreboard:server:requestData")
end

--- Register net event for full data update
RegisterNetEvent("esx_scoreboard:client:receiveData", function(players, jobs, activities, info)
  SendNUIMessage({
    type = "updateAll",
    players = players,
    jobs = jobs,
    activities = activities,
    info = info
  })
end)

return ScoreboardModule