local World = {}
function World.build()
    local Lighting = game:GetService("Lighting")
    local map = Instance.new("Folder")
    map.Name = "DoubleLifePrototype"
    map.Parent = workspace

    local function block(name, size, position, color, material)
        local part = Instance.new("Part")
        part.Name = name
        part.Size = size
        part.Position = position
        part.Anchored = true
        part.Material = material or Enum.Material.SmoothPlastic
        part.Color = color
        part.Parent = map
        return part
    end

    local stone = Color3.fromRGB(68, 69, 74)
    local floorColor = Color3.fromRGB(100, 76, 59)
    local wood = Color3.fromRGB(55, 33, 28)
    local gold = Color3.fromRGB(192, 153, 74)

    local function wall(name, size, position)
        return block(name, size, position, stone, Enum.Material.Brick)
    end

    -- One foyer, one study, an owner's door, and a second exterior infiltration route.
    block("ExteriorGround", Vector3.new(110, 1, 150), Vector3.new(0, -1, 20), Color3.fromRGB(43, 62, 48), Enum.Material.Grass)
    block("FoyerFloor", Vector3.new(56, 1, 56), Vector3.new(0, 0, 0), floorColor, Enum.Material.WoodPlanks)
    block("StudyFloor", Vector3.new(36, 1, 36), Vector3.new(0, 0, 58), floorColor, Enum.Material.WoodPlanks)
    block("PassageFloor", Vector3.new(12, 1, 14), Vector3.new(0, 0, 34), floorColor, Enum.Material.WoodPlanks)

    wall("FoyerWest", Vector3.new(1, 12, 56), Vector3.new(-28, 6, 0))
    wall("FoyerEast", Vector3.new(1, 12, 56), Vector3.new(28, 6, 0))
    wall("FoyerNorthLeft", Vector3.new(22, 12, 1), Vector3.new(-17, 6, 28))
    wall("FoyerNorthRight", Vector3.new(22, 12, 1), Vector3.new(17, 6, 28))
    wall("FoyerSouthLeft", Vector3.new(23, 12, 1), Vector3.new(-16.5, 6, -28))
    wall("FoyerSouthRight", Vector3.new(23, 12, 1), Vector3.new(16.5, 6, -28))
    wall("PassageLeft", Vector3.new(1, 12, 12), Vector3.new(-6, 6, 34))
    wall("PassageRight", Vector3.new(1, 12, 12), Vector3.new(6, 6, 34))
    wall("StudyNorth", Vector3.new(36, 12, 1), Vector3.new(0, 6, 76))
    wall("StudyEast", Vector3.new(1, 12, 36), Vector3.new(18, 6, 58))
    wall("StudySouthLeft", Vector3.new(14, 12, 1), Vector3.new(-11, 6, 40))
    wall("StudySouthRight", Vector3.new(14, 12, 1), Vector3.new(11, 6, 40))
    wall("StudyWestLower", Vector3.new(1, 12, 14), Vector3.new(-18, 6, 47))
    wall("StudyWestUpper", Vector3.new(1, 12, 14), Vector3.new(-18, 6, 69))

    local studyDoor = block("StudyDoor", Vector3.new(8, 11, 1), Vector3.new(0, 5.5, 40), wood)
    local studyWindow = block("StudyWindow", Vector3.new(1, 11, 8), Vector3.new(-18, 5.5, 58), Color3.fromRGB(69, 107, 124), Enum.Material.Glass)
    studyWindow.Transparency = 0.3

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "FoyerSpawn"
    spawn.Size = Vector3.new(7, 1, 7)
    spawn.Position = Vector3.new(0, 1, -16)
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Material = Enum.Material.Neon
    spawn.Color = Color3.fromRGB(117, 132, 117)
    spawn.Parent = map

    Lighting.ClockTime = 19.5
    Lighting.Brightness = 2
    Lighting.Ambient = Color3.fromRGB(85, 88, 105)


    local safe = block("DocumentSafe", Vector3.new(5,4,3), Vector3.new(0,2.5,65), gold, Enum.Material.Metal)
    local console = block("OwnerAccessConsole", Vector3.new(2,3,2), Vector3.new(3.5,2,33), gold)
    local logbook = block("ForensicLog", Vector3.new(2,1,2), Vector3.new(8,2,64), Color3.fromRGB(129,96,73))
    local exitDoor = block("EstateExit", Vector3.new(9,10,1), Vector3.new(0,5,-28), Color3.fromRGB(36,83,69))
    exitDoor.CanCollide = false
    exitDoor.Transparency = 0.35
    return {map=map, block=block, gold=gold, studyDoor=studyDoor, studyWindow=studyWindow,
        console=console, safe=safe, logbook=logbook, exitDoor=exitDoor}
end
return World
