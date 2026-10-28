-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local HasAlreadyEnteredMarker = false
local LastZone                = nil

CurrentAction     = nil
CurrentActionMsg  = ''
CurrentActionData = {}

-- Key controls
CreateThread(function()
	while true do
		Wait(0)

		if CurrentAction then
			if IsControlJustReleased(0, 38) then
				if CurrentAction == 'boat_shop' then
					if not Config.LicenseEnable then
						OpenBoatShop(Config.Zones.BoatShops[CurrentActionData.zoneNum])
					else -- check for license

						xLib.callback('esx_license:checkLicense', false, function(hasBoatLicense)
							if hasBoatLicense then
								OpenBoatShop(Config.Zones.BoatShops[CurrentActionData.zoneNum])
							else
								OpenLicenceMenu(Config.Zones.BoatShops[CurrentActionData.zoneNum])
							end
						end, GetPlayerServerId(PlayerId()), 'boat')
					end
				end

				CurrentAction = nil
				ESX.HideUI()
			end
		else
			Wait(500)
		end
	end
end)

AddEventHandler('esx_boat:hasEnteredMarker', function(zone, zoneNum)
	if zone == 'boat_shop' then
		CurrentAction     = 'boat_shop'
		CurrentActionMsg  = TranslateCap('boat_shop_open')
		CurrentActionData = { zoneNum = zoneNum }
	end
	ESX.TextUI(CurrentActionMsg)
end)

AddEventHandler('esx_boat:hasExitedMarker', function()
	if not isInShopMenu then
		ESX.CloseContext()
	end

	CurrentAction = nil
	ESX.HideUI()
end)

-- Enter / Exit marker events
CreateThread(function()
	while true do
		Wait(0)

		local playerPed = PlayerPedId()
		local coords = GetEntityCoords(playerPed)
		local isInMarker, hasExited, letSleep = false, false, true
		local currentZone, currentZoneNum

		for i=1, #Config.Zones.BoatShops, 1 do
			local distance = #(coords - Config.Zones.BoatShops[i].Outside)

			if distance < Config.DrawDistance then
				DrawMarker(Config.MarkerType, Config.Zones.BoatShops[i].Outside, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.Marker.x, Config.Marker.y, Config.Marker.z, Config.Marker.r, Config.Marker.g, Config.Marker.b, 100, false, true, 2, false, nil, nil, false)
				letSleep = false
			end

			if distance < Config.Marker.x then
				isInMarker     = true
				currentZone    = 'boat_shop'
				currentZoneNum = i
			end
		end

		if isInMarker and not HasAlreadyEnteredMarker or (isInMarker and (LastZone ~= currentZone or LastZoneNum ~= currentZoneNum)) then
			if
				(LastZone ~= nil and LastZoneNum ~= nil) and
				(LastZone ~= currentZone or LastZoneNum ~= currentZoneNum)
			then
				TriggerEvent('esx_boat:hasExitedMarker', LastZone)
				hasExited = true
			end

			HasAlreadyEnteredMarker = true
			LastZone = currentZone
			LastZoneNum = currentZoneNum

			TriggerEvent('esx_boat:hasEnteredMarker', currentZone, currentZoneNum)
		end

		if not hasExited and not isInMarker and HasAlreadyEnteredMarker then
			HasAlreadyEnteredMarker = false
			TriggerEvent('esx_boat:hasExitedMarker')
		end

		if letSleep then
			Wait(500)
		end
	end
end)

-- Blips
CreateThread(function()
	local blipList = {}

	for i=1, #Config.Zones.BoatShops, 1 do
		table.insert(blipList, {
			coords = Config.Zones.BoatShops[i].Outside,
			text   = TranslateCap('blip_shop'),
			sprite = 427,
			color  = 3,
			scale  = 1.0
		})
	end

	for i=1, #blipList, 1 do
		CreateBlip(blipList[i].coords, blipList[i].text, blipList[i].sprite, blipList[i].color, blipList[i].scale)
	end
end)

function CreateBlip(coords, text, sprite, color, scale)
	return xLib.blips.create({
		coords = coords,
		sprite = sprite,
		scale = scale,
		color = color,
		shortRange = true,
		label = text
	})
end
