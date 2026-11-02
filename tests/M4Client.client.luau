-- Test-build-only driver. Production has no remote for character control or snapshots of another client.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = RS:WaitForChild("DoubleLifeRemotes")
local notices = 0
local lastNotice = ""
remotes.PersonalUpdate.OnClientEvent:Connect(function(kind, value) if kind == "Notice" then notices += 1; lastNotice = value end end)
local driver = RS:WaitForChild("M4TestDriver")
driver.OnClientInvoke = function(command)
    if command.kind == "LastNotice" then return lastNotice
    elseif command.kind == "Profile" then
        remotes.ProfileAction:FireServer(command.action, command.item, command.slot)
        task.wait(0.9)
        return remotes.GetState:InvokeServer().profile
    elseif command.kind == "Snapshot" then
        local state = remotes.GetState:InvokeServer()
        assert(not state.roles and (state.round.phase == "Results" or not state.round.result), "no early role reveal")
        for _, other in ipairs(Players:GetPlayers()) do
            assert(other:GetAttribute("Role") == nil and other.Team == nil, "private player roles")
            if other.Character then
                assert(other.Character:GetAttribute("Role") == nil and not other.Character:FindFirstChild("DoubleLifeDossier"), "no carrier marker")
            end
        end
        assert(not RS:FindFirstChild("Roles", true) and not RS:FindFirstChild("RoundService", true), "server-only code")
        assert(not RS:FindFirstChild("EventDirector", true), "server-only event director")
        assert(not RS:FindFirstChild("ProfileService", true) and not RS:FindFirstChild("ProfileStore", true), "private profile authority")
        assert(not state.profiles and not state.profile.lease and not state.profile.receipts and not state.profile.sessionSeq, "private account internals")
        local a = state.activities
        assert(not a.guestActions and not a.pendingIncident and not a.event.participants and not a.event.carrier, "private event internals")
        assert(not a.incident or (not a.incident.source and not a.incident.userId), "incident never identifies guest")
        assert(not a.owner or state.role == "Owner", "private owner controls")
        return state
    elseif command.kind == "Event" then
        remotes.EventAction:FireServer(command.action, command.roundId, command.event)
        task.wait(0.4)
        return true
    elseif command.kind == "Notices" then return notices
    elseif command.kind == "Vote" then
        remotes.CouncilAction:FireServer("Vote", command.roundId, command.target, command.attach == true)
        task.wait(0.4)
        return true
    elseif command.kind == "Drop" then
        remotes.CouncilAction:FireServer("DropEvidence", command.roundId)
        task.wait(0.4)
        return true
    end
    local character = player.Character or player.CharacterAdded:Wait()
    local root, humanoid = character:WaitForChild("HumanoidRootPart"), character:WaitForChild("Humanoid")
    local controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
    controls:Disable()
    if command.kind == "Dance" then
        character:PivotTo(CFrame.new(8, 4, 0))
        local deadline, destination = os.clock() + 45, 5
        repeat
            local state = remotes.GetState:InvokeServer()
            local e = state.activities.event
            if e.phase ~= "Running" then humanoid:MoveTo(root.Position); return e end
            if e.beat == "Move" and state.round.phase == "Active" then
                if math.abs(root.Position.X - destination) < 1 then destination = if destination == 5 then 11 else 5 end
                humanoid:MoveTo(Vector3.new(destination, 4, 0))
            else humanoid:MoveTo(root.Position) end
            task.wait(0.1)
        until os.clock() > deadline
        error("music driver timeout")
    elseif command.kind == "Walk" then
        for _, point in ipairs(command.points) do
            workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
            workspace.CurrentCamera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 1.5, 0), Vector3.new(point.X, root.Position.Y + 1.5, point.Z))
            humanoid:MoveTo(point)
            local deadline = os.clock() + 15
            while Vector2.new(root.Position.X - point.X, root.Position.Z - point.Z).Magnitude > 2.5 and os.clock() < deadline do task.wait(0.1) end
            assert(Vector2.new(root.Position.X - point.X, root.Position.Z - point.Z).Magnitude <= 2.5, "walking route blocked at " .. tostring(point))
        end
        return root.Position
    elseif command.kind == "Prompt" then
        local part = workspace.DoubleLifePrototype:FindFirstChild(command.part)
        assert(part, command.part)
        if command.position then character:PivotTo(CFrame.new(command.position)) end
        workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
        workspace.CurrentCamera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 1.5, 0), part.Position)
        task.wait(0.7)
        local prompt
        for _, child in ipairs(part:GetChildren()) do
            if child:IsA("ProximityPrompt") and child.ActionText == command.action then prompt = child; break end
        end
        assert(prompt, command.action)
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration + 0.25)
        prompt:InputHoldEnd()
        task.wait(0.5)
        return true
    elseif command.kind == "Manual" then
        controls:Enable()
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        return true
    end
    error("unknown driver command")
end
print("M4 CLIENT DRIVER READY", player.Name)
