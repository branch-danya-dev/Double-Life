local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local noticeCount, resultCount = 0, 0
RS:WaitForChild("DoubleLifeRemotes"):WaitForChild("PersonalUpdate").OnClientEvent:Connect(function(kind)
    if kind == "Notice" then noticeCount += 1 elseif kind == "Result" then resultCount += 1 end
end)
-- Test place only: uses real prompt input/network handlers; never included in default.project.json.
RS:WaitForChild("M1TestDriver").OnClientInvoke = function(position, partName, action)
    if position == "NoticeCount" then return {notices = noticeCount, results = resultCount} end
    local character = player.Character or player.CharacterAdded:Wait()
    local part = workspace.DoubleLifePrototype:FindFirstChild(partName)
    assert(part, partName)
    character:PivotTo(CFrame.lookAt(position, Vector3.new(part.Position.X, position.Y, part.Position.Z)))
    workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
    workspace.CurrentCamera.CFrame = CFrame.lookAt(position + Vector3.new(0, 1.5, 0), part.Position)
    task.wait(0.7)
    local prompt
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("ProximityPrompt") and child.ActionText == action then prompt = child; break end
    end
    assert(prompt, action)
    prompt:InputHoldBegin()
    task.wait(prompt.HoldDuration + 0.25)
    prompt:InputHoldEnd()
    task.wait(0.5)
    return true
end
local state = RS:WaitForChild("DoubleLifeRemotes"):WaitForChild("GetState"):InvokeServer()
assert(state.role and not state.roles, "only own role is returned")
assert(not RS:FindFirstChild("Roles", true) and not RS:FindFirstChild("Game", true), "server modules are private")
task.wait(3)
for _, other in ipairs(Players:GetPlayers()) do
    assert(other:GetAttribute("Role") == nil and other.Team == nil, "role not on replicated player")
    if other.Character then assert(other.Character:GetAttribute("Role") == nil, "role not on character") end
end
assert(player:WaitForChild("PlayerGui"):WaitForChild("DoubleLifeHUD"), "HUD loaded")
print("M1 CLIENT AUDIT PASS", player.Name, "own-role-only")
