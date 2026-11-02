-- One transferable clue. Its origin describes an event/place, never a player.
local Evidence = {}
Evidence.__index = Evidence
function Evidence.new(world, interactions, tell)
    return setmetatable({world = world, interactions = interactions, tell = tell}, Evidence)
end
function Evidence:place(position)
    if self.part then self.part:Destroy() end
    local part = self.world.block("BrokenSeal", Vector3.new(1.4, 0.25, 1), position, Color3.fromRGB(220, 108, 71))
    part.CanCollide = false
    self.part = part
    self.interactions:bind(self.interactions.prompt(part, "Подобрать улику", "Сломанная пломба · кабинет", 0.75), function(player)
        if self.holder or self.part ~= part then return end
        self.holder, self.part = player.UserId, nil
        part:Destroy()
        self.tell(player, "У вас сломанная пломба. Место: сейф, кабинет. Можно приложить к голосу или уронить.")
    end)
end
function Evidence:create()
    if self.created then return end
    self.created = true
    self:place(self.world:point("Evidence.Home"))
end
function Evidence:description(id)
    if self.holder ~= id then return nil end
    return {kind = "Сломанная пломба", location = "Сейф, кабинет"}
end
function Evidence:drop(player)
    if self.holder ~= player.UserId then return false end
    self.holder = nil
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local home = self.world:point("Evidence.Home")
    local position = if root then self.world:dropPoint(root.Position, home, 0.15) else home
    self:place(position)
    return true
end
return Evidence
