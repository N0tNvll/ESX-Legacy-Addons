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
		xPlayer.addWeapon(weaponName, 42)
	end)

	return added
end
