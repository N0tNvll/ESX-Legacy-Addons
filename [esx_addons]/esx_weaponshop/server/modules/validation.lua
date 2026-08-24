---Gets weapon price from a configured zone
---@param weaponName string
---@param zone string
---@return number
function GetPrice(weaponName, zone)
	if type(weaponName) ~= 'string' or type(zone) ~= 'string' then
		return -1
	end

	local zoneConfig = Config.Zones[zone]

	if not zoneConfig or not zoneConfig.Items then
		return -1
	end

	for i = 1, #zoneConfig.Items do
		local weapon = zoneConfig.Items[i]

		if weapon.name == weaponName then
			return tonumber(weapon.price) or -1
		end
	end

	return -1
end

---Validates weapon input is a bounded string
---@param weaponName any
---@param source number Player source for logging
---@return boolean valid
function ValidateWeaponName(weaponName, source)
	if type(weaponName) ~= 'string' or weaponName == '' or #weaponName > 64 then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to buy weapon with Invalid name - %s!'):format(
			source,
			tostring(weaponName)
		))
		return false
	end

	return true
end

---Validates zone exists
---@param zone string Zone name
---@param source number Player source for logging
---@return boolean valid
function ValidateZone(zone, source)
	if type(zone) ~= 'string' or not Config.Zones[zone] then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to buy weapon from Invalid zone - %s!'):format(
			source,
			tostring(zone)
		))
		return false
	end

	return true
end

local function GetPlayerServerCoords(source)
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 or not DoesEntityExist(ped) then
		return nil
	end

	return GetEntityCoords(ped)
end

local function IsCoordsNearZone(coords, zone)
	local zoneConfig = Config.Zones[zone]
	if not zoneConfig or not zoneConfig.Locations then
		return false
	end

	local interactionDistance = tonumber(Config.InteractionDistance) or 2.0
	local serverDistanceBuffer = tonumber(Config.ServerDistanceBuffer) or 3.0
	local maxDistance = interactionDistance + serverDistanceBuffer
	for i = 1, #zoneConfig.Locations do
		if #(coords - zoneConfig.Locations[i]) <= maxDistance then
			return true
		end
	end

	return false
end

---Validates the player is near the requested shop zone server-side
---@param source number Player source
---@param zone string Shop zone
---@return boolean valid
function ValidatePlayerNearZone(source, zone)
	local coords = GetPlayerServerCoords(source)
	if not coords or not IsCoordsNearZone(coords, zone) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted remote weaponshop access - %s!'):format(
			source,
			tostring(zone)
		))
		return false
	end

	return true
end

---Validates the player is near any legal weapon shop for license purchase
---@param source number Player source
---@return boolean valid
function ValidatePlayerNearLicenseShop(source)
	local coords = GetPlayerServerCoords(source)
	if not coords then
		return false
	end

	for zoneName, zoneConfig in pairs(Config.Zones) do
		if zoneConfig.Legal and IsCoordsNearZone(coords, zoneName) then
			return true
		end
	end

	print(('[^3WARNING^7] Player ^5%s^7 attempted remote weapon license purchase!'):format(source))
	return false
end

---Checks whether esx_license is available when licensing is enabled
---@return boolean available
function IsLicenseResourceAvailable()
	if not Config.LicenseEnable then
		return true
	end

	if GetResourceState('esx_license') ~= 'started' then
		print('[^3WARNING^7] esx_weaponshop requires esx_license while Config.LicenseEnable is true.')
		return false
	end

	return true
end

---Checks if a player already has the weapon license
---@param source number Player source
---@param cb function Callback(hasLicense)
function CheckWeaponLicense(source, cb)
	if not IsLicenseResourceAvailable() then
		cb(nil)
		return
	end

	local responded = false
	local timeout = tonumber(Config.LicenseCallbackTimeout) or 5000

	SetTimeout(timeout, function()
		if responded then
			return
		end

		responded = true
		print(('[^3WARNING^7] esx_license:checkLicense timed out for player ^5%s^7.'):format(source))
		cb(nil)
	end)

	local triggered = pcall(function()
		TriggerEvent('esx_license:checkLicense', source, 'weapon', function(hasLicense)
			if responded then
				return
			end

			responded = true
			cb(hasLicense == true)
		end)
	end)

	if not triggered and not responded then
		responded = true
		cb(nil)
	end
end

---Checks if the requested zone requires and has a weapon license
---@param source number Player source
---@param zone string Shop zone
---@param cb function Callback(hasRequiredLicense)
function CheckRequiredWeaponLicense(source, zone, cb)
	local zoneConfig = Config.Zones[zone]
	if not Config.LicenseEnable or not zoneConfig or not zoneConfig.Legal then
		cb(true)
		return
	end

	CheckWeaponLicense(source, cb)
end

---Adds the weapon license through esx_license
---@param source number Player source
---@param cb function Callback(success, reason)
function AddWeaponLicense(source, cb)
	if not IsLicenseResourceAvailable() then
		cb(false, 'unavailable')
		return
	end

	local responded = false
	local timeout = tonumber(Config.LicenseCallbackTimeout) or 5000

	SetTimeout(timeout, function()
		if responded then
			return
		end

		responded = true
		print(('[^3WARNING^7] esx_license:addLicense timed out for player ^5%s^7.'):format(source))
		cb(false, 'timeout')
	end)

	local triggered = pcall(function()
		TriggerEvent('esx_license:addLicense', source, 'weapon', function()
			if responded then
				return
			end

			responded = true
			cb(true)
		end)
	end)

	if not triggered and not responded then
		responded = true
		cb(false, 'error')
	end
end
