-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local sequence = 0
local pending

local function finish(success, silent, releaseFocus)
    local request = pending

    if not request then
        return
    end

    pending = nil

    xLib.nui.send({ action = 'closeClipboard', requestId = request.id })

    if AdminOpen and not releaseFocus then
        xLib.nui.focus(true, AdminMode ~= 'menu', AdminMode == 'menu')
    else
        xLib.nui.focus(false, false, false)
    end

    if not silent then
        ESX.ShowNotification(
            Translate(success and 'copied_to_clipboard' or 'clipboard_failed'),
            success and 'success' or 'error'
        )
    end
end

RegisterNetEvent('esx-adminmenu:client:copyToClipboard', function(text)
    if source ~= 65535 or type(text) ~= 'string' or #text == 0 or #text > 4096 then
        return
    end

    -- Keep a usable local copy even if the CEF clipboard is unavailable.
    print('[esx_adminmenu] ' .. text)

    if pending or (IsNuiFocused() and not AdminOpen) then
        ESX.ShowNotification(Translate('clipboard_busy'), 'error')
        return
    end

    sequence = sequence + 1

    local request = { id = sequence }

    pending = request

    xLib.nui.focus(true, true, false)

    SetTimeout(100, function()
        if pending == request then
            xLib.nui.send({
                action = 'showClipboard',
                data = text,
                requestId = request.id,
            })
        end
    end)

    SetTimeout(60000, function()
        if pending == request then
            finish(false)
        end
    end)
end)

xLib.nui.register('clipboardResult', function(data)
    if pending and data.requestId == pending.id then
        finish(data.success == true, data.cancelled == true)
    end

    return { success = true }
end)

AddEventHandler('esx:onPlayerLogout', function()
    finish(false, true, true)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        finish(false, true, true)
    end
end)
