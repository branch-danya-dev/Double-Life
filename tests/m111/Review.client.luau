local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local remote=RS:WaitForChild("M111Review")
local p=Players.LocalPlayer
local gui=Instance.new("ScreenGui"); gui.Name="M111ReviewHud"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false; gui.Parent=p:WaitForChild("PlayerGui")
local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,0,0,54); title.Position=UDim2.fromOffset(0,48)
title.BackgroundColor3=Color3.fromRGB(20,29,34); title.TextColor3=Color3.fromRGB(255,235,200); title.TextSize=17; title.Parent=gui
local bar=Instance.new("Frame"); bar.Size=UDim2.new(1,0,0,45); bar.Position=UDim2.new(0,0,1,-48); bar.BackgroundColor3=title.BackgroundColor3; bar.Parent=gui
local actions={"Before","After","Front","Profile","Walk","Stop","Wave","Next","Failure"}
for i,action in ipairs(actions) do
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1/#actions,-5,1,-8); b.Position=UDim2.new((i-1)/#actions,2,0,4)
    b.Text=action; b.TextSize=15; b.TextColor3=Color3.new(1,1,1); b.BackgroundColor3=Color3.fromRGB(48,73,77); b.Parent=bar
    b.Activated:Connect(function() remote:FireServer(action) end)
end
local camera=workspace.CurrentCamera
remote.OnClientEvent:Connect(function(action,a,b)
    if action=="Camera" then camera.CameraType=Enum.CameraType.Scriptable; camera.FieldOfView=38; camera.CFrame=CFrame.lookAt(a,b)
    elseif action=="Models" then
        for _,m in ipairs(a) do
            local h=m:WaitForChild("Humanoid")
            if m:GetAttribute("MimicReady")~=nil then
                local deadline=os.clock()+20
                repeat task.wait(0.1) until m:GetAttribute("MimicClientReady") or os.clock()>deadline
                assert(m:GetAttribute("MimicClientReady"),"client appearance preload deadline")
            end
            local animator=h:FindFirstChildOfClass("Animator")
            local tracks=animator and animator:GetPlayingAnimationTracks() or {}
            if m:GetAttribute("MimicReady")~=nil then assert(#tracks>0 and h.RigType==Enum.HumanoidRigType.R15,"replicated R15 animation") end
            print("M111 CLIENT RIG",m.Name,h.RigType.Name,#tracks)
        end
    end
end)
Run.RenderStepped:Connect(function()
    for _,g in ipairs(p.PlayerGui:GetChildren()) do if g:IsA("ScreenGui") and g~=gui then g.Enabled=false end end
    local stage=workspace:FindFirstChild("M111ReviewStage")
    title.Text="M11.1 STUDIO REVIEW · "..(stage and stage:GetAttribute("ReviewStatus") or "Loading")
end)
