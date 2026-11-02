-- Pure state machine. Only this object can finish a round or resolve a ballot.
local Round = {}
Round.__index = Round
function Round.new(config)
    return setmetatable({config = config, phase = "Waiting", roundId = 0, remaining = 0,
        elapsed = 0, participants = {}, votes = {}, cast = {}, councilUsed = false}, Round)
end
function Round:countdown()
    if self.phase ~= "Waiting" and self.phase ~= "Results" then return false end
    self.roundId += 1
    self.phase, self.remaining = "Countdown", self.config.COUNTDOWN_SECONDS
    self.elapsed, self.councilUsed, self.result = 0, false, nil
    self.participants, self.votes, self.cast, self.detained = {}, {}, {}, nil
    return true
end
function Round:activate(ids, spy)
    local spies = if type(spy) == "table" then spy else {spy}
    if self.phase ~= "Countdown" or #ids < 3 or #ids > 15 or #spies < 1 or #spies > 2 then return false end
    local team = {}
    for _, id in ipairs(spies) do
        if not table.find(ids, id) or team[id] then return false end
        team[id] = true
    end
    self.participants = {}
    for _, id in ipairs(ids) do self.participants[id] = true end
    self.spy, self.spies = spies[1], team -- scalar retained for M0–M4 fixtures
    self.phase, self.remaining = "Active", self.config.ROUND_SECONDS
    return true
end
function Round:finish(winner, reason)
    if self.phase ~= "Active" and self.phase ~= "Council" then return false end
    self.result = {winner = winner, reason = reason, roundId = self.roundId}
    self.phase, self.remaining = "Results", self.config.RESULT_RESET_SECONDS
    return true
end
function Round:extract(id)
    if self.phase ~= "Active" or not self.spies[id] or not self.participants[id] then return false end
    return self:finish("Spy", "Extraction")
end
function Round:council(id)
    if self.phase ~= "Active" or not self.participants[id] or self.councilUsed
        or self.elapsed < self.config.COUNCIL_DELAY then return false end
    self.councilUsed, self.savedRemaining, self.votes, self.cast = true, self.remaining, {}, {}
    self.phase, self.remaining = "Council", self.config.COUNCIL_SECONDS
    return true
end
function Round:vote(id, target, roundId)
    if self.phase ~= "Council" or roundId ~= self.roundId or not self.participants[id]
        or not self.participants[target] or target == id or self.cast[id] then return false end
    self.votes[id] = target
    self.cast[id] = true
    return true
end
function Round:majority()
    local count, totals = 0, {}
    for _ in pairs(self.participants) do count += 1 end
    for id, target in pairs(self.votes) do
        if self.participants[id] and self.participants[target] then totals[target] = (totals[target] or 0) + 1 end
    end
    for target, votes in pairs(totals) do
        if votes > count / 2 then return target end
    end
    return nil
end
function Round:leave(id)
    if not self.participants[id] then return false end
    self.participants[id], self.votes[id] = nil, nil
    for voter, target in pairs(self.votes) do if target == id then self.votes[voter] = nil end end
    if self.spies[id] then
        for member in pairs(self.spies) do if self.participants[member] then return false end end
        return self:finish("Defenders", "SpyLeft")
    end
    return false
end
function Round:tick(dt, population)
    if self.phase == "Waiting" then
        if population >= 3 then self:countdown(); return "Countdown" end
        return nil
    end
    if self.phase == "Countdown" and population < 3 then
        self.phase, self.remaining = "Waiting", 0
        return "Waiting"
    end
    self.remaining = math.max(0, self.remaining - dt)
    if self.phase == "Active" then
        self.elapsed += dt
        if self.detained and self.elapsed >= self.detained.untilTime then self.detained = nil end
        if self.remaining == 0 then self:finish("Defenders", "Timeout"); return "Results" end
    elseif self.remaining == 0 then
        if self.phase == "Countdown" then return "Start" end
        if self.phase == "Council" then
            local target = self:majority()
            self.detained = if target then {id = target, untilTime = self.elapsed + self.config.SEARCH_SECONDS} else nil
            self.phase, self.remaining = "Active", self.savedRemaining
            return "Search", target
        end
        if self.phase == "Results" then
            self.phase, self.remaining = "Waiting", 0
            return "Reset"
        end
    end
    return nil
end
return Round
