-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local MechanicJob = ESXMechanicJob
local PlayerWorkStates = MechanicJob.PlayerWorkStates
local workSessions = {}
local WORK_ACTION_DELAY = 4000
local WORK_ACTION_DISTANCE = 3.0
local WORK_ACTION_START_COOLDOWN = 1000
local WORK_ACTIONS = {
	harvest_gazbottle = {
		startEvent = 'esx_mechanicjob:startHarvest',
		stopEvent = 'esx_mechanicjob:stopHarvest',
		startNotification = 'recovery_gas_can',
		zone = 'Garage',
		mode = 'harvest',
		item = 'gazbottle',
		max = 5
	},
	harvest_fixtool = {
		startEvent = 'esx_mechanicjob:startHarvest2',
		stopEvent = 'esx_mechanicjob:stopHarvest2',
		startNotification = 'recovery_repair_tools',
		zone = 'Garage',
		mode = 'harvest',
		item = 'fixtool',
		max = 5
	},
	harvest_carotool = {
		startEvent = 'esx_mechanicjob:startHarvest3',
		stopEvent = 'esx_mechanicjob:stopHarvest3',
		startNotification = 'recovery_body_tools',
		zone = 'Garage',
		mode = 'harvest',
		item = 'carotool',
		max = 5
	},
	craft_blowpipe = {
		startEvent = 'esx_mechanicjob:startCraft',
		stopEvent = 'esx_mechanicjob:stopCraft',
		startNotification = 'assembling_blowtorch',
		zone = 'Craft',
		mode = 'craft',
		input = 'gazbottle',
		output = 'blowpipe',
		missingNotification = 'not_enough_gas_can'
	},
	craft_fixkit = {
		startEvent = 'esx_mechanicjob:startCraft2',
		stopEvent = 'esx_mechanicjob:stopCraft2',
		startNotification = 'assembling_repair_kit',
		zone = 'Craft',
		mode = 'craft',
		input = 'fixtool',
		output = 'fixkit',
		missingNotification = 'not_enough_repair_tools'
	},
	craft_carokit = {
		startEvent = 'esx_mechanicjob:startCraft3',
		stopEvent = 'esx_mechanicjob:stopCraft3',
		startNotification = 'assembling_body_kit',
		zone = 'Craft',
		mode = 'craft',
		input = 'carotool',
		output = 'carokit',
		missingNotification = 'not_enough_body_tools'
	}
}

local function isWorkshopActionActive(source, actionName, session)
	return PlayerWorkStates[source] == actionName and workSessions[source] == session
end

local function setWorkshopAction(source, actionName, active)
	if active then
		if PlayerWorkStates[source] then
			return false
		end

		PlayerWorkStates[source] = actionName
		workSessions[source] = {}
		return true
	end

	if PlayerWorkStates[source] ~= actionName then
		return false
	end

	PlayerWorkStates[source] = nil
	workSessions[source] = nil
	return true
end

local function hasCraftingMaterials(xPlayer, action)
	local item = xPlayer.getInventoryItem(action.input)
	return item and (item.count or 0) > 0
end

local function processWorkshopAction(source, actionName, session)
	local action = WORK_ACTIONS[actionName]
	if not action then
		return
	end

	SetTimeout(WORK_ACTION_DELAY, function()
		if not isWorkshopActionActive(source, actionName, session) then
			if workSessions[source] == session then
				workSessions[source] = nil
			end
			return
		end

		local xPlayer = MechanicJob.getWorkshopMechanicPlayer(source)
		if not xPlayer or xPlayer.getIdentifier() ~= session.identifier or not MechanicJob.isPlayerNearZone(source, action.zone, WORK_ACTION_DISTANCE) then
			setWorkshopAction(source, actionName, false)
			return
		end

		if action.mode == 'harvest' then
			local item = xPlayer.getInventoryItem(action.item)

			if not item or (item.count or 0) >= action.max then
				TriggerClientEvent('esx:showNotification', source, TranslateCap('you_do_not_room'))
				setWorkshopAction(source, actionName, false)
				return
			end

			if not xPlayer.canCarryItem(action.item, 1) or xPlayer.addInventoryItem(action.item, 1) ~= true then
				TriggerClientEvent('esx:showNotification', source, TranslateCap('you_do_not_room'))
				setWorkshopAction(source, actionName, false)
				return
			end
		elseif action.mode == 'craft' then
			if not hasCraftingMaterials(xPlayer, action) then
				TriggerClientEvent('esx:showNotification', source, TranslateCap(action.missingNotification))
				setWorkshopAction(source, actionName, false)
				return
			end

			if not xPlayer.canSwapItem(action.input, 1, action.output, 1) then
				TriggerClientEvent('esx:showNotification', source, TranslateCap('you_do_not_room'))
				setWorkshopAction(source, actionName, false)
				return
			end

			if xPlayer.removeInventoryItem(action.input, 1) ~= true then
				setWorkshopAction(source, actionName, false)
				return
			end

			if xPlayer.addInventoryItem(action.output, 1) ~= true then
				if xPlayer.addInventoryItem(action.input, 1) ~= true then
					print(('[esx_mechanicjob] Failed to restore %s for player %s'):format(action.input, source))
				end
				setWorkshopAction(source, actionName, false)
				return
			end
		else
			setWorkshopAction(source, actionName, false)
			return
		end

		processWorkshopAction(source, actionName, session)
	end)
end

local function startWorkshopAction(source, actionName)
	local action = WORK_ACTIONS[actionName]
	if not action or MechanicJob.rejectRateLimited(source, action.startEvent, WORK_ACTION_START_COOLDOWN) then
		return
	end

	local xPlayer = MechanicJob.getWorkshopMechanicPlayer(source)
	if not xPlayer then
		return
	end

	if not MechanicJob.isPlayerNearZone(source, action.zone, WORK_ACTION_DISTANCE) then
		return
	end

	if PlayerWorkStates[source] then
		return
	end

	if action.mode == 'craft' and not hasCraftingMaterials(xPlayer, action) then
		TriggerClientEvent('esx:showNotification', source, TranslateCap(action.missingNotification))
		return
	end

	if not setWorkshopAction(source, actionName, true) then
		return
	end
	local session = workSessions[source]
	session.identifier = xPlayer.getIdentifier()

	TriggerClientEvent('esx:showNotification', source, TranslateCap(action.startNotification))
	processWorkshopAction(source, actionName, session)
end

local function stopWorkshopAction(source, actionName)
	setWorkshopAction(source, actionName, false)
end

AddEventHandler('playerDropped', function()
	workSessions[source] = nil
end)

for actionName, action in pairs(WORK_ACTIONS) do
	local registeredActionName = actionName
	local startEvent = action.startEvent
	local stopEvent = action.stopEvent

	RegisterServerEvent(startEvent)
	AddEventHandler(startEvent, function()
		startWorkshopAction(source, registeredActionName)
	end)

	RegisterServerEvent(stopEvent)
	AddEventHandler(stopEvent, function()
		stopWorkshopAction(source, registeredActionName)
	end)
end
