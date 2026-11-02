local RS = game:GetService("ReplicatedStorage")
local remotes = RS:WaitForChild("DoubleLifeRemotes")
local driver = RS:WaitForChild("M41TestDriver")
driver.OnClientInvoke = function(command)
    if command.action then
        remotes.ProfileAction:FireServer(command.action, command.item, command.slot)
        task.wait(1)
    end
    local state = remotes.GetState:InvokeServer()
    assert(not state.profile.lease and not state.profile.receipts and not state.profile.sessionSeq and not state.profiles, "private profile internals")
    assert(not RS:FindFirstChild("ProfileSessions", true), "private lifecycle code")
    return state.profile
end
print("M4.1 CLIENT READY")
