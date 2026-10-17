---@class HalloweenConfig
---@field Ghost GhostConfig
---@field TrickOrTreat TrickOrTreatConfig
---@field RoutingBucket integer
---@field AdminGroups string[]

---@class GhostConfig
---@field enabled boolean
---@field spawnChance integer
---@field pedModel string
---@field maxDuration integer
---@field exitKeybind string
---@field visibility {range: number, alpha: integer}
---@field movement {speedMultiplier: number}
---@field abilities {scare: GhostScareConfig}
---@field security GhostSecurityConfig

---@class GhostScareConfig
---@field enabled boolean
---@field cooldown integer
---@field range number
---@field keybind string
---@field effects {screenShake: boolean, sound: boolean, soundVolume: number, duration: integer}

---@class GhostSecurityConfig
---@field ghostRequestCooldown integer
---@field maxConcurrentGhosts integer
---@field deathCooldown integer
---@field requestTimeout integer
---@field offerTimeout integer

---@class TrickOrTreatConfig
---@field enabled boolean
---@field roundFrequencyMinutes number Pause after a completed round
---@field roundDurationMinutes number
---@field doorsPerRound integer Shared, not per-player
---@field progressSyncInterval integer
---@field npcSpawnDistance number
---@field npcDespawnDistance number
---@field houses HouseLocation[]
---@field blips {sprite: integer, activeColor: integer, scale: number}
---@field notifications {roundStart: integer, houseEmpty: integer}
---@field interaction table
---@field rewards table Amounts are final; there is no candyPerDoor multiplier

---@class HouseLocation
---@field coords vector3
---@field heading number
---@field pedModel string

---@class ThemeColors
---@field primary string
---@field secondary string
---@field background string
---@field accent string
---@field logoUrl string

---@class NotificationData
---@field size 'small'|'large'
---@field position 'top-left'|'top-right'|'top-center'|'bottom-center'
---@field header string
---@field description string
---@field duration integer?
