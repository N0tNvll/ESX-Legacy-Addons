const fs = require('node:fs');
const path = require('node:path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(process.argv[2] || 'fengari');
const root = path.resolve(__dirname, '..');
const names = ['shared/events.lua', 'configs/trickortreat.lua', 'config.lua', 'shared/config.lua',
    'server/runtime.lua', 'server/config_validator.lua', 'server/main.lua', 'server/ghost.lua',
    'server/trickortreat.lua', 'server/commands.lua', 'client/respawn.lua', 'client/ghost.lua',
    'client/trickortreat.lua'];
let source = 'local SOURCES = {}\n';
for (const name of names) source += `SOURCES[${JSON.stringify(name)}] = [====[${fs.readFileSync(path.join(root, name), 'utf8')}]====]\n`;
source += fs.readFileSync(path.join(__dirname, 'security.lua'), 'utf8');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const result = lauxlib.luaL_dostring(L, to_luastring(source));
if (result !== lua.LUA_OK) {
    console.error(to_jsstring(lua.lua_tostring(L, -1)));
    process.exitCode = 1;
}
lua.lua_close(L);
