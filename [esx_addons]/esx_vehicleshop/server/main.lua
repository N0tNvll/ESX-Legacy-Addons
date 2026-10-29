-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
local D = VehicleShop
local registeredSocieties = {}

function D.registerSocieties()
    local ids = {}

    for id in pairs(D.shops) do
        ids[#ids + 1] = id
    end

    table.sort(ids)

    for _, id in ipairs(ids) do
        local shop = D.shops[id]

        if
            shop.enabled ~= false
            and shop.mode == 'managed'
            and shop.management
            and shop.societyAccount
        then
            if GetResourceState('esx_addonaccount') == 'started' then
                MySQL.insert.await(
                    'INSERT IGNORE INTO addon_account (name, label, shared) VALUES (?, ?, 1)',
                    { shop.societyAccount, shop.label }
                )
            end

            if shop.societyInventory and GetResourceState('esx_addoninventory') == 'started' then
                MySQL.insert.await(
                    'INSERT IGNORE INTO addon_inventory (name, label, shared) VALUES (?, ?, 1)',
                    { shop.societyInventory, shop.label }
                )
            end

            local job = shop.management.job

            if GetResourceState('esx_society') == 'started' and not registeredSocieties[job] then
                local existing = exports['esx_society']:GetSociety(job)

                if not existing then
                    exports['esx_society']:registerSociety(
                        job,
                        shop.label,
                        shop.societyAccount,
                        shop.societyInventory,
                        shop.societyInventory,
                        { type = 'private' }
                    )
                    existing = exports['esx_society']:GetSociety(job)
                end

                if existing and existing.account == shop.societyAccount then
                    shop.billingAccount = shop.societyAccount
                end

                registeredSocieties[job] = true
            end
        end
    end

    TriggerEvent('esx:sqlCatalogReady', { addon_account = true, addon_inventory = true })
end

MySQL.ready(function()
    local ok, err = pcall(function()
        ESXCatalog.awaitReady()
        D.migrate()
        VehicleShopTimedRentals.initialize()
        D.reloadCatalog()
        D.reconcileRentals()
        D.registerSocieties()
    end)

    if not ok then
        print(
            '[esx_vehicleshop] Dealership initialization FAILED; transactions remain closed: '
                .. tostring(err)
        )
        return
    end

    D.ready, VehicleShopDatabaseReady = true, true
    TriggerEvent('esx_vehicleshop:ready')
    TriggerClientEvent('esx_vehicleshop:dealershipsChanged', -1)
    print('[esx_vehicleshop] Multi-dealership catalog, migrations and transaction service ready.')
    CreateThread(function()
        while D.ready do
            local recovered, problem = pcall(D.recoverTradeEntities)

            if not recovered then
                print('[esx_vehicleshop] Returned vehicle cleanup deferred: ' .. tostring(problem))
            end

            Wait(10000)
        end
    end)
end)

AddEventHandler('onResourceStart', function(resource)
    if
        D.ready
        and (
            resource == 'esx_society'
            or resource == 'esx_addonaccount'
            or resource == 'esx_addoninventory'
        )
    then
        D.registerSocieties()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == 'esx_society' then
        registeredSocieties = {}
    end
end)
