fx_version 'cerulean'
game 'gta5'

author 'ESX Payment Gateway'
description 'Reusable ESX payment-method NUI'
version '1.0.0'

lua54 'yes'

ui_page 'web/dist/index.html'

files {
  'web/dist/index.html',
  'web/dist/assets/*',
}

client_script 'client/main.lua'
server_script 'server/main.lua'

dependency 'es_extended'
