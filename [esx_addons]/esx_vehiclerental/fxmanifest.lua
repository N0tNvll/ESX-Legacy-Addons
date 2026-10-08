-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version('cerulean')
game('gta5')
lua54('yes')

description('Prepaid vehicle rentals with server-authoritative contracts')
version('1.0.0')
legacyversion('1.16.0')

ui_page('web/index.html')

shared_scripts({
    '@esx_lib/imports.lua',
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'config.lua',
})

server_scripts({
    '@oxmysql/lib/MySQL.lua',
    'server/state.lua',
    'server/database.lua',
    'server/service.lua',
    'server/main.lua',
})

client_scripts({
    'client/main.lua',
})

files({
    'locales/*.lua',
    'web/index.html',
    'web/styles.css',
    'web/app.js',
    'web/assets/*',
})

dependencies({
    'esx_lib',
    'es_extended',
    'oxmysql',
    '/onesync',
})
