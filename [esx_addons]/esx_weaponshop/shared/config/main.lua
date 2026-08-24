---@type table
Config = Config or {}

-- ════════════════════════════════════════════════════════════════
-- CORE CONFIGURATION
-- ════════════════════════════════════════════════════════════════

Config.Locale = GetConvar('esx:locale', 'en')
Config.OxInventory = ESX.GetConfig().OxInventory

-- ════════════════════════════════════════════════════════════════
-- LICENSE CONFIGURATION
-- ════════════════════════════════════════════════════════════════

-- Only turn this on if you are using esx_license
Config.LicenseEnable = true
Config.LicensePrice = 5000

-- Server-side abuse protection
Config.ServerDistanceBuffer = 3.0
Config.PurchaseCooldown = 1500
Config.LicenseCallbackTimeout = 5000

-- ════════════════════════════════════════════════════════════════
-- MARKER CONFIGURATION
-- ════════════════════════════════════════════════════════════════

Config.DrawDistance = 10.0
Config.Size = { x = 1.5, y = 1.5, z = 0.5 }
Config.Color = { r = 0, g = 128, b = 255 }
Config.Type = 1
Config.InteractionDistance = 2.0
Config.InteractionKeyLabel = 'E'
