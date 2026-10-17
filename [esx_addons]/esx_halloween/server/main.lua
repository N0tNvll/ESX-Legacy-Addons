CreateThread(function()
    local started = GetGameTimer()
    while not Halloween.ValidateItems() do
        if Halloween.Elapsed(started) >= 30000 then
            Config.TrickOrTreat.enabled = false
            print('[esx_halloween] Inventory catalog unavailable; trick-or-treat disabled.')
            break
        end
        Wait(500)
    end
    Halloween.Ready = true
    print(('[esx_halloween] Ready (config corrections: %d).'):format(Halloween.ConfigWarnings))
end)

RegisterNetEvent(Events.REQUEST_SNAPSHOT, function()
    local src = source
    if not Halloween.Allow(src, 'snapshot', 5000) then return end
    Halloween.SyncGhosts(src)
    Halloween.SyncRound(src)
end)
