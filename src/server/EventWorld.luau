local Scene = {}
function Scene.build(world)
    local stage, pedestal = world:object("Events.Stage"), world:object("Events.Pedestal")
    local console, bell, beacon = world:object("Events.Console"), world:object("Events.Bell"), world:object("Events.Beacon")
    local gui=Instance.new("BillboardGui")
    gui.Size,gui.StudsOffset,gui.MaxDistance=UDim2.fromOffset(250,52),Vector3.new(0,4,0),42
    gui.Parent=beacon
    local label=Instance.new("TextLabel")
    label.Size,label.BackgroundTransparency,label.TextColor3=UDim2.fromScale(1,1),0.1,Color3.fromRGB(239,229,204)
    label.BackgroundColor3,label.TextWrapped,label.TextSize=Color3.fromRGB(23,34,39),true,15
    label.Font,label.Text,label.Parent=Enum.Font.GothamMedium,"Площадка мероприятий",gui
    local stroke=Instance.new("UIStroke")
    stroke.Color,stroke.ApplyStrokeMode,stroke.Parent=Color3.fromRGB(180,143,78),Enum.ApplyStrokeMode.Border,label
    local lamps={}
    for _,position in ipairs(world:points("Lamps")) do
        local lamp=world.block("HallLamp",Vector3.one,position,Color3.fromRGB(255,235,207),Enum.Material.Neon)
        lamp.CanCollide,lamp.CanQuery=false,false
        lamp.Shape=Enum.PartType.Ball
        local light=Instance.new("PointLight")
        light.Brightness,light.Range,light.Color,light.Shadows,light.Parent=0.5,24,lamp.Color,false,lamp
        table.insert(lamps,{part=lamp,light=light})
    end
    for _,position in ipairs(world:points("PathLights")) do
        local marker=world.block("SafePathLight",Vector3.new(0.5,0.15,2),position,Color3.fromRGB(139,208,197),Enum.Material.Neon)
        marker.CanCollide,marker.CanQuery=false,false
        local light=Instance.new("PointLight"); light.Brightness,light.Range,light.Color,light.Parent=0.35,13,marker.Color,marker
    end
    return {stage=stage,pedestal=pedestal,console=console,bell=bell,beacon=beacon,label=label,lamps=lamps,relicSpots=world:points("Events.RelicSpots")}
end
return Scene
