local function unavailable(reason, retry)
    Halloween.TrickOrTreatDisabledReason = reason

    if retry then
        return false
    end

    Config.TrickOrTreat.enabled = false
    Halloween.TrickOrTreatCatalogDisabled = true
    print(('[esx_halloween] %s Trick-or-treat disabled.'):format(reason))
    return true
end

local function readItems(custom)
    if custom == 'ox' then
        if GetResourceState('ox_inventory') ~= 'started' then
            return false
        end

        return pcall(function()
            return exports.ox_inventory:Items()
        end)
    end

    return pcall(ESX.GetItems)
end

function Halloween.ValidateItems()
    local settings = Config.TrickOrTreat

    if not settings.enabled and not Halloween.TrickOrTreatCatalogDisabled then
        return true
    end

    local configOK, custom = pcall(ESX.GetConfig, 'CustomInventory')

    if not configOK then
        return unavailable('Inventory configuration unavailable.', true)
    end

    local ok, items = readItems(custom)

    if not ok or type(items) ~= 'table' or (custom and next(items) == nil) then
        return unavailable('Inventory catalog unavailable.', true)
    end

    local missing, seen = {}, {}

    for _, name in ipairs({ 'candy', 'rareCandy' }) do
        local reward = settings.rewards[name]

        if reward.chance > 0 and not items[reward.item] and not seen[reward.item] then
            seen[reward.item] = true
            missing[#missing + 1] = {
                name = reward.item,
                label = reward.label,
                weight = reward.weight,
                rare = reward.rare,
                canRemove = reward.canRemove,
            }
        end
    end

    if
        #missing > 0
        and settings.autoRegisterItems
        and not custom
        and ESX.IsFunctionReference(ESX.AddItems)
    then
        local registered, err = pcall(ESX.AddItems, missing)

        if not registered then
            print(('[esx_halloween] Reward item registration failed: %s'):format(tostring(err)))
            return unavailable(
                'Reward items could not be registered; check the server console.',
                true
            )
        end

        ok, items = readItems(custom)

        if not ok or type(items) ~= 'table' then
            return unavailable('Inventory catalog unavailable.', true)
        end

        for _, definition in ipairs(missing) do
            if not items[definition.name] then
                return unavailable(
                    ('Reward item "%s" is not registered yet.'):format(definition.name),
                    true
                )
            end

            print(('[esx_halloween] Registered missing reward item "%s".'):format(definition.name))
        end
    else
        for _, definition in ipairs(missing) do
            local hint = custom and ' Register it in your inventory backend.'
                or (
                    settings.autoRegisterItems and ' ESX.AddItems is unavailable.'
                    or ' Automatic registration is disabled.'
                )

            return unavailable(('Unknown reward item "%s".%s'):format(definition.name, hint))
        end
    end

    if Halloween.TrickOrTreatCatalogDisabled then
        settings.enabled = true
    end

    Halloween.TrickOrTreatCatalogDisabled, Halloween.TrickOrTreatDisabledReason = nil, nil
    return true
end
