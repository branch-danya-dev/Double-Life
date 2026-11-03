assert(game:GetService("RunService"):IsStudio(), "Studio only")
local RS = game:GetService("ReplicatedStorage")
local player = game:GetService("Players").LocalPlayer
local stats = require(RS:WaitForChild("M8Metrics")).new(600)
game:GetService("RunService").RenderStepped:Connect(function(dt) stats:add(dt) end)
local audit = RS:WaitForChild("M8AuditDriver")
local function checkChat()
    local chat = game:GetService("TextChatService")
    assert(chat.ChatVersion == Enum.ChatVersion.TextChatService, "modern chat selected")
    assert(not chat.CreateDefaultTextChannels and not chat.CreateDefaultCommands, "no text channels/commands")
    for _, name in ipairs({"ChatWindowConfiguration", "ChatInputBarConfiguration", "BubbleChatConfiguration", "ChannelTabsConfiguration"}) do
        assert(not chat:WaitForChild(name).Enabled, "chat surface " .. name)
    end
    assert(not player.PlayerScripts:FindFirstChild("ChatScript"), "legacy ChatScript must not load")
    assert(not player.PlayerGui:FindFirstChild("Chat"), "legacy chat overlay")
    assert(not game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.Chat), "chat toggle hidden")
end
audit.OnClientInvoke = function(command)
    player:WaitForChild("PlayerGui"):WaitForChild("DoubleLifeHUD")
    checkChat()
    if command == "Reset" then stats = require(RS.M8Metrics).new(600); return true end
    local s = RS.DoubleLifeRemotes.GetState:InvokeServer()
    local hud = player.PlayerGui.DoubleLifeHUD
    assert(not s.commerce.enabled and s.profile.mode == "FakeMemory", "isolated profile and shop off")
    if s.round.phase == "Active" and s.activities.event.phase == "Idle" then
        assert(string.find(hud.ActivityBanner.Activity.Text, "Действия", 1, true), "visible no-chat guidance")
    end
    local report = stats:summary()
    report.viewport = tostring(workspace.CurrentCamera.ViewportSize)
    report.chat = "PASS"
    return report
end
task.wait(5)
checkChat()
print("M8 CLIENT CHAT PASS", player.Name)
