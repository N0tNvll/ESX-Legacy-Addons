-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

-- Existing settings/coordinates remain the input of this read-only configuration adapter.
-- New dealerships need only an entry here; runtime logic never switches the global Zones table.
Config.LegacyDealershipId = Config.LegacyDealershipId or 'cars'
Config.Dealerships = Config.Dealerships
    or {
        cars = {
            label = 'Premium Deluxe Motorsport',
            mode = Config.EnablePlayerManagement and 'managed' or 'public',
            coords = Config.Zones.ShopEntering.Pos,
            preview = vector4(
                Config.Zones.ShopInside.Pos.x,
                Config.Zones.ShopInside.Pos.y,
                Config.Zones.ShopInside.Pos.z,
                Config.Zones.ShopInside.Heading
            ),
            delivery = {
                mode = 'spawn',
                coords = vector4(
                    Config.Zones.ShopOutside.Pos.x,
                    Config.Zones.ShopOutside.Pos.y,
                    Config.Zones.ShopOutside.Pos.z,
                    Config.Zones.ShopOutside.Heading
                ),
                garage = 'san_andreas_avenue',
            },
            managementPoint = Config.Zones.BossActions.Pos,
            resalePoint = Config.Zones.ResellVehicle.Pos,
            returnPoint = Config.Zones.GiveBackVehicle.Pos,
            vehicleTypes = { 'car', 'motorcycle', 'bicycle', 'truck', 'emergency' },
            catalog = 'civilian',
            paymentMethods = { 'money', 'bank' },
            license = Config.LicenseEnable and 'drive' or nil,
            management = { job = 'cardealer', minGrade = 0, bossGrades = { boss = true } },
            societyAccount = 'society_cardealer',
            societyInventory = 'society_cardealer',
            stockMode = Config.EnablePlayerManagement and 'limited' or 'unlimited',
            rentals = {
                enabled = Config.EnablePlayerManagement,
                multiplier = Config.RentalPriceMultiplier,
                minimum = Config.MinimumRentalPrice,
            },
            resale = { enabled = true, percentage = Config.ResellPercentage },
            blip = {
                enabled = Config.Blip.show,
                sprite = Config.Blip.Sprite,
                scale = Config.Blip.Scale,
                color = 3,
            },
            color = '#ffac00',
        },
        boats = {
            label = 'Marina Boat Shop',
            mode = 'public',
            coords = vector3(-773.7, -1495.2, 1.6),
            preview = vector4(-798.5, -1503.1, -0.4, 120.0),
            license = 'boat',
            licensePrice = 50000,
            offers = {
                { model = 'seashark', label = 'Seashark (Random Color)', price = 7500 },
                { model = 'seashark3', label = 'Seashark (Dark Blue)', price = 7500 },
                { model = 'suntrap', label = 'Suntrap', price = 10000 },
                { model = 'jetmax', label = 'Jetmax', price = 45000 },
                { model = 'tropic2', label = 'Tropic', price = 65000 },
                { model = 'dinghy2', label = 'Dinghy (Black)', price = 32500 },
                { model = 'dinghy', label = 'Dinghy 2 (Random Color)', price = 40000 },
                { model = 'speeder', label = 'Speeder', price = 85000 },
                { model = 'squalo', label = 'Squalo (Random Color)', price = 61000 },
                { model = 'toro', label = 'Toro', price = 200000 },
                { model = 'submersible', label = 'Submersible', price = 750000 },
            },
            catalog = 'marine',
            vehicleTypes = { 'boat' },
            paymentMethods = { 'money', 'bank' },
            delivery = { mode = 'garage', garage = 'boat_port_1' },
            stockMode = 'unlimited',
            blip = { enabled = true, sprite = 427, scale = 0.8, color = 3 },
            color = '#4bc0e5',
        },
        helicopters = {
            enabled = false,
            label = 'Vespucci Helicopters',
            mode = 'public',
            catalog = 'helicopters',
            coords = vector3(-745.5, -1468.6, 5.0),
            preview = vector4(-724.7, -1444.0, 5.0, 140.0),
            delivery = { mode = 'garage', garage = 'civil_helipad' },
            vehicleTypes = { 'helicopter' },
            paymentMethods = { 'money', 'bank' },
            stockMode = 'unlimited',
            offers = {
                {
                    model = 'maverick',
                    name = 'Maverick',
                    price = 240000,
                    category = 'helicopters',
                    type = 'helicopter',
                },
            },
            blip = { enabled = true, sprite = 43, scale = 0.8, color = 3 },
        },
        aircraft = {
            enabled = false,
            label = 'LSIA Aircraft',
            mode = 'public',
            catalog = 'aircraft',
            coords = vector3(-1617.1, -3154.0, 13.9),
            preview = vector4(-1656.0, -3144.0, 13.9, 330.0),
            delivery = { mode = 'garage', garage = 'civil_hangar' },
            vehicleTypes = { 'plane' },
            paymentMethods = { 'money', 'bank' },
            stockMode = 'unlimited',
            offers = {
                {
                    model = 'mammatus',
                    name = 'Mammatus',
                    price = 320000,
                    category = 'aircraft',
                    type = 'plane',
                },
            },
            blip = { enabled = true, sprite = 90, scale = 0.8, color = 3 },
        },
    }

VehicleShopTypes = {
    car = 'ground',
    motorcycle = 'ground',
    bicycle = 'ground',
    truck = 'ground',
    emergency = 'ground',
    boat = 'boat',
    helicopter = 'helicopter',
    plane = 'plane',
}
