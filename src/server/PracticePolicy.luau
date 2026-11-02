-- Waiting practice never awards event points or emits progression rewards.
local Practice = {}
Practice.__index = Practice
function Practice.new(config) return setmetatable({config = config, records = {}}, Practice) end
function Practice:get(id, now)
    local r = self.records[id]
    if not r or now >= r.endsAt then
        r = {step = 1, endsAt = now + self.config.PRACTICE_SECONDS}
        self.records[id] = r
    end
    return r
end
function Practice:activity(id, key, now)
    local r = self:get(id, now)
    local expected = {"Painting", "Refreshment", "Noise"}
    if expected[r.step] ~= key then return false end
    r.step += 1
    if r.step == 4 then r.endsAt = now + self.config.PRACTICE_RESTART_SECONDS end
    return true
end
function Practice:clear() self.records = {} end
return Practice
