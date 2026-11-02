-- Pure connection lifecycle. Injected scheduler makes reconnect/cancellation races testable.
local Sessions = {}
Sessions.__index = Sessions
function Sessions.new(store, options)
    return setmetatable({store = store, options = options, current = {}, stopping = false}, Sessions)
end
function Sessions:isCurrent(id, token)
    local c = self.current[id]
    return not self.stopping and c ~= nil and c.token == token and c.active
end
function Sessions:close(id, token)
    local e = self.store.entries[id]
    if not e or e.token ~= token then return end
    e.closing = true -- fence new operations BEFORE scheduling an asynchronous close
    self.options.spawn(function()
        local ok, why = self.store:close(id, self.store.options.now() + 20, token)
        if not ok and why ~= "StaleConnection" then self.options.warn(why, #e.queue) end
    end)
end
function Sessions:stop(id, token)
    local c = self.current[id]
    if c and c.token == token then c.active = false; self.current[id] = nil end
    self:close(id, token)
end
function Sessions:start(id, token, owner)
    if self.stopping then return nil end
    local old = self.current[id]
    if old then self:stop(id, old.token) end
    local c = {id = id, token = token, owner = owner, active = true, status = "Recovering", retrying = true}
    self.current[id] = c
    self.options.spawn(function()
        local deadline, delay = self.options.now() + self.options.recoverySeconds, 1
        local function current() return self:isCurrent(id, token) end
        while current() and self.options.now() < deadline do
            local e, why = self.store:load(id, token, self.store.options.now() + math.min(20, deadline - self.options.now()), current)
            if not current() then self:close(id, token); return end
            c.status = if e then e.status else why or "Unavailable"
            if e and e.status == "Ready" and not e.closing and e.profile.lease.expires > self.store.options.now() then
                c.retrying = false
                self.options.changed(c)
                return
            end
            if c.status == "Malformed" or c.status == "UnsupportedVersion" or c.status == "LostLease" then break end
            self.options.changed(c)
            self.options.wait(math.min(delay + self.options.jitter(), math.max(0, deadline - self.options.now())))
            delay = math.min(10, delay * 2)
        end
        if current() then
            c.retrying = false
            if c.status == "Loading" or c.status == "Recovering" then c.status = "Unavailable" end
            self.options.changed(c)
        end
    end)
    return c
end
function Sessions:shutdown(seconds)
    self.stopping = true
    for _, c in pairs(self.current) do c.active = false end
    local deadline, pending, failed = self.options.now() + seconds, 0, false
    for id, e in pairs(self.store.entries) do
        if e.status ~= "Closed" then
            e.closing = true
            pending += 1
            self.options.spawn(function()
                local ok, why = self.store:close(id, self.store.options.now() + math.max(0, deadline - self.options.now()), e.token)
                if not ok then failed = true; self.options.warn(why, #e.queue) end
                pending -= 1
            end)
        end
    end
    while pending > 0 and self.options.now() < deadline do self.options.wait(0.1) end
    return pending == 0 and not failed
end
return Sessions
