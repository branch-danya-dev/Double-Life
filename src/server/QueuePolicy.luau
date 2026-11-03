-- Real-user queue only. Mimics never satisfy readiness or occupy a ticket.
local Queue = {}
Queue.__index = Queue
function Queue.new(settings, now)
    return setmetatable({settings = settings, now = now, entries = {}, serial = 0, selected = nil}, Queue)
end
function Queue:register(id, consent)
    if type(id) ~= "number" or id % 1 ~= 0 then return false end
    if self.entries[id] then return false end
    self.serial += 1
    self.entries[id] = {id = id, serial = self.serial, joined = self.now(), state = "Queued", consent = consent ~= false}
    return true
end
function Queue:cancel(id)
    local r = self.entries[id]
    if not r or r.state == "Active" then return false end
    self.entries[id] = nil
    return true
end
function Queue:leave(id) self.entries[id] = nil end
function Queue:consent(id, accepted)
    local r = self.entries[id]
    if not r or r.state == "Active" then return false end
    r.consent = accepted == true
    return true
end
function Queue:ordered()
    local list = {}
    for id, r in pairs(self.entries) do
        if r.state ~= "Active" then
            if self.now() - r.joined >= self.settings.queueSeconds then self.entries[id] = nil
            else table.insert(list, r) end
        end
    end
    table.sort(list, function(a,b) return a.serial < b.serial end)
    return list
end
function Queue:eligible()
    if self.selected then
        local ids = {}
        for _, id in ipairs(self.selected) do
            local r = self.entries[id]
            if r and r.consent then table.insert(ids,id) end
        end
        return ids
    end
    local list, ids = self:ordered(), {}
    if #list < 2 then
        for _, r in ipairs(list) do r.state, r.readyAt = "Queued", nil end
        return ids
    end
    for index, r in ipairs(list) do
        if index <= 15 then
            r.readyAt = r.readyAt or self.now() + self.settings.readySeconds
            r.state = "MatchReady"
            if r.consent and self.now() >= r.readyAt then table.insert(ids,r.id) end
        end
    end
    -- Someone in a prologue may decline; consenting humans can still match.
    return ids
end
function Queue:select(ids) self.selected = table.clone(ids) end
function Queue:start(ids)
    for _, id in ipairs(ids) do if self.entries[id] then self.entries[id].state = "Active" end end
end
function Queue:reset()
    self.selected = nil
    for _, r in pairs(self.entries) do r.state, r.joined, r.readyAt = "Queued", self.now(), nil end
end
function Queue:snapshot(id)
    local r = self.entries[id]
    return {state = if r then r.state else "Lobby", queued = r ~= nil,
        waitingSeconds = if r then math.max(0, self.now() - r.joined) else 0,
        needsConsent = r ~= nil and not r.consent}
end
return Queue
