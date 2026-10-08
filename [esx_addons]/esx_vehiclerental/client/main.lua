-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local currentBranch
local menuOpen = false
local pending = false
local activeLease
local zones, blips = {}, {}

local function notify(response)
    ESX.ShowNotification(
        type(response) == 'table' and response.message or TranslateCap('unavailable')
    )
end

local function closeMenu()
    menuOpen = false
    currentBranch = nil
    xLib.nui.close({ action = 'rental:close' })
end

local function uiLocales()
    local labels = {}

    for _, name in ipairs({
        'rental_title',
        'contract_section',
        'search',
        'all',
        'compact',
        'sedan',
        'sport',
        'suv',
        'motorcycle',
        'duration',
        'minutes',
        'payment',
        'cash',
        'bank',
        'total',
        'rent',
        'pending',
        'terms',
        'seats',
        'choose',
        'empty',
        'active',
        'remaining',
        'collect',
        'in_use',
        'return_hint',
        'close',
        'expired',
    }) do
        labels[name] = TranslateCap('ui_' .. name)
    end

    return labels
end

local function syncStatus()
    local ok, response = pcall(xLib.callback.await, 'esx_vehiclerental:status', false)

    if ok and response and response.ok then
        activeLease = response.lease
        xLib.nui.send({
            action = 'rental:contract',
            lease = activeLease,
            labels = uiLocales(),
            theme = xLib.colors.getESXTheme(),
        })
    end
end

local function openMenu(branchId)
    if pending or menuOpen or IsPedInAnyVehicle(PlayerPedId(), false) then
        return
    end

    pending = true
    local ok, response = pcall(xLib.callback.await, 'esx_vehiclerental:catalog', false, branchId)
    pending = false

    if not ok or not response or not response.ok then
        notify(response)
        return
    end

    local branch = Config.Branches[branchId]

    if
        not branch
        or #(GetEntityCoords(PlayerPedId()) - branch.coords) > Config.InteractDistance
    then
        return
    end

    currentBranch = branchId
    activeLease = response.lease
    menuOpen = true
    response.labels = uiLocales()
    xLib.nui.open({ action = 'rental:open', data = response }, true, true, false)
end

local function receiveVehicle(response)
    closeMenu()
    activeLease = response.lease
    local deadline = GetGameTimer() + 10000
    local vehicle = 0

    while GetGameTimer() < deadline do
        if NetworkDoesEntityExistWithNetworkId(response.netId) then
            vehicle = NetToVeh(response.netId)

            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                break
            end
        end

        Wait(50)
    end

    if
        vehicle == 0
        or not DoesEntityExist(vehicle)
        or GetEntityModel(vehicle) ~= joaat(response.model)
        or not activeLease
        or activeLease.plate ~= response.plate
    then
        ESX.ShowNotification(TranslateCap('rental_delivery_failed'))
        return
    end

    SetVehicleNumberPlateText(vehicle, response.plate)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleFuelLevel(vehicle, 100.0)
    SetVehicleOnGroundProperly(vehicle)
    SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
    ESX.ShowNotification(TranslateCap('rental_success'))
end

local function perform(event, request)
    if pending then
        return { ok = false, message = TranslateCap('busy') }
    end

    pending = true
    local ok, response = pcall(xLib.callback.await, event, false, request)
    pending = false

    if not ok or type(response) ~= 'table' then
        response = { ok = false, message = TranslateCap('unavailable') }
    end

    return response
end

xLib.nui.register('rental:close', function()
    if not pending then
        closeMenu()
    end

    return { ok = true }
end)

xLib.nui.register('rental:ready', function()
    return {
        ok = true,
        lease = activeLease,
        labels = uiLocales(),
        theme = xLib.colors.getESXTheme(),
    }
end)

xLib.nui.register('rental:rent', function(data)
    if not menuOpen or not currentBranch then
        return { ok = false, message = TranslateCap('too_far') }
    end

    local response = perform('esx_vehiclerental:rent', {
        branch = currentBranch,
        vehicle = data.vehicle,
        plan = data.plan,
        account = data.account,
    })

    if response.ok then
        CreateThread(function()
            receiveVehicle(response)
        end)
    end

    return response
end)

xLib.nui.register('rental:collect', function()
    if not menuOpen or not currentBranch then
        return { ok = false, message = TranslateCap('too_far') }
    end

    local response = perform('esx_vehiclerental:collect', currentBranch)

    if response.ok then
        CreateThread(function()
            receiveVehicle(response)
        end)
    end

    return response
end)

RegisterNetEvent('esx_vehiclerental:contract', function(lease)
    activeLease = lease
    xLib.nui.send({
        action = 'rental:contract',
        lease = lease,
        labels = uiLocales(),
        theme = xLib.colors.getESXTheme(),
    })
end)

RegisterNetEvent('esx_vehiclerental:ended', function(reason)
    activeLease = nil
    xLib.nui.send({ action = 'rental:contract', labels = uiLocales() })
    closeMenu()
    ESX.ShowNotification(
        TranslateCap(reason == 'returned' and 'rental_returned' or 'rental_expired')
    )
end)

RegisterNetEvent('esx:playerLoaded', function()
    CreateThread(syncStatus)
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    activeLease = nil
    closeMenu()
    xLib.nui.send({ action = 'rental:contract' })
end)

CreateThread(function()
    for branchId, branch in pairs(Config.Branches) do
        local blip = xLib.blips.create({
            coords = branch.coords,
            sprite = branch.blip.sprite,
            color = branch.blip.color,
            scale = branch.blip.scale,
            shortRange = true,
            label = TranslateCap('rental_title') .. ' · ' .. branch.label,
        })
        blips[#blips + 1] = blip

        zones[#zones + 1] = xLib.markerZone.create({
            coords = branch.coords,
            drawDistance = 20.0,
            interactDistance = Config.InteractDistance,
            marker = {
                type = 2,
                size = { x = 0.35, y = 0.35, z = 0.35 },
                color = { r = 251, g = 155, b = 4, a = 180 },
            },
            canInteract = function()
                return ESX.PlayerLoaded and not IsPedInAnyVehicle(PlayerPedId(), false)
            end,
            onInside = function()
                ESX.ShowHelpNotification(TranslateCap('rental_interact'))

                if not pending and not menuOpen and IsControlJustReleased(0, 38) then
                    CreateThread(function()
                        openMenu(branchId)
                    end)
                end
            end,
            onExit = function()
                if currentBranch == branchId and not pending then
                    closeMenu()
                end
            end,
        })

        zones[#zones + 1] = xLib.markerZone.create({
            coords = branch.returnCoords,
            drawDistance = 20.0,
            interactDistance = Config.ReturnDistance,
            marker = {
                type = 1,
                size = { x = 3.0, y = 3.0, z = 0.2 },
                color = { r = 251, g = 155, b = 4, a = 75 },
            },
            canDraw = function()
                return activeLease and activeLease.branch == branchId
            end,
            canInteract = function()
                return activeLease
                    and activeLease.branch == branchId
                    and IsPedInAnyVehicle(PlayerPedId(), false)
            end,
            onInside = function()
                ESX.ShowHelpNotification(TranslateCap('rental_return_interact'))

                if not pending and IsControlJustReleased(0, 38) then
                    CreateThread(function()
                        local response = perform('esx_vehiclerental:return', branchId)

                        if not response.ok then
                            notify(response)
                        end
                    end)
                end
            end,
        })
    end

    if ESX.PlayerLoaded then
        syncStatus()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    closeMenu()

    for _, zone in ipairs(zones) do
        zone.remove()
    end
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
end)
