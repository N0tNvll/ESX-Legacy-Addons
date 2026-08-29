--- @module client.module.main
--- Client-side scoreboard module

local ScoreboardClass = xLib.require "client.module.class"

local ScoreboardModule = {}
local currentScoreboard = nil

--- Check if scoreboard is currently open.
--- @return boolean
function ScoreboardModule.IsOpen()
  return currentScoreboard ~= nil and currentScoreboard:IsOpen()
end

--- Open the scoreboard.
function ScoreboardModule.OpenScoreboard()
  if ScoreboardModule.IsOpen() then return end

  currentScoreboard = ScoreboardClass:new()
  currentScoreboard:Open()

  SendNUIMessage({ type = "show" })
  SetNuiFocus(true, true)
  TriggerServerEvent("esx_scoreboard:server:open")
end

--- Close the scoreboard.
function ScoreboardModule.CloseScoreboard()
  if not ScoreboardModule.IsOpen() then return end

  TriggerServerEvent("esx_scoreboard:server:close")
  SendNUIMessage({ type = "hide" })
  SetNuiFocus(false, false)

  currentScoreboard:Close()
  currentScoreboard = nil
end

--- Toggle scoreboard visibility.
function ScoreboardModule.ToggleScoreboard()
  if ScoreboardModule.IsOpen() then
    ScoreboardModule.CloseScoreboard()
  else
    ScoreboardModule.OpenScoreboard()
  end
end

--- Request one player page from the server.
--- @param data table|nil
function ScoreboardModule.RequestPage(data)
  if not ScoreboardModule.IsOpen() then return end
  TriggerServerEvent("esx_scoreboard:server:requestPage", type(data) == "table" and data or {})
end

--- Refresh initial scoreboard data from server.
function ScoreboardModule.RefreshData()
  if not ScoreboardModule.IsOpen() then return end
  TriggerServerEvent("esx_scoreboard:server:requestData")
end

RegisterNetEvent("esx_scoreboard:client:receiveSummary", function(summary)
  SendNUIMessage({
    type = "updateSummary",
    summary = summary
  })
end)

RegisterNetEvent("esx_scoreboard:client:receivePage", function(page)
  SendNUIMessage({
    type = "updatePage",
    page = page
  })
end)

RegisterNetEvent("esx_scoreboard:client:receiveActivities", function(activities)
  SendNUIMessage({
    type = "updateActivities",
    activities = activities
  })
end)

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
