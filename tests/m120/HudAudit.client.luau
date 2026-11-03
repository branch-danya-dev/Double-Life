assert(game:GetService("RunService"):IsStudio(),"Studio only")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local player=game:GetService("Players").LocalPlayer
local Time=require(RS:WaitForChild("DoubleLifeShared").RoundTime)
local records={}
local remotes=RS:WaitForChild("DoubleLifeRemotes")
remotes:WaitForChild("PersonalUpdate").OnClientEvent:Connect(function(kind,s)
    if kind~="Snapshot" then return end
    local r=s.round; local gui=player.PlayerGui:FindFirstChild("DoubleLifeHUD")
    if not gui then return end
    local phase=gui:FindFirstChild("Phase",true); if not phase then return end
    records[r.roundId]=records[r.roundId] or {}
    local record=records[r.roundId]
    if r.phase=="Active" and not record.start then
        Run.RenderStepped:Wait()
        record.start=phase.Text
        print("M120 CLIENT START HUD",r.roundId,r.remaining,phase.Text)
    elseif r.phase=="Council" then
        Run.RenderStepped:Wait()
        assert(phase.Text=="Собрание · игра на паузе · "..Time.format(r.activeRemaining),"paused real HUD")
        local timer=gui:FindFirstChild("CouncilTime",true)
        assert(timer and timer.Text==Time.council(r) and gui.CouncilPanel.Visible,"visible modal contains both timers")
        record.council=true
    end
end)
RS:WaitForChild("M120View").OnClientInvoke=function(c)
    if c.kind=="Audit" then return records[c.round] or {} end
    assert(c.kind=="Gate","known command")
    local gui=Instance.new("ScreenGui"); gui.Name,gui.ResetOnSpawn,gui.Parent="M120Gate",false,player:WaitForChild("PlayerGui")
    gui.DisplayOrder=100
    local button=Instance.new("TextButton"); button.Size=UDim2.fromOffset(400,48); button.Position=UDim2.new(0.5,-200,1,-70)
    button.Text="M12.0 · Начать проверку"; button.TextSize=20; button.Parent=gui
    local proceed=false; button.Activated:Connect(function() proceed=true end)
    print("M120 CLIENT GATE",player.Name,gui.Parent,gui.Enabled)
    repeat task.wait(0.1) until proceed
    gui:Destroy(); return true
end
print("M120 CLIENT READY",player.Name)
