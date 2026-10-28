-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config               = {}

Config.Locale = GetConvar('esx:locale', 'en')

Config.LicenseEnable = true -- enable boat license? Requires esx_license
Config.LicensePrice  = 50000

Config.MarkerType    = 1
Config.DrawDistance  = 10.0

Config.Marker = {
	r = 100, g = 204, b = 100, -- blue-ish color
	x = 1.5, y = 1.5, z = 1.0  -- standard size circle
}

Config.Zones = {

	-- Boat garages are configured in esx_garage. Shops remain here.


	BoatShops = {
		{ -- Shank St, nearby campaign boat garage
			Outside = vector3(-773.7, -1495.2, 1.6),
			Inside = vector4(-798.5, -1503.1, -0.4, 120.0)
		}
	}

}

Config.Vehicles = {
	{model = 'seashark', label = 'Seashark (Random Color)', price = 7500},
	{model = 'seashark3', label = 'Seashark (Dark Blue)', price = 7500},
	{model = 'suntrap', label = 'Suntrap', price = 10000},
	{model = 'jetmax', label = 'Jetmax', price = 45000},
	{model = 'tropic2', label = 'Tropic', price = 65000},
	{model = 'dinghy2', label = 'Dinghy (Black)', price = 32500},
	{model = 'dinghy', label = 'Dinghy 2 (Random Color)', price = 40000},
	{model = 'speeder', label = 'Speeder', price = 85000},
	{model = 'squalo', label = 'Squalo (Random Color)', price = 61000},
	{model = 'toro', label = 'Toro', price = 200000},
	{model = 'submersible', label = 'Submersible', price = 750000}
}
