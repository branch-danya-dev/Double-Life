local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
assert(game:GetService("RunService"):IsStudio(),"Studio only")
local modules=game.ServerScriptService.DoubleLifeServer
local Schema=require(modules.ProfileSchema)
local Config=require(RS.DoubleLifeShared.Config)
local driver=Instance.new("RemoteFunction"); driver.Name,driver.Parent="M6TestDriver",RS
local audit=Instance.new("RemoteFunction"); audit.Name,audit.Parent="M8AuditDriver",RS
local rt=require(modules.Game).start({prologue=false,adapter=require(script.Parent.MemoryStore).new(Schema.copy)})
local startAllowed,naturalTick=false,rt.rounds.policy.tick
rt.rounds.policy.tick=function(self,dt,population) return naturalTick(self,dt,if startAllowed then population else 0) end
rt.roles.random={NextInteger=function(_,_,high) return high end}
local function check(ok,msg) assert(ok,msg); print("M8 PASS",msg) end
local function waitFor(f,seconds,why)
    local deadline=os.clock()+seconds
    repeat if f() then return end; task.wait(0.1) until os.clock()>deadline
    error(why or "condition timed out")
end
local function invoke(p,c,transport)
    local done,ok,value=false,false,nil
    task.spawn(function() ok,value=pcall(function() return (transport or driver):InvokeClient(p,c) end); done=true end)
    waitFor(function() return done end,120,"client "..p.Name.." "..(if type(c)=="table" then c.kind else c))
    assert(ok,tostring(value)); return value
end
local function walk(p,id,offset)
    local point=if rt.world.objects[id] then rt.world:approach(id) else rt.world:point(id)
    local result=invoke(p,{kind="Walk",position=point+(offset or Vector3.zero)})
    print(string.format("M8 WALK %s %s %.2fs %.1fstuds",p.Name,id,result.seconds,result.distance))
    return result
end
local function prompt(p,id,action,alreadyNear)
    if not alreadyNear then walk(p,id) end
    local part=rt.world.objects[id] or rt.world.map:FindFirstChild(id,true)
    assert(part,"prompt object "..id)
    invoke(p,{kind="Prompt",part=part.Name,action=action})
end
local function action(p,kind,a,target)
    return invoke(p,{kind=kind,action=a,target=target,roundId=rt.rounds.policy.roundId})
end
local function snapshot(p) return invoke(p,{kind="Snapshot"}) end
local function role(name)
    for _,p in ipairs(Players:GetPlayers()) do if rt.roles:get(p)==name then return p end end
    error("missing role "..name)
end
local function together(jobs)
    local pending=#jobs; local errors={}
    for _,job in ipairs(jobs) do task.spawn(function() local ok,err=pcall(job); if not ok then table.insert(errors,err) end; pending-=1 end) end
    waitFor(function() return pending==0 end,150,"parallel physical walkthrough")
    assert(#errors==0,table.concat(errors,"\n"))
end
local function metrics(label)
    local parts=0
    for _,p in ipairs(rt.world.level:GetDescendants()) do if p:IsA("BasePart") then parts+=1 end end
    print("M8 METRICS",label,Http:JSONEncode({parts=parts,instances=#rt.world.level:GetDescendants(),world=rt.world.metrics,game=rt.metrics,
        guard=rt.guard.mover.metrics,service=rt.requests.npc.metrics,players=#Players:GetPlayers()}))
end
local static,oldMap,oldScope
local function beginRound()
    static,oldMap,oldScope=rt.world.static,rt.world.map,rt.scope
    startAllowed=true
    waitFor(function() return rt.rounds.policy.phase=="Active" end,20,"natural countdown")
    check(rt.world.static==static and oldMap.Parent==nil and not oldScope.alive,"static identity preserved; old round destroyed")
    for _,p in ipairs(Players:GetPlayers()) do check(snapshot(p).round.participating,"real participant privacy "..p.Name) end
end
local function endRound(winner)
    startAllowed=false
    waitFor(function() return rt.rounds.policy.phase=="Results" end,10,"round outcome")
    check(rt.rounds.policy.result.winner==winner,"outcome "..winner)
    metrics(winner)
    for _,p in ipairs(Players:GetPlayers()) do invoke(p,{kind="Manual"}) end
    waitFor(function() return rt.rounds.policy.phase=="Waiting" end,20,"natural results reset")
    check(rt.world.static==static and rt.social.policy.issued==0 and next(rt.social.policy.traces)==nil,"round reset without rebuilding level")
end
local function reports(label)
    for _, p in ipairs(Players:GetPlayers()) do
        local result = invoke(p, "Report", audit)
        print("M8 CLIENT METRICS", label, p.Name, Http:JSONEncode(result))
        check(result.chat == "PASS", "chat absent in " .. label .. " " .. p.Name)
    end
    metrics(label)
end
local function cohort(n)
    print("M8 COHORT WAIT", n, "start exactly this many local clients")
    waitFor(function() return #Players:GetPlayers() >= n end, 600, "cohort " .. n)
    task.wait(10)
    check(#Players:GetPlayers() == n, "exact cohort " .. n)
    for _, p in ipairs(Players:GetPlayers()) do invoke(p, "Reset", audit) end
    beginRound()
end
local function extract(spy)
    prompt(spy, "StudyWindow", "Открыть окно")
    local start = os.clock()
    prompt(spy, "Safe", "Осмотреть")
    check(rt.dossier:has(spy), "independent path works without owner permission")
    local carry = os.clock()
    prompt(spy, "Social.Egress", "Выйти в холл")
    prompt(spy, "MainExit", "Покинуть особняк")
    print(string.format("M8 ROUTE extraction %.2fs window-to-exit %.2fs", os.clock()-carry, os.clock()-start))
    check(os.clock()-carry < Config.DOSSIER_CARRY_SECONDS, "real carry fits 60 seconds")
end
local function rewards(label)
    task.wait(1)
    for _, p in ipairs(Players:GetPlayers()) do
        local s = snapshot(p)
        print("M8 REWARD", label, p.Name, rt.roles:get(p), Http:JSONEncode(s.profile.reward or {}))
    end
end
local function run()
    local spy, guest, owner
    local staffOnly = game.ServerScriptService:GetAttribute("M8StaffOnly") == true
    if not staffOnly then
    cohort(3)
    spy, guest, owner = role("Spy"), role("Guest"), role("Owner")
    prompt(guest, "Painting1", "Осмотреть")
    action(guest, "Social", "Signal", "Help")
    check(rt.social.marks[guest.UserId] ~= nil, "guest can communicate without chat")
    extract(spy)
    rewards("3")
    check(snapshot(owner).profile.reward.reason == "InsufficientActivity", "idle owner cannot farm tokens")
    reports("3 Results")
    endRound("Spy")
    print("M8 THREE FULL ROUND PASS")
    end

    cohort(5)
    spy, guest, owner = role("Spy"), role("Guest"), role("Owner")
    local staff = role("Staff")
    local staffBefore = snapshot(staff).profile
    together({function() walk(guest, "Service.Target2") end, function() walk(staff, "Service.Pantry") end})
    prompt(guest, "Service.Target2", "Заказать сок сюда", true)
    prompt(staff, "Service.Pantry", "Принять заказ / взять сок", true)
    prompt(staff, "Service.Pantry", "Принять заказ / взять сок", true)
    check(not rt.profiles.round[staff.UserId].actions.ServicePickup, "pickup waits for delivery confirmation")
    walk(guest, "Service.Target2", Vector3.new(0,0,6))
    prompt(staff, "Service.Target2", "Доставить сок")
    check((rt.requests.ledger.scores[staff.UserId] or 0) > 0, "staff completes upstairs delivery without speech")
    prompt(staff, "Service.Target2", "Доставить сок", true)
    check(rt.requests.ledger.scores[staff.UserId] == Config.REQUEST_POINTS, "repeat delivery prompt cannot duplicate session points")
    for _, id in ipairs({"Painting1", "Painting2", "Painting3"}) do prompt(guest, id, "Осмотреть") end
    reports("5 Active")
    extract(spy)
    rewards("5")
    check(snapshot(staff).profile.reward.reason == "Awarded", "one completed staff job receives progression")
    check(snapshot(staff).profile.reward.tokens == 19, "staff receives ordinary participation tokens")
    local staffAfter = snapshot(staff).profile
    check(staffAfter.reputationXp - staffBefore.reputationXp == 50 and staffAfter.tokens - staffBefore.tokens == 19
        and staffAfter.stats.played - staffBefore.stats.played == 1, "one delivery settles once for 50 XP and 19 tokens")
    check(snapshot(guest).profile.reward.reason == "Awarded", "active guest earns persistent reward")
    check(snapshot(owner).profile.reward.reason == "InsufficientActivity", "AFK owner no reward after full round")
    endRound("Spy")
    print("M8 FIVE FULL ROUND PASS")
    if staffOnly then
        print("M8 STAFF REGRESSION PASS")
        -- A second real round reproduces the exploit sequence without delivery.
        -- Only the focused fixture runs it; the full M8 cohort sequence is unchanged.
        cohort(5)
        spy, guest, staff = role("Spy"), role("Guest"), role("Staff")
        staffBefore = snapshot(staff).profile
        together({function() walk(guest, "Service.Target2") end, function() walk(staff, "Service.Pantry") end})
        prompt(guest, "Service.Target2", "Заказать сок сюда", true)
        prompt(staff, "Service.Pantry", "Принять заказ / взять сок", true)
        prompt(staff, "Service.Pantry", "Принять заказ / взять сок", true)
        prompt(staff, "Service.Pantry", "Принять заказ / взять сок", true)
        local abandoned = rt.requests.ledger:assigned(staff.UserId)
        check(abandoned and abandoned.state == "Carrying", "negative case really carries an undelivered order")
        prompt(staff, "Painting1", "Осмотреть")
        walk(staff, "Social.TraceSpot")
        walk(staff, "Service.Pantry")
        local record = rt.profiles.round[staff.UserId]
        waitFor(function() return record.active >= 45 end, 50, "real activity threshold")
        check(record.moving >= 12, "negative case has enough real movement")
        check(record.actions.Painting and not record.actions.ServicePickup and not record.actions.Delivery,
            "painting plus abandoned tray cannot fabricate completed work")
        print("M8 STAFF NEGATIVE ACTIVITY", Http:JSONEncode({active=record.active,moving=record.moving,actions=record.actions}))
        extract(spy)
        rewards("5 undelivered")
        staffAfter = snapshot(staff).profile
        check(staffAfter.reward.reason == "InsufficientActivity", "undelivered pickup plus painting receives no reward")
        check(staffAfter.tokens == staffBefore.tokens and staffAfter.reputationXp == staffBefore.reputationXp
            and staffAfter.stats.played == staffBefore.stats.played, "negative round does not change persistent progress")
        endRound("Spy")
        reports("5 undelivered reset")
        print("M8 STAFF DELIVERY GATE PASS: successful and undelivered rounds; real timers, movement, FakeMemory")
        return
    end

    cohort(8)
    local spies, agents = {}, {}
    for _, p in ipairs(Players:GetPlayers()) do
        if rt.roles:get(p) == "Spy" then table.insert(spies,p) elseif rt.roles:get(p) == "CounterAgent" then table.insert(agents,p) end
    end
    check(#spies == 2 and #agents == 2, "two spies/two agents at eight")
    owner, guest = role("Owner"), role("Guest")
    together({function() walk(owner, "OwnerConsole") end, function() walk(spies[1], "StudyWindow") end})
    prompt(spies[1], "StudyWindow", "Открыть окно", true)
    prompt(spies[1], "Safe", "Осмотреть")
    waitFor(function() return rt.rounds.policy.elapsed >= 30 end, 35)
    prompt(owner, "OwnerConsole", "Созвать собрание", true)
    check(rt.rounds.policy.phase == "Council", "council starts")
    local paused = rt.scope:now()
    task.wait(2)
    check(paused == rt.scope:now() and rt.dossier:has(spies[1]), "carry and events paused")
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= spies[1] then invoke(p, {kind="Vote",roundId=rt.rounds.policy.roundId,target=spies[1].UserId}) end
    end
    waitFor(function() return rt.rounds.policy.phase == "Active" end, 30)
    check(not rt.dossier:has(spies[1]) and rt.rounds.policy.detained ~= nil, "silent majority recovers dossier")
    rt.events:setBlackout(true)
    prompt(guest, "Service.Target2", "Заказать сок сюда")
    waitFor(function() return (rt.requests.received[guest.UserId] or 0) > 0 end, 75, "NPC delivers in blackout")
    rt.events:setBlackout(false)
    check(rt.requests.npc.metrics.arrivals > 0, "NPC reaches upper floor")
    -- The searched spy is still in the locked study. Use the normal exit button;
    -- asking Pathfinding to cross a closed door would be a driver error.
    prompt(spies[1], "Social.Egress", "Выйти в холл")
    local jobs = {}
    for i, p in ipairs(Players:GetPlayers()) do
        table.insert(jobs, function() walk(p, if i % 2 == 0 then "Social.TraceSpot" else "Events.Stage") end)
    end
    together(jobs)
    reports("8 Active")
    -- Real configured-duration timeout; no acceleration or fabricated server outcome.
    while rt.rounds.policy.phase == "Active" do
        print("M8 NATURAL TIMEOUT WAIT", math.ceil(rt.rounds.policy.remaining))
        task.wait(math.min(30, rt.rounds.policy.remaining + 0.1))
    end
    rewards("8")
    endRound("Defenders")
    print("M8 EIGHT FULL ROUND PASS")

    cohort(15)
    spies, jobs = {}, {}
    for i, p in ipairs(Players:GetPlayers()) do
        if rt.roles:get(p) == "Spy" then table.insert(spies,p) end
        table.insert(jobs, function() walk(p, if i % 2 == 0 then "Service.Target2" else "Social.TraceSpot", Vector3.new((i%3-1)*3,0,0)) end)
    end
    check(#spies == 2, "two spies in full lobby")
    together(jobs)
    reports("15 simultaneous routes")
    extract(spies[2])
    check(rt.rounds.policy.result.winner == "Spy", "second spy wins for team")
    rewards("15")
    endRound("Spy")
    reports("15 Waiting reset")
    print("M8 STUDIO SUITE PASS: four natural rounds 3/5/8/15; chat, AFK rewards, counterplay, NPC and reset")
end
local ok, err = xpcall(run, debug.traceback)
if not ok then warn("M8 STUDIO FAIL", err) end
