local Policy = require(script.Parent.GuardPolicy)
local Mover = require(script.Parent.NpcMover)
local Guard = {}
Guard.__index = Guard

function Guard.start(world, config, scope)
    local navigationConfig = table.clone(config)
    navigationConfig.INVESTIGATE_SECONDS = world.navigation.investigateSeconds
    navigationConfig.RETURN_SECONDS = world.navigation.returnSeconds
    local self = setmetatable({scope = scope, policy = Policy.new(navigationConfig), routes = {
        Corridor = world:points("Patrol.Corridor"), Foyer = world:points("Patrol.Foyer"),
    }}, Guard)
    self.mover = Mover.new(world.npcs, "Guard", world:point("Guard.Spawn"), Color3.fromRGB(48, 68, 105), scope)
    self.lastSafe = self.mover.root.Position
    self.worker = task.spawn(function()
        local index = 1
        while scope.alive and self.mover.model.Parent do
            if not self.mover:waitRunning() then break end
            self.lastTick = scope:now()
            local ok, err = pcall(function()
                local policy = self.policy
                local revision = policy.revision
                local function cancelled() return not scope.alive or revision ~= policy.revision end
                self.mover.model:SetAttribute("State", policy.state) -- NPC state only, no player identity.
                self.mover.model:SetAttribute("PatrolZone", policy.zone)
                if policy.state == "Investigate" then
                    self.mover.label.Text = "Охрана · проверяет место"
                    self.mover:move(policy.target, policy.deadline, cancelled)
                    while not cancelled() and scope:now() < policy.deadline do task.wait(0.2) end
                    if cancelled() then return end
                    policy:beginReturn(scope:now())
                elseif policy.state == "Return" then
                    self.mover.label.Text = "Охрана · возвращается"
                    local route = self.routes[policy.zone]
                    -- Pick the nearest reachable route point, not the safe or a doorway.
                    local choices = table.clone(route)
                    table.sort(choices, function(a, b)
                        return (a - self.mover.root.Position).Magnitude < (b - self.mover.root.Position).Magnitude
                    end)
                    local arrived = false
                    for _, point in ipairs(choices) do
                        if self.mover:move(point, policy.deadline, cancelled) then
                            self.lastSafe, arrived = point, true
                            break
                        end
                    end
                    if not arrived then self.mover:move(self.lastSafe, scope:now() + 4, cancelled) end
                    if not cancelled() then policy:resume(scope:now()) end
                else
                    self.mover.label.Text = "Охрана · патруль"
                    local route = self.routes[policy.zone]
                    local point = route[index]
                    if self.mover:move(point, scope:now() + world.navigation.patrolSeconds, cancelled) then self.lastSafe = point end
                    index = index % #route + 1
                    task.wait(0.5)
                end
            end)
            if not ok then
                warn("Guard recovery:", err)
                self.mover:stop()
                self.policy:beginReturn(scope:now())
                task.wait(1)
            end
        end
    end)
    return self
end

function Guard:react(source, position)
    return self.policy:investigate(source, position, self.scope:now(), false)
end

function Guard:command(kind, value)
    return self.policy:command(kind, value, self.scope:now())
end

return Guard
