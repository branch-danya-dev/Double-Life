-- World-space coordinates live here. Services consume semantic IDs, never geometry.
local L = {version=1, rooms={}, nodes={}, groups={}, edges={}, geometry={}, stairs={},
    navigation={patrolSeconds=40, investigateSeconds=40, returnSeconds=40, serviceSeconds=45}}
local function room(id,label,x1,z1,x2,z2,floor)
    table.insert(L.rooms,{id=id,label=label,min={x1,floor,z1},max={x2,floor+18,z2}})
end
room("Foyer","1 · ПРИЁМНАЯ / ВЫХОД ↓",-18,-40,18,16,0.5)
room("Gallery","1 · ГАЛЕРЕЯ / ЛЕСТНИЦА ↑",-54,-40,-18,16,0.5)
room("Ballroom","1 · БАЛЬНЫЙ ЗАЛ / ЛЕСТНИЦА ↑",18,-40,54,16,0.5)
room("Reading","1 · ЧИТАЛЬНЯ",-54,16,-18,64,0.5)
room("ServiceHall","1 · ПРИЁМ КОЛЛЕКЦИИ",-18,16,18,64,0.5)
room("Pantry","1 · БУФЕТ / ЗАКАЗЫ",18,16,54,64,0.5)
room("Promenade","2 · КАБИНЕТ ПО ДОПУСКУ",-54,16,54,32,18.5)
room("Archive","2 · АРХИВ / ТЕРРАСА ↑",-54,32,-18,64,18.5)
room("Study","2 · КАБИНЕТ / КНОПКА ВЫХОДА",-18,32,18,64,18.5)
room("UpperService","2 · СЛУЖЕБНАЯ ГОСТИНАЯ",18,32,54,64,18.5)
room("Terrace","2 · ТЕРРАСА / ОКНО КАБИНЕТА",-54,64,54,80,18.5)
room("Courtyard","ДВОР / ЭКСТРАКЦИЯ ↓",-82,-58,82,84,0.5)
room("WestStair","ЗАПАДНАЯ ЛЕСТНИЦА",-72,6,-54,64,0.5)
room("EastStair","ВОСТОЧНАЯ ЛЕСТНИЦА",54,6,72,64,0.5)
for _,r in ipairs(L.rooms) do if string.find(r.id,"Stair") then r.max[2]=36.5 end end
local function link(a,b,gate) table.insert(L.edges,{a=a,b=b,gate=gate or "Open"}) end
link("Courtyard","Foyer"); link("Courtyard","WestStair")
link("Foyer","Gallery"); link("Foyer","Ballroom"); link("Foyer","ServiceHall")
link("Gallery","Reading"); link("Ballroom","Pantry"); link("Reading","ServiceHall"); link("Pantry","ServiceHall")
link("Gallery","WestStair"); link("Ballroom","EastStair")
link("WestStair","Archive"); link("EastStair","UpperService")
link("Archive","Promenade"); link("UpperService","Promenade")
link("Archive","Terrace"); link("UpperService","Terrace")
link("Promenade","Study","StudyDoor"); link("Terrace","Study","StudyWindow")
local function point(id,zone,p)
    table.insert(L.nodes,{id=id,room=zone,kind="Point",position=p}); return id
end
local function object(id,name,zone,p,size,approach,color)
    table.insert(L.nodes,{id=id,name=name,room=zone,kind="Object",position=p,size=size,approach=approach,color=color or "Gold"}); return id
end
object("OwnerConsole","OwnerAccessConsole","Promenade",{8,20,25},{2,3,2},{5,21.5,25})
object("StudyDoor","StudyDoor","Study",{0,24.5,32},{10,12,1},{0,21.5,27},"Wood")
object("StudyWindow","StudyWindow","Study",{0,24.5,64},{10,12,1},{0,21.5,69},"Glass")
object("Safe","DocumentSafe","Study",{0,20.5,56},{5,4,3},{0,21.5,51})
object("ForensicLog","ForensicLog","Study",{11,20,54},{2,1,2},{11,21.5,50},"Wood")
object("MainExit","EstateExit","Courtyard",{0,5.5,-54},{12,10,1},{0,3.5,-49},"Green")
object("Glass","BreakableGlass","Ballroom",{45,2,-27},{0.8,1.4,0.8},{42,3.5,-27},"Glass")
object("Service.Pantry","ServicePantry","Pantry",{39,2,40},{4,3,3},{34,3.5,40},"Green")
point("Service.Home","Pantry",{34,3.5,40})
object("Service.Target1","ServicePoint1","Ballroom",{28,1.5,-26},{2,2,2},{28,3.5,-22},"Green")
object("Service.Target2","ServicePoint2","Archive",{-44,19.5,45},{2,2,2},{-40,21.5,45},"Green")
L.groups["Service.Targets"]={"Service.Target1","Service.Target2"}
object("Events.Stage","MusicFloor","Ballroom",{36,0.65,-3},{18,0.12,16},{36,3.5,-3},"Teal")
object("Events.Pedestal","RelicPedestal","Ballroom",{24,1.5,9},{3,2,3},{24,3.5,5})
object("Events.Console","EventConsole","Ballroom",{44,2,10},{2,3,2},{40,3.5,10},"Blue")
object("Events.Bell","PracticeBell","Ballroom",{47,1.7,-18},{1.5,2,1.5},{43,3.5,-18})
object("Events.Beacon","MusicSignal","Ballroom",{47,3.5,1},{1,6,1},{44,3.5,1},"Blue")
L.groups["Events.RelicSpots"]={point("Relic.Reading","Reading",{-40,1.5,45}),point("Relic.Gallery","Gallery",{-32,1.5,-25}),point("Relic.Archive","Archive",{-28,19.5,48})}
object("Social.PassReader","PassReader","Promenade",{-8,21,28},{1.5,1,1.5},{-8,21.5,24},"Teal")
object("Social.Egress","StudyEgress","Study",{8,21,36},{1.5,1,1.5},{8,21.5,40},"Teal")
object("Social.ParcelHome","CollectionLabel","Study",{-10,20,52},{1.5,1,1.5},{-10,21.5,48},"Wood")
object("Social.Cloth","ClothStand","Pantry",{28,2,50},{1.5,1,1.5},{28,3.5,46},"Wood")
object("Social.Delivery","CollectionDelivery","ServiceHall",{-10,2,33},{1.5,1,1.5},{-6,3.5,33},"Green")
object("Social.TraceSpot","FabricTrace","Terrace",{8,18.8,68},{1.5,0.3,1.5},{8,21.5,72},"Wood")
L.groups.Paintings={}
for i,z in ipairs({-28,-12,4}) do table.insert(L.groups.Paintings,object("Painting"..i,"Painting"..i,"Gallery",{-53.1,5.5,z},{0.6,4,4},{-49,3.5,z},"Painting")) end
point("Evidence.Home","Study",{4,18.9,55})
point("Guard.Spawn","Promenade",{20,21.5,24})
point("Guard.InspectStudy","Study",{5,21.5,46})
point("Guard.Window","Terrace",{0,21.5,72})
point("Guard.Glass","Ballroom",{40,3.5,-27})
point("Guard.Bell","Ballroom",{40,3.5,-18})
point("Guard.Event","Ballroom",{27,3.5,0})
L.groups["Patrol.Corridor"]={point("Patrol.West","Promenade",{-28,21.5,24}),point("Patrol.Center","Promenade",{0,21.5,24}),point("Patrol.East","UpperService",{36,21.5,47})}
L.groups["Patrol.Foyer"]={point("Patrol.Foyer","Foyer",{0,3.5,-15}),point("Patrol.Ballroom","Ballroom",{30,3.5,-12}),point("Patrol.Service","ServiceHall",{0,3.5,40})}
L.groups["Guard.Incidents"]={"Patrol.Center","Patrol.Ballroom"}
L.groups.PlayerSpawns={}
for i=1,15 do table.insert(L.groups.PlayerSpawns,point("Spawn"..i,"Foyer",{-12+((i-1)%5)*6,3.5,-30+math.floor((i-1)/5)*6})) end
L.groups.Lamps,L.groups.PathLights={},{}
for _,r in ipairs(L.rooms) do
    if r.id~="Courtyard" and not string.find(r.id,"Stair") then
        table.insert(L.groups.Lamps,point("Lamp."..r.id,r.id,{(r.min[1]+r.max[1])/2,r.min[2]+12,(r.min[3]+r.max[3])/2}))
        table.insert(L.groups.PathLights,point("PathLight."..r.id,r.id,{(r.min[1]+r.max[1])/2,r.min[2]+0.15,(r.min[3]+r.max[3])/2}))
    end
end
local function box(id,size,pos,color,transparency) table.insert(L.geometry,{id=id,size=size,position=pos,color=color or "Stone",transparency=transparency}) end
local function wall(axis,id,fixed,low,high,base,height,openings,glass)
    table.sort(openings,function(a,b) return a[1]<b[1] end)
    local cursor,index=low,0
    local function segment(a,b,h,y)
        if b<=a then return end
        index+=1
        box(id..index,if axis=="X" then {1,h,b-a} else {b-a,h,1},if axis=="X" then {fixed,y,(a+b)/2} else {(a+b)/2,y,fixed},if glass then "Glass" else "Stone",if glass then 0.45 else nil)
    end
    for _,gap in ipairs(openings) do
        segment(cursor,gap[1]-gap[2]/2,height,base+height/2)
        segment(gap[1]-gap[2]/2,gap[1]+gap[2]/2,height-gap[3],base+gap[3]+(height-gap[3])/2)
        cursor=gap[1]+gap[2]/2
    end
    segment(cursor,high,height,base+height/2)
end
box("Ground",{164,1,142},{0,-0.1,13},"Grass")
box("GroundFloor",{108,1,104},{0,0,12},"Floor")
box("UpperFloor",{108,1,64},{0,18,48},"Floor")
box("LowerCeiling",{108,1,56},{0,18,-12},"Stone")
box("UpperRoof",{108,1,64},{0,36,48},"Stone")
for _,x in ipairs({-54,54}) do
    wall("X","OuterLower"..x,x,-40,64,0.5,17.5,{{10,12,12}})
    wall("X","OuterUpper"..x,x,16,80,18.5,17.5,{{60,12,12}})
end
for _,x in ipairs({-18,18}) do
    wall("X","LowerPartition"..x,x,-40,64,0.5,17.5,{{-12,12,12},{40,12,12}})
    wall("X","StudySide"..x,x,32,64,18.5,17.5,{})
end
wall("Z","Entry",-40,-54,54,0.5,17.5,{{0,14,12}})
wall("Z","GroundCross",16,-54,54,0.5,17.5,{{-36,12,12},{0,12,12},{36,12,12}})
wall("Z","GroundRear",64,-54,54,0.5,17.5,{})
wall("Z","UpperFront",16,-54,54,18.5,17.5,{},true)
wall("Z","StudyFront",32,-54,54,18.5,17.5,{{-36,12,12},{0,10,12},{36,12,12}})
wall("Z","TerraceAccess",64,-54,54,18.5,17.5,{{-36,12,12},{0,10,12},{36,12,12}})
wall("Z","TerraceRear",80,-54,54,18.5,17.5,{})
for _,x in ipairs({-62,62}) do
    local id=if x<0 then "WestStair" else "EastStair"
    table.insert(L.stairs,{id=id,center=x,start=20,steps=18,depth=2,rise=1,width=12})
    box(id.."Base",{18,1,58},{x,0,35},"Floor"); box(id.."Landing",{18,1,8},{x,18,60},"Floor"); box(id.."Roof",{18,1,58},{x,36,35},"Stone")
    wall("X",id.."Outer",if x<0 then -72 else 72,6,64,0.5,35.5,if x<0 then {{12,10,12}} else {})
    wall("Z",id.."South",6,x-9,x+9,0.5,35.5,{})
    wall("Z",id.."North",64,x-9,x+9,0.5,35.5,{})
    -- Smooth collision ramp under the visible treads: prevents R15 downhill snagging.
    local angle=math.atan(0.5)
    box(id.."WalkSurface",{12,1,math.sqrt(36*36+18*18)},{x,9.5-math.cos(angle)/2,38+math.sin(angle)/2},"Floor")
    L.geometry[#L.geometry].rotation={-angle,0,0}
    for i=1,18 do
        box(id.."Step"..i,{12,i,2},{x,0.5+i/2,19+i*2},"Floor")
        L.geometry[#L.geometry].collide=false
        for _,side in ipairs({-6.5,6.5}) do box(id.."Rail"..side.."_"..i,{1,4,2},{x+side,2.5+i,19+i*2},"Wood") end
    end
end
for _,x in ipairs({-82,82}) do wall("X","Boundary"..x,x,-58,84,0.5,40,{}) end
for _,z in ipairs({-58,84}) do wall("Z","Boundary"..z,z,-82,82,0.5,40,{}) end
for i,p in ipairs({{-36,1.5,-34},{-46,1.5,54},{36,1.5,56},{-27,19.5,56},{45,19.5,50}}) do box("Furniture"..i,{7,2,3},p,"Wood") end
return L
