// SPDX-License-Identifier: GPL-3.0-only
// node tests/upstream-prs/run.cjs /absolute/path/to/fengari
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const runtime = require(process.argv[2] || 'fengari');
const { readLocale, placeholders } = require('./locales.cjs');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = runtime;
const root = path.resolve(__dirname, '../../[esx_addons]');
const resources = ['esx_accessorymanager', 'esx_adminmenu', 'esx_ambulancejob', 'esx_animations', 'esx_banking', 'esx_barbershop', 'esx_basicneeds', 'esx_billing', 'esx_boat', 'esx_clotheshop', 'esx_cruisecontrol', 'esx_death', 'esx_dmvschool', 'esx_drugs', 'esx_garage', 'esx_hud', 'esx_joblisting', 'esx_jobs', 'esx_lscustom', 'esx_mechanicjob', 'esx_optionalneeds', 'esx_pausemenu', 'esx_policejob', 'esx_property', 'esx_rpchat', 'esx_society', 'esx_taxijob', 'esx_vehicleshop', 'esx_weaponshop'];
for (const resource of resources) {
    const english = readLocale(runtime, fs.readFileSync(path.join(root, resource, 'locales/en.lua'), 'utf8'), 'en');
    const hungarian = readLocale(runtime, fs.readFileSync(path.join(root, resource, 'locales/hu.lua'), 'utf8'), 'hu');
    for (const [key, value] of Object.entries(english)) {
        assert.equal(typeof hungarian[key], 'string', `${resource}: missing Hungarian ${key}`);
        assert.deepEqual(placeholders(hungarian[key]), placeholders(value), `${resource}: incompatible format for ${key}`);
    }
}
console.log(`PASS ${resources.length} Hungarian locale tables: all current English keys and format parameters`);
const files = {
    workshop: 'esx_mechanicjob/server/modules/workshop.lua',
    accessories: 'esx_accessories/client/main.lua',
    dmv: 'esx_dmvschool/client/main.lua',
    taxi: 'esx_taxijob/client/main.lua',
    drugs: 'esx_drugs/client/main.lua',
    weed: 'esx_drugs/client/weed.lua',
    pause: 'esx_pausemenu/client.lua',
    death: 'esx_death/client/main.lua',
};
let source = 'local SOURCES = {}\n';
for (const [name, file] of Object.entries(files)) {
    const text = fs.readFileSync(path.join(root, file), 'utf8')
        .replace(/\r\n/g, '\n')
        .replace(/\s*<const>/g, '')
        .replace(/(\w+)\s*\+=\s*([^\r\n]+)/g, '$1 = $1 + $2');
    source += `SOURCES[${JSON.stringify(name)}] = [====[${text}]====]\n`;
}
source += fs.readFileSync(path.join(__dirname, 'behavior.lua'), 'utf8');
const state = lauxlib.luaL_newstate();
lualib.luaL_openlibs(state);
try {
    if (lauxlib.luaL_dostring(state, to_luastring(source)) !== lua.LUA_OK) {
        throw new Error(to_jsstring(lua.lua_tostring(state, -1)));
    }
} finally {
    lua.lua_close(state);
}
