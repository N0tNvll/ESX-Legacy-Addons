local settings = Config.TrickOrTreat
local round, tickets, travel = nil, {}, {}
local idleSince = GetGameTimer()

local function openRound()
    return Halloween.Ready and settings.enabled and round and not round.closing
        and Halloween.Elapsed(round.started) < round.duration
end

local function remaining(state)
    return math.max(0, state.duration - Halloween.Elapsed(state.started))
end

local function payload(src)
    if not openRound() or not Halloween.InBucket(src) then return { active = false } end
    local ids = {}
    for _, id in ipairs(round.selected) do
        if not round.houses[id].collected then ids[#ids + 1] = id end
    end
    return {
        active = true, roundId = round.id, totalHouses = #round.selected,
        currentHouses = round.collected, timeRemaining = remaining(round),
        activeHouseIds = ids
    }
end

function Halloween.SyncRound(src)
    TriggerClientEvent(Events.ROUND_START, src, payload(src))
end

local function broadcast()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if Halloween.Player(src) then Halloween.SyncRound(src) end
    end
end

local function endRound()
    if not round then return end
    round.closing = true
    if round.inFlight > 0 then return end
    local previous = round
    round, tickets = nil, {}
    idleSince = GetGameTimer()
    TriggerClientEvent(Events.ROUND_END, -1, {
        roundId = previous.id, totalCollected = previous.collected, totalHouses = #previous.selected
    })
end

local function selectHouses()
    local indices = {}
    for index = 1, #settings.houses do indices[index] = index end
    local count = math.min(settings.doorsPerRound, #indices)
    for index = 1, count do
        local selected = math.random(index, #indices)
        indices[index], indices[selected] = indices[selected], indices[index]
    end
    local result = {}
    for index = 1, count do result[index] = indices[index] end
    return result
end

local function startRound()
    if not Halloween.Ready or not settings.enabled or round then return false end
    local state = {
        id = Halloween.Token(), selected = selectHouses(), houses = {}, collected = 0,
        inFlight = 0, started = GetGameTimer(), duration = settings.roundDurationMinutes * 60000,
        synced = GetGameTimer()
    }
    for _, id in ipairs(state.selected) do state.houses[id] = { collected = false } end
    round = state
    broadcast()
    return true
end

local function rewardFor(house)
    if house.reward then return house.reward end
    local roll, common, rare = math.random(100), settings.rewards.candy, settings.rewards.rareCandy
    if roll <= common.chance then
        house.reward = { rewardType = 'treat', item = common.item, amount = common.amount }
    elseif roll <= common.chance + rare.chance then
        house.reward = { rewardType = 'treat', item = rare.item, amount = rare.amount }
    else
        house.reward = { rewardType = 'trick', item = 'trick', amount = 0 }
    end
    return house.reward
end

local function respond(src, errorMessage, extra)
    local data = extra or {}
    data.success = errorMessage == nil
    data.error = errorMessage
    TriggerClientEvent(Events.HOUSE_COLLECT_RESPONSE, src, data)
end

local function release(ticket)
    if ticket.delivering then return end
    if tickets[ticket.src] == ticket then tickets[ticket.src] = nil end
    if ticket.house.ticket == ticket then ticket.house.ticket = nil end
end

local function validate(src, id, roundId)
    local player = Halloween.Player(src)
    if not openRound() or not player or not Halloween.InBucket(src)
        or not Halloween.Alive(src) or Halloween.IsGhost(src) then return nil, 'Event unavailable' end
    if roundId ~= round.id or not Halloween.IsInteger(id, 1, #settings.houses) then
        return nil, 'Invalid house or round'
    end
    local house = round.houses[id]
    if not house or house.collected then return nil, 'House not available' end
    local coords = GetEntityCoords(GetPlayerPed(src))
    local destination = settings.houses[id].coords
    if #(coords - destination) > settings.interaction.distance + settings.interaction.tolerance then
        return nil, 'Too far away'
    end
    local previous = travel[src]
    if previous and previous.player == player then
        local seconds = Halloween.Elapsed(previous.at) / 1000
        local distance = #(coords - previous.coords)
        if seconds < settings.interaction.minimumTravelSeconds
            or distance > seconds * settings.interaction.maxTravelSpeed + settings.interaction.travelAllowance then
            return nil, 'Please wait before collecting from another house'
        end
    end
    return { player = player, house = house, coords = coords }
end

RegisterNetEvent(Events.HOUSE_INTERACT_REQUEST, function(id, roundId)
    local src = source
    if not Halloween.Allow(src, 'houseStart', 1000) then return end
    local result, err = validate(src, id, roundId)
    if not result then respond(src, err); return end
    local previous = tickets[src]
    if previous then
        if previous.delivering or Halloween.Elapsed(previous.started) < settings.interaction.requestTimeout then
            respond(src, 'Collection in progress'); return
        end
        release(previous)
    end
    local reservation = result.house.ticket
    if reservation then
        if not reservation.delivering and (not Halloween.Current(reservation.src, reservation.player)
            or Halloween.Elapsed(reservation.started) >= settings.interaction.requestTimeout) then
            release(reservation)
        else
            respond(src, 'House is busy'); return
        end
    end
    local ticket = {
        token = Halloween.Token(), src = src, player = result.player, round = round, id = id,
        house = result.house, started = GetGameTimer(), coords = result.coords
    }
    rewardFor(result.house) -- A full inventory or failed delivery cannot reroll this house.
    tickets[src], result.house.ticket = ticket, ticket
    TriggerClientEvent(Events.HOUSE_INTERACT_RESPONSE, src, {
        token = ticket.token, houseId = id, roundId = round.id, duration = settings.interaction.duration
    })
end)

RegisterNetEvent(Events.HOUSE_COLLECT_REQUEST, function(id, roundId, token)
    local src = source
    if not Halloween.Allow(src, 'houseFinish', 250) then return end
    local ticket = tickets[src]
    if not ticket or ticket.token ~= token or ticket.id ~= id or ticket.round.id ~= roundId
        or ticket.delivering or not Halloween.Current(src, ticket.player) then return end
    local elapsed = Halloween.Elapsed(ticket.started)
    if elapsed < settings.interaction.duration then respond(src, 'Interaction not finished'); return end
    local result, err = validate(src, id, roundId)
    if not result or round ~= ticket.round or ticket.house.ticket ~= ticket
        or elapsed >= settings.interaction.requestTimeout then
        release(ticket); respond(src, err or 'Interaction expired'); return
    end

    -- Reserve before calling inventory adapters/hooks, which may yield.
    ticket.delivering = true
    local state, house, reward, player = ticket.round, ticket.house, ticket.house.reward, ticket.player
    state.inFlight = state.inFlight + 1
    local consumed, success, failure = false, false, nil
    if reward.rewardType == 'treat' then
        local checked, canCarry = pcall(player.canCarryItem, reward.item, reward.amount)
        if not checked then
            failure = 'Inventory unavailable'
        elseif not canCarry then
            failure = 'Inventory full'
        elseif not Halloween.Current(src, player) or not openRound() then
            failure = 'Collection expired'
        else
            local beforeOK, before = pcall(player.getInventoryItem, reward.item)
            local beforeCount = beforeOK and before and before.count
            local stillEligible = validate(src, id, roundId)
            if not stillEligible or not Halloween.Current(src, player)
                or Halloween.Elapsed(ticket.started) >= settings.interaction.requestTimeout then
                failure = 'Collection expired'
            else
                local delivered, added = pcall(player.addInventoryItem, reward.item, reward.amount)
                local afterOK, after = pcall(player.getInventoryItem, reward.item)
                local measured = afterOK and after and type(beforeCount) == 'number' and type(after.count) == 'number'
                local changed = measured and after.count ~= beforeCount
                local increased = measured and after.count >= beforeCount + reward.amount
                if delivered and (added == true or (added == nil and increased)) then
                    consumed, success = true, true
                elseif not delivered or changed or added ~= false or not measured then
                    -- Ambiguous adapter errors must not reopen a potentially paid house.
                    consumed, failure = true, 'Reward delivery could not be confirmed'
                    print(('[esx_halloween] Inventory delivery requires review (round %d, house %d).'):format(state.id, id))
                else
                    failure = 'Reward could not be delivered'
                end
            end
        end
    else
        consumed, success = true, true
    end

    if consumed then
        house.collected = true
        state.collected = state.collected + 1
        if Halloween.Current(src, player) then
            travel[src] = { player = player, coords = result.coords, at = GetGameTimer() }
        end
    end
    ticket.delivering = false
    release(ticket)
    state.inFlight = state.inFlight - 1

    if Halloween.Current(src, player) then
        if success then
            if reward.rewardType == 'trick' then
                TriggerClientEvent(Events.TRIGGER_TRICK, src, {
                    roundId = state.id, token = token, damage = settings.rewards.trick.damage,
                    effects = settings.rewards.trick.effects
                })
            end
            respond(src, nil, {
                roundId = state.id, houseId = id, rewardType = reward.rewardType,
                rewardItem = reward.item, rewardAmount = reward.amount,
                remainingHouses = math.max(0, #state.selected - state.collected)
            })
        else
            respond(src, failure)
        end
    end
    if round == state then
        if state.closing or remaining(state) == 0 or state.collected >= #state.selected then
            endRound()
        elseif consumed then
            broadcast()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        for _, ticket in pairs(tickets) do
            if not ticket.delivering and (not Halloween.Current(ticket.src, ticket.player)
                or Halloween.Elapsed(ticket.started) >= settings.interaction.requestTimeout) then release(ticket) end
        end
        if round then
            if not settings.enabled or remaining(round) == 0 or round.closing then
                endRound()
            elseif Halloween.Elapsed(round.synced) >= settings.progressSyncInterval then
                round.synced = GetGameTimer()
                broadcast()
            end
        elseif Halloween.Ready and settings.enabled
            and Halloween.Elapsed(idleSince) >= settings.roundFrequencyMinutes * 60000 then
            startRound()
        end
    end
end)

local function forget(src)
    src = tonumber(src)
    if not src then return end
    local ticket = tickets[src]
    if ticket then release(ticket) end
    travel[src] = nil
end
AddEventHandler('playerDropped', function() forget(source) end)
AddEventHandler('esx:playerLogout', forget)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    endRound()
end)

RegisterCommand('startround', function(src)
    if not Halloween.HasAdminPermission(src) then Halloween.Message(src, 'No permission'); return end
    Halloween.Message(src, startRound() and 'Round started' or 'A round is active or the event is unavailable')
end, false)

RegisterCommand('resetcooldowns', function(src)
    if not Halloween.HasAdminPermission(src) then Halloween.Message(src, 'No permission'); return end
    if not round or round.inFlight > 0 then Halloween.Message(src, 'No reset available while a reward is being delivered'); return end
    endRound()
    startRound()
    Halloween.Message(src, 'A new round was started; previous collection tickets are invalid')
end, false)
