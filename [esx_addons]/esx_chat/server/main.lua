-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local limiter = xLib.rateLimiter({
    capacity = Config.RateLimit.burst,
    refill = 1,
    interval = Config.RateLimit.interval
})

local function sanitizeText(value)
    if type(value) ~= 'string' then
        return nil
    end

    if #value > Config.MaxMessageLength * 4 then
        value = value:sub(1, Config.MaxMessageLength * 4)
    end

    value = value:gsub('%c', ' '):gsub('%s+', ' ')
    value = value:match('^%s*(.*%S)') or ''

    if #value > Config.MaxMessageLength then
        value = value:sub(1, Config.MaxMessageLength)
    end

    while #value > 0 and not utf8.len(value) do
        value = value:sub(1, -2)
    end

    if value == '' then
        return nil
    end

    return value
end

local function getPlayerName(playerId, xPlayer)
    local name = xPlayer and xPlayer.getName()

    if type(name) == 'string' and name ~= '' then
        return name
    end

    return GetPlayerName(playerId) or ('Player %s'):format(playerId)
end

local function push(target, payload)
    TriggerClientEvent('esx_chat:pushMessage', target, payload)
end

local function systemMessage(target, text)
    push(target, {
        type = 'system',
        title = TranslateCap('title_system'),
        text = text,
        icon = 'system'
    })
end

local function log(command, playerId, xPlayer, text, recipients, extra)
    if not Config.Logs.enabled or command.log == false then
        return
    end

    local fields = {
        { name = 'Player', value = ('%s (%s)'):format(getPlayerName(playerId, xPlayer), playerId), inline = true },
        { name = 'Identifier', value = xPlayer and xPlayer.getIdentifier() or '-', inline = true },
        { name = 'Recipients', value = recipients, inline = true }
    }

    if extra then
        fields[#fields + 1] = extra
    end

    fields[#fields + 1] = { name = 'Message', value = text or '-' }

    ESX.DiscordLogFields(Config.Logs.channel, ('/%s'):format(command.name), 'default', fields)
end

local function sendToPlayers(playerIds, payload)
    for i = 1, #playerIds do
        push(playerIds[i], payload)
    end

    return #playerIds
end

local function getNearbyPlayerIds(playerId, distance)
    local nearby = xLib.onesync.getPlayersInArea(playerId, distance, nil, GetPlayerRoutingBucket(playerId))
    local ids = {}

    for i = 1, #nearby do
        ids[i] = nearby[i].id
    end

    return ids
end

local function rollDice(sides)
    return math.random(1, math.max(2, math.floor(tonumber(sides) or 6)))
end

local function buildProximityMessage(command, name, text)
    local key = command.name

    if key == 'dice' then
        return {
            type = 'dice',
            title = TranslateCap('title_dice', name),
            text = _U('dice_result', rollDice(command.sides)),
            icon = 'user-plus'
        }
    end

    if key == 'try' then
        local result = math.random(0, 1) == 1 and _U('try_success') or _U('try_failure')

        return {
            type = 'try',
            title = TranslateCap('title_try', name),
            text = _U('try_result', text, result),
            icon = 'user-plus'
        }
    end

    if key == 'environment' then
        return {
            type = 'environment',
            title = TranslateCap('title_environment', name),
            text = text,
            icon = 'user-plus'
        }
    end

    return {
        type = key,
        title = name,
        text = text,
        icon = 'user-plus'
    }
end

local handlers = {}

handlers.proximity = function(command, playerId, xPlayer, text)
    local name = getPlayerName(playerId, xPlayer)
    local payload = buildProximityMessage(command, name, text)
    local recipients = sendToPlayers(getNearbyPlayerIds(playerId, command.distance or Config.ProximityDistance), payload)

    log(command, playerId, xPlayer, payload.text, recipients)
end

handlers.global = function(command, playerId, xPlayer, text)
    local name = getPlayerName(playerId, xPlayer)
    local title

    if command.anonymous then
        title = TranslateCap('title_anontwt')
    elseif command.name == 'twt' then
        title = TranslateCap('title_twt', name)
    else
        title = TranslateCap('title_ooc', name)
    end

    push(-1, {
        type = command.name,
        title = title,
        text = text,
        icon = command.name == 'ooc' and 'user' or 'message'
    })

    log(command, playerId, xPlayer, text, GetNumPlayerIndices())
end

handlers.job = function(command, playerId, xPlayer, text)
    local job = xPlayer.getJob()

    if type(job) ~= 'table' or not job.name then
        return systemMessage(playerId, _U('job_unknown'))
    end

    local recipients = sendToPlayers(ESX.GetExtendedPlayers('job', job.name, true), {
        type = 'job',
        title = _U('title_job', string.upper(job.label or job.name), getPlayerName(playerId, xPlayer)),
        text = text,
        icon = 'user'
    })

    log(command, playerId, xPlayer, text, recipients, { name = 'Job', value = job.name, inline = true })
end

handlers.private = function(command, playerId, xPlayer, text, targetId)
    if not targetId or not GetPlayerName(targetId) then
        return systemMessage(playerId, _U('player_not_found'))
    end

    local senderName = getPlayerName(playerId, xPlayer)
    local targetName = getPlayerName(targetId, ESX.GetPlayerFromId(targetId))

    push(targetId, {
        type = 'pm',
        title = _U('title_pm_in', senderName),
        text = text,
        icon = 'message'
    })

    push(playerId, {
        type = 'pm',
        title = _U('title_pm_out', targetName),
        text = text,
        icon = 'message'
    })

    log(command, playerId, xPlayer, text, 1, { name = 'Target', value = ('%s (%s)'):format(targetName, targetId), inline = true })
end

handlers.staff = function(command, playerId, xPlayer, text)
    local name = getPlayerName(playerId, xPlayer)
    local payload = {
        type = 'system',
        title = _U('title_report', playerId, name),
        text = text,
        icon = 'system'
    }
    local recipients = 0

    for i = 1, #Config.StaffGroups do
        recipients = recipients + sendToPlayers(ESX.GetExtendedPlayers('group', Config.StaffGroups[i], true), payload)
    end

    systemMessage(playerId, recipients > 0 and _U('report_sent') or _U('report_logged'))
    log(command, playerId, xPlayer, text, recipients)
end

local helpText

handlers.help = function(_, playerId)
    systemMessage(playerId, helpText)
end

local NO_TEXT_COMMANDS = { dice = true, help = true }

local function buildSuggestion(command)
    local arguments = {}

    if command.scope == 'private' then
        arguments[#arguments + 1] = { name = 'playerId', help = _U('arg_player'), type = 'any' }
    end

    if not NO_TEXT_COMMANDS[command.name] then
        arguments[#arguments + 1] = { name = 'text', help = command.scope == 'proximity' and _U('arg_action') or _U('arg_message'), type = 'merge' }
    end

    return {
        help = command.description or _U(('command_%s'):format(command.name)),
        arguments = arguments,
        validate = false
    }
end

local function usage(command)
    local parts = {}

    for _, argument in ipairs(buildSuggestion(command).arguments) do
        parts[#parts + 1] = ('[%s]'):format(argument.help)
    end

    return _U('usage', command.name, table.concat(parts, ' '))
end

local function runCommand(command, xPlayer, args)
    if not xPlayer then
        return
    end

    local playerId = xPlayer.source

    if not limiter:consume(playerId) then
        return systemMessage(playerId, _U('rate_limited'))
    end

    local text

    if not NO_TEXT_COMMANDS[command.name] then
        text = sanitizeText(args.text)

        if not text then
            return systemMessage(playerId, usage(command))
        end
    end

    local handler = handlers[command.scope]

    if command.scope == 'private' then
        return handler(command, playerId, xPlayer, text, tonumber(args.playerId))
    end

    handler(command, playerId, xPlayer, text)
end

local function registerCommands()
    local names = {}

    for _, command in ipairs(Config.Commands) do
        if command.enabled ~= false and handlers[command.scope] then
            local commandNames = { command.name }

            for _, alias in ipairs(command.aliases or {}) do
                commandNames[#commandNames + 1] = alias
            end

            for _, name in ipairs(commandNames) do
                ESX.RegisterCommand(name, command.group or 'user', function(xPlayer, args)
                    runCommand(command, xPlayer, args)
                end, false, buildSuggestion(command))
            end

            names[#names + 1] = ('/%s'):format(command.name)
        elseif command.enabled ~= false then
            print(('[^3WARNING^7] esx_chat: command ^5%s^7 has an unknown scope ^5%s^7'):format(tostring(command.name), tostring(command.scope)))
        end
    end

    helpText = _U('help_list', table.concat(names, ', '))
end

registerCommands()

RegisterNetEvent('esx_chat:submitGlobal', function(rawText)
    local playerId = source

    if not Config.AllowGlobalChat then
        return
    end

    if not limiter:consume(playerId) then
        return systemMessage(playerId, _U('rate_limited'))
    end

    local text = sanitizeText(rawText)

    if not text then
        return
    end

    local xPlayer = ESX.GetPlayerFromId(playerId)
    local name = getPlayerName(playerId, xPlayer)

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

    log({ name = 'global' }, playerId, xPlayer, text, GetNumPlayerIndices())
end)

CreateThread(function()
    Wait(1000)

    if GetResourceState('chat') == 'started' then
        print('[^3WARNING^7] esx_chat replaces the default chat resource. Remove "ensure chat" from your server.cfg to avoid two chat windows.')
    end
end)

exports('addMessage', function(target, message)
    push(target or -1, message)
end)
