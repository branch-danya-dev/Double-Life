-- Test-build-only driver. Production has no remote for character control or snapshots of another client.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = RS:WaitForChild("DoubleLifeRemotes")
local notices = 0
remotes.PersonalUpdate.OnClientEvent:Connect(function(kind) if kind == "Notice" then notices += 1 end end)
local driver = RS:WaitForChild("M2TestDriver")
driver.OnClientInvoke = function(command)
    if command.kind == "Snapshot" then
        local state = remotes.GetState:InvokeServer()
        assert(not state.roles and (state.round.phase == "Results" or not state.round.result), "no early role reveal")
        for _, other in ipairs(Players:GetPlayers()) do
            assert(other:GetAttribute("Role") == nil and other.Team == nil, "private player roles")
            if other.Character then
                assert(other.Character:GetAttribute("Role") == nil and not other.Character:FindFirstChild("DoubleLifeDossier"), "no carrier marker")
            end
        end
        assert(not RS:FindFirstChild("Roles", true) and not RS:FindFirstChild("RoundService", true), "server-only code")
        return state
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
    if command.kind == "Walk" then
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
print("M2 CLIENT DRIVER READY", player.Name)
