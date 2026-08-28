Modules = Modules or {}
Modules.Zone = Modules.Zone or {}

Modules.Zone.current = false ---@type Zone | false
Modules.Zone.lastCheck = 0 ---@type integer
Modules.Zone.checkIntervalMs = 500 ---@type integer

---@return Zone
function Modules.Zone.getClosest()
    local now = GetGameTimer()

    if Modules.Zone.current and (now - Modules.Zone.lastCheck) < Modules.Zone.checkIntervalMs then
        return Modules.Zone.current
    end

    local playerCoords = GetEntityCoords(ESX.PlayerData.ped).xy

    local closestZone, closestZoneDistance = nil, nil
    for zone, zoneCoords in pairs(Config.Zones) do
        local currentDistance = #(playerCoords - zoneCoords)
        if (not closestZone or currentDistance < closestZoneDistance) then
            closestZone = zone
            closestZoneDistance = currentDistance
        end
    end

    Modules.Zone.current = closestZone
    Modules.Zone.lastCheck = now

    return closestZone
end