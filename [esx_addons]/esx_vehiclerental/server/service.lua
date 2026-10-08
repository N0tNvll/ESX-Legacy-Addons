-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local function isAllowed(values, selected)
    for _, value in ipairs(values) do
        if value == selected then
            return true
        end
    end

    return false
end

local function validPlayer(playerId, player, branch)
    return Rental.current(playerId, player)
        and Rental.near(playerId, branch)
        and GetEntityHealth(GetPlayerPed(playerId)) > 0
        and GetVehiclePedIsIn(GetPlayerPed(playerId), false) == 0
end

local function hasLicense(player)
    if not Config.RequireDrivingLicense then
        return true
    end

    return MySQL.scalar.await(
        'SELECT 1 FROM user_licenses WHERE owner = ? AND type = ? LIMIT 1',
        { player.identifier, Config.DrivingLicenseType }
    ) ~= nil
end

local function reserveSpawn(branchId, branch)
    for index, coords in ipairs(branch.spawns) do
        local key = ('%s:%d'):format(branchId, index)
        local blocked = Rental.slots[key] ~= nil

        if not blocked then
            for _, entity in ipairs(GetAllVehicles()) do
                if GetEntityRoutingBucket(entity) == branch.bucket then
                    local target = vector3(coords.x, coords.y, coords.z)

                    if #(GetEntityCoords(entity) - target) < Config.SpawnClearRadius then
                        blocked = true
                        break
                    end
                end
            end
        end

        if not blocked then
            Rental.slots[key] = true
            return coords, key
        end
    end
end

local function spawnVehicle(ctx, branch, vehicle, lease)
    local coords, slot = reserveSpawn(lease.branch, branch)

    if not coords then
        return Rental.error('spawn_blocked')
    end

    ctx.slot = slot
    local entity = CreateVehicleServerSetter(
        joaat(lease.model),
        vehicle.type,
        coords.x,
        coords.y,
        coords.z,
        coords.w
    )
    ctx.entity = entity ~= 0 and entity or nil
    local deadline = GetGameTimer() + Config.SpawnTimeout

    while ctx.entity and not DoesEntityExist(ctx.entity) and GetGameTimer() < deadline do
        Wait(50)
    end

    if not ctx.entity or not DoesEntityExist(ctx.entity) then
        return Rental.error('spawn_failed')
    end

    SetEntityRoutingBucket(entity, branch.bucket)
    SetEntityOrphanMode(entity, 2)
    FreezeEntityPosition(entity, true)
    SetVehicleNumberPlateText(entity, lease.plate)
    lease.entity = entity
    lease.netId = NetworkGetNetworkIdFromEntity(entity)

    return nil
end

local function publishVehicle(ctx, lease, playerId, player)
    lease.source = playerId
    lease.player = player
    lease.warned = nil
    Rental.leases[lease.identifier] = lease
    ctx.persisted = true

    FreezeEntityPosition(lease.entity, false)
    Entity(lease.entity).state:set(
        'esxRental',
        { plate = lease.plate, expires = lease.expires },
        true
    )

    TriggerClientEvent('esx_vehiclerental:contract', playerId, Rental.publicLease(lease))
    TriggerEvent(
        'esx_vehiclerental:rented',
        playerId,
        lease.netId,
        lease.plate,
        lease.model,
        lease.expires
    )

    return {
        ok = true,
        netId = lease.netId,
        model = lease.model,
        plate = lease.plate,
        lease = Rental.publicLease(lease),
    }
end

function Rental.cleanupOperation(ctx)
    if ctx.finished then
        return
    end

    ctx.finished = true

    local function cleanup(action, ...)
        local ok, err = pcall(action, ...)

        if not ok then
            print(('[esx_vehiclerental] Compensation cleanup failed: %s'):format(tostring(err)))
        end
    end

    if not ctx.persisted then
        if ctx.entity and DoesEntityExist(ctx.entity) then
            cleanup(DeleteEntity, ctx.entity)
        end

        if ctx.lease then
            -- Dispatch cleanup even on resource stop; pending insertions are discarded on next startup.
            cleanup(
                MySQL.update,
                'DELETE FROM esx_vehicle_rentals WHERE identifier = ? AND plate = ?',
                { ctx.lease.identifier, ctx.lease.plate }
            )
        end

        if ctx.charged and ctx.charged > 0 then
            local ok, refunded =
                pcall(ctx.player.addAccountMoney, ctx.account, ctx.charged, 'Vehicle Rental Refund')

            if not ok or refunded ~= true then
                ctx.refundFailed = true
                print(
                    ('[esx_vehiclerental] REFUND FAILED: %s / %s / %d'):format(
                        ctx.identifier,
                        ctx.account,
                        ctx.charged
                    )
                )
            end
        end
    end

    if ctx.accountOperation then
        cleanup(ctx.player.endAccountOperation)
    end

    if ctx.slot then
        Rental.slots[ctx.slot] = nil
    end

    Rental.operations[ctx.identifier] = nil
    Rental.locks[ctx.identifier] = nil
end

function Rental.execute(playerId, run)
    if not Rental.ready or Rental.stopping then
        return Rental.error('unavailable')
    end

    if not Rental.limiter:consume(playerId) then
        return Rental.error('rate_limited')
    end

    local player = ESX.GetPlayerFromId(playerId)

    if not Rental.current(playerId, player) then
        return Rental.error('unavailable')
    end

    local identifier = player.identifier

    if Rental.locks[identifier] then
        return Rental.error('busy')
    end

    Rental.locks[identifier] = true
    local ctx = { identifier = identifier, player = player }
    Rental.operations[identifier] = ctx

    local ok, result = pcall(run, player, ctx)
    local cleanupOk, cleanupError = pcall(Rental.cleanupOperation, ctx)

    if not ok or not cleanupOk then
        print(
            ('[esx_vehiclerental] Operation failed: %s'):format(
                tostring(not ok and result or cleanupError)
            )
        )
        return Rental.error('internal_error')
    end

    if ctx.refundFailed then
        return Rental.error('refund_failed')
    end

    return result
end

function Rental.catalog(playerId, branchId)
    if not Rental.ready or Rental.stopping then
        return Rental.error('unavailable')
    end

    if not Rental.readLimiter:consume(playerId) then
        return Rental.error('rate_limited')
    end

    local branch = Rental.key(branchId) and Config.Branches[branchId]
    local player = ESX.GetPlayerFromId(playerId)

    if not Rental.current(playerId, player) or not Rental.near(playerId, branch) then
        return Rental.error('too_far')
    end

    local vehicles, plans, balances = {}, {}, {}

    for planId, plan in pairs(Config.Plans) do
        plans[#plans + 1] = { id = planId, minutes = plan.minutes }
    end

    table.sort(plans, function(a, b)
        return a.minutes < b.minutes
    end)

    for _, model in ipairs(branch.vehicles) do
        local vehicle = Config.Vehicles[model]
        local prices = {}

        for planId, plan in pairs(Config.Plans) do
            prices[planId] = Rental.cost(vehicle, plan)
        end

        vehicles[#vehicles + 1] = {
            model = model,
            label = vehicle.label,
            category = vehicle.category,
            seats = vehicle.seats,
            image = vehicle.image,
            prices = prices,
        }
    end

    for _, accountName in ipairs(Config.PaymentAccounts) do
        local account = player.getAccount(accountName)
        balances[accountName] = account and account.money or 0
    end

    return {
        ok = true,
        branch = { id = branchId, label = branch.label },
        vehicles = vehicles,
        plans = plans,
        accounts = Config.PaymentAccounts,
        balances = balances,
        lease = Rental.publicLease(Rental.leases[player.identifier]),
        currency = Config.Currency,
        locale = Config.Locale,
        theme = xLib.colors.getESXTheme(),
    }
end

function Rental.rent(playerId, request)
    return Rental.execute(playerId, function(player, ctx)
        if type(request) ~= 'table' then
            return Rental.error('invalid_request')
        end

        local branch = Rental.key(request.branch) and Config.Branches[request.branch]
        local vehicle = Rental.key(request.vehicle) and Config.Vehicles[request.vehicle]
        local plan = Rental.key(request.plan) and Config.Plans[request.plan]

        if
            not branch
            or not vehicle
            or not plan
            or not isAllowed(branch.vehicles, request.vehicle)
            or not isAllowed(Config.PaymentAccounts, request.account)
        then
            return Rental.error('invalid_request')
        end

        if not validPlayer(playerId, player, branch) then
            return Rental.error('too_far')
        end

        if Rental.leases[player.identifier] then
            return Rental.error('active_rental')
        end

        if not hasLicense(player) then
            return Rental.error('license_required')
        end

        if not validPlayer(playerId, player, branch) or player.beginAccountOperation() ~= true then
            return Rental.error('unavailable')
        end

        ctx.accountOperation = true
        ctx.account = request.account
        local price = Rental.cost(vehicle, plan)
        local account = player.getAccount(ctx.account)

        if not account or account.money < price then
            return Rental.error('insufficient_funds')
        end

        local plate = xLib.vehiclePlate.generateUnique(
            { prefix = 'R', letters = 3, numbers = 4 },
            Rental.DB.plateExists
        )

        if not plate then
            return Rental.error('spawn_failed')
        end

        local lease = {
            identifier = player.identifier,
            branch = request.branch,
            model = request.vehicle,
            plan = request.plan,
            account = ctx.account,
            price = price,
            plate = plate,
            expires = os.time() + plan.minutes * 60,
        }

        ctx.lease = lease
        local failure = spawnVehicle(ctx, branch, vehicle, lease)

        if failure then
            return failure
        end

        if not validPlayer(playerId, player, branch) then
            return Rental.error('too_far')
        end

        Rental.DB.insert(lease)

        if not validPlayer(playerId, player, branch) then
            return Rental.error('unavailable')
        end

        if player.removeAccountMoney(ctx.account, price, 'Vehicle Rental') ~= true then
            return Rental.error('insufficient_funds')
        end

        ctx.charged = price
        local activated, activationError = pcall(Rental.DB.activate, lease)

        if not activated then
            print(
                ('[esx_vehiclerental] Contract activation failed: %s'):format(
                    tostring(activationError)
                )
            )
            return Rental.error('save_failed')
        end

        -- Once activation is committed the paid contract survives disconnects.
        -- Do not issue a refund that would leave a free active contract in SQL.
        ctx.persisted = true
        Rental.leases[lease.identifier] = lease

        if not validPlayer(playerId, player, branch) then
            DeleteEntity(lease.entity)
            lease.entity = nil
            lease.netId = nil
            return Rental.error('unavailable')
        end

        return publishVehicle(ctx, lease, playerId, player)
    end)
end

function Rental.collect(playerId, branchId)
    return Rental.execute(playerId, function(player, ctx)
        local lease = Rental.leases[player.identifier]
        local branch = Rental.key(branchId) and Config.Branches[branchId]

        if not lease then
            return Rental.error('no_rental')
        end

        if lease.branch ~= branchId then
            return Rental.error('wrong_branch')
        end

        if not validPlayer(playerId, player, branch) then
            return Rental.error('too_far')
        end

        if lease.expires <= os.time() then
            return Rental.error('expired_contract')
        end

        if Rental.liveEntity(lease) then
            return Rental.error('vehicle_in_use')
        end

        local vehicle = Config.Vehicles[lease.model]

        if not vehicle or not hasLicense(player) then
            return Rental.error(vehicle and 'license_required' or 'unavailable')
        end

        local failure = spawnVehicle(ctx, branch, vehicle, lease)

        if failure then
            return failure
        end

        if not validPlayer(playerId, player, branch) or lease.expires <= os.time() then
            return Rental.error('unavailable')
        end

        return publishVehicle(ctx, lease, playerId, player)
    end)
end

function Rental.close(lease, reason)
    local entity = Rental.liveEntity(lease)

    -- Expired vehicles must stop being usable even when the database is temporarily unavailable.
    if reason == 'expired' and entity then
        DeleteEntity(entity)
        lease.entity = nil
        lease.netId = nil
        entity = nil
    end

    Rental.DB.delete(lease)

    if entity then
        DeleteEntity(entity)
    end

    Rental.leases[lease.identifier] = nil

    if Rental.current(lease.source, lease.player) then
        TriggerClientEvent('esx_vehiclerental:ended', lease.source, reason)
    end

    TriggerEvent('esx_vehiclerental:ended', lease.identifier, lease.plate, reason)
end

function Rental.returnVehicle(playerId, branchId)
    return Rental.execute(playerId, function(player)
        local lease = Rental.leases[player.identifier]
        local branch = Rental.key(branchId) and Config.Branches[branchId]

        if not lease then
            return Rental.error('no_rental')
        end

        if lease.branch ~= branchId then
            return Rental.error('wrong_branch')
        end

        local entity = Rental.liveEntity(lease)
        local ped = GetPlayerPed(playerId)

        if
            not Rental.near(playerId, branch, true)
            or not entity
            or GetEntityRoutingBucket(entity) ~= branch.bucket
            or GetVehiclePedIsIn(ped, false) ~= entity
            or GetPedInVehicleSeat(entity, -1) ~= ped
            or #(GetEntityCoords(entity) - branch.returnCoords) > Config.ReturnDistance
        then
            return Rental.error('return_vehicle')
        end

        -- SQL is awaited while the character lock is held. Vehicle identity comes from the server's lease.
        lease.source = playerId
        lease.player = player
        Rental.close(lease, 'returned')
        return { ok = true }
    end)
end
