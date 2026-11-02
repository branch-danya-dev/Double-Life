-- Pure server policy; injected timestamps make spam limits and expiry testable.
local Policy = {}
Policy.__index = Policy

function Policy.new(config)
    return setmetatable({config = config, state = "Patrol", zone = "Corridor",
        revision = 0, nextReaction = 0, nextCommand = 0, sources = {}}, Policy)
end

function Policy:investigate(source, target, now, ownerOrder)
    if self.state ~= "Patrol" or now < self.nextReaction then return false end
    if not ownerOrder and now < (self.sources[source] or 0) then return false end
    self.sources[source] = now + self.config.NOISE_SOURCE_COOLDOWN
    self.state, self.target = "Investigate", target
    self.deadline = now + self.config.INVESTIGATE_SECONDS
    self.revision += 1
    return true
end

function Policy:command(kind, value, now)
    if now < self.nextCommand or self.state ~= "Patrol" then return false end
    if kind == "zone" then
        if value ~= "Foyer" and value ~= "Corridor" then return false end
        self.zone = value
        self.revision += 1
    elseif kind == "inspect" then
        if not self:investigate("Owner", value, now, true) then return false end
    else
        return false
    end
    self.nextCommand = now + self.config.OWNER_COMMAND_COOLDOWN
    return true
end

function Policy:beginReturn(now)
    self.state, self.target = "Return", nil
    self.deadline = now + self.config.RETURN_SECONDS
    self.revision += 1
end

function Policy:resume(now)
    self.state = "Patrol"
    self.nextReaction = now + self.config.GUARD_REST_SECONDS
    self.revision += 1
end

return Policy
