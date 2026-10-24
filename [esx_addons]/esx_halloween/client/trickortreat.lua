local settings = Config.TrickOrTreat
local round, interaction, nearest
local endedRound = 0
local pumpkins, blips, loading, failures = {}, {}, {}, {}
local stopping = false

local function deletePumpkin(id)
    local object = pumpkins[id]

    if object and DoesEntityExist(object) then
        DeleteEntity(object)
    end

    pumpkins[id], loading[id], failures[id] = nil, nil, nil
end

local function clear()
    round, interaction, nearest = nil, nil, nil

    for id in pairs(pumpkins) do
        deletePumpkin(id)
    end

    loading, failures = {}, {}

    for _, blip in pairs(blips) do
        RemoveBlip(blip)
    end

    blips = {}
    SendNUIMessage({ type = 'trickOrTreatRoundEnd' })
end

local function timeRemaining()
    return round and math.max(0, round.remaining - Halloween.Elapsed(round.synced)) or 0
end

function Halloween.SyncRoundUI()
    if not round then
        SendNUIMessage({ type = 'trickOrTreatRoundEnd' })
        return
    end

    SendNUIMessage({
        type = 'trickOrTreatRoundStart',
        totalHouses = round.total,
        currentHouses = round.collected,
        timeRemaining = timeRemaining(),
    })
end

local function spawnPumpkin(id, state)
    local house = settings.houses[id]
    local model = GetHashKey(settings.pumpkinModel)

    if not IsModelInCdimage(model) or not IsModelValid(model) or IsModelAPed(model) then
        failures[id] = GetGameTimer()
        return
    end

    local token = {}

    loading[id] = token
    CreateThread(function()
        RequestModel(model)

        local started = GetGameTimer()

        while
            not HasModelLoaded(model)
            and round == state
            and state.available[id]
            and not stopping
            and loading[id] == token
            and Halloween.Elapsed(started) < 5000
        do
            Wait(50)
        end

        if
            stopping
            or round ~= state
            or not state.available[id]
            or loading[id] ~= token
            or #(GetEntityCoords(PlayerPedId()) - house.coords) > settings.npcDespawnDistance
        then
            if loading[id] == token then
                loading[id] = nil
            end

            SetModelAsNoLongerNeeded(model)
            return
        end

        if not HasModelLoaded(model) then
            loading[id], failures[id] = nil, GetGameTimer()
            SetModelAsNoLongerNeeded(model)
            return
        end

        RequestCollisionAtCoord(house.coords.x, house.coords.y, house.coords.z)

        local found, groundZ =
            GetGroundZFor_3dCoord(house.coords.x, house.coords.y, house.coords.z + 5.0, false)
        local z = found and Halloween.IsNumber(groundZ) and groundZ or house.coords.z
        local object = CreateObject(model, house.coords.x, house.coords.y, z, false, false, false)

        loading[id] = nil
        SetModelAsNoLongerNeeded(model)

        if object == 0 then
            failures[id] = GetGameTimer()
            return
        end

        SetEntityAsMissionEntity(object, true, true)
        SetEntityHeading(object, house.heading)
        PlaceObjectOnGroundProperly(object)
        FreezeEntityPosition(object, true)
        SetEntityInvincible(object, true)
        pumpkins[id] = object
    end)
end

local function sync(data)
    if type(data) ~= 'table' then
        return
    end

    if data.active ~= true or not settings.enabled then
        clear()
        return
    end

    if
        not Halloween.IsInteger(data.roundId, 1, 9007199254740991)
        or data.roundId <= endedRound
        or not Halloween.IsInteger(data.totalHouses, 1, settings.doorsPerRound)
        or not Halloween.IsInteger(data.currentHouses, 0, data.totalHouses)
        or not Halloween.IsNumber(data.timeRemaining)
        or data.timeRemaining <= 0
        or type(data.activeHouseIds) ~= 'table'
    then
        return
    end

    local same = round and round.id == data.roundId

    if round and data.roundId < round.id then
        return
    end

    if not same then
        clear()
    end

    local available = {}

    for _, id in ipairs(data.activeHouseIds) do
        if Halloween.IsInteger(id, 1, #settings.houses) then
            available[id] = true
        end
    end

    round = round or { id = data.roundId }
    round.available, round.total, round.collected = available, data.totalHouses, data.currentHouses
    round.remaining, round.synced = data.timeRemaining, GetGameTimer()

    for id, blip in pairs(blips) do
        if not available[id] then
            RemoveBlip(blip)
            blips[id] = nil
            deletePumpkin(id)
        end
    end

    for id in pairs(loading) do
        if not available[id] then
            loading[id] = nil
        end
    end

    for id in pairs(available) do
        if not blips[id] then
            local coords = settings.houses[id].coords
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

            SetBlipAsShortRange(blip, false)
            SetBlipSprite(blip, settings.blips.sprite)
            SetBlipColour(blip, settings.blips.activeColor)
            SetBlipScale(blip, settings.blips.scale)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString('Trick-or-Treat Pumpkin')
            EndTextCommandSetBlipName(blip)
            blips[id] = blip
        end
    end

    if not same then
        Halloween.SyncRoundUI()
    else
        SendNUIMessage({
            type = 'trickOrTreatProgress',
            currentHouses = round.collected,
            totalHouses = round.total,
            timeRemaining = timeRemaining(),
        })
    end
end

RegisterNetEvent(Events.ROUND_START, function(data)
    if source == 65535 then
        sync(data)
    end
end)

RegisterNetEvent(Events.HOUSE_STATE_SYNC, function(data)
    if source == 65535 then
        sync(data)
    end
end)

RegisterNetEvent(Events.ROUND_END, function(data)
    if source ~= 65535 or type(data) ~= 'table' or not Halloween.IsNumber(data.roundId) then
        return
    end

    endedRound = math.max(endedRound, data.roundId)

    if round and round.id <= data.roundId then
        clear()
    end
end)

local function canInteract(id)
    return round
        and round.available[id]
        and pumpkins[id]
        and DoesEntityExist(pumpkins[id])
        and not ESX.PlayerData.dead
        and not IsEntityDead(PlayerPedId())
        and not Halloween.ClientGhost()
        and #(GetEntityCoords(PlayerPedId()) - settings.houses[id].coords)
            <= settings.interaction.distance
end

RegisterNetEvent(Events.HOUSE_INTERACT_RESPONSE, function(data)
    if source ~= 65535 or type(data) ~= 'table' then
        return
    end

    local pending = interaction

    if
        not pending
        or not round
        or data.roundId ~= round.id
        or data.houseId ~= pending.id
        or not Halloween.IsInteger(data.token, 1, 9007199254740991)
        or not Halloween.IsNumber(data.duration)
        or data.duration ~= settings.interaction.duration
    then
        return
    end

    pending.token, pending.started = data.token, GetGameTimer()
    CreateThread(function()
        while
            interaction == pending
            and canInteract(pending.id)
            and Halloween.Elapsed(pending.started) < data.duration
        do
            Wait(50)
        end

        if interaction ~= pending then
            return
        end

        if not canInteract(pending.id) then
            interaction = nil
            return
        end

        pending.started = GetGameTimer()
        TriggerServerEvent(Events.HOUSE_COLLECT_REQUEST, pending.id, pending.roundId, pending.token)
    end)
end)

RegisterNetEvent(Events.HOUSE_COLLECT_RESPONSE, function(data)
    if source ~= 65535 or type(data) ~= 'table' or type(data.success) ~= 'boolean' then
        return
    end

    local pending = interaction

    if data.success then
        if
            not pending
            or pending.id ~= data.houseId
            or pending.roundId ~= data.roundId
            or (data.rewardType ~= 'treat' and data.rewardType ~= 'trick')
            or type(data.rewardItem) ~= 'string'
            or not Halloween.IsInteger(data.rewardAmount, 0, 100)
        then
            return
        end

        SendNUIMessage({
            type = 'trickOrTreatCollect',
            rewardType = data.rewardType,
            rewardItem = data.rewardItem,
            rewardAmount = data.rewardAmount,
        })
    elseif pending and type(data.error) == 'string' then
        ESX.ShowNotification(data.error)
    end

    interaction = nil
end)

RegisterNetEvent(Events.TRIGGER_TRICK, function(data)
    if
        source ~= 65535
        or type(data) ~= 'table'
        or not interaction
        or data.token ~= interaction.token
        or data.roundId ~= interaction.roundId
        or type(data.effects) ~= 'table'
    then
        return
    end

    for _, effect in ipairs(data.effects) do
        if effect == 'jumpscare' then
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.3)
            SendNUIMessage({ type = 'triggerJumpscare', soundVolume = 0.7, duration = 1500 })
        elseif
            effect == 'small_damage'
            and Halloween.IsInteger(data.damage, 0, 20)
            and not ESX.PlayerData.dead
        then
            local ped = PlayerPedId()

            SetEntityHealth(ped, math.max(101, GetEntityHealth(ped) - data.damage))
        end
    end
end)

CreateThread(function()
    local uiAt = GetGameTimer()

    while true do
        Wait(500)

        local state = round

        nearest = nil

        if state then
            if timeRemaining() == 0 then
                endedRound = math.max(endedRound, state.id)
                clear()
            else
                local coords, closest =
                    GetEntityCoords(PlayerPedId()), settings.interaction.distance

                for id in pairs(state.available) do
                    local distance = #(coords - settings.houses[id].coords)

                    if distance < closest then
                        nearest, closest = id, distance
                    end

                    if
                        distance <= settings.npcSpawnDistance
                        and not pumpkins[id]
                        and not loading[id]
                        and (not failures[id] or Halloween.Elapsed(failures[id]) >= 10000)
                    then
                        spawnPumpkin(id, state)
                    elseif distance > settings.npcDespawnDistance then
                        deletePumpkin(id)
                    end
                end

                if Halloween.Elapsed(uiAt) >= 1000 then
                    uiAt = GetGameTimer()
                    SendNUIMessage({
                        type = 'trickOrTreatProgress',
                        currentHouses = state.collected,
                        totalHouses = state.total,
                        timeRemaining = timeRemaining(),
                    })
                end
            end
        end

        if
            interaction
            and Halloween.Elapsed(interaction.started) >= settings.interaction.requestTimeout
        then
            interaction = nil
        end
    end
end)

CreateThread(function()
    while true do
        if nearest and canInteract(nearest) then
            Wait(0)
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentString(
                interaction and 'Looting pumpkin...' or 'Press ~INPUT_CONTEXT~ to loot pumpkin'
            )
            EndTextCommandDisplayHelp(0)

            if not interaction and IsControlJustReleased(0, settings.interaction.key) then
                interaction = { id = nearest, roundId = round.id, started = GetGameTimer() }
                TriggerServerEvent(Events.HOUSE_INTERACT_REQUEST, nearest, round.id)
            end
        else
            Wait(250)
        end
    end
end)

AddEventHandler('esx:onPlayerLogout', clear)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    stopping = true
    clear()
end)
