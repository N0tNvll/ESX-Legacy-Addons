-- SPDX-License-Identifier: GPL-3.0-only

Config = {}

Config.DrawDistance = 18.0
Config.MarkerType = 1
Config.MarkerSize = vector3(1.5, 1.5, 0.6)
Config.MarkerColor = { r = 251, g = 155, b = 4, a = 130 }
Config.ActionCooldown = 1200

Config.Text = {
    startShift = 'Press ~INPUT_PICKUP~ to start your shift.',
    endShift = 'Press ~INPUT_PICKUP~ to end your shift.',
    doAction = 'Press ~INPUT_PICKUP~ to work here.',
    wrongJob = 'You need this job to work here.',
    shiftStarted = 'Shift started. Follow the route on your GPS.',
    shiftEnded = 'Shift ended.',
    vehicleNeeded = 'Your work vehicle must be nearby.',
    spawnBlocked = 'The vehicle spawn point is blocked.',
    alreadyWorking = 'You are already on shift.',
    notWorking = 'You are not on shift.',
    actionPaid = 'Task complete. You earned $%s.',
}

Config.Jobs = {
    miner = {
        label = 'Miner',
        grade = 'Quarry Crew',
        blip = { sprite = 68, color = 47, scale = 0.8 },
        start = vector3(892.35, -2172.77, 32.28),
        tasks = {
            {
                id = 'extract',
                title = 'Extract mineral rock',
                description = 'Break rocks from active quarry veins.',
                target = 40,
            },
            {
                id = 'process',
                title = 'Process raw ore',
                description = 'Wash and separate usable material.',
                target = 20,
            },
            {
                id = 'deliver',
                title = 'Deliver processed sacks',
                description = 'Take sealed sacks to the buyer.',
                target = 10,
            },
        },
        actions = {
            {
                id = 'extract',
                label = 'Break mineral vein',
                pay = 95,
                duration = 5500,
                scenario = 'WORLD_HUMAN_HAMMERING',
                points = {
                    vector3(2954.26, 2786.23, 41.42),
                    vector3(2971.91, 2776.02, 38.38),
                    vector3(2991.61, 2752.37, 43.04),
                },
            },
            {
                id = 'process',
                label = 'Wash raw ore',
                pay = 130,
                duration = 6500,
                scenario = 'WORLD_HUMAN_BUM_WASH',
                points = {
                    vector3(289.24, 2862.90, 43.64),
                    vector3(281.27, 2866.16, 43.64),
                },
            },
            {
                id = 'deliver',
                label = 'Deliver sealed sacks',
                pay = 260,
                duration = 4500,
                scenario = 'WORLD_HUMAN_CLIPBOARD',
                points = {
                    vector3(-169.48, -2659.16, 6.00),
                    vector3(-148.78, -1040.38, 27.27),
                },
            },
        },
    },

    delivery = {
        label = 'Delivery Driver',
        grade = 'Parcel Route',
        blip = { sprite = 478, color = 47, scale = 0.8 },
        start = vector3(-424.23, -2789.84, 6.00),
        vehicle = {
            model = 'burrito3',
            spawn = vector3(-435.91, -2796.66, 6.00),
            heading = 45.0,
            requiredDistance = 35.0,
        },
        tasks = {
            {
                id = 'load',
                title = 'Load delivery van',
                description = 'Scan and load parcels at the warehouse.',
                target = 10,
            },
            {
                id = 'deliver',
                title = 'Complete doorstep deliveries',
                description = 'Carry parcels to assigned addresses.',
                target = 10,
            },
            {
                id = 'return',
                title = 'Return delivery manifest',
                description = 'Close the route back at the warehouse.',
                target = 5,
            },
        },
        actions = {
            {
                id = 'load',
                label = 'Load parcels',
                pay = 80,
                duration = 4500,
                scenario = 'PROP_HUMAN_BUM_BIN',
                points = { vector3(-424.23, -2789.84, 6.00) },
            },
            {
                id = 'deliver',
                label = 'Deliver parcel',
                pay = 185,
                duration = 5000,
                requiresVehicle = true,
                scenario = 'WORLD_HUMAN_CLIPBOARD',
                points = {
                    vector3(-41.08, -58.59, 63.33),
                    vector3(309.61, -177.36, 58.02),
                    vector3(1207.41, -620.30, 66.44),
                    vector3(-1098.16, -345.75, 37.80),
                    vector3(-1505.44, -301.18, 49.68),
                },
            },
            {
                id = 'return',
                label = 'Return route manifest',
                pay = 240,
                duration = 3500,
                requiresVehicle = true,
                scenario = 'WORLD_HUMAN_CLIPBOARD',
                points = { vector3(-424.23, -2789.84, 6.00) },
            },
        },
    },

    garbage = {
        label = 'Sanitation Worker',
        grade = 'City Route',
        blip = { sprite = 318, color = 47, scale = 0.8 },
        start = vector3(485.14, -1306.16, 29.25),
        vehicle = {
            model = 'trash2',
            spawn = vector3(475.13, -1313.81, 29.21),
            heading = 300.0,
            requiredDistance = 40.0,
        },
        tasks = {
            {
                id = 'collect',
                title = 'Collect public trash bags',
                description = 'Pull bags from assigned collection points.',
                target = 20,
            },
            {
                id = 'compact',
                title = 'Compact truck load',
                description = 'Secure the load before leaving the block.',
                target = 10,
            },
            {
                id = 'dump',
                title = 'Dump at landfill',
                description = 'Empty the truck at the city landfill.',
                target = 5,
            },
        },
        actions = {
            {
                id = 'collect',
                label = 'Collect trash bags',
                pay = 110,
                duration = 5200,
                requiresVehicle = true,
                scenario = 'PROP_HUMAN_BUM_BIN',
                points = {
                    vector3(114.78, -1462.31, 29.30),
                    vector3(-6.77, -1566.64, 29.29),
                    vector3(-349.22, -1569.81, 25.23),
                    vector3(-536.72, -1719.45, 19.31),
                    vector3(287.11, -1812.85, 27.06),
                },
            },
            {
                id = 'compact',
                label = 'Compact truck load',
                pay = 95,
                duration = 4200,
                requiresVehicle = true,
                scenario = 'WORLD_HUMAN_WELDING',
                points = {
                    vector3(485.14, -1306.16, 29.25),
                    vector3(489.66, -1331.28, 29.33),
                },
            },
            {
                id = 'dump',
                label = 'Dump landfill load',
                pay = 340,
                duration = 7000,
                requiresVehicle = true,
                scenario = 'WORLD_HUMAN_CLIPBOARD',
                points = { vector3(-591.42, -1606.29, 27.01) },
            },
        },
    },
}
