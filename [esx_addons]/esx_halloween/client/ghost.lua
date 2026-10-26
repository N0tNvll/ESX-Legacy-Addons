local keys = { X = 73, E = 38, DELETE = 178, BACKSPACE = 177 }
local exitKey = keys[Config.Ghost.exitKeybind]
local scareKey = keys[Config.Ghost.abilities.scare.keybind]
local offer, request, appearance
local restoringAppearance, deferredAppearance
local isGhost, stopping, restoring = false, false, false
local otherGhosts, visibility = {}, {}
local recovered = 0

Halloween.ClientGhost = function()
    return isGhost or request ~= nil or restoring
end

local function hideChoice()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hideGhostChoice' })
end

local function resetRemote(id)
    local cached = visibility[id]

    if cached and DoesEntityExist(cached.ped) then
        ResetEntityAlpha(cached.ped)
    end

    visibility[id] = nil
end

local function disableGhost(notifyServer, immediate)
    local previous = request
    local saved = appearance or restoringAppearance or deferredAppearance

    request, offer, appearance = nil, nil, nil

    local wasGhost = isGhost

    isGhost = false
    hideChoice()
    SendNUIMessage({ type = 'hideGhostHUD' })

    if notifyServer and previous then
        TriggerServerEvent(Events.EXIT_GHOST_MODE, previous.token)
    end

    if previous and previous.model then
        SetModelAsNoLongerNeeded(previous.model)
    end

    if wasGhost and ESX.PlayerData.dead and not immediate then
        deferredAppearance = saved
        Halloween.ResetGhostStats()
    elseif wasGhost or restoringAppearance or deferredAppearance then
        deferredAppearance = nil
        restoring = true
        restoringAppearance = saved

        Halloween.RestoreAppearance(saved, immediate)

        restoringAppearance = nil
        restoring = false
    elseif saved then
        SetModelAsNoLongerNeeded(saved.model)
    end
end

function Halloween.SyncGhostUI()
    if offer then
        SendNUIMessage({
            type = 'showGhostChoice',
            duration = math.max(0, offer.duration - Halloween.Elapsed(offer.started)),
        })
    elseif isGhost and request then
        SendNUIMessage({
            type = 'showGhostHUD',
            maxDuration = math.max(0, request.duration - Halloween.Elapsed(request.started)),
            exitKey = Config.Ghost.exitKeybind,
            scareKey = Config.Ghost.abilities.scare.enabled
                    and Config.Ghost.abilities.scare.keybind
                or '',
        })
    end
end

local function cancelled(entry)
    return stopping or request ~= entry
end

local function prepare(entry)
    if entry.fromDeath then
        local started = GetGameTimer()

        while
            recovered <= entry.recovered
            and not cancelled(entry)
            and Halloween.Elapsed(started) < Config.Ghost.security.requestTimeout
        do
            Wait(50)
        end

        if cancelled(entry) then
            return
        end

        if recovered <= entry.recovered then
            disableGhost(true, false)
            return
        end

        Wait(100)
    end

    if cancelled(entry) then
        return
    end

    local model = GetHashKey(Config.Ghost.pedModel)

    if not IsModelInCdimage(model) or not IsModelValid(model) or not IsModelAPed(model) then
        disableGhost(true, false)
        return
    end

    RequestModel(model)

    local started = GetGameTimer()

    while
        not HasModelLoaded(model)
        and not cancelled(entry)
        and Halloween.Elapsed(started) < 8000
    do
        Wait(50)
    end

    if cancelled(entry) then
        SetModelAsNoLongerNeeded(model)
        return
    end

    if not HasModelLoaded(model) then
        SetModelAsNoLongerNeeded(model)
        disableGhost(true, false)
        return
    end

    local saved = Halloween.CaptureAppearance(function()
        return cancelled(entry)
    end)

    if cancelled(entry) then
        if saved then
            SetModelAsNoLongerNeeded(saved.model)
        end

        SetModelAsNoLongerNeeded(model)
        return
    end

    if not saved then
        SetModelAsNoLongerNeeded(model)
        disableGhost(true, false)
        return
    end

    appearance, entry.model = saved, model
    entry.phase, entry.started = 'prepared', GetGameTimer()
    TriggerServerEvent(Events.GHOST_READY, entry.token, 'prepared')
end

local function enableGhost(entry, duration)
    if request ~= entry or not appearance or not HasModelLoaded(entry.model) then
        return
    end

    SetPlayerModel(PlayerId(), entry.model)
    SetModelAsNoLongerNeeded(entry.model)

    local ped = PlayerPedId()

    SetEntityAlpha(ped, Config.Ghost.visibility.alpha, false)
    SetPedCanRagdoll(ped, false)
    SetEntityInvincible(ped, true)
    SetPlayerInvincible(PlayerId(), true)
    SetRunSprintMultiplierForPlayer(PlayerId(), Config.Ghost.movement.speedMultiplier)

    isGhost, entry.phase, entry.started, entry.duration = true, 'active', GetGameTimer(), duration
    TriggerServerEvent(Events.GHOST_READY, entry.token, 'active')

    SendNUIMessage({
        type = 'showGhostHUD',
        maxDuration = duration,
        exitKey = Config.Ghost.exitKeybind,
        scareKey = Config.Ghost.abilities.scare.enabled and Config.Ghost.abilities.scare.keybind
            or '',
    })
end

RegisterNetEvent(Events.SHOW_GHOST_CHOICE, function(forced, data)
    if
        source ~= 65535
        or not Config.Ghost.enabled
        or Halloween.ClientGhost()
        or type(data) ~= 'table'
        or not Halloween.IsInteger(data.token, 1, 9007199254740991)
        or type(data.fromDeath) ~= 'boolean'
        or not Halloween.IsNumber(data.duration)
    then
        return
    end

    offer = {
        token = data.token,
        fromDeath = data.fromDeath,
        started = GetGameTimer(),
        duration = data.duration,
    }

    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'showGhostChoice', forced = forced == true, duration = data.duration })
end)

RegisterNUICallback('ghostChoice', function(data, cb)
    local selected = offer

    hideChoice()
    offer = nil

    if
        not selected
        or type(data) ~= 'table'
        or (data.choice ~= 'ghost' and data.choice ~= 'normal')
    then
        cb({ ok = false, error = 'Choice expired' })
        return
    end

    if data.choice == 'ghost' then
        request = {
            token = selected.token,
            fromDeath = selected.fromDeath,
            phase = 'requested',
            started = GetGameTimer(),
            recovered = recovered,
        }
    end

    TriggerServerEvent(Events.REQUEST_GHOST_MODE, data.choice, selected.token)
    cb({ ok = true })
end)

RegisterNetEvent(Events.GHOST_MODE_RESPONSE, function(approved, reason, data)
    if
        source ~= 65535
        or type(approved) ~= 'boolean'
        or type(data) ~= 'table'
        or not Halloween.IsInteger(data.token, 1, 9007199254740991)
    then
        return
    end

    if
        not request
        and approved
        and (data.phase == 'respawn' or data.phase == 'preparing')
        and not isGhost
        and not stopping
        and not restoring
    then
        -- Trusted server exports can initiate preparation without an NUI choice.
        request = { token = data.token, fromDeath = data.fromDeath == true, recovered = recovered }
    end

    local entry = request

    if not entry or entry.token ~= data.token then
        return
    end

    if not approved then
        disableGhost(false, false)

        if type(reason) == 'string' then
            ESX.ShowNotification(reason)
        end

        return
    end

    if data.phase == 'respawn' and entry.phase ~= 'respawn' then
        entry.phase, entry.started = 'respawn', GetGameTimer()
        ESX.TriggerServerCallback('esx_death:respawn', function(result)
            if result and result.ok then
                TriggerServerEvent(Events.GHOST_READY, entry.token, 'respawned')
            end

            if request == entry and (not result or not result.ok) then
                disableGhost(true, false)
                ESX.ShowNotification(
                    'Normal respawn is unavailable. Try again from the death screen.'
                )
            end
        end)
    elseif
        data.phase == 'preparing'
        and entry.phase ~= 'preparing'
        and entry.phase ~= 'prepared'
    then
        entry.phase, entry.started = 'preparing', GetGameTimer()
        CreateThread(function()
            prepare(entry)
        end)
    elseif
        data.phase == 'active'
        and entry.phase == 'prepared'
        and Halloween.IsNumber(data.duration)
        and data.duration > 0
        and data.duration <= Config.Ghost.maxDuration
    then
        enableGhost(entry, data.duration)
    end
end)

RegisterNetEvent(Events.FORCE_GHOST_EXIT, function(token)
    if source ~= 65535 then
        return
    end

    if (request and request.token == token) or (offer and offer.token == token) then
        disableGhost(false, false)
    end
end)

AddEventHandler('esx_death:recovered', function()
    if deferredAppearance then
        local saved = deferredAppearance

        deferredAppearance = nil
        saved.health, saved.armor = GetEntityHealth(PlayerPedId()), GetPedArmour(PlayerPedId())
        restoring, restoringAppearance = true, saved
        Halloween.RestoreAppearance(saved, false)
        restoring, restoringAppearance = false, nil
    end

    recovered = recovered + 1
end)

CreateThread(function()
    while true do
        if isGhost then
            Wait(0)
            DisablePlayerFiring(PlayerId(), true)

            for _, control in ipairs({ 24, 25, 140, 141, 142, 23, 75 }) do
                DisableControlAction(0, control, true)
            end

            local entry = request

            if IsControlJustPressed(0, exitKey) then
                disableGhost(true, false)
            elseif
                entry
                and Config.Ghost.abilities.scare.enabled
                and IsControlJustPressed(0, scareKey)
                and (
                    not entry.lastScare
                    or Halloween.Elapsed(entry.lastScare)
                        >= Config.Ghost.abilities.scare.cooldown
                )
            then
                local coords = GetEntityCoords(PlayerPedId())
                local target, distance = ESX.Game.GetClosestPlayer(coords)

                if target ~= -1 and distance and distance <= Config.Ghost.abilities.scare.range then
                    TriggerServerEvent(Events.TRIGGER_SCARE, GetPlayerServerId(target))
                    entry.lastScare = GetGameTimer()
                end
            end
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(250)

        if offer and Halloween.Elapsed(offer.started) >= offer.duration then
            TriggerServerEvent(Events.EXIT_GHOST_MODE, offer.token)
            offer = nil
            hideChoice()
        end

        local entry = request

        if entry then
            local timeout = isGhost and entry.duration or Config.Ghost.security.requestTimeout

            if Halloween.Elapsed(entry.started) >= timeout then
                disableGhost(true, false)
            end
        end
    end
end)

RegisterNetEvent(Events.SYNC_GHOST_STATE, function(id, enabled)
    if
        source ~= 65535
        or not Halloween.IsInteger(id, 1, 65534)
        or type(enabled) ~= 'boolean'
        or id == GetPlayerServerId(PlayerId())
    then
        return
    end

    if enabled then
        otherGhosts[id] = true
    else
        otherGhosts[id] = nil
        resetRemote(id)
    end
end)

RegisterNetEvent(Events.GHOST_SNAPSHOT, function(ids)
    if source ~= 65535 or type(ids) ~= 'table' then
        return
    end

    local latest = {}

    for _, id in ipairs(ids) do
        if Halloween.IsInteger(id, 1, 65534) and id ~= GetPlayerServerId(PlayerId()) then
            latest[id] = true
        end
    end

    for id in pairs(otherGhosts) do
        if not latest[id] then
            resetRemote(id)
        end
    end

    otherGhosts = latest
end)

CreateThread(function()
    while true do
        Wait(next(otherGhosts) and 500 or 1000)

        local coords = GetEntityCoords(PlayerPedId())

        for id in pairs(otherGhosts) do
            local player = GetPlayerFromServerId(id)

            if player ~= -1 then
                local ped = GetPlayerPed(player)

                if ped ~= 0 and DoesEntityExist(ped) then
                    local alpha = #(coords - GetEntityCoords(ped)) <= Config.Ghost.visibility.range
                            and Config.Ghost.visibility.alpha
                        or 0
                    local cached = visibility[id]

                    if not cached or cached.ped ~= ped or cached.alpha ~= alpha then
                        if cached and cached.ped ~= ped then
                            resetRemote(id)
                        end

                        SetEntityAlpha(ped, alpha, false)
                        visibility[id] = { ped = ped, alpha = alpha }
                    end
                end
            else
                resetRemote(id)
            end
        end
    end
end)

RegisterNetEvent(Events.RECEIVE_SCARE, function(name)
    if source ~= 65535 or type(name) ~= 'string' then
        return
    end

    local effect = Config.Ghost.abilities.scare.effects

    SendNUIMessage({
        type = 'triggerJumpscare',
        soundVolume = effect.sound and effect.soundVolume or 0,
        duration = effect.duration,
    })

    if effect.screenShake then
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.3)
    end

    SendNUIMessage({
        type = 'showNotification',
        size = 'large',
        position = 'bottom-center',
        header = 'You were scared!',
        description = name:sub(1, 100) .. ' has haunted you!',
        duration = 4000,
    })
end)

AddEventHandler('esx:onPlayerLogout', function()
    disableGhost(true, true)

    for id in pairs(otherGhosts) do
        resetRemote(id)
    end

    otherGhosts = {}
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    stopping = true
    disableGhost(false, true)
    DoScreenFadeIn(0)

    for id in pairs(otherGhosts) do
        resetRemote(id)
    end
end)
