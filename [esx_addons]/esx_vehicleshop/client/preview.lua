-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
local S = VehicleShopClient
local vehicle, camera, sequence = nil, nil, 0

function S.clearPreview()
    sequence = sequence + 1

    if vehicle and DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end

    vehicle = nil

    if camera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(camera, false)
        camera = nil
    end

    ClearFocus()
end

function S.preview(model)
    if
        type(model) ~= 'string'
        or not model:match('^[%w_%-]+$')
        or not S.shop
        or not S.shop.preview
    then
        return nil, 'preview_unavailable'
    end

    local hash = joaat(model)

    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return nil, 'model_unavailable'
    end

    S.clearPreview()

    local current, point = sequence, S.shop.preview
    local ok, loaded = pcall(xLib.streaming.requestModelWithSpinner, hash, 'Cargando vehículo')

    if not ok or not loaded then
        return nil, 'model_unavailable'
    end

    if not S.open or current ~= sequence then
        SetModelAsNoLongerNeeded(hash)
        return false
    end

    SetFocusPosAndVel(point.x, point.y, point.z, 0, 0, 0)
    xLib.game.spawnLocalVehicle(
        hash,
        vector3(point.x, point.y, point.z),
        point.w or 0,
        function(entity)
            if current ~= sequence or not S.open then
                DeleteEntity(entity)
                SetModelAsNoLongerNeeded(hash)
                return
            end

            vehicle = entity
            FreezeEntityPosition(entity, true)
            SetEntityCollision(entity, false, false)
            SetVehicleDoorsLocked(entity, 2)

            local minimum, maximum = GetModelDimensions(hash)
            local distance =
                math.max(5.5, (maximum.y - minimum.y) * 1.3, (maximum.x - minimum.x) * 1.5)
            camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

            local angle = math.rad((point.w or 0) + 45)

            SetCamCoord(
                camera,
                point.x + math.cos(angle) * distance,
                point.y + math.sin(angle) * distance,
                point.z + math.max(1.5, maximum.z * 0.8)
            )
            PointCamAtEntity(camera, entity, 0, 0, maximum.z * 0.35, true)
            SetCamFov(camera, 50.0)
            SetCamActive(camera, true)
            RenderScriptCams(true, false, 0, true, true)
            SetModelAsNoLongerNeeded(hash)
        end
    )
    return true
end
