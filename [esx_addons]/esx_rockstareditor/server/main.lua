-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local accessLimiter = xLib.rateLimiter({
    capacity = 4,
    refill = 2,
    interval = 1000,
})
local actions =
    { open = true, start = true, save = true, discard = true, editor = true, status = true }

xLib.callback.register('esx_rockstareditor:authorize', function(source, action)
    if type(action) ~= 'string' or not actions[action] then
        return { ok = false, reason = 'invalid_action' }
    end

    if not accessLimiter:consume(source) then
        return { ok = false, reason = 'busy' }
    end

    local player = ESX.GetPlayerFromId(source)

    if not player then
        return { ok = false, reason = 'access_denied' }
    end

    if Config.RestrictAccess then
        local allowedGroup = Config.AllowedGroups[player.getGroup()] == true
        local allowedAce = type(Config.AcePermission) == 'string'
            and Config.AcePermission ~= ''
            and IsPlayerAceAllowed(source, Config.AcePermission)

        if not allowedGroup and not allowedAce then
            return { ok = false, reason = 'access_denied' }
        end
    end

    local replaySetting = GetConvar('sv_disableClientReplays', 'false'):lower()
    local replaysDisabled = replaySetting == 'true' or replaySetting == '1'

    if replaysDisabled and (action == 'start' or action == 'editor') then
        return { ok = false, reason = 'replays_disabled' }
    end

    return { ok = true, replaysDisabled = replaysDisabled }
end)
