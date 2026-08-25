local currentShop = nil
local uiOpen = false

local function NormalizeUiInteger(value)
	value = tonumber(value)

	if not value or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	return math.floor(value)
end

local function GetInitialWeaponAmmo()
	return math.max(NormalizeUiInteger(Config.InitialWeaponAmmo) or 42, 0)
end

local function SyncBoughtWeaponToPed(weaponName)
	if Config.OxInventory then
		return
	end

	if type(weaponName) ~= 'string' or weaponName == '' then
		return
	end

	if type(GiveWeaponToPed) ~= 'function' then
		return
	end

	local ped = PlayerPedId()
	if not ped or ped == 0 then
		return
	end

	local weaponHash = joaat(weaponName)
	local initialAmmo = GetInitialWeaponAmmo()

	if HasPedGotWeapon(ped, weaponHash, false) then
		local currentAmmo = NormalizeUiInteger(GetAmmoInPedWeapon(ped, weaponHash)) or 0

		if currentAmmo < initialAmmo and type(SetPedAmmo) == 'function' then
			SetPedAmmo(ped, weaponHash, initialAmmo)
		end

		return
	end

	GiveWeaponToPed(ped, weaponHash, initialAmmo, false, false)
end

local function BuildBoughtWeaponState(weaponName)
	local ammo = GetInitialWeaponAmmo()
	local ped = PlayerPedId()

	if ped and ped ~= 0 then
		local weaponHash = joaat(weaponName)

		if HasPedGotWeapon(ped, weaponHash, false) then
			ammo = math.max(NormalizeUiInteger(GetAmmoInPedWeapon(ped, weaponHash)) or 0, ammo)
		end
	end

	return {
		owned = true,
		ammo = ammo,
		tintIndex = 0,
		components = {}
	}
end

local function ApplyItemStateOverrides(items, stateOverrides)
	if type(stateOverrides) ~= 'table' then
		return
	end

	for i = 1, #items do
		local item = items[i]
		local override = item and stateOverrides[item.name]

		if type(override) == 'table' then
			item.state = {
				owned = override.owned == true or item.state.owned == true,
				ammo = math.max(NormalizeUiInteger(override.ammo) or NormalizeUiInteger(item.state.ammo) or 0, 0),
				tintIndex = math.max(NormalizeUiInteger(override.tintIndex) or NormalizeUiInteger(item.state.tintIndex) or 0, 0),
				components = type(override.components) == 'table' and override.components or item.state.components or {}
			}
		end
	end
end

---Opens weaponshop NUI
---@param zone string Shop zone name
---@param mode string NUI mode (`shop` or `license`)
---@param selectedName string|nil Weapon selected after refresh
---@param stateOverrides table|nil Item state overrides applied before sending data to NUI
local function OpenNui(zone, mode, selectedName, stateOverrides)
	local items = BuildShopItems(zone)
	ApplyItemStateOverrides(items, stateOverrides)

	currentShop = zone
	uiOpen = true

	ESX.HideUI()
	SetNuiFocus(true, true)
	SendNUIMessage({
		type = 'openShop',
		shopData = {
			shopName = TranslateCap('shop_menu_title'),
			items = items,
			categories = BuildCategories(items),
			locales = GetShopLocales(),
			fallbackImage = GetWeaponShopFallbackImage(),
			legal = Config.Zones[zone].Legal,
			mode = mode,
			licensePrice = Config.LicensePrice,
			selectedName = selectedName
		}
	})
end

---Opens the weapon shop
---@param zone string Shop zone name
function OpenShop(zone)
	OpenNui(zone, 'shop')
end

---Opens the weapon license purchase view
---@param zone string Shop zone name
function OpenBuyLicenseMenu(zone)
	OpenNui(zone, 'license')
end

function CloseShop()
	SetNuiFocus(false, false)
	SendNUIMessage({ type = 'closeShop' })
	currentShop = nil
	uiOpen = false
end

---Gets current shop name
---@return string|nil
function GetCurrentShop()
	return currentShop
end

---Checks if UI is open
---@return boolean
function IsUIOpen()
	return uiOpen
end

-- NUI Ready Callback
RegisterNUICallback('ready', function(data, cb)
	cb({ theme = GetESXThemeColors() })
end)

-- Purchase callback
RegisterNUICallback('buyWeapon', function(data, cb)
	if type(data) ~= 'table' or type(data.weaponName) ~= 'string' or not currentShop then
		cb({ ok = false })
		return
	end

	local shop = currentShop

	ESX.TriggerServerCallback('esx_weaponshop:buyWeapon', function(bought)
		if bought then
			local price = GetZoneWeaponPrice(shop, data.weaponName)
			DisplayBoughtScaleform(data.weaponName, price)
			SyncBoughtWeaponToPed(data.weaponName)

			if currentShop == shop then
				OpenNui(shop, 'shop', data.weaponName, {
					[data.weaponName] = BuildBoughtWeaponState(data.weaponName)
				})
			end
		else
			PlaySoundFrontend(-1, 'ERROR', 'HUD_AMMO_SHOP_SOUNDSET', false)
		end

		cb({ ok = bought and true or false })
	end, data.weaponName, shop)
end)

-- Upgrade purchase callback
RegisterNUICallback('buyUpgrade', function(data, cb)
	if type(data) ~= 'table' or type(data.weaponName) ~= 'string' or type(data.action) ~= 'string' or not currentShop then
		cb({ ok = false })
		return
	end

	ESX.TriggerServerCallback('esx_weaponshop:buyUpgrade', function(bought)
		if bought then
			PlaySoundFrontend(-1, 'WEAPON_PURCHASE', 'HUD_AMMO_SHOP_SOUNDSET', false)
			ESX.ShowNotification(TranslateCap('upgrade_bought'))
			OpenNui(currentShop, 'shop', data.weaponName)
		else
			PlaySoundFrontend(-1, 'ERROR', 'HUD_AMMO_SHOP_SOUNDSET', false)
		end

		cb({ ok = bought and true or false })
	end, data, currentShop)
end)

-- License callback
RegisterNUICallback('buyLicense', function(_, cb)
	ESX.TriggerServerCallback('esx_weaponshop:buyLicense', function(bought)
		cb({ ok = bought and true or false })

		if bought and currentShop then
			OpenShop(currentShop)
		end
	end)
end)

-- Close UI callback
RegisterNUICallback('closeUI', function(data, cb)
	CloseShop()
	cb('ok')
end)
