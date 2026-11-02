local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
assert(game:GetService("RunService"):IsStudio(),"Studio only")
local modules=game.ServerScriptService.DoubleLifeServer
local Schema=require(modules.ProfileSchema)
local Config=require(RS.DoubleLifeShared.Config)
local driver=Instance.new("RemoteFunction"); driver.Name,driver.Parent="M6TestDriver",RS
local rt=require(modules.Game).start({adapter=require(script.Parent.MemoryStore).new(Schema.copy)})
local startAllowed,naturalTick=false,rt.rounds.policy.tick
rt.rounds.policy.tick=function(self,dt,population) return naturalTick(self,dt,if startAllowed then population else 0) end
rt.roles.random={NextInteger=function(_,_,high) return high end}
local function check(ok,msg) assert(ok,msg); print("M6 PASS",msg) end
local function waitFor(f,seconds,why)
    local deadline=os.clock()+seconds
    repeat if f() then return end; task.wait(0.1) until os.clock()>deadline
    error(why or "condition timed out")
end
local function invoke(p,c)
    local done,ok,value=false,false,nil
    task.spawn(function() ok,value=pcall(function() return driver:InvokeClient(p,c) end); done=true end)
    waitFor(function() return done end,120,"client "..p.Name.." "..c.kind)
    assert(ok,tostring(value)); return value
end
local function walk(p,id,offset)
    local point=if rt.world.objects[id] then rt.world:approach(id) else rt.world:point(id)
    local result=invoke(p,{kind="Walk",position=point+(offset or Vector3.zero)})
    print(string.format("M6 WALK %s %s %.2fs %.1fstuds",p.Name,id,result.seconds,result.distance))
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
    print("M6 METRICS",label,Http:JSONEncode({parts=parts,instances=#rt.world.level:GetDescendants(),world=rt.world.metrics,game=rt.metrics,
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
local function run()
    waitFor(function() return #Players:GetPlayers()>=5 end,300,"launch five real clients")
    task.wait(8)
    local first=Players:GetPlayers()[1]
    check(#Players:GetPlayers()==5,"five real clients initial cohort")
    check(not snapshot(first).commerce.enabled,"shop off; no real storage/payment APIs")
    local protected=game:GetService("PathfindingService"):CreatePath({AgentRadius=2,AgentHeight=6,AgentCanJump=true})
    protected:ComputeAsync(rt.world:spawn(1),rt.world:approach("Safe"))
    check(protected.Status~=Enum.PathStatus.Success,"closed study has no free navigation bypass")
    protected:Destroy()
    -- Full public topology walked before roles; no test-only teleport.
    for _,id in ipairs({"Painting1","Painting2","Painting3","Service.Pantry","Service.Target1","Service.Target2",
        "Social.TraceSpot","Guard.Window","Events.Console","Events.Bell","Social.Delivery","Relic.Reading","MainExit"}) do
        walk(first,id)
        if string.find(id,"Painting") then prompt(first,id,"Осмотреть",true) end
    end
    check(rt.dossier:count(first)==3,"all paintings reachable and interactive while waiting")
    prompt(first,"Service.Target2","Заказать сок сюда")
    check(rt.requests.ledger.requests[first.UserId]~=nil,"upstairs request accepted through real prompt")
    task.spawn(function()
        for _=1,15 do
            if (rt.requests.received[first.UserId] or 0)>0 then break end
            print("M6 NPC ROUTE",tostring(rt.requests.npc.root.Position),Http:JSONEncode(rt.requests.npc.metrics),Http:JSONEncode(rt.requests.ledger.requests[first.UserId]))
            task.wait(5)
        end
    end)
    waitFor(function() return (rt.requests.received[first.UserId] or 0)>0 end,75,"NPC multi-level delivery")
    check(rt.requests.npc.metrics.arrivals>0,"NPC physically delivered upstairs")
    metrics("Waiting topology")
    beginRound()
    local owner,spy,agent,staff,guest=role("Owner"),role("Spy"),role("CounterAgent"),role("Staff"),role("Guest")
    together({function() walk(owner,"OwnerConsole") end,function() walk(guest,"Social.PassReader") end,
        function() walk(agent,"Service.Target2") end,function() walk(staff,"Service.Pantry") end,
        function() walk(spy,"Social.Cloth") end})
    prompt(owner,"OwnerConsole","Сменить зону патруля",true)
    check(rt.guard.policy.zone=="Foyer","owner sends patrol between floors")
    action(owner,"Social","Grant",guest.UserId)
    prompt(guest,"Social.PassReader","Приложить пропуск",true)
    check(not rt.world.studyDoor.CanCollide and rt.social.policy.traces.Reader,"named pass opens legal route")
    together({function()
    prompt(agent,"Service.Target2","Заказать сок сюда",true)
    check(rt.requests.ledger.requests[agent.UserId]~=nil,"staff customer request accepted")
    prompt(staff,"Service.Pantry","Принять заказ / взять сок",true)
    check(rt.requests.ledger:assigned(staff.UserId)~=nil,"staff accepts order before NPC")
    prompt(staff,"Service.Pantry","Принять заказ / взять сок",true)
    check(rt.requests.ledger:assigned(staff.UserId).state=="Carrying","staff picks up physical tray")
    -- Leave the interaction approach clear: characters still block prompt line of sight.
    walk(agent,"Service.Target2",Vector3.new(0,0,6))
    prompt(spy,"SocialCloth","Подобрать",true)
    end,function()
    -- Enter immediately during the real ten-second pass opening; do not wait for unrelated roles.
    walk(guest,"Social.ParcelHome"); prompt(guest,"SocialParcel","Подобрать",true)
    check(rt.social.policy:holding(guest.UserId)=="Parcel","guest enters and takes physical collection")
    action(guest,"Social","Drop")
    check(rt.social.parts.Parcel.Position.Y>18 and (rt.social.parts.Parcel.Position-guest.Character.HumanoidRootPart.Position).Magnitude<5,"parcel drops on actual upper floor")
    prompt(guest,"SocialParcel","Подобрать",true)
    end})
    together({function() prompt(staff,"Service.Target2","Доставить сок") end,
        function() prompt(guest,"Social.Egress","Выйти в холл"); prompt(guest,"Social.Delivery","Передать экспонат") end,
        function() prompt(spy,"Social.TraceSpot","Оставить ткань") end})
    check(rt.social.policy.deliveries[guest.UserId],"collection carried downstairs within 45 active seconds")
    check((rt.requests.ledger.scores[staff.UserId] or 0)>0,"staff walked multi-level delivery")
    check((rt.social.policy.plants[spy.UserId] or 0)>0,"cloth physically planted on terrace")
    prompt(agent,"Social.PassReader","Проверить изменение")
    prompt(agent,"Social.TraceSpot","Проверить изменение")
    action(guest,"Social","Signal","Help")
    check(rt.social.marks[guest.UserId]~=nil,"no-chat sign in new scene")
    together({function() walk(owner,"Events.Console") end,function() walk(guest,"Events.Stage") end})
    prompt(owner,"Events.Console","Выбрать мероприятие",true)
    invoke(owner,{kind="Event",action="Start",event="Music",roundId=rt.rounds.policy.roundId})
    waitFor(function() return rt.events.policy.phase=="Running" end,7)
    invoke(guest,{kind="Dance",position=rt.world:approach("Events.Stage")})
    check(rt.events.policy.awards[guest.UserId]~=nil,"music event on physical floor")
    prompt(spy,"StudyWindow","Открыть окно")
    local operation=os.clock()
    prompt(spy,"Safe","Осмотреть")
    check(rt.dossier:has(spy),"solo spy entered independent window")
    local carried=os.clock()
    prompt(agent,"ForensicLog","Изучить журнал")
    walk(agent,"Evidence.Home")
    prompt(agent,"BrokenSeal","Подобрать улику",true)
    check(rt.evidence.holder==agent.UserId,"agent physically collects seal upstairs")
    walk(agent,"ForensicLog")
    invoke(agent,{kind="DropEvidence",roundId=rt.rounds.policy.roundId})
    check(rt.evidence.part and (rt.evidence.part.Position-agent.Character.HumanoidRootPart.Position).Magnitude<5,"seal drops on actual upper floor rather than old bounds")
    prompt(spy,"Social.Egress","Выйти в холл")
    prompt(spy,"MainExit","Покинуть особняк")
    print(string.format("M6 DOSSIER WALK extraction %.2fs; window-to-exit %.2fs",os.clock()-carried,os.clock()-operation))
    endRound("Spy")
    print("M6 FIVE CLIENTS PASS; add clients for EIGHT+ round now")
    waitFor(function() return #Players:GetPlayers()>=8 end,300,"add at least three clients")
    task.wait(8)
    beginRound()
    local participants=#Players:GetPlayers()
    local spies,agents={},{}
    for _,p in ipairs(Players:GetPlayers()) do
        if rt.roles:get(p)=="Spy" then table.insert(spies,p) elseif rt.roles:get(p)=="CounterAgent" then table.insert(agents,p) end
    end
    check(#spies==2 and #agents==2,"two spies and two agents in live large round")
    owner,guest=role("Owner"),role("Guest")
    rt.events.choose=function(_,high) return high end -- deterministic relic location; no placement/movement override
    together({function() walk(owner,"Events.Console") end,function() walk(guest,"Relic.Archive") end,
        function() walk(spies[1],"StudyWindow") end,function() walk(agents[1],"OwnerConsole",Vector3.new(6,0,0)) end})
    prompt(owner,"Events.Console","Выбрать мероприятие",true)
    invoke(owner,{kind="Event",action="Start",event="Relic",roundId=rt.rounds.policy.roundId})
    waitFor(function() return rt.events.relic~=nil end,7)
    prompt(guest,"EventRelic","Взять реликвию",true)
    local relicStart=os.clock()
    prompt(guest,"Events.Pedestal","Вернуть реликвию")
    check(rt.events.policy.delivered,"relic walked downstairs before timeout")
    print(string.format("M6 RELIC WALK %.2fs",os.clock()-relicStart))
    prompt(spies[1],"StudyWindow","Открыть окно",true)
    prompt(spies[1],"Safe","Осмотреть")
    check(rt.dossier:has(spies[1]),"dossier before council")
    walk(owner,"OwnerConsole")
    prompt(owner,"OwnerConsole","Созвать собрание",true)
    check(rt.rounds.policy.phase=="Council","real owner console calls council")
    local paused=rt.scope:now(); task.wait(3)
    check(rt.scope:now()==paused and rt.dossier:has(spies[1]),"council pauses carry, world and NPCs")
    for _,p in ipairs(Players:GetPlayers()) do if p~=spies[1] then invoke(p,{kind="Vote",roundId=rt.rounds.policy.roundId,target=spies[1].UserId}) end end
    waitFor(function() return rt.rounds.policy.phase=="Active" end,30)
    check(not rt.dossier:has(spies[1]) and rt.rounds.policy.detained~=nil,"majority search recovers dossier without elimination")
    -- The remaining time is real seven-minute time. Exercise NPC/blackout and walking while defenders hold.
    rt.events:setBlackout(true)
    walk(agents[1],"Events.Bell"); walk(agents[1],"Service.Target2")
    rt.events:setBlackout(false)
    check(#rt.events.scene.lamps>=10,"blackout retains permanent route lights across both floors")
    prompt(agents[1],"Service.Target2","Заказать сок сюда",true)
    waitFor(function() return (rt.requests.received[agents[1].UserId] or 0)>0 end,75,"large round NPC delivery")
    local nextReport=0
    while rt.rounds.policy.phase=="Active" do
        if os.clock()>nextReport then print("M6 DEFENDERS WAIT",math.ceil(rt.rounds.policy.remaining)); nextReport=os.clock()+30 end
        task.wait(1)
    end
    endRound("Defenders")
    print("M6 LARGE CLIENTS PASS",participants,"two sequential natural rounds; both outcomes")
    print("M6 OPTIONAL LOAD: add to 12-15 clients within 180 seconds")
    waitFor(function() return #Players:GetPlayers()>=12 end,180,"optional 12+ session")
    task.wait(8)
    beginRound()
    local jobs={}
    for index,p in ipairs(Players:GetPlayers()) do
        table.insert(jobs,function() walk(p,if index%2==0 then "Service.Target2" else "Social.TraceSpot",Vector3.new((index%3-1)*3,0,0)) end)
    end
    together(jobs); metrics("12-15 simultaneous routes")
    print("M6 LOAD PASS",#Players:GetPlayers())
    for _,p in ipairs(Players:GetPlayers()) do invoke(p,{kind="Manual"}) end
    print("M6 STUDIO SUITE PASS; inspect first-person, J/K and touch emulation; then End Session")
end
local ok,err=xpcall(run,debug.traceback)
if not ok then warn("M6 STUDIO FAIL",err) end
