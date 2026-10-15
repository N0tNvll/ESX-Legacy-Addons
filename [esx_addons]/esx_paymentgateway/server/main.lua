local ESX = exports.es_extended:getSharedObject()

--- Payment methods a request may use.
local VALID_METHODS <const> = { cash = true, card = true }

--- Used when a request has no (valid) methods.
local DEFAULT_METHODS <const> = { "cash", "card" }
local DEFAULT_ALLOWED <const> = { cash = true, card = true }

--- Maps a payment method to its ESX account.
local METHOD_ACCOUNT <const> = { cash = "money", card = "bank" }

---@class PaymentRequest
---@field amount integer
---@field currency string
---@field title string
---@field description? string
---@field methods string[] Methods shown in the UI
---@field allowed table<string, boolean> Same methods as a set, used for server-side checks
---@field resultEvent? string Server event fired with (playerId, success, method, request)

--- Open payments, indexed by player id (max one per player).
---@type table<number, PaymentRequest>
local PendingPayments = {}

--- Closes a pending payment, notifies the client and fires the requester's result event.
--- Everything here is synchronous, as required for net event logic.
---@param playerId number
---@param success boolean
---@param message string
---@param method? string
local function finish(playerId, success, message, method)
    local request = PendingPayments[playerId]
    PendingPayments[playerId] = nil

    TriggerClientEvent("esx_paymentgateway:result", playerId, { success = success, message = message })

    if request and request.resultEvent then
        TriggerEvent(request.resultEvent, playerId, success, method, request)
    end
end

--- Opens a payment selector for a player.
---@param playerId number
---@param request { amount: integer, title: string, description?: string, currency?: string, methods?: string[], resultEvent?: string }
---@return boolean success
---@return string? error
exports("RequestPayment", function(playerId, request)
    local player = ESX.GetPlayerFromId(playerId)
    if not player then return false, "Player is not available." end
    if PendingPayments[playerId] then return false, "The player already has a payment open." end

    if type(request) ~= "table" or type(request.amount) ~= "number" or request.amount < 1 or request.amount ~= math.floor(request.amount) then
        return false, "Amount must be a positive whole number."
    end

    if type(request.title) ~= "string" or request.title == "" then
        return false, "A payment title is required."
    end

    -- Keep only known methods: a list for the UI and a set for server-side checks.
    local methods, allowed = {}, {}
    for _, method in ipairs(type(request.methods) == "table" and request.methods or DEFAULT_METHODS) do
        if VALID_METHODS[method] and not allowed[method] then
            allowed[method] = true
            methods[#methods + 1] = method
        end
    end

    if #methods == 0 then
        methods, allowed = DEFAULT_METHODS, DEFAULT_ALLOWED
    end

    local paymentRequest = {
        amount = request.amount,
        currency = type(request.currency) == "string" and request.currency or "$",
        title = request.title,
        description = type(request.description) == "string" and request.description or nil,
        methods = methods,
        allowed = allowed,
        resultEvent = type(request.resultEvent) == "string" and request.resultEvent or nil,
    }

    PendingPayments[playerId] = paymentRequest

    local bank = player.getAccount("bank")
    TriggerClientEvent("esx_paymentgateway:open", playerId, {
        amount = paymentRequest.amount,
        currency = paymentRequest.currency,
        title = paymentRequest.title,
        description = paymentRequest.description,
        methods = methods,
        cashBalance = player.getMoney(),
        bankBalance = bank and bank.money or 0,
    })

    return true
end)

RegisterNetEvent("esx_paymentgateway:selectMethod", function(method)
    local playerId = source
    local request = PendingPayments[playerId]
    local player = ESX.GetPlayerFromId(playerId)
    local message = "No payment is open."

    if request and player then
        -- The client is untrusted: only a method this request allows is accepted.
        local account = type(method) == "string" and request.allowed[method] and player.getAccount(METHOD_ACCOUNT[method])
        message = "That payment method is unavailable."

        if account then
            message = "You do not have enough money for this payment."

            if account.money >= request.amount then
                player.removeAccountMoney(METHOD_ACCOUNT[method], request.amount)
                return finish(playerId, true, "Payment complete.", method)
            end
        end
    end

    -- The payment stays open (if any) so the player can pick another method.
    TriggerClientEvent("esx_paymentgateway:result", playerId, { success = false, message = message })
end)

RegisterNetEvent("esx_paymentgateway:cancel", function()
    if PendingPayments[source] then
        finish(source, false, "Payment cancelled.")
    end
end)

AddEventHandler("playerDropped", function()
    PendingPayments[source] = nil
end)


RegisterCommand("testpayment", function(source, args)
    -- Console (source 0) has no player to pay.
    if source == 0 then return end
 
    local amount = tonumber(args[1]) or DEFAULT_AMOUNT
 
    -- A missing or unknown method lets the gateway offer both cash and card.
    local methods = (args[2] == "cash" or args[2] == "card") and { args[2] } or nil
 
    local success, err = exports.esx_paymentgateway:RequestPayment(source, {
        amount = amount,
        title = "Test payment",
        description = "esx_paymentgateway test",
        methods = methods,
        resultEvent = "esx_paymentgateway:test:result",
    })
 
    if not success then
        print(("[testpayment] request failed for %s: %s"):format(source, err))
    end
end, true)
 
--- Local server event (not a net event, so clients can't trigger it).
---@param playerId number
---@param success boolean
---@param method? string
---@param request PaymentRequest
AddEventHandler("esx_paymentgateway:test:result", function(playerId, success, method, request)
    print(("[testpayment] player %s | success: %s | method: %s | amount: %s"):format(playerId, tostring(success), method or "none", request.amount))
end)