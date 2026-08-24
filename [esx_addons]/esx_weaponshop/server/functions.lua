---Validates player exists
---@param source number Player source
---@return table|nil xPlayer ESX player object or nil
function ValidatePlayer(source)
	local xPlayer = ESX.Player(source)
	if not xPlayer then
		return nil
	end
	return xPlayer
end

---Checks if player has required funds for the purchase
---@param xPlayer table ESX player object
---@param isBlackMarket boolean
---@param price number
---@return boolean
function CanPayForWeapon(xPlayer, isBlackMarket, price)
	if isBlackMarket then
		local account = xPlayer.getAccount('black_money')
		local balance = account and tonumber(account.money) or 0
		if balance < price then
			xPlayer.showNotification(TranslateCap('not_enough_black'))
			return false
		end

		return true
	end

	if (tonumber(xPlayer.getMoney()) or 0) < price then
		xPlayer.showNotification(TranslateCap('not_enough'))
		return false
	end

	return true
end

---Deducts purchase amount from the corresponding account
---@param xPlayer table ESX player object
---@param isBlackMarket boolean
---@param price number
---@return boolean
function TakeWeaponPayment(xPlayer, isBlackMarket, price)
	if isBlackMarket then
		if not xPlayer.getAccount('black_money') then
			return false
		end

		xPlayer.removeAccountMoney('black_money', price, 'Black Weapons Deal')
	else
		xPlayer.removeMoney(price, 'Weapons Deal')
	end

	return true
end

---Refunds a failed weapon purchase
---@param xPlayer table ESX player object
---@param isBlackMarket boolean
---@param price number
function RefundWeaponPayment(xPlayer, isBlackMarket, price)
	if isBlackMarket then
		xPlayer.addAccountMoney('black_money', price, 'Black Weapons Deal Refund')
	else
		xPlayer.addMoney(price, 'Weapons Deal Refund')
	end
end
