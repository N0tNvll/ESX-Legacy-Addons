--- @module server.module.main
--- Server-side scoreboard module

--- Module exports table
local ScoreboardModule = {}

--- Cached activities
local cachedActivities = {}

--- Server start time for uptime tracking
local serverStartTime = os.time()

local nextActivityId = 1

local lastRequest = {}

local broadcastPending = false

--- Player / job cache
local playerCache = nil
local jobCache = nil
local cacheDirty = true
local cachedPlayerCount = 0

--- Mark player/job caches as stale
local function InvalidateCache()
  cacheDirty = true
end

local function DeferredBroadcast()
  if broadcastPending then return end
  broadcastPending = true
  CreateThread(function()
    Wait(500)
    broadcastPending = false
    ScoreboardModule.BroadcastUpdate()
  end)
end

--- Get current server uptime in seconds
--- @return number
function ScoreboardModule.GetUptime()
  return os.time() - serverStartTime
end

--- Get configured max players
--- @return number
function ScoreboardModule.GetMaxPlayers()
  if Config.MaxPlayers and Config.MaxPlayers > 0 then
    return Config.MaxPlayers
  end
  return GetConvarInt("sv_maxclients", 128)
end

--- Get configured server name
--- @return string
function ScoreboardModule.GetServerName()
  return Config.ServerName or "ESX Server"
end

--- Get configured logo URL
--- @return string
function ScoreboardModule.GetLogoUrl()
  return Config.LogoUrl or ""
end

--- Build server info object for NUI
--- @return table
function ScoreboardModule.GetServerInfo()
  return {
    serverName = ScoreboardModule.GetServerName(),
    maxPlayers = ScoreboardModule.GetMaxPlayers(),
    logoUrl = ScoreboardModule.GetLogoUrl(),
    uptime = ScoreboardModule.GetUptime()
  }
end

--- Get all connected players data (cached)
--- Rebuilds only when cache is dirty or player count changed.
--- Pings are refreshed every call since they change constantly.
--- @return table
function ScoreboardModule.GetAllPlayers()
  local currentCount = #GetPlayers()

  if not cacheDirty and playerCache and cachedPlayerCount == currentCount then
    for _, player in ipairs(playerCache) do
      player.ping = GetPlayerPing(player.serverId) or 0
    end
    return playerCache
  end

  local players = {}
  local allPlayers = GetPlayers()

  for _, playerId in ipairs(allPlayers) do
    local sourceNum = tonumber(playerId)
    local xPlayer = ESX.GetPlayerFromId(sourceNum)

    if xPlayer then
      local charName = xPlayer.getName() or GetPlayerName(sourceNum) or "Unknown"

      table.insert(players, {
        serverId = sourceNum,
        name = charName,
        job = xPlayer.job.name,
        jobGrade = xPlayer.job.grade_label or xPlayer.job.grade_name,
        group = xPlayer.getGroup(),
        ping = GetPlayerPing(sourceNum) or 0,
        activity = ScoreboardModule.GetPlayerActivity(sourceNum)
      })
    end
  end

  playerCache = players
  cachedPlayerCount = currentCount
  return players
end

--- Get job counts (cached)
--- Rebuilds only when player cache is dirty.
--- @return table
function ScoreboardModule.GetJobCounts()
  if not cacheDirty and jobCache then
    return jobCache
  end

  local jobs = {}
  local allPlayers = GetPlayers()

  for _, playerId in ipairs(allPlayers) do
    local xPlayer = ESX.GetPlayerFromId(tonumber(playerId))
    if xPlayer then
      local jobName = xPlayer.job.name
      if not jobs[jobName] then
        local configJob = Config.Jobs[jobName]
        jobs[jobName] = {
          name = jobName,
          label = configJob and configJob.label or xPlayer.job.label or jobName,
          count = 0,
          color = ScoreboardModule.GetJobColor(jobName)
        }
      end
      jobs[jobName].count = jobs[jobName].count + 1
    end
  end

  local jobArray = {}
  for _, jobData in pairs(jobs) do
    table.insert(jobArray, jobData)
  end

  table.sort(jobArray, function(a, b) return a.count > b.count end)

  jobCache = jobArray
  cacheDirty = false
  return jobArray
end

--- Get color for a job
--- @param jobName string
--- @return string
function ScoreboardModule.GetJobColor(jobName)
  if Config.Jobs[jobName] and Config.Jobs[jobName].color then
    return Config.Jobs[jobName].color
  end
  local colors = {
    police = "#3B82F6",
    ambulance = "#EF4444",
    mechanic = "#F59E0B",
    taxi = "#FBBF24",
    realtor = "#10B981",
    cardealer = "#8B5CF6",
    banker = "#06B6D4",
    unemployed = "#6B7280"
  }
  return colors[jobName] or "#FB9B04"
end

--- Get player activity
--- @param source number
--- @return string|nil
function ScoreboardModule.GetPlayerActivity(source)
  return nil
end

--- Get active activities
--- @return table
function ScoreboardModule.GetActiveActivities()
  return cachedActivities
end

--- Add an activity
--- @param activityType string
--- @param label string
--- @param location string
--- @param players table|nil
function ScoreboardModule.AddActivity(activityType, label, location, players)
  local configType = Config.ActivityTypes[activityType]
  local activity = {
    id = nextActivityId,
    type = activityType,
    label = label or (configType and configType.label) or activityType,
    location = location,
    startTime = os.time(),
    players = players or {}
  }

  nextActivityId = nextActivityId + 1
  table.insert(cachedActivities, activity)
  DeferredBroadcast()

  return activity.id
end

--- Remove an activity
--- @param activityId number
function ScoreboardModule.RemoveActivity(activityId)
  for i, activity in ipairs(cachedActivities) do
    if activity.id == activityId then
      table.remove(cachedActivities, i)
      DeferredBroadcast()
      return true
    end
  end
  return false
end

--- Update an activity
--- @param activityId number
--- @param data table
function ScoreboardModule.UpdateActivity(activityId, data)
  for _, activity in ipairs(cachedActivities) do
    if activity.id == activityId then
      for key, value in pairs(data) do
        activity[key] = value
      end
      DeferredBroadcast()
      return true
    end
  end
  return false
end

--- Send data to specific client
--- @param source number
function ScoreboardModule.SendToClient(source)
  local players = ScoreboardModule.GetAllPlayers()
  local jobs = ScoreboardModule.GetJobCounts()
  local info = ScoreboardModule.GetServerInfo()

  TriggerClientEvent("esx_scoreboard:client:receiveData", source,
    players,
    jobs,
    cachedActivities,
    info
  )
end

--- Track clients that have the scoreboard open
local activeClients = {}

--- Register server event for data request
RegisterNetEvent("esx_scoreboard:server:requestData", function()
    local src = source
    local now = os.time()
    if lastRequest[src] and (now - lastRequest[src]) < 2 then return end
    lastRequest[src] = now

    activeClients[src] = true
    ScoreboardModule.SendToClient(src)
end)

--- Client explicitly closed scoreboard
RegisterNetEvent("esx_scoreboard:server:close", function()
    activeClients[source] = nil
end)

--- Broadcast only to clients that actually have the scoreboard open
function ScoreboardModule.BroadcastUpdate()
    local players = ScoreboardModule.GetAllPlayers()
    local jobs = ScoreboardModule.GetJobCounts()
    local info = ScoreboardModule.GetServerInfo()

    for clientId, _ in pairs(activeClients) do
        TriggerClientEvent("esx_scoreboard:client:receiveData", clientId,
            players, jobs, cachedActivities, info)
    end
end

--- Handle player dropped — clean up tracking and invalidate cache
AddEventHandler("playerDropped", function(reason)
    activeClients[source] = nil
    lastRequest[source] = nil
    InvalidateCache()
end)

--- Invalidate cache when a new player connects
AddEventHandler("playerConnecting", function()
    InvalidateCache()
end)

--- Invalidate cache when a player changes job
AddEventHandler("esx:setJob", function(source, job, lastJob)
    InvalidateCache()
end)

--- Export for other resources to add activities
exports("AddActivity", ScoreboardModule.AddActivity)
exports("RemoveActivity", ScoreboardModule.RemoveActivity)
exports("UpdateActivity", ScoreboardModule.UpdateActivity)
exports("GetActiveActivities", ScoreboardModule.GetActiveActivities)

return ScoreboardModule