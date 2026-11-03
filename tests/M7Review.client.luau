-- Only in the review build. Camera tour does not move the character or prove routes.
assert(game:GetService("RunService"):IsStudio(),"Studio only")
local player=game.Players.LocalPlayer
local UI=require(player.PlayerScripts:WaitForChild("DoubleLifeClient"):WaitForChild("Interface"))
local camera=workspace.CurrentCamera
local views={
    {"Приёмная",Vector3.new(-10,6,-31),Vector3.new(6,9,-5)},
    {"Галерея",Vector3.new(-42,6,10),Vector3.new(-51,6,-20)},
    {"Бальный зал",Vector3.new(23,6,-30),Vector3.new(42,8,5)},
    {"Читальня",Vector3.new(-25,6,52),Vector3.new(-50,6,40)},
    {"Променад",Vector3.new(-27,24,20),Vector3.new(12,25,31)},
    {"Кабинет",Vector3.new(13,24,36),Vector3.new(-3,23,56)},
    {"Терраса",Vector3.new(-42,24,73),Vector3.new(3,23,64)},
    {"Лестница",Vector3.new(-62,5,14),Vector3.new(-62,16,46)},
}
local gui=Instance.new("ScreenGui"); gui.Name,gui.DisplayOrder,gui.Parent="M7ReviewControls",20,player:WaitForChild("PlayerGui")
local index=0
local function button(text,x,callback)
    local b=Instance.new("TextButton")
    b.Text,b.Size,b.Position,b.TextSize,b.Parent=text,UDim2.fromOffset(100,36),UDim2.new(0,x,1,-122),12,gui
    UI.decorate(b,true); b.Selectable=false; b.Activated:Connect(callback); return b
end
local viewButton
local function nextView()
    index=index%#views+1
    camera.CameraType=Enum.CameraType.Scriptable
    camera.CFrame=CFrame.lookAt(views[index][2],views[index][3])
    viewButton.Text=views[index][1].." →"
    print("M7 REVIEW view",views[index][1])
end
viewButton=button("Обзор →",14,nextView)
button("Свет / сбой",120,function() game.ReplicatedStorage.M7Review:FireServer("Blackout") end)
button("Играть",226,function()
    camera.CameraType=Enum.CameraType.Custom
    camera.CameraSubject=(player.Character or player.CharacterAdded:Wait()):WaitForChild("Humanoid")
end)
button("Интерфейс",332,function()
    for _,name in ipairs({"DoubleLifeHUD","DoubleLifeSocial","MansionPresentation"}) do
        local target=player.PlayerGui:FindFirstChild(name)
        if target then target.Enabled=not target.Enabled end
    end
end)
task.wait(8)
nextView()
local pg=player.PlayerGui
local rules=pg.DoubleLifeHUD.CouncilPanel
local scroll=rules:FindFirstChildOfClass("ScrollingFrame")
rules:GetPropertyChangedSignal("Visible"):Connect(function()
    if rules.Visible then
        task.wait(0.2)
        print("M7 REVIEW scroll",scroll.Active,scroll.ScrollingEnabled,scroll.AbsoluteSize,scroll.AbsoluteCanvasSize,scroll.CanvasPosition)
    end
end)
scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    if rules.Visible then print("M7 REVIEW scrolled",scroll.CanvasPosition) end
end)
game:GetService("GuiService"):GetPropertyChangedSignal("SelectedObject"):Connect(function()
    local selected=game:GetService("GuiService").SelectedObject
    print("M7 REVIEW selection",selected and selected.Name or "none")
end)
