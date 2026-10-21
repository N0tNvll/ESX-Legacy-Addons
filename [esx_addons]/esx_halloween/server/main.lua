CreateThread(function()
    local started = GetGameTimer()

    while not Halloween.ValidateItems() do
        if Halloween.Elapsed(started) >= 30000 then
            Config.TrickOrTreat.enabled = false
            Halloween.TrickOrTreatCatalogDisabled = true
            print(
                ('[esx_halloween] %s Trick-or-treat disabled.'):format(
                    Halloween.TrickOrTreatDisabledReason or 'Inventory catalog unavailable.'
                )
            )
            break
        end

        Wait(500)
    end

    Halloween.Ready = true
    print(('[esx_halloween] Ready (config corrections: %d).'):format(Halloween.ConfigWarnings))
end)

RegisterNetEvent(Events.REQUEST_SNAPSHOT, function()
    local src = source

    if not Halloween.Allow(src, 'snapshot', 5000) then
        return
    end

    Halloween.SyncGhosts(src)
    Halloween.SyncRound(src)
end)
