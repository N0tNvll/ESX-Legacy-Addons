local shopBlips = {}

---Creates blips for all weaponshop locations
function CreateShopBlips()
	if not Config.Zones then
		return
	end

	for _, zoneData in pairs(Config.Zones) do
		local blipSettings = zoneData.Blip
		local locations = zoneData.Locations
		if blipSettings and blipSettings.Enabled and type(locations) == 'table' then
			local posCount = #locations

			for i = 1, posCount do
				local location = locations[i]
				local blip = AddBlipForCoord(location.x, location.y, location.z)

				SetBlipSprite(blip, blipSettings.Sprite)
				SetBlipDisplay(blip, blipSettings.Display)
				SetBlipScale(blip, blipSettings.Scale)
				SetBlipColour(blip, blipSettings.Color)
				SetBlipAsShortRange(blip, blipSettings.ShortRange)

				BeginTextCommandSetBlipName('STRING')
				AddTextComponentSubstringPlayerName(TranslateCap('map_blip'))
				EndTextCommandSetBlipName(blip)

				shopBlips[#shopBlips + 1] = blip
			end
		end
	end
end

---Removes all weaponshop blips
function RemoveShopBlips()
	for i = 1, #shopBlips do
		RemoveBlip(shopBlips[i])
	end
	shopBlips = {}
end

-- Initialize blips after resource start (ensures Config is fully loaded)
AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		CreateShopBlips()
	end
end)
