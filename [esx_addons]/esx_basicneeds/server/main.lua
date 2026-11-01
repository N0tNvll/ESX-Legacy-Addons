-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

local function handleItemUsage(itemName, itemConfig, source)
    local xPlayer = ESX.Player(source)
    local statusType, notificationMessage
    local animationType = itemConfig.type

    if not xPlayer then
        return
    end

    if itemConfig.type == 'food' then
        statusType = 'hunger'
        notificationMessage = TranslateCap('used_food', ESX.GetItemLabel(itemName))
    elseif itemConfig.type == 'drink' then
        statusType = 'thirst'
        notificationMessage = TranslateCap('used_drink', ESX.GetItemLabel(itemName))
    elseif itemConfig.type == 'alcohol' then
        statusType = 'drunk'
        animationType = 'drink'
        notificationMessage = TranslateCap('used_beer')
    else
        print(string.format('^1[ERROR]^0 Item "%s" has an invalid type defined.', itemName))
        return
    end

    local inventoryItem = xPlayer.getInventoryItem(itemName)

    if not inventoryItem or (inventoryItem.count or 0) < 1 then
        return
    end

    if itemConfig.remove and xPlayer.removeInventoryItem(itemName, 1) == false then
        return
    end

    TriggerEvent('esx_status:add', source, statusType, itemConfig.status)
    TriggerClientEvent('esx_basicneeds:onUse', source, animationType, itemConfig.prop, itemConfig.anim, itemConfig.pos, itemConfig.rot)
    xPlayer.showNotification(notificationMessage)
end

CreateThread(function()
    for itemName, itemConfig in pairs(Config.Items) do
        ESX.RegisterUsableItem(itemName, function(source)
            handleItemUsage(itemName, itemConfig, source)
        end)
    end
end)

ESX.RegisterCommand(
    'heal',
    'admin',
    function(xPlayer, args, showError)
        if not args.playerId then
            return showError('Player ID is required')
        end

        TriggerEvent('esx_status:set', args.playerId.source, 'hunger', 1000000)
        TriggerEvent('esx_status:set', args.playerId.source, 'thirst', 1000000)
        args.playerId.triggerEvent('esx_basicneeds:healPlayer')
        args.playerId.showNotification(TranslateCap('got_healed'))
    end,
    true,
    {
        help = 'Heal a player, or yourself - restores thirst, hunger, and health.',
        validate = true,
        arguments = {
            { name = 'playerId', help = 'The player ID', type = 'player' },
        },
    }
)

AddEventHandler('txAdmin:events:healedPlayer', function(eventData)
    if GetInvokingResource() ~= 'monitor' or type(eventData) ~= 'table' or type(eventData.id) ~= 'number' then
        return
    end

    TriggerEvent('esx_status:set', eventData.id, 'hunger', 1000000)
    TriggerEvent('esx_status:set', eventData.id, 'thirst', 1000000)
    TriggerClientEvent('esx_basicneeds:healPlayer', eventData.id)
end)
