local limits, sessions, sequence = {}, {}, 0

Halloween.Ready = false

function Halloween.Token()
    sequence = sequence + 1
    return sequence
end

function Halloween.Player(src)
    if not Halloween.IsInteger(src, 1, 65534) then
        return nil
    end

    local player = sessions[src]

    if player then
        local ok, current = pcall(player.isCurrent)

        if ok and current then
            return player
        end
    end

    -- Exported tables are copies across Lua runtimes. Cache the bound methods,
    -- and ask the core whether that exact session is still current.
    player = ESX.GetPlayerFromId(src)

    if not player then
        sessions[src] = nil
        return nil
    end

    local ok, current = pcall(player.isCurrent)

    if not ok or not current then
        sessions[src] = nil
        return nil
    end

    sessions[src] = player
    return player
end

function Halloween.Current(src, player)
    if not player or player.source ~= src then
        return false
    end

    local ok, current = pcall(player.isCurrent)

    return ok and current == true
end

function Halloween.Allow(src, action, interval)
    local player = Halloween.Player(src)

    if not Halloween.Ready or not player then
        return false
    end

    local entry = limits[src]

    if not entry or entry.player ~= player then
        entry = { player = player, actions = {} }
        limits[src] = entry
    end

    local since = entry.actions[action]

    if since and Halloween.Elapsed(since) < interval then
        return false
    end

    entry.actions[action] = GetGameTimer()
    return true
end

function Halloween.InBucket(src)
    return GetPlayerRoutingBucket(src) == Config.RoutingBucket
end

function Halloween.DeathState(src)
    if GetResourceState('esx_death') ~= 'started' then
        return nil
    end

    local ok, state = pcall(function()
        return exports.esx_death:GetDeathState(src)
    end)

    return ok and type(state) == 'table' and state or nil
end

function Halloween.Alive(src)
    local state = Halloween.DeathState(src)
    local ped = GetPlayerPed(src)

    return state ~= nil
        and state.dead == false
        and ped ~= 0
        and DoesEntityExist(ped)
        and GetEntityHealth(ped) > 100
end

function Halloween.HasAdminPermission(src)
    if src == 0 then
        return true
    end

    local player = Halloween.Player(src)

    if not player then
        return false
    end

    local group = player.getGroup()

    for _, allowed in ipairs(Config.AdminGroups) do
        if type(allowed) == 'string' and group == allowed then
            return true
        end
    end

    return false
end

function Halloween.Message(src, message)
    if src == 0 then
        print('[esx_halloween] ' .. message)
    else
        TriggerClientEvent('esx:showNotification', src, message)
    end
end

local function forget(src)
    src = tonumber(src)

    if src then
        limits[src], sessions[src] = nil, nil
    end
end

AddEventHandler('playerDropped', function()
    forget(source)
end)

AddEventHandler('esx:playerLogout', forget)
