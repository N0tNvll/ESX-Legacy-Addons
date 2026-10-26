fx_version 'cerulean'
game 'gta5'
use_experimental_fxv2_oal 'yes'

description 'ESX Halloween Event - Ghost Mode & Trick-or-Treat'
version '2.1.0'

ui_page 'web/build/index.html'

files {
    'web/build/**/*',
}

shared_script '@es_extended/imports.lua'

shared_scripts {
    'shared/events.lua',
    'types.lua',
    'configs/trickortreat.lua',
    'config.lua',
    'shared/config.lua',
}

client_scripts {
    'client/convars.lua',
    'client/respawn.lua',
    'client/ghost.lua',
    'client/trickortreat.lua',
    'client/main.lua',
}

server_scripts {
    'server/runtime.lua',
    'server/config_validator.lua',
    'server/main.lua',
    'server/ghost.lua',
    'server/trickortreat.lua',
    'server/commands.lua',
}

dependencies {
    'esx_custom_props',
    'es_extended',
    'esx_textui',
    'esx_death',
    'skinchanger',
    '/onesync',
}
