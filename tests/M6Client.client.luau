-- Isolated test driver: no character teleport/CFrame mutation, no fake prompt firing.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Pathfinding=game:GetService("PathfindingService")
local player=Players.LocalPlayer
local remotes=RS:WaitForChild("DoubleLifeRemotes")
local driver=RS:WaitForChild("M6TestDriver")
local controls
local function body()
    local c=player.Character or player.CharacterAdded:Wait()
    return c:WaitForChild("HumanoidRootPart"),c:WaitForChild("Humanoid")
end
local function near(a,b,r) return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude<r and math.abs(a.Y-b.Y)<4 end
local function walk(destination)
    local root,h=body()
    local began,travel,last=os.clock(),0,root.Position
    if near(root.Position,destination,3) then return {seconds=0,distance=0,position=root.Position} end
    local camera=workspace.CurrentCamera
    camera.CameraType=Enum.CameraType.Scriptable
    for _=1,3 do
        local path=Pathfinding:CreatePath({AgentRadius=2,AgentHeight=6,AgentCanJump=false,WaypointSpacing=4})
        path:ComputeAsync(root.Position,destination)
        if path.Status==Enum.PathStatus.Success then
            local failed=false
            for _,w in ipairs(path:GetWaypoints()) do
                if w.Action==Enum.PathWaypointAction.Jump then h.Jump=true end
                local untilTime=os.clock()+6
                repeat
                    h:MoveTo(w.Position)
                    local eye=root.Position+Vector3.new(0,1.5,0)
                    local look=Vector3.new(w.Position.X,eye.Y,w.Position.Z)
                    if (look-eye).Magnitude>0.1 then camera.CFrame=CFrame.lookAt(eye,look) end
                    task.wait(0.1)
                    travel+=(root.Position-last).Magnitude; last=root.Position
                until near(root.Position,w.Position,2) or os.clock()>untilTime
                if not near(root.Position,w.Position,2.5) then failed=true; break end
            end
            if not failed and near(root.Position,destination,3) then
                path:Destroy(); h:MoveTo(root.Position)
                return {seconds=os.clock()-began,distance=travel,position=root.Position}
            end
        end
        path:Destroy(); task.wait(0.5)
    end
    error("physical route blocked "..tostring(root.Position).." -> "..tostring(destination))
end
driver.OnClientInvoke=function(c)
    controls=controls or require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
    controls:Disable()
    -- Scriptable first-person camera does not run Roblox's normal avatar fade.
    -- Hide only the local body while driving, without changing world collisions.
    if player.Character then
        for _,p in ipairs(player.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.LocalTransparencyModifier=if c.kind=="Manual" then 0 else 1 end
        end
    end
    if c.kind=="LessonReady" then
        local deadline=os.clock()+15
        repeat
            local root=body()
            local s=remotes.GetState:InvokeServer().prologue
            if s.active and (root.Position-s.target).Magnitude<180 then return true end
            task.wait(0.1)
        until os.clock()>deadline
        error("private spawn did not replicate")
    elseif c.kind=="Walk" then return walk(c.position)
    elseif c.kind=="Prompt" then
        local part=workspace.DoubleLifeMansion.Round:FindFirstChild(c.part,true)
        assert(part,"missing object "..c.part)
        local root=body()
        workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
        workspace.CurrentCamera.CFrame=CFrame.lookAt(root.Position+Vector3.new(0,1.5,0),part.Position)
        local prompt
        for _,p in ipairs(part:GetChildren()) do if p:IsA("ProximityPrompt") and p.ActionText==c.action then prompt=p; break end end
        assert(prompt,"missing prompt "..c.action)
        task.wait(0.25); prompt:InputHoldBegin(); task.wait(prompt.HoldDuration+0.3); prompt:InputHoldEnd(); task.wait(0.5)
        return true
    elseif c.kind=="Prologue" then remotes.PrologueAction:FireServer(c.action); task.wait(0.7); return true
    elseif c.kind=="LessonPrompt" then
        local s=remotes.GetState:InvokeServer().prologue
        assert(s.active and s.object and s.object:IsDescendantOf(s.scene),"private lesson target")
        local root=body()
        workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
        workspace.CurrentCamera.CFrame=CFrame.lookAt(root.Position+Vector3.new(0,1.5,0),s.object.Position)
        local prompt
        for _,p in ipairs(s.object:GetChildren()) do if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText==s.action then prompt=p; break end end
        assert(prompt,"current lesson prompt")
        task.wait(0.25); prompt:InputHoldBegin(); task.wait(prompt.HoldDuration+0.3); prompt:InputHoldEnd(); task.wait(0.6)
        return true
    elseif c.kind=="LessonDance" then
        local s=remotes.GetState:InvokeServer().prologue
        walk(s.target)
        local root,h=body(); local direction=1; local deadline=os.clock()+40
        repeat
            s=remotes.GetState:InvokeServer().prologue
            if not s.active or s.step~=c.step then h:MoveTo(root.Position); return true end
            local e=s.music
            if e and e.phase=="Running" and e.beat=="Move" then
                local destination=s.target+Vector3.new(3*direction,0,0)
                if near(root.Position,destination,1) then direction=-direction end
                h:MoveTo(destination)
            else h:MoveTo(root.Position) end
            task.wait(0.1)
        until os.clock()>deadline
        error("lesson dance deadline")
    elseif c.kind=="Queue" then remotes.QueueAction:FireServer(c.action); task.wait(0.6); return true
    elseif c.kind=="Social" then remotes.SocialAction:FireServer(c.action,c.target,c.roundId); task.wait(0.7); return true
    elseif c.kind=="Event" then remotes.EventAction:FireServer(c.action,c.roundId,c.event); task.wait(0.5); return true
    elseif c.kind=="Vote" then remotes.CouncilAction:FireServer("Vote",c.roundId,c.target,false); task.wait(0.4); return true
    elseif c.kind=="DropEvidence" then remotes.CouncilAction:FireServer("DropEvidence",c.roundId); task.wait(0.5); return true
    elseif c.kind=="Snapshot" then
        local s=remotes.GetState:InvokeServer()
        assert(not s.roles and not s.profile.lease and not s.profile.receipts and not s.commerce.purchases,"private state")
        assert(not s.commerce.enabled,"production commerce remains disabled")
        for _,p in ipairs(Players:GetPlayers()) do assert(p:GetAttribute("Role")==nil and p.Team==nil,"private roles") end
        if s.round.phase=="Active" or s.round.phase=="Council" then assert(#s.publicStyles==0,"cosmetics do not reveal roles") end
        return s
    elseif c.kind=="Dance" then
        walk(c.position)
        local root,h=body(); local direction=1; local deadline=os.clock()+40
        repeat
            local s=remotes.GetState:InvokeServer(); local e=s.activities.event
            if e.phase~="Running" then h:MoveTo(root.Position); return e end
            if e.beat=="Move" and s.round.phase=="Active" then
                local destination=c.position+Vector3.new(3*direction,0,0)
                if near(root.Position,destination,1) then direction=-direction end
                h:MoveTo(destination)
            else h:MoveTo(root.Position) end
            task.wait(0.1)
        until os.clock()>deadline
        error("music driver deadline")
    elseif c.kind=="Manual" then
        controls:Enable(); workspace.CurrentCamera.CameraType=Enum.CameraType.Custom; return true
    end
    error("unknown M6 command")
end
print("M6 CLIENT READY",player.Name)
