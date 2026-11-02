-- Pure validation; physical traversability is additionally checked in Studio.
local C={}
C.required={OwnerConsole="Object",StudyDoor="Object",StudyWindow="Object",Safe="Object",ForensicLog="Object",MainExit="Object",Glass="Object",
    ["Service.Pantry"]="Object",["Service.Home"]="Point",["Events.Stage"]="Object",["Events.Pedestal"]="Object",["Events.Console"]="Object",
    ["Events.Bell"]="Object",["Events.Beacon"]="Object",["Social.PassReader"]="Object",["Social.Egress"]="Object",["Social.ParcelHome"]="Object",
    ["Social.Cloth"]="Object",["Social.Delivery"]="Object",["Social.TraceSpot"]="Object",["Evidence.Home"]="Point",["Guard.Spawn"]="Point",
    ["Guard.InspectStudy"]="Point",["Guard.Window"]="Point",["Guard.Glass"]="Point",["Guard.Bell"]="Point",["Guard.Event"]="Point"}
C.groups={PlayerSpawns=15,Paintings=3,["Service.Targets"]=2,["Patrol.Corridor"]=3,["Patrol.Foyer"]=3,["Events.RelicSpots"]=3,["Guard.Incidents"]=2,Lamps=1,PathLights=1}
local objectGroups={Paintings=true,["Service.Targets"]=true}
local function vector(p)
    if type(p)~="table" or #p~=3 then return false end
    for _,v in ipairs(p) do if type(v)~="number" or v~=v or math.abs(v)>10000 then return false end end
    return true
end
function C.reachable(l,start,allowed)
    local seen,queue={[start]=true},{start}
    for _,room in ipairs(queue) do
        for _,e in ipairs(l.edges) do
            local other=if e.a==room then e.b elseif e.b==room then e.a else nil
            if other and allowed[e.gate] and not seen[other] then seen[other]=true; table.insert(queue,other) end
        end
    end
    return seen
end
function C.validate(l)
    local function fail(s) return false,"World contract: "..s end
    if type(l)~="table" or l.version~=1 then return fail("unsupported schema") end
    for _,field in ipairs({"rooms","nodes","groups","edges","geometry","stairs","navigation"}) do
        if type(l[field])~="table" then return fail("missing table "..field) end
    end
    local rooms,nodes,names={},{},{}
    for _,r in ipairs(l.rooms) do
        if rooms[r.id] or not vector(r.min) or not vector(r.max) then return fail("invalid/duplicate room "..tostring(r.id)) end
        for i=1,3 do if r.min[i]>=r.max[i] then return fail("room bounds "..r.id) end end
        rooms[r.id]=r
    end
    for _,n in ipairs(l.nodes) do
        if type(n.id)~="string" or nodes[n.id] then return fail("duplicate/invalid ID "..tostring(n.id)) end
        if not rooms[n.room] or not vector(n.position) then return fail("invalid point "..n.id) end
        if n.kind~="Point" and n.kind~="Object" then return fail("unknown kind "..n.id) end
        local r=rooms[n.room]
        for i=1,3 do if n.position[i]<r.min[i] or n.position[i]>r.max[i] then return fail("out of room "..n.id) end end
        if n.kind=="Object" then
            if not vector(n.size) or not vector(n.approach) or type(n.name)~="string" or names[n.name] then return fail("object type/name "..n.id) end
            for _,v in ipairs(n.size) do if v<=0 then return fail("object size "..n.id) end end
            local distance=0
            for i=1,3 do distance+=(n.approach[i]-n.position[i])^2 end
            if distance>100 then return fail("approach out of interaction reach "..n.id) end
            names[n.name]=true
        end
        nodes[n.id]=n
    end
    for id,kind in pairs(C.required) do if not nodes[id] or nodes[id].kind~=kind then return fail("required "..id.." : "..kind) end end
    for name,count in pairs(C.groups) do if type(l.groups[name])~="table" or #l.groups[name]<count then return fail("required group "..name) end end
    for name,group in pairs(l.groups) do
        local seen={}
        for _,id in ipairs(group) do
            if not nodes[id] or seen[id] then return fail("group "..name.." ID "..tostring(id)) end
            if C.groups[name] and nodes[id].kind~=(if objectGroups[name] then "Object" else "Point") then return fail("group type "..name.." ID "..id) end
            seen[id]=true
        end
    end
    for _,e in ipairs(l.edges) do
        if not rooms[e.a] or not rooms[e.b] or e.a==e.b then return fail("invalid room link") end
        if e.gate~="Open" and (not nodes[e.gate] or nodes[e.gate].kind~="Object") then return fail("unknown gate "..e.gate) end
    end
    local open=C.reachable(l,"Foyer",{Open=true})
    if open.Study then return fail("unprotected Study bypass") end
    for id in pairs(rooms) do if id~="Study" and not open[id] then return fail("unreachable room "..id) end end
    if not C.reachable(l,"Foyer",{Open=true,StudyWindow=true}).Study then return fail("no independent spy route") end
    if not C.reachable(l,"Foyer",{Open=true,StudyDoor=true}).Study then return fail("no legal access route") end
    for _,s in ipairs(l.stairs) do if s.width<10 or s.rise>1 or s.depth<2 or s.steps*s.rise~=18 then return fail("unsafe stairs "..s.id) end end
    local ids={}
    for _,g in ipairs(l.geometry) do
        if ids[g.id] or not vector(g.position) or not vector(g.size) then return fail("invalid geometry "..tostring(g.id)) end
        for _,v in ipairs(g.size) do if v<=0 then return fail("invalid geometry size "..g.id) end end
        ids[g.id]=true
    end
    for _,n in ipairs(l.nodes) do
        if n.approach then
            for _,g in ipairs(l.geometry) do
                local p,s,c=n.approach,g.size,g.position
                if g.collide~=false and math.abs(p[1]-c[1])<s[1]/2+1.5 and math.abs(p[3]-c[3])<s[3]/2+1.5
                    and p[2]+3>c[2]-s[2]/2+0.05 and p[2]-3<c[2]+s[2]/2-0.05 then return fail("blocked approach "..n.id.." by "..g.id) end
            end
        end
    end
    return true,"World contract OK",nodes
end
return C
