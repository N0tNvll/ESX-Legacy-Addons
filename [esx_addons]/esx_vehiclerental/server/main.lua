-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local function validateConfiguration()
    for _, account in ipairs(Config.PaymentAccounts) do
        assert(account == 'money' or account == 'bank', 'Rental accounts must be money or bank')
    end

    for _, plan in pairs(Config.Plans) do
        assert(
            type(plan.minutes) == 'number'
                and plan.minutes % 1 == 0
                and plan.minutes >= 1
                and plan.minutes <= 10080,
            'Invalid rental duration'
        )
        assert(
            type(plan.multiplier) == 'number' and plan.multiplier > 0 and plan.multiplier <= 10,
            'Invalid rental multiplier'
        )
    end

    for model, vehicle in pairs(Config.Vehicles) do
        assert(Rental.key(model), 'Invalid rental model')
        assert(
            vehicle.type == 'automobile' or vehicle.type == 'bike',
            'Rental vehicle type must be automobile or bike'
        )
        assert(
            type(vehicle.rate) == 'number' and vehicle.rate > 0 and vehicle.rate <= 1000000,
            'Invalid rental rate'
        )
    end

    for branchId, branch in pairs(Config.Branches) do
        assert(Rental.key(branchId) and #branch.spawns > 0, 'Invalid rental branch')
        assert(
            type(branch.bucket) == 'number' and branch.bucket >= 0 and branch.bucket % 1 == 0,
            'Invalid rental routing bucket'
        )

        for _, model in ipairs(branch.vehicles) do
            assert(Config.Vehicles[model], 'Unknown model in rental branch')
        end
    end

    assert(
        Config.InteractDistance > 0 and Config.InteractDistance <= 10,
        'Invalid rental interaction distance'
    )
    assert(
        Config.ReturnDistance > 0 and Config.ReturnDistance <= 15,
        'Invalid rental return distance'
    )
    assert(
        Config.SpawnTimeout > 0 and Config.SpawnTimeout <= 15000,
        'Invalid vehicle spawn timeout'
    )
end

local function syncPlayer(playerId)
    if not Rental.ready then
        return
    end

    local player = ESX.GetPlayerFromId(playerId)
    local lease = player and Rental.leases[player.identifier]

    if lease and Rental.current(playerId, player) then
        lease.source = playerId
        lease.player = player
        TriggerClientEvent('esx_vehiclerental:contract', playerId, Rental.publicLease(lease))
    end
end

xLib.callback.register('esx_vehiclerental:catalog', Rental.catalog)
xLib.callback.register('esx_vehiclerental:rent', Rental.rent)
xLib.callback.register('esx_vehiclerental:collect', Rental.collect)
xLib.callback.register('esx_vehiclerental:return', Rental.returnVehicle)

xLib.callback.register('esx_vehiclerental:status', function(playerId)
    if not Rental.ready or not Rental.readLimiter:consume(playerId) then
        return Rental.error('unavailable')
    end

    local player = ESX.GetPlayerFromId(playerId)

    if not Rental.current(playerId, player) then
        return Rental.error('unavailable')
    end

    local lease = Rental.leases[player.identifier]

    if lease then
        lease.source = playerId
        lease.player = player
    end

    return { ok = true, lease = Rental.publicLease(lease) }
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    syncPlayer(playerId)
end)

AddEventHandler('esx:playerDropped', function(playerId)
    Rental.limiter:reset(playerId)
    Rental.readLimiter:reset(playerId)

    for _, lease in pairs(Rental.leases) do
        if lease.source == playerId then
            local entity = Rental.liveEntity(lease)

            if entity then
                DeleteEntity(entity)
            end

            lease.entity = nil
            lease.netId = nil
            lease.source = nil
            lease.player = nil
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    Rental.stopping = true

    for _, ctx in pairs(Rental.operations) do
        local ok, err = pcall(Rental.cleanupOperation, ctx)

        if not ok then
            print(('[esx_vehiclerental] Shutdown cleanup failed: %s'):format(tostring(err)))
        end
    end

    for _, lease in pairs(Rental.leases) do
        local entity = Rental.liveEntity(lease)

        if entity then
            DeleteEntity(entity)
        end
    end
end)

CreateThread(function()
    MySQL.ready.await()
    local ok, err = pcall(function()
        validateConfiguration()
        Rental.DB.initialize()
    end)

    if not ok then
        print(('[esx_vehiclerental] Initialization blocked: %s'):format(tostring(err)))
        return
    end

    Rental.ready = true

    for _, player in ipairs(ESX.GetExtendedPlayers()) do
        syncPlayer(player.source)
    end

    print('[esx_vehiclerental] Rental contracts ready.')
end)

CreateThread(function()
    while true do
        Wait(1000)

        if Rental.ready and not Rental.stopping then
            for identifier, lease in pairs(Rental.leases) do
                local remaining = lease.expires - os.time()

                if
                    remaining <= Config.ExpiryWarningSeconds
                    and remaining > 0
                    and not lease.warned
                then
                    lease.warned = true
                    Rental.notify(lease, 'rental_warning')
                end

                if
                    remaining <= 0
                    and not Rental.locks[identifier]
                    and (not lease.retryAt or os.time() >= lease.retryAt)
                then
                    Rental.locks[identifier] = true

                    CreateThread(function()
                        local ok, err = pcall(Rental.close, lease, 'expired')
                        Rental.locks[identifier] = nil

                        if not ok then
                            print(
                                ('[esx_vehiclerental] Expiry cleanup failed: %s'):format(
                                    tostring(err)
                                )
                            )
                            lease.retryAt = os.time() + 30
                        end
                    end)
                end
            end
        end
    end
end)
