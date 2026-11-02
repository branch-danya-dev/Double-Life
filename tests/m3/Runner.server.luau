-- Launch ONE client first, then follow the two explicit Output markers to add clients.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
assert(game:GetService("RunService"):IsStudio(), "Studio-only integration fixture")
local driver = Instance.new("RemoteFunction")
driver.Name, driver.Parent = "M3TestDriver", RS
local Game = require(game.ServerScriptService.DoubleLifeServer.Game)
local function waitFor(test, seconds, message)
    local deadline = os.clock() + seconds
    repeat if test() then return end; task.wait(0.1) until os.clock() >= deadline
    error(message)
end
local function check(ok, message) assert(ok, message); print("M3 PASS", message) end
local function invoke(player, command)
    local done, ok, result = false, false, nil
    task.spawn(function() ok, result = pcall(function() return driver:InvokeClient(player, command) end); done = true end)
    waitFor(function() return done end, 70, "driver timeout " .. command.kind)
    assert(ok, tostring(result)); return result
end
local function prompt(player, part, action, position)
    return invoke(player, {kind = "Prompt", part = part, action = action, position = position})
end
local function snapshot(player) return invoke(player, {kind = "Snapshot"}) end
local function run()
    waitFor(function() return Game.get() and #Players:GetPlayers() >= 1 end, 300, "launch first client")
    local rt = Game.get()
    local first = Players:GetPlayers()[1]
    waitFor(function() return first.Character and first.Character:FindFirstChild("HumanoidRootPart") end, 30, "first character")
    task.wait(3)
    check(#Players:GetPlayers() == 1 and rt.rounds.policy.phase == "Waiting", "first visitor can play in Waiting")
    check(snapshot(first).activities.practice.step == 1 and snapshot(first).role == "Waiting", "practice has private steps and no role")
    prompt(first, "Painting1", "Осмотреть", Vector3.new(-24, 4, -15))
    check(snapshot(first).activities.practice.step == 2, "practice inspection advances")
    prompt(first, "ServicePoint1", "Заказать сок сюда", Vector3.new(17, 4, -10))
    waitFor(function() return (rt.requests.received[first.UserId] or 0) == 1 end, 65, "real NPC practice delivery")
    check(snapshot(first).activities.practice.step == 3, "practice waits for physical NPC delivery")
    waitFor(function() return rt.guard.policy.state == "Patrol" and rt.scope:now() >= rt.guard.policy.nextReaction end, 55, "guard available for practice")
    prompt(first, "PracticeBell", "Позвать охрану", Vector3.new(18, 4, -21))
    check(snapshot(first).activities.practice.step == 4 and rt.guard.policy.state == "Investigate", "practice safe reaction completes without rewards")
    check(next(rt.events.policy.scores) == nil and not rt.events.policy.incidentUsed, "waiting cannot farm event rewards or incidents")
    check(not rt.interactions:inReach(first, rt.world.safe:FindFirstChildOfClass("ProximityPrompt")), "waiting cannot steal")
    local waitingClock = rt.scope
    print("M3 WAITING PASS: add FOUR clients now")
    waitFor(function() return #Players:GetPlayers() >= 5 end, 240, "add four clients")
    waitFor(function() return rt.rounds.policy.phase == "Active" end, 30, "five-player round")
    check(not waitingClock.alive and next(rt.events.practice.records) == nil, "countdown cancels practice and rebuilds world")
    local function role(name)
        for _, player in ipairs(Players:GetPlayers()) do if rt.roles:get(player) == name then return player end end
        error("missing role " .. name)
    end
    local function event(player, action, kind, id)
        return invoke(player, {kind = "Event", action = action, event = kind, roundId = id or rt.rounds.policy.roundId})
    end
    local function start(owner, kind)
        prompt(owner, "EventConsole", "Выбрать мероприятие", Vector3.new(9, 4, 20))
        event(owner, "Start", kind)
        check(rt.events.policy.phase == "Announcing", "owner event starts through held prompt and remote")
        waitFor(function() return rt.events.policy.phase == "Running" end, 8, "event announcement")
    end
    local signals, results = {}, {}
    for name, signal in pairs(rt.eventSignals) do
        signals[name] = {}
        signal.Event:Connect(function(payload)
            check(payload.roundId == rt.rounds.policy.roundId, "roundId on server hook " .. name)
            table.insert(signals[name], payload)
        end)
    end
    rt.roundFinished.Event:Connect(function(payload) results[payload.roundId] = (results[payload.roundId] or 0) + 1 end)
    local owner, spy, guest, agent = role("Owner"), role("Spy"), role("Guest"), role("CounterAgent")
    for _, player in ipairs(Players:GetPlayers()) do snapshot(player) end
    event(owner, "Start", "Relic")
    check(rt.events.policy.used == 0, "remote start without held nearby menu denied")
    prompt(guest, "EventConsole", "Выбрать мероприятие", Vector3.new(9, 4, 20))
    event(guest, "Start", "Relic")
    check(rt.events.policy.used == 0, "guest cannot choose owner event")
    invoke(guest, {kind = "Walk", points = {Vector3.new(15, 4, 16)}}) -- Clear the console's line of sight for the owner.
    start(owner, "Relic")
    waitFor(function() return rt.guard.policy.sources.Event1 ~= nil end, 12, "event guard attention")
    check(rt.guard.policy.state == "Investigate", "event draws bounded guard route in hall")
    rt.events.choose = function(low, high) return if high == 2 then 2 else low end -- deterministic blackout, production RNG unchanged
    for index, z in ipairs({-15, 0, 15}) do prompt(spy, "Painting" .. index, "Осмотреть", Vector3.new(-24, 4, z)) end
    check(not rt.events.policy.incidentUsed, "spy neutral actions never trigger guest incident")
    invoke(spy, {kind = "Walk", points = {Vector3.new(-18, 4, 15)}})
    local notices = invoke(owner, {kind = "Notices"})
    for index, z in ipairs({-15, 0, 15}) do prompt(guest, "Painting" .. index, "Осмотреть", Vector3.new(-24, 4, z)) end
    check(rt.events.policy.pendingIncident ~= nil and not snapshot(owner).activities.incident, "guest incident has no immediate public marker")
    check(invoke(owner, {kind = "Notices"}) == notices, "guest feedback is private")
    local relicPosition = rt.events.relic.Position
    prompt(guest, "EventRelic", "Взять реликвию", relicPosition + Vector3.new(0, 3, -3))
    check(rt.events.policy.carrier == guest.UserId and rt.events.relic:FindFirstChildOfClass("WeldConstraint"), "relic physically carried by Guest")
    waitFor(function() return rt.events.blackout end, 18, "delayed blackout")
    check(math.abs(rt.events.scene.lamps[1].light.Brightness - 0.1) < 0.001 and rt.world.map:FindFirstChild("SafePathLight"), "blackout leaves safe path lights")
    waitFor(function() return rt.rounds.policy.elapsed >= 30 end, 35, "council delay")
    prompt(owner, "OwnerAccessConsole", "Созвать собрание", Vector3.new(0, 4, 36))
    check(rt.rounds.policy.phase == "Council", "defenders may call council during relic and blackout")
    local time, eventEnd, incidentEnd = rt.scope:now(), rt.events.policy.endsAt, rt.events.policy.incident.endsAt
    event(guest, "DropRelic")
    task.wait(2)
    check(rt.scope:now() == time and rt.events.policy.endsAt == eventEnd and rt.events.policy.incident.endsAt == incidentEnd,
        "Council pauses event, incident and reward clocks")
    check(rt.events.policy.carrier == guest.UserId and next(rt.events.policy.scores) == nil, "Council blocks relic drop and rewards")
    waitFor(function() return rt.rounds.policy.phase == "Active" end, 28, "council resumes")
    check(not rt.rounds.policy.detained, "no-majority council resumes all activities")
    guest:Kick("M3 test: relic carrier departure")
    waitFor(function() return not rt.rounds.policy.participants[guest.UserId] end, 10, "carrier leaves")
    check(not rt.events.policy.carrier and rt.events.relic.Anchored and rt.events.relicPrompt.Enabled, "departed carrier restores reachable relic")
    relicPosition = rt.events.relic.Position
    prompt(agent, "EventRelic", "Взять реликвию", relicPosition + Vector3.new(0, 3, -3))
    event(agent, "DropRelic")
    check(not rt.events.policy.carrier and rt.events.relicPrompt.Enabled, "ordinary drop restores accessible pickup")
    prompt(agent, "EventRelic", "Взять реликвию", rt.events.relic.Position + Vector3.new(0, 3, -3))
    invoke(agent, {kind = "Walk", points = {Vector3.new(-5, 4, 6)}})
    prompt(agent, "RelicPedestal", "Вернуть реликвию")
    check(rt.events.policy.scores[agent.UserId] == 15 and not rt.events.relic, "physical delivery awards once and removes relic")
    prompt(agent, "RelicPedestal", "Вернуть реликвию")
    check(rt.events.policy.scores[agent.UserId] == 15, "duplicate delivery cannot farm points")
    event(owner, "Start", "Music")
    check(rt.events.policy.used == 1, "cooldown rejects next event")
    waitFor(function() return not rt.events.policy.incident end, 30, "blackout expires")
    check(rt.events.scene.lamps[1].light.Brightness == 4, "lighting restored exactly")
    local late
    local connection = Players.PlayerAdded:Connect(function(player) late = player end)
    print("M3 LATE READY: add ONE client now")
    waitFor(function() return late ~= nil end, 240, "late client")
    connection:Disconnect()
    waitFor(function() return late.Character and late.Character:FindFirstChild("HumanoidRootPart") end, 30, "late character")
    task.wait(2)
    check(snapshot(late).role == "Waiting" and not snapshot(late).round.participating, "late arrival remains spectator")
    event(late, "Start", "Music")
    prompt(late, "Painting1", "Осмотреть", Vector3.new(-24, 4, -15))
    check(rt.dossier:count(late) == 0 and rt.events.policy.used == 1, "late arrival cannot progress or launch event")
    waitFor(function() return rt.events.policy.phase == "Idle" end, 65, "55-second event cooldown")
    start(owner, "Music")
    local danced, danceResult = false, nil
    task.spawn(function() danceResult = invoke(agent, {kind = "Dance"}); danced = true end)
    prompt(spy, "StudyWindow", "Открыть окно", Vector3.new(-22, 4, 58))
    prompt(spy, "DocumentSafe", "Осмотреть", Vector3.new(0, 4, 61))
    check(rt.dossier:has(spy) and rt.events.policy.phase == "Running", "spy can steal during music without forced participation")
    owner:Kick("M3 test: owner departure during music")
    waitFor(function() return not rt.rounds.policy.participants[owner.UserId] end, 10, "owner leaves")
    check(rt.rounds.policy.phase == "Active", "owner departure does not stop the match or event")
    waitFor(function() return danced end, 30, "three dance cycles")
    check(danceResult.passes == 3 and rt.events.policy.scores[agent.UserId] == 26, "server observes all three dance cycles and awards once")
    check(not rt.events.policy.scores[late.UserId] and not rt.events.policy.scores[spy.UserId], "nonparticipants and spectator receive no event award")
    check(#signals.EventStarted == 2 and #signals.EventFinished == 2 and #signals.GuestIncidentTriggered == 1, "one lifecycle per event and one incident per round")
    for _, player in ipairs(Players:GetPlayers()) do snapshot(player) end
    prompt(spy, "EstateExit", "Покинуть особняк", Vector3.new(0, 4, -24))
    local roundId = rt.rounds.policy.roundId
    check(rt.rounds.policy.result.winner == "Spy" and results[roundId] == 1, "extraction remains authoritative after events")
    waitFor(function() return rt.rounds.policy.phase == "Active" and rt.rounds.policy.roundId > roundId end, 35, "second round")
    check(rt.events.policy.used == 0 and next(rt.events.policy.scores) == nil and not rt.events.policy.incidentUsed, "new round resets event limits and scores")
    owner, spy, guest = role("Owner"), role("Spy"), role("Guest")
    local rolls = 0
    rt.events.choose = function(low, high)
        if high == 2 then rolls += 1; return if rolls == 1 then 1 else 2 end
        return low
    end
    for index, z in ipairs({-15, 0, 15}) do prompt(guest, "Painting" .. index, "Осмотреть", Vector3.new(-24, 4, z)) end
    waitFor(function() return rt.events.policy.incident and rt.events.policy.incident.dispatched end, 20, "delayed guard inspection")
    local guardPosition = rt.guard.mover.root.Position
    task.wait(2)
    check(rt.events.policy.incident.kind == "Inspection" and rt.guard.policy.state == "Investigate"
        and (rt.guard.mover.root.Position - guardPosition).Magnitude > 1, "guest inspection moves real guard on bounded route")
    for _, player in ipairs(Players:GetPlayers()) do snapshot(player) end
    start(owner, "Relic")
    prompt(guest, "EventRelic", "Взять реликвию", rt.events.relic.Position + Vector3.new(0, 3, -3))
    guest.Character.Humanoid.Health = 0
    waitFor(function() return not rt.events.policy.carrier end, 5, "carrier death")
    check(rt.events.relic.Anchored and rt.events.relicPrompt.Enabled, "carrier death preserves relic availability")
    waitFor(function() return guest.Character and guest.Character:FindFirstChildOfClass("Humanoid") and guest.Character.Humanoid.Health > 0 end, 12, "respawn")
    waitFor(function() return rt.rounds.policy.elapsed >= 30 end, 35, "second council delay")
    prompt(owner, "OwnerAccessConsole", "Созвать собрание", Vector3.new(0, 4, 36))
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= spy then invoke(player, {kind = "Vote", roundId = rt.rounds.policy.roundId, target = spy.UserId}) end
    end
    waitFor(function() return rt.rounds.policy.phase == "Active" end, 28, "second council ends")
    check(rt.rounds.policy.detained and rt.rounds.policy.detained.id == spy.UserId, "defender majority search still works during event")
    local oldDirector, oldClock, staleRan = rt.events, rt.scope, false
    oldClock:delay(60, function() staleRan = true end)
    roundId = rt.rounds.policy.roundId
    rt.rounds.policy.remaining = 1 -- Only the terminal wait is accelerated; all M3 durations use production values.
    waitFor(function() return rt.rounds.policy.phase == "Results" end, 3, "defender timeout")
    check(rt.rounds.policy.result.winner == "Defenders" and results[roundId] == 1, "defender timeout wins during relic event")
    check(not rt.events.relic and not rt.events.policy.pendingIncident and not rt.events.policy.incident and not rt.events.blackout,
        "Results cancels every decoration, incident and pending effect")
    waitFor(function() return rt.rounds.policy.phase == "Active" and rt.rounds.policy.roundId > roundId end, 35, "third clean round")
    oldClock:advance(100)
    check(not oldClock.alive and not staleRan and not oldDirector.world.map.Parent, "old callbacks and world cannot affect next round")
    check(next(rt.events.policy.scores) == nil and rt.events.scene.lamps[1].light.Brightness == 4, "fresh score ledger and lighting")
    for _, player in ipairs(Players:GetPlayers()) do snapshot(player); invoke(player, {kind = "Manual"}) end
    print("M3 STUDIO SUITE PASS", #Players:GetPlayers(), "clients; production event timings; manual playtest deferred")
end
local ok, err = xpcall(run, debug.traceback)
if not ok then warn("M3 STUDIO SUITE FAIL", err) end
