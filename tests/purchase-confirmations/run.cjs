// SPDX-License-Identifier: GPL-3.0-only
// Run with: node tests/purchase-confirmations/run.cjs /path/to/fengari
const fs = require('node:fs');
const path = require('node:path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(process.argv[2] || 'fengari');
const root = path.resolve(__dirname, '../../[esx_addons]');
const files = {
    drugs: 'esx_drugs/client/main.lua',
    weapons: 'esx_weaponshop/client/modules/nui.lua',
    markers: 'esx_weaponshop/client/modules/markers.lua',
    weaponMain: 'esx_weaponshop/client/main.lua',
    accessories: 'esx_accessories/client/main.lua',
    barber: 'esx_barbershop/client/main.lua',
    clothes: 'esx_clotheshop/client/main.lua',
    boats: 'esx_boat/client/main.lua',
    imports: 'esx_paymentgateway/imports.lua',
};
let source = 'local SOURCES = {}\n';
for (const [name, file] of Object.entries(files)) {
    source += `SOURCES[${JSON.stringify(name)}] = [====[${fs.readFileSync(path.join(root, file), 'utf8')}]====]\n`;
}
const localeFolder = path.join(root, 'esx_vehicleshop/locales');
for (const file of fs.readdirSync(localeFolder).filter(file => file.endsWith('.lua'))) {
    source += `SOURCES[${JSON.stringify('vehicleLocale:' + file.slice(0, -4))}] = [====[${fs.readFileSync(path.join(localeFolder, file), 'utf8')}]====]\n`;
}
source += fs.readFileSync(path.join(__dirname, 'client.lua'), 'utf8');
const state = lauxlib.luaL_newstate();
lualib.luaL_openlibs(state);
try {
    if (lauxlib.luaL_dostring(state, to_luastring(source)) !== lua.LUA_OK) {
        throw new Error(to_jsstring(lua.lua_tostring(state, -1)));
    }
} finally {
    lua.lua_close(state);
}
