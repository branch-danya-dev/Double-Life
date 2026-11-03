local Catalog=require('../src/server/MimicAppearance')
local P=require('../src/server/MimicCrowdPolicy')
local Suite={}
function Suite.run(load)
    local n=0; local function check(ok,label) assert(ok,label); n+=1 end
    local I=load('MimicIdentity',{MimicAppearance=Catalog})
    local names=I.names({{Name='UniqueOne',DisplayName='miravell'},{Name='UniqueTwo',DisplayName='miravell'},
        {Name='LEONARDEN',DisplayName='Mіra_Ve11'}},{NikaFane=true})
    check(I.name(1,names)=='MiraVell2','duplicate real display names and case avoided')
    check(I.name(2,names)=='LeonArden2','real account name avoided')
    check(I.name(3,names)=='NikaFane2','reserved name avoided')
    check(I.key('Mіra_Ve11')==I.key('MiraVell'),'obvious homoglyph and separator collision')
    local all={}; for i=0,99 do all[I.key('MiraVell'..(if i==0 then '' else tostring(i+1)))]=true end
    check(I.name(1,all)==nil,'bounded name exhaustion')
    for id=1,20 do
        local f=I.preset(id)
        check(I.conflict(f,f),'exact clone '..id)
        local near=table.clone(f); near.Head=-1
        check(I.conflict(f,near),'same outfit and hair, different head '..id)
        near=table.clone(f); near.hair={}
        check(I.conflict(f,near),'same outfit and silhouette, different hair '..id)
        near=table.clone(f); near.Shirt=-1
        check(not I.conflict(f,near),'different outfit allowed '..id)
        local used={}; for other=1,20 do if other~=id then used[other]=true end end
        check(I.pick(Catalog.seed,id,used,{f})==nil,'exhaustion defers '..id)
        check(I.pick(Catalog.seed,id,used,{})==id,'released slot reusable '..id)
        local d=table.clone(f); d.HairAccessory=''; d.GetAccessories=function() return {{AssetId=tonumber(Catalog.presets[id].HairAccessory),AccessoryType='Enum.AccessoryType.Hair'}} end
        check(I.conflict(f,I.description(d)),'normalized layered hair '..id)
    end
    local reserved={}
    for serial=1,20 do local id=I.pick(42,serial,reserved,{}); check(id and not reserved[id],'unique reservation'); reserved[id]=true end
    check(I.pick(42,21,reserved,{})==nil,'no duplicate fallback')
    local RoundService=load('RoundService',{RoundPolicy={}},{game={GetService=function() return {} end}})
    local round=setmetatable({policy={phase='Council',roundId=1,participants={[100]=true},mimics={['m:1']=true},
        remaining=20,savedRemaining=200,cast={}},roster={{id=100,name='ActualAccount'}},protocol={},
        session={actors={get=function() return {name='MiraVell'} end}}},RoundService)
    local snapshot=round:snapshot({UserId=100})
    check(#snapshot.members==2,'public council includes actual human and fictional actor')
    check(snapshot.members[1].id==100 and snapshot.members[1].name=='ActualAccount','human account identity unchanged')
    check(snapshot.members[2].id=='m:1' and snapshot.members[2].name=='MiraVell','public name matches plate without marker')
    round.policy.mimics={}; check(#round:snapshot({UserId=100}).members==1,'removed mimic absent from public roster')
    local function v(x,y,z) return {X=x,Y=y,Z=z} end
    local from,to=v(0,3,0),v(10,3,0)
    local people={{key='player',position=v(5,3,0)}}
    check(P.blocker(from,to,people,'mimic',3.2)==people[1],'stationary player in path')
    check(not P.blocker(from,to,people,'player',3.2),'exclude self')
    check(not P.free(v(5,3,1),people,'mimic',4.2),'occupied stop')
    check(P.free(v(5,20,1),people,'mimic',4.2),'different floors independent')
    check(not P.blocker(v(0,20,0),v(10,20,0),people,'mimic',3.2),'no cross-floor blocking')
    check(not P.blocker(v(5,3,1),v(5,3,5),people,'mimic',3.2),'may separate after player walks into body')
    check(P.blocker(v(5,3,2),v(5,3,0),people,'mimic',3.2)~=nil,'cannot deepen overlap')
    check(P.blocker(from,v(0,3,0),{{key=1,position=v(1,3,0)}},0,3.2)~=nil,'zero segment safe')
    for i=1,25 do local x,z=P.offset(i,3); check(x*x+z*z<=100.01,'bounded standing radius') end
    -- Real Crowd controller with a deterministic engine: physically advances MoveTo,
    -- samples minimum human distance, and verifies wait/cancel rather than teleport.
    local V={}; local mt={}
    function V.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
    mt.__add=function(a,b) return V.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
    mt.__sub=function(a,b) return V.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
    mt.__mul=function(a,b) return V.new(a.X*b,a.Y*b,a.Z*b) end
    mt.__index=function(a,k) if k=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) elseif k=='Unit' then local l=a.Magnitude; return V.new(a.X/l,a.Y/l,a.Z/l) end end
    local time,root,target,minimum=0,{Position=V.new(0,3,0),Parent=true},nil,100
    local env={Vector3=V,CFrame={new=function(p) return p end},workspace={GetPartBoundsInBox=function() return {} end,Blockcast=function() return nil end,Raycast=function(_,p) return {Position=V.new(p.X,0,p.Z),Normal={Y=1}} end},
        task={wait=function(dt) time+=dt; if target then local delta=target-root.Position; local d=V.new(delta.X,0,delta.Z); if d.Magnitude>0.001 then root.Position+=d.Unit*math.min(d.Magnitude,0.9) end end; minimum=math.min(minimum,P.distance(root.Position,v(5,3,0))) end}}
    local Crowd=load('MimicCrowd',{MimicCrowdPolicy=P},env); local crowd=Crowd.new()
    crowd.people=people
    local mover={root=root,preset=1,scope={now=function() return time end},humanoid={MoveTo=function(_,p) target=p end}}
    function mover:near(p,r) return P.distance(root.Position,p)<=r end
    function mover:stop() target=nil end
    check(crowd:walk(mover,V.new(12,3,0),20,function() return true end),'detour reaches target')
    check(minimum>=3.2,'detour does not walk through human')
    check(crowd.metrics.detours>0,'detour measured')
    root.Position=V.new(0,3,0); time=0; env.workspace.Blockcast=function() return {} end
    check(not crowd:walk(mover,V.new(12,3,0),20,function() return true end),'narrow blocked passage waits then yields')
    check(time<2 and root.Position.X==0,'bounded wait without pushing player')
    check(not crowd:walk(mover,V.new(12,3,0),20,function() return false end),'cancel immediate')
    env.workspace.Blockcast=function() return nil end
    local slot=crowd:slot(V.new(5,3,0),'first',1)
    check(slot and P.distance(slot,people[1].position)>=4.2,'standing slot clears human')
    local second=crowd:slot(V.new(5,3,0),'second',1)
    check(second and P.distance(slot,second)>=4.2,'reservations separate concurrent targets')
    crowd:release('first'); crowd:release('second'); check(next(crowd.slots)==nil,'reservations cleanup')
    env.workspace.GetPartBoundsInBox=function() return {{}} end
    check(crowd:slot(V.new(0,3,0),'wall',1)==nil,'initial solid overlap cannot be a spawn or stop')
    env.workspace.GetPartBoundsInBox=function() return {} end
    env.workspace.Raycast=function() return nil end
    check(crowd:slot(V.new(0,3,0),'none',1)==nil,'no floor defers, no broken fallback')
    env.workspace.Raycast=function(_,p) return {Position=V.new(p.X,0,p.Z),Normal={Y=1}} end
    env.task.spawn=function(f) f() end
    env.Vector2={new=function(x,z) return {Magnitude=math.sqrt(x*x+z*z)} end}
    env.Enum={PathStatus={Success='Success'},PathWaypointAction={Jump='Jump'}}
    env.game={GetService=function() return {CreatePath=function()
        return {Status='Success',ComputeAsync=function() end,Destroy=function() end,
            Blocked={Connect=function() return {Disconnect=function() end} end},
            GetWaypoints=function() return {{Position=V.new(0,0,0)},{Position=V.new(4,0,0)},{Position=V.new(8,0,0)},{Position=V.new(12,0,0)}} end}
    end} end}
    local Mover=load('NpcMover',{},env)
    time=0; root.Position=V.new(0,3,0); target=nil; minimum=100
    local routed=setmetatable({root=root,preset=1,crowd=crowd,humanoid={Health=100,MoveTo=function(_,p) target=p end},
        scope={alive=true,running=true,now=function() return time end},metrics={computes=0,failures=0,timeouts=0,arrivals=0,computeSeconds=0}},Mover)
    check(routed:move(V.new(12,3,0),30,function() return false end),'actual path skips occupied intermediate waypoints and reaches goal')
    check(minimum>=3.2 and routed.metrics.computes==1,'one path, safe physical route past stationary player')
    print('M11.2 identity and crowd runtime:',n,'assertions PASS')
end
return Suite
