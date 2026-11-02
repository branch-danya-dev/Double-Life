local Policy = require(script.Parent.AnalyticsPolicy)
local Service = {}
Service.__index = Service
function Service.new(rt, send)
    local studio = game:GetService("RunService"):IsStudio()
    assert(not send or studio, "Telemetry injection is Studio-only")
    local policy = Policy.new(send or function(player, event, value)
        if not studio then game:GetService("AnalyticsService"):LogCustomEvent(player, "DL_" .. event, value) end
    end, os.clock)
    local self = setmetatable({rt = rt, policy = policy, joined = {}, completed = {}, lastPhase = "", lastRound = 0}, Service)
    rt.roundFinished.Event:Connect(function(payload)
        for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
            if rt.rounds.policy.participants[player.UserId] then
                local record = rt.profiles.round[player.UserId]
                local played = self.completed[player] or (record and record.startPlayed) or 0
                self:emit(player, if played == 0 then "FirstMatch" else "RepeatMatch")
                self.completed[player] = played + 1
                self:emit(player, if (rt.roles:get(player) == "Spy") == (payload.winner == "Spy") then "Win" else "Loss")
            end
        end
    end)
    return self
end
function Service:emit(player, event, value) return self.policy:emit(player, event, value) end
function Service:add(player) self.joined[player] = os.clock(); self:emit(player, "Join") end
function Service:remove(player)
    self:emit(player, "SessionSeconds", math.min(86400, os.clock() - (self.joined[player] or os.clock())))
    self.joined[player], self.completed[player], self.policy.last[player] = nil, nil, nil
end
function Service:tick()
    local p = self.rt.rounds.policy
    if p.phase == self.lastPhase and p.roundId == self.lastRound then return end
    self.lastPhase, self.lastRound = p.phase, p.roundId
    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        self:emit(player, p.phase)
        if p.phase == "Active" and p.elapsed == 0 and p.participants[player.UserId] then self:emit(player, "MatchStarted") end
    end
end
return Service
