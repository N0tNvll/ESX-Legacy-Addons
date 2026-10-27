// SPDX-License-Identifier: GPL-3.0-only
exports.readLocale = function readLocale(runtime, source, language) {
    const { lua, lauxlib, lualib, to_luastring, to_jsstring } = runtime;
    const state = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(state);
    function read(index) {
        const result = {};
        const position = lua.lua_absindex(state, index);
        lua.lua_pushnil(state);
        while (lua.lua_next(state, position)) {
            if (lua.lua_type(state, -2) === lua.LUA_TSTRING && lua.lua_type(state, -1) === lua.LUA_TSTRING) {
                result[to_jsstring(lua.lua_tostring(state, -2))] = to_jsstring(lua.lua_tostring(state, -1));
            }
            lua.lua_pop(state, 1);
        }
        return result;
    }
    try {
        if (lauxlib.luaL_dostring(state, to_luastring('Locales = {}\n' + source)) !== lua.LUA_OK) {
            throw new Error(to_jsstring(lua.lua_tostring(state, -1)));
        }
        const returned = lua.lua_type(state, -1) === lua.LUA_TTABLE ? read(-1) : null;
        lua.lua_getglobal(state, to_luastring('Locales'));
        lua.lua_getfield(state, -1, to_luastring(language));
        if (lua.lua_type(state, -1) === lua.LUA_TTABLE) return read(-1);
        if (returned) return returned;
        throw new Error('Locale table not found: ' + language);
    } finally {
        lua.lua_close(state);
    }
};

exports.placeholders = value => [...value.replace(/%%/g, '').matchAll(/%[-+#0]*\d*(?:\.\d+)?([cdiouxXeEfgGqsaA])/g)].map(match => match[1]);
