local nearbyZone = nil
local textShown = false

---Gets the nearby interactable weaponshop zone
---@return string|nil
function GetNearbyZone()
	return nearbyZone
end

---Draws markers and handles proximity detection
---@return number sleepTime
function DrawMarkersAndCheckProximity()
	local sleep = 1500
	local hasVisibleMarker = false
	local zoneInRange = nil
	local uiOpen = IsUIOpen()
	local ped = ESX.PlayerData and ESX.PlayerData.ped

	if not ped or ped == 0 then
		ped = PlayerPedId()
	end

	if not ped or ped == 0 then
		return sleep
	end

	local coords = GetEntityCoords(ped)
	local drawDistance = tonumber(Config.DrawDistance) or 10.0
	local interactionDistance = tonumber(Config.InteractionDistance) or 2.0

	for zoneName, zoneData in pairs(Config.Zones) do
		local locations = zoneData.Locations
		local posCount = type(locations) == 'table' and #locations or 0

		for i = 1, posCount do
			local location = locations[i]
			local distance = #(coords - location)

			if Config.Type ~= -1 and distance < drawDistance then
				hasVisibleMarker = true
				sleep = 0

				if distance < interactionDistance then
					zoneInRange = zoneName
				end

				DrawMarker(
					Config.Type,
					location.x, location.y, location.z,
					0.0, 0.0, 0.0,
					0.0, 0.0, 0.0,
					Config.Size.x, Config.Size.y, Config.Size.z,
					Config.Color.r, Config.Color.g, Config.Color.b, 100,
					false, true, 2, false, nil, nil, false
				)
			end
		end
	end

	if uiOpen then
		nearbyZone = nil
	elseif zoneInRange then
		if not textShown or nearbyZone ~= zoneInRange then
			ESX.TextUI(TranslateCap('shop_menu_prompt', Config.InteractionKeyLabel or 'E'))
			textShown = true
		end

		nearbyZone = zoneInRange
	else
		nearbyZone = nil
	end

	if (not zoneInRange or uiOpen) and textShown then
		textShown = false
		ESX.HideUI()
	end

	if not hasVisibleMarker and uiOpen then
		CloseShop()
		nearbyZone = nil
	end

	return sleep
end
