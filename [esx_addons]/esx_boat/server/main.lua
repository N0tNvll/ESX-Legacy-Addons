-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

local function generateBoatPlate()
	return xLib.vehiclePlate.generateUnique({
		prefix = 'BO',
		letters = 2,
		numbers = 4
	}, function(plate)
		return MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE plate = ?', {plate}) ~= nil
	end)
end

local getPlayerCoords = xLib.player.getCoords
local function isNearCoords(source, coords, distance)
	if type(coords) == 'vector4' then
		coords = vector3(coords.x, coords.y, coords.z)
	end

	return xLib.player.isNearCoords(source, coords, distance)
end

local function isNearBoatShop(source)
	for i = 1, #(Config.Zones.BoatShops or {}) do
		local shop = Config.Zones.BoatShops[i]
		if isNearCoords(source, shop.Outside, 20.0) or isNearCoords(source, shop.Inside, 35.0) then
			return true
		end
	end

	return false
end

local function getVehicleFromHash(model)
	for k,v in ipairs(Config.Vehicles) do
		if joaat(v.model) == model then
			return v
		end
	end

	return nil
end

xLib.callback.registerCompat('esx_boat:buyBoat', function(source, cb, vehicleProps, account)
    local xPlayer = ESX.GetPlayerFromId(source)
    local model = type(vehicleProps) == 'table' and tonumber(vehicleProps.model)
    local vehicleData = model and getVehicleFromHash(model)
    local price = vehicleData and tonumber(vehicleData.price) or 0

    -- vehicle model not found
    if not xPlayer or price == 0 or not isNearBoatShop(source) then
        print(('[^2INFO^7] Player ^5%s^7 Attempted To Exploit Shop'):format(source))
        return cb(false, 'invalid_purchase')
    end

    local plate = generateBoatPlate()

    if not plate then
        return cb(false, 'plate_unavailable')
    end

    if xPlayer.isCurrent() ~= true or not isNearBoatShop(source) then
        return cb(false, 'purchase_invalidated')
    end

    local storedProps = {model = model, plate = plate}
    if type(vehicleData.props) == 'table' then
        for key, value in pairs(vehicleData.props) do
            storedProps[key] = value
        end
    end

    local charged, failure = PaymentGateway.Charge(xPlayer, account, price, "Boat Purchase")

    if not charged then
        return cb(false, failure)
    end

    local query = 'INSERT INTO owned_vehicles (owner, plate, vehicle, type, `stored`) '
        .. 'VALUES (@owner, @plate, @vehicle, @type, @stored)'

    MySQL.insert(query, {
        ['@owner']   = xPlayer.getIdentifier(),
        ['@plate']   = plate,
        ['@vehicle'] = json.encode(storedProps),
        ['@type']    = 'boat',
        ['@stored']  = true
    }, function(insertId)
        if not insertId then
            PaymentGateway.Refund(xPlayer, account, price, "Boat Purchase Refund")
            return cb(false, 'persistence_failed')
        end

        cb(true)
    end)
end)

xLib.callback.registerCompat('esx_boat:buyBoatLicense', function(source, cb, account)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not isNearBoatShop(source) then
        return cb(false, 'invalid_purchase')
    end

    TriggerEvent('esx_license:checkLicense', source, 'boat', function(hasLicense)
        if xPlayer.isCurrent() ~= true then
            return cb(false, 'session_closing')
        end

        if hasLicense then
            return cb(false, 'already_owned')
        end

        if not isNearBoatShop(source) then
            return cb(false, 'not_near_shop')
        end

        local charged, failure =
            PaymentGateway.Charge(xPlayer, account, Config.LicensePrice, "Boat License Purchase")

        if not charged then
            return cb(false, failure)
        end
        TriggerEvent('esx_license:addLicense', source, 'boat', function(result)
            if not result then
                PaymentGateway.Refund(xPlayer, account, Config.LicensePrice, "Boat License Refund")
                return cb(false, 'license_failed')
            end

            cb(true)
        end)
    end)
end)

function getPriceFromModel(model)
	for k,v in ipairs(Config.Vehicles) do
		if joaat(v.model) == model then
			return v.price
		end
	end

	return 0
end
