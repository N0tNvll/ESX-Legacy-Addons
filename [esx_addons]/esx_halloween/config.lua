---@type HalloweenConfig
Config = {
    -- Gameplay is restricted to this routing bucket.
    RoutingBucket = 0,
    Ghost = {
        enabled = true,
        spawnChance = 20,
        pedModel = 'u_m_y_zombie_01',
        maxDuration = 600000, -- 10 minutes in milliseconds
        exitKeybind = 'X',

        visibility = {
            range = 25.0, -- Distance in meters
            alpha = 77 -- ~30% opacity (0-255)
        },

        movement = {
            speedMultiplier = 1.49 -- GTA's supported sprint multiplier limit
        },

        abilities = {
            scare = {
                enabled = true,
                cooldown = 30000, -- 30 seconds in milliseconds
                range = 10.0, -- Distance in meters
                keybind = 'E',
                effects = {
                    screenShake = true,
                    sound = true,
                    soundVolume = 0.8,
                    duration = 3000 -- 3 seconds in milliseconds
                }
            }
        },

        -- Security & anti-abuse settings
        security = {
            ghostRequestCooldown = 60000, -- 60 seconds between ghost mode requests
            maxConcurrentGhosts = 10, -- Maximum number of ghosts at once
            deathCooldown = 2000, -- 2 seconds after death before showing ghost choice
            requestTimeout = 15000, -- Model preparation / activation timeout
            offerTimeout = 30000 -- One-use server offer expires after 30 seconds
        }
    },

    -- Trick-or-Treat event configuration (loaded via shared_scripts)
    TrickOrTreat = TrickOrTreatConfig or {},

    -- Admin permissions for /ghost command
    AdminGroups = {
        'admin',
        'superadmin'
    },

    -- esx_death owns hospital selection, waiting periods and death penalties.
}
