-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
VehicleShopClient = { shops = {}, generation = 0, open = false, pending = nil }

local S = VehicleShopClient

function S.request(name, ...)
    local ok, response = pcall(xLib.callback.await, 'esx_vehicleshop:' .. name, false, ...)

    if not ok then
        return nil, 'unconfirmed'
    end

    if type(response) ~= 'table' or not response.success then
        return nil, type(response) == 'table' and response.error or 'operation_failed'
    end

    return response.data
end

function S.send(kind, data)
    SendNUIMessage({ type = kind, data = data })
end

function S.close()
    S.generation = S.generation + 1
    S.open, S.shop = false, nil

    if S.clearPreview then
        S.clearPreview()
    end

    SetNuiFocus(false, false)
    S.send('close', {})
end

function S.openShop(id, offerId, action, plate)
    if S.closeTimedRental then
        S.closeTimedRental()
    end

    S.close()

    local generation = S.generation
    local data, err = S.request('getDealership', id)

    if generation ~= S.generation then
        return false
    end

    if not data then
        ESX.ShowNotification(
            err == 'not_ready' and 'El concesionario se está preparando.'
                or 'No puedes acceder a este concesionario.',
            'error'
        )
        return false
    end

    S.shop, S.open = data.shop, true
    SetNuiFocus(true, true)
    S.send('open', { snapshot = data, locale = Config.Locale, pending = S.pending })

    if offerId then
        local quote, problem = S.request('getOffer', offerId)

        if generation == S.generation then
            S.send('quote', quote or { error = problem })
        end
    elseif action then
        local quote, problem = S.request('quote', { shopId = id, kind = action, plate = plate })

        if generation == S.generation then
            S.send('quote', quote or { error = problem })
        end
    end

    return true
end

exports('openDealership', S.openShop)
RegisterNetEvent('esx_vehicleshop:offer', function(id, offer)
    S.openShop(id, offer.id)
end)

local function nui(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local ok, result, failure = pcall(handler, data or {})

        cb({
            success = ok and result ~= nil,
            data = ok and result or nil,
            error = ok and failure or 'operation_failed',
        })
    end)
end

nui('close', function()
    S.close()
    return true
end)

nui('preview', function(data)
    if not S.open or not S.shop then
        return nil, 'not_near_shop'
    end

    return S.preview(data.model)
end)

nui('refresh', function(data)
    if not S.open or not S.shop then
        return nil, 'not_near_shop'
    end

    return S.request('getDealership', S.shop.id, data.page)
end)

nui('quote', function(data)
    if not S.open or not S.shop then
        return nil, 'not_near_shop'
    end

    data.shopId = S.shop.id
    return S.request('quote', data)
end)

nui('execute', function(data)
    if not S.open or not S.shop then
        return nil, 'not_near_shop'
    end

    S.pending = data.id

    local result, failure = S.request('executeOrder', data.id, data.account)

    if result and result.complete and S.pending == data.id then
        S.pending = nil
    end

    return result, failure
end)

nui('status', function(data)
    local id = data.id or S.pending
    local result, failure = S.request('orderStatus', id)

    if
        result
        and (
            result.complete
            or result.state == 'failed'
            or result.expired
            or result.state == 'quoted'
        )
        and S.pending == id
    then
        S.pending = nil
    end

    return result, failure
end)

nui('inventory', function()
    if not S.open or not S.shop then
        return nil, 'not_near_shop'
    end

    local result, err = S.request('getInventory', S.shop.id)

    if result and result.ox then
        S.close()
        exports.ox_inventory:openInventory('stash', result.stash)
    end

    return result, err
end)

nui('moveInventory', function(data)
    if not S.open or not S.shop then
        return nil, 'not_near_shop'
    end

    return S.request(
        'moveInventory',
        S.shop.id,
        data.item,
        tonumber(data.count),
        data.deposit == true
    )
end)

nui('employees', function()
    if not S.open or not S.shop or not S.shop.boss then
        return nil, 'not_allowed'
    end

    local job = S.shop.societyJob

    S.close()
    TriggerEvent('esx_society:openBossMenu', job, function(_, menu)
        menu.close()
    end, { withdraw = false, deposit = false, wash = false })
    return true
end)

nui('invoice', function(data)
    if not S.open or not S.shop or not S.shop.employee or not S.shop.billingAccount then
        return nil, 'not_allowed'
    end

    local target, distance = xLib.game.getClosestPlayer()
    local amount = tonumber(data.amount)

    if target == -1 or distance > 3 or not amount or amount < 1 or amount % 1 ~= 0 then
        return nil, 'buyer_unavailable'
    end

    TriggerServerEvent(
        'esx_billing:sendBill',
        GetPlayerServerId(target),
        S.shop.billingAccount,
        S.shop.name,
        amount
    )
    return true
end)

RegisterNetEvent('esx_vehicleshop:delivery', function(networkId)
    S.close()

    local generation = S.generation
    local deadline = GetGameTimer() + 5000

    while not NetworkDoesEntityExistWithNetworkId(networkId) and GetGameTimer() < deadline do
        Wait(50)
    end

    if generation ~= S.generation or not ESX.IsPlayerLoaded() then
        return
    end

    local vehicle = NetworkDoesEntityExistWithNetworkId(networkId) and NetToVeh(networkId)

    if vehicle and vehicle ~= 0 then
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    end
end)

CreateThread(function()
    while true do
        if S.open then
            DisableAllControlActions(0)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        S.close()
    end
end)
