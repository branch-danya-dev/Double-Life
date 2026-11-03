local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local SoundService=game:GetService("SoundService")
local Tween=game:GetService("TweenService")
local CAS=game:GetService("ContextActionService")
local Prompts=game:GetService("ProximityPromptService")
local UI=require(script.Parent.Interface)
local P=UI.presentation
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local remotes=RS:WaitForChild("DoubleLifeRemotes")
local locale=player.LocaleId
local function t(key) return P.label(locale,key) end
local gui=Instance.new("ScreenGui")
gui.Name,gui.ResetOnSpawn,gui.DisplayOrder,gui.Parent="MansionPresentation",false,8,pg
local function label(parent,name,text,size,position)
    local l=Instance.new("TextLabel")
    l.Name,l.Text,l.Size,l.Position,l.TextSize=name,text,size,position,14
    l.TextWrapped,l.BackgroundTransparency,l.TextColor3,l.Font,l.Parent=true,1,UI.color("Paper"),Enum.Font.GothamMedium,parent
    return l
end
local function button(parent,name,text,size,position,callback)
    local b=Instance.new("TextButton")
    b.Name,b.Text,b.Size,b.Position,b.TextSize,b.TextWrapped,b.Parent=name,text,size,position,14,true,parent
    UI.decorate(b,true); b.Activated:Connect(callback); return b
end
local menu=Instance.new("ScrollingFrame")
menu.Name,menu.Size,menu.Position,menu.AnchorPoint,menu.Visible,menu.Parent="MansionMenu",UDim2.fromOffset(300,378),UDim2.fromScale(0.5,0.5),Vector2.new(0.5,0.5),false,gui
UI.decorate(menu,false); UI.bindPanel(menu)
menu.ScrollBarThickness,menu.ScrollingDirection=5,Enum.ScrollingDirection.Y
menu.BackgroundTransparency,menu.ClipsDescendants,menu.Active=0.02,true,true
menu.CanvasSize=UDim2.fromOffset(0,378)
label(menu,"Title",t("Header"),UDim2.new(1,-20,0,42),UDim2.fromOffset(10,4))
local settings=Instance.new("ScrollingFrame")
settings.Name,settings.Size,settings.Position,settings.AnchorPoint,settings.Visible,settings.Parent="AtmosphereSettings",UDim2.fromOffset(320,276),UDim2.fromScale(0.5,0.5),Vector2.new(0.5,0.5),false,gui
UI.decorate(settings,false); UI.bindPanel(settings)
settings.ScrollBarThickness,settings.ScrollingDirection=5,Enum.ScrollingDirection.Y
settings.BackgroundTransparency,settings.ClipsDescendants,settings.Active=0.02,true,true
settings.CanvasSize=UDim2.fromOffset(0,276)
label(settings,"Title",t("Settings"),UDim2.new(1,-20,0,40),UDim2.fromOffset(10,4))
local soundOn,motionOn,bright=false,true,false
-- Audio is opt-in to avoid an unexpected loop when a player first joins.
gui:SetAttribute("SoundEnabled",soundOn); gui:SetAttribute("MotionEnabled",motionOn)
local function sound(name,id,volume,looped,speed)
    local s=Instance.new("Sound")
    s.Name,s.SoundId,s.Volume,s.Looped,s.PlaybackSpeed,s.Parent=name,id,volume,looped,speed,SoundService
    return s
end
local cue=sound("MansionCue",P.audio.Cue,0.12,false,1.4)
local room=sound("MansionRoom",P.audio.Room,0.025,true,0.65)
local beat=sound("MansionBeat",P.audio.Cue,0.08,false,1)
local accessibility=Instance.new("ColorCorrectionEffect")
accessibility.Name,accessibility.Enabled,accessibility.Brightness,accessibility.Contrast,accessibility.Parent="MansionAccessibility",false,0.12,-0.1,workspace.CurrentCamera
local switches={}
local function updateSettings()
    switches.Sound.Text=t("Sound")..": "..t(if soundOn then "On" else "Off")
    switches.Motion.Text=t("Motion")..": "..t(if motionOn then "On" else "Off")
    switches.Contrast.Text=t("Contrast")..": "..t(if bright then "On" else "Off")
    gui:SetAttribute("SoundEnabled",soundOn); gui:SetAttribute("MotionEnabled",motionOn)
    accessibility.Enabled=bright
    if soundOn then room:Play() else room:Stop(); cue:Stop(); beat:Stop() end
end
switches.Sound=button(settings,"Sound","",UDim2.new(1,-24,0,44),UDim2.fromOffset(12,48),function() soundOn=not soundOn; updateSettings() end)
switches.Motion=button(settings,"Motion","",UDim2.new(1,-24,0,44),UDim2.fromOffset(12,100),function() motionOn=not motionOn; updateSettings() end)
switches.Contrast=button(settings,"Contrast","",UDim2.new(1,-24,0,44),UDim2.fromOffset(12,152),function() bright=not bright; updateSettings() end)
local closeSettings=button(settings,"Close",t("Close"),UDim2.new(1,-24,0,44),UDim2.fromOffset(12,216),function() settings.Visible=false end)
closeSettings.Modal=true
updateSettings()
local function close() menu.Visible,settings.Visible=false,false end
local function toggle()
    local open=not menu.Visible
    UI.send("Close"); settings.Visible=false; menu.Visible=open
    UI.focus(menu)
end
for i,key in ipairs({"Rules","Profile","Social","Shop","Settings","Close"}) do
    local b=button(menu,key,t(key),UDim2.new(1,-24,0,44),UDim2.fromOffset(12,48+(i-1)*53),function()
        close()
        if key=="Settings" then settings.Visible=true; UI.focus(settings) elseif key~="Close" then UI.send(key) end
    end)
    b.Modal=true
end
local menuButton=button(gui,"Menu","◇  Меню · Tab",UDim2.fromOffset(124,44),UDim2.new(1,-136,0,12),toggle)
menuButton.SelectionOrder=-10
local state
local dropButton=button(gui,"Drop",t("Drop"),UDim2.fromOffset(124,44),UDim2.new(1,-136,0,64),function()
    if not state then return end
    if state.evidence then remotes.CouncilAction:FireServer("DropEvidence",state.round.roundId)
    elseif state.activities.event.hasRelic then remotes.EventAction:FireServer("DropRelic",state.round.roundId)
    elseif state.social.held then remotes.SocialAction:FireServer("Drop",nil,state.round.roundId) end
end)
dropButton.Visible=false
local toast=label(gui,"Feedback","",UDim2.new(0.8,0,0,48),UDim2.new(0.5,0,0.65,0))
toast.AnchorPoint,toast.Visible=Vector2.new(0.5,0.5),false
local toastLimit=Instance.new("UISizeConstraint"); toastLimit.MaxSize,toastLimit.Parent=Vector2.new(520,120),toast
UI.decorate(toast,false); toast.BackgroundTransparency=0.08
local held=label(gui,"HeldCard",t("Held"),UDim2.fromOffset(210,44),UDim2.new(1,-224,1,-62))
UI.decorate(held,false); held.BackgroundTransparency,held.Visible=0.08,false
local progress=label(gui,"Interaction",t("Action"),UDim2.fromOffset(240,32),UDim2.new(0.5,-120,0.57,0))
progress.Visible=false
local fill=Instance.new("Frame")
fill.Name,fill.Size,fill.Position,fill.BackgroundColor3,fill.BorderSizePixel,fill.Parent="HoldProgress",UDim2.fromScale(0,0.1),UDim2.fromScale(0,1),UI.color("Brass"),0,progress
local holding,holdStart,feedbackUntil,activeTween=nil,0,0,nil
Prompts.PromptButtonHoldBegan:Connect(function(prompt)
    holding,holdStart=prompt,os.clock(); progress.Text,progress.Visible=prompt.ActionText,true
end)
Prompts.PromptButtonHoldEnded:Connect(function() holding=nil; progress.Visible=false end)
local function feedback(text)
    toast.Text,toast.Visible,feedbackUntil=text,true,os.clock()+3
    toast.Size=UDim2.new(0.8,0,0,math.min(120,UI.textHeight(text,toast.AbsoluteSize.X-16,48,14)))
    if soundOn then cue:Play() end
    if activeTween then activeTween:Cancel() end
    held.Rotation=if motionOn then -4 else 0
    if motionOn then activeTween=Tween:Create(held,TweenInfo.new(0.35),{Rotation=0}); activeTween:Play() end
end
local function fitMenu()
    local size=gui.AbsoluteSize
    if size.X<200 or size.Y<200 then return end
    local columns=if size.Y<420 and size.X>=600 then 2 else 1
    local width=math.min(if columns==2 then 560 else 300,size.X-24)
    local index=0
    for _,key in ipairs({"Rules","Profile","Social","Shop","Settings","Close"}) do
        local b=menu:FindFirstChild(key)
        if b.Visible then
            local buttonWidth=(width-24-(columns-1)*12)/columns
            b.Position=UDim2.fromOffset(12+(index%columns)*(buttonWidth+12),48+math.floor(index/columns)*53)
            b.Size=UDim2.fromOffset(buttonWidth,44)
            index+=1
        end
    end
    local height=60+math.ceil(index/columns)*53
    menu.CanvasSize=UDim2.fromOffset(0,height)
    menu.Size=UDim2.fromOffset(width,math.min(height,size.Y-24))
end
local function snapshot(value)
    local message=P.feedback(state,value)
    if not state or state.round.roundId~=value.round.roundId or state.round.phase~=value.round.phase then
        close(); holding=nil; progress.Visible=false; toast.Visible=false; feedbackUntil=0
    end
    state=value
    dropButton.Visible=value.evidence~=nil or value.activities.event.hasRelic==true or value.social.held~=nil
    held.Visible=P.held(value) and value.round.phase=="Active"
    if message then feedback(message) end
    local profile=menu:FindFirstChild("Profile")
    profile.Visible=value.round.phase=="Waiting" or value.round.phase=="Results"
    fitMenu()
end
remotes.PersonalUpdate.OnClientEvent:Connect(function(kind,value)
    if kind=="Snapshot" then snapshot(value) elseif kind=="Notice" or kind=="EventNotice" then feedback(value) end
end)
UI.action:Connect(function(action) if action=="Close" then close() end end)
pg:GetAttributeChangedSignal("MansionPanel"):Connect(function()
    local name=pg:GetAttribute("MansionPanel")
    if name~="MansionMenu" and name~="AtmosphereSettings" then close() end
end)
CAS:BindAction("MansionMenu",function(_,input)
    if input==Enum.UserInputState.Begin then toggle() end
    return Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.Tab)
CAS:BindAction("MansionBack",function(_,input)
    if input==Enum.UserInputState.Begin then UI.send("Close") end
    return Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.ButtonB)
local npcs={}
local function track(instance)
    if instance:IsA("Model") and instance:GetAttribute("MansionNPC") then
        local root=instance:FindFirstChild("HumanoidRootPart")
        if root then npcs[instance]={root=root,joints=root:GetChildren(),phase=0} end
    end
end
for _,d in ipairs(workspace:GetDescendants()) do track(d) end
workspace.DescendantAdded:Connect(track)
local beatAt,step=0,0
Run.PreSimulation:Connect(function(dt)
    local now=os.clock()
    if holding then fill.Size=UDim2.fromScale(math.clamp((now-holdStart)/math.max(0.1,holding.HoldDuration),0,1),0.1) end
    if toast.Visible and now>feedbackUntil then toast.Visible=false end
    for model,npc in pairs(npcs) do
        if not model.Parent then npcs[model]=nil
        else
            local distance=(npc.root.Position-workspace.CurrentCamera.CFrame.Position).Magnitude
            local speed=npc.root.AssemblyLinearVelocity*Vector3.new(1,0,1)
            local moving=motionOn and distance<90 and speed.Magnitude>0.5
            npc.phase+=dt*math.min(speed.Magnitude,12)*0.7
            for _,joint in ipairs(npc.joints) do
                if joint:IsA("Motor6D") then
                    local name=joint.Name
                    local limb=string.find(name,"Leg") or string.find(name,"Arm")
                    local sign=if string.find(name,"Left") then 1 else -1
                    if string.find(name,"Arm") then sign=-sign end
                    joint.Transform=if moving and limb then CFrame.Angles(math.sin(npc.phase)*0.35*sign,0,0) else CFrame.identity
                end
            end
        end
    end
    if soundOn and state then
        local e=state.activities.event
        local dance=e.phase=="Running" and e.kind=="Music" and e.beat=="Move" and state.round.phase=="Active"
        if dance and now>=beatAt then
            step=(step+1)%4; beat.PlaybackSpeed=({0.8,1.2,1,1.5})[step+1]; beat:Play(); beatAt=now+0.5
        elseif not dance then beat:Stop(); beatAt=now end
        room.Volume=if state.round.phase=="Council" then 0 elseif state.activities.incident and state.activities.incident.kind=="Blackout" then 0.015 else 0.025
    end
end)
local function fit()
    local size=gui.AbsoluteSize
    local layout=P.layout(size.X,size.Y)
    fitMenu()
    settings.Size=UDim2.fromOffset(math.min(320,layout.panelWidth),math.min(276,size.Y-24))
    gui:SetAttribute("Compact",layout.compact)
    menuButton.Text=if game:GetService("UserInputService").TouchEnabled then "◇  Меню" else "◇  Меню · Tab"
end
UI.watchViewport(gui,fit)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() accessibility.Parent=workspace.CurrentCamera end)
local ok,value=pcall(function() return remotes.GetState:InvokeServer() end)
if ok then snapshot(value) end
