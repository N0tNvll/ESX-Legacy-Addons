// Parse the real integration files and verify that retired garage entry points are absent.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
let runtime;try{runtime=require('fengari')}catch{runtime=require('../../../esx_core/tools/node_modules/fengari')}
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=runtime;
const root=path.resolve(__dirname,'../..'),state=lauxlib.luaL_newstate();lualib.luaL_openlibs(state);
const resources=['esx_garage','esx_boat','esx_policejob','esx_ambulancejob','esx_taxijob','esx_mechanicjob','esx_society','esx_vehicleshop','esx_service'];
let count=0;
function files(folder){return fs.readdirSync(folder,{withFileTypes:true}).flatMap(entry=>entry.name==='web'?[]:entry.isDirectory()?files(path.join(folder,entry.name)):entry.name.endsWith('.lua')?[path.join(folder,entry.name)]:[])}
for(const resource of resources){
 for(const file of files(path.join(root,'[esx_addons]',resource))){
  const source=fs.readFileSync(file,'utf8').replace(/\s*<const>/g,'')
   .replace(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\[(=*)\[[\s\S]*?\]\1\]|`([^`]+)`/g,(token,equals,model)=>model===undefined?token:'GetHashKey('+JSON.stringify(model)+')')
   .replace(/([\w.]+(?:\[[^\]\r\n]+\])*)\?\[([^\]]+)\]/g,'($1 or {})[$2]')
   .replace(/(\w+(?:\.\w+)*)\s*([+-])=\s*([^\r\n]+)/g,'$1 = $1 $2 $3');
  if(lauxlib.luaL_loadstring(state,to_luastring(source))!==lua.LUA_OK)throw Error(path.relative(root,file)+': '+to_jsstring(lua.lua_tostring(state,-1)));
  lua.lua_pop(state,1);count++;
 }
}
const retired=['esx_boat:takeOutVehicle','esx_boat:getGarage','esx_boat:storeVehicle','esx_policejob:storeNearbyVehicle','esx_ambulancejob:storeNearbyVehicle',
 'esx_vehicleshop:retrieveJobVehicles','esx_vehicleshop:setJobVehicleState','esx_taxijob:SpawnVehicle','esx_society:getVehiclesInGarage','esx_society:putVehicleInGarage','esx_society:removeVehicleFromGarage'];
for(const resource of resources){for(const file of files(path.join(root,'[esx_addons]',resource)).filter(file=>!file.includes(path.sep+'locales'+path.sep))){
 const source=fs.readFileSync(file,'utf8');for(const name of retired)assert.ok(!source.includes(name),`${name} remains in ${file}`);
}}
for(const resource of ['esx_policejob','esx_ambulancejob']){
 const source=fs.readFileSync(path.join(root,'[esx_addons]',resource,'client/vehicle.lua'),'utf8');
 assert.ok(source.includes('PaymentGateway.Pay(')&&source.includes(resource+':buyJobVehicle'));
 assert.ok(source.includes('spawnLocalVehicle')&&!source.includes('game.spawnVehicle('));
}
assert.ok(fs.readFileSync(path.join(root,'[esx_addons]/esx_boat/client/main.lua'),'utf8').includes('function OpenLicenceMenu(shop)'));
assert.ok(fs.readFileSync(path.join(root,'[esx_addons]/esx_garage/fxmanifest.lua'),'utf8').includes("'integrations/config.lua'"));
lua.lua_close(state);
console.log(`PASS ${count} Lua files parse; retired garage routes are absent and purchase/shop paths remain.`);
