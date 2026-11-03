local Plan = require(script.Parent.RolePlan)
local Roles = {}
Roles.__index = Roles
function Roles.new(config, update)
    return setmetatable({values = {}, config = config, update = update, random = Random.new()}, Roles)
end
function Roles:get(player) return self.values[player.UserId] or self.config.ROLE_GUEST end
function Roles:assign(players)
    local ids = {}
    for index, player in ipairs(players) do if index <= 15 then table.insert(ids, player.UserId) end end
    self.values = Plan.assign(ids, function(n) return self.random:NextInteger(1, n) end, "M9")
    for _, player in ipairs(players) do self.update:FireClient(player, "Role", self:get(player)) end
    return ids
end
function Roles:remove(player) self.values[player.UserId] = nil end
function Roles:clear() self.values = {} end
return Roles
