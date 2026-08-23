fx_version 'adamant'

game 'gta5'

description 'Allows players to RP as a mechanic (repair and modify vehicles)'
lua54 'yes'
version '1.0'
legacyversion '1.14.1'

shared_scripts {
	'@esx_lib/imports.lua',
	'@es_extended/imports.lua'
}

client_scripts {
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua',
	'client/main.lua'
}

server_scripts {
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua',
	'server/modules/init.lua',
	'server/modules/utils.lua',
	'server/main.lua',
	'server/modules/impound.lua',
	'server/modules/workshop.lua',
	'server/modules/npc_jobs.lua',
	'server/modules/items.lua',
	'server/modules/stock.lua'
}

dependencies {
	'es_extended',
	'esx_society',
	'esx_billing'
}
