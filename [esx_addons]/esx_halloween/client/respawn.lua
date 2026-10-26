-- esx_death exclusively owns respawn, penalties and recovery.
function FadeScreenOut()
    DoScreenFadeOut(500)

    local started = GetGameTimer()

    while not IsScreenFadedOut() and Halloween.Elapsed(started) < 2000 do
        Wait(0)
    end
end

function FadeScreenIn()
    DoScreenFadeIn(500)
end

function Halloween.ResetGhostStats()
    local ped = PlayerPedId()

    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)

    if not ESX.PlayerData.dead then
        SetPlayerInvincible(PlayerId(), false)
        SetEntityInvincible(ped, false)
        SetPedCanRagdoll(ped, true)
    end

    ResetEntityAlpha(ped)
    SetEntityVisible(ped, true, false)
end

function Halloween.CaptureAppearance(cancelled)
    local skin

    TriggerEvent('skinchanger:getSkin', function(value)
        if type(value) ~= 'table' then
            return
        end

        skin = {}

        for key, entry in pairs(value) do
            skin[key] = entry
        end
    end)

    local started = GetGameTimer()

    while not skin and Halloween.Elapsed(started) < 2000 and not cancelled() do
        Wait(0)
    end

    if not skin or cancelled() then
        return nil
    end

    local ped = PlayerPedId()
    local model = GetEntityModel(ped)

    RequestModel(model) -- Keep the original model loaded for synchronous stop cleanup.
    started = GetGameTimer()

    while not HasModelLoaded(model) and Halloween.Elapsed(started) < 3000 and not cancelled() do
        Wait(0)
    end

    if not HasModelLoaded(model) or cancelled() then
        SetModelAsNoLongerNeeded(model)
        return nil
    end

    return { skin = skin, model = model, health = GetEntityHealth(ped), armor = GetPedArmour(ped) }
end

function Halloween.RestoreAppearance(appearance, immediate)
    if not appearance then
        Halloween.ResetGhostStats()
        return
    end

    if not immediate then
        FadeScreenOut()
    end

    if HasModelLoaded(appearance.model) then
        SetPlayerModel(PlayerId(), appearance.model)
        TriggerEvent('skinchanger:loadSkin', appearance.skin)

        -- Do not resurrect a player whose death lifecycle has started meanwhile.
        if not ESX.PlayerData.dead then
            SetEntityHealth(PlayerPedId(), appearance.health)
            SetPedArmour(PlayerPedId(), appearance.armor)

            if not ESX.GetConfig('CustomInventory') then
                TriggerEvent('esx:restoreLoadout')
            end
        end
    end

    Halloween.ResetGhostStats()
    SetModelAsNoLongerNeeded(appearance.model)

    if not immediate then
        FadeScreenIn()
    end
end
