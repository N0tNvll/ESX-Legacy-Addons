function Halloween.ValidateItems()
    if not Config.TrickOrTreat.enabled then return true end
    local custom = ESX.GetConfig('CustomInventory')
    local items
    if custom == 'ox' then
        if GetResourceState('ox_inventory') ~= 'started' then return false end
        local ok, result = pcall(function() return exports.ox_inventory:Items() end)
        if not ok then return false end
        items = result
    else
        items = ESX.GetItems()
    end
    if type(items) ~= 'table' or next(items) == nil then return false end
    for _, name in ipairs({ 'candy', 'rareCandy' }) do
        local reward = Config.TrickOrTreat.rewards[name]
        if reward.chance > 0 and not items[reward.item] then
            print(('[esx_halloween] Unknown reward item "%s"; trick-or-treat disabled.'):format(reward.item))
            Config.TrickOrTreat.enabled = false
            break
        end
    end
    return true
end
