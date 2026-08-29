--- @module server.module.main
--- Main server module for the scoreboard resource

local ScoreboardModule = {}

local RESOURCE_NAME <const> = GetCurrentResourceName()
local PING_REFRESH_INTERVAL <const> = 10000  
local REQUEST_COOLDOWN <const> = 2            
local BROADCAST_DEFER_MS <const> = 500      
local INVALIDATE_DEBOUNCE_MS <const> = 1000   
local MAX_ACTIVITY_TYPE_LEN <const> = 50
local MAX_ACTIVITY_LABEL_LEN <const> = 100
local MAX_ACTIVITY_LOCATION_LEN <const> = 100

--- @type table<number, table> Active activity entries.
local cachedActivities = {}

--- @type number Monotonic activity ID counter.
local nextActivityId = 1

--- @type number Server start timestamp (seconds).
local serverStartTime = os.time()

--- @type table<number, number> Last request timestamp per client source.
local lastRequest = {}

--- @type table<number, boolean> Clients with scoreboard currently open.
local activeClients = {}

--- @type table<number, string> Maps player source -> current job name for fast decrement on drop.
local playerJobMap = {}

--- @type table<string, table> Incremental job counters: [jobName] = { name, label, count, color }
local jobCounters = {}

--- @type table|nil Cached player array.
local playerCache = nil

--- @type number Cached player count for cache validation.
local cachedPlayerCount = 0

--- @type boolean True when player cache needs rebuild.
local cacheDirty = true

--- @type number Last time pings were refreshed (GetGameTimer).
local lastPingUpdate = 0

--- @type boolean Prevents stacked activity broadcasts.
local activityBroadcastPending = false

--- @type boolean Prevents stacked cache invalidations.
local invalidatePending = false


local function InvalidateCache()
  if invalidatePending then return end
  invalidatePending = true
  CreateThread(function()
    Wait(INVALIDATE_DEBOUNCE_MS)
    invalidatePending = false
    cacheDirty = true
  end)
end

local function DeferredBroadcastActivities()
  if activityBroadcastPending then return end
  activityBroadcastPending = true
  CreateThread(function()
    Wait(BROADCAST_DEFER_MS)
    activityBroadcastPending = false
    ScoreboardModule.BroadcastActivities()
  end)
end


--- Initialize job counters from the ESX job registry.
--- @return boolean success
local function InitJobCounters()
  local jobs = ESX.GetJobs()
  if type(jobs) ~= "table" then
    return false
  end

  jobCounters = {}
  for name, jobData in pairs(jobs) do
    jobCounters[name] = {
      name = name,
      label = jobData.label or name,
      count = 0,
      color = ScoreboardModule.GetJobColor(name)
    }
  end
  return true
end

--- Atomically increment a job counter.
--- @param jobName string
local function IncrementJob(jobName)
  local job = jobCounters[jobName]
  if job then
    job.count = job.count + 1
  end
end

--- Atomically decrement a job counter, clamped at 0.
--- @param jobName string
local function DecrementJob(jobName)
  local job = jobCounters[jobName]
  if job then
    job.count = math.max(0, job.count - 1)
  end
end

--- Get current server uptime in seconds.
--- @return number
function ScoreboardModule.GetUptime()
  return os.time() - serverStartTime
end

--- Get configured max players.
--- @return number
function ScoreboardModule.GetMaxPlayers()
  if Config.MaxPlayers and Config.MaxPlayers > 0 then
    return Config.MaxPlayers
  end
  return GetConvarInt("sv_maxclients", 128)
end

--- Get configured server name.
--- @return string
function ScoreboardModule.GetServerName()
  return Config.ServerName or "ESX Server"
end

--- Get configured logo URL.
--- @return string
function ScoreboardModule.GetLogoUrl()
  return Config.LogoUrl or ""
end

--- Build server info object for NUI.
--- @return table
function ScoreboardModule.GetServerInfo()
  return {
    serverName = ScoreboardModule.GetServerName(),
    maxPlayers = ScoreboardModule.GetMaxPlayers(),
    logoUrl = ScoreboardModule.GetLogoUrl(),
    uptime = ScoreboardModule.GetUptime()
  }
end

--- Get color for a job. 
--- @param jobName string
--- @return string Hex color code
function ScoreboardModule.GetJobColor(jobName)
  if Config.Jobs and Config.Jobs[jobName] and Config.Jobs[jobName].color then
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

--- Get player activity.
--- @param source number
--- @return string|nil
function ScoreboardModule.GetPlayerActivity(source)
  return nil
end

--- Get active activities.
--- @return table
function ScoreboardModule.GetActiveActivities()
  return cachedActivities
end

--- Get all connected players data.
--- @param table|nil preFetchedIds Optional pre-fetched GetPlayers() result.
--- @return table Array of player data.
function ScoreboardModule.GetAllPlayers(preFetchedIds)
  local allPlayerIds = preFetchedIds or GetPlayers()
  local currentCount = #allPlayerIds
  local now = GetGameTimer()

  if not cacheDirty and playerCache and cachedPlayerCount == currentCount then
    if (now - lastPingUpdate) >= PING_REFRESH_INTERVAL then
      lastPingUpdate = now
      for _, player in ipairs(playerCache) do
        player.ping = GetPlayerPing(player.serverId) or 0
      end
    end
    return playerCache
  end

  lastPingUpdate = now
  local players = {}

  for _, playerId in ipairs(allPlayerIds) do
    local sourceNum = tonumber(playerId)
    if sourceNum then
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
  end

  playerCache = players
  cachedPlayerCount = currentCount
  cacheDirty = false
  return players
end

--- Get job counts.
--- @return table Sorted array of active jobs.
function ScoreboardModule.GetJobCounts()
  local result = {}
  for _, data in pairs(jobCounters) do
    if data.count > 0 then
      table.insert(result, data)
    end
  end
  table.sort(result, function(a, b) return a.count > b.count end)
  return result
end

--- Add an activity.
--- @param activityType string
--- @param label string|nil
--- @param location string|nil
--- @param players table|nil
--- @return number activityId
function ScoreboardModule.AddActivity(activityType, label, location, players)
  if type(activityType) ~= "string" or #activityType == 0 or #activityType > MAX_ACTIVITY_TYPE_LEN then
    print("[^3esx_scoreboard^7] Warning: Invalid activityType rejected")
    return -1
  end

  if label and type(label) == "string" and #label > MAX_ACTIVITY_LABEL_LEN then
    label = label:sub(1, MAX_ACTIVITY_LABEL_LEN)
  end

  if location and type(location) == "string" and #location > MAX_ACTIVITY_LOCATION_LEN then
    location = location:sub(1, MAX_ACTIVITY_LOCATION_LEN)
  end

  if players and type(players) ~= "table" then
    players = {}
  end

  local configType = Config.ActivityTypes and Config.ActivityTypes[activityType]
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
  DeferredBroadcastActivities()

  return activity.id
end

--- Remove an activity by ID.
--- @param activityId number
--- @return boolean success
function ScoreboardModule.RemoveActivity(activityId)
  if type(activityId) ~= "number" then return false end

  for i, activity in ipairs(cachedActivities) do
    if activity.id == activityId then
      table.remove(cachedActivities, i)
      DeferredBroadcastActivities()
      return true
    end
  end
  return false
end

--- Update an activity by ID.
--- @param activityId number
--- @param data table
--- @return boolean success
function ScoreboardModule.UpdateActivity(activityId, data)
  if type(activityId) ~= "number" or type(data) ~= "table" then return false end

  for _, activity in ipairs(cachedActivities) do
    if activity.id == activityId then
      for key, value in pairs(data) do
        activity[key] = value
      end
      DeferredBroadcastActivities()
      return true
    end
  end
  return false
end

--- Send full data payload to a specific client.
--- @param source number
function ScoreboardModule.SendToClient(source)
  local allIds = GetPlayers()
  local players = ScoreboardModule.GetAllPlayers(allIds)
  local jobs = ScoreboardModule.GetJobCounts()
  local info = ScoreboardModule.GetServerInfo()

  TriggerClientEvent("esx_scoreboard:client:receiveData", source,
    players, jobs, cachedActivities, info)
end

--- Broadcast full update to all clients with scoreboard open.
function ScoreboardModule.BroadcastUpdate()
  local allIds = GetPlayers()
  local players = ScoreboardModule.GetAllPlayers(allIds)
  local jobs = ScoreboardModule.GetJobCounts()
  local info = ScoreboardModule.GetServerInfo()

  for clientId, _ in pairs(activeClients) do
    TriggerClientEvent("esx_scoreboard:client:receiveData", clientId,
      players, jobs, cachedActivities, info)
  end
end

--- Broadcast only activities to all clients with scoreboard open.
function ScoreboardModule.BroadcastActivities()
  for clientId, _ in pairs(activeClients) do
    TriggerClientEvent("esx_scoreboard:client:receiveActivities", clientId, cachedActivities)
  end
end

RegisterNetEvent("esx_scoreboard:server:requestData", function()
  local src = source
  if type(src) ~= "number" or src <= 0 then return end

  local now = os.time()
  if lastRequest[src] and (now - lastRequest[src]) < REQUEST_COOLDOWN then
    return
  end
  lastRequest[src] = now

  activeClients[src] = true
  ScoreboardModule.SendToClient(src)
end)

RegisterNetEvent("esx_scoreboard:server:close", function()
  local src = source
  if type(src) == "number" then
    activeClients[src] = nil
  end
end)

AddEventHandler("esx:playerLoaded", function(playerId, xPlayer)
  if not xPlayer or not xPlayer.job then return end

  local jobName = xPlayer.job.name
  IncrementJob(jobName)
  playerJobMap[playerId] = jobName

  InvalidateCache()
end)

AddEventHandler("playerDropped", function(reason)
  local src = source
  if type(src) ~= "number" then return end
  local jobName = playerJobMap[src]
  if jobName then
    DecrementJob(jobName)
    playerJobMap[src] = nil
  end

  activeClients[src] = nil
  lastRequest[src] = nil
  InvalidateCache()
end)

AddEventHandler("esx:setJob", function(source, newJob, lastJob)
  if type(source) ~= "number" then return end

  if lastJob and lastJob.name then
    DecrementJob(lastJob.name)
  end
  if newJob and newJob.name then
    IncrementJob(newJob.name)
    playerJobMap[source] = newJob.name
  end

  InvalidateCache()
end)

AddEventHandler("playerConnecting", function()
  InvalidateCache()
end)

AddEventHandler("onResourceStart", function(resourceName)
  if resourceName ~= RESOURCE_NAME then return end

  CreateThread(function()
    local attempts = 0
    while not InitJobCounters() and attempts < 10 do
      Wait(1000)
      attempts = attempts + 1
    end

    if attempts >= 10 then
      if Config.Debug then
        print("[^1esx_scoreboard^7] Critical: ESX.GetJobs() unavailable after 10 attempts")
      end
      return
    end

    if Config.Debug then
      print("[^2esx_scoreboard^7] Job counters initialized. Syncing existing players...")
    end

    for _, pid in ipairs(GetPlayers()) do
      local src = tonumber(pid)
      local xPlayer = src and ESX.GetPlayerFromId(src)
      if xPlayer and xPlayer.job then
        IncrementJob(xPlayer.job.name)
        playerJobMap[src] = xPlayer.job.name
      end
    end

    if Config.Debug then
      print("[^2esx_scoreboard^7] Scoreboard ready " .. #GetPlayers() .. " players")
    end
  end)
end)

exports("AddActivity", ScoreboardModule.AddActivity)
exports("RemoveActivity", ScoreboardModule.RemoveActivity)
exports("UpdateActivity", ScoreboardModule.UpdateActivity)
exports("GetActiveActivities", ScoreboardModule.GetActiveActivities)

return ScoreboardModule