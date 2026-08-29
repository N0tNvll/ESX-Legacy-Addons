Config = {}

Config.Locale = GetConvar('esx:locale', 'en')
Config.EnableESXIdentity = true
Config.MaxSalary = 3500
Config.SocietyGarageDistance = 12.0

Config.SocietyGarageZones = {
    mechanic = {
        vector3(-386.899, -105.675, 37.683),
        vector3(-97.5, 6496.1, 31.4)
    },
    taxi = {
        vector3(908.317, -183.070, 73.201),
        vector3(915.039, -162.187, 74.5)
    }
}

Config.BossGrades = { -- Uncomment and/or add additional grades you want to have access to the boss menu.
    ['boss'] = true,
    --['staff1'] = false,
    --['staff2'] = false,
    --['staff3'] = false,
}

Config.UniformSaveCooldown = 30000 -- Minimum delay (ms) between two uniform saves for the same job.
Config.UniformComponents = {
    'tshirt_1', 'tshirt_2', 'torso_1', 'torso_2', 'decals_1', 'decals_2', 'arms', 'arms_2',
    'pants_1', 'pants_2', 'shoes_1', 'shoes_2', 'mask_1', 'mask_2', 'bproof_1', 'bproof_2',
    'chain_1', 'chain_2', 'helmet_1', 'helmet_2', 'glasses_1', 'glasses_2', 'watches_1', 'watches_2',
    'bracelets_1', 'bracelets_2', 'bags_1', 'bags_2', 'ears_1', 'ears_2'
}
