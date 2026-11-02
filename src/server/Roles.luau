-- This table lives only in ServerScriptService. Never add role attributes or teams.
local Roles = {}
Roles.__index = Roles

function Roles.new(config, update)
    return setmetatable({values = {}, config = config, update = update}, Roles)
end

function Roles:get(player)
    return self.values[player.UserId] or self.config.ROLE_GUEST
end

function Roles:add(player)
    local c = self.config
    local used = {}
    for _, role in pairs(self.values) do used[role] = true end
    local role = c.ROLE_GUEST
    for _, candidate in ipairs({c.ROLE_OWNER, c.ROLE_SPY, c.ROLE_AGENT, c.ROLE_STAFF}) do
        if not used[candidate] then role = candidate; break end
    end
    self.values[player.UserId] = role
    self.update:FireClient(player, "Role", role)
end

function Roles:remove(player, remaining)
    local vacant = self.values[player.UserId]
    self.values[player.UserId] = nil
    -- Preserve M0 guest promotion; existing special roles never change silently.
    if vacant and vacant ~= self.config.ROLE_GUEST then
        for _, other in ipairs(remaining) do
            if other ~= player and self:get(other) == self.config.ROLE_GUEST then
                self.values[other.UserId] = vacant
                self.update:FireClient(other, "Role", vacant)
                break
            end
        end
    end
end

return Roles
