--- @module client.module.enum
--- Enum definitions for the scoreboard client module

local Enum = {}

--- Scoreboard visibility states
Enum.ScoreboardState = {
  CLOSED = 0,
  OPEN = 1
}

--- Player sort options
Enum.SortOption = {
  ID = "serverId",
  NAME = "name",
  JOB = "job",
  PING = "ping"
}

return Enum