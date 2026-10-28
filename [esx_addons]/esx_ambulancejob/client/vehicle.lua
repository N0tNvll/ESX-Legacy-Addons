-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local spawnedVehicles = {}

function OpenVehicleShopMenu(type, hospital, part, partNum)
	local playerCoords = GetEntityCoords(PlayerPedId())
	local elements = {
		{label = TranslateCap('garage_buyitem'), action = 'buy_vehicle'}
	}

	OpenAmbulanceMenu('default', 'vehicle_spawner', TranslateCap('garage_title'), elements, function(data, menu)
		if data.current.action == "buy_vehicle" then
			local shopElements = {}
			local authorizedVehicles = Config.AuthorizedVehicles[type][ESX.PlayerData.job.grade_name] 	
			local shopCoords = Config.Hospitals[hospital][part][partNum].InsideShop

			if #authorizedVehicles > 0 then
				for k,vehicle in ipairs(authorizedVehicles) do
					if IsModelInCdimage(vehicle.model) then
						local vehicleLabel = GetLabelText(GetDisplayNameFromVehicleModel(vehicle.model))

						shopElements[#shopElements+1] = {
							label = ('%s - <span style="color:green;">%s</span>'):format(vehicleLabel, TranslateCap('shop_item', ESX.Math.GroupDigits(vehicle.price))),
							name  = vehicleLabel,
							model = vehicle.model,
							price = vehicle.price,
							props = vehicle.props,
							type  = type
						}
					end
				end

				if #shopElements > 0 then
					OpenShopMenu(shopElements, playerCoords, shopCoords)
				else
					ESX.ShowNotification(TranslateCap('garage_notauthorized'))
				end
			else
				ESX.ShowNotification(TranslateCap('garage_notauthorized'))
			end
		end
	end, function(data, menu)
		menu.close()
	end)
end

function OpenShopMenu(elements, restoreCoords, shopCoords)
	local playerPed = PlayerPedId()
	isInShopMenu = true

	OpenAmbulanceMenu('default', 'vehicle_shop', TranslateCap('vehicleshop_title'), elements, function(data, menu)
		OpenAmbulanceMenu('default', 'vehicle_shop_confirm', data.current.name, {
			{label = 'View', value = 'view'}
		}, function(data2, menu2)
			if data2.current.value == 'view' then
				DeleteSpawnedVehicles()
				WaitForVehicleToLoad(data.current.model)

				xLib.game.spawnLocalVehicle(data.current.model, shopCoords.xyz, shopCoords.w, function(vehicle)
					table.insert(spawnedVehicles, vehicle)
					TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
					FreezeEntityPosition(vehicle, true)
					SetModelAsNoLongerNeeded(data.current.model)

					if data.current.props then
						xLib.game.setVehicleProperties(vehicle, data.current.props)
					end
				end)

				OpenAmbulanceMenu('default', 'vehicle_shop_buy', data.current.name, {
					{label = 'Buy', value = 'buy'},
					{label = 'Stop Viewing', value = 'stop'}
				}, function(data3, menu3)
					if data3.current.value == 'stop' then
						isInShopMenu = false
						menu3.close()

						DeleteSpawnedVehicles()
						FreezeEntityPosition(playerPed, false)
						SetEntityVisible(playerPed, true)

						xLib.entity.Teleport(playerPed, restoreCoords)
					elseif data3.current.value == 'buy' then
						local newPlate = exports['esx_vehicleshop']:GeneratePlate()
						local vehicle  = GetVehiclePedIsIn(playerPed, false)
						local props    = xLib.game.getVehicleProperties(vehicle)
						props.plate    = newPlate

                        PaymentGateway.Pay(
                            {
                                amount = data.current.price,
                                title = data.current.name,
                            },
                            'esx_ambulancejob:buyJobVehicle',
                            function (bought, paymentFailure)
							if bought then
								ESX.ShowNotification(TranslateCap('vehicleshop_bought', data.current.name, ESX.Math.GroupDigits(data.current.price)))

								isInShopMenu = false
								menu3.close()
								menu2.close()
								menu.close()
								DeleteSpawnedVehicles()
								FreezeEntityPosition(playerPed, false)
								SetEntityVisible(playerPed, true)

								xLib.entity.Teleport(playerPed, restoreCoords)
							else
                                PaymentGateway.NotifyFailure(
                                    paymentFailure,
                                    TranslateCap('vehicleshop_money'))
								menu3.close()
							end
						end, props, data.current.type)
					end
				end, function(data3, menu3)
					isInShopMenu = false
					menu3.close()

					DeleteSpawnedVehicles()
					FreezeEntityPosition(playerPed, false)
					SetEntityVisible(playerPed, true)

					xLib.entity.Teleport(playerPed, restoreCoords)
				end)
			end
		end, function(data2, menu2)
			menu2.close()
		end)
	end, function(data, menu)
		isInShopMenu = false
		menu.close()
	end)
end

CreateThread(function()
	while true do
		sleep = 1500

		if isInShopMenu then
			sleep = 0
			DisableControlAction(0, 75, true)  -- Disable exit vehicle
			DisableControlAction(27, 75, true) -- Disable exit vehicle
		end
		Wait(sleep)
	end
end)

function DeleteSpawnedVehicles()
	while #spawnedVehicles > 0 do
		local vehicle = spawnedVehicles[1]
		xLib.game.deleteVehicle(vehicle)
		table.remove(spawnedVehicles, 1)
	end
end

function WaitForVehicleToLoad(modelHash)
	xLib.streaming.requestModelWithSpinner(modelHash, TranslateCap('vehicleshop_awaiting_model'))
end
