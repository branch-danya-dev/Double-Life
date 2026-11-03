local Config = require("../src/shared/Config")
local Round = require("../src/server/RoundPolicy")
local Plan = require("../src/server/RolePlan")
local Reward = require("../src/server/ProgressionPolicy")
local Catalog = require("../src/server/ProgressionCatalog")
local Guide = require("../src/shared/RoleGuide")
local Metrics = require("./PlaytestMetrics")
local count = 0
local function check(ok, why) assert(ok, why); count += 1 end
for _, population in ipairs({3, 4, 5, 8, 12, 15}) do
    local ids = {}
    for i = 1, population do table.insert(ids, i) end
    local roles = Plan.assign(ids, function(i) return i end, "M5")
    local spies, owner = {}, nil
    for id, role in pairs(roles) do
        if role == "Spy" then table.insert(spies, id) end
        if role == "Owner" then owner = id end
        check(Guide.goal(role) ~= Guide.goals.Waiting, "every assigned role has a short goal")
    end
    check(#spies == (if population >= 8 then 2 else 1), "spy team boundary")
    for _, outcome in ipairs({"Timeout", "Extraction", "SpyLeft"}) do
        local r = Round.new(Config)
        check(r:tick(0, population) == "Countdown", "normal lobby countdown")
        check(r:tick(Config.COUNTDOWN_SECONDS, population) == "Start", "full countdown")
        check(r:activate(ids, spies), "live M5 composition accepted")
        r:tick(Config.COUNCIL_DELAY, population)
        check(r:council(owner), "silent owner can call council")
        local remaining = r.savedRemaining
        check(r:tick(Config.COUNCIL_SECONDS, population) == "Search" and r.detained == nil, "AFK voters do not invent a majority")
        check(r.remaining == remaining, "council preserves active time")
        if outcome == "Timeout" then
            r:tick(remaining, population)
            check(r.result.winner == "Defenders" and r.result.reason == "Timeout", "AFK spy cannot stall the match")
        elseif outcome == "Extraction" then
            check(r:extract(spies[#spies]) and r.result.winner == "Spy", "either spy can finish for the team")
        else
            for index, spy in ipairs(spies) do
                r:leave(spy)
                check(r.phase == (if index == #spies then "Results" else "Active"), "remaining spy keeps playing")
            end
            check(r.result.reason == "SpyLeft", "last spy leaving ends round")
        end
        check(not r:extract(spies[1]), "no duplicate outcome in results")
        check(r:tick(Config.RESULT_RESET_SECONDS, population) == "Reset", "natural reset")
        check(r:tick(0, 2) == nil and r.phase == "Waiting", "underfilled lobby waits")
    end
end
for _, role in ipairs(Catalog.roles) do
    for _, case in ipairs({"AFK", "TimeOnly", "MovementOnly", "OneAction", "Qualified", "Win"}) do
        local record = Reward.round(role, "local-test")
        record.active = if case == "AFK" then 0 else 420
        record.moving = if case == "AFK" or case == "TimeOnly" then 0 else 12
        if case == "OneAction" or case == "Qualified" or case == "Win" then Reward.action(record, "Painting") end
        if case == "Qualified" or case == "Win" then Reward.action(record, "Refreshment") end
        local winner = if (case == "Win") == (role == "Spy") then "Spy" else "Defenders"
        local award, why = Reward.reward(record, winner, Catalog.rules)
        if case == "Qualified" or case == "Win" then
            check(award ~= nil and award.tokens == (if case == "Win" then 24 else 19), "qualified token envelope")
            check(award.xp == (if case == "Win" then 65 else 50), "qualified XP envelope")
        else check(not award and why == "InsufficientActivity", "AFK and movement alone cannot farm") end
        check(Reward.reward(record, winner, Catalog.rules) == nil, "single settlement")
    end
end
for _, role in ipairs(Catalog.roles) do
    local record = Reward.round(role, "pickup-test")
    check(Reward.action(record, "ServicePickup") == (role == "Staff"), "only Staff pickup contributes")
    check(not Reward.action(record, "ServicePickup"), "pickup cannot be farmed repeatedly")
end
for _, case in ipairs({"PickupOnly", "Short", "Stationary", "Complete", "Left"}) do
    local record = Reward.round("Staff", "service-test")
    record.active = if case == "Short" then 44 else 45
    record.moving = if case == "Stationary" then 11 else 12
    Reward.action(record, "ServicePickup")
    if case ~= "PickupOnly" then Reward.action(record, "Delivery") end
    if case == "Left" then record.left = true end
    local award = Reward.reward(record, "Spy", Catalog.rules)
    check((award ~= nil) == (case == "Complete"), "service job preserves activity and departure gates")
    if award then check(award.tokens == 19 and award.xp == 50, "one delivered job receives ordinary participation reward") end
    check(not Reward.reward(record, "Spy", Catalog.rules), "service reward cannot settle twice")
end
local m = Metrics.new(100)
check(m:summary().samples == 0, "no fabricated FPS without samples")
for _, invalid in ipairs({0, -1, math.huge, 0/0, "bad"}) do check(not m:add(invalid), "invalid sample rejected") end
for i = 1, 100 do m:add(i / 1000) end
local s = m:summary()
check(s.samples == 100 and s.p50Ms == 50 and s.p95Ms == 95 and s.p99Ms == 99, "nearest rank percentiles")
check(s.maxMs == 100 and s.over50Ms == 50, "hitch counters")
for _ = 1, 1000 do m:add(0.02) end
s = m:summary()
check(s.samples == 100 and s.p95Ms == 20 and s.meanFps == 50, "bounded ring overwrites previous cohort")
check(Guide.goal("unexpected") == Guide.goals.Waiting, "safe guidance fallback")
print("M8 balance/diagnostics:", count, "assertions PASS")
