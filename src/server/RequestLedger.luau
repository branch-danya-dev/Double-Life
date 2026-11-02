-- No Roblox dependencies: all request transitions and scoring are server-owned.
local Ledger = {}
Ledger.__index = Ledger

function Ledger.new(config)
    return setmetatable({config = config, requests = {}, cooldowns = {}, scores = {}, serial = 0}, Ledger)
end

function Ledger:create(userId, target, now)
    if self.requests[userId] then return nil, "У вас уже есть активный запрос." end
    if now < (self.cooldowns[userId] or 0) then return nil, "Подождите перед следующим запросом." end
    local count = 0
    for _ in pairs(self.requests) do count += 1 end
    if count >= self.config.REQUEST_LIMIT then return nil, "Обслуживание занято. Попробуйте позже." end
    self.serial += 1
    local request = {id = self.serial, userId = userId, target = target, state = "Queued",
        queuedAt = now, expires = now + self.config.REQUEST_TTL}
    self.requests[userId] = request
    self.cooldowns[userId] = now + self.config.REQUEST_COOLDOWN
    return request
end

function Ledger:active(request, now)
    return self.requests[request.userId] == request and now < request.expires
end

function Ledger:assigned(executor)
    for _, request in pairs(self.requests) do
        if request.executor == executor then return request end
    end
    return nil
end

function Ledger:accept(executor, now, npc)
    if self:assigned(executor) then return nil end
    local oldest
    for _, request in pairs(self.requests) do
        if self:active(request, now) and request.state == "Queued" and request.userId ~= executor
            and (not npc or now - request.queuedAt >= self.config.REQUEST_NPC_DELAY)
            and (not oldest or request.id < oldest.id) then oldest = request end
    end
    if oldest then oldest.executor, oldest.state = executor, "Accepted" end
    return oldest
end

function Ledger:pickup(request, executor, now)
    if not self:active(request, now) or request.executor ~= executor or request.state ~= "Accepted" then return false end
    request.state = "Carrying"
    return true
end

function Ledger:deliver(request, executor, now)
    if not self:active(request, now) or request.executor ~= executor or request.state ~= "Carrying" then return false end
    self.requests[request.userId] = nil
    request.state = "Delivered"
    if executor ~= 0 then self.scores[executor] = (self.scores[executor] or 0) + self.config.REQUEST_POINTS end
    return true
end

function Ledger:release(executor, now)
    local request = self:assigned(executor)
    if request then request.executor, request.state, request.queuedAt = nil, "Queued", now end
end

function Ledger:expire(now)
    local expired = {}
    for id, request in pairs(self.requests) do
        if now >= request.expires then self.requests[id] = nil; table.insert(expired, request) end
    end
    return expired
end

function Ledger:remove(userId, now)
    self.requests[userId], self.cooldowns[userId], self.scores[userId] = nil, nil, nil
    self:release(userId, now)
end

return Ledger
