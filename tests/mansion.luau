local L=require("../src/server/MansionLayout")
local C=require("../src/server/WorldContract")
local Clock=require("../src/server/SessionClock")
local Config=require("../src/shared/Config")
local count=0
local function check(ok,why) assert(ok,why); count+=1 end
local function copy(v)
    if type(v)~="table" then return v end
    local result={}; for k,item in pairs(v) do result[k]=copy(item) end; return result
end
local ok,why,nodes=C.validate(L)
check(ok,why)
for id,kind in pairs(C.required) do check(nodes[id].kind==kind,"required semantic "..id) end
for _,n in ipairs(L.nodes) do
    local broken=copy(L)
    table.insert(broken.nodes,copy(n))
    check(not C.validate(broken),"duplicate rejected "..n.id)
end
for id in pairs(C.required) do
    local broken=copy(L)
    for i,n in ipairs(broken.nodes) do if n.id==id then table.remove(broken.nodes,i); break end end
    check(not C.validate(broken),"missing mandatory ID "..id)
end
for _,mutation in ipairs({
    function(x) x.nodes[1].kind="PartGuess" end,
    function(x) x.nodes[1].position={0/0,2,3} end,
    function(x) x.nodes[1].position={900,2,3} end,
    function(x) x.nodes[1].approach={0,0,0} end,
    function(x) x.nodes[1].approach={80,21.5,25} end,
    function(x) x.nodes[1].size={0,1,1} end,
    function(x) x.nodes[1].room="Unknown" end,
    function(x) x.groups.PlayerSpawns={} end,
    function(x) x.groups.Paintings[1]="Absent" end,
    function(x) x.groups.Paintings[1]="Spawn1" end,
    function(x) x.groups.PlayerSpawns[1]="Painting1" end,
    function(x) x.edges[1].b="Absent" end,
    function(x) x.edges[#x.edges].gate="Absent" end,
    function(x) x.stairs[1].width=4 end,
    function(x) x.stairs[1].rise=2 end,
    function(x) x.geometry[1].size[1]=-1 end,
    function(x) x.nodes=nil end,
    function(x) table.insert(x.edges,{a="Courtyard",b="Study",gate="Open"}) end,
    function(x) for i=#x.edges,1,-1 do if x.edges[i].gate=="StudyWindow" then table.remove(x.edges,i) end end end,
    function(x) for i=#x.edges,1,-1 do if x.edges[i].gate=="StudyDoor" then table.remove(x.edges,i) end end end,
    function(x) for i=#x.edges,1,-1 do if x.edges[i].a=="Reading" or x.edges[i].b=="Reading" then table.remove(x.edges,i) end end end,
}) do local broken=copy(L); mutation(broken); check(not C.validate(broken),"invalid contract rejected") end
local open=C.reachable(L,"Foyer",{Open=true})
check(not open.Study,"closed safe room has no free route")
for _,r in ipairs(L.rooms) do if r.id~="Study" then check(open[r.id],"public functional room "..r.id) end end
check(C.reachable(L,"Foyer",{Open=true,StudyWindow=true}).Study,"solo spy independent route")
check(C.reachable(L,"Foyer",{Open=true,StudyDoor=true}).Study,"owner admission route")
for a=1,15 do for b=a+1,15 do
    local p,q=nodes[L.groups.PlayerSpawns[a]].position,nodes[L.groups.PlayerSpawns[b]].position
    check((p[1]-q[1])^2+(p[3]-q[3])^2>=36,"distinct safe spawn spacing")
end end
local clock=Clock.new(); local returned=false
clock:delay(Config.DOSSIER_CARRY_SECONDS,function() returned=true end)
clock:advance(30); clock.running=false; clock:advance(120)
check(not returned,"carry deadline pauses with council")
clock.running=true; clock:advance(29); check(not returned,"carrying time not wall time")
clock:advance(1); check(returned,"configured maximum applies while moving too")
local old=Clock.new(); local stale=false; old:delay(1,function() stale=true end); old:destroy(); old:advance(5)
check(not stale,"destroyed round cancels carried deadline")
print("PASS: "..count.." M6 world schema, access graph, geometry clearance and timer assertions")
