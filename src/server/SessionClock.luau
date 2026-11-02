-- Round-local game time: Council pauses deadlines and invalidation cancels all callbacks.
local Clock = {}
Clock.__index = Clock
function Clock.new()
    return setmetatable({time = 0, alive = true, running = true, pending = {}}, Clock)
end
function Clock:now() return self.time end
function Clock:delay(seconds, callback)
    if self.alive then table.insert(self.pending, {at = self.time + seconds, run = callback}) end
end
function Clock:advance(dt)
    if not self.alive or not self.running then return end
    self.time += dt
    local due, pending = {}, {}
    for _, item in ipairs(self.pending) do
        table.insert(if item.at <= self.time then due else pending, item)
    end
    self.pending = pending
    for _, item in ipairs(due) do if self.alive then item.run() end end
end
function Clock:destroy() self.alive, self.running, self.pending = false, false, {} end
return Clock
