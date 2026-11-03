-- Original fictional guests: generated appearance, no real user's avatar/name.
local Mover=require(script.Parent.NpcMover)
local Rig={}
local names={"MiraVell","LeonArden","NikaFane","FelixVale","AdaMorn","OscarReed","VeraLinden","MaxElvar","LinaOrrel","IrisVoss","TheoWren","RinaCole"}
function Rig.new(parent,serial,position,scope)
    local name=names[(serial-1)%#names+1]..(if serial>#names then tostring(math.floor((serial-1)/#names)+1) else "")
    local color=Color3.fromHSV((serial*0.137)%1,0.3,0.28)
    -- Local motor rig is the deterministic fallback if the avatar service fails.
    local mover=Mover.new(parent,name,position,color,scope)
    local description=Instance.new("HumanoidDescription")
    description.HeadColor=Color3.fromRGB(184+serial%5*10,145+serial%4*12,112+serial%3*15)
    description.LeftArmColor,description.RightArmColor=description.HeadColor,description.HeadColor
    description.TorsoColor,description.LeftLegColor,description.RightLegColor=color,color,color
    description.HeightScale,description.WidthScale=0.95+serial%3*0.04,0.9+serial%3*0.05
    local ok,model,done,abandoned=false,nil,false,false
    if not Rig.pending then
        Rig.pending=true
        task.spawn(function()
            ok,model=pcall(function()
                return game:GetService("Players"):CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R15)
            end)
            description:Destroy(); Rig.pending=false; done=true
            if abandoned and ok then model:Destroy() end
        end)
        local deadline=os.clock()+3
        while not done and scope.alive and os.clock()<deadline do task.wait(0.1) end
        if not done then abandoned=true; ok=false end
    else description:Destroy() end
    if ok and scope.alive then
        mover.model:Destroy()
        model.Name=name
        model:PivotTo(CFrame.new(position))
        for _,p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") then p.CollisionGroup="DoubleLifeActors"; p.CanQuery=false end
            if p:IsA("Script") or p:IsA("LocalScript") then p:Destroy() end
        end
        model.Parent=parent
        mover.model,mover.root,mover.humanoid=model,model.HumanoidRootPart,model:FindFirstChildOfClass("Humanoid")
        mover.humanoid.WalkSpeed=10+serial%3
        mover.humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
        mover.root:SetNetworkOwner(nil)
        local torso=model:FindFirstChild("UpperTorso")
        if torso then
            local shirt=Instance.new("Part"); shirt.Name,shirt.Size,shirt.Color="EveningWaistcoat",Vector3.new(1,1.3,0.08),Color3.fromRGB(225,210,180)
            shirt.CanCollide,shirt.CanQuery,shirt.Massless=false,false,true
            shirt.CFrame,shirt.Parent=torso.CFrame*CFrame.new(0,0,-0.53),model
            local weld=Instance.new("WeldConstraint"); weld.Part0,weld.Part1,weld.Parent=torso,shirt,shirt
        end
        local sign=Instance.new("BillboardGui"); sign.Size,sign.StudsOffset,sign.MaxDistance,sign.Parent=UDim2.fromOffset(180,40),Vector3.new(0,2.5,0),35,model.Head
        local label=Instance.new("TextLabel"); label.Size,label.BackgroundTransparency,label.TextSize,label.TextColor3,label.Parent=UDim2.fromScale(1,1),1,13,Color3.fromRGB(241,224,186),sign
        mover.label=label
    elseif ok then model:Destroy() end
    mover.label.Text=name.." · персонаж"
    mover.model:SetAttribute("MimicName",name)
    mover.model:SetAttribute("MansionNPC",true)
    local head=mover.model:FindFirstChild("Head")
    if head then
        local function detail(name,size,offset,tint,ball)
            local p=Instance.new("Part")
            p.Name,p.Size,p.Color=name,size,tint
            p.CanCollide,p.CanQuery,p.Massless=false,false,true
            if ball then p.Shape=Enum.PartType.Ball end
            p.CFrame,p.Parent=head.CFrame*CFrame.new(offset),mover.model
            local weld=Instance.new("WeldConstraint"); weld.Part0,weld.Part1,weld.Parent=head,p,p
        end
        local dark=Color3.fromRGB(25+serial%4*12,20+serial%3*10,18+serial%2*8)
        detail("OriginalHair",Vector3.new(head.Size.X*1.03,0.45,head.Size.Z*1.03),Vector3.new(0,head.Size.Y/2-0.1,0),dark,true)
        for _,x in ipairs({-0.23,0.23}) do
            detail("Eye",Vector3.new(0.1,0.13,0.05),Vector3.new(x,0.05,-head.Size.Z/2-0.025),Color3.fromRGB(35,30,28),true)
        end
        detail("Smile",Vector3.new(0.22,0.04,0.04),Vector3.new(0,-0.2,-head.Size.Z/2-0.025),dark,false)
        if serial%3==0 then detail("HairBun",Vector3.new(0.6,0.6,0.6),Vector3.new(0,0.35,head.Size.Z/2),dark,true) end
    end
    local joints={}
    for _,j in ipairs(mover.model:GetDescendants()) do
        if j:IsA("Motor6D") then table.insert(joints,{joint=j,base=j.C0,name=j.Name}) end
    end
    function mover:animate(now,gesture)
        local walking=self.root.AssemblyLinearVelocity.Magnitude>1
        for _,j in ipairs(joints) do
            if j.joint.Parent then
                local limb=string.find(j.name,"Hip") or string.find(j.name,"Shoulder") or string.find(j.name,"Arm") or string.find(j.name,"Leg")
                local side=if string.find(j.name,"Left") then 1 else -1
                local angle=if walking and limb then math.sin(now*7)*0.35*side else math.sin(now*1.6)*0.025
                if gesture and (string.find(j.name,"RightShoulder") or string.find(j.name,"Right Arm")) then angle=-1.2+math.sin(now*5)*0.2 end
                j.joint.C0=j.base*CFrame.Angles(angle,0,0)
            end
        end
    end
    return mover,name
end
return Rig
