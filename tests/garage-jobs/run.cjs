const fs = require('node:fs');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');
let runtime;
try { runtime = require('fengari'); }
catch { runtime = require('../../../esx_core/tools/node_modules/fengari'); }
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = runtime;
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const db = new DatabaseSync(':memory:');
db.function('JSON_UNQUOTE', value => value == null ? null : String(value));
db.exec(`CREATE TABLE owned_vehicles (owner TEXT NOT NULL, plate TEXT PRIMARY KEY, vehicle TEXT, type TEXT DEFAULT 'car', job TEXT,
 stored INTEGER DEFAULT 1, parking TEXT, pound TEXT, custom_name TEXT, is_favorite INTEGER DEFAULT 0, last_used INTEGER, mileage REAL DEFAULT 0)`);
db.exec('CREATE TABLE datastore_data(name TEXT, owner TEXT, data TEXT); CREATE TABLE esx_garage_fleet_imports(slot TEXT PRIMARY KEY, job TEXT, plate TEXT)');
function push(value, state = L) {
  if (value == null) lua.lua_pushnil(state);
  else if (typeof value === 'string') lua.lua_pushstring(state, to_luastring(value));
  else if (typeof value === 'boolean') lua.lua_pushboolean(state, value);
  else if (typeof value === 'number' || typeof value === 'bigint') lua.lua_pushnumber(state, Number(value));
  else {
    lua.lua_newtable(state);
    for (const [key, item] of Object.entries(value)) {
      push(item, state);
      if (Array.isArray(value)) lua.lua_seti(state, -2, Number(key) + 1);
      else lua.lua_setfield(state, -2, to_luastring(key));
    }
  }
}
function read(index, state = L) {
  const kind = lua.lua_type(state, index);
  if (kind === lua.LUA_TNIL) return null;
  if (kind === lua.LUA_TSTRING) return to_jsstring(lua.lua_tostring(state, index));
  if (kind === lua.LUA_TNUMBER) return lua.lua_tonumber(state, index);
  if (kind === lua.LUA_TBOOLEAN) return lua.lua_toboolean(state, index);
  if (kind !== lua.LUA_TTABLE) throw Error('Unexpected Lua value');
  const position = lua.lua_absindex(state, index), result = {};
  lua.lua_pushnil(state);
  while (lua.lua_next(state, position)) { result[read(-2, state)] = read(-1, state); lua.lua_pop(state, 1); }
  const keys = Object.keys(result);
  if (keys.length && keys.every((key) => /^\d+$/.test(key))) return keys.sort((a,b) => a-b).map((key) => result[key]);
  return result;
}
function expose(name, fn) {
  lua.lua_pushcfunction(L, (state) => {
    try { push(fn(state), state); return 1; }
    catch (error) { lua.lua_pushstring(state, to_luastring(error.message)); return lua.lua_error(state); }
  });
  lua.lua_setglobal(L, to_luastring(name));
}
expose('JSON_ENCODE', (state) => JSON.stringify(read(1, state)));
expose('JSON_DECODE', (state) => JSON.parse(read(1, state)));
expose('DB_RESET', () => { db.exec('DELETE FROM owned_vehicles; DELETE FROM datastore_data; DELETE FROM esx_garage_fleet_imports'); return true; });
expose('DB_TRANSACTION', state => {
  db.exec('BEGIN');
  try { for (const item of read(1,state)) db.prepare(item.query).run(...item.values); db.exec('COMMIT'); return true; }
  catch { db.exec('ROLLBACK'); return false; }
});
expose('DB_SQL', (state) => {
  const query = read(1, state).replaceAll("ESCAPE '\\\\'", "ESCAPE '\\'").replace(/ ENGINE=InnoDB DEFAULT CHARSET=utf8mb4$/, '');
  const raw = read(2, state), params = Array.isArray(raw) ? raw : [];
  const statement = db.prepare(query);
  if (/^\s*SELECT/i.test(query)) return statement.all(...params);
  return Number(statement.run(...params).changes);
});
const root = path.resolve(__dirname, '../../[esx_addons]/esx_garage');
const sources = {};
for (const [name, file] of Object.entries({ service: '../esx_service/server/main.lua', categories: 'server/modules/categories.lua', fleets: 'server/modules/fleets.lua', integrationConfig: 'integrations/config.lua', integrationServer: 'integrations/server.lua', registry: 'server/modules/registry.lua', vehicle: 'server/modules/vehicle.lua', migration: 'server/modules/migration.lua', client: 'client/init.lua' })) {
  const source = fs.readFileSync(path.join(root, file), 'utf8').replace(/\s*<const>/g, '');
  if (lauxlib.luaL_loadstring(L, to_luastring(source)) !== lua.LUA_OK) throw Error(`${file}: ${to_jsstring(lua.lua_tostring(L, -1))}`);
  lua.lua_pop(L, 1); sources[name] = source;
}
push(sources); lua.lua_setglobal(L, to_luastring('SOURCES'));
const jobs={};
for(const name of ['esx_policejob','esx_ambulancejob','esx_taxijob','esx_mechanicjob'])jobs[name]=fs.readFileSync(path.join(root,'..',name,'config.lua'),'utf8').replace(/`([^`]+)`/g,'GetHashKey("$1")');
push(jobs);lua.lua_setglobal(L,to_luastring('JOB_CONFIGS'));
if (lauxlib.luaL_loadfile(L, path.join(__dirname, 'server.lua')) !== lua.LUA_OK || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) throw Error(to_jsstring(lua.lua_tostring(L, -1)));
if (lauxlib.luaL_loadfile(L, path.join(__dirname, 'client.lua')) !== lua.LUA_OK || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) throw Error(to_jsstring(lua.lua_tostring(L, -1)));
db.close();
