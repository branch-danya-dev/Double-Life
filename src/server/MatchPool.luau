-- Entire bounded pool is one atomic MemoryStore value: no multi-key partial claim.
-- No yields/randomness/side effects inside UpdateAsync's retryable transform.
local Pool = {}
function Pool.empty() return {tickets = {}, matches = {}} end
function Pool.prune(s, now)
    for id, t in pairs(s.tickets) do if t.expires <= now then s.tickets[id] = nil end end
    for id, m in pairs(s.matches) do
        local valid = m.expires > now
        for _, uid in ipairs(m.ids) do
            local t = s.tickets[tostring(uid)]
            if not t or t.match ~= id then valid = false end
        end
        if not valid then
            for _, uid in ipairs(m.ids) do
                local t = s.tickets[tostring(uid)]
                if t and t.match == id then t.match, t.arrived = nil, nil end
            end
            s.matches[id] = nil
        end
    end
end
function Pool.register(s, id, server, token, now, settings)
    if type(id)~="number" or id%1~=0 or id<=0 or type(server)~="string" or #server<1 or #server>100
        or type(token)~="string" or #token<1 or #token>100 then return false end
    local key = tostring(id)
    local old = s.tickets[key]
    if old and (old.server ~= server or old.token ~= token) then return false end
    if not old then
        local count = 0; for _ in pairs(s.tickets) do count += 1 end
        if count >= settings.poolLimit then return false end
        old = {id=id,server=server,token=token,joined=now}
        s.tickets[key] = old
    end
    old.expires = now + settings.ticketLease
    return true
end
function Pool.cancel(s, id, server, token, now)
    local t = s.tickets[tostring(id)]
    if not t or t.server ~= server or t.token ~= token then return false end
    s.tickets[tostring(id)] = nil
    Pool.prune(s, now)
    return true
end
function Pool.match(s, matchId, now, settings)
    local list = {}
    for _, t in pairs(s.tickets) do if not t.match and t.expires > now then table.insert(list,t) end end
    table.sort(list,function(a,b) return a.joined < b.joined or (a.joined == b.joined and a.id < b.id) end)
    if #list < 2 or s.matches[matchId] then return nil end
    local m = {id=matchId, target=list[1].server, ids={}, expires=now+settings.assignmentLease}
    for i=1,math.min(15,#list) do
        local t=list[i]; table.insert(m.ids,t.id)
        t.match, t.expires, t.arrived = matchId, m.expires, t.server == m.target
    end
    s.matches[matchId]=m
    return m
end
function Pool.arrive(s, id, token, matchId, destination, now)
    local t, m = s.tickets[tostring(id)], s.matches[matchId]
    if not t or not m or t.token ~= token or t.match ~= matchId or m.target ~= destination or m.expires <= now then return false end
    t.server, t.arrived = destination, true
    return true
end
function Pool.ready(s, matchId, server, present, now)
    local m=s.matches[matchId]
    if not m or m.target ~= server or m.expires <= now then return false end
    for _, id in ipairs(m.ids) do
        local t=s.tickets[tostring(id)]
        if not t or not t.arrived or not present[id] then return false end
    end
    return true
end
function Pool.consume(s, matchId, server, present, now)
    if not Pool.ready(s,matchId,server,present,now) or s.matches[matchId].committed then return false end
    -- Retain the consumed reservation until TTL, preventing stale renewals from
    -- recreating tickets during the countdown-to-start boundary.
    s.matches[matchId].committed = true
    return true
end
return Pool
