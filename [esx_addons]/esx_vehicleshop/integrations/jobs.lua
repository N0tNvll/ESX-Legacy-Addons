-- SPDX-License-Identifier: GPL-3.0-only
-- Runs server-side inside the job resource, after its config and garage adapter.
local resource = GetCurrentResourceName()
local job = assert(
    ({ esx_policejob = 'police', esx_ambulancejob = 'ambulance' })[resource],
    'Unsupported dealership integration'
)

local registering, pending = false, false

local function authorized(source)
    local player = ESX.GetPlayerFromId(source)

    if not player or player.job.name ~= job or player.job.onDuty == false then
        return false
    end

    if Config.EnableESXService then
        return GetResourceState('esx_service') == 'started'
            and exports['esx_service']:IsInService(job, source) == true
    end

    return true
end

local function register()
    if registering then
        pending = true
        return
    end

    if GetResourceState('esx_vehicleshop') ~= 'started' then
        return
    end

    registering = true

    local ok, problem = pcall(function()
        ESXCatalog.awaitReady()

        local locations = job == 'police' and Config.PoliceStations or Config.Hospitals

        for key, location in pairs(locations or {}) do
            for group, vehicleType in pairs({
                Vehicles = 'car',
                Helicopters = 'helicopter',
                Planes = 'plane',
                Boats = 'boat',
            }) do
                local gradeOffers = Config.AuthorizedVehicles[vehicleType] or {}
                local offers, added = {}, {}

                for _, list in pairs(gradeOffers) do
                    for _, offer in ipairs(list) do
                        local model = offer.model:lower()

                        if not added[model] then
                            added[model] = true
                            offers[#offers + 1] = {
                                model = model,
                                name = offer.label or model,
                                price = offer.price,
                                props = offer.props,
                                category = job .. '_' .. vehicleType,
                                type = vehicleType,
                            }
                        end
                    end
                end

                for index, point in ipairs(location[group] or {}) do
                    local id = ('%s_%s_%s_%s'):format(job, key, group:lower(), index)
                    local settings = Config.DealershipIntegration or {}

                    exports['esx_vehicleshop']:registerDealership(id, {
                        label = point.ShopLabel
                            or ((location.label or location.Label or key) .. ' - ' .. job),
                        mode = 'public',
                        existingInteraction = true,
                        coords = point.Spawner,
                        preview = point.InsideShop,
                        delivery = { mode = 'garage', garage = id },
                        vehicleTypes = { vehicleType },
                        offers = offers,
                        access = {
                            jobs = { [job] = point.ShopMinGrade or settings.minGrade or 0 },
                            authorize = authorized,
                        },
                        ownershipJob = job,
                        stockMode = 'unlimited',
                        paymentMethods = settings.paymentMethods or { 'money', 'bank' },
                        societyAccount = settings.societyAccount or ('society_' .. job),
                        societyMinGrade = settings.societyMinGrade or 0,
                        resolveOffer = function(source, model)
                            if not authorized(source) then
                                return nil
                            end

                            local player = ESX.GetPlayerFromId(source)

                            for _, offer in ipairs(gradeOffers[player.job.grade_name] or {}) do
                                if offer.model:lower() == model then
                                    return { price = offer.price, props = offer.props }
                                end
                            end
                        end,
                    })
                end
            end
        end
    end)

    registering = false

    if not ok then
        print(('[%s] Dealership registration failed: %s'):format(resource, tostring(problem)))
    end

    if pending then
        pending = false
        register()
    end
end

MySQL.ready(register)
AddEventHandler('esx_vehicleshop:ready', register)
AddEventHandler('onResourceStart', function(name)
    if name == 'esx_vehicleshop' then
        register()
    end
end)
