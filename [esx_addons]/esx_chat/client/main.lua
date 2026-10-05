-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local chatOpen = false
local suggestions = {}
local templates = {}
local normalizeLegacyMessage

local function getClockTime()
    if Config.UseGameClock then
        return ('%02d:%02d'):format(GetClockHours(), GetClockMinutes())
    end

    return nil
end

local function pushMessage(message)
    if type(message) == 'table' and (message.args or message.template) and normalizeLegacyMessage then
        message = normalizeLegacyMessage(message) or message
    end

    if type(message) ~= 'table' then
        message = {
            type = 'system',
            title = 'SYSTEM',
            text = tostring(message),
            icon = 'system'
        }
    end

    if not message.time then
        message.time = getClockTime()
    end

    SendNUIMessage({
        action = 'message',
        message = message
    })
end

local function inferType(title)
    local value = string.lower(tostring(title or ''))

    if string.find(value, '[pm]', 1, true) or string.find(value, 'pm from', 1, true) then
        return 'pm'
    elseif string.find(value, 'system', 1, true) then
        return 'system'
    elseif string.find(value, 'ooc', 1, true) then
        return 'ooc'
    elseif string.find(value, 'environment', 1, true) then
        return 'environment'
    elseif string.find(value, 'dice', 1, true) then
        return 'dice'
    elseif string.find(value, 'try', 1, true) then
        return 'try'
    elseif string.find(value, 'job', 1, true) then
        return 'job'
    end

    return 'global'
end

normalizeLegacyMessage = function(message)
    if type(message) == 'string' then
        return {
            type = 'system',
            title = 'SYSTEM',
            text = message,
            icon = 'system'
        }
    end

    if type(message) ~= 'table' then
        return nil
    end

    local args = message.args or {}
    local title = ''
    local text = ''

    if #args >= 1 then
        title = tostring(args[1] or '')
    end

    if #args >= 2 then
        local parts = {}
        for index = 2, #args do
            parts[#parts + 1] = tostring(args[index] or '')
        end
        text = table.concat(parts, ' ')
    elseif #args == 1 then
        text = title
        title = ''
    end

    if message.template and templates[message.template] then
        local rendered = templates[message.template]
        for index, value in ipairs(args) do
            rendered = rendered:gsub('{' .. (index - 1) .. '}', tostring(value))
        end
        text = rendered:gsub('<.->', '')
        title = title ~= '' and title or 'SYSTEM'
    end

    local kind = message.esxType or message.type or inferType(title)

    return {
        type = kind,
        title = title,
        text = text,
        color = message.color,
        multiline = message.multiline,
        icon = message.icon
    }
end

local function setFocus(value)
    chatOpen = value
    SetNuiFocus(value, value)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = value and 'open' or 'close'
    })
end

RegisterNetEvent('esx_chat:pushMessage', function(message)
    pushMessage(message)
end)

RegisterNetEvent('esx_chat:pushProximity', function(serverId, message)
    local target = GetPlayerFromServerId(serverId)
    if target == -1 then
        return
    end

    local localPlayer = PlayerId()
    if target == localPlayer then
        pushMessage(message)
        return
    end

    local localPed = PlayerPedId()
    local targetPed = GetPlayerPed(target)

    if targetPed == 0 then
        return
    end

    local distance = #(GetEntityCoords(localPed) - GetEntityCoords(targetPed))
    if distance <= Config.ProximityDistance then
        pushMessage(message)
    end
end)

-- Compatibility with the standard FiveM chat events.
RegisterNetEvent('chat:addMessage', function(message)
    local normalized = normalizeLegacyMessage(message)
    if normalized then
        pushMessage(normalized)
    end
end)

RegisterNetEvent('chatMessage', function(author, color, text)
    pushMessage({
        type = inferType(author),
        title = tostring(author or ''),
        text = tostring(text or ''),
        color = color
    })
end)

RegisterNetEvent('chat:addTemplate', function(id, html)
    if type(id) == 'string' and type(html) == 'string' then
        templates[id] = html
    end
end)

RegisterNetEvent('chat:addSuggestion', function(name, help, params)
    if type(name) ~= 'string' then
        return
    end

    suggestions[name] = {
        name = name,
        description = help or '',
        params = params or {}
    }

    SendNUIMessage({
        action = 'suggestion:add',
        suggestion = suggestions[name]
    })
end)

RegisterNetEvent('chat:addSuggestions', function(items)
    if type(items) ~= 'table' then
        return
    end

    for _, item in ipairs(items) do
        if type(item) == 'table' and type(item.name) == 'string' then
            suggestions[item.name] = item
            SendNUIMessage({
                action = 'suggestion:add',
                suggestion = item
            })
        end
    end
end)

RegisterNetEvent('chat:removeSuggestion', function(name)
    suggestions[name] = nil
    SendNUIMessage({ action = 'suggestion:remove', name = name })
end)

RegisterNetEvent('chat:clear', function()
    SendNUIMessage({ action = 'clear' })
end)

RegisterCommand('+esxchat', function()
    if chatOpen or IsPauseMenuActive() then
        return
    end

    setFocus(true)
end, false)

RegisterCommand('-esxchat', function()
end, false)

RegisterKeyMapping('+esxchat', 'Open ESX chat', 'keyboard', Config.OpenKey)

RegisterCommand('clear', function()
    SendNUIMessage({ action = 'clear' })
    pushMessage({
        type = 'system',
        title = 'SYSTEM',
        text = 'The chat has been cleared.',
        icon = 'system'
    })
end, false)

RegisterNUICallback('close', function(_, cb)
    setFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('submit', function(data, cb)
    local text = type(data) == 'table' and tostring(data.text or '') or ''
    local mode = type(data) == 'table' and tostring(data.mode or 'ooc') or 'ooc'

    text = text:gsub('[\r\n]', ' '):gsub('^%s*(.-)%s*$', '%1')

    if text ~= '' then
        if text:sub(1, 1) == '/' then
            ExecuteCommand(text:sub(2))
        elseif mode == 'rp' then
            ExecuteCommand(('me %s'):format(text))
        elseif mode == 'ooc' then
            ExecuteCommand(('ooc %s'):format(text))
        elseif mode == 'job' then
            ExecuteCommand(('job %s'):format(text))
        elseif mode == 'pm' then
            ExecuteCommand(('pm %s'):format(text))
        else
            ExecuteCommand(('ooc %s'):format(text))
        end
    end

    setFocus(false)
    cb({ ok = true })
end)

local function sendInit()
    SendNUIMessage({
        action = 'init',
        config = {
            maxVisibleMessages = Config.MaxVisibleMessages,
            keepMessages = Config.KeepMessages,
            autoHideAfter = Config.AutoHideAfter,
            showCommandPanelOnOpen = Config.ShowCommandPanelOnOpen,
            maxMessageLength = Config.MaxMessageLength,
            commands = Config.Commands,
            rpCommands = Config.RPCommands
        }
    })
end

RegisterNUICallback('ready', function(_, cb)
    sendInit()
    cb({ ok = true })
end)

CreateThread(function()
    Wait(250)
    sendInit()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and chatOpen then
        SetNuiFocus(false, false)
    end
end)

exports('addMessage', function(message)
    pushMessage(message)
end)

exports('addSuggestion', function(name, help, params)
    TriggerEvent('chat:addSuggestion', name, help, params)
end)
