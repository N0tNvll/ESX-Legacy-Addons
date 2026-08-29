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
