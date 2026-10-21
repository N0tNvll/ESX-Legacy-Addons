RegisterCommand('ghost', function(src, args)
    if not Halloween.HasAdminPermission(src) then
        Halloween.Message(src, 'No permission')
        return
    end

    local target = args[1] and tonumber(args[1]) or src

    if not Halloween.Player(target) then
        Halloween.Message(src, 'Player not found')
        return
    end

    if not Halloween.OfferGhost(target, true) then
        Halloween.Message(src, 'Ghost mode unavailable or normal respawn is not ready yet')
        return
    end

    Halloween.Message(src, 'Ghost choice offered')
end, false)
