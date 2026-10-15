--- Theme convars (see ESX UI guidelines) and their fallbacks.
--- They must be replicated with `setr` to be readable on the client.
local THEME_CONVARS <const> = {
    primaryColor = { name = "esx:ui:primaryColor", default = "#fb9b04" },
    secondaryColor = { name = "esx:ui:secondaryColor", default = "#252525" },
    backgroundColor = { name = "esx:ui:backgroundColor", default = "#161616" },
    accentColor = { name = "esx:ui:accentColor", default = "#fb9b04" },
    logoUrl = { name = "esx:ui:logoUrl", default = "" },
}

--- Whether the payment UI is currently open.
local isOpen = false

--- Toggles NUI focus and tells the UI to close when needed.
---@param state boolean
local function setOpen(state)
    isOpen = state
    SetNuiFocus(state, state)

    if not state then
        SendNUIMessage({ action = "close" })
    end
end

RegisterNetEvent("esx_paymentgateway:open", function(paymentRequest)
    -- Read on every open so convar changes apply without a restart.
    local theme = {}
    for key, convar in pairs(THEME_CONVARS) do
        theme[key] = GetConvar(convar.name, convar.default)
    end

    setOpen(true)
    SendNUIMessage({ action = "open", payload = paymentRequest, theme = theme })
end)

RegisterNetEvent("esx_paymentgateway:result", function(result)
    SendNUIMessage({ action = "paymentResult", payload = result })

    if result.success then
        SetTimeout(1200, function()
            if isOpen then setOpen(false) end
        end)
    end
end)

RegisterNUICallback("selectPayment", function(data, callback)
    if isOpen then
        TriggerServerEvent("esx_paymentgateway:selectMethod", data.method)
    end

    callback({ ok = isOpen })
end)

RegisterNUICallback("close", function(_, callback)
    if isOpen then
        TriggerServerEvent("esx_paymentgateway:cancel")
        setOpen(false)
    end

    callback({ ok = true })
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)
