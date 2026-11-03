local Policy = require(script.Parent.ActorPolicy)
local Players = game:GetService("Players")
local Registry = {}
Registry.__index = Registry
function Registry.new() return setmetatable({values = {}, serial = 0}, Registry) end
function Registry:addHuman(player)
    assert(typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players)
    self.values[player.UserId] = Policy.human(player.UserId, player)
end
function Registry:addMimic(model, name)
    self.serial += 1
    local actor = Policy.mimic("m:" .. self.serial, model, name)
    self.values[actor.id] = actor
    model:SetAttribute("ActorId", actor.id)
    model:SetAttribute("ActorKind", "Mimic")
    return actor
end
function Registry:get(id) return self.values[id] end
function Registry:remove(id) self.values[id] = nil end
function Registry:human(id)
    local a = self.values[id]
    return if Policy.canProfile(a) and a.player.Parent == Players then a.player else nil
end
return Registry
