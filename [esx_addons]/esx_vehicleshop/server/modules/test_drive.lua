local D = VehicleShop
local drives, cooldowns = {}, {}
local stopping = false

local function finish(source, notify)
    local drive = drives[source]

    if not drive then
        return true
    end

    drive.closing = true

    if drive.spawning then
        return true
    end

    local ok, released = true, true

    if drive.spawned and GetResourceState('esx_garage') == 'started' then
        ok, released = pcall(function()
            return exports['esx_garage']:releaseRentalVehicle(drive.owner, drive.plate)
        end)
    end

    if notify and not drive.notified and D.current(drive.player) then
        drive.notified = true
        TriggerClientEvent('esx_vehicleshop:testDriveEnded', source, drive.id, GetPlayerRoutingBucket(source) == drive.bucket)
    end

    if ok and released then
        drives[source] = nil
        cooldowns[source] = GetGameTimer() + 5000
        return true
    end

    return false
end

D.register('startTestDrive', function(source, request)
    D.assert(not stopping and type(request) == 'table', 'test_unavailable')
    D.assert(not drives[source] and (cooldowns[source] or 0) <= GetGameTimer(), 'test_active')

    local player, shop = D.playerShop(source, request.shopId)
    local offer = D.assert(D.offer(shop, request.model, player), 'invalid_vehicle')
    local point = type(shop.testDrive) == 'table' and shop.testDrive.coords or (shop.delivery and shop.delivery.coords) or shop.preview
    local ped = GetPlayerPed(source)

    D.assert(Config.TestDrive.enabled and shop.testDrive ~= false and point, 'test_unavailable')
    D.assert(ped ~= 0 and GetEntityHealth(ped) > 0, 'test_unavailable')
    D.assert(GetVehiclePedIsIn(ped, false) == 0, 'leave_vehicle')
    D.validBuyer(player, shop, offer)

    local props = D.paintProps(offer.props, request.color)
    local coords = GetEntityCoords(ped)
    local drive = {
        id = D.uuid(),
        owner = player.getIdentifier(),
        player = player,
        shop = shop.id,
        model = offer.model,
        returnCoords = { x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped) },
        bucket = GetPlayerRoutingBucket(source),
        duration = math.max(10, math.min(300, math.floor(Config.TestDrive.duration))),
        spawning = true,
    }

    drives[source] = drive

    local ok, result = pcall(function()
        local vehicleType = ESX.GetVehicleType(offer.model, source)

        D.assert(vehicleType and not drive.closing and not stopping, 'test_unavailable')
        D.validBuyer(player, shop, D.assert(D.offer(shop, offer.model, player), 'invalid_vehicle'))
        D.assert(GetPlayerRoutingBucket(source) == drive.bucket, 'purchase_invalidated')

        drive.plate = D.assert(D.plate(), 'plate_unavailable')

        for _, other in pairs(drives) do
            D.assert(other == drive or other.plate ~= drive.plate, 'busy')
        end

        local entity, failure = exports['esx_garage']:spawnRentalVehicle({
            plate = drive.plate,
            identifier = drive.owner,
            branch = 'test:' .. shop.id,
            model = offer.model,
        }, {
            bucket = drive.bucket,
            spawns = { point },
        }, vehicleType, { radius = 3.0, timeout = 5000 })

        D.assert(entity, failure or 'spawn_failed')
        drive.spawned = true
        drive.netId = entity.netId
        D.assert(not drive.closing and not stopping, 'test_unavailable')
        D.validBuyer(player, shop, D.assert(D.offer(shop, offer.model, player), 'invalid_vehicle'))
        D.assert(GetPlayerRoutingBucket(source) == drive.bucket, 'purchase_invalidated')
        drive.expires = os.time() + drive.duration
        D.assert(exports['esx_garage']:publishRentalVehicle(drive.owner, drive.plate, drive.expires), 'spawn_failed')

        return {
            id = drive.id,
            shopId = shop.id,
            model = drive.model,
            netId = drive.netId,
            plate = drive.plate,
            props = D.safeProps(props, drive.model, drive.plate),
            returnCoords = drive.returnCoords,
            duration = math.max(0, drive.expires - os.time()),
        }
    end)

    drive.spawning = false

    if not ok then
        finish(source, false)
        error(result)
    end

    return result
end)

D.register('finishTestDrive', function(source, id)
    local drive = drives[source]

    D.assert(not drive or (drive.id == id and D.current(drive.player)), 'test_unavailable')
    finish(source, true)
    return true
end)

AddEventHandler('esx:playerDropped', function(playerId)
    finish(playerId, false)
    cooldowns[playerId] = nil
end)

AddEventHandler('esx:playerLogout', function(playerId)
    finish(playerId, false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() and resource ~= 'esx_garage' then
        return
    end

    stopping = resource == GetCurrentResourceName()

    for source in pairs(drives) do
        finish(source, true)
    end
end)

CreateThread(function()
    while not stopping do
        Wait(1000)

        for source, drive in pairs(drives) do
            if not drive.spawning then
                local ped = GetPlayerPed(source)
                local entity = GetResourceState('esx_garage') == 'started' and exports['esx_garage']:getRentalVehicle(drive.owner, drive.plate)

                if drive.closing or drive.expires <= os.time() or not D.current(drive.player) or ped == 0 or GetEntityHealth(ped) <= 0 or GetPlayerRoutingBucket(source) ~= drive.bucket or not entity or #(GetEntityCoords(ped) - vector3(drive.returnCoords.x, drive.returnCoords.y, drive.returnCoords.z)) > Config.TestDrive.maxDistance then
                    finish(source, true)
                end
            end
        end
    end
end)
