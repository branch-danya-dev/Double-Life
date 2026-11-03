assert(game:GetService('RunService'):IsStudio(),'Studio only')
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local player=Players.LocalPlayer
local UI=require(RS.DoubleLifeShared.LobbyPresentation)
local seen={}
RS:WaitForChild('DoubleLifeRemotes'):WaitForChild('PersonalUpdate').OnClientEvent:Connect(function(kind,s)
    if kind~='Snapshot' or not s.queue then return end
    task.defer(function()
        local gui=player.PlayerGui:FindFirstChild('LobbyHUD')
        if not gui then return end
        local label=gui:FindFirstChildWhichIsA('TextLabel',true)
        assert(label and label.Text==UI.status(s.queue),'actual LobbyHUD uses neutral status')
        assert(not label.Text:find('людей здесь') and not label.Text:find('персонажей') and not label.Text:find('Owner и Spy'),'no diagnostics in ordinary HUD')
        local key=tostring(#Players:GetPlayers())..':'..s.queue.state
        if not seen[key] then
            seen[key]=true
            print('M1121 HUD PASS',player.Name,key,label.Text)
        end
    end)
end)
