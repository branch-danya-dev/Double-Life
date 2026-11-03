local Players=game:GetService("Players")
local Input=game:GetService("UserInputService")
local UI=require(script.Parent.Interface)
local player=Players.LocalPlayer
local remotes=game:GetService("ReplicatedStorage"):WaitForChild("DoubleLifeRemotes")
local gui=Instance.new("ScreenGui"); gui.Name,gui.ResetOnSpawn,gui.DisplayOrder,gui.Parent="PrologueHUD",false,8,player:WaitForChild("PlayerGui")
local function frame(name,height,y)
    local f=Instance.new("Frame"); f.Name,f.AnchorPoint,f.Size,f.Position,f.Parent=name,Vector2.new(0.5,0),UDim2.new(1,-24,0,height),UDim2.new(0.5,0,0,y),gui
    local limit=Instance.new("UISizeConstraint"); limit.MaxSize,limit.Parent=Vector2.new(500,height),f
    UI.decorate(f,false); return f
end
local function label(parent,y,height,size)
    local l=Instance.new("TextLabel"); l.Size,l.Position,l.BackgroundTransparency=UDim2.new(1,-16,0,height),UDim2.fromOffset(8,y),1
    l.TextWrapped,l.TextSize,l.TextColor3,l.Font,l.Parent=true,size,UI.color("Paper"),Enum.Font.GothamMedium,parent
    return l
end
local hint=frame("Lesson",138,60)
local title=label(hint,6,26,15)
local text=label(hint,34,70,14)
local distance=label(hint,108,24,12)
local ready=frame("Invitation",142,206)
local invite=label(ready,5,55,14)
invite.Text="Найден второй человек. Войти в настоящий матч? Учебные предметы останутся здесь."
local actions=frame("LessonActions",90,0)
actions.AnchorPoint,actions.Position=Vector2.new(0.5,1),UDim2.new(0.5,0,1,-12)
local last,wasActive=nil,false
local function send(action) remotes.PrologueAction:FireServer(action) end
local function button(parent,value,index,total,y,callback)
    local b=Instance.new("TextButton"); b.Size,b.Position=UDim2.new(1/total,-10,0,38),UDim2.new((index-1)/total,5,0,y)
    b.Text,b.TextSize,b.TextWrapped,b.Parent=value,12,true,parent
    UI.decorate(b,true); b.Activated:Connect(callback); return b
end
button(ready,"Войти · Y",1,3,60,function() send("Accept") end)
button(ready,"После шага · J",2,3,60,function() send("Defer") end)
button(ready,"Продолжить · N",3,3,60,function() send("Decline") end)
local readyNote=label(ready,102,34,12)
local skip=button(actions,"Пропустить · K",1,3,5,function() send("Skip") end)
local lobby=button(actions,"В лобби · L",2,3,5,function() send("Lobby") end)
local queue=button(actions,"Очередь · Q",3,3,5,function()
    if last then remotes.QueueAction:FireServer(if last.queue.queued then "Cancel" else "Register") end
end)
local replay=button(actions,"Знакомство с поместьем · R",1,1,5,function() send("Replay") end)
local saved=label(actions,48,35,12)
local marker=Instance.new("Highlight"); marker.Name,marker.FillTransparency,marker.OutlineColor,marker.DepthMode,marker.Parent="LessonTarget",1,UI.color("Brass"),Enum.HighlightDepthMode.Occluded,gui
local function render(s)
    if not s.prologue then return end
    last=s; local p=s.prologue
    hint.Visible=p.active; actions.Visible=p.available and not s.round.participating
    actions.AnchorPoint=if p.active then Vector2.new(0.5,1) else Vector2.new(1,0)
    actions.Position=if p.active then UDim2.new(0.5,0,1,-12) else UDim2.new(1,-12,0,252)
    actions:FindFirstChildOfClass("UISizeConstraint").MaxSize=Vector2.new(if p.active then 500 else 340,90)
    ready.Visible=p.available and s.queue.state=="MatchReady" and s.queue.needsConsent
    skip.Visible,lobby.Visible,queue.Visible,replay.Visible=p.active,p.active,p.active,not p.active
    saved.Text=if p.active then "Поиск идёт параллельно. Пролог без XP и жетонов. "..p.saved else p.saved
    if not s.queue.queued and p.active then saved.Text="Очередь выключена. Можно закончить знакомство или включить поиск." end
    queue.Text=if s.queue.queued then "Отменить поиск · Q" else "Искать матч · Q"
    readyNote.Text=if p.deferred then "Войдём после завершения текущего шага, если соперник ещё ждёт." else "Продолжить — остаться здесь и выйти из очереди."
    if p.active then
        title.Text="ЗНАКОМСТВО · сцена "..p.chapter.."/5 · шаг "..p.step.."/"..p.total
        text.Text=p.text
        if p.music and p.music.phase=="Running" then text.Text=if p.music.beat=="Move" then "ДВИГАЙСЯ на площадке" else "ЗАМРИ на площадке" end
    end
    marker.Adornee=if p.active then p.object else nil
    marker.Enabled=p.active
    if p.active~=wasActive then
        player.CameraMode=if p.active then Enum.CameraMode.Classic else Enum.CameraMode.LockFirstPerson
        player.CameraMinZoomDistance=if p.active then 7 else 0.5
        player.CameraMaxZoomDistance=if p.active then 15 else 400
        wasActive=p.active
    end
end
remotes.PersonalUpdate.OnClientEvent:Connect(function(kind,s) if kind=="Snapshot" then render(s) end end)
Input.InputBegan:Connect(function(key,processed)
    if processed or not last or not last.prologue.available or last.round.participating then return end
    local k=key.KeyCode
    if k==Enum.KeyCode.Y and ready.Visible then send("Accept")
    elseif k==Enum.KeyCode.J and ready.Visible then send("Defer")
    elseif k==Enum.KeyCode.N and ready.Visible then send("Decline")
    elseif last.prologue.active then
        if k==Enum.KeyCode.K then send("Skip") elseif k==Enum.KeyCode.L then send("Lobby")
        elseif k==Enum.KeyCode.Q then remotes.QueueAction:FireServer(if last.queue.queued then "Cancel" else "Register") end
    elseif k==Enum.KeyCode.R then send("Replay") end
end)
local elapsed=0
game:GetService("RunService").RenderStepped:Connect(function(dt)
    elapsed+=dt; if elapsed<0.25 then return end; elapsed=0
    local p=last and last.prologue; local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if p and p.active and root and p.target then distance.Text=p.action.." · расстояние "..math.floor((root.Position-p.target).Magnitude) end
end)
hint.Visible,actions.Visible,ready.Visible=false,false,false
