-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Config = Config.TimedRentals

VehicleShopTimedRentals = {
    ready = false,
    stopping = false,
    leases = {},
    locks = {},
    operations = {},
    limiter = xLib.rateLimiter({ capacity = 2, refill = 1, interval = 3000 }),
    readLimiter = xLib.rateLimiter({ capacity = 5, refill = 2, interval = 1000 }),
}

local Rental = VehicleShopTimedRentals

Rental.translate = Config.translate

function Rental.current(playerId, player)
    return not Rental.stopping
        and player
        and player.source == playerId
        and player.isCurrent
        and player.isCurrent() == true
        and GetPlayerName(playerId) ~= nil
end

function Rental.error(code)
    return { ok = false, code = code, message = Rental.translate(code) }
end

function Rental.key(value)
    return type(value) == 'string' and #value <= 64 and value:match('^[%w_]+$') and value or nil
end

function Rental.near(playerId, branch, returning)
    return branch
        and GetPlayerRoutingBucket(playerId) == branch.bucket
        and xLib.player.isNearCoords(
            playerId,
            returning and branch.returnCoords or branch.coords,
            returning and Config.ReturnDistance or Config.InteractDistance
        )
end

function Rental.cost(vehicle, plan)
    local price = math.ceil(vehicle.rate * plan.minutes * plan.multiplier)

    assert(price > 0 and price <= 1000000000 and price % 1 == 0, 'Invalid rental price')
    return price
end

function Rental.liveEntity(lease)
    if not lease or GetResourceState('esx_garage') ~= 'started' then
        return nil
    end

    return exports['esx_garage']:getRentalVehicle(lease.identifier, lease.plate)
end

function Rental.removeEntity(lease)
    if GetResourceState('esx_garage') == 'started' then
        assert(
            exports['esx_garage']:releaseRentalVehicle(lease.identifier, lease.plate),
            'Unable to remove rental vehicle'
        )
    end

    lease.entity = nil
    lease.netId = nil
end

function Rental.publicLease(lease)
    if not lease then
        return nil
    end

    local vehicle = Config.Vehicles[lease.model]
    local branch = Config.Branches[lease.branch]

    return {
        model = lease.model,
        label = vehicle and vehicle.label or lease.model,
        plate = lease.plate,
        branch = lease.branch,
        branchLabel = branch and branch.label or lease.branch,
        remaining = math.max(0, lease.expires - os.time()),
        inUse = Rental.liveEntity(lease) ~= nil,
    }
end

function Rental.notify(lease, key)
    if Rental.current(lease.source, lease.player) then
        TriggerClientEvent('esx:showNotification', lease.source, Rental.translate(key))
    end
end
