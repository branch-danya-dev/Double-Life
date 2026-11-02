-- Real Studio clients; isolated in-memory adapter, never a DataStore namespace.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local modules = game.ServerScriptService.DoubleLifeServer
local Schema = require(modules.ProfileSchema)
local adapter = require(script.Parent.MemoryStore).new(Schema.copy)
local driver = Instance.new("RemoteFunction")
driver.Name, driver.Parent = "M4TestDriver", RS
local rt = require(modules.Game).start({adapter = adapter})
local function waitFor(test, seconds, message)
    local deadline = os.clock() + seconds
    repeat if test() then return end; task.wait(0.1) until os.clock() >= deadline
    error(message)
end
local function check(ok, message) assert(ok, message); print("M4 PASS", message) end
local function invoke(player, command)
    local done, ok, result = false, false, nil
    task.spawn(function() ok, result = pcall(function() return driver:InvokeClient(player, command) end); done = true end)
    waitFor(function() return done end, 75, "driver timeout " .. command.kind)
    assert(ok, tostring(result)); return result
end
local function snapshot(player) return invoke(player, {kind = "Snapshot"}) end
local function prompt(player, part, action, position)
    return invoke(player, {kind = "Prompt", part = part, action = action, position = position})
end
local function profile(player, action, item, slot)
    return invoke(player, {kind = "Profile", action = action, item = item, slot = slot})
end
local function role(name)
    for _, player in ipairs(Players:GetPlayers()) do if rt.roles:get(player) == name then return player end end
    error("missing role " .. name)
end
local function ready(player)
    local e = rt.profiles:entry(player)
    return e and e.status == "Ready"
end
local function activities(players)
    for index, player in ipairs(players) do
        prompt(player, "Painting1", "Осмотреть", Vector3.new(-24, 4, -15))
        invoke(player, {kind = "Walk", points = {Vector3.new(-17, 4, -15 + index * 3)}})
    end
    local owner = role("Owner")
    prompt(owner, "EventConsole", "Выбрать мероприятие", Vector3.new(9, 4, 20))
    invoke(owner, {kind = "Event", action = "Start", event = "Music", roundId = rt.rounds.policy.roundId})
    waitFor(function() return rt.events.policy.phase == "Running" end, 8, "music start")
    local done, errors = 0, {}
    for _, player in ipairs(players) do
        task.spawn(function()
            local ok, result = pcall(function() return invoke(player, {kind = "Dance"}) end)
            if not ok then table.insert(errors, result) end
            done += 1
        end)
    end
    waitFor(function() return done == #players end, 35, "dance group")
    assert(#errors == 0, table.concat(errors, ";"))
    check(rt.events.policy.phase == "Finished", "M3 music still runs with profile hooks")
    for index, player in ipairs(players) do
        invoke(player, {kind = "Walk", points = {Vector3.new(18, 4, -8), Vector3.new(-15, 4, -8), Vector3.new(-15, 4, index * 3)}})
    end
end
local function run()
    waitFor(function() return #Players:GetPlayers() == 1 end, 300, "launch ONE client")
    local first = Players:GetPlayers()[1]
    waitFor(function() return ready(first) and first.Character and first.Character:FindFirstChild("HumanoidRootPart") end, 30, "first profile")
    task.wait(2)
    check(snapshot(first).profile.mode == "FakeMemory" and snapshot(first).profile.tokens == 0, "isolated test profile loaded")
    prompt(first, "Painting1", "Осмотреть", Vector3.new(-24, 4, -15))
    check(snapshot(first).profile.reputationXp == 0, "Waiting activity never grants permanent XP")
    check(profile(first, "Buy", "ObserverTitle").tokens == 0, "insufficient tokens rejected over real remote")
    check(profile(first, "Equip", "Prybar", "Spy").equipped.Spy == "Lockpick", "locked tool rejected over real remote")
    check(profile(first, "Award", "ObserverTitle").reputationXp == 0, "client cannot award XP")
    rt.roles.random = {NextInteger = function(_, _, high) return high end} -- fixture-only roster; production RNG unchanged
    print("M4 WAITING PASS: add FOUR clients now")
    waitFor(function() return #Players:GetPlayers() == 5 end, 240, "add four clients")
    waitFor(function() return rt.rounds.policy.phase == "Active" end, 30, "first round")
    for _, player in ipairs(Players:GetPlayers()) do check(ready(player), "profile ready before round for " .. player.Name); snapshot(player) end
    local firstRoles = {}
    for _, player in ipairs(Players:GetPlayers()) do firstRoles[player.UserId] = rt.roles:get(player) end
    local owner, spy, agent, staff, idle = role("Owner"), role("Spy"), role("CounterAgent"), role("Staff"), role("Guest")
    local active = {owner, spy, agent, staff}
    check(profile(spy, "Equip", "Prybar", "Spy").equipped.Spy == "Lockpick", "Active loadout changes denied")
    activities(active)
    local baseline = rt.profiles:tool(spy, "Spy")
    check(baseline.window == 14 and baseline.trace == 35, "first round freezes free baseline tool")
    prompt(spy, "StudyWindow", "Открыть окно", Vector3.new(-22, 4, 58))
    local opened = rt.scope:now()
    prompt(spy, "DocumentSafe", "Осмотреть", Vector3.new(0, 4, 61))
    check(rt.dossier:has(spy), "baseline permits ordinary dossier theft")
    waitFor(function() return rt.scope:now() >= opened + 15 end, 17, "baseline window closure")
    check(rt.world.studyWindow.CanCollide, "baseline window actually closes after 14 seconds")
    waitFor(function() return rt.scope:now() >= opened + 36 end, 24, "baseline trace expiry")
    check(rt.world.studyWindow.Color == Color3.fromRGB(69, 107, 124), "baseline trace actually clears after 35 seconds")
    for _, player in ipairs(active) do
        local record = rt.profiles.round[player.UserId]
        check(record.active >= 45 and record.moving >= 12, "real active movement qualifies " .. player.Name)
    end
    prompt(spy, "EstateExit", "Покинуть особняк", Vector3.new(0, 4, -24))
    local roundOne = rt.rounds.policy.roundId
    waitFor(function() return snapshot(spy).profile.reward and snapshot(spy).profile.reward.reason == "Awarded" end, 6, "confirmed first reward")
    local firstProfile = snapshot(spy).profile
    check(firstProfile.stats.played == 1 and firstProfile.roleXp.Spy == 40 and firstProfile.level == 2, "first completed round grants account and role progression")
    check(snapshot(idle).profile.stats.played == 0, "AFK real client receives no permanent rewards")
    rt.roundFinished:Fire({roundId = roundOne, winner = "Spy", reason = "Extraction"})
    task.wait(0.2)
    check(snapshot(spy).profile.stats.played == 1, "duplicate server result cannot grant twice")
    check(profile(agent, "Equip", "Prybar", "Spy").equipped.Spy == "Prybar", "unlocked sidegrade selected before next role")
    profile(staff, "Equip", "JournalLens", "CounterAgent")
    adapter.faults["User_" .. spy.UserId] = {"after"}
    profile(spy, "Buy", "ObserverTitle")
    waitFor(function() return ready(spy) and rt.profiles:entry(spy).profile.inventory.ObserverTitle end, 5, "uncertain purchase retry")
    local balance = snapshot(spy).profile.tokens
    check(balance == firstProfile.tokens - 20, "response lost after purchase still debits once")
    check(profile(spy, "Buy", "ObserverTitle").tokens == balance, "replayed purchase remote does not double charge")
    profile(spy, "Equip", "ObserverTitle", "Title")
    rt.profiles:remove(spy) -- Same real client reloads its account through a new store lease.
    waitFor(function() return rt.profiles.store.entries[spy.UserId].status == "Closed" end, 3, "profile released")
    rt.profiles:add(spy)
    waitFor(function() return ready(spy) end, 3, "profile reload")
    check(snapshot(spy).profile.tokens == balance and snapshot(spy).profile.equipped.Title == "ObserverTitle", "reload keeps balance, collection and equipped title")
    rt.roles.random = {NextInteger = function() return 1 end}
    print("M4 FIRST ROUND PASS", roundOne, "real rewards, purchase and profile reload")
    waitFor(function() return rt.rounds.policy.phase == "Active" and rt.rounds.policy.roundId > roundOne end, 30, "second round")
    local changed = 0
    for _, player in ipairs(Players:GetPlayers()) do if firstRoles[player.UserId] ~= rt.roles:get(player) then changed += 1 end end
    check(changed >= 3, "second round has different role assignments")
    owner, spy, agent = role("Owner"), role("Spy"), role("CounterAgent")
    check(spy == active[3] and select(2, rt.profiles:tool(spy, "Spy")) == "Prybar", "saved choice frozen for new Spy role")
    activities(active)
    prompt(spy, "StudyWindow", "Открыть окно", Vector3.new(-22, 4, 58))
    opened = rt.scope:now()
    prompt(spy, "DocumentSafe", "Осмотреть", Vector3.new(0, 4, 61))
    check(rt.dossier:has(spy), "alternative retains ordinary access and theft")
    invoke(spy, {kind = "Walk", points = {Vector3.new(-5, 4, 55)}})
    prompt(agent, "ForensicLog", "Изучить журнал", Vector3.new(8, 4, 61))
    check(string.find(invoke(agent, {kind = "LastNotice"}), "40", 1, true) ~= nil, "agent lens gives bounded recent-time fact without identity")
    prompt(agent, "ForensicLog", "Изучить журнал")
    check(string.find(invoke(agent, {kind = "LastNotice"}), "Подождите", 1, true) ~= nil, "agent precision tradeoff enforces longer read cooldown")
    check(select(2, rt.profiles:tool(agent, "CounterAgent")) == "JournalLens", "agent alternative selected from persistent collection")
    waitFor(function() return rt.scope:now() >= opened + 15 end, 17, "sidegrade longer window")
    check(not rt.world.studyWindow.CanCollide, "alternative window stays open after baseline would close")
    waitFor(function() return rt.scope:now() >= opened + 23 end, 10, "sidegrade closure")
    check(rt.world.studyWindow.CanCollide, "alternative window bounded to 22 seconds")
    waitFor(function() return rt.scope:now() >= opened + 36 end, 15, "sidegrade longer trace")
    check(rt.world.studyWindow.Color == Color3.fromRGB(190, 144, 80), "alternative leaves stronger visible trace beyond baseline expiry")
    prompt(owner, "OwnerAccessConsole", "Созвать собрание", Vector3.new(0, 4, 36))
    for _, player in ipairs(Players:GetPlayers()) do if player ~= spy then invoke(player, {kind = "Vote", roundId = rt.rounds.policy.roundId, target = spy.UserId}) end end
    waitFor(function() return rt.rounds.policy.phase == "Active" end, 28, "council ends")
    check(not rt.dossier:has(spy) and rt.rounds.policy.detained.id == spy.UserId, "defenders can search alternative-tool Spy normally")
    waitFor(function() return rt.scope:now() >= opened + 71 end, 40, "sidegrade trace expiry")
    check(rt.world.studyWindow.Color == Color3.fromRGB(69, 107, 124), "longer trace also expires after Council pause")
    for _, player in ipairs(Players:GetPlayers()) do snapshot(player) end
    print("M4 SECOND ROUND: waiting for genuine 420-second defender timeout; no timer acceleration")
    waitFor(function() return rt.rounds.policy.phase == "Results" end, 430, "full defender timeout")
    check(rt.rounds.policy.result.winner == "Defenders", "full-length defensive victory preserved")
    waitFor(function() return snapshot(owner).profile.stats.played == 2 end, 6, "second reward")
    check(snapshot(owner).profile.roleXp.Owner >= 30 and snapshot(owner).profile.roleXp.Spy >= 30, "role XP independently follows changed roles")
    check(snapshot(idle).profile.stats.played == 0, "vote alone cannot farm XP for stationary client")
    for _, player in ipairs(active) do
        local state = snapshot(player).profile
        check(state.stats.played == 2 and #state.history == 2, "two durable results for " .. player.Name)
    end
    local oldRound = rt.rounds.policy.roundId
    waitFor(function() return rt.rounds.policy.phase == "Active" and rt.rounds.policy.roundId > oldRound end, 30, "world rebuild")
    check(snapshot(owner).profile.stats.played == 2 and rt.events.policy.used == 0, "world reset preserves profile but clears session events")
    rt.roundFinished:Fire({roundId = roundOne, winner = "Spy", reason = "Extraction"})
    task.wait(0.2)
    check(snapshot(owner).profile.stats.played == 2, "stale prior-round callback cannot award in new world")
    require(script.Parent.StoreAudit).run(rt)
    for _, player in ipairs(Players:GetPlayers()) do snapshot(player); invoke(player, {kind = "Manual"}) end
    print("M4 STUDIO SUITE PASS", #Players:GetPlayers(), "real clients; isolated memory adapter; real DataStore NOT TESTED")
end
local ok, err = xpcall(run, debug.traceback)
if not ok then warn("M4 STUDIO SUITE FAIL", err) end
