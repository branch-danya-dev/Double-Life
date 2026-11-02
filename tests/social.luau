local Roles = require("../src/server/RolePlan")
local Round = require("../src/server/RoundPolicy")
local Config = require("../src/shared/Config")
local Progression = require("../src/server/ProgressionPolicy")
local Catalog = require("../src/server/ProgressionCatalog")
local Schema = require("../src/server/ProfileSchema")
local Social = require("../src/server/SocialPolicy")
local Clock = require("../src/server/SessionClock")
local Analytics = require("../src/server/AnalyticsPolicy")
local count = 0
local function check(ok, why) assert(ok, why); count += 1 end
for _, size in ipairs({3, 4, 5, 6, 7, 8, 9, 10, 12, 15}) do
    for seed = 1, 5 do
        local ids = {}
        for id = 1, size do table.insert(ids, id) end
        local roles = Roles.assign(ids, function(n) return (seed % n) + 1 end, "M5")
        local totals, spies = {}, {}
        for id, role in pairs(roles) do
            totals[role] = (totals[role] or 0) + 1
            if role == "Spy" then table.insert(spies, id) end
        end
        for index, role in ipairs({"Owner", "Spy", "CounterAgent", "Staff", "Guest"}) do
            check((totals[role] or 0) == Roles.matrix[size][index], "exact matrix " .. size .. " " .. role)
        end
        local p = Round.new(Config)
        p:countdown()
        check(p:activate(ids, spies), "matrix activates")
        if #spies == 2 then
            check(not p:leave(spies[1]) and p.phase == "Active", "one spy leave never ends round")
            check(not p:extract(spies[1]), "departed spy cannot win")
        end
        check(p:extract(spies[#spies]) and p.result.winner == "Spy", "survivor extracts without teammate")
        check(not p:extract(spies[#spies]), "exactly one result")
        local record = Progression.round("Spy", "connection")
        record.active, record.moving = 60, 15
        Progression.action(record, "Window"); Progression.action(record, "Safe")
        local award = Progression.reward(record, p.result.winner, Catalog.rules)
        check(award.won and Progression.reward(record, p.result.winner, Catalog.rules) == nil, "one spy team reward")
        local profile = Schema.new(Catalog)
        check(Progression.apply(profile, {kind = "Award", id = "round", award = award, at = 1}, Catalog) and #profile.history == 1, "history recorded")
        local left = Round.new(Config); left:countdown(); left:activate(ids, spies)
        if #spies == 2 then left:leave(spies[1]) end
        check(left:leave(spies[#spies]) and left.result.winner == "Defenders", "all spies leave ends round")
        local idle = Round.new(Config); idle:countdown(); idle:activate(ids, spies)
        check(idle:extract(spies[1]), "AFK teammate is not needed for extraction")
        local timeout = Round.new(Config); timeout:countdown(); timeout:activate(ids, spies); timeout:tick(420, size)
        check(timeout.result.winner == "Defenders", "timeout unchanged")
    end
end
local p, clock = Social.new(), Clock.new()
check(not p:grant("Guest", 3, 0), "guest cannot grant")
check(p:grant("Owner", 3, 0) and not p:grant("Owner", 4, 1), "grant throttle")
check(p:usePass(3, 1) and not p:usePass(4, 1), "pass scoped to recipient")
clock:advance(10); clock.running = false; clock:advance(100)
check(p:usePass(3, clock:now()), "council pauses pass lifetime")
clock.running = true; clock:advance(51)
check(not p:usePass(3, clock:now()), "pass expires")
check(p:grant("Owner", 4, 61) and p:grant("Owner", 5, 80) and not p:grant("Owner", 6, 100), "three passes per round")
check(p:pickup(3, "Parcel", 0) and not p:pickup(4, "Parcel", 0), "unique physical item")
check(not p:pickup(3, "Cloth", 0), "one hand slot")
check(not p:accept(4, 3, 1), "no stealing without consent")
check(p:offer(3, 4, 1) and not p:accept(4, 9, 2), "offer bound to source")
check(p:accept(4, 3, 2) and not p:accept(4, 3, 2) and not p:holding(3), "one atomic transfer")
check(p:offer(4, 3, 3), "handoff can help chosen guest")
check(not p:accept(3, 4, 11), "offer expiry")
check(p:drop(4, 12) == "Parcel" and not p:drop(4, 12), "single drop")
p:tick(27)
check(p.items.Parcel.place == "Collection", "dropped item returns; cannot block route")
check(p:pickup(3, "Parcel", 28) and p:deliver(3, "Guest", 30), "verified guest delivery")
check(not p:pickup(4, "Parcel", 31) and p:pickup(4, "Parcel", 40), "delivery replenishment bounded")
check(not p:deliver(4, "Spy", 40), "only natural recipient roles earn delivery")
p:remove(4, 41)
check(not p:holding(4) and not p.passes[4], "death/leave revokes pass and drops resource")
p:tick(60); p:pickup(3, "Parcel", 61)
check(not p:deliver(3, "Guest", 62), "no repeated delivery farming")
p:tick(106)
check(not p:holding(3), "AFK carrier return deadline")
check(p:pickup(5, "Cloth", 110) and p:plant(5, 114), "time-validated service can plant neutral trace")
check(p.traces.Fabric == 159 and type(p.traces.Fabric) == "number", "trace stores expiry, no culprit")
check(not p:pickup(5, "Cloth", 120), "cloth cooldown")
check(p:pickup(5, "Cloth", 134) and p:plant(5, 138), "second bluff")
p:pickup(5, "Cloth", 158)
check(not p:plant(5, 162), "bluff limit")
check(p:signal(1, "Here", 0) and not p:signal(1, "Help", 1) and not p:signal(1, "free text", 10), "fixed signals and cooldown")
p:tick(200)
check(next(p.traces) == nil, "all traces expire")
local reset = Social.new()
check(reset.issued == 0 and next(reset.passes) == nil and not reset:holding(5), "round reset clears state")
reset:pickup(1, "Parcel", 0); reset:offer(1, 2, 0); reset:drop(1, 1); reset:pickup(1, "Parcel", 2)
check(not reset:accept(2, 1, 3), "drop and repick cannot revive old hand-off consent")
reset:offer(1, 2, 3); reset:offer(1, 3, 3); reset:accept(2, 1, 4)
check(reset.offers[3] == nil, "one accepted transfer cancels competing offers")
local emitted, time = {}, 0
local analytics = Analytics.new(function(_, event, value) table.insert(emitted, {event, value}) end, function() return time end)
check(analytics:emit(1, "Join") and not analytics:emit(1, "Join"), "analytics bounded")
check(not analytics:emit(1, "Spy") and not analytics:emit(1, "custom text"), "no role/free text analytics")
check(analytics:emit(1, "ShopOpen") and not analytics:emit(1, "ShopOpen"), "shop spam bounded")
time = 16
check(analytics:emit(1, "ShopOpen") and not analytics:emit(1, "SessionSeconds", 0/0), "typed finite values")
check(#emitted == 3, "only expected telemetry emitted")
print("PASS: " .. count .. " M5 matrix, team, physical interaction and analytics assertions")
