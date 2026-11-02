-- Optional continuation: add ONE client after M2 STUDIO SUITE PASS.
return function(rt, driver)
    local Players = game:GetService("Players")
    local Config = require(game.ReplicatedStorage.DoubleLifeShared.Config)
    local function check(ok, message) assert(ok, message); print("M2 EDGE PASS", message) end
    local function waitFor(test, seconds, message)
        local deadline = os.clock() + seconds
        repeat if test() then return end; task.wait(0.2) until os.clock() >= deadline
        error(message)
    end
    local function invoke(player, command)
        local done, result, ok = false, nil, false
        task.spawn(function() ok, result = pcall(function() return driver:InvokeClient(player, command) end); done = true end)
        waitFor(function() return done end, 30, "edge client response")
        assert(ok, tostring(result)); return result
    end
    local function prompt(player, part, action, position)
        return invoke(player, {kind = "Prompt", part = part, action = action, position = position})
    end
    local baseline = table.clone(rt.roles.values)
    local late
    print("M2 EDGE READY: add one client during Active")
    local connection = Players.PlayerAdded:Connect(function(player) late = player end)
    waitFor(function() return late ~= nil end, 240, "add one late client")
    connection:Disconnect()
    waitFor(function() return late.Character and late.Character:FindFirstChild("HumanoidRootPart") end, 25, "late character")
    task.wait(2)
    local state = invoke(late, {kind = "Snapshot"})
    check(state.role == "Waiting" and not state.round.participating, "late join waits without a hidden role")
    for id, value in pairs(baseline) do check(rt.roles.values[id] == value, "late join preserves existing role") end
    prompt(late, "ServicePoint1", "Заказать сок сюда", Vector3.new(17, 4, -10))
    check(not rt.requests.ledger.requests[late.UserId], "late join cannot change active world")
    local owner, spy, guest
    for _, player in ipairs(Players:GetPlayers()) do
        local role = rt.roles.values[player.UserId]
        if role == "Owner" then owner = player elseif role == "Spy" then spy = player elseif role == "Guest" then guest = player end
    end
    prompt(spy, "StudyWindow", "Открыть окно", Vector3.new(-22, 4, 58))
    prompt(spy, "DocumentSafe", "Осмотреть", Vector3.new(0, 4, 61))
    check(rt.dossier:has(spy), "disconnect scenario has a real dossier carrier")
    Config.COUNCIL_SECONDS = 25
    waitFor(function() return rt.rounds.policy.elapsed >= 30 end, 35, "council delay")
    prompt(owner, "OwnerAccessConsole", "Созвать собрание", Vector3.new(0, 4, 36))
    check(rt.rounds.policy.phase == "Council", "edge council begins")
    local roundId = rt.rounds.policy.roundId
    invoke(late, {kind = "Vote", roundId = roundId, target = spy.UserId})
    check(rt.rounds.policy.votes[late.UserId] == nil, "late join has no vote")
    invoke(owner, {kind = "Vote", roundId = roundId, target = guest.UserId})
    check(rt.rounds.policy.votes[owner.UserId] == guest.UserId, "owner has exactly one ordinary vote")
    owner:Kick("M2 edge: owner/voter leaves council")
    waitFor(function() return not rt.rounds.policy.participants[owner.UserId] end, 10, "owner disconnect processed")
    check(rt.rounds.policy.phase == "Council" and rt.rounds.policy.votes[owner.UserId] == nil,
        "owner/voter departure removes vote but does not hang council")
    spy:Kick("M2 edge: dossier carrier leaves council")
    waitFor(function() return rt.rounds.policy.phase == "Results" end, 3, "carrier departure result")
    check(rt.rounds.policy.result.reason == "SpyLeft", "carrier departure in paused council gives defenders win")
    waitFor(function() return rt.rounds.policy.phase == "Waiting" end, 8, "two-player waiting")
    check(#Players:GetPlayers() == 2 and next(rt.roles.values) == nil, "under three returns to explicit neutral waiting")
    prompt(late, "Painting1", "Осмотреть", Vector3.new(-24, 4, -15))
    prompt(late, "ServicePoint1", "Заказать сок сюда", Vector3.new(17, 4, -10))
    check(rt.requests.ledger.requests[late.UserId] ~= nil, "neutral request created")
    print("M2 NEUTRAL WORKER", coroutine.status(rt.requests.worker), rt.requests.lastTick, rt.scope:now())
    waitFor(function() return (rt.requests.received[late.UserId] or 0) == 1 end, 50, "neutral service")
    check(rt.dossier:count(late) == 1, "waiting supports paintings and autonomous service")
    print("M2 EDGE SUITE PASS", #Players:GetPlayers(), "clients remain")
    for _, player in ipairs(Players:GetPlayers()) do invoke(player, {kind = "Manual"}) end
end
