local vehicles, slots = {}, {}

local function allowed()
    return GetInvokingResource() == 'esx_vehicleshop'
end

local function live(record)
    local entity = record and record.entity

    if not entity or not DoesEntityExist(entity) then
        return nil
    end

    if
        GetEntityModel(entity) ~= record.model
        or NetworkGetNetworkIdFromEntity(entity) ~= record.netId
    then
        return nil
    end

    return entity
end

local function releaseSlot(record)
    if record and record.slot then
        slots[record.slot] = nil
        record.slot = nil
    end
end

local function remove(record)
    local entity = live(record)

    if entity then
        FreezeEntityPosition(entity, true)
        DeleteEntity(entity)

        if DoesEntityExist(entity) then
            record.retiring = true
            return true, 'pending'
        end
    end

    releaseSlot(record)
    vehicles[record.plate] = nil
    return true
end

local function reserve(branchId, branch, radius)
    for index, coords in ipairs(branch.spawns) do
        local key = ('%s:%d'):format(branchId, index)
        local blocked = slots[key] ~= nil

        if not blocked then
            for _, entity in ipairs(GetAllVehicles()) do
                if GetEntityRoutingBucket(entity) == branch.bucket then
                    local target = vector3(coords.x, coords.y, coords.z)

                    if #(GetEntityCoords(entity) - target) < radius then
                        blocked = true
                        break
                    end
                end
            end
        end

        if not blocked then
            slots[key] = true
            return coords, key
        end
    end
end

exports('spawnRentalVehicle', function(lease, branch, vehicleType, options)
    if not allowed() or type(lease) ~= 'table' or type(branch) ~= 'table' then
        return nil, 'unavailable'
    end

    local previous = vehicles[lease.plate]

    if previous and (previous.identifier ~= lease.identifier or live(previous)) then
        return nil, 'vehicle_in_use'
    end

    if previous then
        remove(previous)
    end

    local coords, slot = reserve(lease.branch, branch, options.radius)

    if not coords then
        return nil, 'spawn_blocked'
    end

    local record = {
        identifier = lease.identifier,
        plate = lease.plate,
        model = joaat(lease.model),
        slot = slot,
    }

    vehicles[lease.plate] = record

    local ok, problem = pcall(function()
        record.entity = CreateVehicleServerSetter(
            record.model,
            vehicleType,
            coords.x,
            coords.y,
            coords.z,
            coords.w
        )

        local deadline = GetGameTimer() + options.timeout

        while
            record.entity ~= 0
            and not DoesEntityExist(record.entity)
            and GetGameTimer() < deadline
        do
            Wait(50)
        end

        assert(record.entity ~= 0 and DoesEntityExist(record.entity), 'spawn_failed')
        record.netId = NetworkGetNetworkIdFromEntity(record.entity)
        SetEntityRoutingBucket(record.entity, branch.bucket)
        SetEntityOrphanMode(record.entity, 2)
        FreezeEntityPosition(record.entity, true)
        SetVehicleNumberPlateText(record.entity, lease.plate)
    end)

    if not ok then
        remove(record)
        return nil, 'spawn_failed'
    end

    return { entity = record.entity, netId = record.netId }
end)

exports('getRentalVehicle', function(identifier, plate)
    local record = vehicles[plate]

    if not allowed() or not record or record.identifier ~= identifier then
        return nil
    end

    return live(record)
end)

exports('publishRentalVehicle', function(identifier, plate, expires)
    local record = vehicles[plate]
    local entity = live(record)

    if not allowed() or not entity or record.identifier ~= identifier or record.retiring then
        return false
    end

    FreezeEntityPosition(entity, false)
    Entity(entity).state:set('esxRental', { plate = plate, expires = expires }, true)
    releaseSlot(record)
    return true
end)

exports('releaseRentalVehicle', function(identifier, plate)
    local record = vehicles[plate]

    if not allowed() or (record and record.identifier ~= identifier) then
        return false
    end

    return not record or remove(record)
end)

CreateThread(function()
    while true do
        Wait(1000)

        for _, record in pairs(vehicles) do
            if record.retiring then
                remove(record)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() and resource ~= 'esx_vehicleshop' then
        return
    end

    for _, record in pairs(vehicles) do
        local entity = live(record)

        if entity then
            FreezeEntityPosition(entity, true)
            DeleteEntity(entity)
        end

        releaseSlot(record)
    end

    vehicles = {}
end)
