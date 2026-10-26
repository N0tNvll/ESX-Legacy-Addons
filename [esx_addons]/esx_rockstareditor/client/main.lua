-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local resource = GetCurrentResourceName()
local menuOpen = false
local requestId = 0
local pending
local stopping = false
local launching = false
local executing = false
local actions = { start = true, save = true, discard = true, editor = true }

local function stateMessage(action)
    return {
        action = action,
        state = Recorder.State(),
        showIndicator = Config.ShowRecordingIndicator,
    }
end

local function cancelPending()
    requestId = requestId + 1

    if pending then
        local current = pending

        pending = nil
        current.finish({ ok = false, message = Translate('cancelled') })
    end
end

local function closeMenu()
    cancelPending()

    if menuOpen then
        menuOpen = false
        SetNuiFocus(false, false)
    end

    SendNUIMessage({ action = 'close' })
end

local function authorize(action, callback)
    if pending then
        callback({ ok = false, message = Translate('busy') })
        return
    end

    requestId = requestId + 1

    local current = { id = requestId }
    local completed = false

    current.finish = function(result)
        if completed then
            return
        end

        completed = true

        if pending == current then
            pending = nil
        end

        callback(result)
    end

    pending = current

    SetTimeout(Config.AccessTimeout, function()
        if pending == current then
            requestId = requestId + 1
            current.finish({ ok = false, message = Translate('request_failed') })
        end
    end)

    CreateThread(function()
        local ok, result = pcall(xLib.callback.await, 'esx_rockstareditor:authorize', false, action)

        if current.id ~= requestId or stopping or not ESX.PlayerLoaded then
            current.finish({ ok = false, message = Translate('cancelled') })
            return
        end

        if not ok or type(result) ~= 'table' or result.ok ~= true then
            local reason = ok and type(result) == 'table' and result.reason or 'request_failed'
            local known = reason == 'access_denied'
                or reason == 'busy'
                or reason == 'invalid_action'
                or reason == 'replays_disabled'

            current.finish({ ok = false, message = Translate(known and reason or 'request_failed') })
            return
        end

        current.finish({
            ok = true,
            requestId = current.id,
            replaysDisabled = result.replaysDisabled,
        })
    end)
end

local function openMenu()
    if stopping or launching or executing or not ESX.PlayerLoaded then
        return
    end

    if menuOpen then
        closeMenu()
        return
    end

    if pending or IsPauseMenuActive() or IsNuiFocused() then
        return
    end

    authorize('open', function(result)
        if not result.ok then
            if result.message ~= Translate('cancelled') then
                ESX.ShowNotification(result.message, 'error')
            end

            return
        end

        if IsPauseMenuActive() or IsNuiFocused() then
            return
        end

        local message = stateMessage('open')
        local text = {}

        for key in pairs(Locales['en']) do
            if key:sub(1, 3) == 'ui_' then
                text[key] = Translate(key)
            end
        end

        message.locale = text
        message.language = Config.Locale
        message.theme = xLib.colors.getESXTheme()
        message.command = '/' .. Config.Command
        menuOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage(message)
    end)
end

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('action', function(data, cb)
    if not menuOpen or type(data) ~= 'table' or not actions[data.action] then
        cb({ ok = false, message = Translate('invalid_action') })
        return
    end

    if executing then
        cb({ ok = false, message = Translate('busy') })
        return
    end

    local action = data.action

    if (action == 'discard' or action == 'editor') and data.confirmed ~= true then
        cb({ ok = false, message = Translate('confirmation_required') })
        return
    end

    authorize(action, function(result)
        if not result.ok then
            cb(result)
            return
        end

        if not menuOpen or result.requestId ~= requestId then
            cb({ ok = false, message = Translate('cancelled') })
            return
        end

        if action == 'editor' then
            if Recorder.IsRecording() then
                cb({ ok = false, message = Translate('finish_recording') })
                return
            end

            if not Recorder.State().editorAvailable then
                cb({ ok = false, message = Translate('unavailable') })
                return
            end

            launching = true
            cb({ ok = true })
            closeMenu()

            CreateThread(function()
                Wait(150)

                if stopping or not ESX.PlayerLoaded then
                    launching = false
                    return
                end

                if Recorder.IsRecording() then
                    launching = false
                    ESX.ShowNotification(Translate('finish_recording'), 'error')
                    return
                end

                local ok = pcall(ActivateRockstarEditor, 0)

                if IsScreenFadedOut() then
                    DoScreenFadeIn(0)
                end

                launching = false

                if not ok then
                    ESX.ShowNotification(Translate('editor_failed'), 'error')
                end
            end)
            return
        end

        executing = true

        local ok, reason = Recorder.Run(action)

        executing = false
        cb({
            ok = ok,
            message = Translate(reason, '/' .. Config.Command .. 'status'),
            state = Recorder.State(),
        })

        if
            ok
            and action == 'start'
            and Config.CloseOnRecord
            and result.requestId == requestId
            and menuOpen
        then
            closeMenu()
            ESX.ShowNotification(Translate(reason), 'success')
        end
    end)
end)

RegisterCommand(Config.Command, openMenu, false)

RegisterCommand(Config.Command .. 'status', function()
    if stopping or not ESX.PlayerLoaded then
        return
    end

    authorize('status', function(result)
        if not result.ok then
            ESX.ShowNotification(result.message, 'error')
            return
        end

        Recorder.Diagnostics(result.replaysDisabled)
        ESX.ShowNotification(Translate('diagnostics_printed'), 'info')
    end)
end, false)

for _, alias in ipairs(Config.Aliases) do
    RegisterCommand(alias, openMenu, false)
end

RegisterKeyMapping(Config.Command, Translate('keybind_menu'), 'keyboard', Config.Keybind)

CreateThread(function()
    local wasRecording = false

    while not stopping do
        Wait(500)

        if ESX.PlayerLoaded then
            local message = stateMessage('state')

            if
                menuOpen
                or (Config.ShowRecordingIndicator and (message.state.recording or wasRecording))
            then
                SendNUIMessage(message)
            end

            wasRecording = message.state.recording
        end
    end
end)

CreateThread(function()
    while not stopping do
        if
            Config.ShowRecordingIndicator
            and Config.HideGameFeedWhileRecording
            and ESX.PlayerLoaded
            and type(ThefeedHideThisFrame) == 'function'
            and Recorder.IsRecording()
        then
            ThefeedHideThisFrame()
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('esx:onPlayerLogout', function()
    closeMenu()
    Recorder.Cleanup()
    SendNUIMessage({ action = 'reset' })
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= resource then
        return
    end

    stopping = true
    closeMenu()
    Recorder.Cleanup()
    SendNUIMessage({ action = 'reset' })
end)

exports('OpenMenu', openMenu)
exports('CloseMenu', closeMenu)
exports('GetRecordingState', Recorder.State)
