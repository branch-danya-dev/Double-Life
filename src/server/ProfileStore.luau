-- Pure store coordinator. Every write derives from the latest value inside UpdateAsync.
-- One worker per key; ordered immutable operations survive ambiguous write responses.
local Store = {}
Store.__index = Store
function Store.new(adapter, schema, policy, catalog, options)
    return setmetatable({adapter = adapter, schema = schema, policy = policy, catalog = catalog,
        options = options, entries = {}, uncertain = {}}, Store)
end
function Store:attempt(entry, transform, deadline, current)
    local reason = "Unavailable"
    for attempt = 1, 3 do
        if current and not current() then return nil, "Cancelled" end
        if deadline and self.options.now() >= deadline then return nil, "Unavailable" end
        local callbackReason
        local ok, result = pcall(function()
            return self.adapter:update("User_" .. entry.id, function(raw)
                if current and not current() then callbackReason = "Cancelled"; return nil end
                local value, why = transform(raw)
                callbackReason = why
                return value
            end)
        end)
        if ok then return result, callbackReason end
        if attempt < 3 then
            local delay = 2 ^ (attempt - 1) + self.options.jitter()
            if deadline and self.options.now() + delay >= deadline then break end
            self.options.wait(delay)
        end
    end
    return nil, reason
end
function Store:load(id, token, deadline, current)
    if current and not current() then return nil, "Cancelled" end
    local previous = self.entries[id]
    if previous and previous.busy then return nil, "Recovering" end
    if previous and previous.status ~= "Closed" then
        if previous.closing then
            local ok, why = self:close(id, deadline or self.options.now() + 20, previous.token)
            if not ok then
                if why ~= "LostLease" then return nil, why end
                -- Fenced operations must NEVER migrate to the new lease. Keep them until
                -- the next authoritative read can identify commits, then report any unknowns.
                self.uncertain[id] = {token = previous.token, operations = self.schema.copy(previous.queue),
                    count = previous.unconfirmed or 0}
                previous.status = "Closed"
            end
        elseif previous.token ~= token then return nil, "Locked"
        elseif previous.loaded then return previous end
    end
    if current and not current() then return nil, "Cancelled" end
    local entry = if previous and previous.token == token and not previous.loaded and previous.status ~= "Closed"
        then previous else {id = id, token = token, queue = {}, nextSeq = 0, unconfirmed = previous and previous.unconfirmed or 0}
    entry.status, entry.busy = "Loading", true
    self.entries[id] = entry
    local unknown = entry.unconfirmed or 0
    local result, reason = self:attempt(entry, function(raw)
        local p, why = self.schema.normalize(raw, self.catalog)
        if not p then return nil, why end
        local now = self.options.now()
        if p.lease.owner ~= token and p.lease.expires > now then return nil, "Locked" end
        local pending = self.uncertain[id]
        if pending then
            unknown = pending.count
            for _, op in ipairs(pending.operations) do
                local confirmed = p.lease.owner == pending.token and p.sessionSeq >= op.seq
                for _, receipt in ipairs(p.receipts) do if receipt.id == op.id then confirmed = true end end
                if not confirmed then unknown += 1 end
            end
        end
        if p.lease.owner ~= token then p.sessionSeq = 0 end
        p.lease = {owner = token, expires = now + self.options.leaseSeconds}
        p.revision += 1
        self.policy.unlock(p, self.catalog)
        return p
    end, deadline, current)
    entry.busy = false
    if result then
        entry.profile, entry.status, entry.loaded = result, "Ready", true
        entry.nextSeq = result.sessionSeq
        entry.unconfirmed, self.uncertain[id] = unknown, nil
    else entry.status = reason or "Unavailable" end
    return entry
end
function Store:enqueue(id, operation, token)
    local e = self.entries[id]
    if token and (not e or e.token ~= token) then return false, "StaleConnection" end
    if not e or e.status ~= "Ready" or e.closing or e.profile.lease.expires <= self.options.now() then return false, "Unavailable" end
    if #e.queue >= 16 then return false, "Busy" end
    if type(operation.id) ~= "string" or #operation.id > 180 then return false, "InvalidOperation" end
    for _, queued in ipairs(e.queue) do if queued.id == operation.id then return true, "Queued" end end
    for _, receipt in ipairs(e.profile.receipts) do if receipt.id == operation.id then return true, receipt.reason end end
    e.nextSeq += 1
    local copy = self.schema.copy(operation)
    copy.seq = e.nextSeq
    table.insert(e.queue, copy)
    return true, "Queued"
end
function Store:flush(id, release, deadline, token)
    local e = self.entries[id]
    if token and (not e or e.token ~= token) then return false, "StaleConnection" end
    if not e or not e.loaded or e.status == "Closed" or e.status == "LostLease" or e.status == "Malformed" then return false, e and e.status end
    if e.closing and not release then return false, "Closing" end
    if e.busy then return false, "Busy" end
    e.busy = true
    local batch = self.schema.copy(e.queue)
    local result, reason = self:attempt(e, function(raw)
        -- A deleted key while holding a lease is a conflict, never permission to recreate defaults.
        if raw == nil then return nil, "LostLease" end
        local p, why = self.schema.normalize(raw, self.catalog)
        if not p then return nil, why end
        local now = self.options.now()
        if p.lease.owner ~= e.token then return nil, "LostLease" end
        local lastSeq = if #batch > 0 then batch[#batch].seq else e.profile.sessionSeq
        if release and p.lease.expires == 0 and p.sessionSeq >= lastSeq then return p end -- release response was lost
        if p.lease.expires <= now then return nil, "LostLease" end
        for _, op in ipairs(batch) do
            if op.seq > p.sessionSeq then
                if op.seq ~= p.sessionSeq + 1 then return nil, "SequenceConflict" end
                local ok, whyOp = self.policy.apply(p, op, self.catalog)
                table.insert(p.receipts, {id = op.id, ok = ok, reason = whyOp})
                while #p.receipts > 64 do table.remove(p.receipts, 1) end
                p.sessionSeq = op.seq
            end
        end
        p.lease.expires = if release then 0 else now + self.options.leaseSeconds
        p.revision += 1
        return p
    end, deadline)
    e.busy = false
    if result then
        for _ = 1, #batch do table.remove(e.queue, 1) end
        e.profile, e.status = result, if release then "Closed" else "Ready"
        return true
    end
    e.status = reason or "Unavailable"
    return false, e.status
end
function Store:close(id, deadline, token)
    local e = self.entries[id]
    if token and (not e or e.token ~= token) then return false, "StaleConnection" end
    if not e or e.status == "Closed" then return true end
    e.closing = true
    while e.busy and self.options.now() < deadline do self.options.wait(0.05) end
    if e.busy then return false, "Deadline" end
    if self.entries[id] ~= e then return false, "StaleConnection" end
    if e.status == "Closed" then return true end
    if not e.loaded then
        -- An acquisition can commit before its response is lost. Release only our own
        -- token; never create a key or write a default after a failed load.
        e.busy = true
        local result, why = self:attempt(e, function(raw)
            if raw == nil then return nil, "NoLease" end
            local p, invalid = self.schema.normalize(raw, self.catalog)
            if not p then return nil, invalid end
            if p.lease.owner ~= e.token then return nil, "NoLease" end
            p.lease.expires = 0
            return p
        end, deadline)
        e.busy = false
        if result or why == "NoLease" or why == "Malformed" or why == "UnsupportedVersion" then e.status = "Closed"; return true end
        e.status = why or "Unavailable"
        return false, e.status
    end
    return self:flush(id, true, deadline, e.token)
end
return Store
