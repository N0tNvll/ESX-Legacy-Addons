local cases=0
local function test(name,fn)
    local ok,err=pcall(fn)
    assert(ok,name..': '..tostring(err))
    cases=cases+1;print('PASS '..name)
end
local vector={}
local function vec3(x,y,z)return setmetatable({x=x,y=y,z=z},vector)end
vector.__sub=function(a,b)return vec3(a.x-b.x,a.y-b.y,a.z-b.z)end
vector.__add=function(a,b)return vec3(a.x+b.x,a.y+b.y,a.z+b.z)end
vector.__len=function(a)return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z)end
local function copy(value)return JSON_DECODE(JSON_ENCODE(value))end
local function fixture()
    DB_RESET()
    local env=setmetatable({}, {__index=_G})
    local state={callbacks={},events={},exports={},entities={},managed={},timers={},writes=0,spawns=0,fees=0,now=1000}
    env.vec3,env.vector3=vec3,vec3
    env.vec4=function(x,y,z,w)local v=vec3(x,y,z);v.w=w;return v end
    env.vector4=env.vec4
    local function garage(id,kind,job,grade,shared)
        return{id=id,type=kind,job=job,minGrade=grade,shared=shared,label=id,entryPoint=vec3(0,0,0),storePoint=vec3(0,0,0),spawns={env.vec4(10,0,0,0)}}
    end
    env.Config={Settings={interactionDistance=3,restrictToGarage=false,defaultImpoundFee=100,vehicleKeys=true,vehiclesPerPage=30,maxVehiclesPerMenu=100},
        Garages={garage('personal','public'),garage('police','job','police',2,true),garage('ambulance','job','ambulance',0,true),garage('assigned','job','police',2,false)},
        Impounds={{id='pound',label='Pound',getOutPoint=vec3(0,0,0),spawns={env.vec4(10,0,0,0)},cost=100}}}
    state.players={}
    for id=1,3 do
        local player={identifier='owner'..id,source=id,job={name=id==3 and 'ambulance' or 'police',grade=3}}
        player.getMoney=function()return 10000 end
        player.getAccount=function()return{money=10000}end
        player.addMoney=function(amount)state.fees=state.fees-amount end
        player.addAccountMoney=function(_,amount)state.fees=state.fees-amount end
        player.showNotification=function()end
        state.players[id]=player
        state.entities[100+id]={coords=vec3(0,0,0),exists=true}
    end
    env.ESX={GetPlayerFromId=function(id)return state.players[id]end,GetExtendedVehicleFromPlate=function(plate)return state.managed[plate]end}
    env.GetPlayerPed=function(id)return state.players[id]and 100+id or 0 end
    env.DoesEntityExist=function(id)return state.entities[id]~=nil and state.entities[id].exists end
    env.GetEntityCoords=function(id)return state.entities[id].coords end
    env.GetEntityModel=function(id)return state.entities[id].model or 0 end
    env.GetVehicleType=function(id)return state.entities[id].vehicleType or 'automobile' end
    env.GetEntityType=function(id)return id>1000 and 2 or 1 end
    env.GetEntityPopulationType=function()return 7 end
    env.GetVehicleNumberPlateText=function(id)return state.entities[id].plate end
    env.GetVehiclePedIsIn=function(id)return state.entities[id].vehicle or 0 end
    env.GetAllVehicles=function()local list={};for id,e in pairs(state.entities)do if e.plate and e.exists then list[#list+1]=id end end;return list end
    env.NetworkGetEntityFromNetworkId=function(id)return id end
    env.GetResourceState=function()return'stopped'end
    env.GetCurrentResourceName=function()return'esx_garage'end
    env.GetInvokingResource=function()return state.invokingResource or 'esx_policejob' end
    env.GetGameTimer=function()return state.now end
    env.GetHashKey=function()return 123 end
    env.GetConvar=function(_,fallback)return fallback end
    env.ESX.GetConfig=function()return{}end
    env.Wait=function()assert(state.silentDelete or state.failDelete,'unexpected wait');state.now=state.now+1000 end
    env.SetTimeout=function(_,fn)state.timers[#state.timers+1]=fn end
    env.print=function()end
    env.os={time=function()return 100 end}
    env.json={encode=JSON_ENCODE,decode=JSON_DECODE}
    env.GarageReady=true;env.ESXCatalog={awaitReady=function()end}
    env.xLib={callback={registerCompat=function(name,fn)state.callbacks[name]=fn end},rateLimiter=function()return{consume=function()return true end}end}
    env.PaymentGateway={Charge=function(_,account,amount)if account~='money'and account~='bank'then return false end;state.fees=state.fees+amount;return true end}
    env.AddEventHandler=function(name,fn)local previous=state.events[name];state.events[name]=function(...)if previous then previous(...)end;return fn(...)end end
    env.TriggerClientEvent=function()end
    env.TriggerEvent=function(name,...)state.lastEvent={name,...}end
    env.TranslateCap=function(key)return key end
    env.exports=setmetatable({}, {__call=function(_,name,fn)state.exports[name]=fn end})
    env.MySQL={
        query={await=function(query,params)
            local result=DB_SQL(query,params or {})
            if state.onRead then local hook=state.onRead;state.onRead=nil;hook()end
            return result
        end},
        update={await=function(query,params)
            if state.failWrite then error('database failed')end
            state.writes=state.writes+1
            local result=DB_SQL(query,params or {})
            if state.onWrite then local hook=state.onWrite;state.onWrite=nil;hook(query)end
            if state.zeroChangedRows and (query:find('SET `custom_name`',1,true)or query:find('SET `is_favorite`',1,true))then return 0 end
            return result
        end},
    }
    env.MySQL.single={await=function(query,params)local rows=env.MySQL.query.await(query,params);return rows[1]end}
    env.MySQL.scalar={await=function(query,params)
        if query:find('SELECT ENGINE FROM information_schema.TABLES',1,true)then return state.engine or'InnoDB'end
        local row=env.MySQL.single.await(query,params);if row then for _,value in pairs(row)do return value end end
    end}
    env.MySQL.transaction={await=function(items)if state.failTransaction then return false end;return DB_TRANSACTION(items)end}
    env.xLib.vehiclePlate={normalize=function(value)
        if type(value)~='string'then return nil end;value=value:gsub('%s+$',''):upper()
        return #value>0 and #value<=12 and value:match('^[%w %-]+$')and value or nil
    end,generateUnique=function(_,exists)
        for index=1,100 do local candidate=('JF%06d'):format(index);if not exists(candidate)then return candidate end end
    end}
    function state.add(owner,plate,job,stored,parking,pound)
        DB_SQL('INSERT INTO owned_vehicles(owner,plate,job,stored,parking,pound,vehicle)VALUES(?,?,?,?,?,?,?)',
            {owner,plate,job or '',stored==nil and 1 or stored,parking or '',pound or '',JSON_ENCODE({plate=plate,model=123,fuelLevel=38,engineHealth=750,bodyHealth=800})})
        DB_SQL("UPDATE owned_vehicles SET job=NULLIF(job,''), parking=NULLIF(parking,''),pound=NULLIF(pound,'')",{})
    end
    function state.row(plate)return DB_SQL('SELECT * FROM owned_vehicles WHERE plate=?',{plate})[1]end
    function state.vehicle(plate,managed)
        local row=state.row(plate);assert(row)
        local id=1001+#env.GetAllVehicles()
        state.entities[id]={exists=true,coords=vec3(1,0,0),plate=plate,model=123,vehicleType=({boat='boat',helicopter='heli',heli='heli',plane='plane',airplane='plane',submarine='submarine'})[row.type]or'automobile'}
        state.entities[101].vehicle=id;state.entities[102].vehicle=id;state.entities[103].vehicle=id
        local obj={plate=plate,getOwner=function()return row.owner end,getEntity=function()return id end,getNetId=function()return id end,getModelHash=function()return 123 end}
        obj.delete=function(_,garageName)
            if state.failDelete then error('delete failed')end
            if state.silentDelete then return end
            state.entities[id].exists=false;state.managed[plate]=nil
            if garageName then DB_SQL('UPDATE owned_vehicles SET stored=1,parking=?,pound=NULL WHERE owner=? AND plate=?',{garageName,row.owner,plate})
            else DB_SQL('UPDATE owned_vehicles SET stored=1 WHERE owner=? AND plate=?',{row.owner,plate})end
        end
        if managed then state.managed[plate]=obj end
        return obj,id
    end
    env.DeleteEntity=function(id)if state.failDelete then error('delete failed')end;if not state.silentDelete then state.entities[id].exists=false end end
    env.ESX.CreateExtendedVehicle=function(owner,plate)
        if state.failSpawn then return nil end
        local row=DB_SQL('SELECT * FROM owned_vehicles WHERE owner=? AND plate=? AND stored=1',{owner,plate})[1]
        assert(row,'core must use the original database owner')
        state.spawns=state.spawns+1;state.spawnOwner=owner
        local obj=state.vehicle(plate,true)
        DB_SQL('UPDATE owned_vehicles SET stored=0 WHERE owner=? AND plate=?',{owner,plate})
        if state.onSpawn then state.onSpawn()end
        return obj
    end
    assert(load(SOURCES.categories,'categories','t',env))()
    assert(load(SOURCES.registry,'registry','t',env))()
    assert(load(SOURCES.vehicle,'vehicle','t',env))()
    function state.call(name,source,data)
        local result,replies=nil,0
        state.callbacks['esx_garage:'..name](source,function(value)result=value;replies=replies+1 end,data)
        assert(replies==1,'one callback reply required');return result
    end
    function state.get(id,garageId,fleetGarageId,filter)
        return state.call('getVehicles',id,{garageId=garageId,fleetGarageId=fleetGarageId,filter=filter})
    end
    function state.take(id,plate,garageId,fleetGarageId)
        return state.call('retrieveVehicle',id,{plate=plate,garageId=garageId,fleetGarageId=fleetGarageId,spawn={x=10,y=0,z=0,w=0},paymentAccount='money'})
    end
    function state.store(id,plate,garageId,props)
        return state.call('storeVehicle',id,{plate=plate,garageId=garageId,props=props or{model=999,plate='FORGED',fuelLevel=25,engineHealth=690,bodyHealth=730}})
    end
    return env,state
end

test('personal lists include only the owner and NULL/empty jobs',function()
    local _,s=fixture();s.add('owner1','MINE');s.add('owner2','OTHER');s.add('owner1','COP','police');s.add('owner1','MED','ambulance')
    assert(#s.get(1,'personal').vehicles==1 and s.get(1,'personal').vehicles[1].plate=='MINE')
end)
test('shared fleet ignores personal owner but keeps other jobs separate',function()
    local _,s=fixture();s.add('owner1','A','police');s.add('owner2','B','police');s.add('owner1','C','ambulance');s.add('owner2','PRIVATE')
    local rows=s.get(2,'police').vehicles;assert(#rows==2 and rows[1].owner==nil)
end)
test('assigned job garages require the employee owner as well as job',function()
    local _,s=fixture();s.add('owner1','A','police');s.add('owner2','B','police');s.add('owner2','PRIVATE')
    local rows=s.get(2,'assigned').vehicles;assert(#rows==1 and rows[1].plate=='B')
end)
test('wrong jobs and insufficient grades cannot list or retrieve fleet vehicles',function()
    local _,s=fixture();s.add('owner1','COP','police')
    assert(s.get(3,'police').success==false and not s.take(3,'COP','police').success)
    s.players[1].job.grade=1
    assert(s.get(1,'police').success==false and not s.take(1,'COP','police').success and s.spawns==0)
end)
test('an unspecified job garage and custom authorization cannot bypass job checks',function()
    local env,s=fixture();local garage=env.Garages.police
    garage.job=nil;garage.access={authorize=function()return true end}
    assert(not env.CanAccessGarage(1,garage))
    garage.job='police';s.players[1].job.name='ambulance';assert(not env.CanAccessGarage(1,garage))
end)
test('access.jobs minimum grades and additional custom checks are enforced',function()
    local env,s=fixture();local garage=env.Garages.police;garage.job=nil;garage.access={jobs={police=4},authorize=function()return true end}
    assert(not env.CanAccessGarage(1,garage));s.players[1].job.grade=4;assert(env.CanAccessGarage(1,garage))
    garage.access.authorize=function()return false end;assert(not env.CanAccessGarage(1,garage))
end)
test('personal retrieval cannot take an owned job vehicle or another owner vehicle',function()
    local _,s=fixture();s.add('owner1','COP','police');s.add('owner2','OTHER')
    assert(not s.take(1,'COP','personal').success and not s.take(1,'OTHER','personal').success and s.spawns==0)
end)
test('employees retrieve shared vehicles through the original ESX owner',function()
    local _,s=fixture();s.add('owner1','COP','police')
    assert(s.take(2,'COP','police').success and s.spawnOwner=='owner1')
    local row=s.row('COP');assert(row.owner=='owner1' and row.job=='police' and row.stored==0)
end)
test('a second employee cannot duplicate an active fleet vehicle',function()
    local _,s=fixture();s.add('owner1','COP','police');assert(s.take(1,'COP','police').success)
    assert(not s.take(2,'COP','police').success and s.spawns==1)
end)
test('concurrent requests for one fleet plate share the existing lock',function()
    local _,s=fixture();s.add('owner1','COP','police');local other
    s.onRead=function()other=s.take(2,'COP','police')end
    assert(s.take(1,'COP','police').success and other.error=='busy' and s.spawns==1)
end)
test('job changes while SQL waits prevent fleet retrieval and listing',function()
    local _,s=fixture();s.add('owner1','COP','police')
    s.onRead=function()s.players[1].job.name='ambulance'end
    assert(not s.take(1,'COP','police').success and s.spawns==0)
    s.players[1].job.name='police';s.onRead=function()s.players[1].job.grade=0 end
    assert(s.get(1,'police').error=='not_allowed')
end)
test('a grade change while spawning deletes the entity and restores the row',function()
    local _,s=fixture();s.add('owner1','COP','police',1,'police')
    s.onSpawn=function()s.players[1].job.grade=0 end
    assert(not s.take(1,'COP','police').success)
    assert(s.row('COP').stored==1 and s.row('COP').parking=='police' and s.writes>=1 and s.fees==0)
    for id,e in pairs(s.entities)do if id>1000 then assert(not e.exists)end end
end)
test('another authorized employee stores shared props without changing ownership',function()
    local _,s=fixture();s.add('owner1','COP','police',0);s.vehicle('COP',true)
    assert(s.store(2,'COP','police').success)
    local row=s.row('COP');local props=JSON_DECODE(row.vehicle)
    assert(row.owner=='owner1' and row.job=='police' and row.stored==1 and row.parking=='police')
    assert(props.model==123 and props.plate=='COP' and props.fuelLevel==25 and props.engineHealth==690 and props.bodyHealth==730)
end)
test('unmanaged shared vehicles use the same guarded store path',function()
    local _,s=fixture();s.add('owner1','COP','police',0);local _,id=s.vehicle('COP',false)
    assert(s.store(2,'COP','police').success and not s.entities[id].exists and s.row('COP').stored==1)
end)
test('personal and fleet vehicles cannot be parked into the other context',function()
    local _,s=fixture();s.add('owner1','COP','police',0);s.vehicle('COP',true)
    assert(not s.store(1,'COP','personal').success)
    s.add('owner1','MINE',nil,0);s.vehicle('MINE',true)
    assert(not s.store(1,'MINE','police').success and s.row('MINE').stored==0)
end)
test('store failures keep the existing vehicle and row available',function()
    local _,s=fixture();s.add('owner1','COP','police',0);local _,id=s.vehicle('COP',true);s.failWrite=true
    assert(not s.store(1,'COP','police').success and s.entities[id].exists and s.row('COP').stored==0)
end)

test('failed or ineffective entity deletion rolls back storage and properties',function()
    for _,managed in ipairs({true,false})do
        for _,failure in ipairs({'failDelete','silentDelete'})do
            local _,s=fixture();s.add('owner1','COP','police',0);local _,id=s.vehicle('COP',managed)
            local before=s.row('COP').vehicle;s[failure]=true
            assert(not s.store(2,'COP','police').success and s.entities[id].exists, failure..' '..tostring(managed))
            local row=s.row('COP');assert(row.stored==0 and row.parking==nil and row.vehicle==before, failure..' '..tostring(managed)..' '..JSON_ENCODE(row))
        end
    end
end)
test('job change during store rolls back without deleting the vehicle',function()
    local _,s=fixture();s.add('owner1','COP','police',0);local _,id=s.vehicle('COP',true)
    s.onWrite=function()s.players[1].job.name='ambulance'end
    assert(not s.store(1,'COP','police').success and s.entities[id].exists and s.row('COP').stored==0)
end)
test('fleet ownership transfers and personal-key grants fail even for the original owner',function()
    local _,s=fixture();s.add('owner1','COP','police')
    for _,context in ipairs({'personal','police'})do
        assert(not s.call('transferVehicle',1,{plate='COP',targetId=2,garageId=context}).success)
        assert(not s.call('giveKeys',1,{plate='COP',garageId=context}).success)
    end
    assert(not s.call('transferVehicle',1,{plate='COP',targetId=2}).success and s.row('COP').owner=='owner1')
end)
test('personal transfer, rename and favorite retain their existing behavior',function()
    local _,s=fixture();s.add('owner1','MINE')
    assert(s.call('renameVehicle',1,{plate='MINE',name='My car'}).success)
    assert(s.call('toggleFavorite',1,{plate='MINE',isFavorite=true}).success)
    assert(s.row('MINE').custom_name=='My car' and s.row('MINE').is_favorite==1)
    assert(s.call('transferVehicle',1,{plate='MINE',targetId=2}).success and s.row('MINE').owner=='owner2')
end)
test('fleet rename/favorite require the authorized garage context',function()
    local _,s=fixture();s.add('owner1','COP','police')
    assert(not s.call('renameVehicle',1,{plate='COP',name='Unauthorized'}).success)
    assert(s.call('renameVehicle',2,{plate='COP',name='Fleet',garageId='police'}).success)
    assert(not s.call('toggleFavorite',3,{plate='COP',isFavorite=true,garageId='police'}).success)
end)
test('impound personal and fleet contexts stay separate and enforce the fee',function()
    local _,s=fixture();s.add('owner1','MINE',nil,1,nil,'pound');s.add('owner2','COP','police',1,nil,'pound')
    local own=s.get(1,'pound').vehicles;assert(#own==1 and own[1].plate=='MINE')
    local fleet=s.get(1,'pound','police').vehicles;assert(#fleet==1 and fleet[1].plate=='COP')
    assert(not s.take(1,'COP','pound').success)
    assert(s.take(1,'COP','pound','police').success and s.fees==100 and s.row('COP').owner=='owner2')
end)
test('forged impound fleet context cannot bypass job or grade',function()
    local _,s=fixture();s.add('owner2','COP','police',1,nil,'pound')
    assert(s.get(3,'pound','police').success==false and not s.take(3,'COP','pound','police').success)
    assert(s.get(1,'personal','police').success==false)
    s.players[1].job.grade=0;assert(s.get(1,'pound','police').success==false)
end)
test('restrictions preserve parking rules and legacy cross-context parking stays recoverable',function()
    local env,s=fixture();env.Config.Settings.restrictToGarage=true
    s.add('owner1','COP','police',1,'personal');assert(s.take(1,'COP','police').success)
    s.add('owner1','MINE',nil,1,'police');assert(s.take(1,'MINE','personal').success)
end)
test('vehicle model spoofing and mismatched plates cannot be stored',function()
    local _,s=fixture();s.add('owner1','COP','police',0);local _,id=s.vehicle('COP',true)
    s.entities[id].model=456;assert(not s.store(1,'COP','police').success)
    s.entities[id].model=123;s.entities[id].plate='SPOOF';assert(not s.store(1,'COP','police').success)
    assert(s.row('COP').stored==0 and s.entities[id].exists)
end)
test('SQL parameters isolate hostile search input and pagination',function()
    local _,s=fixture();s.add('owner1','MINE');s.add('owner2','OTHER')
    assert(#s.get(1,'personal',nil,{search="'; DROP TABLE owned_vehicles; --"}).vehicles==0)
    assert(s.row('OTHER').owner=='owner2')
end)
test('spawn failure restores fleet parking and does not charge',function()
    local _,s=fixture();s.add('owner1','COP','police',1,'police');s.failSpawn=true
    assert(not s.take(1,'COP','police').success and s.row('COP').stored==1 and s.row('COP').parking=='police' and s.fees==0)
end)
test('custom checks that change jobs cannot expose the new job fleet',function()
    local env,s=fixture();s.add('owner1','COP','police');s.add('owner1','MED','ambulance')
    env.Garages.police.access={authorize=function()s.players[1].job.name='ambulance';return true end}
    assert(s.get(1,'police').success==false)
end)
test('resource startup applies the fleet migration even with every old marker present',function()
    local env,s=fixture();local markers={schema='1.16.0',performance_indexes='1.16.0',filter_indexes='1.16.0',mileage_precision='1.16.0',pound_normalization='1.16.0'}
    local columns,indexes,added,updates={}, {},0,0
    env.xLib.schema={ensureColumn=function(tableName,column,definition)
        assert(tableName=='owned_vehicles' and column=='job' and definition:find('NULL DEFAULT NULL',1,true))
        if columns[column]then return false end;columns[column]=true;added=added+1;return true
    end}
    env.MySQL.ready=function(fn)fn()end
    env.MySQL.scalar.await=function(query,params)
        if query:find('SELECT `version`',1,true)then return markers[params[1]]end
        if query:find('SELECT DATA_TYPE',1,true)then return'varchar'end
        if query:find('COLUMN_NAME',1,true)then return 1 end
        if query:find('INDEX_NAME',1,true)then return params[2]=='idx_owned_vehicles_job_plate'and(indexes.job and 1 or 0)or 1 end
        return 0
    end
    env.MySQL.query.await=function(query,params)
        if query:find('INSERT INTO `esx_garage_migrations`',1,true)then markers[params[1]]=params[2]end
        if query:find('ADD INDEX `idx_owned_vehicles_job_plate`',1,true)then indexes.job=true end
        if query:find('SELECT DISTINCT',1,true)then return{}end
        return{}
    end
    env.MySQL.update.await=function()updates=updates+1;return 0 end
    assert(load(SOURCES.migration,'migration','t',env))()
    assert(env.GarageReady and markers.job_fleets=='1.16.0'and added==1 and indexes.job and updates==0)
    assert(load(SOURCES.migration,'migration','t',env))()
    assert(env.GarageReady and added==1 and updates==0)
end)
test('an unsuccessful fleet schema migration leaves the resource closed',function()
    local env=fixture();env.MySQL.ready=function(fn)fn()end
    env.MySQL.scalar.await=function(query)
        if query:find('SELECT `version`',1,true)then return nil end
        return'varchar'
    end
    env.MySQL.query.await=function()return{}end
    env.xLib.schema={ensureColumn=function()error('schema unavailable')end}
    assert(load(SOURCES.migration,'migration','t',env))()
    assert(not env.GarageReady)
end)
test('idempotent personal metadata updates handle MySQL zero changed rows',function()
    local _,s=fixture();s.add('owner1','MINE');s.zeroChangedRows=true
    assert(s.call('renameVehicle',1,{plate='MINE',name='Same name'}).success)
    assert(s.call('renameVehicle',1,{plate='MINE',name='Same name'}).success)
    assert(s.call('toggleFavorite',1,{plate='MINE',isFavorite=true}).success)
end)
local function categorized()
    local env,s=fixture()
    for _,category in ipairs({'ground','boat','helicopter','plane'})do
        for _,kind in ipairs({'public','job'})do
            local id=category..'_'..kind
            local garage={id=id,label=id,type=kind,job=kind=='job'and'police'or nil,shared=true,minGrade=2,
                entryPoint=vec3(0,0,0),storePoint=vec3(0,0,0),spawns={env.vec4(10,0,0,0)},vehicleCategories={category}}
            env.Garages[id]=garage;env.Config.Garages[#env.Config.Garages+1]=garage
        end
        local lot={id=category..'_pound',label=category,getOutPoint=vec3(0,0,0),spawns={env.vec4(10,0,0,0)},cost=100,vehicleCategories={category}}
        env.Impounds[lot.id]=lot;env.Config.Impounds[#env.Config.Impounds+1]=lot
    end
    function s.typed(plate,vehicleType,job,stored,parking,pound)
        s.add('owner1',plate,job,stored,parking,pound);DB_SQL('UPDATE owned_vehicles SET type=? WHERE plate=?',{vehicleType,plate})
    end
    return env,s
end

test('civil and job lists independently separate land, boats, helicopters and planes',function()
    local _,s=categorized()
    for _,kind in ipairs({'public','job'})do
        local job=kind=='job'and'police'or nil
        local prefix=kind=='job'and'J'or'P'
        for _,category in ipairs({'ground','boat','helicopter','plane'})do s.typed(prefix..category:sub(1,1),category=='ground'and'car'or category,job)end
        for _,category in ipairs({'ground','boat','helicopter','plane'})do
            local rows=s.get(kind=='job'and 2 or 1,category..'_'..kind).vehicles
            assert(#rows==1 and rows[1].plate==prefix..category:sub(1,1),category..' '..kind)
        end
    end
end)

test('direct retrieval cannot cross category or civilian/job boundaries',function()
    local _,s=categorized();s.typed('BOAT','boat');s.typed('HELI','helicopter','police');s.typed('PLANE','plane')
    for _,request in ipairs({{'BOAT','ground_public'},{'PLANE','helicopter_public'},{'HELI','plane_job'},{'HELI','helicopter_public'},{'BOAT','boat_job'}})do
        assert(not s.take(1,request[1],request[2]).success)
    end
    assert(s.spawns==0)
end)

test('boats and aircraft retrieve through their own civilian or shared job points',function()
    for _,kind in ipairs({'public','job'})do
        for _,category in ipairs({'boat','helicopter','plane'})do
            local _,s=categorized();s.typed('UNIT',category,kind=='job'and'police'or nil)
            assert(s.take(kind=='job'and 2 or 1,'UNIT',category..'_'..kind).success,category..' '..kind)
        end
    end
end)

test('managed and unmanaged boats or aircraft store only in compatible garages with props intact',function()
    for _,managed in ipairs({true,false})do
        for _,category in ipairs({'boat','helicopter','plane'})do
            local _,s=categorized();s.typed('UNIT',category,'police',0);local _,id=s.vehicle('UNIT',managed)
            assert(not s.store(2,'UNIT','ground_job').success and s.entities[id].exists)
            assert(s.store(2,'UNIT',category..'_job').success and not s.entities[id].exists)
            local row=s.row('UNIT');local props=JSON_DECODE(row.vehicle)
            assert(row.owner=='owner1'and row.job=='police'and row.parking==category..'_job'and props.fuelLevel==25 and props.engineHealth==690)
        end
    end
end)

test('actual entity category rejects incorrect database labels at spawn and store',function()
    local _,s=categorized();s.typed('UNIT','car','police')
    s.onSpawn=function()s.entities[s.managed.UNIT:getEntity()].vehicleType='plane'end
    assert(not s.take(2,'UNIT','ground_job').success and s.row('UNIT').stored==1)
    DB_SQL('UPDATE owned_vehicles SET stored=0 WHERE plate=?',{'UNIT'});local _,id=s.vehicle('UNIT',false);s.entities[id].vehicleType='boat'
    assert(not s.store(2,'UNIT','ground_job').success and s.entities[id].exists and s.row('UNIT').stored==0)
end)

test('legacy native category aliases remain compatible and ambiguous aircraft fail closed',function()
    local env,s=categorized();s.typed('HELI','heli');s.typed('SUB','submarine');s.typed('BIKE','bike');s.typed('OLD','aircraft')
    assert(#s.get(1,'helicopter_public').vehicles==1 and #s.get(1,'boat_public').vehicles==1 and #s.get(1,'ground_public').vehicles==1)
    assert(not s.take(1,'OLD','plane_public').success)
    env.Config.VehicleCategoryOverrides={maverick='helicopter'}
    assert(env.GarageCategories.resolve(s.row('OLD'))=='helicopter')
    assert(#s.get(1,'helicopter_public').vehicles==4) -- same fixture model is overridden server-side, without rewriting rows.
    assert(s.row('OLD').type=='aircraft')
end)

test('category filtering occurs before pagination in mixed fleets',function()
    local _,s=categorized();for i=1,36 do s.typed(('B%02d'):format(i),'boat')end
    for i=1,36 do s.typed(('G%02d'):format(i),'car')end
    local result=s.call('getVehicles',1,{garageId='ground_public',page=1,pageSize=30})
    assert(#result.vehicles==30 and result.hasNext and result.vehicles[1].plate=='G01')
    result=s.call('getVehicles',1,{garageId='ground_public',page=2,pageSize=30})
    assert(#result.vehicles==6 and not result.hasNext)
end)

test('a helipad minimum grade cannot be bypassed using a road fleet at an aerial impound',function()
    local env,s=categorized();s.typed('HELI','helicopter','police',1,nil,'helicopter_pound')
    env.Garages.helicopter_job.minGrade=5
    assert(#s.get(1,'helicopter_pound','ground_job').vehicles==0)
    assert(not s.take(1,'HELI','helicopter_pound','ground_job').success)
    assert(s.get(1,'helicopter_pound','helicopter_job').success==false)
end)

test('impound exports route boats and aircraft away from land lots',function()
    local env,s=categorized()
    for _,category in ipairs({'boat','helicopter','plane'})do
        s.typed(category,category,'police',0)
        assert(s.exports.impoundVehicle(category,'pound'))
        assert(s.row(category).pound==category..'_pound')
    end
end)

test('restart recovery and old impounds keep non-land vehicles at compatible lots',function()
    local env,s=categorized();s.typed('BOAT','boat',nil,0);s.typed('HELI','helicopter','police',1,nil,'pound');s.typed('PLANE','plane','police',0)
    local scalar=env.MySQL.scalar.await
    env.MySQL.scalar.await=function(query,params)
        if query:find('SELECT `version`',1,true)then return'1.16.0'end
        if query:find('information_schema',1,true)then return 1 end
        return scalar(query,params)
    end
    env.MySQL.ready=function(fn)fn()end
    assert(load(SOURCES.migration,'migration','t',env))()
    assert(env.GarageReady and s.row('BOAT').pound=='boat_pound'and s.row('HELI').pound=='helicopter_pound'and s.row('PLANE').pound=='plane_pound')
    assert(s.row('HELI').owner=='owner1'and s.row('HELI').job=='police')
end)

test('missing compatible impounds preserve the row instead of moving a boat onto land',function()
    local env,s=categorized();s.typed('BOAT','boat',nil,0);env.Config.Impounds={env.Impounds.pound}
    assert(not s.exports.impoundVehicle('BOAT')and s.row('BOAT').stored==0 and s.row('BOAT').pound==nil)
end)

test('per-model permissions apply in SQL and survive a grade change during spawn',function()
    local env,s=categorized();s.typed('UNIT','car','police')
    env.Garages.ground_job.models=function(source)return s.players[source].job.grade>=3 and {123}or{}end
    assert(#s.get(2,'ground_job').vehicles==1)
    s.onSpawn=function()s.players[2].job.grade=2 end
    assert(not s.take(2,'UNIT','ground_job').success and s.row('UNIT').stored==1)
    assert(#s.get(2,'ground_job').vehicles==0)
end)

test('service reservations are released on failed retrieval and after storing',function()
    local env,s=categorized();s.typed('UNIT','car','police');local reserved,released,stored=0,0,0
    local garage=env.Garages.ground_job
    garage.reserve=function()reserved=reserved+1;return{acquired=true}end
    garage.release=function(_,token)assert(token.acquired);released=released+1 end
    garage.onStored=function()stored=stored+1 end
    s.failSpawn=true;assert(not s.take(2,'UNIT','ground_job').success and reserved==1 and released==1)
    s.failSpawn=false;assert(s.take(2,'UNIT','ground_job').success and reserved==2 and released==1)
    assert(s.store(2,'UNIT','ground_job').success and stored==1)
end)

test('stopped job resources unregister only their own garage definitions',function()
    local env,s=categorized();s.invokingResource='esx_testjob'
    s.exports.registerGarage(env.Garages.boat_job)
    s.events.onResourceStop('esx_testjob')
    assert(env.Garages.boat_job==nil and env.Garages.ground_job and env.Garages.personal)
end)

local function fleetFixture()
    local env,s=fixture();s.invokingResource='esx_taxijob';assert(load(SOURCES.fleets,'fleets','t',env))()
    function s.prepare(vehicles,job)return s.exports.prepareJobFleet(job or'taxi',vehicles or{},'society_'..(job or'taxi'))end
    function s.legacy(vehicles)DB_SQL('INSERT INTO datastore_data(name,data)VALUES(?,?)',{'society_taxi',JSON_ENCODE({garage=vehicles})})end
    function s.count()return DB_SQL('SELECT COUNT(*) AS count FROM owned_vehicles',{})[1].count end
    return env,s
end

test('fleet import preserves legacy properties and archive, and never repeats on restart',function()
    local _,s=fleetFixture();s.legacy({{plate='OLD',model=123,fuelLevel=22,bodyHealth=640}})
    local before=DB_SQL('SELECT data FROM datastore_data',{})[1].data
    assert(s.prepare()and s.prepare()and s.count()==1)
    local row=s.row('OLD');local props=JSON_DECODE(row.vehicle)
    assert(row.owner=='society:taxi'and row.job=='taxi'and props.fuelLevel==22 and props.bodyHealth==640)
    assert(DB_SQL('SELECT data FROM datastore_data',{})[1].data==before)
end)

test('import refuses a personal plate collision without overwriting either source',function()
    local _,s=fleetFixture();s.add('owner1','OLD');s.legacy({{plate='OLD',model=123}})
    assert(not s.prepare()and s.count()==1 and s.row('OLD').owner=='owner1'and s.row('OLD').job==nil)
end)

test('existing matching job vehicles keep original ownership and out state during import',function()
    local _,s=fleetFixture();s.add('owner1','OLD','taxi',0);s.legacy({{plate='OLD',model=123}})
    local before=s.row('OLD').vehicle;assert(s.prepare()and s.count()==1)
    local row=s.row('OLD');assert(row.owner=='owner1'and row.stored==0 and row.vehicle==before)
end)

test('initial fleets use unique slots, count existing vehicles and do not restock on restart',function()
    local _,s=fleetFixture();s.add('owner1','OLD','taxi',0)
    assert(s.prepare({{model=123,count=3}})and s.count()==3)
    assert(s.prepare({{model=123,count=3}})and s.count()==3)
    assert(s.prepare({{model=123,count=4}})and s.count()==4)
    assert(s.row('OLD').owner=='owner1'and s.row('OLD').stored==0)
    DB_SQL('DELETE FROM owned_vehicles WHERE plate=?',{'JF000001'})
    assert(s.prepare({{model=123,count=4}})and s.count()==3)
end)

test('failed import transactions roll back vehicle and ledger together and retry safely',function()
    local _,s=fleetFixture();s.legacy({{plate='OLD',model=123}});s.failTransaction=true
    assert(not s.prepare()and s.count()==0 and #DB_SQL('SELECT * FROM esx_garage_fleet_imports',{})==0)
    s.failTransaction=false;assert(s.prepare()and s.count()==1)
end)

test('only the matching server job resource can provision a fleet',function()
    local _,s=fleetFixture();s.invokingResource='esx_policejob';assert(not s.prepare({{model=123,count=3}})and s.count()==0)
    s.invokingResource='esx_mechanicjob';assert(not s.prepare({{model=123,count=3}})and s.count()==0)
    assert(s.prepare({{model=123,count=1}},'mechanic')and s.count()==1)
end)

test('nontransactional fleet tables are rejected without changing or converting data',function()
    local _,s=fleetFixture();s.engine='MyISAM';s.legacy({{plate='OLD',model=123}})
    assert(not s.prepare({{model=123,count=2}})and s.count()==0 and #DB_SQL('SELECT * FROM esx_garage_fleet_imports',{})==0)
end)

test('cross-resource callable model rules are handled as function references',function()
    local env,s=categorized();s.typed('UNIT','car','police')
    local rule=setmetatable({__cfx_functionReference=true},{__call=function()return{123}end})
    env.ESX.IsFunctionReference=function(value)return type(value)=='table'and value.__cfx_functionReference end
    env.Garages.ground_job.models=rule
    assert(#s.get(2,'ground_job').vehicles==1 and s.take(2,'UNIT','ground_job').success)
end)

test('job adapters reuse each actual config, isolate helicopter points, and preserve duty/model restrictions',function()
    for resource,source in pairs(JOB_CONFIGS)do
        local env,s=fixture();env.GetCurrentResourceName=function()return resource end
        assert(load(source,resource..' config','t',env))()
        local locations=env.Config.PoliceStations or env.Config.Hospitals
        local first
        if locations then for _,location in pairs(locations)do first=location.Vehicles[1];break end end
        local original=first and first.Spawner
        assert(load(SOURCES.integrationConfig,'integration config','t',env))()
        if first then assert(first.GaragePoint==original and #(first.Spawner-original)==6)end
        local registered,prepared
        env.exports.esx_garage={registerGarages=function(_,definitions)registered=definitions end,prepareJobFleet=function(_,job,vehicles)prepared={job,vehicles};return true end}
        env.GetResourceState=function()return'started'end;env.MySQL.ready=function(fn)fn()end
        assert(load(SOURCES.integrationServer,'integration server','t',env))()
        assert(registered and #registered>0,resource)
        local job=registered[1].job;s.players[1].job={name=job,grade=3,grade_name='boss',onDuty=false}
        assert(not registered[1].access.authorize(1));s.players[1].job.onDuty=true;assert(registered[1].access.authorize(1))
        if first then
            local sawHeli=false;for _,garage in ipairs(registered)do assert(garage.entryPoint);if garage.vehicleCategories[1]=='helicopter'then sawHeli=true end end
            assert(sawHeli and first.GaragePoint==original)
        else
            assert(prepared and prepared[1]==job and #prepared[2]>0)
            if job=='mechanic'then assert(#registered[1].models(1)==3);s.players[1].job.grade_name='recrue';assert(#registered[1].models(1)==2)end
        end
    end
end)

test('service integration reuses an employee slot, enforces the cap and releases it',function()
    local env,s=fixture();env.GlobalState={}
    env.RegisterNetEvent=function(name,fn)if fn then s.events[name]=fn end end
    env.ESX.Player=env.ESX.GetPlayerFromId
    assert(load(SOURCES.service,'service','t',env))()
    s.events['esx_service:activateService']('police',1)
    local ok,acquired=s.exports.TryEnableService('police',1);assert(ok and acquired)
    ok,acquired=s.exports.TryEnableService('police',1);assert(ok and not acquired)
    assert(not s.exports.TryEnableService('police',2))
    assert(s.exports.DisableService('police',1)and s.exports.TryEnableService('police',2))
    assert(not s.exports.TryEnableService('police',3))
end)

print(('Passed %d unified garage server scenarios against real SQL predicates.'):format(cases))
