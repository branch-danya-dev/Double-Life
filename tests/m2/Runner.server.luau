local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "test fixture is Studio-only")
local driver = Instance.new("RemoteFunction")
driver.Name, driver.Parent = "M2TestDriver", RS
local Game = require(game.ServerScriptService.DoubleLifeServer.Game)
local Config = require(RS.DoubleLifeShared.Config)
-- Accelerate only intermission/council; production defaults remain in the production artifact.
Config.COUNCIL_SECONDS, Config.RESULT_RESET_SECONDS = 12, 4
local function untilTrue(test, seconds, message)
    local deadline = os.clock() + seconds
    repeat if test() then return end; task.wait(0.2) until os.clock() >= deadline
    error(message)
end
local function check(ok, message) assert(ok, message); print("M2 PASS", message) end
local function invoke(player, command)
    local done, result, ok = false, nil, false
    task.spawn(function() ok, result = pcall(function() return driver:InvokeClient(player, command) end); done = true end)
    untilTrue(function() return done end, 60, "client driver timeout: " .. player.Name .. " " .. command.kind)
    assert(ok, tostring(result))
    return result
end
local function prompt(player, part, action, position)
    return invoke(player, {kind = "Prompt", part = part, action = action, position = position})
end
local function walk(player, points) return invoke(player, {kind = "Walk", points = points}) end
local function snapshot(player) return invoke(player, {kind = "Snapshot"}) end
local function run()
    untilTrue(function() return Game.get() ~= nil and #Players:GetPlayers() >= 5 end, 240, "launch five clients")
    local rt = Game.get()
    untilTrue(function() return rt.rounds.policy.phase == "Active" end, 30, "active round")
    check(#rt.rounds.roster == 5, "five real clients participate")
    local finished, completed = {}, 0
    rt.roundFinished.Event:Connect(function(event) finished[event.roundId] = (finished[event.roundId] or 0) + 1 end)
    rt.taskCompleted.Event:Connect(function() completed += 1 end)
    local function role(name)
        for _, p in ipairs(Players:GetPlayers()) do if rt.roles:get(p) == name then return p end end
        error("missing role " .. name)
    end
    local function nextRound(previous)
        untilTrue(function() return rt.rounds.policy.phase == "Active" and rt.rounds.policy.roundId > previous end, 30, "next round")
        check(not rt.evidence.created and next(rt.requests.ledger.requests) == nil and next(rt.requests.ledger.scores) == nil,
            "new round clears evidence, queue and scores")
        check(rt.world.studyDoor.CanCollide and rt.world.studyWindow.CanCollide and #rt.rounds:snapshot(role("Spy")).protocol == 0,
            "new round restores access and clears council")
        for _, p in ipairs(Players:GetPlayers()) do check(not rt.dossier:has(p) and rt.dossier:count(p) == 0, "fresh personal progress " .. p.Name) end
    end
    local function council(owner)
        untilTrue(function() return rt.rounds.policy.elapsed >= 30 end, 40, "council startup delay")
        prompt(owner, "OwnerAccessConsole", "Созвать собрание", Vector3.new(0, 4, 36))
        check(rt.rounds.policy.phase == "Council", "owner summons via real prompt")
    end
    local function vote(voter, target, attach)
        invoke(voter, {kind = "Vote", roundId = rt.rounds.policy.roundId, target = target.UserId, attach = attach})
    end
    local owner, spy, guest, staff = role("Owner"), role("Spy"), role("Guest"), role("Staff")
    for _, p in ipairs(Players:GetPlayers()) do check(snapshot(p).role == rt.roles:get(p), "own-role-only client snapshot " .. p.Name) end
    local started = os.clock()
    walk(spy, {Vector3.new(0, 4, -34), Vector3.new(-34, 4, -34), Vector3.new(-34, 4, 58), Vector3.new(-22, 4, 58)})
    prompt(spy, "StudyWindow", "Открыть окно")
    check(not rt.world.studyWindow.CanCollide, "window reached by physical walking and opened")
    walk(spy, {Vector3.new(-13, 4, 58), Vector3.new(0, 4, 61)})
    local notices = invoke(owner, {kind = "Notices"})
    prompt(spy, "DocumentSafe", "Осмотреть")
    check(rt.dossier:has(spy) and invoke(owner, {kind = "Notices"}) == notices, "theft has no automatic owner alert")
    check(snapshot(owner).hasDossier == false and snapshot(spy).hasDossier == true, "carrier information private")
    print("M2 WALK TO DOSSIER SECONDS", os.clock() - started)
    prompt(guest, "BrokenSeal", "Подобрать улику", Vector3.new(4, 4, 62))
    check(rt.evidence.holder == guest.UserId, "physical evidence collected by ordinary guest")
    invoke(guest, {kind = "Drop", roundId = rt.rounds.policy.roundId})
    check(rt.evidence.part ~= nil and rt.evidence.holder == nil, "evidence can be dropped")
    prompt(guest, "BrokenSeal", "Подобрать улику")
    check(rt.evidence.holder == guest.UserId, "dropped evidence picked up")
    -- Keep a live request and an open window across the Council pause.
    prompt(staff, "ServicePoint1", "Заказать сок сюда", Vector3.new(17, 4, -10))
    local request = rt.requests.ledger.requests[staff.UserId]
    council(owner)
    local time, remaining, npcPosition = rt.scope:now(), rt.rounds.policy.savedRemaining, rt.guard.mover.root.Position
    vote(guest, spy, true)
    vote(owner, spy, false)
    vote(staff, spy, false)
    vote(owner, guest, false)
    check(rt.rounds.policy.votes[owner.UserId] == spy.UserId, "duplicate vote cannot replace or multiply")
    check(rt.rounds.protocol[guest.UserId].evidence.location == "Сейф, кабинет", "server-owned clue attached to accusation")
    check(rt.scope:now() == time and rt.rounds.policy.savedRemaining == remaining and request.expires > time,
        "Council pauses active and request clocks")
    check((rt.guard.mover.root.Position - npcPosition).Magnitude < 0.5, "Council freezes NPC in place")
    local safePrompt = rt.world.safe:FindFirstChildOfClass("ProximityPrompt")
    check(not rt.interactions:inReach(spy, safePrompt), "critical actions denied during council")
    untilTrue(function() return rt.rounds.policy.phase == "Active" end, 15, "council ends")
    check(rt.rounds.policy.detained and rt.rounds.policy.detained.id == spy.UserId and not rt.dossier:has(spy), "correct search returns dossier without ending game")
    check(spy.Character.HumanoidRootPart.Anchored and not rt.rounds:callCouncil(owner), "bounded detention and one council only")
    untilTrue(function() return not rt.rounds.policy.detained end, 15, "search releases")
    check(not spy.Character.HumanoidRootPart.Anchored, "suspect returns to play")
    check(rt.guard.mover.root:GetNetworkOwner() == nil and rt.requests.npc.root:GetNetworkOwner() == nil,
        "NPC ownership remains on server after Council")
    prompt(spy, "DocumentSafe", "Осмотреть", Vector3.new(0, 4, 61))
    -- Open door via the owner, then physically leave the study and walk to exit.
    prompt(owner, "OwnerAccessConsole", "Открыть кабинет", Vector3.new(0, 4, 36))
    walk(spy, {Vector3.new(0, 4, 44), Vector3.new(0, 4, 33), Vector3.new(0, 4, -23)})
    prompt(spy, "EstateExit", "Покинуть особняк")
    local id = rt.rounds.policy.roundId
    check(rt.rounds.policy.phase == "Results" and rt.rounds.policy.result.winner == "Spy", "spy extraction win")
    check(#snapshot(owner).round.result.roles == 5 and finished[id] == 1, "roles revealed only at one result event")
    local oldClock, staleRan = rt.scope, false
    oldClock:delay(0.1, function() staleRan = true end)
    nextRound(id)
    oldClock:advance(100)
    check(not staleRan and not oldClock.alive, "stale round callback cannot affect new round")
    owner, spy, guest, staff = role("Owner"), role("Spy"), role("Guest"), role("Staff")
    -- Innocent search preserves ordinary activity; player service still awards once.
    council(owner)
    for _, p in ipairs({owner, spy, staff}) do vote(p, guest, false) end
    untilTrue(function() return rt.rounds.policy.phase == "Active" end, 15, "innocent council ends")
    check(rt.rounds.policy.detained.id == guest.UserId and rt.rounds.policy.result == nil, "innocent searched without elimination or role reveal")
    untilTrue(function() return not rt.rounds.policy.detained end, 15, "innocent release")
    prompt(guest, "Painting1", "Осмотреть", Vector3.new(-24, 4, -15))
    check(rt.dossier:count(guest) == 1, "innocent continues personal goals")
    prompt(guest, "ServicePoint1", "Заказать сок сюда", Vector3.new(17, 4, -10))
    prompt(staff, "ServicePantry", "Принять заказ / взять сок", Vector3.new(-15, 4, 19))
    prompt(staff, "ServicePantry", "Принять заказ / взять сок")
    prompt(staff, "ServicePoint1", "Доставить сок", Vector3.new(20, 4, -7))
    check(rt.requests.ledger.scores[staff.UserId] == 10 and completed >= 3, "M1 player delivery and server task hooks")
    prompt(staff, "ServicePoint1", "Доставить сок")
    check(rt.requests.ledger.scores[staff.UserId] == 10, "no duplicate task reward")
    id = rt.rounds.policy.roundId
    rt.rounds.policy.remaining = 1 -- Exercise real Heartbeat expiry without waiting for the full configured match.
    untilTrue(function() return rt.rounds.policy.phase == "Results" end, 3, "timer result")
    check(rt.rounds.policy.result.winner == "Defenders" and rt.rounds.policy.result.reason == "Timeout" and finished[id] == 1, "defenders win on timer exactly once")
    nextRound(id)
    owner, spy, guest = role("Owner"), role("Spy"), role("Guest")
    council(owner)
    vote(owner, guest, false)
    untilTrue(function() return rt.rounds.policy.phase == "Active" end, 15, "no-majority council")
    check(not rt.rounds.policy.detained, "no majority means no sanction")
    id = rt.rounds.policy.roundId
    owner:Kick("M2 test: owner departure")
    task.wait(2)
    check(rt.rounds.policy.phase == "Active", "owner departure does not end or hang round")
    prompt(guest, "ServicePoint2", "Заказать сок сюда", Vector3.new(-8, 4, 22))
    untilTrue(function() return (rt.requests.received[guest.UserId] or 0) >= 1 end, 60, "NPC delivers with absent owner")
    check(true, "NPC service recovers and delivers after consecutive rounds")
    spy:Kick("M2 test: spy departure")
    untilTrue(function() return rt.rounds.policy.phase == "Results" end, 3, "spy departure result")
    check(rt.rounds.policy.result.reason == "SpyLeft" and finished[id] == 1, "spy departure awards defenders once")
    nextRound(id)
    check(#rt.rounds.roster == 3, "next full match works with three clients")
    print("M2 STUDIO SUITE PASS", #Players:GetPlayers(), "clients remain; five at start; four consecutive rounds")
    for _, p in ipairs(Players:GetPlayers()) do invoke(p, {kind = "Manual"}) end
    local edgeOk, edgeError = xpcall(function() require(script.Parent.EdgeCases)(rt, driver) end, debug.traceback)
    if not edgeOk then warn("M2 EDGE SUITE FAIL", edgeError) end
end
local ok, err = xpcall(run, debug.traceback)
if not ok then warn("M2 STUDIO SUITE FAIL", err) end
