-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {}

Config.Locale = GetConvar('esx:locale', 'en')

-- Core behavior
Config.OpenKey = 'T'
Config.MaxMessageLength = 280
Config.ProximityDistance = 20.0
Config.MaxVisibleMessages = 5
Config.KeepMessages = 100
Config.EmitLegacyChatMessage = true
Config.AllowGlobalChat = true -- kept for compatibility with resources that trigger esx_chat:submitGlobal

-- Anti-spam: `burst` messages at once, then one more every `interval` milliseconds
Config.RateLimit = {
    burst = 3,
    interval = 1500
}

-- UI behavior
-- 'always': messages stay visible
-- 'onMessage': messages appear on a new message and fade after AutoHideAfter
-- 'hidden': messages are only visible while the chat input is open
-- Players can switch their own mode with /chatmode or the button next to the input.
Config.DefaultDisplayMode = 'onMessage'
Config.AutoHideAfter = 12000 -- milliseconds, used by the 'onMessage' mode
Config.UseGameClock = true

-- Logs go through ESX.DiscordLogFields. Set the webhook in es_extended (Config.DiscordLogs.Webhooks.Chat)
-- or with the `esx:logs:Chat` convar when esx_lib provides xLib.logs.
Config.Logs = {
    enabled = true,
    channel = 'Chat'
}

-- Groups that receive /report messages.
Config.StaffGroups = { 'owner', 'admin' }

-- Chat commands. Each entry is registered with ESX.RegisterCommand.
--   name        command name, without the slash
--   aliases     extra names for the same command
--   enabled     set to false to disable the command
--   group       minimum ESX group allowed to use it ('user' = everyone)
--   scope       'proximity' | 'global' | 'job' | 'private' | 'staff' | 'help'
--   distance    proximity range, defaults to Config.ProximityDistance
--   rp          shown in the RP tab
--   anonymous   hides the author from players (staff still see it in the logs)
--   log         set to false to skip logging this command
--   description overrides the localized description
Config.Commands = {
    { name = 'me', scope = 'proximity', group = 'user', rp = true },
    { name = 'do', scope = 'proximity', group = 'user', rp = true },
    { name = 'environment', scope = 'proximity', group = 'user', rp = true },
    { name = 'dice', scope = 'proximity', group = 'user', rp = true, sides = 6 },
    { name = 'try', scope = 'proximity', group = 'user', rp = true },
    { name = 'ooc', scope = 'global', group = 'user' },
    { name = 'twt', scope = 'global', group = 'user' },
    { name = 'anontwt', scope = 'global', group = 'user', anonymous = true },
    { name = 'job', scope = 'job', group = 'user' },
    { name = 'pm', aliases = { 'msg' }, scope = 'private', group = 'user' },
    { name = 'report', scope = 'staff', group = 'user' },
    { name = 'help', scope = 'help', group = 'user' }
}
