-- Original native geometry. This module never edits navigation/collision data.
local Art = {}
Art.budgets = {staticParts=1800, roundParts=260, lights=22, animatedNPCs=2, particles=0}
Art.palette = {
    Ink={23,34,39}, Walnut={61,39,32}, Brass={180,143,78}, Ivory={218,207,181},
    Teal={33,74,76}, Wine={95,40,48}, Sage={72,98,82}, Stone={111,116,116},
    Paper={235,224,192}, Glow={255,216,151}, Blue={57,76,99}, Leaf={43,74,60},
}
Art.rooms = {Foyer="Teal",Gallery="Wine",Ballroom="Teal",Reading="Wine",ServiceHall="Sage",
    Pantry="Sage",Promenade="Blue",Archive="Wine",Study="Blue",UpperService="Sage",Terrace="Stone"}
function Art.skin(g)
    if string.find(g.id,"Boundary") then return "Leaf","Grass" end
    if string.find(g.id,"Rail") then return "Walnut","Wood" end
    if g.color=="Floor" then return "Walnut","WoodPlanks" end
    if g.color=="Grass" then return "Leaf","Grass" end
    if g.color=="Glass" then return "Blue","Glass" end
    if g.color=="Wood" then return "Walnut","Wood" end
    return "Ivory","SmoothPlastic"
end
function Art.build(layout)
    local parts = {}
    local function add(name,size,position,color,material,rotation,shape)
        table.insert(parts,{name=name,size=size,position=position,color=color,material=material or "SmoothPlastic",
            rotation=rotation,shape=shape,collide=false,query=false})
    end
    -- Segment-aware mouldings end at existing openings; no new door or wall.
    for _,g in ipairs(layout.geometry) do
        local s,p=g.size,g.position
        if s[2]>5 and (s[1]==1 or s[3]==1) and not string.find(g.id,"Boundary") then
            local alongX=s[3]==1
            local span=if alongX then s[1] else s[3]
            local function strip(name,width,height,y,color,thickness)
                add(g.id..name,if alongX then {width,height,thickness} else {thickness,height,width},
                    {p[1],y,p[3]},color,if color=="Walnut" then "Wood" else "SmoothPlastic")
            end
            local bottom,top=p[2]-s[2]/2,p[2]+s[2]/2
            strip("Cornice",span+0.12,0.16,top-1.05,"Brass",1.2)
            strip("Crown",span+0.16,0.4,top-0.65,"Ivory",1.55)
            if s[2]>12 and g.color~="Glass" then
                strip("Panel",span,4.6,bottom+2.3,"Walnut",1.08)
                strip("Dado",span,0.14,bottom+4.65,"Brass",1.25)
                strip("Skirting",span,0.3,bottom+0.2,"Ink",1.25)
                for d=-span/2+1.4,span/2-1.4,7 do
                    local x,z=if alongX then p[1]+d else p[1],if alongX then p[3] else p[3]+d
                    add(g.id.."Flute",if alongX then {0.11,3.7,1.15} else {1.15,3.7,0.11},{x,bottom+2.35,z},"Brass")
                end
                for d=-span/2+4,span/2-4,10 do
                    local x,z=if alongX then p[1]+d else p[1],if alongX then p[3] else p[3]+d
                    for _,side in ipairs({-1,1}) do
                        add(g.id.."UpperPanelSide",if alongX then {0.06,4.8,1.12} else {1.12,4.8,0.06},
                            {x+(if alongX then side*2.7 else 0),bottom+9.8,z+(if alongX then 0 else side*2.7)},"Brass")
                        add(g.id.."UpperPanelRail",if alongX then {5.4,0.06,1.12} else {1.12,0.06,5.4},
                            {x,bottom+9.8+side*2.4,z},"Brass")
                    end
                end
            end
        end
        if string.find(g.id,"Furniture") then
            -- Upholstery fits the old bench collider. Backs remain at its rear edge.
            add(g.id.."Seat",{6.8,0.4,2.9},{p[1],p[2]+1.12,p[3]},"Teal","Fabric")
            add(g.id.."Back",{6.8,2.1,0.32},{p[1],p[2]+1.8,p[3]+1.35},"Teal","Fabric")
            for _,x in ipairs({-3.4,3.4}) do
                add(g.id.."Arm",{0.28,1,3},{p[1]+x,p[2]+1.5,p[3]},"Brass","Metal")
            end
        end
    end
    for _,r in ipairs(layout.rooms) do
        local accent=Art.rooms[r.id]
        if accent then
            local x,z,y=(r.min[1]+r.max[1])/2,(r.min[3]+r.max[3])/2,r.min[2]
            local w,d=r.max[1]-r.min[1]-9,r.max[3]-r.min[3]-9
            add(r.id.."RugBorder",{w,0.025,d},{x,y+0.025,z},"Brass")
            add(r.id.."Rug",{w-0.5,0.025,d-0.5},{x,y+0.05,z},accent,"Fabric")
            for _,side in ipairs({-1,1}) do
                add(r.id.."RunnerEdge",{0.07,0.025,d-1.8},{x+side*(w/2-0.8),y+0.075,z},"Brass")
            end
            -- Layered geometric ceiling rose, pendant and opaline glass tubes.
            add(r.id.."CeilingRose",{7.6,0.12,7.6},{x,y+16.85,z},"Brass",nil,{0,math.pi/4,0})
            add(r.id.."RoseInset",{6.9,0.14,6.9},{x,y+16.72,z},accent,nil,{0,math.pi/4,0})
            add(r.id.."Pendant",{0.14,3.2,0.14},{x,y+15.6,z},"Brass","Metal")
            add(r.id.."Chandelier",{4.6,0.25,4.6},{x,y+13.9,z},"Brass","Metal",{0,math.pi/4,0})
            for i=1,8 do
                local a=i*math.pi/4
                add(r.id.."Opal",{0.5,1.5,0.5},{x+math.cos(a)*2.2,y+13,z+math.sin(a)*2.2},"Paper","SmoothPlastic")
            end
            -- Small planters against the far corners, outside the approach lanes.
            if r.id~="Promenade" then
                for _,side in ipairs({-1,1}) do
                    local px,pz=x+side*(w/2+2),r.max[3]-2
                    add(r.id.."Planter",{1.7,1.8,1.7},{px,y+0.9,pz},"Ink")
                    add(r.id.."PotRim",{1.85,0.18,1.85},{px,y+1.7,pz},"Brass","Metal")
                    for k=1,3 do
                        add(r.id.."Palm",{0.3,3.4,1.8},{px+(k-2)*0.5,y+3,pz},"Leaf",nil,{0,k,0.25*(k-2)})
                    end
                end
            end
        end
    end
    -- Reading-room shelves and the archive are distinct from the public salon.
    for _,shelf in ipairs({{-51,0.5,35},{-51,0.5,55},{-51,18.5,38},{-51,18.5,56}}) do
        local x,y,z=shelf[1],shelf[2],shelf[3]
        add("LibraryCase",{2,9,6},{x,y+4.5,z},"Walnut","Wood")
        for tier=1,3 do
            add("ShelfLip",{2.2,0.15,6.2},{x,y+tier*2.7,z},"Brass")
            for book=1,6 do
                add("BookSpine",{0.25,1.6+(book%2)*0.3,0.6},{x+1.1,y+tier*2.7-1,z-2.5+book*0.72},
                    ({"Wine","Teal","Paper"})[book%3+1],"Fabric")
            end
        end
    end
    -- Recognizable foyer crest and exterior entrance; all visual only.
    for _,x in ipairs({-10,10}) do
        add("EntryPillar",{1.5,12,1.5},{x,6.5,-39.2},"Ivory","Marble")
        add("EntryCapital",{2,0.4,2},{x,12.5,-39.2},"Brass")
    end
    for i=1,5 do
        add("FoyerFan",{0.16,5.5,0.18},{(i-3)*0.85,14,-39.3},"Brass","Metal",{0,0,(i-3)*0.21})
    end
    for _,x in ipairs({-62,62}) do
        -- Stair runners remain flush to decorative treads, never change the ramp.
        for i=1,18 do
            add("StairRunner",{5,0.025,1.9},{x,0.5+i+0.02,19+i*2},"Wine","Fabric")
            add("StairNosing",{11.9,0.08,0.08},{x,0.5+i,18.04+i*2},"Brass")
        end
    end
    for _,x in ipairs({-40,-24,24,40}) do
        add("PromenadeMullion",{0.18,16,1.12},{x,27,16},"Brass","Metal")
    end
    assert(#parts<=Art.budgets.staticParts,"M7 static art budget exceeded")
    return parts
end
return Art
