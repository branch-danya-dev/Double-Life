-- Pure event/incident rules. All timestamps come from the cancellable SessionClock.
local Policy = {}
Policy.__index = Policy
function Policy.new(config)
    return setmetatable({config = config, phase = "Idle", serial = 0, used = 0, readyAt = 0,
        scores = {}, participants = {}, trials = {}, guestActions = {}, incidentUsed = false}, Policy)
end
function Policy:reason(role, allowed, now)
    if not allowed then return "Мероприятия доступны только участникам активного раунда." end
    if role ~= "Owner" then return "Мероприятие выбирает владелец." end
    if self.used >= self.config.EVENT_LIMIT then return "Лимит: два мероприятия за раунд." end
    if self.phase ~= "Idle" then return "Дождитесь завершения события и перерыва." end
    if now < self.readyAt then return "Перерыв между мероприятиями ещё не закончился." end
    return nil
end
function Policy:start(role, allowed, kind, now)
    local reason = self:reason(role, allowed, now)
    if reason then return false, reason end
    if kind ~= "Relic" and kind ~= "Music" then return false, "Неизвестное мероприятие." end
    self.serial += 1
    self.used += 1
    self.kind, self.phase, self.endsAt = kind, "Announcing", now + self.config.EVENT_ANNOUNCE_SECONDS
    self.participants, self.trials, self.awards, self.carrier = {}, {}, {}, nil
    self.delivered, self.cancelled = false, false
    return true
end
function Policy:finish(now, cancelled)
    if self.phase ~= "Running" and self.phase ~= "Announcing" then return false end
    self.phase, self.cancelled, self.carrier = "Finished", cancelled == true, nil
    self.endsAt, self.readyAt = now + self.config.EVENT_RESULT_SECONDS, now + self.config.EVENT_COOLDOWN
    if not cancelled then
        for id, entry in pairs(self.participants) do
            local points = if self.kind == "Relic" then (if entry.delivered then 15 else 3) else 2 + entry.passes * 3
            self.awards[id] = points
            self.scores[id] = (self.scores[id] or 0) + points
        end
    end
    return true
end
function Policy:pickup(id, allowed)
    if not allowed or self.phase ~= "Running" or self.kind ~= "Relic" or self.carrier then return false end
    self.carrier = id
    local first = self.participants[id] == nil
    self.participants[id] = self.participants[id] or {}
    return true, first
end
function Policy:drop(id)
    if self.carrier ~= id then return false end
    self.carrier = nil
    return true
end
function Policy:deliver(id, allowed, now)
    if not allowed or self.phase ~= "Running" or self.kind ~= "Relic" or self.carrier ~= id then return false end
    self.participants[id].delivered, self.delivered = true, true
    return self:finish(now, false)
end
function Policy:sample(id, x, z, inside, now)
    if self.phase ~= "Running" or self.kind ~= "Music" then return false end
    if not inside then self.trials[id] = nil; return false end
    local trial = self.trials[id]
    if not trial then
        trial = {x = x, z = z, distance = 0, moved = false, failed = self.beat == "Freeze"}
        self.trials[id] = trial
    end
    local distance = math.sqrt((x - trial.x)^2 + (z - trial.z)^2)
    local first = false
    if self.beat == "Move" then
        -- Implausible jumps do not count as dancing. Movement is sampled by the server.
        if distance < 4 then trial.distance += distance end
        trial.x, trial.z = x, z
        if trial.distance >= 1.5 then
            trial.moved = true
            first = self.participants[id] == nil
            self.participants[id] = self.participants[id] or {passes = 0}
        end
    elseif now - self.beatStarted <= 0.45 then
        trial.x, trial.z = x, z -- Small stopping grace for normal replication latency.
    elseif distance > 0.7 then trial.failed = true end
    return first
end
function Policy:advance(now)
    if self.phase == "Announcing" and now >= self.endsAt then
        self.phase = "Running"
        self.endsAt = now + (if self.kind == "Relic" then self.config.RELIC_SECONDS else self.config.MUSIC_MOVE_SECONDS)
        self.beat, self.beatIndex, self.beatStarted = "Move", 1, now
        return "Running"
    elseif self.phase == "Running" and now >= self.endsAt then
        if self.kind == "Relic" then self:finish(now, false); return "Finished" end
        if self.beat == "Move" then
            self.beat, self.beatStarted, self.endsAt = "Freeze", now, now + self.config.MUSIC_FREEZE_SECONDS
        else
            for id, trial in pairs(self.trials) do
                if trial.moved and not trial.failed and self.participants[id] then self.participants[id].passes += 1 end
            end
            self.trials = {}
            if self.beatIndex >= self.config.MUSIC_ROUNDS then self:finish(now, false); return "Finished" end
            self.beatIndex += 1
            self.beat, self.beatStarted, self.endsAt = "Move", now, now + self.config.MUSIC_MOVE_SECONDS
        end
        return "Beat"
    elseif self.phase == "Finished" and now >= self.endsAt then self.phase = "Cooldown"
    elseif self.phase == "Cooldown" and now >= self.readyAt then self.phase = "Idle" end
    return nil
end
function Policy:neutral(id, role, allowed, key, now, choose)
    if not allowed or role ~= "Guest" or self.incidentUsed then return false end
    local actions = self.guestActions[id] or {}
    self.guestActions[id] = actions
    actions[key] = true
    local count = 0
    for _ in pairs(actions) do count += 1 end
    if count < self.config.GUEST_ACTIONS then return false end
    self.incidentUsed = true
    self.pendingIncident = {kind = if choose(1, 2) == 1 then "Inspection" else "Blackout",
        due = now + choose(self.config.INCIDENT_DELAY_MIN, self.config.INCIDENT_DELAY_MAX), source = id}
    return true
end
function Policy:advanceIncident(now)
    if self.pendingIncident and now >= self.pendingIncident.due then
        self.incident, self.pendingIncident = self.pendingIncident, nil
        self.incident.endsAt = now + self.config.INCIDENT_SECONDS
        return "Started"
    elseif self.incident and now >= self.incident.endsAt then
        self.incident = nil
        return "Finished"
    end
    return nil
end
function Policy:remove(id)
    self:drop(id)
    self.trials[id], self.participants[id], self.guestActions[id] = nil, nil, nil
end
return Policy
