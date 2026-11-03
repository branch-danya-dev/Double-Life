local Lobby={}
function Lobby.build(rt)
    local root=Instance.new("Folder"); root.Name,root.Parent="DoubleLifeLobby",workspace
    local function block(name,size,pos,color)
        local p=Instance.new("Part"); p.Name,p.Size,p.Position,p.Color=name,size,pos,color
        p.Anchored,p.Material,p.Parent=true,Enum.Material.Wood,root
        return p
    end
    local wood,gold=Color3.fromRGB(51,35,31),Color3.fromRGB(181,145,76)
    block("ReceptionFloor",Vector3.new(150,1,100),Vector3.new(-270,-0.5,0),wood)
    for _,v in ipairs({{-345,0,1,100},{-195,0,1,100},{-270,-50,150,1},{-270,50,150,1}}) do
        block("LobbyWall",Vector3.new(v[3],14,v[4]),Vector3.new(v[1],7,v[2]),wood)
    end
    block("ArrivalScreen",Vector3.new(1,12,32),Vector3.new(-318,6,25),gold)
    local spots={Vector3.new(-302,3,-25),Vector3.new(-245,3,-25),Vector3.new(-230,3,20),Vector3.new(-285,3,20)}
    for i,pos in ipairs(spots) do
        local p=block("LobbyInterest"..i,Vector3.new(4,3,2),pos+Vector3.new(0,0,-5),gold)
        local light=Instance.new("PointLight"); light.Color,light.Range,light.Brightness,light.Parent=Color3.fromRGB(255,215,155),25,1.4,p
    end
    local spawn=Instance.new("SpawnLocation")
    spawn.Name,spawn.Size,spawn.Position,spawn.Anchored,spawn.Neutral,spawn.Transparency,spawn.Parent="LobbySpawn",Vector3.new(8,1,8),Vector3.new(-250,0.5,32),true,true,1,root
    local console=block("LobbyVisit",Vector3.new(3,3,2),Vector3.new(-220,2,32),gold)
    local Interactions=require(script.Parent.Interactions)
    local interactions=Interactions.new({finished=false},function(p)
        return p.Parent==game:GetService("Players") and rt.rounds.policy.phase=="Waiting"
    end)
    local prompt=Interactions.prompt(console,"Осмотреть особняк","Приёмная · свободная практика",0.5)
    interactions:bind(prompt,function(p)
        if p.Character then p.Character:PivotTo(CFrame.new(rt.world:spawn(1))) end
    end,true)
    return {root=root,spawn=spawn,spots=spots,entrance=Vector3.new(-330,3,25),interactions=interactions,
        position=function(_,index) return Vector3.new(-250+(index%5)*3,4,32-math.floor(index/5)*3) end}
end
return Lobby
