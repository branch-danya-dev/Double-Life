local Plan = require(script.Parent.MansionArtPlan)
local Art = {}
local function v(p) return Vector3.new(p[1],p[2],p[3]) end
function Art.color(key) return Color3.fromRGB(table.unpack(Plan.palette[key])) end
local function piece(parent,name,size,cf,color,material)
    local p=Instance.new("Part")
    p.Name,p.Size,p.CFrame=name,size,cf
    p.Color,p.Material=Art.color(color),Enum.Material[material or "SmoothPlastic"]
    p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch,p.CastShadow=true,false,false,false,false
    p.Parent=parent
    return p
end
function Art.build(world)
    local folder=Instance.new("Folder"); folder.Name,folder.Parent="ArtDeco",world.static
    for _,spec in ipairs(Plan.build(world.layout)) do
        local cf=CFrame.new(v(spec.position))
        if spec.rotation then cf*=CFrame.Angles(table.unpack(spec.rotation)) end
        piece(folder,spec.name,v(spec.size),cf,spec.color,spec.material)
    end
    world.metrics.artParts=#folder:GetChildren()
    local lighting=game:GetService("Lighting")
    lighting.ClockTime,lighting.Brightness=19.1,1.2
    lighting.Ambient,lighting.OutdoorAmbient=Color3.fromRGB(118,110,103),Color3.fromRGB(92,104,133)
    lighting.EnvironmentDiffuseScale,lighting.EnvironmentSpecularScale=0.6,0.5
    lighting.GlobalShadows=true
    -- Named effects are replaced only on a full world rebuild.
    for _,name in ipairs({"MansionHaze","MansionGrade","MansionBloom"}) do
        local old=lighting:FindFirstChild(name); if old then old:Destroy() end
    end
    local haze=Instance.new("Atmosphere")
    haze.Name,haze.Density,haze.Offset,haze.Haze,haze.Glare="MansionHaze",0.22,0.2,1,0
    haze.Color,haze.Decay,haze.Parent=Color3.fromRGB(173,186,206),Color3.fromRGB(75,80,110),lighting
    local grade=Instance.new("ColorCorrectionEffect")
    grade.Name,grade.Contrast,grade.Saturation,grade.TintColor,grade.Parent="MansionGrade",0.06,-0.08,Color3.fromRGB(255,245,224),lighting
    local bloom=Instance.new("BloomEffect")
    bloom.Name,bloom.Intensity,bloom.Size,bloom.Threshold,bloom.Parent="MansionBloom",0.12,16,1.5,lighting
end
function Art.interactive(part,id)
    local function detail(name,size,offset,color,rotation)
        local cf=part.CFrame*CFrame.new(offset)
        if rotation then cf*=CFrame.Angles(table.unpack(rotation)) end
        return piece(part,name,size,cf,color)
    end
    part.Material=Enum.Material.Wood
    part.Color=Art.color("Walnut")
    if id=="StudyDoor" or id=="StudyWindow" then
        if id=="StudyWindow" then part.Material,part.Color=Enum.Material.Glass,Art.color("Blue") end
        for _,x in ipairs({-4.65,0,4.65}) do detail("DecoStile",Vector3.new(0.17,11.8,1.12),Vector3.new(x,0,0),"Brass") end
        for _,y in ipairs({-5.6,0,5.6}) do detail("DecoRail",Vector3.new(9.5,0.15,1.12),Vector3.new(0,y,0),"Brass") end
        -- Door openness is authoritative. No lingering opaque ornaments when open.
        part:GetPropertyChangedSignal("Transparency"):Connect(function()
            for _,p in ipairs(part:GetChildren()) do if p:IsA("BasePart") then p.Transparency=if part.Transparency>=0.8 then 0.85 else 0 end end
        end)
    elseif string.find(id,"Painting") then
        part.Color=Art.color("Ink")
        for _,z in ipairs({-2.15,2.15}) do detail("Frame",Vector3.new(0.8,4.6,0.2),Vector3.new(0,0,z),"Brass") end
        for _,y in ipairs({-2.15,2.15}) do detail("Frame",Vector3.new(0.8,0.2,4.6),Vector3.new(0,y,0),"Brass") end
        local index=tonumber(string.sub(id,-1)) or 1
        for i=1,5 do
            detail("OriginalArtwork",Vector3.new(0.08,0.3+i*0.45,0.28),Vector3.new(0.35,-0.3,-1.65+i*0.55),
                ({"Paper","Brass","Teal"})[index],{math.rad((i-3)*12),0,0})
        end
    elseif id=="Safe" then
        part.Material,part.Color=Enum.Material.Metal,Art.color("Ink")
        detail("SafeFace",Vector3.new(4.4,3.4,0.08),Vector3.new(0,0,-1.55),"Brass")
        detail("SafeInset",Vector3.new(4.15,3.15,0.08),Vector3.new(0,0,-1.61),"Ink")
        local dial=detail("Dial",Vector3.new(0.85,0.85,0.3),Vector3.new(-0.7,0,-1.8),"Brass"); dial.Shape=Enum.PartType.Ball
        detail("Handle",Vector3.new(0.14,1.2,0.2),Vector3.new(1,0,-1.85),"Brass")
    elseif id=="Events.Stage" then
        part.Material,part.Color=Enum.Material.Marble,Art.color("Teal")
        for _,z in ipairs({-7.6,7.6}) do detail("DanceBorder",Vector3.new(17.5,0.025,0.12),Vector3.new(0,0.08,z),"Brass") end
        for _,x in ipairs({-8.6,8.6}) do detail("DanceBorder",Vector3.new(0.12,0.025,15),Vector3.new(x,0.08,0),"Brass") end
    elseif id=="Social.TraceSpot" or id=="Glass" or id=="MainExit" then
        -- These sources are hidden/revealed by gameplay, so do not attach decoration.
        part.Color=Art.color(if id=="MainExit" then "Teal" else "Paper")
    elseif id=="Service.Pantry" then
        detail("Countertop",Vector3.new(4.3,0.18,3.3),Vector3.new(0,1.6,0),"Ivory")
        detail("Tray",Vector3.new(3.4,0.1,2.1),Vector3.new(0,1.8,0),"Brass")
        for _,x in ipairs({-1,0,1}) do
            local cup=detail("JuiceGlass",Vector3.new(0.8,0.5,0.5),Vector3.new(x,2.25,0),"Paper",{0,0,math.pi/2})
            cup.Shape,cup.Material,cup.Transparency=Enum.PartType.Cylinder,Enum.Material.Glass,0.25
            local juice=detail("Juice",Vector3.new(0.45,0.4,0.4),Vector3.new(x,2.14,0),"Brass",{0,0,math.pi/2})
            juice.Shape=Enum.PartType.Cylinder
        end
    elseif id=="Events.Bell" then
        local bell=detail("BrassBell",Vector3.new(1.3,1.3,1.3),Vector3.new(0,1.15,0),"Brass")
        bell.Shape=Enum.PartType.Ball
        detail("BellHandle",Vector3.new(0.16,0.65,0.16),Vector3.new(0,1.95,0),"Walnut")
        detail("BellFoot",Vector3.new(1.6,0.15,1.6),Vector3.new(0,0.65,0),"Brass")
    elseif id=="Events.Beacon" then
        part.Material=Enum.Material.Neon
    else
        detail("BrassEdge",Vector3.new(part.Size.X+0.08,0.12,part.Size.Z+0.08),Vector3.new(0,part.Size.Y/2+0.05,0),"Brass")
        if string.find(id,"Service.Target") then
            local top=detail("RoundTable",Vector3.new(0.18,3.8,3.8),Vector3.new(0,part.Size.Y/2+0.15,0),"Teal",{0,0,math.pi/2})
            top.Shape=Enum.PartType.Cylinder
            local cup=detail("Glass",Vector3.new(0.45,0.65,0.45),Vector3.new(0.6,part.Size.Y/2+0.55,0),"Paper"); cup.Material=Enum.Material.Glass
        else
            detail("Inlay",Vector3.new(part.Size.X*0.6,0.04,part.Size.Z*0.6),Vector3.new(0,part.Size.Y/2+0.13,0),"Paper")
        end
    end
end
return Art
