-- Deliberately test-only. Data persists across coordinator reloads, NOT across server processes.
local Memory = {}
function Memory.new(copy)
    local self = {mode = "FakeMemory", data = {}, faults = {}, calls = {}, onUpdate = nil}
    function self:update(key, transform)
        table.insert(self.calls, key)
        if self.onUpdate then self.onUpdate(key) end
        local faults = self.faults[key] or {}
        local fault = table.remove(faults, 1)
        if fault == "before" then error("transient/throttle before commit") end
        local value = transform(copy(self.data[key]))
        if fault == "replay" then value = transform(copy(self.data[key])) end -- callback may run twice
        if value == nil then return nil end
        self.data[key] = copy(value)
        if fault == "after" then error("response lost AFTER atomic commit") end
        return copy(value)
    end
    return self
end
return Memory
