local Jobs = setmetatable({}, {
	__index = function(_, key)
		return ESX.GetJobs()[key]
	end
})

local RegisteredSocieties = {}
local SocietiesByName = {}

local DEFAULT_UNEMPLOYED_JOB = 'unemployed'
local DEFAULT_UNEMPLOYED_GRADE = 0

function GetSociety(name)
	return SocietiesByName[name]
end

exports('GetSociety', GetSociety)

local function getXPlayer(source)
	local xPlayer = ESX.Player(source)

	if not xPlayer then
		print(('[^3WARNING^7] Invalid xPlayer for source ^5%s^7!'):format(source))
		return nil
	end

	return xPlayer
end

local function isBossJob(jobData)
	return jobData and Config.BossGrades[jobData.grade_name] == true
end

local function parsePositiveAmount(amount)
	amount = tonumber(amount)

	if not amount then
		return nil
	end

	if amount ~= amount then
		return nil
	end

	amount = ESX.Math.Round(amount)

	if amount <= 0 then
		return nil
	end

	return amount
end

local function canAccessSociety(source, societyName, requireBoss)
	local society = GetSociety(societyName)

	if not society then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to access non-existing society - ^5%s^7!'):format(source, societyName))
		return false, nil, nil
	end

	local xPlayer = getXPlayer(source)
	if not xPlayer then
		return false, nil, nil
	end

	local xPlayerJob = xPlayer.getJob()

	if not xPlayerJob or xPlayerJob.name ~= society.name then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to access different society - ^5%s^7!'):format(source, society.name))
		return false, society, xPlayer
	end

	if requireBoss and not isBossJob(xPlayerJob) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted boss society action without boss grade - ^5%s^7!'):format(source, society.name))
		return false, society, xPlayer
	end

	return true, society, xPlayer
end

local function normalizePlate(plate)
	if type(plate) ~= 'string' then
		return nil
	end

	plate = plate:gsub('^%s*(.-)%s*$', '%1')
	plate = plate:upper()

	if plate == '' then
		return nil
	end

	return plate
end

local function getVehiclePlate(vehicle)
	if type(vehicle) ~= 'table' then
		return nil
	end

	return normalizePlate(vehicle.plate)
end

local function findVehicleIndexByPlate(garage, plate)
	for i = 1, #garage do
		local garagePlate = getVehiclePlate(garage[i])

		if garagePlate == plate then
			return i
		end
	end

	return nil
end

local function isValidJobGrade(job, grade)
	grade = tonumber(grade)

	if not grade then
		return false
	end

	grade = ESX.Math.Round(grade)

	if not Jobs[job] then
		return false
	end

	if not Jobs[job].grades or not Jobs[job].grades[tostring(grade)] then
		return false
	end

	return true, grade
end

function registerSociety(name, label, account, datastore, inventory, data)
	if SocietiesByName[name] then
		print(('[^3WARNING^7] society already registered, name: ^5%s^7'):format(name))
		return
	end

	local society = {
		name = name,
		label = label,
		account = account,
		datastore = datastore,
		inventory = inventory,
		data = data
	}

	SocietiesByName[name] = society
	table.insert(RegisteredSocieties, society)
end

AddEventHandler('esx_society:registerSociety', registerSociety)
exports('registerSociety', registerSociety)

AddEventHandler('esx_society:getSocieties', function(cb)
	cb(RegisteredSocieties)
end)

AddEventHandler('esx_society:getSociety', function(name, cb)
	cb(GetSociety(name))
end)

RegisterServerEvent('esx_society:checkSocietyBalance')
AddEventHandler('esx_society:checkSocietyBalance', function(societyName)
	local source = source
	local allowed, society, xPlayer = canAccessSociety(source, societyName, false)

	if not allowed then
		return
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
		if not account then
			print(('[^3WARNING^7] Society account not found for ^5%s^7!'):format(society.name))
			return
		end

		TriggerClientEvent('esx:showNotification', xPlayer.src, TranslateCap('check_balance', ESX.Math.GroupDigits(account.money or 0)))
	end)
end)

RegisterServerEvent('esx_society:withdrawMoney')
AddEventHandler('esx_society:withdrawMoney', function(societyName, amount)
	local source = source
	local allowed, society, xPlayer = canAccessSociety(source, societyName, true)

	if not allowed then
		return
	end

	amount = parsePositiveAmount(amount)

	if not amount then
		xPlayer.showNotification(TranslateCap('invalid_amount'))
		return
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
		if not account then
			print(('[^3WARNING^7] Society account not found for ^5%s^7!'):format(society.name))
			return
		end

		if account.money >= amount then
			account.removeMoney(amount)
			xPlayer.addMoney(amount, TranslateCap('money_add_reason'))
			xPlayer.showNotification(TranslateCap('have_withdrawn', ESX.Math.GroupDigits(amount)))
		else
			xPlayer.showNotification(TranslateCap('invalid_amount'))
		end
	end)
end)

RegisterServerEvent('esx_society:depositMoney')
AddEventHandler('esx_society:depositMoney', function(societyName, amount)
	local source = source
	local allowed, society, xPlayer = canAccessSociety(source, societyName, false)

	if not allowed then
		return
	end

	amount = parsePositiveAmount(amount)

	if not amount then
		xPlayer.showNotification(TranslateCap('invalid_amount'))
		return
	end

	if xPlayer.getMoney() < amount then
		xPlayer.showNotification(TranslateCap('invalid_amount'))
		return
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
		if not account then
			print(('[^3WARNING^7] Society account not found for ^5%s^7!'):format(society.name))
			return
		end

		xPlayer.removeMoney(amount, TranslateCap('money_remove_reason'))
		account.addMoney(amount)
		xPlayer.showNotification(TranslateCap('have_deposited', ESX.Math.GroupDigits(amount)))
	end)
end)

RegisterServerEvent('esx_society:washMoney')
AddEventHandler('esx_society:washMoney', function(societyName, amount)
	local source = source
	local allowed, society, xPlayer = canAccessSociety(source, societyName, false)

	if not allowed then
		return
	end

	amount = parsePositiveAmount(amount)

	if not amount then
		xPlayer.showNotification(TranslateCap('invalid_amount'))
		return
	end

	local account = xPlayer.getAccount('black_money')

	if not account or account.money < amount then
		xPlayer.showNotification(TranslateCap('invalid_amount'))
		return
	end

	xPlayer.removeAccountMoney('black_money', amount, 'Washing')

	MySQL.insert('INSERT INTO society_moneywash (identifier, society, amount) VALUES (?, ?, ?)', {
		xPlayer.getIdentifier(),
		society.name,
		amount
	}, function()
		xPlayer.showNotification(TranslateCap('you_have', ESX.Math.GroupDigits(amount)))
	end)
end)

RegisterServerEvent('esx_society:putVehicleInGarage')
AddEventHandler('esx_society:putVehicleInGarage', function(societyName, vehicle)
	local source = source
	local allowed, society = canAccessSociety(source, societyName, false)

	if not allowed then
		return
	end

	local plate = getVehiclePlate(vehicle)

	if not plate then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to put invalid vehicle in garage - ^5%s^7!'):format(source, societyName))
		return
	end

	vehicle.plate = plate

	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		if not store then
			print(('[^3WARNING^7] Datastore not found for society garage - ^5%s^7!'):format(society.name))
			return
		end

		local garage = store.get('garage') or {}

		if findVehicleIndexByPlate(garage, plate) then
			print(('[^3WARNING^7] Player ^5%s^7 attempted to insert duplicate vehicle plate - ^5%s^7!'):format(source, plate))
			return
		end

		table.insert(garage, vehicle)
		store.set('garage', garage)
	end)
end)

RegisterServerEvent('esx_society:removeVehicleFromGarage')
AddEventHandler('esx_society:removeVehicleFromGarage', function(societyName, vehicle)
	local source = source
	local allowed, society = canAccessSociety(source, societyName, false)

	if not allowed then
		return
	end

	local plate = getVehiclePlate(vehicle)

	if not plate then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to remove invalid vehicle from garage - ^5%s^7!'):format(source, societyName))
		return
	end

	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		if not store then
			print(('[^3WARNING^7] Datastore not found for society garage - ^5%s^7!'):format(society.name))
			return
		end

		local garage = store.get('garage') or {}
		local index = findVehicleIndexByPlate(garage, plate)

		if not index then
			print(('[^3WARNING^7] Player ^5%s^7 attempted to remove non-existing vehicle plate - ^5%s^7!'):format(source, plate))
			return
		end

		table.remove(garage, index)
		store.set('garage', garage)
	end)
end)

ESX.RegisterServerCallback('esx_society:getSocietyMoney', function(source, cb, societyName)
	local allowed, society = canAccessSociety(source, societyName, true)

	if not allowed then
		return cb(0)
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
		if not account then
			print(('[^3WARNING^7] Society account not found for ^5%s^7!'):format(society.name))
			return cb(0)
		end

		cb(account.money or 0)
	end)
end)

ESX.RegisterServerCallback('esx_society:getEmployees', function(source, cb, societyName)
	local allowed, society = canAccessSociety(source, societyName, true)

	if not allowed then
		return cb({})
	end

	local employees = {}
	local xPlayers = ESX.ExtendedPlayers('job', society.name)

	for i = 1, #xPlayers do
		local xPlayer = xPlayers[i]

		local name = xPlayer.getName()
		if Config.EnableESXIdentity and name == GetPlayerName(xPlayer.src) then
			name = xPlayer.get('firstName') .. ' ' .. xPlayer.get('lastName')
		end

		local job = xPlayer.getJob()

		table.insert(employees, {
			name = name,
			identifier = xPlayer.getIdentifier(),
			job = {
				name = society.name,
				label = job.label,
				grade = job.grade,
				grade_name = job.grade_name,
				grade_label = job.grade_label
			}
		})
	end

	local query = 'SELECT identifier, job_grade FROM `users` WHERE `job` = ? ORDER BY job_grade DESC'

	if Config.EnableESXIdentity then
		query = 'SELECT identifier, job_grade, firstname, lastname FROM `users` WHERE `job` = ? ORDER BY job_grade DESC'
	end

	MySQL.query(query, { society.name }, function(result)
		for _, row in pairs(result) do
			local alreadyInTable = false
			local identifier = row.identifier

			for _, v in pairs(employees) do
				if v.identifier == identifier then
					alreadyInTable = true
					break
				end
			end

			if not alreadyInTable then
				local name = TranslateCap('name_not_found')

				if Config.EnableESXIdentity then
					name = (row.firstname or '') .. ' ' .. (row.lastname or '')
				end

				local jobData = Jobs[society.name]
				local gradeData = jobData and jobData.grades and jobData.grades[tostring(row.job_grade)]

				if jobData and gradeData then
					table.insert(employees, {
						name = name,
						identifier = identifier,
						job = {
							name = society.name,
							label = jobData.label,
							grade = row.job_grade,
							grade_name = gradeData.name,
							grade_label = gradeData.label
						}
					})
				end
			end
		end

		cb(employees)
	end)
end)

ESX.RegisterServerCallback('esx_society:getJob', function(source, cb, societyName)
	local allowed = canAccessSociety(source, societyName, true)

	if not allowed then
		return cb(false)
	end

	if not Jobs[societyName] then
		return cb(false)
	end

	local job = json.decode(json.encode(Jobs[societyName]))
	local grades = {}

	for _, v in pairs(job.grades) do
		table.insert(grades, v)
	end

	table.sort(grades, function(a, b)
		return a.grade < b.grade
	end)

	job.grades = grades

	cb(job)
end)

ESX.RegisterServerCallback('esx_society:setJob', function(source, cb, identifier, job, grade, actionType)
	local xPlayer = getXPlayer(source)

	if not xPlayer then
		return cb()
	end

	local xPlayerJob = xPlayer.getJob()

	if not isBossJob(xPlayerJob) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJob for identifier ^5%s^7 without boss grade!'):format(source, identifier))
		return cb()
	end

	if type(identifier) ~= 'string' or identifier == '' then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJob with invalid identifier!'):format(source))
		return cb()
	end

	if identifier == xPlayer.getIdentifier() then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJob himself!'):format(source))
		return cb()
	end

	if actionType ~= 'hire' and actionType ~= 'promote' and actionType ~= 'fire' then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJob with invalid actionType - ^5%s^7!'):format(source, actionType))
		return cb()
	end

	local targetJob = xPlayerJob.name
	local targetGrade = tonumber(grade)

	if actionType == 'fire' then
		targetJob = DEFAULT_UNEMPLOYED_JOB
		targetGrade = DEFAULT_UNEMPLOYED_GRADE
	end

	local validGrade
	validGrade, targetGrade = isValidJobGrade(targetJob, targetGrade)

	if not validGrade then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJob with invalid job/grade: ^5%s/%s^7!'):format(source, targetJob, tostring(targetGrade)))
		return cb()
	end

	local xTarget = ESX.Player(identifier)

	if xTarget then
		local xTargetJobBefore = xTarget.getJob()

		if actionType ~= 'hire' and xTargetJobBefore.name ~= xPlayerJob.name then
			print(('[^3WARNING^7] Player ^5%s^7 attempted to %s player from different job - ^5%s^7!'):format(source, actionType, identifier))
			return cb()
		end

		xTarget.setJob(targetJob, targetGrade)

		local xTargetName = xTarget.getName()
		local xTargetJobAfter = xTarget.getJob()

		if actionType == 'hire' then
			xTarget.showNotification(TranslateCap('you_have_been_hired', targetJob))
			xPlayer.showNotification(TranslateCap('you_have_hired', xTargetName))
		elseif actionType == 'promote' then
			xTarget.showNotification(TranslateCap('you_have_been_promoted'))
			xPlayer.showNotification(TranslateCap('you_have_promoted', xTargetName, xTargetJobAfter.grade_label))
		elseif actionType == 'fire' then
			xTarget.showNotification(TranslateCap('you_have_been_fired', xTargetJobBefore.label))
			xPlayer.showNotification(TranslateCap('you_have_fired', xTargetName))
		end

		return cb()
	end

	if actionType == 'hire' then
		MySQL.update('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', {
			targetJob,
			targetGrade,
			identifier
		}, function()
			cb()
		end)

		return
	end

	MySQL.query('SELECT job FROM users WHERE identifier = ? LIMIT 1', { identifier }, function(result)
		local row = result and result[1]

		if not row then
			print(('[^3WARNING^7] Player ^5%s^7 attempted to setJob for unknown identifier ^5%s^7!'):format(source, identifier))
			return cb()
		end

		if row.job ~= xPlayerJob.name then
			print(('[^3WARNING^7] Player ^5%s^7 attempted to %s offline player from different job - ^5%s^7!'):format(source, actionType, identifier))
			return cb()
		end

		MySQL.update('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', {
			targetJob,
			targetGrade,
			identifier
		}, function()
			cb()
		end)
	end)
end)

ESX.RegisterServerCallback('esx_society:setJobSalary', function(source, cb, job, grade, salary)
	local xPlayer = getXPlayer(source)

	if not xPlayer then
		return cb()
	end

	local xPlayerJob = xPlayer.getJob()

	if xPlayerJob.name ~= job or not isBossJob(xPlayerJob) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobSalary for ^5%s^7!'):format(source, job))
		return cb()
	end

	local validGrade
	validGrade, grade = isValidJobGrade(job, grade)

	if not validGrade then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobSalary with invalid grade for ^5%s^7!'):format(source, job))
		return cb()
	end

	salary = tonumber(salary)

	if not salary then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobSalary with invalid salary for ^5%s^7!'):format(source, job))
		return cb()
	end

	salary = ESX.Math.Round(salary)

	if salary < 0 or salary > Config.MaxSalary then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobSalary outside config limits for ^5%s^7!'):format(source, job))
		return cb()
	end

	MySQL.update('UPDATE job_grades SET salary = ? WHERE job_name = ? AND grade = ?', {
		salary,
		job,
		grade
	}, function()
		Jobs[job].grades[tostring(grade)].salary = salary
		ESX.RefreshJobs()
		Wait(1)

		local xPlayers = ESX.ExtendedPlayers('job', job)

		for _, xTarget in pairs(xPlayers) do
			if xTarget.getJob().grade == grade then
				xTarget.setJob(job, grade)
			end
		end

		cb()
	end)
end)

ESX.RegisterServerCallback('esx_society:setJobLabel', function(source, cb, job, grade, label)
	local xPlayer = getXPlayer(source)

	if not xPlayer then
		return cb()
	end

	local xPlayerJob = xPlayer.getJob()

	if xPlayerJob.name ~= job or not isBossJob(xPlayerJob) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobLabel for ^5%s^7!'):format(source, job))
		return cb()
	end

	local validGrade
	validGrade, grade = isValidJobGrade(job, grade)

	if not validGrade then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobLabel with invalid grade for ^5%s^7!'):format(source, job))
		return cb()
	end

	if type(label) ~= 'string' then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobLabel with invalid label for ^5%s^7!'):format(source, job))
		return cb()
	end

	label = label:gsub('^%s*(.-)%s*$', '%1')

	if label == '' or #label > 50 then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobLabel with invalid label length for ^5%s^7!'):format(source, job))
		return cb()
	end

	MySQL.update('UPDATE job_grades SET label = ? WHERE job_name = ? AND grade = ?', {
		label,
		job,
		grade
	}, function()
		Jobs[job].grades[tostring(grade)].label = label
		ESX.RefreshJobs()
		Wait(1)

		local xPlayers = ESX.ExtendedPlayers('job', job)

		for _, xTarget in pairs(xPlayers) do
			if xTarget.getJob().grade == grade then
				xTarget.setJob(job, grade)
			end
		end

		cb()
	end)
end)

local getOnlinePlayers, onlinePlayers = false, nil

ESX.RegisterServerCallback('esx_society:getOnlinePlayers', function(source, cb)
	local xPlayer = getXPlayer(source)

	if not xPlayer then
		return cb({})
	end

	if not isBossJob(xPlayer.getJob()) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to get online players without boss grade!'):format(source))
		return cb({})
	end

	if getOnlinePlayers == false and onlinePlayers == nil then
		getOnlinePlayers, onlinePlayers = true, {}

		local xPlayers = ESX.ExtendedPlayers()

		for _, xTarget in pairs(xPlayers) do
			table.insert(onlinePlayers, {
				source = xTarget.src,
				identifier = xTarget.getIdentifier(),
				name = xTarget.getName(),
				job = xTarget.getJob()
			})
		end

		cb(onlinePlayers)

		getOnlinePlayers = false
		Wait(1000)
		onlinePlayers = nil
		return
	end

	while getOnlinePlayers do
		Wait(0)
	end

	cb(onlinePlayers or {})
end)

ESX.RegisterServerCallback('esx_society:getVehiclesInGarage', function(source, cb, societyName)
	local allowed, society = canAccessSociety(source, societyName, false)

	if not allowed then
		return cb({})
	end

	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		if not store then
			print(('[^3WARNING^7] Datastore not found for society garage - ^5%s^7!'):format(society.name))
			return cb({})
		end

		local garage = store.get('garage') or {}
		cb(garage)
	end)
end)

ESX.RegisterServerCallback('esx_society:isBoss', function(source, cb, job)
	cb(isPlayerBoss(source, job))
end)

function isPlayerBoss(playerId, job)
	local xPlayer = ESX.Player(playerId)

	if not xPlayer then
		return false
	end

	local society = GetSociety(job)

	if not society then
		print(('esx_society: player %s attempted boss check for invalid society %s!'):format(playerId, job))
		return false
	end

	local xPlayerJob = xPlayer.getJob()

	if xPlayerJob.name == society.name and isBossJob(xPlayerJob) then
		return true
	end

	print(('esx_society: %s attempted open a society boss menu!'):format(xPlayer.getIdentifier()))
	return false
end

function WashMoneyCRON(d, h, m)
	MySQL.query('SELECT * FROM society_moneywash', function(result)
		for i = 1, #result do
			local row = result[i]
			local society = GetSociety(row.society)

			if not society then
				print(('[^3WARNING^7] Invalid society in moneywash table - ^5%s^7!'):format(row.society))
			else
				local amount = tonumber(row.amount)

				if amount and amount > 0 then
					TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
						if account then
							account.addMoney(amount)
						else
							print(('[^3WARNING^7] Society account not found while washing money - ^5%s^7!'):format(society.name))
						end
					end)

					local xPlayer = ESX.Player(row.identifier)

					if xPlayer then
						xPlayer.showNotification(TranslateCap('you_have_laundered', ESX.Math.GroupDigits(amount)))
					end
				else
					print(('[^3WARNING^7] Invalid moneywash amount for identifier ^5%s^7!'):format(row.identifier))
				end
			end
		end

		MySQL.update('DELETE FROM society_moneywash')
	end)
end

TriggerEvent('cron:runAt', 3, 0, WashMoneyCRON)