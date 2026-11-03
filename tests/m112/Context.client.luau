assert(game:GetService("RunService"):IsStudio(),"Studio-only capture fixture")
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local player=Players.LocalPlayer
local remote=game:GetService("ReplicatedStorage"):WaitForChild("M112ContextView")
local gui=Instance.new("ScreenGui"); gui.Name,gui.ResetOnSpawn,gui.Parent="M112Capture",false,player:WaitForChild("PlayerGui")
gui.DisplayOrder=100
local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-24,0,36); title.Position=UDim2.fromOffset(12,12)
title.BackgroundColor3=Color3.fromRGB(25,28,30); title.TextColor3=Color3.new(1,1,1); title.TextSize=18; title.Parent=gui
local nextButton=Instance.new("TextButton"); nextButton.Size=UDim2.fromOffset(260,42); nextButton.Position=UDim2.new(0.5,-130,1,-60)
nextButton.Text="Capture saved · Continue"; nextButton.TextSize=18; nextButton.Parent=gui
gui.Enabled=false
local proceed=false; nextButton.Activated:Connect(function() proceed=true end)
remote.OnClientInvoke=function(c)
    local model=c.model; assert(model and model:FindFirstChild("HumanoidRootPart"),"replicated capture model")
    local deadline=os.clock()+20
    repeat task.wait(0.1) until model:GetAttribute("MimicClientReady") or os.clock()>deadline
    assert(model:GetAttribute("MimicClientReady"),"client appearance preload deadline")
    proceed=false; gui.Enabled=true; title.Text="M11.2 · "..c.label
    local camera=workspace.CurrentCamera; camera.CameraType=Enum.CameraType.Scriptable; camera.FieldOfView=65
    local filter=RaycastParams.new(); filter.FilterType=Enum.RaycastFilterType.Exclude
    filter.FilterDescendantsInstances={model,player.Character}; filter.RespectCanCollide=true
    local offset
    local function chooseOffset(root)
        local target=root.Position+Vector3.new(0,1,0); local best,score
        for i=0,7 do
            local v=(root.CFrame*CFrame.Angles(0,i*math.pi/4,0)).LookVector*11+Vector3.new(0,2,0)
            local hit=workspace:Raycast(target,v,filter)
            local length=if hit then math.max(1,hit.Distance-0.6) else v.Magnitude
            local rank=length-(if i==0 then 0 else 1)
            if not score or rank>score then best,score=v.Unit*length,rank end
        end
        return best
    end
    local connection=Run.RenderStepped:Connect(function()
        if model.Parent then
            local root=model.HumanoidRootPart
            title.Text=string.format("M11.2 · %s · root Y %.1f",c.label,root.Position.Y)
            offset=offset or chooseOffset(root)
            local target=c.center or root.Position+Vector3.new(0,3,0)
            if c.wide then offset=Vector3.new(17,12,20) end
            local hit=workspace:Raycast(target,offset,filter)
            if hit and hit.Distance<offset.Magnitude-0.5 then offset=chooseOffset(root) end
            camera.CFrame=CFrame.lookAt(target+offset,target)
        end
        for _,v in ipairs(player.Character:GetDescendants()) do if v:IsA("BasePart") then v.LocalTransparencyModifier=0 end end
    end)
    local untilTime=os.clock()+(if c.ui then 18 else 600)
    repeat task.wait(0.1) until proceed or not model.Parent or os.clock()>untilTime
    connection:Disconnect(); gui.Enabled=false
    for _,v in ipairs(player.PlayerGui:GetChildren()) do if v:IsA("ScreenGui") and v~=gui then v.Enabled=true end end
    local h=model:FindFirstChildOfClass("Humanoid"); local animator=h and h:FindFirstChildOfClass("Animator")
    return {r15=h and h.RigType==Enum.HumanoidRigType.R15,tracks=animator and #animator:GetPlayingAnimationTracks() or 0,
        clothing=model:FindFirstChildOfClass("Shirt")~=nil and model:FindFirstChildOfClass("Pants")~=nil}
end
