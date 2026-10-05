-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {}

-- Core behavior
Config.OpenKey = 'T'
Config.MaxMessageLength = 280
Config.MessageCooldown = 600 -- milliseconds
Config.ProximityDistance = 20.0
Config.MaxVisibleMessages = 5
Config.KeepMessages = 100
Config.EmitLegacyChatMessage = true
Config.AllowGlobalChat = true -- kept for compatibility with resources that trigger esx_chat:submitGlobal

-- UI behavior
Config.AutoHideAfter = 12000 -- milliseconds, 0 disables message fading
Config.ShowCommandPanelOnOpen = false -- suggestions only appear after typing '/'
Config.UseGameClock = true

-- Commands shown by the slash suggestion system.
Config.Commands = {
    { name = '/me', description = 'Perform an action' },
    { name = '/do', description = 'Describe the surroundings' },
    { name = '/environment', description = 'Describe the environment around you' },
    { name = '/dice', description = 'Roll a six-sided die' },
    { name = '/try', description = 'Attempt an action with a success/failure result' },
    { name = '/ooc', description = 'Out of character chat' },
    { name = '/job', description = 'Message players with the same job' },
    { name = '/pm [id]', description = 'Private message' },
    { name = '/report', description = 'Report a player' },
    { name = '/help', description = 'Show all commands' }
}

-- Commands exposed inside the RP tab.
Config.RPCommands = {
    { name = '/me', description = 'Perform an action' },
    { name = '/do', description = 'Describe the surroundings' },
    { name = '/environment', description = 'Describe the environment' },
    { name = '/dice', description = 'Roll a die' },
    { name = '/try', description = 'Try an action' }
}

-- Groups that receive /report messages.
Config.AdminGroups = {
    admin = true,
    superadmin = true
}
