local function GetOxInventory()
	if not Config.OxInventory then
		return nil
	end

	if GetResourceState('ox_inventory') ~= 'started' then
		print('[^3WARNING^7] ox_inventory is enabled in ESX config but the resource is not started.')
		return nil
	end

	return exports.ox_inventory
end

local function GetInitialWeaponAmmo()
	local ammo = tonumber(Config.InitialWeaponAmmo)

	if not ammo or ammo ~= ammo or ammo == math.huge or ammo == -math.huge then
		return 42
	end

	return math.max(math.floor(ammo), 0)
end

---Checks if player can receive the weapon
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@return boolean
function CanReceiveWeapon(source, xPlayer, weaponName)
	local ox_inventory = GetOxInventory()

	if Config.OxInventory and not ox_inventory then
		xPlayer.showNotification(TranslateCap('cannot_carry'))
		return false
	end

	if ox_inventory then
		local searched, count = pcall(function()
			return ox_inventory:Search(source, 'count', weaponName)
		end)

		if not searched or type(count) ~= 'number' then
			xPlayer.showNotification(TranslateCap('cannot_carry'))
			return false
		end

		if count > 0 then
			xPlayer.showNotification(TranslateCap('already_owned'))
			return false
		end

		local checked, canCarry = pcall(function()
			return ox_inventory:CanCarryItem(source, weaponName, 1)
		end)

		if not checked or not canCarry then
			xPlayer.showNotification(TranslateCap('cannot_carry'))
			return false
		end

		return true
	end

	local checked, hasWeapon = pcall(function()
		return xPlayer.hasWeapon(weaponName)
	end)

	if not checked then
		return false
	end

	if hasWeapon then
		xPlayer.showNotification(TranslateCap('already_owned'))
		return false
	end

	return true
end

---Gives weapon item to player depending on inventory backend
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@return boolean
function AddWeapon(source, xPlayer, weaponName)
	local ox_inventory = GetOxInventory()

	if Config.OxInventory and not ox_inventory then
		return false
	end

	if ox_inventory then
		local added, result = pcall(function()
			return ox_inventory:AddItem(source, weaponName, 1)
		end)

		return added and result == true
	end

	local added = pcall(function()
		xPlayer.addWeapon(weaponName, GetInitialWeaponAmmo())
	end)

	return added
end

---Checks whether the player owns a weapon in the active non-ox loadout.
---@param xPlayer table ESX player object
---@param weaponName string
---@return boolean
function HasPlayerWeapon(xPlayer, weaponName)
	if Config.OxInventory then
		return false
	end

	if type(xPlayer.hasWeapon) ~= 'function' then
		return false
	end

	local checked, hasWeapon = pcall(function()
		return xPlayer.hasWeapon(weaponName)
	end)

	return checked and hasWeapon == true
end

local function GetPlayerServerPed(source)
	if not source then
		return nil
	end

	local ped = GetPlayerPed(source)

	return ped and ped ~= 0 and ped or nil
end

local function GetPlayerWeaponEntry(xPlayer, weaponName)
	if type(xPlayer.getWeapon) == 'function' then
		local checked, first, second = pcall(function()
			return xPlayer.getWeapon(weaponName)
		end)

		if checked then
			if type(first) == 'table' then
				return first
			end

			if type(second) == 'table' then
				return second
			end
		end
	end

	if type(xPlayer.loadout) == 'table' then
		for i = 1, #xPlayer.loadout do
			local weapon = xPlayer.loadout[i]

			if weapon and weapon.name == weaponName then
				return weapon
			end
		end
	end

	return nil
end

local function NormalizeAmmoCount(value)
	value = tonumber(value)

	if not value or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	return math.max(math.floor(value), 0)
end

local function GetPedWeaponAmmo(source, weaponName)
	if type(GetAmmoInPedWeapon) ~= 'function' or type(weaponName) ~= 'string' then
		return nil
	end

	local ped = GetPlayerServerPed(source)
	if not ped then
		return nil
	end

	local checked, ammo = pcall(function()
		return GetAmmoInPedWeapon(ped, joaat(weaponName))
	end)

	return checked and NormalizeAmmoCount(ammo) or nil
end

---Gets the current ammo count for an owned weapon.
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@return number|nil ammo
function GetPlayerWeaponAmmo(source, xPlayer, weaponName)
	if Config.OxInventory then
		return nil
	end

	local pedAmmo = GetPedWeaponAmmo(source, weaponName)
	if pedAmmo then
		return pedAmmo
	end

	local weapon = GetPlayerWeaponEntry(xPlayer, weaponName)
	if not weapon then
		return nil
	end

	return NormalizeAmmoCount(weapon.ammo) or 0
end

local function NormalizePositiveAmmoLimit(value)
	value = NormalizeAmmoCount(value)

	return value and value > 0 and value or nil
end

---Checks whether adding ammo would stay inside the client runtime weapon ammo limit.
---@param source number Player source
---@param xPlayer table ESX player object
---@param weaponName string
---@param amount number
---@param ammoState table|nil Client ammo state with currentAmmo/maxAmmo
---@return boolean canAdd
function CanAddWeaponAmmo(source, xPlayer, weaponName, amount, ammoState)
	amount = tonumber(amount)
	if not amount or amount ~= amount or amount == math.huge or amount == -math.huge or amount <= 0 then
		return false
	end

	amount = math.floor(amount)

	if type(ammoState) ~= 'table' then
		xPlayer.showNotification(TranslateCap('unavailable'))
		return false
	end

	local maxAmmo = NormalizePositiveAmmoLimit(ammoState.maxAmmo)
	if not maxAmmo then
		xPlayer.showNotification(TranslateCap('unavailable'))
		return false
	end

	local currentAmmo = NormalizeAmmoCount(ammoState.currentAmmo)
	if not currentAmmo then
		xPlayer.showNotification(TranslateCap('unavailable'))
		return false
	end

	local serverAmmo = GetPlayerWeaponAmmo(source, xPlayer, weaponName)
	if serverAmmo and serverAmmo > currentAmmo then
		currentAmmo = serverAmmo
	end

	if currentAmmo >= maxAmmo or currentAmmo + amount > maxAmmo then
		xPlayer.showNotification(TranslateCap('ammo_full'))
		return false
	end

	return true
end

---Adds ammo to an owned weapon.
---@param xPlayer table ESX player object
---@param weaponName string
---@param amount number
---@return boolean
function AddWeaponAmmo(xPlayer, weaponName, amount)
	if Config.OxInventory or type(xPlayer.addWeaponAmmo) ~= 'function' then
		return false
	end

	local added = pcall(function()
		xPlayer.addWeaponAmmo(weaponName, amount)
	end)

	return added
end

---Checks whether a weapon component is already owned.
---@param xPlayer table ESX player object
---@param weaponName string
---@param componentName string
---@return boolean
function HasWeaponComponent(xPlayer, weaponName, componentName)
	if Config.OxInventory or type(xPlayer.hasWeaponComponent) ~= 'function' then
		return false
	end

	local checked, hasComponent = pcall(function()
		return xPlayer.hasWeaponComponent(weaponName, componentName)
	end)

	return checked and hasComponent == true
end

---Adds a component to an owned weapon.
---@param xPlayer table ESX player object
---@param weaponName string
---@param componentName string
---@return boolean
function AddWeaponComponent(xPlayer, weaponName, componentName)
	if Config.OxInventory or type(xPlayer.addWeaponComponent) ~= 'function' then
		return false
	end

	local added = pcall(function()
		xPlayer.addWeaponComponent(weaponName, componentName)
	end)

	return added
end

---Gets the current tint index for an owned weapon.
---@param xPlayer table ESX player object
---@param weaponName string
---@return number
function GetWeaponTint(xPlayer, weaponName)
	if Config.OxInventory or type(xPlayer.getWeaponTint) ~= 'function' then
		return 0
	end

	local checked, tintIndex = pcall(function()
		return xPlayer.getWeaponTint(weaponName)
	end)

	return checked and tonumber(tintIndex) or 0
end

---Sets a tint on an owned weapon.
---@param xPlayer table ESX player object
---@param weaponName string
---@param tintIndex number
---@return boolean
function SetWeaponTint(xPlayer, weaponName, tintIndex)
	if Config.OxInventory or type(xPlayer.setWeaponTint) ~= 'function' then
		return false
	end

	local set = pcall(function()
		xPlayer.setWeaponTint(weaponName, tintIndex)
	end)

	return set
end
