local Players = game:GetService("Players")
local Interactions = {}
Interactions.__index = Interactions

function Interactions.new(state)
    return setmetatable({state = state, last = {}, holds = {}}, Interactions)
end

function Interactions.prompt(part, action, object, hold)
    local p = Instance.new("ProximityPrompt")
    p.ActionText, p.ObjectText = action, object
    p.HoldDuration = hold or 0.5
    p.MaxActivationDistance = 10
    p.RequiresLineOfSight = true
    p.Parent = part
    return p
end

function Interactions:inReach(player, p)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local host = p.Parent
    if self.state.finished or player.Parent ~= Players or not p.Enabled or not host
        or not host:IsDescendantOf(workspace) or not root or not humanoid or humanoid.Health <= 0
        or (root.Position - host.Position).Magnitude > p.MaxActivationDistance + 1 then
        return false
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    local origin = (character:FindFirstChild("Head") or root).Position
    local hit = workspace:Raycast(origin, host.Position - origin, params)
    return hit == nil or hit.Instance == host
end

function Interactions:bind(p, callback)
    local starts = {}
    self.holds[p] = starts
    p.PromptButtonHoldBegan:Connect(function(player)
        if self:inReach(player, p) then starts[player.UserId] = os.clock() end
    end)
    p.Triggered:Connect(function(player)
        local now, id = os.clock(), player.UserId
        local started = starts[id]
        starts[id] = nil
        if not self:inReach(player, p) or now < (self.last[id] or 0) then return end
        -- Hold signals are untrusted too: require elapsed server time and recheck reach.
        if p.HoldDuration > 0 and (not started or now - started < p.HoldDuration - 0.1
            or now - started > p.HoldDuration + 3) then return end
        self.last[id] = now + 0.4
        callback(player)
    end)
end

function Interactions:remove(player)
    self.last[player.UserId] = nil
    for _, holds in pairs(self.holds) do holds[player.UserId] = nil end
end

return Interactions
