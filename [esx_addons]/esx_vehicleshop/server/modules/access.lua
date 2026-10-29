-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
local D = VehicleShop

function D.employee(player, shop, boss)
    local rule, job = shop.management, player and player.job

    if
        shop.mode ~= 'managed'
        or not rule
        or not job
        or job.name ~= rule.job
        or job.grade < (rule.minGrade or 0)
        or job.onDuty == false
    then
        return false
    end

    return not boss or ((rule.bossGrades or { boss = true })[job.grade_name] == true)
end

function D.canAccess(player, shop)
    if not D.current(player) or not shop or shop.enabled == false then
        return false
    end

    if
        shop.ownershipJob
        and (not player.job or player.job.name ~= shop.ownershipJob or player.job.onDuty == false)
    then
        return false
    end

    if shop.access and shop.access.jobs then
        local grade = shop.access.jobs[player.job.name]

        if grade == nil or player.job.grade < grade or player.job.onDuty == false then
            return false
        end
    end

    if shop.access and shop.access.authorize then
        local ok, allowed = pcall(shop.access.authorize, player.source, shop.id)

        if not ok or allowed ~= true or not D.current(player) then
            return false
        end

        local job = player.job

        if
            shop.ownershipJob and (not job or job.name ~= shop.ownershipJob or job.onDuty == false)
        then
            return false
        end

        if shop.access.jobs then
            local minimum = job and shop.access.jobs[job.name]

            if minimum == nil or job.grade < minimum or job.onDuty == false then
                return false
            end
        end
    end

    return true
end

function D.location(source, shop, action)
    if action == 'resale' then
        return D.near(source, shop.resalePoint, 12)
    end

    if action == 'return' then
        return D.near(source, shop.returnPoint, 12)
    end

    if
        action == nil
        and (D.near(source, shop.returnPoint, 12) or D.near(source, shop.resalePoint, 12))
    then
        return true
    end

    return D.near(source, shop.coords, 12)
        or D.near(source, shop.managementPoint, 8)
        or D.near(source, shop.preview, 8)
        or (action == 'inventory' and D.near(source, shop.resalePoint, 12))
end

function D.playerShop(source, id, action, employee)
    local player, shop = ESX.GetPlayerFromId(source), type(id) == 'string' and D.shops[id]

    D.assert(D.canAccess(player, shop), 'not_allowed')
    D.assert(D.location(source, shop, action), 'not_near_shop')

    if employee then
        D.assert(D.employee(player, shop), 'employee_required')
    end

    return player, shop
end

function D.hasLicense(player, name)
    if not name then
        return true
    end

    if GetResourceState('esx_license') ~= 'started' then
        return false
    end

    return MySQL.scalar.await(
        'SELECT 1 FROM user_licenses WHERE owner = ? AND type = ? LIMIT 1',
        { player.getIdentifier(), name }
    ) ~= nil
end

function D.validBuyer(player, shop, offer)
    D.assert(D.canAccess(player, shop) and D.location(player.source, shop), 'purchase_invalidated')
    D.assert(
        D.hasLicense(player, shop.license) and D.hasLicense(player, offer and offer.license),
        'license_required'
    )
    D.assert(D.canAccess(player, shop) and D.location(player.source, shop), 'purchase_invalidated')
end

function D.entity(source, plate)
    local ped = GetPlayerPed(source)

    if not ped or ped <= 0 then
        return nil
    end

    for _, entity in ipairs(GetAllVehicles()) do
        if
            DoesEntityExist(entity)
            and xLib.vehiclePlate.normalize(GetVehicleNumberPlateText(entity)) == plate
            and #(GetEntityCoords(entity) - GetEntityCoords(ped)) <= 10
            and GetEntityRoutingBucket(entity) == GetPlayerRoutingBucket(source)
        then
            return entity
        end
    end
end

function D.shopPayload(shop, player)
    local manager = D.employee(player, shop)

    return {
        id = shop.id,
        name = shop.label or shop.id,
        mode = shop.mode,
        coords = D.point(shop.coords),
        preview = D.point(shop.preview),
        delivery = shop.delivery and D.point(shop.delivery.coords),
        managementPoint = manager and D.point(shop.managementPoint) or nil,
        existingInteraction = shop.existingInteraction == true,
        resalePoint = D.point(shop.resalePoint),
        returnPoint = D.point(shop.returnPoint),
        blip = shop.blip,
        marker = shop.marker,
        color = shop.color,
        logo = shop.logo,
        paymentMethods = shop.paymentMethods,
        license = shop.license,
        licensePrice = shop.licensePrice,
        employee = manager,
        boss = D.employee(player, shop, true),
        societyJob = manager and shop.management.job or nil,
        societyInventory = manager and shop.societyInventory or nil,
        billingAccount = manager and shop.billingAccount or nil,
        rentals = shop.rentals and shop.rentals.enabled == true,
        resale = shop.resale and shop.resale.enabled == true,
        stockMode = shop.stockMode,
    }
end
