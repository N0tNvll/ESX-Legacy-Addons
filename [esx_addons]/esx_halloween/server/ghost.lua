local ghosts, offers, deaths, lastRequest, recoveries = {}, {}, {}, {}, {}

local function countGhosts()
    local count = 0
    for _ in pairs(ghosts) do count = count + 1 end
    return count
end

local function clearOffer(src, reason)
    local offer = offers[src]
    offers[src] = nil
    if offer and Halloween.Current(src, offer.player) then
        TriggerClientEvent(Events.FORCE_GHOST_EXIT, src, offer.token, reason)
    end
end

local function reply(src, approved, reason, entry, phase)
    TriggerClientEvent(Events.GHOST_MODE_RESPONSE, src, approved, reason, {
        token = entry and entry.token,
        phase = phase,
        fromDeath = entry and entry.fromDeath or false,
        duration = Config.Ghost.maxDuration
    })
end

local function removeGhost(src, reason)
    local entry = ghosts[src]
    ghosts[src] = nil
    if entry then
        if entry.phase == 'active' then
            TriggerClientEvent(Events.SYNC_GHOST_STATE, -1, src, false)
        end
        if Halloween.Current(src, entry.player) then
            TriggerClientEvent(Events.FORCE_GHOST_EXIT, src, entry.token, reason)
        end
    end
end

function Halloween.IsGhost(src)
    local entry = ghosts[src]
    return entry ~= nil and Halloween.Current(src, entry.player)
end

function Halloween.OfferGhost(src, forced)
    local player = Halloween.Player(src)
    local state = Halloween.DeathState(src)
    if not Halloween.Ready or not Config.Ghost.enabled or not player or not state
        or not Halloween.InBucket(src) or ghosts[src] or offers[src] then return false end
    if state.dead and (state.earlyRemaining or 1) > 0 then return false end
    local previous = lastRequest[src]
    if previous and previous.player == player
        and Halloween.Elapsed(previous.at) < Config.Ghost.security.ghostRequestCooldown then return false end
    local offer = {
        player = player, token = Halloween.Token(), fromDeath = state.dead == true,
        started = GetGameTimer()
    }
    offers[src] = offer
    TriggerClientEvent(Events.SHOW_GHOST_CHOICE, src, forced == true, {
        token = offer.token, fromDeath = offer.fromDeath,
        duration = Config.Ghost.security.offerTimeout
    })
    return true
end

local function beginGhost(src, offer)
    if countGhosts() >= Config.Ghost.security.maxConcurrentGhosts then
        reply(src, false, 'Maximum number of ghosts reached', offer)
        return false
    end
    local entry = {
        player = offer.player, token = offer.token, fromDeath = offer.fromDeath,
        started = GetGameTimer(), phase = offer.fromDeath and 'respawn' or 'preparing'
    }
    ghosts[src] = entry
    if entry.fromDeath then recoveries[src] = entry end
    lastRequest[src] = { player = entry.player, at = GetGameTimer() }
    reply(src, true, nil, entry, entry.phase)
    return true
end

local function finishRecovery(src, entry)
    if recoveries[src] ~= entry or not entry.respawned or not Halloween.Current(src, entry.player) then return false end
    local state = Halloween.DeathState(src)
    if not state or state.dead ~= false or not state.recovery or not state.recovery.point then return false end
    recoveries[src] = nil
    TriggerClientEvent('esx_death:recover', src, state.recovery)
    if ghosts[src] == entry and Config.Ghost.enabled and Halloween.InBucket(src) then
        entry.phase, entry.started = 'preparing', GetGameTimer()
        reply(src, true, nil, entry, 'preparing')
    end
    return true
end

RegisterNetEvent(Events.REQUEST_GHOST_MODE, function(choice, token)
    local src = source
    if not Halloween.Allow(src, 'ghostRequest', 750) then return end
    if not Halloween.IsInteger(token, 1, 9007199254740991)
        or (choice ~= 'ghost' and choice ~= 'normal') then return end
    local offer = offers[src]
    if not offer or token ~= offer.token or not Halloween.Current(src, offer.player) then
        reply(src, false, 'No valid ghost offer', { token = token })
        return
    end
    offers[src] = nil -- An offer can be consumed only once.
    if choice ~= 'ghost' then return end
    local state = Halloween.DeathState(src)
    if not Config.Ghost.enabled or ghosts[src] or not Halloween.InBucket(src)
        or Halloween.Elapsed(offer.started) >= Config.Ghost.security.offerTimeout
        or not state or (state.dead == true) ~= offer.fromDeath
        or (offer.fromDeath and (state.earlyRemaining or 1) > 0) then
        reply(src, false, 'Ghost offer expired or unavailable', offer)
        return
    end
    beginGhost(src, offer)
end)

-- Only esx_death's trusted server lifecycle can create a death offer.
AddEventHandler('esx_death:stateChanged', function(src, dead, reason)
    if GetInvokingResource() ~= 'esx_death' then return end
    local player = Halloween.Player(src)
    if not player then return end
    if dead then
        removeGhost(src, 'death')
        clearOffer(src, 'death')
        if Config.Ghost.enabled and reason == 'death' then
            local state = Halloween.DeathState(src)
            if state and state.dead then
                deaths[src] = {
                    player = player, started = GetGameTimer(),
                    delay = math.max(Config.Ghost.security.deathCooldown, (state.earlyRemaining or 0) * 1000)
                }
            end
        end
        return
    end

    deaths[src] = nil
    clearOffer(src, 'recovered')
    local entry = recoveries[src]
    if not entry or not Halloween.Current(src, entry.player) or reason ~= 'respawn' then
        recoveries[src] = nil
        removeGhost(src, 'recovered')
        return
    end
    entry.phase, entry.started, entry.respawned = 'recovering', GetGameTimer(), true
    -- esx_death publishes the transition before completing penalties/recovery data.
    -- Always finish that legitimate recovery, even if the ghost request is cancelled.
    CreateThread(function()
        local started = GetGameTimer()
        while Halloween.Current(src, player) and Halloween.Elapsed(started) < 15000 do
            if finishRecovery(src, entry) or recoveries[src] ~= entry then return end
            Wait(100)
        end
        if ghosts[src] == entry then removeGhost(src, 'recovery_failed') end
    end)
end)

RegisterNetEvent(Events.GHOST_READY, function(token, phase)
    local src = source
    if phase ~= 'prepared' and phase ~= 'active' and phase ~= 'respawned' then return end
    if not Halloween.Allow(src, 'ghostReady:' .. phase, 100) then return end
    if phase == 'respawned' then
        local recovery = recoveries[src]
        if recovery and recovery.token == token then finishRecovery(src, recovery) end
        return
    end
    local entry = ghosts[src]
    if not entry or token ~= entry.token or not Halloween.Current(src, entry.player) then return end
    if not Config.Ghost.enabled or not Halloween.InBucket(src)
        or Halloween.Elapsed(entry.started) >= Config.Ghost.security.requestTimeout then
        removeGhost(src, 'expired')
        return
    end
    if not Halloween.Alive(src) then return end
    if phase == 'prepared' and entry.phase == 'preparing' then
        entry.phase, entry.started = 'activating', GetGameTimer()
        reply(src, true, nil, entry, 'active')
    elseif phase == 'active' and entry.phase == 'activating' then
        entry.phase, entry.started = 'active', GetGameTimer()
        TriggerClientEvent(Events.SYNC_GHOST_STATE, -1, src, true)
    end
end)

RegisterNetEvent(Events.EXIT_GHOST_MODE, function(token)
    local src = source
    if not Halloween.Allow(src, 'ghostExit', 250) then return end
    local entry = ghosts[src]
    if entry and entry.token == token then removeGhost(src, 'exit') end
    local offer = offers[src]
    if offer and offer.token == token then
        offers[src] = nil
        TriggerClientEvent(Events.FORCE_GHOST_EXIT, src, token, 'cancelled')
    end
end)

RegisterNetEvent(Events.TRIGGER_SCARE, function(target)
    local src = source
    if not Halloween.Allow(src, 'scare', 250) then return end
    local entry = ghosts[src]
    local ability = Config.Ghost.abilities.scare
    if not Config.Ghost.enabled or not ability.enabled or not entry or entry.phase ~= 'active'
        or not Halloween.Current(src, entry.player) or not Halloween.IsInteger(target, 1, 65534)
        or src == target or not Halloween.Player(target) or not Halloween.Alive(src)
        or not Halloween.Alive(target) or Halloween.IsGhost(target)
        or not Halloween.InBucket(src) or GetPlayerRoutingBucket(target) ~= GetPlayerRoutingBucket(src) then return end
    if Halloween.Elapsed(entry.started) >= Config.Ghost.maxDuration then removeGhost(src, 'expired'); return end
    if entry.lastScare and Halloween.Elapsed(entry.lastScare) < ability.cooldown then return end
    local ped, targetPed = GetPlayerPed(src), GetPlayerPed(target)
    if #(GetEntityCoords(ped) - GetEntityCoords(targetPed)) > ability.range then return end
    entry.lastScare = GetGameTimer()
    TriggerClientEvent(Events.RECEIVE_SCARE, target, (GetPlayerName(src) or 'A ghost'):sub(1, 100))
end)

function Halloween.SyncGhosts(src)
    local ids = {}
    if Halloween.InBucket(src) then
        for id, entry in pairs(ghosts) do
            if id ~= src and entry.phase == 'active' and Halloween.Current(id, entry.player)
                and Halloween.InBucket(id) and Halloween.Elapsed(entry.started) < Config.Ghost.maxDuration then
                ids[#ids + 1] = id
            end
        end
    end
    TriggerClientEvent(Events.GHOST_SNAPSHOT, src, ids)
end

CreateThread(function()
    while true do
        Wait(500)
        for src, candidate in pairs(deaths) do
            if not Halloween.Current(src, candidate.player) or not Config.Ghost.enabled then
                deaths[src] = nil
            elseif Halloween.Elapsed(candidate.started) >= candidate.delay then
                deaths[src] = nil
                local state = Halloween.DeathState(src)
                if state and state.dead and (state.earlyRemaining or 1) == 0
                    and math.random(100) <= Config.Ghost.spawnChance then
                    Halloween.OfferGhost(src, false)
                end
            end
        end
        for src, offer in pairs(offers) do
            if not Config.Ghost.enabled or not Halloween.Current(src, offer.player)
                or not Halloween.InBucket(src)
                or Halloween.Elapsed(offer.started) >= Config.Ghost.security.offerTimeout then
                offers[src] = nil
                if Halloween.Current(src, offer.player) then
                    TriggerClientEvent(Events.FORCE_GHOST_EXIT, src, offer.token, 'offer_expired')
                end
            end
        end
        for src, entry in pairs(ghosts) do
            local timeout = entry.phase == 'active' and Config.Ghost.maxDuration
                or Config.Ghost.security.requestTimeout
            if not Config.Ghost.enabled or not Halloween.Current(src, entry.player)
                or not Halloween.InBucket(src) or Halloween.Elapsed(entry.started) >= timeout then
                removeGhost(src, 'expired')
            end
        end
        for src, entry in pairs(recoveries) do
            if not Halloween.Current(src, entry.player) or Halloween.Elapsed(entry.started) >= 300000 then
                recoveries[src] = nil
            end
        end
    end
end)

local function forget(src)
    src = tonumber(src)
    if not src then return end
    removeGhost(src, 'logout')
    clearOffer(src, 'logout')
    offers[src], deaths[src], lastRequest[src], recoveries[src] = nil, nil, nil, nil
end
AddEventHandler('playerDropped', function() forget(source) end)
AddEventHandler('esx:playerLogout', forget)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(ghosts) do removeGhost(src, 'resource_stop') end
end)

exports('IsPlayerGhost', Halloween.IsGhost)
exports('SetPlayerGhost', function(src, enabled)
    if type(enabled) ~= 'boolean' or not Halloween.Player(src) then return false end
    if not enabled then removeGhost(src, 'server'); return true end
    if not Config.Ghost.enabled or ghosts[src] or not Halloween.InBucket(src) then return false end
    local state = Halloween.DeathState(src)
    if not state or (state.dead and (state.earlyRemaining or 1) > 0) then return false end
    return beginGhost(src, {
        player = Halloween.Player(src), token = Halloween.Token(), fromDeath = state.dead == true
    })
end)
