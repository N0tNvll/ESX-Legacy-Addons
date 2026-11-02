local S = VehicleShopClient
local starting = false

local function roadSpawn(point)
    if not point then
        return nil
    end

    local found, coords, heading =
        GetClosestVehicleNodeWithHeading(point.x, point.y, point.z, 1, 3.0, 0)

    if not found or not coords then
        return nil
    end

    return { x = coords.x, y = coords.y, z = coords.z, w = heading or 0.0 }
end

local function stop(restore, reopen)
    local drive = S.testDrive

    if not drive then
        return
    end

    S.testDrive = nil
    S.send('testDrive', { active = false })

    if not restore or not ESX.IsPlayerLoaded() or IsEntityDead(PlayerPedId()) then
        return
    end

    local ped, coords = PlayerPedId(), drive.returnCoords

    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.w or 0)

    if reopen and S.generation == drive.generation and S.openShop(drive.shopId) then
        S.send('selectVehicle', { model = drive.model })
    end
end

function S.finishTestDrive(reopen)
    local drive = S.testDrive

    if not drive or drive.finishing then
        return false
    end

    drive.finishing = true
    drive.reopen = reopen ~= false

    local result, failure = S.request('finishTestDrive', drive.id)

    if not result then
        drive.finishing = false
    end

    return result, failure
end

function S.startTestDrive(data)
    if starting or S.testDrive or S.pending or not S.open or not S.shop then
        return nil, 'test_active'
    end

    starting = true

    local generation = S.generation
    local origin = S.shop.testDrivePoint or S.shop.delivery or S.shop.preview
    local drive, failure = S.request('startTestDrive', {
        shopId = S.shop.id,
        model = data.model,
        color = data.color,
        spawn = roadSpawn(origin),
    })

    starting = false

    if not drive then
        return nil, failure
    end

    if generation ~= S.generation or not ESX.IsPlayerLoaded() then
        S.request('finishTestDrive', drive.id)
        return nil, 'test_unavailable'
    end

    S.close()
    S.testDrive = drive
    drive.generation = S.generation
    drive.deadline = GetGameTimer() + drive.duration * 1000

    local deadline, vehicle = GetGameTimer() + 5000, 0

    while S.testDrive == drive and GetGameTimer() < deadline do
        if NetworkDoesEntityExistWithNetworkId(drive.netId) then
            vehicle = NetToVeh(drive.netId)

            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                break
            end
        end

        Wait(50)
    end

    if S.testDrive ~= drive or not ESX.IsPlayerLoaded() or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityModel(vehicle) ~= joaat(drive.model) or IsEntityDead(PlayerPedId()) then
        S.finishTestDrive(false)
        return nil, 'spawn_failed'
    end

    deadline = GetGameTimer() + 2000

    while S.testDrive == drive and not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(vehicle)
        Wait(50)
    end

    if S.testDrive ~= drive or not NetworkHasControlOfEntity(vehicle) then
        S.finishTestDrive(false)
        return nil, 'spawn_failed'
    end

    local ok = pcall(function()
        xLib.game.setVehicleProperties(vehicle, drive.props)
        SetVehicleFuelLevel(vehicle, 100.0)
        SetVehicleDoorsLocked(vehicle, 4)
        SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
    end)

    if not ok then
        S.finishTestDrive(false)
        return nil, 'spawn_failed'
    end

    deadline = GetGameTimer() + 2000

    while S.testDrive == drive and GetVehiclePedIsIn(PlayerPedId(), false) ~= vehicle and GetGameTimer() < deadline do
        Wait(50)
    end

    if S.testDrive ~= drive or GetVehiclePedIsIn(PlayerPedId(), false) ~= vehicle then
        S.finishTestDrive(false)
        return nil, 'spawn_failed'
    end

    drive.vehicle = vehicle
    drive.reopen = true
    S.send('testDrive', { active = true, remaining = drive.duration })
    return true
end

RegisterNetEvent('esx_vehicleshop:testDriveEnded', function(id, restore)
    local drive = S.testDrive

    if drive and drive.id == id then
        stop(restore, drive.reopen)
    end
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    stop(false, false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() or resource == 'esx_garage' then
        stop(true, false)
    end
end)

xLib.addKeybind({
    name = 'esx_vehicleshop_end_test_drive',
    description = S.translate('dealership_end_test'),
    defaultMapper = 'keyboard',
    defaultKey = 'G',
    onPressed = function()
        S.finishTestDrive(true)
    end,
})

CreateThread(function()
    while true do
        Wait(250)

        local drive = S.testDrive

        if drive and drive.vehicle and not drive.finishing then
            local remaining = math.max(0, math.ceil((drive.deadline - GetGameTimer()) / 1000))

            S.send('testDrive', { active = true, remaining = remaining })

            if remaining == 0 or IsEntityDead(PlayerPedId()) or not DoesEntityExist(drive.vehicle) or GetVehiclePedIsIn(PlayerPedId(), false) ~= drive.vehicle then
                S.finishTestDrive(not IsEntityDead(PlayerPedId()))
            end
        end
    end
end)
