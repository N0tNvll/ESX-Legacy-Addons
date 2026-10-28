local cases=0
local function test(name,fn)local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));cases=cases+1;print('PASS '..name)end
local mt={}
local function v(x,y,z)return setmetatable({x=x,y=y,z=z},mt)end
mt.__sub=function(a,b)return v(a.x-b.x,a.y-b.y,a.z-b.z)end
mt.__len=function(a)return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z)end
local function fixture()
    local state={events={},nui={},messages={},requests={},points={},timers={}}
    local env=setmetatable({}, {__index=_G})
    env.Config={Locale='en',Settings={interactionDistance=3,showMarker=false,vehicleKeys=true,defaultImpoundFee=100}}
    env.vector3,env.vec3=v,v;env.vector4=function(x,y,z,w)local q=v(x,y,z);q.w=w;return q end
    local spawns={env.vector4(10,0,0,0)}
    local garage={id='police',label='Police Fleet',type='job',job='police',entryPoint=v(0,0,0),spawns=spawns}
    local impound={id='pound',label='Impound',getOutPoint=v(0,0,0),spawns=spawns,cost=100}
    state.garages={garages={garage},impounds={impound}}
    state.page={vehicles={{plate='COP',job='police',type='car',stored=1,vehicle=JSON_ENCODE({model=123,plate='COP',fuelLevel=35})}},page=1,pageSize=30,hasNext=false}
    env.json={decode=JSON_DECODE,encode=JSON_ENCODE}
    env.ESX={PlayerData={},IsPlayerLoaded=function()return true end,GetVehicleTypeClient=function()return'car'end,TextUI=function()end,HideUI=function()end,ShowNotification=function()end}
    env.RegisterNetEvent=function(name,fn)state.events[name]=fn end
    env.AddEventHandler=env.RegisterNetEvent;env.ESX.SecureNetEvent=env.RegisterNetEvent
    env.DecorIsRegisteredAsType=function()return true end
    env.GetEntityCoords=function()return v(0,0,0)end
    env.GetResourceState=function()return'stopped'end
    env.GetCurrentResourceName=function()return'esx_garage'end
    env.GetGamePool=function()return{}end
    env.GetDisplayNameFromVehicleModel=function()return'ADDER'end
    env.GetVehiclePedIsIn=function()return 0 end
    env.IsPedInAnyVehicle=function()return false end
    env.PlayerPedId=function()return 1 end
    env.TranslateCap=function(key)return key end
    env.RemoveBlip=function()end
    env.CreateThread=function()end
    env.SetTimeout=function(_,fn)state.timers[#state.timers+1]=fn end
    env.xLib={points={startLoop=function()end},cache={ped=1,coords=v(0,0,0)},point={delete=function()end},
        addKeybind=function(def)state.interact=def.onPressed end,
        nui={register=function(name,fn)state.nui[name]=fn end,focus=function()end,send=function(message)state.messages[#state.messages+1]=message end,
            close=function(message)state.messages[#state.messages+1]=message end},
        callback={await=function(name,_,data)
            state.requests[#state.requests+1]={name=name,data=data}
            if name=='esx_garage:getGarages'then return state.garages end
            if name=='esx_garage:getVehicles'then
                if state.onPage then local hook=state.onPage;state.onPage=nil;hook()end
                return state.page
            end
            return{success=true}
        end}}
    env.xLib.point.new=function(_,properties)state.points[#state.points+1]=properties;return properties end
    assert(load(SOURCES.client,'client','t',env))()
    state.events['esx:playerLoaded']()
    function state.enter(index)state.points[index].enter()end
    function state.opens()local count=0;for _,message in ipairs(state.messages)do if message.type=='openGarage'then count=count+1 end end;return count end
    return state
end
test('job menus retain the existing NUI and expose job metadata',function()
    local s=fixture();s.enter(1);s.interact();assert(s.opens()==1)
    local open=s.messages[#s.messages];assert(open.payload.garage.type=='job' and open.payload.vehicles[1].job=='police')
end)
test('impound context reaches every server action without a client-supplied job',function()
    local s=fixture();s.enter(2);s.interact()
    assert(s.messages[#s.messages].payload.garage.fleets[1].id=='police')
    assert(s.nui['garage:getVehicles']({page=1,fleetGarageId='police'}).success)
    s.nui['garage:renameVehicle']({vehicleId='COP',newName='Fleet'})
    local request=s.requests[#s.requests]
    assert(request.data.garageId=='pound' and request.data.fleetGarageId=='police' and request.data.job==nil)
end)
test('job and logout changes close the menu and discard the old location',function()
    for _,event in ipairs({'esx:setJob','esx:onPlayerLogout'})do
        local s=fixture();s.enter(1);s.interact();s.events[event]()
        local result=s.nui['garage:renameVehicle']({vehicleId='COP',newName='stale'})
        assert(result.error=='no_location')
        assert(s.messages[#s.messages].type=='closeGarage')
    end
end)
test('a stale page cannot reopen the previous job menu after a job change',function()
    local s=fixture();s.enter(1);s.onPage=function()s.events['esx:setJob']()end;s.interact()
    assert(s.opens()==0)
end)
print(('Passed %d unified garage client scenarios.'):format(cases))
