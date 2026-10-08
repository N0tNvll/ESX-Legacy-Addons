-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local DISPLAY_MODES = { always = true, onMessage = true, hidden = true }
local DISPLAY_ORDER = { 'always', 'onMessage', 'hidden' }
local DISPLAY_KVP = 'esx_chat:displayMode'

local chatOpen = false
local nuiReady = false
local suggestions = {}
local templates = {}

local function getDisplayMode()
    local stored = GetResourceKvpString(DISPLAY_KVP)

    if stored and DISPLAY_MODES[stored] then
        return stored
    end

    return DISPLAY_MODES[Config.DefaultDisplayMode] and Config.DefaultDisplayMode or 'onMessage'
end

local displayMode = getDisplayMode()

local function getClockTime()
    if Config.UseGameClock then
        return ('%02d:%02d'):format(GetClockHours(), GetClockMinutes())
    end

    return nil
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

local function normalizeLegacyMessage(message)
    if type(message) == 'string' then
        return {
            type = 'system',
            title = TranslateCap('title_system'),
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
            rendered = rendered:gsub('{' .. (index - 1) .. '}', function()
                return tostring(value)
            end)
        end
        text = rendered:gsub('<.->', '')
        title = title ~= '' and title or TranslateCap('title_system')
    end

    return {
        type = message.esxType or message.type or inferType(title),
        title = title,
        text = text,
        color = message.color,
        multiline = message.multiline,
        icon = message.icon
    }
end

local function pushMessage(message)
    if type(message) == 'table' and (message.args or message.template) then
        message = normalizeLegacyMessage(message) or message
    end

    if type(message) ~= 'table' then
        message = normalizeLegacyMessage(tostring(message))
    end

    if not message.time then
        message.time = getClockTime()
    end

    SendNUIMessage({
        action = 'message',
        message = message
    })
end

local function setFocus(value)
    chatOpen = value
    SetNuiFocus(value, value)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = value and 'open' or 'close'
    })
end

local function setDisplayMode(mode, notify)
    if not DISPLAY_MODES[mode] then
        return false
    end

    displayMode = mode
    SetResourceKvp(DISPLAY_KVP, mode)
    SendNUIMessage({ action = 'displayMode', mode = mode })

    if notify then
        pushMessage({
            type = 'system',
            title = TranslateCap('title_system'),
            text = _U('display_mode_set', _(('ui_display_%s'):format(mode))),
            icon = 'system'
        })
    end

    return true
end

local function nextDisplayMode()
    for index, mode in ipairs(DISPLAY_ORDER) do
        if mode == displayMode then
            return DISPLAY_ORDER[index % #DISPLAY_ORDER + 1]
        end
    end

    return DISPLAY_ORDER[1]
end

local function getRPCommands()
    local commands = {}

    for _, command in ipairs(Config.Commands) do
        if command.enabled ~= false and command.rp then
            commands[#commands + 1] = {
                name = ('/%s'):format(command.name),
                description = command.description or _(('command_%s'):format(command.name))
            }
        end
    end

    return commands
end

local LOCALE_KEYS = {
    'ui_tab_ooc', 'ui_tab_rp', 'ui_tab_job', 'ui_tab_pm',
    'ui_placeholder_ooc', 'ui_placeholder_rp', 'ui_placeholder_job', 'ui_placeholder_pm',
    'ui_rp_commands', 'ui_suggestions', 'ui_emojis', 'ui_emoji_hint', 'ui_send',
    'ui_display_always', 'ui_display_onMessage', 'ui_display_hidden'
}

local function getUILocale()
    local strings = {}

    for _, key in ipairs(LOCALE_KEYS) do
        strings[key] = _(key)
    end

    return strings
end

local function sendInit()
    SendNUIMessage({
        action = 'init',
        config = {
            maxVisibleMessages = Config.MaxVisibleMessages,
            keepMessages = Config.KeepMessages,
            autoHideAfter = Config.AutoHideAfter,
            maxMessageLength = Config.MaxMessageLength,
            displayMode = displayMode,
            rpCommands = getRPCommands(),
            locale = getUILocale(),
            theme = xLib.colors.getESXTheme()
        }
    })

    for _, suggestion in pairs(suggestions) do
        SendNUIMessage({ action = 'suggestion:add', suggestion = suggestion })
    end
end

local function addSuggestion(name, help, params)
    if type(name) ~= 'string' then
        return
    end

    suggestions[name] = {
        name = name,
        description = help or '',
        params = params or {}
    }

    if nuiReady then
        SendNUIMessage({
            action = 'suggestion:add',
            suggestion = suggestions[name]
        })
    end
end

RegisterNetEvent('esx_chat:pushMessage', function(message)
    pushMessage(message)
end)

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

RegisterNetEvent('chat:addSuggestion', addSuggestion)

RegisterNetEvent('chat:addSuggestions', function(items)
    if type(items) ~= 'table' then
        return
    end

    for _, item in ipairs(items) do
        if type(item) == 'table' then
            addSuggestion(item.name, item.help or item.description, item.params)
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

RegisterKeyMapping('+esxchat', _('key_open'), 'keyboard', Config.OpenKey)

RegisterCommand('clear', function()
    SendNUIMessage({ action = 'clear' })
    pushMessage({
        type = 'system',
        title = TranslateCap('title_system'),
        text = _U('chat_cleared'),
        icon = 'system'
    })
end, false)

RegisterCommand('chatmode', function(_, args)
    local mode = args[1]

    if not mode then
        return setDisplayMode(nextDisplayMode(), true)
    end

    for value in pairs(DISPLAY_MODES) do
        if value:lower() == mode:lower() then
            return setDisplayMode(value, true)
        end
    end

    pushMessage({
        type = 'system',
        title = TranslateCap('title_system'),
        text = _U('display_mode_usage'),
        icon = 'system'
    })
end, false)

RegisterNUICallback('close', function(_, cb)
    setFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('cycleDisplayMode', function(_, cb)
    setDisplayMode(nextDisplayMode(), false)
    cb({ ok = true, mode = displayMode })
end)

RegisterNUICallback('submit', function(data, cb)
    local text = type(data) == 'table' and tostring(data.text or '') or ''
    local mode = type(data) == 'table' and tostring(data.mode or 'ooc') or 'ooc'

    text = text:gsub('[\r\n]', ' '):match('^%s*(.*%S)') or ''

    if text ~= '' then
        if text:sub(1, 1) == '/' then
            ExecuteCommand(text:sub(2))
        elseif mode == 'rp' then
            ExecuteCommand(('me %s'):format(text))
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

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    sendInit()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and chatOpen then
        SetNuiFocus(false, false)
    end
end)

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/chatmode', _('command_chatmode'), { { name = 'mode', help = 'always | onMessage | hidden' } })
    TriggerEvent('chat:addSuggestion', '/clear', _('command_clear'), {})
end)

exports('addMessage', function(message)
    pushMessage(message)
end)

exports('addSuggestion', function(name, help, params)
    addSuggestion(name, help, params)
end)
