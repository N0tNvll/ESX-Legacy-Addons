local activeRequests = {}
local requestCooldowns = {}

local function GetRequestKey(source, action)
	return ('%s:%s'):format(source, action)
end

local function BeginRequest(source, action)
	local key = GetRequestKey(source, action)
	local now = GetGameTimer()
	local cooldown = tonumber(Config.PurchaseCooldown) or 750

	if activeRequests[key] or (requestCooldowns[key] and requestCooldowns[key] > now) then
		return nil
	end

	activeRequests[key] = true
	requestCooldowns[key] = now + math.max(cooldown, 0)
	return key
end

local function EndRequest(key)
	if key then
		activeRequests[key] = nil
	end
end

local function GetPlayerIdentifier(xPlayer)
	if not xPlayer then
		return nil
	end

	if type(xPlayer.getIdentifier) == 'function' then
		local ok, identifier = pcall(xPlayer.getIdentifier)
		if ok and type(identifier) == 'string' then
			return identifier
		end
	end

	return type(xPlayer.identifier) == 'string' and xPlayer.identifier or nil
end

local function ValidateSamePlayer(source, expectedIdentifier)
	local xPlayer = ValidatePlayer(source)

	if not xPlayer or GetPlayerIdentifier(xPlayer) ~= expectedIdentifier then
		return nil
	end

	return xPlayer
end

AddEventHandler('playerDropped', function()
	local prefix = tostring(source) .. ':'

	for key in pairs(activeRequests) do
		if key:sub(1, #prefix) == prefix then
			activeRequests[key] = nil
		end
	end

	for key in pairs(requestCooldowns) do
		if key:sub(1, #prefix) == prefix then
			requestCooldowns[key] = nil
		end
	end
end)

---Handles weapon license purchase requests
---@param source number Player source
---@param cb function Callback function(success)
function ProcessLicensePurchase(source, cb)
	local requestKey = BeginRequest(source, 'license')
	if not requestKey then
		cb(false)
		return
	end

	local function finish(success)
		EndRequest(requestKey)
		cb(success and true or false)
	end

	local xPlayer = ValidatePlayer(source)
	local licensePrice = tonumber(Config.LicensePrice) or 0

	if not xPlayer then
		finish(false)
		return
	end

	local identifier = GetPlayerIdentifier(xPlayer)
	if not identifier then
		finish(false)
		return
	end

	if not Config.LicenseEnable then
		finish(false)
		return
	end

	if not ValidatePlayerNearLicenseShop(source) then
		finish(false)
		return
	end

	if not IsLicenseResourceAvailable() then
		finish(false)
		return
	end

	if licensePrice <= 0 then
		finish(false)
		return
	end

	if (tonumber(xPlayer.getMoney()) or 0) < licensePrice then
		xPlayer.showNotification(TranslateCap('not_enough'))
		finish(false)
		return
	end

	CheckWeaponLicense(source, function(hasLicense)
		if hasLicense ~= false then
			finish(false)
			return
		end

		xPlayer = ValidateSamePlayer(source, identifier)
		if not xPlayer then
			finish(false)
			return
		end

		if not ValidatePlayerNearLicenseShop(source) then
			finish(false)
			return
		end

		if (tonumber(xPlayer.getMoney()) or 0) < licensePrice then
			xPlayer.showNotification(TranslateCap('not_enough'))
			finish(false)
			return
		end

		xPlayer.removeMoney(licensePrice, 'Weapon License')

		AddWeaponLicense(source, function(added, reason)
			if added then
				finish(true)
				return
			end

			if reason ~= 'timeout' then
				xPlayer = ValidateSamePlayer(source, identifier)
			end

			if reason ~= 'timeout' and xPlayer then
				xPlayer.addMoney(licensePrice, 'Weapon License Refund')
			end

			finish(false)
		end)
	end)
end

---Handles weapon purchase requests from clients
---@param source number Player source
---@param weaponName string
---@param zone string Shop zone
---@param cb function Callback function(success)
function ProcessWeaponPurchase(source, weaponName, zone, cb)
	local requestKey = BeginRequest(source, 'weapon')
	if not requestKey then
		cb(false)
		return
	end

	local function finish(success)
		EndRequest(requestKey)
		cb(success and true or false)
	end

	local xPlayer = ValidatePlayer(source)

	if not xPlayer then
		finish(false)
		return
	end

	local identifier = GetPlayerIdentifier(xPlayer)
	if not identifier then
		finish(false)
		return
	end

	if not ValidateZone(zone, source) or not ValidateWeaponName(weaponName, source) then
		finish(false)
		return
	end

	if not ValidatePlayerNearZone(source, zone) then
		finish(false)
		return
	end

	local price = GetPrice(weaponName, zone)

	if price <= 0 then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to buy Invalid weapon - %s!'):format(
			source,
			tostring(weaponName)
		))
		finish(false)
		return
	end

	local isBlackMarket = zone == 'BlackWeashop'

	CheckRequiredWeaponLicense(source, zone, function(hasRequiredLicense)
		if not hasRequiredLicense then
			finish(false)
			return
		end

		xPlayer = ValidateSamePlayer(source, identifier)
		if not xPlayer then
			finish(false)
			return
		end

		if not ValidatePlayerNearZone(source, zone) then
			finish(false)
			return
		end

		if not CanReceiveWeapon(source, xPlayer, weaponName) then
			finish(false)
			return
		end

		if not CanPayForWeapon(xPlayer, isBlackMarket, price) then
			finish(false)
			return
		end

		if not TakeWeaponPayment(xPlayer, isBlackMarket, price) then
			finish(false)
			return
		end

		if not AddWeapon(source, xPlayer, weaponName) then
			xPlayer = ValidateSamePlayer(source, identifier)
			if xPlayer then
				RefundWeaponPayment(xPlayer, isBlackMarket, price)
			end

			finish(false)
			return
		end

		finish(true)
	end)
end
