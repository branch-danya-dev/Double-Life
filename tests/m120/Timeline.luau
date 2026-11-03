-- Same deterministic production state-machine timeline in CLI and Studio.
local Suite = {}
function Suite.run(Config, Round, Time)
    local n = 0
    local function check(ok, message) assert(ok, message); n += 1 end
    local function start(spies)
        local r = Round.new(Config, 2)
        check(r:tick(9999, 1) == nil and r.elapsed == 0, "solo waiting consumes no active time")
        check(r:tick(0, 2) == "Countdown", "two real participants start countdown")
        check(r:tick(Config.COUNTDOWN_SECONDS, 2) == "Start" and r.elapsed == 0, "countdown excluded")
        check(r:activate({1, 2, 3}, spies or {2}), "activate real participants")
        for i = 1, 6 do check(r:addMimic("m:" .. i), "Guest actor admitted") end
        check(r.remaining == 1200 and r.phase == "Active", "authoritative twenty minutes")
        return r
    end
    local r = start()
    r:tick(420, 2)
    check(r.phase == "Active" and r.remaining == 780 and r.elapsed == 420, "old timeout remains active")
    r:tick(779, 2)
    check(r.phase == "Active" and r.remaining == 1, "1199 seconds boundary")
    check(r:tick(1, 2) == "Results", "1200 finishes")
    check(r.result.winner == "Defenders" and r.result.reason == "Timeout", "defender timeout")
    check(not r:finish("Spy", "Extraction") and not r:extract(2), "terminal result immutable")
    check(r:tick(Config.RESULT_RESET_SECONDS, 2) == "Reset" and r.elapsed == 1200, "results excluded")
    r:tick(0, 2); r:tick(Config.COUNTDOWN_SECONDS, 2); r:activate({1, 2}, 2)
    check(r.roundId == 2 and r.remaining == 1200 and r.elapsed == 0 and not r.councilUsed, "fresh repeated round")
    for _, elapsed in ipairs({90, 1100, 1199.999}) do
        r = start(); r:tick(elapsed, 2)
        check(r:extract(2) and r.result.reason == "Extraction", "immediate early/late extraction")
        check(math.abs(r.elapsed - elapsed) < 0.00001, "no minimum duration")
        check(not r:extract(2) and r:tick(10000, 2) == "Reset", "extraction wins then timeout cannot win")
        check(r.result.reason == "Extraction", "no result replacement")
    end
    r = start(); r:tick(10000, 2)
    check(r.elapsed == 1200 and r.result.reason == "Timeout", "large dt clamps active telemetry")
    check(not r:extract(2), "timeout wins before extraction")
    for _, lastStep in ipairs({0.25, 10000}) do
        r = start(); r:tick(400, 2)
        check(r:council(1) and r.savedRemaining == 800 and r.remaining == 25, "one council saves whole-match balance")
        r:tick(24.75, 2)
        check(r.phase == "Council" and r.remaining == 0.25 and r.elapsed == 400, "council boundary pause")
        check(not r:extract(2), "extraction disabled while world frozen")
        check(r:tick(lastStep, 2) == "Search", "council resumes including existing overshoot semantics")
        check(r.phase == "Active" and r.remaining == 800 and r.elapsed == 400, "no reset or acceleration")
        check(not r:council(1), "council limit unchanged")
        r:tick(799, 2); check(r.phase == "Active" and r.remaining == 1, "resumed match boundary")
        r:tick(1, 2); check(r.result.reason == "Timeout" and r.elapsed == 1200, "total active budget")
    end
    for _, council in ipairs({false, true}) do
        r = start({2, 3}); r:tick(90, 3)
        if council then check(r:council(1), "council before departures") end
        local saved = r.remaining
        check(not r:leave(2) and r.remaining == saved and r.result == nil, "first spy leaves without ending")
        check(not r:leave(1) and r.result == nil, "owner departure does not end")
        check(r:leave(3) and r.result.reason == "SpyLeft", "last spy ends immediately even during pause")
        check(not r:leave(3), "departure idempotent")
    end
    for _, pair in ipairs({{1200,"20:00"},{600,"10:00"},{599,"09:59"},{1,"00:01"},{0,"00:00"},{-4,"00:00"},{0.1,"00:01"}}) do
        check(Time.format(pair[1]) == pair[2], "HUD boundary " .. pair[2])
    end
    check(Time.remaining({phase="Council",remaining=25,activeRemaining=800}) == 800, "HUD uses paused active timer")
    check(Time.remaining({phase="Active",remaining=599,activeRemaining=599}) == 599, "HUD active timer")
    for _, seconds in ipairs({25, 1, 0}) do
        check(Time.council({remaining=seconds,activeRemaining=800}) == "Собрание · осталось "..seconds.." с\nМатч · 13:20 · пауза", "visible modal separates paused timer")
    end
    check(Config.DOSSIER_CARRY_SECONDS == 60 and Config.COUNCIL_SECONDS == 25 and Config.COUNCIL_DELAY == 30, "other durations unchanged")
    return n
end
return Suite
