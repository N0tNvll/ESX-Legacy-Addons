---Trick-or-Treat Configuration
---Defines all settings for the trick-or-treating event feature
---@class TrickOrTreatConfig
TrickOrTreatConfig = {
    ---Enable/disable the trick-or-treat event feature
    enabled = true,
    ---Create missing reward items through ESX.AddItems (default ESX inventory only)
    autoRegisterItems = true,

    ---Pause between rounds, independent of round duration
    roundFrequencyMinutes = 5,
    roundDurationMinutes = 5,
    progressSyncInterval = 15000,
    ---Custom prop streamed by esx_custom_props (upstream PR #94)
    pumpkinModel = 'esx_jackolantern',
    ---Legacy option names retained for the pumpkin streaming distances
    npcSpawnDistance = 60.0,
    npcDespawnDistance = 80.0,

    ---Number of random houses selected per round
    doorsPerRound = 12,

    ---Notification display settings
    notifications = {
        ---Duration in ms to show round start notification
        roundStart = 10000,
        ---Duration in ms to show house empty notification
        houseEmpty = 5000,
    },

    ---Map blip/marker settings for active houses
    blips = {
        ---Blip color for active houses (27 = orange)
        activeColor = 27,
        ---Blip sprite for candy icon (280 = candy)
        sprite = 280,
        ---Blip scale/size
        scale = 0.8,
    },

    ---Reward probability distribution (chances must sum to 100)
    rewards = {
        ---Common treat reward
        candy = {
            item = 'medikit',
            label = 'Medikit',
            weight = 2,
            amount = 3,
            chance = 70, -- 70% chance
        },
        ---Rare treat reward
        rareCandy = {
            item = 'diamond',
            label = 'Diamond',
            weight = 1,
            amount = 1,
            chance = 15, -- 15% chance
        },
        ---Trick/negative effect (no item, but effects)
        trick = {
            chance = 15, -- 15% chance
            effects = { 'jumpscare', 'small_damage' },
            damage = 10,
        },
    },

    ---Player interaction settings
    interaction = {
        ---Maximum distance to loot a pumpkin at the house
        distance = 2.0,
        tolerance = 0.5,
        duration = 1500,
        requestTimeout = 7000,
        minimumTravelSeconds = 2,
        maxTravelSpeed = 120.0,
        travelAllowance = 30.0,
        ---Keybind for interaction (38 = E key)
        key = 38,
    },

    ---House locations for trick-or-treating (xyz coordinates and heading)
    ---These are real Los Santos residential locations from across the map
    houses = {
        { coords = vec3(-178.37246704102,502.0654296875,135.8270111084),   heading = 270.0 }, 
        { coords = vec3(-687.14166259766,595.67144775391,142.64710998535), heading = 315.0 },
        { coords = vec3(-888.4541015625,700.06134033203,149.69592285156),  heading = 270.0 }, 
        { coords = vec3(-910.33557128906,693.93438720703,150.4351348877),  heading = 270.0 },
        { coords = vec3(-1292.7266845703,454.37738037109,96.672241210938), heading = 270.0 }, 
        { coords = vec3(-1405.6368408203,528.28857421875,122.8362121582),  heading = 360.0 }, 
        { coords = vec3(-1518.7095947266,852.43664550781,180.59475708008), heading = 270.0 }, 
        { coords = vec3(-1922.9255371094,161.28923034668,83.602005004883), heading = 180.0 }, 
        { coords = vec3(-1960.7307128906,211.09573364258,85.807815551758), heading = 220.0 }, 
        { coords = vec3(1267.5646972656,-648.51525878906,66.856468200684), heading = 270.0 },
        { coords = vec3(1011.9693603516,-424.53192138672,63.957683563232), heading = 220.0 },
        { coords = vec3(1028.9694824219,-411.6432800293,64.949264526367),  heading = 120.0 },
        { coords = vec3(-1464.1306152344,-703.89886474609,25.790525436401),heading = 90.0 },
        { coords = vec3(-543.88671875,-203.47373962402,37.220127105713),   heading = 90.0 },
        { coords = vec3(-264.23968505859,-971.16247558594,30.219585418701),heading = 90.0 },
        { coords = vec3(125.44569396973,-1930.5848388672,20.382429122925), heading = 290.0 },
        { coords = vec3(85.39673614502,-1959.9094238281,20.126684188843),  heading = 280.0 },
        { coords = vec3(1662.1208496094,3819.0009765625,34.47473526001),   heading = 220.0 },
        { coords = vec3(1687.0096435547,4818.8173828125,40.990341186523),  heading = 380.0 },
        { coords = vec3(-131.72650146484,6377.767578125,31.180015563965),  heading = 320.0 },
        { coords = vec3(-166.20640563965,6388.0239257812,30.486497879028), heading = 120.0 },
    },
}
