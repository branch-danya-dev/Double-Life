-- Reuse the canonical M6 geometry/M7 dressing and World.reset, never shared state.
local World=require(script.Parent.World)
local EventWorld=require(script.Parent.EventWorld)
local Scene={}
function Scene.build(source,slot)
    local parent=workspace:FindFirstChild("DoubleLifePrologues")
    if not parent then parent=Instance.new("Folder"); parent.Name,parent.Parent="DoubleLifePrologues",workspace end
    local root=Instance.new("Folder"); root.Name,root.Parent="Visit"..slot,parent
    local offset=Vector3.new(-600-(slot-1)*220,0,0)
    local static=source.static:Clone(); static.Parent=root
    local nav=source.level.Navigation:Clone(); nav.Parent=root
    for _,tree in ipairs({static,nav}) do
        for _,p in ipairs(tree:GetDescendants()) do if p:IsA("BasePart") then p.CFrame+=offset end end
    end
    local world=setmetatable({level=root,static=static,anchors={},objects={},layout=source.layout,
        navigation=source.navigation,metrics={resets=0}},World)
    for _,a in ipairs(nav:GetDescendants()) do if a:IsA("Attachment") then world.anchors[a.Name]=a end end
    world:reset()
    local events=EventWorld.build(world)
    local extra={}
    local function prop(id,pos,size)
        local p=world.block(id,size or Vector3.new(2,2,2),pos,Color3.fromRGB(181,145,76))
        p.CanCollide=false; extra[id]=p
    end
    prop("Welcome",world:spawn(1)+Vector3.new(0,-1,-5),Vector3.new(3,2,2))
    prop("TrainingClue",world:point("Evidence.Home"),Vector3.new(1.4,0.25,1))
    prop("EvidenceBoard",offset+Vector3.new(-34,2,45),Vector3.new(5,2,3))
    return {world=world,root=root,events=events,extra=extra,offset=offset,
        point=function(self,id) return if extra[id] then extra[id].Position+Vector3.new(0,2,3) else world:approach(id) end,
        object=function(self,id) return extra[id] or world:object(id) end}
end
return Scene
