-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {}

Config.Locale = GetConvar('esx:locale', 'en')
Config.Currency = 'USD'
Config.PaymentAccounts = { 'money', 'bank' }
Config.RequireDrivingLicense = false
Config.DrivingLicenseType = 'drive'
Config.InteractDistance = 3.0
Config.ReturnDistance = 6.0
Config.SpawnClearRadius = 3.0
Config.SpawnTimeout = 5000
Config.ExpiryWarningSeconds = 60

-- Rentals are prepaid. Returning early ends the contract without a refund.
-- Time keeps running while disconnected. Retrieve the remaining time at the original branch.
Config.Plans = {
    short = { minutes = 30, multiplier = 1.0 },
    standard = { minutes = 60, multiplier = 0.90 },
    extended = { minutes = 120, multiplier = 0.80 },
}

-- The model, server vehicle type and all prices come exclusively from this configuration.
Config.Vehicles = {
    blista = {
        label = 'Dinka Blista',
        category = 'compact',
        type = 'automobile',
        rate = 12,
        seats = 2,
        image = 'blista.webp',
    },
    dilettante = {
        label = 'Karin Dilettante',
        category = 'compact',
        type = 'automobile',
        rate = 10,
        seats = 4,
        image = 'dilettante.webp',
    },
    premier = {
        label = 'Declasse Premier',
        category = 'sedan',
        type = 'automobile',
        rate = 15,
        seats = 4,
        image = 'premier.webp',
    },
    sultan = {
        label = 'Karin Sultan',
        category = 'sport',
        type = 'automobile',
        rate = 25,
        seats = 4,
        image = 'sultan.webp',
    },
    baller = {
        label = 'Gallivanter Baller',
        category = 'suv',
        type = 'automobile',
        rate = 22,
        seats = 4,
        image = 'baller.webp',
    },
    faggio = {
        label = 'Pegassi Faggio',
        category = 'motorcycle',
        type = 'bike',
        rate = 6,
        seats = 2,
        image = 'faggio.webp',
    },
}

Config.Branches = {
    airport = {
        label = 'Los Santos Airport',
        coords = vector3(-1034.61, -2731.82, 20.17),
        returnCoords = vector3(-1030.35, -2724.31, 20.14),
        bucket = 0,
        vehicles = { 'blista', 'dilettante', 'premier', 'sultan', 'baller', 'faggio' },
        spawns = {
            vector4(-1030.35, -2724.31, 20.14, 240.0),
            vector4(-1027.65, -2727.35, 20.14, 240.0),
        },
        blip = { sprite = 225, color = 47, scale = 0.75 },
    },
    city = {
        label = 'Legion Square',
        coords = vector3(215.86, -810.13, 30.73),
        returnCoords = vector3(223.50, -804.78, 30.57),
        bucket = 0,
        vehicles = { 'blista', 'dilettante', 'premier', 'sultan', 'faggio' },
        spawns = {
            vector4(223.50, -804.78, 30.57, 249.0),
            vector4(225.68, -801.90, 30.56, 249.0),
        },
        blip = { sprite = 225, color = 47, scale = 0.75 },
    },
}
