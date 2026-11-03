local Players=game:GetService("Players")
local GuiService=game:GetService("GuiService")
local Input=game:GetService("UserInputService")
local P=require(game:GetService("ReplicatedStorage").DoubleLifeShared.Presentation)
local UI={presentation=P}
local events=Instance.new("BindableEvent")
UI.action=events.Event
function UI.send(action) events:Fire(action) end
function UI.color(key) return Color3.fromRGB(table.unpack(P.colors[key])) end
function UI.textHeight(text,width,minimum,size)
    return math.max(minimum,game:GetService("TextService"):GetTextSize(text,size or 14,Enum.Font.GothamMedium,Vector2.new(math.max(120,width),10000)).Y+6)
end
function UI.watchViewport(gui,callback)
    local cameraConnection
    local function refresh()
        if gui.AbsoluteSize.X>=200 and gui.AbsoluteSize.Y>=200 then callback(gui.AbsoluteSize) end
    end
    local function bind()
        if cameraConnection then cameraConnection:Disconnect() end
        local camera=workspace.CurrentCamera
        if camera then cameraConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh) end
        refresh()
    end
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind)
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
    bind()
end
function UI.decorate(instance,button)
    instance.BorderSizePixel=0
    instance.BackgroundColor3=UI.color(if button then "Teal" else "Ink")
    if instance:IsA("TextButton") or instance:IsA("TextLabel") then
        instance.TextColor3,instance.Font=UI.color("Paper"),Enum.Font.GothamMedium
        instance.AutoLocalize=true
    end
    local stroke=Instance.new("UIStroke")
    stroke.Name,stroke.Color,stroke.Thickness,stroke.ApplyStrokeMode,stroke.Parent="DecoOutline",UI.color("Brass"),1,Enum.ApplyStrokeMode.Border,instance
    if button then
        instance.Selectable=true
        instance.SelectionGained:Connect(function() stroke.Thickness=3 end)
        instance.SelectionLost:Connect(function() stroke.Thickness=1 end)
    end
end
function UI.focus(panel)
    if Input.GamepadEnabled and panel.Visible then
        for _,child in ipairs(panel:GetDescendants()) do
            if child:IsA("TextButton") and child.Visible then GuiService.SelectedObject=child; return end
        end
    end
end
-- Explicit paging also works when a device cannot comfortably drag long text.
function UI.pager(gui,panel,scroll)
    local row=Instance.new("Frame")
    row.Name,row.BackgroundTransparency,row.AnchorPoint,row.Parent=panel.Name.."Pager",1,Vector2.new(0.5,0),gui
    local function refresh()
        row.Size=UDim2.fromOffset(panel.AbsoluteSize.X,44)
        row.Position=UDim2.new(panel.Position.X.Scale,panel.Position.X.Offset,
            panel.Position.Y.Scale,panel.Position.Y.Offset+panel.AbsoluteSize.Y/2+4)
        row.Visible=panel.Visible and scroll.AbsoluteCanvasSize.Y>scroll.AbsoluteSize.Y
        if not row.Visible and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(row) then
            GuiService.SelectedObject=nil
        end
    end
    for index,direction in ipairs({-1,1}) do
        local b=Instance.new("TextButton")
        b.Name,b.Text=if direction<0 then "Up" else "Down",if direction<0 then "↑" else "↓"
        b.Size,b.Position=UDim2.new(0.5,-4,1,0),UDim2.new((index-1)/2,if index==1 then 0 else 4,0,0)
        b.TextSize,b.Modal,b.Parent=22,true,row
        UI.decorate(b,true)
        b.Activated:Connect(function()
            scroll.CanvasPosition=Vector2.new(0,math.clamp(scroll.CanvasPosition.Y+direction*scroll.AbsoluteSize.Y*0.8,
                0,math.max(0,scroll.AbsoluteCanvasSize.Y-scroll.AbsoluteSize.Y)))
        end)
    end
    panel:GetPropertyChangedSignal("Visible"):Connect(refresh)
    panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
    panel:GetPropertyChangedSignal("Position"):Connect(refresh)
    scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(refresh)
    refresh()
end
function UI.bindPanel(panel)
    panel:GetPropertyChangedSignal("Visible"):Connect(function()
        if panel.Visible then
            Players.LocalPlayer.PlayerGui:SetAttribute("MansionPanel",panel.Name)
            UI.focus(panel)
        elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then GuiService.SelectedObject=nil end
    end)
end
return UI
