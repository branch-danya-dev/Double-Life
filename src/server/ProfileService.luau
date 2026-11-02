local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local Catalog = require(script.Parent.ProgressionCatalog)
local Schema = require(script.Parent.ProfileSchema)
local Policy = require(script.Parent.ProgressionPolicy)
local Store = require(script.Parent.ProfileStore)
local Sessions = require(script.Parent.ProfileSessions)
local Settings = require(script.Parent.PersistenceSettings)
local Adapter = require(script.Parent.DataStoreAdapter)
local Service = {}
Service.__index = Service
function Service.new(runtime, tell, options)
    options = options or {}
    assert(not options.adapter or game:GetService("RunService"):IsStudio(), "Injected storage is Studio-only")
    local self = setmetatable({runtime = runtime, tell = tell, catalog = Catalog, connections = {}, rewards = {},
        requests = {}, round = {}, serverId = Http:GenerateGUID(false), nextSave = {}, sampleTime = 0}, Service)
    self.adapter = options.adapter or Adapter.new(Settings)
    self.store = Store.new(self.adapter, Schema, Policy, Catalog, {now = os.time, wait = task.wait,
        jitter = function() return math.random() * 0.3 end, leaseSeconds = Settings.leaseSeconds})
    self.sessions = Sessions.new(self.store, {now = os.clock, wait = task.wait, spawn = task.spawn,
        jitter = function() return math.random() * 0.3 end,
        recoverySeconds = if self.adapter.mode == "DisabledStudio" then 0 else Settings.recoverySeconds,
        warn = function(why, pending) warn("M4.1 profile close unconfirmed", why, pending) end,
        changed = function(c)
            if self.connections[c.owner] ~= c.token then return end
            local message
            if c.status == "Ready" and not c.retrying then
                self.nextSave[c.id] = os.clock() + Settings.autosaveSeconds + math.random() * 10
                message = "Профиль загружен. P — профиль и снаряжение в ожидании/итогах."
            elseif c.retrying then message = "Сохранение временно недоступно. Восстанавливаем профиль автоматически; можно продолжать игру."
            else message = "Профиль не восстановлен. Награды и покупки отключены; автоматические попытки завершены. Повторите вход позже." end
            if c.notified ~= message then c.notified = message; self.tell(c.owner, message) end
        end})
    runtime.taskCompleted.Event:Connect(function(payload) self:action(payload, payload.kind) end)
    runtime.eventSignals.EventParticipated.Event:Connect(function(payload) self:action(payload, payload.kind) end)
    runtime.eventSignals.EventFinished.Event:Connect(function(payload)
        if not payload.cancelled then
            for id in pairs(payload.awards) do self:action({roundId = payload.roundId, userId = id}, payload.kind) end
        end
    end)
    runtime.eventSignals.GuestIncidentTriggered.Event:Connect(function(payload) self:action(payload, "Incident") end)
    runtime.roundFinished.Event:Connect(function(payload) self:finish(payload) end)
    game:BindToClose(function() self:shutdown() end)
    return self
end
function Service:entry(player)
    local e = self.store.entries[player.UserId]
    local token = self.connections[player]
    return if e and e.token == token and self.sessions:isCurrent(player.UserId, token) then e else nil
end
function Service:add(player)
    if self.sessions.stopping then return end
    local token = self.serverId .. ":" .. Http:GenerateGUID(false)
    self.connections[player] = token
    self.requests[player.UserId], self.rewards[player.UserId] = nil, nil
    self.sessions:start(player.UserId, token, player)
end
function Service:beginRound(roundId)
    self.roundId, self.round = roundId, {}
    for _, player in ipairs(Players:GetPlayers()) do
        local e, role = self:entry(player), self.runtime.roles:get(player)
        local ready = e and e.status == "Ready" and e.profile.lease.expires > os.time()
        local record = Policy.round(role, if ready then e.token else nil)
        record.tool = if ready then e.profile.equipped[role] else Catalog.defaults[role]
        self.round[player.UserId] = record
    end
end
function Service:tool(player, role)
    local record = self.round[player.UserId]
    local id = if record and record.role == role then record.tool else Catalog.defaults[role]
    return Catalog.items[id], id
end
function Service:action(payload, kind)
    if self.sessions.stopping then return end
    local phase = self.runtime.rounds.policy.phase
    if payload.roundId ~= self.roundId or (phase ~= "Active" and not (phase == "Council" and (kind == "Council" or kind == "Vote"))) then return end
    local record = self.round[payload.userId]
    if record and self.runtime.rounds.policy.participants[payload.userId] then Policy.action(record, kind) end
end
function Service:pump(id, token)
    local e = self.store.entries[id]
    token = token or (e and e.token)
    if not e or e.token ~= token or e.busy or e.closing or not self.sessions:isCurrent(id, token) then return end
    task.spawn(function()
        if not self.sessions:isCurrent(id, token) then return end
        self.store:flush(id, false, nil, token)
        -- New requests may have arrived while UpdateAsync yielded. Preserve their order.
        if e.status == "Ready" and #e.queue > 0 and not e.closing then self:pump(id, token) end
    end)
end
function Service:finish(payload)
    if self.sessions.stopping then return end
    if payload.roundId ~= self.roundId then return end
    for id, record in pairs(self.round) do
        if not record.finished then
            local award, reason = Policy.reward(record, payload.winner, Catalog.rules)
            local player = Players:GetPlayerByUserId(id)
            local e = player and self:entry(player)
            local result = {roundId = payload.roundId, reason = reason or "Unavailable"}
            self.rewards[id] = result
            if award and e and e.status == "Ready" and e.token == record.connection and not record.left then
                local key = self.serverId .. ":round:" .. payload.roundId .. ":" .. id
                local accepted = self.store:enqueue(id, {id = key, kind = "Award", award = award, at = os.time()}, e.token)
                if accepted then
                    result.id, result.award, result.reason = key, award, "Pending"
                    result.beforeLevel = Policy.level(e.profile.reputationXp, 10, 50)
                    result.beforeMastery = Policy.level(e.profile.roleXp[record.role], 5, 30)
                    result.beforeInventory = Schema.copy(e.profile.inventory)
                    self:pump(id, e.token)
                end
            end
        end
    end
end
function Service:request(player, kind, item, slot)
    local phase = self.runtime.rounds.policy.phase
    if phase ~= "Waiting" and phase ~= "Results" then return false, "PhaseLocked" end
    if (kind ~= "Buy" and kind ~= "Equip") or type(item) ~= "string" or #item > 40
        or (kind == "Equip" and (type(slot) ~= "string" or #slot > 20)) then return false, "InvalidRequest" end
    local e = self:entry(player)
    if not e or e.status ~= "Ready" then return false, "Unavailable" end
    if os.clock() < (e.nextRequest or 0) then return false, "Busy" end
    e.nextRequest = os.clock() + 0.6
    local id = self.serverId .. ":request:" .. Http:GenerateGUID(false)
    local ok, why = self.store:enqueue(player.UserId, {id = id, kind = kind, item = item, slot = slot}, e.token)
    if ok then self.requests[player.UserId] = id; self:pump(player.UserId, e.token) end
    return ok, why
end
function Service:remove(player)
    local token = self.connections[player]
    local record = self.round[player.UserId]
    if record and self.sessions:isCurrent(player.UserId, token) then record.left = true end
    self.connections[player] = nil
    self.sessions:stop(player.UserId, token)
end
function Service:shutdown()
    return self.sessions:shutdown(25)
end
function Service:tick(dt)
    self.sampleTime += dt
    if self.sampleTime < 0.5 then return end
    local seconds = math.min(self.sampleTime, 1)
    self.sampleTime = 0
    local round = self.runtime.rounds.policy
    for _, player in ipairs(Players:GetPlayers()) do
        local record = self.round[player.UserId]
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if record and not record.left and not record.finished and round.phase == "Active" and round.participants[player.UserId]
            and root and humanoid and humanoid.Health > 0 then
            record.active += seconds
            if record.position then
                local distance = (root.Position - record.position).Magnitude
                if distance > 0.5 and distance <= seconds * 24 then record.moving += seconds end
            end
            record.position = root.Position
        elseif record then record.position = nil end
        local e = self:entry(player)
        if e and e.loaded and not e.closing and os.clock() >= (self.nextSave[player.UserId] or math.huge) then
            self.nextSave[player.UserId] = os.clock() + Settings.autosaveSeconds + math.random() * 10
            self:pump(player.UserId, e.token)
        end
    end
end
function Service:snapshot(player)
    local e = self:entry(player)
    local data = e and e.profile
    local c = self.sessions.current[player.UserId]
    if c and (c.token ~= self.connections[player] or not self.sessions:isCurrent(player.UserId, c.token)) then c = nil end
    local state = {status = if e then e.status elseif c then c.status else "Unavailable", mode = self.adapter.mode,
        retrying = c and c.retrying or false, unconfirmed = e and e.unconfirmed or 0}
    if state.retrying then state.status = if c.status == "Locked" then "Locked" else "Recovering" end
    if not data then return state end
    if state.status == "Ready" and data.lease.expires <= os.time() then state.status = "LostLease" end
    if not state.retrying and (e.busy or #e.queue > 0) then state.status = if state.status == "Ready" then "Saving" else state.status end
    state.revision, state.reputationXp, state.tokens = data.revision, data.reputationXp, data.tokens
    state.level, state.nextLevelXp = Policy.level(data.reputationXp, 10, 50), nil
    if state.level < 10 then state.nextLevelXp = 50 * state.level * (state.level + 1) / 2 end
    state.roleXp, state.stats, state.history = Schema.copy(data.roleXp), Schema.copy(data.stats), Schema.copy(data.history)
    state.equipped, state.achievements, state.mastery, state.catalog = Schema.copy(data.equipped), Schema.copy(data.achievements), {}, {}
    for _, role in ipairs(Catalog.roles) do state.mastery[role] = Policy.level(data.roleXp[role], 5, 30) end
    for _, id in ipairs(Catalog.order) do
        local item = Catalog.items[id]
        table.insert(state.catalog, {id = id, name = item.name, description = item.description, slot = item.slot,
            price = item.price, level = item.level, owned = data.inventory[id] == true})
    end
    for _, receipt in ipairs(data.receipts) do
        if receipt.id == self.requests[player.UserId] then state.requestResult = receipt.reason end
    end
    local reward = self.rewards[player.UserId]
    if reward and reward.roundId == self.runtime.rounds.policy.roundId then
        state.reward = {reason = reward.reason}
        for _, receipt in ipairs(data.receipts) do
            if receipt.id == reward.id and receipt.ok then
                state.reward = {reason = "Awarded", xp = reward.award.xp, roleXp = reward.award.roleXp, tokens = reward.award.tokens,
                    beforeLevel = reward.beforeLevel, level = state.level, beforeMastery = reward.beforeMastery,
                    mastery = state.mastery[reward.award.role], unlocked = {}}
                for id in pairs(data.inventory) do
                    if not reward.beforeInventory[id] then table.insert(state.reward.unlocked, Catalog.items[id].name) end
                end
            end
        end
    end
    return state
end
return Service
