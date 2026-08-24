---@type table
Config.WeaponShopUpgrades = Config.WeaponShopUpgrades or {}

Config.WeaponShopUpgrades.Enabled = true

Config.WeaponShopUpgrades.Ammo = {
	Enabled = true,
	PricePerRound = 5,
	DefaultAmount = 30,
	MinAmount = 1,
	MaxAmount = 250,
	QuickAmounts = { 30, 60, 120, 250 }
}

Config.WeaponShopUpgrades.Components = {
	Enabled = true,
	DefaultPrice = 750,
	Blacklisted = {
		clip_default = true
	},
	Prices = {
		clip_extended = 650,
		flashlight = 250,
		suppressor = 1250,
		scope = 1500,
		scope_holo = 1250,
		scope_small = 1450,
		scope_medium = 1800,
		grip = 900,
		compensator = 850,
		luxary_finish = 1800,
		vip_finish = 2000,
		bodyguard_finish = 2000
	}
}

Config.WeaponShopUpgrades.Tints = {
	Enabled = true,
	DefaultPrice = 350,
	Prices = {
		[0] = 0,
		[1] = 250,
		[2] = 750,
		[3] = 350,
		[4] = 450,
		[5] = 500,
		[6] = 400,
		[7] = 900
	},
	Swatches = {
		[0] = '#9A9A9A',
		[1] = '#3E8F45',
		[2] = '#D6A536',
		[3] = '#D96AA7',
		[4] = '#6C7A45',
		[5] = '#3A6EA5',
		[6] = '#D87522',
		[7] = '#D8DDE2'
	}
}
