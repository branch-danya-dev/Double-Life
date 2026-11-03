local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local UI=require(script.Parent.Interface)
local Presentation=require(RS:WaitForChild("DoubleLifeShared"):WaitForChild("LobbyPresentation"))
local remotes=RS:WaitForChild("DoubleLifeRemotes")
local gui=Instance.new("ScreenGui"); gui.Name,gui.ResetOnSpawn,gui.DisplayOrder,gui.Parent="LobbyHUD",false,7,Players.LocalPlayer:WaitForChild("PlayerGui")
local frame=Instance.new("Frame"); frame.AnchorPoint,frame.Position,frame.Size=Vector2.new(1,0),UDim2.new(1,-12,0,110),UDim2.new(1,-24,0,132)
frame.BackgroundColor3,frame.Parent=Color3.fromRGB(29,32,36),gui; UI.decorate(frame,false)
local limit=Instance.new("UISizeConstraint"); limit.MaxSize,limit.Parent=Vector2.new(340,132),frame
local label=Instance.new("TextLabel"); label.Size,label.Position,label.BackgroundTransparency=UDim2.new(1,-16,0,70),UDim2.fromOffset(8,6),1
label.TextWrapped,label.TextSize,label.TextColor3,label.Parent=true,14,Color3.fromRGB(240,226,197),frame
local last
local function toggle() if last then remotes.QueueAction:FireServer(if last.queued then "Cancel" else "Register") end end
local function button(text,x,callback)
    local b=Instance.new("TextButton"); b.Size,b.Position=UDim2.new(0.5,-12,0,42),UDim2.new(x,8,0,82)
    b.Text,b.TextSize,b.TextWrapped,b.BackgroundColor3,b.TextColor3,b.Parent=text,13,true,Color3.fromRGB(57,78,76),Color3.new(1,1,1),frame
    UI.decorate(b,true); b.Activated:Connect(callback); return b
end
local join=button("Очередь · Q",0,toggle)
button("В приёмную",0.5,function() remotes.QueueAction:FireServer("Lobby") end)
remotes.PersonalUpdate.OnClientEvent:Connect(function(kind,s)
    if kind~="Snapshot" or not s.queue then return end
    last=s.queue; frame.Visible=not s.round.participating and not (s.prologue and s.prologue.active)
    label.Text=Presentation.status(last)
    join.Text=if last.queued then "Выйти из очереди · Q" else "Встать в очередь · Q"
end)
Input.InputBegan:Connect(function(key,processed) if not processed and key.KeyCode==Enum.KeyCode.Q and frame.Visible then toggle() end end)
