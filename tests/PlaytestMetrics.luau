-- Bounded local diagnostics, never shipped or sent to analytics.
local Metrics = {}
Metrics.__index = Metrics
function Metrics.new(capacity)
    assert(type(capacity) == "number" and capacity >= 1 and capacity <= 3600 and capacity % 1 == 0)
    return setmetatable({capacity = capacity, values = {}, cursor = 1}, Metrics)
end
function Metrics:add(dt)
    if type(dt) ~= "number" or dt ~= dt or dt <= 0 or dt == math.huge then return false end
    self.values[self.cursor] = dt * 1000
    self.cursor = self.cursor % self.capacity + 1
    return true
end
function Metrics:summary()
    local values = table.clone(self.values)
    local n = #values
    if n == 0 then return {samples = 0} end
    table.sort(values)
    local sum, slow = 0, 0
    for _, ms in ipairs(values) do sum += ms; if ms > 50 then slow += 1 end end
    return {samples = n, seconds = sum / 1000, meanFps = 1000 * n / sum,
        p50Ms = values[math.ceil(n * 0.5)], p95Ms = values[math.ceil(n * 0.95)],
        p99Ms = values[math.ceil(n * 0.99)], maxMs = values[n], over50Ms = slow}
end
return Metrics
