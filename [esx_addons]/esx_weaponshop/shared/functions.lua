---Gets ESX theme colors from convars (client-only)
---@return table Theme colors
function GetESXThemeColors()
	return {
		primaryColor = GetConvar('esx:ui:primaryColor', '#FB9B04'),
		secondaryColor = GetConvar('esx:ui:secondaryColor', '#1a1a1a'),
		backgroundColor = GetConvar('esx:ui:backgroundColor', '#0a0a0a'),
		accentColor = GetConvar('esx:ui:accentColor', '#ffffff'),
		logoUrl = GetConvar('esx:ui:logoUrl', '')
	}
end

---Safely gets an ESX weapon config without letting ESX.GetWeapon assertions bubble.
---@param weaponName any
---@return table|nil weapon
function GetWeaponConfig(weaponName)
	if type(weaponName) ~= 'string' or weaponName == '' then
		return nil
	end

	local ok, first, second = pcall(ESX.GetWeapon, weaponName)
	if not ok then
		return nil
	end

	if type(second) == 'table' then
		return second
	end

	return type(first) == 'table' and first or nil
end

---Checks whether weapon upgrades are usable with the active inventory backend.
---@return boolean supported
function AreWeaponShopUpgradesSupported()
	return Config.WeaponShopUpgrades and Config.WeaponShopUpgrades.Enabled == true and not Config.OxInventory
end

local function NormalizePositiveInteger(value)
	value = tonumber(value)

	if not value or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	value = math.floor(value)
	return value > 0 and value or nil
end

local function NormalizeInteger(value)
	value = tonumber(value)

	if not value or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	return math.floor(value)
end

local function NormalizeAmmoNativeResult(first, second)
	local ammo = NormalizePositiveInteger(second)
	if ammo then
		return ammo
	end

	if first ~= true and first ~= false then
		return NormalizePositiveInteger(first)
	end

	return nil
end

local function GetWeaponMaxAmmo(ped, weaponHash)
	if type(GetMaxAmmo) ~= 'function' then
		return nil
	end

	local checked, first, second = pcall(function()
		return GetMaxAmmo(ped, weaponHash)
	end)

	if not checked then
		return nil
	end

	return NormalizeAmmoNativeResult(first, second)
end

local function GetWeaponMaxAmmoByType(ped, weaponHash)
	if type(GetPedAmmoTypeFromWeapon) ~= 'function' or type(GetMaxAmmoByType) ~= 'function' then
		return nil
	end

	local typeChecked, ammoType = pcall(function()
		return GetPedAmmoTypeFromWeapon(ped, weaponHash)
	end)

	ammoType = typeChecked and NormalizeInteger(ammoType) or nil
	if not ammoType or ammoType == 0 then
		return nil
	end

	local checked, first, second = pcall(function()
		return GetMaxAmmoByType(ped, ammoType)
	end)

	if not checked then
		return nil
	end

	return NormalizeAmmoNativeResult(first, second)
end

local function GetPedWeaponMaxAmmo(ped, weaponName)
	if not ped or ped == 0 or type(weaponName) ~= 'string' then
		return nil
	end

	local weaponHash = joaat(weaponName)

	return GetWeaponMaxAmmo(ped, weaponHash) or GetWeaponMaxAmmoByType(ped, weaponHash)
end

---Gets the runtime ammo cap for a weapon from the current client ped when available.
---@param weaponName string
---@return number|nil maxAmmo
function GetWeaponShopAmmoLimit(weaponName)
	if IsDuplicityVersion() or type(PlayerPedId) ~= 'function' then
		return nil
	end

	return GetPedWeaponMaxAmmo(PlayerPedId(), weaponName)
end

---Converts a configured image value into a browser-safe URL.
---@param image string|nil
---@return string imageUrl
function GetWeaponShopImageUrl(image)
	if type(image) ~= 'string' or image == '' then
		return ''
	end

	local scheme = image:match('^(%a[%w+.-]*):')
	if scheme then
		scheme = scheme:lower()

		if scheme == 'http' or scheme == 'https' or scheme == 'nui' or scheme == 'data' then
			return image
		end

		return ''
	end

	image = image:gsub('^%./', ''):gsub('^/+', '')
	return ('nui://%s/%s'):format(GetCurrentResourceName(), image)
end

---Gets a configured image override for a weapon.
---@param weaponName string
---@return string|nil imageUrl
function GetWeaponShopCustomImage(weaponName)
	if type(weaponName) ~= 'string' or type(Config.WeaponImages) ~= 'table' then
		return nil
	end

	local image = Config.WeaponImages[weaponName] or Config.WeaponImages[weaponName:upper()]
	local imageUrl = GetWeaponShopImageUrl(image)

	return imageUrl ~= '' and imageUrl or nil
end

---Gets a browser-safe fallback image URL from config.
---@return string fallbackImage
function GetWeaponShopFallbackImage()
	return GetWeaponShopImageUrl(Config.FallbackWeaponImage)
end

local function GetComponentPrice(componentName, weaponName)
	local config = Config.WeaponShopUpgrades.Components or {}
	local byWeapon = config.WeaponPrices and config.WeaponPrices[weaponName]
	local price = byWeapon and byWeapon[componentName] or config.Prices and config.Prices[componentName] or config.DefaultPrice

	return tonumber(price) or 0
end

local function GetTintPrice(tintIndex, weaponName)
	local config = Config.WeaponShopUpgrades.Tints or {}
	local byWeapon = config.WeaponPrices and config.WeaponPrices[weaponName]
	local price = byWeapon and byWeapon[tintIndex] or config.Prices and config.Prices[tintIndex] or config.DefaultPrice

	return tonumber(price) or 0
end

local function GetTintSwatch(tintIndex)
	local config = Config.WeaponShopUpgrades.Tints or {}

	return config.Swatches and config.Swatches[tintIndex] or '#9A9A9A'
end

---Builds upgrade options for a weapon using ESX weapon metadata and local prices.
---@param weaponName string
---@return table upgrades
function BuildWeaponUpgrades(weaponName)
	local upgrades = {
		supported = AreWeaponShopUpgradesSupported(),
		ammo = nil,
		components = {},
		tints = {}
	}

	if not upgrades.supported then
		return upgrades
	end

	local weapon = GetWeaponConfig(weaponName)
	if not weapon then
		return upgrades
	end

	local upgradeConfig = Config.WeaponShopUpgrades
	local ammoConfig = upgradeConfig.Ammo or {}

	if ammoConfig.Enabled ~= false and type(weapon.ammo) == 'table' and not weapon.throwable then
		upgrades.ammo = {
			label = weapon.ammo.label or TranslateCap('upgrade_ammo'),
			pricePerRound = tonumber(ammoConfig.PricePerRound) or 0,
			defaultAmount = tonumber(ammoConfig.DefaultAmount) or 30,
			minAmount = tonumber(ammoConfig.MinAmount) or 1,
			maxAmount = tonumber(ammoConfig.MaxAmount) or 250,
			quickAmounts = ammoConfig.QuickAmounts or { 30, 60, 120 },
			maxAmmo = GetWeaponShopAmmoLimit(weaponName)
		}
	end

	local componentConfig = upgradeConfig.Components or {}
	if componentConfig.Enabled ~= false and type(weapon.components) == 'table' then
		for i = 1, #weapon.components do
			local component = weapon.components[i]
			local componentName = component and component.name

			if type(componentName) == 'string' and not (componentConfig.Blacklisted and componentConfig.Blacklisted[componentName]) then
				local price = GetComponentPrice(componentName, weaponName)
				if price > 0 then
					upgrades.components[#upgrades.components + 1] = {
						name = componentName,
						label = component.label or componentName,
						price = price
					}
				end
			end
		end
	end

	local tintConfig = upgradeConfig.Tints or {}
	if tintConfig.Enabled ~= false and type(weapon.tints) == 'table' then
		for fallbackIndex, tintData in pairs(weapon.tints) do
			local tintIndex = nil
			local tintLabel = nil

			if type(tintData) == 'table' then
				tintIndex = tonumber(tintData.tint or tintData.index)
				tintLabel = tintData.label or tintData.name
			else
				tintIndex = tonumber(fallbackIndex)
				tintLabel = tostring(tintData)
			end

			if tintIndex and tintIndex == math.floor(tintIndex) and type(tintLabel) == 'string' and tintLabel ~= '' then
				upgrades.tints[#upgrades.tints + 1] = {
					index = tintIndex,
					label = tintLabel,
					price = GetTintPrice(tintIndex, weaponName),
					color = GetTintSwatch(tintIndex)
				}
			end
		end

		table.sort(upgrades.tints, function(a, b)
			return a.index < b.index
		end)
	end

	return upgrades
end

---Finds a configured component upgrade option.
---@param weaponName string
---@param componentName string
---@return table|nil component
function GetWeaponShopComponentUpgrade(weaponName, componentName)
	local upgrades = BuildWeaponUpgrades(weaponName)

	for i = 1, #upgrades.components do
		if upgrades.components[i].name == componentName then
			return upgrades.components[i]
		end
	end

	return nil
end

---Finds a configured tint upgrade option.
---@param weaponName string
---@param tintIndex number
---@return table|nil tint
function GetWeaponShopTintUpgrade(weaponName, tintIndex)
	local upgrades = BuildWeaponUpgrades(weaponName)

	for i = 1, #upgrades.tints do
		if upgrades.tints[i].index == tintIndex then
			return upgrades.tints[i]
		end
	end

	return nil
end
