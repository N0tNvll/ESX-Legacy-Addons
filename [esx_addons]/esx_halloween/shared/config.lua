Halloween = {}

function Halloween.IsNumber(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

function Halloween.IsInteger(value, minimum, maximum)
    return Halloween.IsNumber(value) and value % 1 == 0 and value >= minimum and value <= maximum
end

function Halloween.Elapsed(since)
    return (GetGameTimer() - since) % 4294967296
end

local warnings = 0
local function warn(path)
    warnings = warnings + 1
    if IsDuplicityVersion() then
        print(('[esx_halloween] Invalid %s; corrected or feature disabled.'):format(path))
    end
end

local function object(parent, key)
    if type(parent[key]) ~= 'table' then warn(key); parent[key] = {} end
    return parent[key]
end

local function number(parent, key, default, low, high, integer)
    local value = parent[key]
    if not Halloween.IsNumber(value) or value < low or value > high or (integer and value % 1 ~= 0) then
        if value ~= nil then warn(key) end
        parent[key] = default
    end
end

local function boolean(parent, key, default)
    if type(parent[key]) ~= 'boolean' then
        if parent[key] ~= nil then warn(key) end
        parent[key] = default
    end
end

if type(Config) ~= 'table' then warn('Config'); Config = {} end
number(Config, 'RoutingBucket', 0, 0, 2147483647, true)
local ghost = object(Config, 'Ghost')
boolean(ghost, 'enabled', false)
number(ghost, 'spawnChance', 20, 0, 100, true)
number(ghost, 'maxDuration', 600000, 1000, 3600000, true)
if type(ghost.pedModel) ~= 'string' or #ghost.pedModel == 0 or #ghost.pedModel > 64 then
    warn('Ghost.pedModel'); ghost.pedModel = 'u_m_y_zombie_01'
end
local keys = { X = true, E = true, DELETE = true, BACKSPACE = true }
if not keys[ghost.exitKeybind] then ghost.exitKeybind = 'X' end
local visibility = object(ghost, 'visibility')
number(visibility, 'range', 25.0, 1, 100)
number(visibility, 'alpha', 77, 0, 255, true)
number(object(ghost, 'movement'), 'speedMultiplier', 1.49, 1.0, 1.49)
local scare = object(object(ghost, 'abilities'), 'scare')
boolean(scare, 'enabled', false)
number(scare, 'cooldown', 30000, 1000, 3600000, true)
number(scare, 'range', 10.0, 1, 50)
if not keys[scare.keybind] then scare.keybind = 'E' end
local effects = object(scare, 'effects')
boolean(effects, 'screenShake', true)
boolean(effects, 'sound', true)
number(effects, 'soundVolume', 0.8, 0, 1)
number(effects, 'duration', 3000, 500, 10000, true)
local security = object(ghost, 'security')
number(security, 'ghostRequestCooldown', 60000, 1000, 3600000, true)
number(security, 'maxConcurrentGhosts', 10, 1, 128, true)
number(security, 'deathCooldown', 2000, 0, 60000, true)
number(security, 'requestTimeout', 15000, 5000, 30000, true)
number(security, 'offerTimeout', 30000, 5000, 60000, true)

local treat = object(Config, 'TrickOrTreat')
boolean(treat, 'enabled', false)
number(treat, 'roundFrequencyMinutes', 5, 1, 1440)
number(treat, 'roundDurationMinutes', 5, 1, 60)
number(treat, 'doorsPerRound', 12, 1, 100, true)
number(treat, 'progressSyncInterval', 15000, 5000, 60000, true)
number(treat, 'npcSpawnDistance', 60.0, 10, 150)
number(treat, 'npcDespawnDistance', math.max(80.0, treat.npcSpawnDistance + 20), treat.npcSpawnDistance + 1, 200)
local blips = object(treat, 'blips')
number(blips, 'sprite', 280, 1, 1000, true)
number(blips, 'activeColor', 27, 0, 85, true)
number(blips, 'scale', 0.8, 0.1, 2)
local notifications = object(treat, 'notifications')
number(notifications, 'roundStart', 10000, 1000, 30000, true)
number(notifications, 'houseEmpty', 5000, 1000, 30000, true)
local interaction = object(treat, 'interaction')
number(interaction, 'distance', 2.0, 1, 5)
number(interaction, 'tolerance', 0.5, 0, 1)
number(interaction, 'key', 38, 0, 360, true)
number(interaction, 'duration', 1500, 500, 5000, true)
number(interaction, 'requestTimeout', 7000, interaction.duration + 1000, 15000, true)
number(interaction, 'minimumTravelSeconds', 2, 0, 30)
number(interaction, 'maxTravelSpeed', 120.0, 10, 200)
number(interaction, 'travelAllowance', 30.0, 0, 100)

local houses = object(treat, 'houses')
local validHouses = #houses > 0 and #houses <= 1000
local houseCount = 0
for index in pairs(houses) do
    houseCount = houseCount + 1
    if not Halloween.IsInteger(index, 1, #houses) then validHouses = false end
end
if houseCount ~= #houses then validHouses = false end
for _, house in ipairs(houses) do
    local ok = type(house) == 'table' and pcall(function()
        assert(Halloween.IsNumber(house.coords.x) and Halloween.IsNumber(house.coords.y)
            and Halloween.IsNumber(house.coords.z))
        assert(math.abs(house.coords.x) < 20000 and math.abs(house.coords.y) < 20000
            and math.abs(house.coords.z) < 5000)
        assert(Halloween.IsNumber(house.heading))
        assert(type(house.pedModel) == 'string' and #house.pedModel > 0 and #house.pedModel <= 64)
        house.coords = vector3(house.coords.x, house.coords.y, house.coords.z)
    end)
    if not ok then validHouses = false end
end
local rewards = object(treat, 'rewards')
local total, validRewards = 0, true
for _, key in ipairs({ 'candy', 'rareCandy', 'trick' }) do
    local reward = object(rewards, key)
    if not Halloween.IsInteger(reward.chance, 0, 100) then
        validRewards = false
    else
        total = total + reward.chance
    end
    if key ~= 'trick' then
        if type(reward.item) ~= 'string' or not reward.item:match('^[%w_%-]+$')
            or #reward.item > 64 or not Halloween.IsInteger(reward.amount, 1, 100) then
            validRewards = false
        end
    end
end
number(rewards.trick, 'damage', 10, 0, 20, true)
if type(rewards.trick.effects) ~= 'table' then
    rewards.trick.effects = { 'jumpscare', 'small_damage' }
end
local selectedEffects, effectSet = {}, {}
for _, effect in ipairs(rewards.trick.effects) do
    if (effect == 'jumpscare' or effect == 'small_damage') and not effectSet[effect] then
        selectedEffects[#selectedEffects + 1], effectSet[effect] = effect, true
    end
end
rewards.trick.effects = selectedEffects
if not validHouses or not validRewards or total ~= 100 then
    warn('TrickOrTreat.houses/rewards'); treat.enabled = false
end
if type(Config.AdminGroups) ~= 'table' then Config.AdminGroups = {} end
Halloween.ConfigWarnings = warnings
