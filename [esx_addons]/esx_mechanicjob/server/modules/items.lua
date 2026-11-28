-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESX.RegisterUsableItem('blowpipe', function(source)
    local source = source
    local xPlayer = ESX.Player(source)

    if not xPlayer then
        return
    end

    xPlayer.removeInventoryItem('blowpipe', 1)

    TriggerClientEvent('esx_mechanicjob:onHijack', source)
    TriggerClientEvent('esx:showNotification', source, TranslateCap('you_used_blowtorch'))
end)

local function useRepairKit(source, itemName)
    local xPlayer = ESX.Player(source)

    if not xPlayer then
        return
    end

    local item = xPlayer.getInventoryItem(itemName)

    if not item or (item.count or 0) < 1 then
        return
    end

    if xPlayer.removeInventoryItem(itemName, 1) ~= true then
        return
    end

    TriggerClientEvent('esx_mechanicjob:onFixkit', source)
    TriggerClientEvent('esx:showNotification', source, TranslateCap('you_used_repair_kit'))
end

ESX.RegisterUsableItem('fixkit', function(source)
    useRepairKit(source, 'fixkit')
end)

ESX.RegisterUsableItem('repairkit', function(source)
    useRepairKit(source, 'repairkit')
end)

ESX.RegisterUsableItem('carokit', function(source)
    local source = source
    local xPlayer = ESX.Player(source)

    if not xPlayer then
        return
    end

    xPlayer.removeInventoryItem('carokit', 1)

    TriggerClientEvent('esx_mechanicjob:onCarokit', source)
    TriggerClientEvent('esx:showNotification', source, TranslateCap('you_used_body_kit'))
end)
