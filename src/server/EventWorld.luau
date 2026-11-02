local Scene = {}
function Scene.build(world)
    local function part(name, size, position, color)
        return world.block(name, size, position, color)
    end
    local stage = part("MusicFloor", Vector3.new(16, 0.12, 14), Vector3.new(8, 0.6, 1), Color3.fromRGB(56, 100, 105))
    stage.CanCollide = false
    local pedestal = part("RelicPedestal", Vector3.new(3, 2, 3), Vector3.new(-5, 1.5, 10), world.gold)
    local console = part("EventConsole", Vector3.new(2, 3, 2), Vector3.new(9, 2, 24), Color3.fromRGB(98, 110, 157))
    local bell = part("PracticeBell", Vector3.new(1.5, 2, 1.5), Vector3.new(21, 1.7, -21), world.gold)
    local beacon = part("MusicSignal", Vector3.new(1, 6, 1), Vector3.new(16, 3.5, 9), Color3.fromRGB(100, 130, 150))
    local gui = Instance.new("BillboardGui")
    gui.Size, gui.StudsOffset, gui.MaxDistance = UDim2.fromOffset(300, 80), Vector3.new(0, 4, 0), 60
    gui.Parent = beacon
    local label = Instance.new("TextLabel")
    label.Size, label.BackgroundTransparency, label.TextColor3 = UDim2.fromScale(1, 1), 0.15, Color3.new(1, 1, 1)
    label.BackgroundColor3, label.TextWrapped, label.TextSize = Color3.fromRGB(28, 32, 40), true, 18
    label.Font, label.Text, label.Parent = Enum.Font.GothamBold, "Площадка мероприятий", gui
    local lamps = {}
    for _, x in ipairs({-21, 21}) do
        local lamp = part("HallLamp", Vector3.new(1, 1, 1), Vector3.new(x, 10, 2), Color3.fromRGB(255, 218, 156))
        lamp.Material, lamp.CanCollide = Enum.Material.Neon, false
        local light = Instance.new("PointLight")
        light.Brightness, light.Range, light.Color, light.Parent = 4, 40, lamp.Color, lamp
        table.insert(lamps, {part = lamp, light = light})
    end
    for _, z in ipairs({-24, -10, 12, 26, 35}) do
        local marker = part("SafePathLight", Vector3.new(0.5, 0.15, 2), Vector3.new(3, 0.7, z), Color3.fromRGB(139, 208, 197))
        marker.CanCollide, marker.Material = false, Enum.Material.Neon
        local light = Instance.new("PointLight")
        light.Brightness, light.Range, light.Parent = 1.5, 10, marker
    end
    return {stage = stage, pedestal = pedestal, console = console, bell = bell, beacon = beacon, label = label, lamps = lamps,
        relicSpots = {Vector3.new(-20, 1.4, 7), Vector3.new(19, 1.4, 18), Vector3.new(-10, 1.4, -8)}}
end
return Scene
