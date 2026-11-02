local Scene = {}
function Scene.build(world)
    local stage, pedestal = world:object("Events.Stage"), world:object("Events.Pedestal")
    local console, bell, beacon = world:object("Events.Console"), world:object("Events.Bell"), world:object("Events.Beacon")
    local gui=Instance.new("BillboardGui")
    gui.Size,gui.StudsOffset,gui.MaxDistance=UDim2.fromOffset(300,80),Vector3.new(0,4,0),60
    gui.Parent=beacon
    local label=Instance.new("TextLabel")
    label.Size,label.BackgroundTransparency,label.TextColor3=UDim2.fromScale(1,1),0.15,Color3.new(1,1,1)
    label.BackgroundColor3,label.TextWrapped,label.TextSize=Color3.fromRGB(28,32,40),true,18
    label.Font,label.Text,label.Parent=Enum.Font.GothamBold,"Площадка мероприятий",gui
    local lamps={}
    for _,position in ipairs(world:points("Lamps")) do
        local lamp=world.block("HallLamp",Vector3.one,position,Color3.fromRGB(255,218,156),Enum.Material.Neon)
        lamp.CanCollide=false
        local light=Instance.new("PointLight")
        light.Brightness,light.Range,light.Color,light.Parent=1.2,32,lamp.Color,lamp
        table.insert(lamps,{part=lamp,light=light})
    end
    for _,position in ipairs(world:points("PathLights")) do
        local marker=world.block("SafePathLight",Vector3.new(0.5,0.15,2),position,Color3.fromRGB(139,208,197),Enum.Material.Neon)
        marker.CanCollide=false
        local light=Instance.new("PointLight"); light.Brightness,light.Range,light.Parent=1.5,16,marker
    end
    return {stage=stage,pedestal=pedestal,console=console,bell=bell,beacon=beacon,label=label,lamps=lamps,relicSpots=world:points("Events.RelicSpots")}
end
return Scene
