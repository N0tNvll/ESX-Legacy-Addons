local ready = false
local dead = false
local generation = 0
local activePed
local activeLevel = -1
local clipsets = {
    'move_m@drunk@slightlydrunk',
    'move_m@drunk@moderatedrunk',
    'move_m@drunk@verydrunk',
}

local function resetAlcohol()
    generation = generation + 1

    if activePed then
        ClearTimecycleModifier()

        if DoesEntityExist(activePed) then
            ResetPedMovementClipset(activePed, 0.0)
            SetPedIsDrunk(activePed, false)
            SetPedMotionBlur(activePed, false)
        end
    end

    activePed = nil
    activeLevel = -1
end

local function registerAlcohol()
    TriggerEvent('esx_status:registerStatus', 'drunk', 0, '#8F15A5', function(status)
        return status.val > 0
    end, function(status)
        status.remove(1500)
    end)

    ready = true
end

local function updateAlcohol(status)
    local ped = PlayerPedId()

    if not ready or not ESX.PlayerLoaded or dead or IsEntityDead(ped) then
        resetAlcohol()
        return
    end

    if activePed and activePed ~= ped then
        resetAlcohol()
    end

    if not status or status.val <= 0 then
        if activePed then
            resetAlcohol()
        end

        return
    end

    local level = 1

    if status.val > 500000 then
        level = 3
    elseif status.val > 250000 then
        level = 2
    end

    if activePed == ped and activeLevel == level then
        return
    end

    local currentGeneration = generation
    local clipset = clipsets[level]
    local loaded = xLib.streaming.requestAnimSet(clipset)

    if not loaded then
        return
    end

    if currentGeneration ~= generation or not ready or not ESX.PlayerLoaded or dead or PlayerPedId() ~= ped or not DoesEntityExist(ped) or IsEntityDead(ped) then
        RemoveAnimSet(clipset)
        return
    end

    SetPedMovementClipset(ped, clipset, 1.0)
    SetTimecycleModifier('spectator5')
    SetPedMotionBlur(ped, true)
    SetPedIsDrunk(ped, true)
    RemoveAnimSet(clipset)

    activePed = ped
    activeLevel = level
end

AddEventHandler('esx_status:loaded', registerAlcohol)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() and ESX.PlayerLoaded then
        registerAlcohol()
    end
end)

AddEventHandler('esx:onPlayerDeath', function()
    dead = true
    resetAlcohol()
end)

AddEventHandler('esx:onPlayerSpawn', function()
    dead = false
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    ready = false
    dead = false
    resetAlcohol()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        ready = false
        resetAlcohol()
    end
end)

RegisterNetEvent('esx_optionalneeds:onDrink', function()
    TriggerEvent('esx_basicneeds:onUse', 'drink', 'prop_amb_beer_bottle')
end)

CreateThread(function()
    while true do
        Wait(1000)

        if ready and ESX.PlayerLoaded then
            TriggerEvent('esx_status:getStatus', 'drunk', updateAlcohol)
        elseif activePed then
            resetAlcohol()
        end
    end
end)
