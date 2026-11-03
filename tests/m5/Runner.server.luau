-- Real Studio clients, real prompts/remotes; fake account/market APIs only.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local modules = game.ServerScriptService.DoubleLifeServer
local Schema = require(modules.ProfileSchema)
local adapter = require(script.Parent.MemoryStore).new(Schema.copy)
local commerceAdapter = require(script.Parent.MemoryStore).new(Schema.copy)
local market = require(script.Parent.FakeMarketplace).new()
local settings = {enabled = true, isolatedDataStoreVerified = true, passId = 101, productId = 202}
local function account(player) return 100000 + math.abs(player.UserId) end
local telemetry = {}
local Config = require(RS.DoubleLifeShared.Config)
Config.COUNTDOWN_SECONDS = 300 -- fixture allows time to add real clients, live remains 12
local driver = Instance.new("RemoteFunction")
driver.Name, driver.Parent = "M5TestDriver", RS
local rt = require(modules.Game).start({prologue=false,adapter = adapter, commerceAdapter = commerceAdapter, market = market,
    commerceSettings = settings, commerceId = account, analytics = function(_, event) telemetry[event] = (telemetry[event] or 0) + 1 end})
local startAllowed, naturalTick = false, rt.rounds.policy.tick
rt.rounds.policy.tick = function(self, dt, population)
    return naturalTick(self, dt, if startAllowed then population else 0)
end -- fixture only: permits launching five clients together while auditing Waiting
local function check(ok, message) assert(ok, message); print("M5 PASS", message) end
local function waitFor(predicate, seconds, why)
    local deadline = os.clock() + seconds
    repeat if predicate() then return end; task.wait(0.1) until os.clock() >= deadline
    error(why or "condition timed out")
end
local function invoke(player, command)
    local done, ok, value = false, false, nil
    task.spawn(function() ok, value = pcall(function() return driver:InvokeClient(player, command) end); done = true end)
    waitFor(function() return done end, 45, "client invocation " .. command.kind)
    assert(ok, tostring(value)); return value
end
local function snapshot(p) return invoke(p, {kind = "Snapshot"}) end
local function move(p, position) invoke(p, {kind = "Move", position = position}) end
local function prompt(p, part, action, position) invoke(p, {kind = "Prompt", part = part, action = action, position = position}) end
local function social(p, action, target) return invoke(p, {kind = "Social", action = action, target = target, roundId = rt.rounds.policy.roundId}) end
local function commerce(p, action, key) return invoke(p, {kind = "Commerce", action = action, key = key}) end
local function role(name)
    for _, p in ipairs(Players:GetPlayers()) do if rt.roles:get(p) == name then return p end end
    error("missing " .. name)
end
local function run()
    waitFor(function() return #Players:GetPlayers() >= 1 end, 300, "launch real clients")
    local first = Players:GetPlayers()[1]
    waitFor(function() return rt.commerce.policy.accounts[account(first)] ~= nil end, 30)
    task.wait(3)
    settings.enabled = false
    check(not snapshot(first).commerce.enabled, "real client shop DISABLED with zero platform IDs")
    commerce(first, "Prompt", "Supporter")
    check(#market.prompts == 0, "disabled UI request cannot prompt")
    settings.enabled = true
    market.ownership[account(first)] = true
    market.passFinished(first, settings.passId)
    check(commerce(first, "Style", true).selected, "pass verified server-side and voluntary style saved")
    local e = rt.profiles:entry(first)
    rt.profiles.store:enqueue(first.UserId, {kind = "Award", id = "M5-test-seed", at = os.time(), award = {role = "Guest", won = false, xp = 50, roleXp = 30, tokens = 80}}, e.token)
    rt.profiles.store:flush(first.UserId, false, nil, e.token)
    check(snapshot(first).publicStyles[1].title == "Supporter", "social title visible in Waiting")
    print("M5 WAITING PASS: add FOUR clients now")
    rt.roles.random = {NextInteger = function(_, _, high) return high end}
    waitFor(function() return #Players:GetPlayers() == 5 end, 300, "need five real clients")
    waitFor(function()
        for _, p in ipairs(Players:GetPlayers()) do if not rt.profiles:entry(p) or rt.profiles:entry(p).status ~= "Ready" then return false end end
        return true
    end, 30)
    startAllowed = true
    waitFor(function() return rt.rounds.policy.phase == "Countdown" end, 3)
    rt.rounds.policy.remaining = 1
    waitFor(function() return rt.rounds.policy.phase == "Active" end, 5)
    for _, p in ipairs(Players:GetPlayers()) do check(snapshot(p).round.participating, "real client privacy/participation " .. p.Name) end
    local owner, guest, staff, spy, agent = role("Owner"), role("Guest"), role("Staff"), role("Spy"), role("CounterAgent")
    move(guest, Vector3.new(3, 4, 34))
    social(guest, "Grant", spy.UserId)
    check(rt.social.policy.issued == 0, "non-owner denied even at console")
    move(owner, Vector3.new(0, 4, -16)); social(owner, "Grant", guest.UserId)
    check(rt.social.policy.issued == 0, "remote owner grant denied from afar")
    move(owner, Vector3.new(2, 4, 34)); social(owner, "Grant", guest.UserId)
    check(snapshot(guest).social.passSeconds > 0, "owner grants named participant via real remote")
    prompt(guest, "PassReader", "Приложить пропуск", Vector3.new(3, 4, 36))
    check(not rt.world.studyDoor.CanCollide and rt.social.policy.traces.Reader ~= nil, "pass opens shared access and leaves anonymous trace")
    move(guest, Vector3.new(-8, 4, 60)) -- clear the reader's line of sight for the next participant
    prompt(agent, "PassReader", "Проверить изменение", Vector3.new(3, 4, 36))
    check(string.find(invoke(agent, {kind = "LastNotice"}), "Считыватель") ~= nil, "agent reads temporal trace through real prompt")
    prompt(guest, "SocialParcel", "Подобрать", Vector3.new(-8, 4, 60))
    check(rt.social.policy:holding(guest.UserId) == "Parcel" and rt.social.policy.traces.Collection, "guest takes collection and leaves second physical trace")
    move(staff, Vector3.new(-12, 4, 60)); social(guest, "Offer", staff.UserId); social(staff, "Accept", guest.UserId)
    check(rt.social.policy:holding(staff.UserId) == "Parcel" and not rt.social.policy:holding(guest.UserId), "consensual near transfer has one carrier")
    move(spy, Vector3.new(20, 4, -16)); social(staff, "Offer", spy.UserId)
    check(rt.social.policy.offers[spy.UserId] == nil, "no remote-distance transfer")
    prompt(staff, "StudyEgress", "Выйти в холл", Vector3.new(3, 4, 45))
    check(not rt.world.studyDoor.CanCollide, "guest/staff cannot be trapped by absent owner")
    prompt(staff, "CollectionDelivery", "Передать экспонат", Vector3.new(-17, 4, 10))
    check(rt.social.policy.deliveries[staff.UserId] and rt.profiles.round[staff.UserId].actions.Collection, "verified physical delivery earns activity once")
    prompt(guest, "SocialCloth", "Подобрать", Vector3.new(17, 4, 10))
    prompt(guest, "FabricTrace", "Оставить ткань", Vector3.new(-23, 4, 58))
    check(rt.social.policy.traces.Fabric and not rt.social.policy:holding(guest.UserId), "guest creates plausible anonymous false trace with real hold")
    move(guest, Vector3.new(-24, 4, 52)) -- leave the window approach clear for the subsequent spy
    local heldUntil = rt.social.policy.traces.Fabric
    rt.rounds.policy.elapsed = math.max(rt.rounds.policy.elapsed, 31)
    check(rt.rounds:callCouncil(owner), "owner council remains functional")
    local before = rt.scope:now(); task.wait(2)
    check(rt.scope:now() == before and rt.social.policy.traces.Fabric == heldUntil, "council pauses resource and trace timers")
    social(guest, "Signal", "Here")
    check(not rt.social.marks[guest.UserId], "council blocks active signals")
    rt.rounds.policy.remaining = 0.2
    waitFor(function() return rt.rounds.policy.phase == "Active" end, 3)
    social(guest, "Signal", "Here")
    check(rt.social.marks[guest.UserId] ~= nil, "silent context sign visible in world")
    -- One spy still has an independent route; no owner or helper required.
    prompt(spy, "StudyWindow", "Открыть окно", Vector3.new(-23, 4, 58))
    check(not rt.world.studyWindow.CanCollide, "independent spy route preserved")
    prompt(spy, "DocumentSafe", "Осмотреть", Vector3.new(0, 4, 61))
    check(rt.dossier:has(spy), "old safe theft preserved")
    prompt(spy, "EstateExit", "Покинуть особняк", Vector3.new(0, 4, -24))
    check(rt.rounds.policy.phase == "Results" and rt.rounds.policy.result.winner == "Spy", "real prompt finishes exactly one team result")
    rt.rounds.policy.remaining = 240 -- fixture holds social phase for UI/reconnect checks
    for index, p in ipairs(Players:GetPlayers()) do p.Character:PivotTo(CFrame.new((index - 3) * 4, 4, -12)) end
    local result = snapshot(guest)
    check(#result.publicStyles == 5, "all five real clients see public cosmetic surface")
    for _, style in ipairs(result.publicStyles) do
        if style.id == first.UserId then check(style.title == "Supporter", "other participant sees chosen paid style without private account fields") end
    end
    local id, purchase = account(guest), "M5-engine-receipt"
    commerceAdapter.faults["Commerce_" .. id] = {"after", "before", "before"}
    local info = {PlayerId = id, ProductId = 202, PurchaseId = purchase}
    check(market.receipt(info) == "NotProcessedYet", "real service defers ambiguous fake storage response")
    check(market.receipt(info) == "PurchaseGranted" and market.receipt(info) == "PurchaseGranted", "service receipt retry confirmed")
    check(snapshot(guest).commerce.charges == 1, "one cosmetic charge despite duplicate receipt")
    commerce(guest, "Effect")
    check(snapshot(guest).commerce.charges == 0, "charge consumed once through real remote")
    waitFor(function() return rt.commerce.effects[guest] ~= nil end, 15)
    check(snapshot(owner).publicStyles ~= nil, "nearby social effect available to other real client")
    waitFor(function() return rt.commerce.policy.accounts[id].effect.complete end, 15)
    check(market.receipt(info) == "PurchaseGranted" and snapshot(guest).commerce.charges == 0, "consumed purchase cannot be recredited")
    local token = rt.profiles:entry(guest).token
    rt.profiles:remove(guest); rt.profiles:add(guest)
    rt.commerce:remove(guest); rt.commerce:add(guest)
    waitFor(function() local e2 = rt.profiles:entry(guest); return e2 and e2.status == "Ready" and e2.token ~= token end, 20)
    check(snapshot(guest).commerce.charges == 0, "M4.1 profile reconnect does not duplicate paid charge")
    commerce(guest, "Open")
    check(telemetry.Join == 5 and telemetry.ShopOpen == 1 and telemetry.Offer == nil and telemetry.Purchase ~= nil, "finite telemetry test stub; no real dashboard claim")
    for _, p in ipairs(Players:GetPlayers()) do invoke(p, {kind = "Manual"}) end
    print("M5 FIVE CLIENTS PASS: inspect K shop and visible social status; DataStore NOT TESTED / paid shop DISABLED in production")
    task.wait(60)
    rt.rounds.policy.remaining = 0.2
    waitFor(function() return rt.rounds.policy.phase == "Waiting" or rt.rounds.policy.phase == "Countdown" end, 5)
    check(rt.social.policy.issued == 0 and next(rt.social.policy.traces) == nil and not rt.dossier:has(spy), "full round reset")
    print("M5 STUDIO PASS: five real clients, no chat, fake commerce, public whitelist, reset")
    print("M5 EIGHT CLIENTS: add THREE clients now")
    waitFor(function() return #Players:GetPlayers() == 8 end, 300, "optional eight-client extension")
    rt.rounds.policy.remaining = 1
    waitFor(function() return rt.rounds.policy.phase == "Active" end, 5)
    local spies, agents = {}, 0
    for _, p in ipairs(Players:GetPlayers()) do
        check(snapshot(p).round.participating, "eight-client participant privacy " .. p.Name)
        if rt.roles:get(p) == "Spy" then table.insert(spies, p) end
        if rt.roles:get(p) == "CounterAgent" then agents += 1 end
    end
    check(#spies == 2 and agents == 2, "eight real clients use live M5 team matrix")
    spies[1]:Kick("M5 isolated integration: disconnect one spy")
    waitFor(function() return not rt.rounds.policy.participants[spies[1].UserId] end, 8)
    check(rt.rounds.policy.phase == "Active", "actual client disconnect leaves second spy in active game")
    prompt(spies[2], "StudyWindow", "Открыть окно", Vector3.new(-23, 4, 58))
    prompt(spies[2], "DocumentSafe", "Осмотреть", Vector3.new(0, 4, 61))
    prompt(spies[2], "EstateExit", "Покинуть особняк", Vector3.new(0, 4, -24))
    check(rt.rounds.policy.phase == "Results" and rt.rounds.policy.result.winner == "Spy", "remaining spy extracts without teammate")
    print("M5 EIGHT CLIENTS PASS: real disconnect and surviving spy extraction")
end
local ok, err = xpcall(run, debug.traceback)
if not ok then warn("M5 STUDIO FAIL", err) end
