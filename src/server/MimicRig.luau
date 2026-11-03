-- Validated R15 only. A cold failure defers admission; a warm failure reuses
-- the identical completed template. No hand-built body or facial geometry.
local Players=game:GetService("Players")
local Content=game:GetService("ContentProvider")
local Mover=require(script.Parent.NpcMover)
local Catalog=require(script.Parent.MimicAppearance)
local LoadPolicy=require(script.Parent.MimicLoadPolicy)
local Motion=require(script.Parent.MimicAnimation)
local Rig={templates={},descriptions={},policy=LoadPolicy.new(os.clock),
    metrics={requests=0,failures=0,timeouts=0,cacheHits=0,deferred=0,live=0,tracks=0,pending=0,maxPending=0,maxSeconds=0}}
local bodyParts={"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand",
    "LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"}
function Rig.description(id)
    assert(Catalog.presets[id],"Unknown avatar preset")
    if not Rig.descriptions[id] then
        local p=Catalog.presets[id]; local d=Instance.new("HumanoidDescription")
        for _,key in ipairs({"Shirt","Pants","HairAccessory","HatAccessory","Head","HeightScale","WidthScale","DepthScale","HeadScale","BodyTypeScale","ProportionScale"}) do d[key]=p[key] end
        for key,value in pairs(Catalog.body[p.body]) do d[key]=value end
        local skin=Color3.fromRGB(table.unpack(p.skin))
        for _,key in ipairs({"HeadColor","TorsoColor","LeftArmColor","RightArmColor","LeftLegColor","RightLegColor"}) do d[key]=skin end
        Rig.descriptions[id]=d
    end
    return Rig.descriptions[id]:Clone()
end
function Rig.validate(model,id)
    if not model or not model:IsA("Model") then return false,"Model" end
    local h=model:FindFirstChildOfClass("Humanoid"); local root=model:FindFirstChild("HumanoidRootPart")
    if not h or h.RigType~=Enum.HumanoidRigType.R15 or not root then return false,"R15" end
    for _,name in ipairs(bodyParts) do if not model:FindFirstChild(name) then return false,name end end
    local motors,accessories=0,0
    for _,v in ipairs(model:GetDescendants()) do
        if v:IsA("Motor6D") and v.Part0 and v.Part1 then motors+=1
        elseif v:IsA("AnimationConstraint") and v.Attachment0 and v.Attachment1
            and v.Attachment0:IsDescendantOf(model) and v.Attachment1:IsDescendantOf(model) then motors+=1 end
        if v:IsA("Accessory") and v:FindFirstChild("Handle") then accessories+=1 end
    end
    if motors<15 or accessories<1 then return false,"JointsAccessories:"..motors..":"..accessories end
    if not model:FindFirstChildOfClass("Shirt") or not model:FindFirstChildOfClass("Pants") then return false,"Clothing" end
    local applied=h:GetAppliedDescription(); local p=Catalog.presets[id]
    -- Layered hair is normalized into AccessoryDescription by Roblox and may
    -- disappear from the legacy HairAccessory string. Verify its actual ID.
    local hair=false
    for _,a in ipairs(applied:GetAccessories(true)) do
        if a.AssetId==tonumber(p.HairAccessory) and a.AccessoryType==Enum.AccessoryType.Hair then hair=true end
    end
    local valid=applied.Shirt==p.Shirt and applied.Pants==p.Pants and hair
    applied:Destroy()
    return valid,if valid then "R15Ready" else "AppliedDescription"
end
local function template(id,scope,refresh)
    if Rig.templates[id] and not refresh then Rig.metrics.cacheHits+=1; return Rig.templates[id]:Clone(),"Cache" end
    local token=Rig.policy:begin(id)
    if token then
        Rig.metrics.requests+=1; Rig.metrics.pending+=1
        Rig.metrics.maxPending=math.max(Rig.metrics.maxPending,Rig.metrics.pending)
        task.spawn(function()
            local model,description
            local ok,why=pcall(function()
                description=Rig.description(id)
                if Rig.testDelay then task.wait(Rig.testDelay) end
                if Rig.testFailure then error("InjectedAvatarFailure") end
                model=Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R15)
                local valid,reason=Rig.validate(model,id)
                assert(valid,"InvalidR15Template:"..reason)
                for _,v in ipairs(model:GetDescendants()) do if v:IsA("LuaSourceContainer") then v:Destroy() end end
                local failed=false
                Content:PreloadAsync({model},function(_,status) if status~=Enum.AssetFetchStatus.Success then failed=true end end)
                assert(not failed,"AvatarContentUnavailable")
            end)
            if description then description:Destroy() end
            if ok then
                if Rig.templates[id] then Rig.templates[id]:Destroy() end
                model.Archivable=true; Rig.templates[id]=model
            else
                if model then model:Destroy() end
                Rig.metrics.failures+=1
                warn("Mimic avatar deferred",id,tostring(why):match("[^\n]+"))
            end
            Rig.metrics.pending-=1; Rig.policy:finish(token,ok)
        end)
        while Rig.policy.pending==token and scope.alive and not Rig.policy:expired(token) do task.wait(0.1) end
        if Rig.policy.pending==token and Rig.policy:expired(token) then Rig.metrics.timeouts+=1 end
    end
    if Rig.templates[id] then Rig.metrics.cacheHits+=1; return Rig.templates[id]:Clone(),"Cache" end
    Rig.metrics.deferred+=1; return nil,"Deferred"
end
function Rig.configureForTest(failure,delaySeconds)
    assert(game:GetService("RunService"):IsStudio(),"Avatar injection is Studio-only")
    Rig.testFailure=failure==true
    Rig.testDelay=delaySeconds and math.clamp(delaySeconds,0,12) or nil
end
function Rig.new(parent,serial,position,scope,id,refresh,nickname,admit)
    id=id or Catalog.pick(Catalog.seed,serial,{})
    local began=os.clock(); local model,source=template(id,scope,refresh)
    if not model then return nil,source end
    if not scope.alive or not parent.Parent or (admit and not admit()) then model:Destroy(); return nil,"Cancelled" end
    local p=Catalog.presets[id]
    local name=nickname or p.name..(if serial>#Catalog.presets then tostring(math.floor((serial-1)/#Catalog.presets)+1) else "")
    local h=model:FindFirstChildOfClass("Humanoid"); local root=model.HumanoidRootPart
    local visibility={}
    model.Name=name; model.PrimaryPart=root
    model:SetAttribute("MimicName",name); model:SetAttribute("MimicReady",false)
    for _,v in ipairs(model:GetDescendants()) do
        if v:IsA("BasePart") then
            visibility[v]=v.Transparency; v.Transparency=1; v.CollisionGroup="DoubleLifeActors"; v.CanQuery=false
            if v.Parent:IsA("Accessory") then v.CanCollide=false; v.Massless=true end
        elseif v:IsA("Decal") then visibility[v]=v.Transparency; v.Transparency=1 end
    end
    root.Anchored=true; model:PivotTo(CFrame.new(position)); model.Parent=parent
    local motion=Motion.new(model,serial)
    local deadline=os.clock()+5
    while motion and not motion:ready() and scope.alive and model.Parent and os.clock()<deadline do task.wait(0.1) end
    if motion and not motion:ready() and scope.alive and model.Parent then
        motion:fallback(); deadline=os.clock()+2
        while not motion:ready() and scope.alive and model.Parent and os.clock()<deadline do task.wait(0.1) end
    end
    if not motion or not motion:ready() or not scope.alive or not model.Parent or (admit and not admit()) then
        if motion then motion:destroy() end; model:Destroy(); Rig.metrics.deferred+=1; return nil,"AnimationDeferred"
    end
    h.WalkSpeed=10+serial%3; h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
    motion:update(0,false,false)
    for v,alpha in pairs(visibility) do if v.Parent then v.Transparency=alpha end end
    root.Anchored=false; root:SetNetworkOwner(nil)
    local sign=Instance.new("BillboardGui"); sign.Name="MimicNameplate"
    sign.Size,sign.StudsOffset,sign.MaxDistance,sign.Parent=UDim2.fromOffset(180,40),Vector3.new(0,2.5,0),35,model.Head
    local label=Instance.new("TextLabel"); label.Size,label.BackgroundTransparency,label.TextSize,label.TextColor3,label.Parent=UDim2.fromScale(1,1),1,13,Color3.fromRGB(241,224,186),sign
    label.Text=name
    model:SetAttribute("MimicName",name); model:SetAttribute("MansionNPC",true)
    model:SetAttribute("AppearanceId",id); model:SetAttribute("AppearanceStyle",p.style)
    local mover=setmetatable({model=model,root=root,humanoid=h,label=label,scope=scope,motion=motion,preset=id,source=source,
        metrics={computes=0,failures=0,timeouts=0,arrivals=0,computeSeconds=0}},Mover)
    local attachment=Instance.new("Attachment"); attachment.Parent=root
    local facing=Instance.new("AlignOrientation"); facing.Mode=Enum.OrientationAlignmentMode.OneAttachment
    facing.Attachment0,facing.MaxTorque,facing.MaxAngularVelocity,facing.Responsiveness=attachment,3000,1.5,5
    facing.Enabled=false; facing.Parent=root
    function mover:lookAt(point)
        local flat=Vector3.new(point.X,self.root.Position.Y,point.Z)
        if (flat-self.root.Position).Magnitude>1 then
            facing.CFrame=CFrame.lookAt(self.root.Position,flat).Rotation; facing.Enabled=true; self.humanoid.AutoRotate=false
        end
    end
    function mover:animate(_,gesture,paused)
        local velocity=self.root.AssemblyLinearVelocity
        local speed=Vector2.new(velocity.X,velocity.Z).Magnitude
        if speed>0.8 or self.destination then facing.Enabled=false; self.humanoid.AutoRotate=true end
        self.motion:update(speed,gesture,paused)
    end
    local cleaned=false
    local function cleanup()
        if cleaned then return end; cleaned=true
        motion:destroy(); Rig.metrics.live-=1; Rig.metrics.tracks-=6
    end
    model.Destroying:Connect(cleanup)
    function mover:destroy() cleanup(); self.model:Destroy() end
    Rig.metrics.live+=1; Rig.metrics.tracks+=6
    Rig.metrics.maxSeconds=math.max(Rig.metrics.maxSeconds,os.clock()-began)
    model:SetAttribute("MimicReady",true)
    return mover,name
end
return Rig
