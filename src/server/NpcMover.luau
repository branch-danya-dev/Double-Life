local PathfindingService = game:GetService("PathfindingService")
local Mover = {}
Mover.__index = Mover

function Mover.new(parent, name, position, color, scope)
    local model = Instance.new("Model")
    model.Name = name
    local root = Instance.new("Part")
    root.Name, root.Size = "HumanoidRootPart", Vector3.new(2, 2, 1)
    root.Transparency, root.CollisionGroup = 1, "DoubleLifeActors"
    root.CanQuery = false
    root.CFrame = CFrame.new(position)
    root.Parent = model
    local function body(name_, size, offset)
        local part = Instance.new("Part")
        part.Name, part.Size, part.Color = name_, size, color
        part.CanCollide, part.CanQuery, part.Massless = false, false, true
        part.CFrame = root.CFrame * CFrame.new(offset)
        part.Parent = model
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1, weld.Parent = root, part, root
        return part
    end
    body("Torso", Vector3.new(2, 2, 1), Vector3.zero)
    local head = body("Head", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 1.7, 0))
    body("Left Leg", Vector3.new(0.8, 2, 0.8), Vector3.new(-0.55, -2, 0))
    body("Right Leg", Vector3.new(0.8, 2, 0.8), Vector3.new(0.55, -2, 0))
    local humanoid = Instance.new("Humanoid")
    humanoid.RequiresNeck = false
    -- This rig has R6 legs: their two studs already contribute to standing height.
    -- Adding R15's hip offset floated the root above stair waypoints and broke arrival checks.
    humanoid.HipHeight, humanoid.WalkSpeed = 0, 11
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.Parent = model
    model.PrimaryPart, model.Parent = root, parent
    root:SetNetworkOwner(nil)
    local sign = Instance.new("BillboardGui")
    sign.Size, sign.StudsOffset, sign.MaxDistance = UDim2.fromOffset(190, 42), Vector3.new(0, 2.5, 0), 45
    sign.Parent = head
    local label = Instance.new("TextLabel")
    label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
    label.TextColor3, label.TextSize, label.TextWrapped = Color3.new(1, 1, 1), 14, true
    label.Parent = sign
    return setmetatable({model = model, root = root, humanoid = humanoid, label = label, scope = scope,
        metrics = {computes = 0, failures = 0, timeouts = 0, arrivals = 0, computeSeconds = 0}}, Mover)
end

function Mover:stop()
    self.destination = nil
    if self.root.Parent then self.humanoid:MoveTo(self.root.Position) end
end

function Mover:near(position, radius)
    local delta = self.root.Position - position
    return Vector2.new(delta.X, delta.Z).Magnitude <= radius and math.abs(delta.Y) < 5
end

function Mover:waitRunning()
    local paused = false
    while self.scope.alive and not self.scope.running do
        paused = true
        if self.root.Parent then self.humanoid:MoveTo(self.root.Position) end
        task.wait(0.1)
    end
    if paused and self.scope.alive and self.root.Parent and self.destination then self.humanoid:MoveTo(self.destination) end
    return self.scope.alive
end

function Mover:move(position, deadline, cancelled)
    local function valid()
        return self:waitRunning() and self.root.Parent ~= nil and self.humanoid.Health > 0
            and self.scope:now() < deadline and not cancelled()
    end
    for _ = 1, 2 do
        if not valid() then self:stop(); return false end
        if self:near(position, 2.5) then self:stop(); return true end
        -- Never queue an unbounded number of ComputeAsync jobs if the engine stalls.
        if self.computing then self:stop(); return false end
        -- Mansion ramps are continuous: jumping can pick rail tops as shortcut waypoints.
        local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 6, AgentCanJump = false})
        local done, computed = false, false
        self.metrics.computes += 1
        local computeStarted = os.clock()
        self.computing = true
        local abandoned = false
        task.spawn(function()
            computed = pcall(function() path:ComputeAsync(self.root.Position, position) end)
            self.metrics.computeSeconds += os.clock() - computeStarted
            self.computing, done = false, true
            if abandoned then path:Destroy() end
        end)
        local computeDeadline = math.min(deadline, self.scope:now() + 3)
        while not done and valid() and self.scope:now() < computeDeadline do task.wait(0.1) end
        if not done then self.metrics.timeouts += 1; abandoned = true; self:stop(); return false end
        if computed and path.Status == Enum.PathStatus.Success and valid() then
            local blocked, current = false, 1
            local connection = path.Blocked:Connect(function(index)
                if index >= current then blocked = true end
            end)
            local arrived = true
            for index, waypoint in ipairs(path:GetWaypoints()) do
                current = index
                if not valid() or blocked then arrived = false; break end
                if waypoint.Action == Enum.PathWaypointAction.Jump then self.humanoid.Jump = true end
                self.destination = waypoint.Position
                self.humanoid:MoveTo(waypoint.Position)
                local waypointDeadline = math.min(deadline, self.scope:now() + 3)
                while valid() and not blocked and not self:near(waypoint.Position, 2)
                    and self.scope:now() < waypointDeadline do task.wait(0.1) end
                if not valid() or blocked or not self:near(waypoint.Position, 2.5) then arrived = false; break end
            end
            connection:Disconnect()
            path:Destroy()
            if arrived and self:near(position, 3) then self.metrics.arrivals += 1; self:stop(); return true end
        else
            path:Destroy()
        end
        self:stop()
        task.wait(0.25)
    end
    self:stop()
    self.metrics.failures += 1
    return false
end

return Mover
