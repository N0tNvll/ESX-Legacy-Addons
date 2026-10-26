-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {}

Config.Locale = GetConvar('esx:locale', 'en')
Config.Command = 'rockstar'
Config.Aliases = { 'rockstareditor' }

Config.Keybind = ''
Config.CloseOnRecord = true
Config.ShowRecordingIndicator = true
-- Optional: hide GTA's above-radar notification panel during recording.
-- esx_hud moves status/location out of the way, so the native feed can remain visible.
Config.HideGameFeedWhileRecording = false
Config.AccessTimeout = 5000

Config.RestrictAccess = false
Config.AllowedGroups = {
    admin = true,
    superadmin = true,
    moderator = true,
}
Config.AcePermission = 'esx_rockstareditor.use'
