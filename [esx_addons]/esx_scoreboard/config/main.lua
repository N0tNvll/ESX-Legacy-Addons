--- @module config.main
--- Configuration file for the scoreboard resource

Config = {}

--- Key to open the scoreboard (default: Z - 20)
Config.OpenKey = 20

--- Interval (ms) to refresh scoreboard data
Config.UpdateInterval = 5000

--- Server display name shown in the scoreboard header
Config.ServerName = "ESX Server"

--- Max players displayed in the header (set to nil to use sv_maxclients convar)
Config.MaxPlayers = 64

--- Logo URL shown in the scoreboard header (set to "" to show ESX placeholder)
Config.LogoUrl = ""

--- Jobs to display in the scoreboard with their display labels
Config.Jobs = {
  police = { label = "Police", color = "#3B82F6" },
  ambulance = { label = "EMS", color = "#EF4444" },
  mechanic = { label = "Mechanic", color = "#F59E0B" },
  taxi = { label = "Taxi", color = "#FBBF24" },
  realtor = { label = "Realtor", color = "#10B981" },
  cardealer = { label = "Car Dealer", color = "#8B5CF6" },
  banker = { label = "Banker", color = "#06B6D4" }
}

--- Activity types that can be shown in the scoreboard
Config.ActivityTypes = {
  robbery = { label = "Robbery", icon = "💰" },
  heist = { label = "Heist", icon = "🏦" },
  drug = { label = "Drug Sale", icon = "💊" },
  race = { label = "Street Race", icon = "🏎️" },
  hostage = { label = "Hostage", icon = "🚫" },
  shootout = { label = "Shootout", icon = "🔫" }
}