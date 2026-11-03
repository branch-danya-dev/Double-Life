-- Server preload cannot guarantee a client's mesh/texture readiness. Keep each
-- replicated R15 hidden until its complete local content is ready, then fade in.
-- Only two outstanding engine preloads; a stalled engine call retains its slot.
local Content=game:GetService("ContentProvider")
local Run=game:GetService("RunService")
local states={}; local pending=0; local tick=0
local parts={"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand",
    "LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot","HumanoidRootPart"}
local function hide(v)
    if v:IsA("BasePart") then v.LocalTransparencyModifier=1
    elseif v:IsA("BillboardGui") then v.Enabled=false end
end
local function watch(model)
    if states[model] or not model:IsA("Model") or model:GetAttribute("MimicReady")==nil then return end
    local s={at=os.clock(),attempts=0,nextAt=0}; states[model]=s
    for _,v in ipairs(model:GetDescendants()) do hide(v) end
    s.add=model.DescendantAdded:Connect(function(v) if not s.visible then hide(v) end end)
    s.remove=model.Destroying:Connect(function()
        s.add:Disconnect(); s.remove:Disconnect(); states[model]=nil
    end)
end
local function complete(model)
    if not model:GetAttribute("MimicReady") then return false end
    for _,name in ipairs(parts) do if not model:FindFirstChild(name) then return false end end
    if not model:FindFirstChildOfClass("Shirt") or not model:FindFirstChildOfClass("Pants") then return false end
    for _,v in ipairs(model:GetChildren()) do if v:IsA("Accessory") and v:FindFirstChild("Handle") then return true end end
    return false
end
workspace.DescendantAdded:Connect(function(v)
    if v:IsA("Model") then watch(v)
    elseif v.Parent and v.Parent:IsA("Model") then watch(v.Parent) end
end)
for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("Model") then watch(v) end end
Run.Heartbeat:Connect(function(dt)
    tick+=dt; if tick<0.1 then return end; tick=0
    for model,s in pairs(states) do
        if not model:IsDescendantOf(workspace) then continue end
        if s.ready and not s.visible then
            local alpha=math.clamp((os.clock()-s.ready)/0.35,0,1)
            for _,v in ipairs(model:GetDescendants()) do
                if v:IsA("BasePart") then v.LocalTransparencyModifier=1-alpha
                elseif v:IsA("BillboardGui") then v.Enabled=alpha==1 end
            end
            if alpha==1 then s.visible=true; model:SetAttribute("MimicClientReady",true) end
        elseif not s.ready and not s.loading and pending<2 and s.attempts<3 and os.clock()>=s.nextAt and complete(model) then
            s.loading=true; s.attempts+=1; pending+=1
            task.spawn(function()
                local success=true
                local ok=pcall(function()
                    Content:PreloadAsync({model},function(_,status) if status~=Enum.AssetFetchStatus.Success then success=false end end)
                end)
                pending-=1; s.loading=false
                if states[model]~=s then return end
                if ok and success and complete(model) then s.ready=os.clock()
                else s.nextAt=os.clock()+5*s.attempts end
            end)
        end
    end
end)
