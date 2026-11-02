local Layout = require(script.Parent.MansionLayout)
local Contract = require(script.Parent.WorldContract)
local World = {}
World.__index = World
local colors = {Stone=Color3.fromRGB(88,91,99),Floor=Color3.fromRGB(126,104,79),Wood=Color3.fromRGB(88,62,46),
    Gold=Color3.fromRGB(192,153,74),Glass=Color3.fromRGB(95,142,160),Green=Color3.fromRGB(78,145,110),
    Teal=Color3.fromRGB(61,130,143),Blue=Color3.fromRGB(98,110,157),Grass=Color3.fromRGB(58,81,62),Painting=Color3.fromRGB(163,121,96)}
local function v(p) return Vector3.new(p[1],p[2],p[3]) end
local function folder(name,parent)
    local f=Instance.new("Folder"); f.Name,f.Parent=name,parent; return f
end
local function block(parent,name,size,position,color,material)
    local p=Instance.new("Part")
    p.Name,p.Size,p.Position,p.Color=name,size,position,color
    p.Anchored,p.Material,p.Parent=true,material or Enum.Material.SmoothPlastic,parent
    return p
end
function World:point(id) return assert(self.anchors[id],"Missing world anchor "..id).WorldPosition end
function World:approach(id) return self:point(id..".Approach") end
function World:object(id) return assert(self.objects[id],"Missing world object "..id) end
function World:points(group)
    local result={}
    for _,id in ipairs(assert(Layout.groups[group],"Missing group "..group)) do table.insert(result,self:point(id)) end
    return result
end
function World:spawn(index) return self:point(Layout.groups.PlayerSpawns[(index-1)%15+1]) end
function World:dropPoint(position,fallback,height)
    -- Resolve the actual floor on either level, rather than the old graybox bounds.
    local params=RaycastParams.new()
    params.FilterType,params.FilterDescendantsInstances=Enum.RaycastFilterType.Include,{self.static}
    local hit=workspace:Raycast(position,Vector3.new(0,-12,0),params)
    if hit and hit.Normal.Y>0.7 then return hit.Position+Vector3.new(0,height,0) end
    return fallback
end
function World:reset()
    local started=os.clock()
    if self.map then self.map:Destroy() end
    self.map=folder("Round",self.level)
    self.interactives=folder("Interactives",self.map)
    self.temporary=folder("Temporary",self.map)
    self.npcs=folder("NPCs",self.map)
    self.objects={}
    self.block=function(name,size,position,color,material) return block(self.temporary,name,size,position,color,material) end
    for _,n in ipairs(Layout.nodes) do
        if n.kind=="Object" then
            local p=block(self.interactives,n.name,v(n.size),self:point(n.id),colors[n.color])
            p:SetAttribute("WorldId",n.id)
            if n.id=="StudyWindow" then p.Material,p.Transparency=Enum.Material.Glass,0.3 end
            if n.id~="StudyDoor" and n.id~="StudyWindow" then p.CanCollide=false end
            if n.id=="MainExit" then p.Transparency=0.5 end
            self.objects[n.id]=p
        end
    end
    self.gold=colors.Gold
    self.studyDoor,self.studyWindow=self:object("StudyDoor"),self:object("StudyWindow")
    self.safe,self.console,self.logbook,self.exitDoor=self:object("Safe"),self:object("OwnerConsole"),self:object("ForensicLog"),self:object("MainExit")
    self.metrics.resets+=1; self.metrics.lastResetMs=(os.clock()-started)*1000
    return self
end
function World.build()
    local started=os.clock()
    local ok,why,nodes=Contract.validate(Layout)
    assert(ok,why)
    local self=setmetatable({anchors={},navigation=Layout.navigation,layout=Layout,metrics={resets=0}},World)
    self.level=folder("DoubleLifeMansion",workspace)
    self.static=folder("StaticGeometry",self.level)
    local navigation=folder("Navigation",self.level)
    local origin=block(navigation,"AnchorOrigin",Vector3.one,Vector3.zero,colors.Stone)
    origin.CanCollide,origin.CanQuery,origin.Transparency=false,false,1
    for id,n in pairs(nodes) do
        local a=Instance.new("Attachment"); a.Name,a.Position,a.Parent=id,v(n.position),origin; self.anchors[id]=a
        a:SetAttribute("Room",n.room)
        if n.approach then
            local approach=Instance.new("Attachment"); approach.Name,approach.Position,approach.Parent=id..".Approach",v(n.approach),origin
            self.anchors[approach.Name]=approach
        end
    end
    for _,g in ipairs(Layout.geometry) do
        local p=block(self.static,g.id,v(g.size),v(g.position),colors[g.color],
            if g.color=="Floor" then Enum.Material.WoodPlanks elseif g.color=="Glass" then Enum.Material.Glass else Enum.Material.SmoothPlastic)
        p.Transparency=g.transparency or 0
        if g.rotation then p.CFrame=CFrame.new(v(g.position))*CFrame.Angles(g.rotation[1],g.rotation[2],g.rotation[3]) end
        if g.collide==false then p.CanCollide,p.CanQuery=false,false end
    end
    local signs=folder("Wayfinding",self.static)
    for _,r in ipairs(Layout.rooms) do
        if r.id~="Courtyard" then
            local p=block(signs,r.id.."Sign",Vector3.new(12,1.5,0.2),Vector3.new((r.min[1]+r.max[1])/2,r.min[2]+8,r.min[3]+2),colors.Teal)
            p.CanCollide,p.CanQuery=false,false
            local gui=Instance.new("BillboardGui"); gui.Size,gui.MaxDistance,gui.Parent=UDim2.fromOffset(260,40),65,p
            local label=Instance.new("TextLabel"); label.Size,label.Text,label.TextSize=UDim2.fromScale(1,1),r.label,15
            label.TextColor3,label.BackgroundColor3,label.TextWrapped,label.Parent=Color3.new(1,1,1),colors.Teal,true,gui
        end
    end
    self.spawns=folder("Spawns",self.level)
    for i,id in ipairs(Layout.groups.PlayerSpawns) do
        local p=Instance.new("SpawnLocation"); p.Name,p.Size,p.Position="PlayerSpawn"..i,Vector3.new(4,0.2,4),self:point(id)-Vector3.new(0,2.85,0)
        p.Anchored,p.CanCollide,p.Neutral,p.Duration,p.Transparency,p.Parent=true,false,true,0,1,self.spawns
    end
    local lighting=game:GetService("Lighting")
    lighting.ClockTime,lighting.Brightness,lighting.Ambient=14,2,Color3.fromRGB(125,128,140)
    self:reset(); self.metrics.buildMs=(os.clock()-started)*1000
    return self
end
return World
