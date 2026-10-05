-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local lastMessageAt = {}

local function trim(value)
    return (value:gsub('^%s*(.-)%s*$', '%1'))
end

local function sanitizeText(value)
    if type(value) ~= 'string' then
        return nil
    end

    value = value:gsub('[\r\n\t]', ' '):gsub('%s+', ' ')
    value = trim(value)

    if value == '' then
        return nil
    end

    if #value > Config.MaxMessageLength then
        value = value:sub(1, Config.MaxMessageLength)
    end

    return value
end

local function getXPlayer(playerId)
    if ESX.Player then
        return ESX.Player(playerId)
    end

    return ESX.GetPlayerFromId(playerId)
end

local function getPlayerName(playerId)
    local xPlayer = getXPlayer(playerId)

    if xPlayer and xPlayer.getName then
        local ok, name = pcall(function()
            return xPlayer.getName()
        end)

        if ok and type(name) == 'string' and name ~= '' then
            return name
        end
    end

    return GetPlayerName(playerId) or ('Player %s'):format(playerId)
end

local function getPlayerJob(playerId)
    local xPlayer = getXPlayer(playerId)
    if not xPlayer then
        return nil
    end

    if xPlayer.getJob then
        local ok, job = pcall(function()
            return xPlayer.getJob()
        end)
        if ok and type(job) == 'table' then
            return job
        end
    end

    if type(xPlayer.job) == 'table' then
        return xPlayer.job
    end

    return nil
end

local function isRateLimited(playerId)
    local now = GetGameTimer()
    local previous = lastMessageAt[playerId] or 0

    if previous ~= 0 and (now - previous) < Config.MessageCooldown then
        return true
    end

    lastMessageAt[playerId] = now
    return false
end

local function push(target, payload)
    TriggerClientEvent('esx_chat:pushMessage', target, payload)
end

local function systemMessage(target, text)
    push(target, {
        type = 'system',
        title = 'SYSTEM',
        text = text,
        icon = 'system'
    })
end

local function validatePlayerCommand(playerId, args)
    if playerId == 0 then
        print('[esx_chat] This command can only be used by a player.')
        return nil
    end

    if isRateLimited(playerId) then
        systemMessage(playerId, 'You are sending messages too quickly.')
        return nil
    end

    return sanitizeText(table.concat(args, ' '))
end

local function canUseNoArgCommand(playerId)
    if playerId == 0 then
        print('[esx_chat] This command can only be used by a player.')
        return false
    end

    if isRateLimited(playerId) then
        systemMessage(playerId, 'You are sending messages too quickly.')
        return false
    end

    return true
end

local function broadcastProximity(playerId, kind, text, title)
    local name = getPlayerName(playerId)

    TriggerClientEvent('esx_chat:pushProximity', -1, playerId, {
        type = kind,
        title = title or name,
        text = text,
        icon = 'user-plus'
    })
end

RegisterNetEvent('esx_chat:submitGlobal', function(rawText)
    local playerId = source

    if not Config.AllowGlobalChat or playerId == 0 or isRateLimited(playerId) then
        if playerId ~= 0 and Config.AllowGlobalChat then
            systemMessage(playerId, 'You are sending messages too quickly.')
        end
        return
    end

    local text = sanitizeText(rawText)
    if not text then
        return
    end

    local name = getPlayerName(playerId)

    if Config.EmitLegacyChatMessage then
        TriggerEvent('chatMessage', playerId, name, text)
        if WasEventCanceled() then
            return
        end
    end

    push(-1, {
        type = 'global',
        title = name,
        text = text,
        icon = 'user'
    })
end)

RegisterCommand('me', function(playerId, args)
    local text = validatePlayerCommand(playerId, args)
    if text then
        broadcastProximity(playerId, 'me', text)
    end
end, false)

RegisterCommand('do', function(playerId, args)
    local text = validatePlayerCommand(playerId, args)
    if text then
        broadcastProximity(playerId, 'do', text)
    end
end, false)

RegisterCommand('environment', function(playerId, args)
    local text = validatePlayerCommand(playerId, args)
    if text then
        broadcastProximity(playerId, 'environment', text, ('ENVIRONMENT | %s'):format(getPlayerName(playerId)))
    end
end, false)

RegisterCommand('dice', function(playerId)
    if not canUseNoArgCommand(playerId) then
        return
    end

    local roll = math.random(1, 6)
    broadcastProximity(playerId, 'dice', ('rolled a %d.'):format(roll), ('DICE | %s'):format(getPlayerName(playerId)))
end, false)

RegisterCommand('try', function(playerId, args)
    local text = validatePlayerCommand(playerId, args)
    if not text then
        if playerId ~= 0 then
            systemMessage(playerId, 'Usage: /try [action]')
        end
        return
    end

    local success = math.random(0, 1) == 1
    local result = success and 'SUCCESS' or 'FAILURE'
    broadcastProximity(playerId, 'try', ('%s — %s'):format(text, result), ('TRY | %s'):format(getPlayerName(playerId)))
end, false)

RegisterCommand('ooc', function(playerId, args)
    local text = validatePlayerCommand(playerId, args)
    if not text then
        return
    end

    push(-1, {
        type = 'ooc',
        title = ('OOC | %s'):format(getPlayerName(playerId)),
        text = text,
        icon = 'user'
    })
end, false)

RegisterCommand('job', function(playerId, args)
    local text = validatePlayerCommand(playerId, args)
    if not text then
        if playerId ~= 0 then
            systemMessage(playerId, 'Usage: /job [message]')
        end
        return
    end

    local senderJob = getPlayerJob(playerId)
    if not senderJob or not senderJob.name then
        systemMessage(playerId, 'Your job could not be determined.')
        return
    end

    local senderName = getPlayerName(playerId)
    local jobLabel = senderJob.label or senderJob.name

    for _, target in ipairs(GetPlayers()) do
        local targetId = tonumber(target)
        if targetId then
            local targetJob = getPlayerJob(targetId)
            if targetJob and targetJob.name == senderJob.name then
                push(targetId, {
                    type = 'job',
                    title = ('%s | %s'):format(string.upper(jobLabel), senderName),
                    text = text,
                    icon = 'user'
                })
            end
        end
    end
end, false)

local function privateMessage(playerId, args)
    if playerId == 0 then
        print('[esx_chat] /pm can only be used by a player.')
        return
    end

    if isRateLimited(playerId) then
        systemMessage(playerId, 'You are sending messages too quickly.')
        return
    end

    local targetId = tonumber(args[1])
    if not targetId or not GetPlayerName(targetId) then
        systemMessage(playerId, 'Player not found. Usage: /pm [id] [message]')
        return
    end

    table.remove(args, 1)
    local text = sanitizeText(table.concat(args, ' '))
    if not text then
        systemMessage(playerId, 'Usage: /pm [id] [message]')
        return
    end

    local senderName = getPlayerName(playerId)
    local targetName = getPlayerName(targetId)

    push(targetId, {
        type = 'pm',
        title = ('[PM] %s → You'):format(senderName),
        text = text,
        icon = 'message'
    })

    push(playerId, {
        type = 'pm',
        title = ('[PM] You → %s'):format(targetName),
        text = text,
        icon = 'message'
    })
end

RegisterCommand('pm', privateMessage, false)
RegisterCommand('msg', privateMessage, false)

RegisterCommand('report', function(playerId, args)
    local text = validatePlayerCommand(playerId, args)
    if not text then
        if playerId ~= 0 then
            systemMessage(playerId, 'Usage: /report [message]')
        end
        return
    end

    local senderName = getPlayerName(playerId)
    local delivered = false

    for _, target in ipairs(GetPlayers()) do
        local targetId = tonumber(target)
        local xPlayer = targetId and getXPlayer(targetId)
        local group

        if xPlayer and xPlayer.getGroup then
            local ok, value = pcall(function()
                return xPlayer.getGroup()
            end)
            if ok then
                group = value
            end
        end

        if group and Config.AdminGroups[group] then
            delivered = true
            push(targetId, {
                type = 'system',
                title = ('REPORT #%s · %s'):format(playerId, senderName),
                text = text,
                icon = 'system'
            })
        end
    end

    print(('[esx_chat] REPORT #%s %s: %s'):format(playerId, senderName, text))
    systemMessage(playerId, delivered and 'Your report was sent to online staff.' or 'Your report was logged; no staff are currently online.')
end, false)

RegisterCommand('help', function(playerId)
    if playerId == 0 then
        return
    end

    systemMessage(playerId, 'Commands: /me, /do, /environment, /dice, /try, /ooc, /job, /pm [id], /report, /help')
end, false)

AddEventHandler('playerDropped', function()
    lastMessageAt[source] = nil
end)

exports('addMessage', function(target, message)
    push(target or -1, message)
end)
