assert(game:GetService("RunService"):IsStudio(),"Studio only")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local modules=game.ServerScriptService.DoubleLifeServer
local Rig=require(modules.MimicRig)
local driver=Instance.new("RemoteFunction"); driver.Name,driver.Parent="M6TestDriver",RS
local audit=Instance.new("RemoteFunction"); audit.Name,audit.Parent="M8AuditDriver",RS
local view=Instance.new("RemoteFunction"); view.Name,view.Parent="M112ContextView",RS
local Identity=require(modules.MimicIdentity)
local CrowdPolicy=require(modules.MimicCrowdPolicy)
local rt=require(modules.Game).start({adapter=require(script.Parent.MemoryStore).new(require(modules.ProfileSchema).copy)})
rt.mimics.nextCreate=math.huge
rt.roles.random={NextInteger=function(_,_,high) return high end}
local function check(ok,msg) assert(ok,msg); print("M112 PASS",msg) end
local function waitFor(f,seconds,msg)
    local deadline=os.clock()+seconds
    repeat if f() then return end; task.wait(0.1) until os.clock()>deadline
    error(msg or "timeout")
end
local function invoke(p,c,remote,timeout)
    local done,ok,value=false,false,nil
    task.spawn(function() ok,value=pcall(function() return (remote or driver):InvokeClient(p,c) end); done=true end)
    waitFor(function() return done end,timeout or 120,"client response")
    assert(ok,tostring(value)); return value
end
local function capture(p,a,label)
    -- Hold the next AI job after a real arrival; never reposition a body for evidence.
    waitFor(function() return not a.working end,40,"capture waits for physical arrival")
    local nextAt=a.next; a.next=math.huge; a.mover:stop()
    print("M112 CAPTURE READY",label)
    invoke(p,{kind="Manual"})
    local result=invoke(p,{model=a.mover.model,label=label},view,600)
    a.next=nextAt
    check(result.r15 and result.tracks>0 and result.clothing,"client R15 clothing and playing tracks "..label)
end
local function actor(context,predicate)
    for _,a in pairs(rt.mimics.values) do if a.context==context and (not predicate or predicate(a)) then return a end end
end
local function auditRigs()
    local used={}; local n=0
    for _,a in pairs(rt.mimics.values) do
        check(Rig.validate(a.mover.model,a.preset),"complete R15 "..a.actor.id)
        check(a.mover.motion:ready(),"ready cached tracks "..a.actor.id)
        used[a.appearanceContext]=used[a.appearanceContext] or {}
        check(not used[a.appearanceContext][a.preset],"distinct neighbours "..a.actor.id)
        used[a.appearanceContext][a.preset]=true; n+=1
        check(a.actor.name==a.mover.model:GetAttribute("MimicName") and a.mover.label.Text==a.actor.name,"same clean nickname in actor and plate")
        check(not Identity.names(Players:GetPlayers(),{})[Identity.key(a.actor.name)],"no human nickname impersonation")
        for _,look in ipairs(rt.mimics:humanLooks()) do check(not Identity.conflict(Identity.preset(a.preset),look),"no human outfit clone") end
        check(a.actor.kind=="Mimic" and a.actor.role=="Guest","fictional Guest "..a.actor.id)
        check(rt.profiles.round[a.actor.id]==nil and rt.profiles.store.entries[a.actor.id]==nil,"no mimic profile "..a.actor.id)
    end
    check(Rig.metrics.live==n and Rig.metrics.tracks==6*n,"one bounded track set per live actor")
    check(Rig.metrics.maxPending<=1 and rt.mimics.metrics.maxWorkers<=2,"bounded avatar and path workers")
end
local function lesson(p)
    invoke(p,{kind="LessonReady"})
    local s=invoke(p,{kind="Snapshot"}).prologue
    invoke(p,{kind="Walk",position=s.target}); invoke(p,{kind="LessonPrompt"})
    waitFor(function() return rt.prologue.records[p].policy.step~=s.step end,5,"lesson physical step "..s.step)
end
local function prompt(p,id,action)
    invoke(p,{kind="Walk",position=if rt.world.objects[id] then rt.world:approach(id) else rt.world:point(id)})
    invoke(p,{kind="Prompt",part=rt.world:object(id).Name,action=action})
end
local function run()
    print("M112 WAIT ONE: start one client")
    waitFor(function() return #Players:GetPlayers()==1 end,120)
    local first=Players:GetPlayers()[1]
    waitFor(function() return first.Character and first.Character:FindFirstChildOfClass("Humanoid") end,20)
    local description=Rig.description(6)
    first.Character:FindFirstChildOfClass("Humanoid"):ApplyDescriptionAsync(description); description:Destroy()
    check(Identity.conflict(Identity.preset(6),rt.mimics:humanLooks()[1]),"real Player wears exact catalogue preset 6")
    rt.mimics.nextCreate=0
    waitFor(function() return actor("Prologue") and rt.mimics:count("Lobby")==rt.settings.lobbyDensity-1 end,120,"solo guide plus lobby R15s")
    check(rt.rounds.policy.phase=="Waiting","one human does not start a match")
    auditRigs(); capture(first,actor("Prologue"),"PRIVATE PROLOGUE / R15 guide")
    for _=1,7 do lesson(first) end
    local record=rt.prologue.records[first]
    check(record.policy.step==8 and record.carry==nil and record.scene.root:FindFirstChild("PracticeJuice",true),"physical upstairs delivery completed with R15 guide")
    invoke(first,{kind="Prologue",action="Lobby"})
    waitFor(function() return rt.mimics:count("Prologue")==0 end,5)
    check(record.scene==nil,"private scene and guide release tracks")
    -- Five production lobby AI approach the same interest object, around a stationary
    -- real Player. Only scheduling changes: all bodies walk using production movers.
    invoke(first,{kind="Walk",position=rt.lobby.spots[1]})
    invoke(first,{kind="Manual"})
    waitFor(function()
        local idle=true
        for _,a in pairs(rt.mimics.values) do if a.context=="Lobby" then a.next=math.huge; if a.working then idle=false end end end
        return idle
    end,65)
    local crowd={samples=0,overlaps=0,minDistance=100,minPair=100,playerDrift=0}
    local standing=first.Character.HumanoidRootPart.Position
    local monitor=game:GetService("RunService").Heartbeat:Connect(function()
        local root=first.Character.HumanoidRootPart; local all={}
        crowd.playerDrift=math.max(crowd.playerDrift,(root.Position-standing).Magnitude)
        for _,a in pairs(rt.mimics.values) do if a.context=="Lobby" then
            local distance=CrowdPolicy.distance(root.Position,a.mover.root.Position)
            crowd.samples+=1; crowd.minDistance=math.min(crowd.minDistance,distance)
            if distance<2 then
                crowd.overlaps+=1
                if not crowd.firstOverlap then
                    crowd.firstOverlap={actor=a.actor.name,player=tostring(root.Position),mimic=tostring(a.mover.root.Position),target=tostring(a.mover.destination)}
                    print('M112 CROWD OVERLAP',Http:JSONEncode(crowd.firstOverlap))
                end
            end
            for _,other in ipairs(all) do crowd.minPair=math.min(crowd.minPair,CrowdPolicy.distance(other,a.mover.root.Position)) end
            table.insert(all,a.mover.root.Position)
        end end
    end)
    for _,a in pairs(rt.mimics.values) do if a.context=="Lobby" then a.index=4; a.next=0 end end
    print("M112 CAPTURE READY LOBBY CROWD / stationary player / moving guests")
    invoke(first,{model=actor("Lobby").mover.model,label="LOBBY / stationary Player + 5 guests",center=rt.lobby.spots[1]+Vector3.new(0,0,3),wide=true},view,600)
    monitor:Disconnect()
    print("M112 CROWD METRICS",Http:JSONEncode(crowd))
    check(crowd.samples>100 and crowd.overlaps==0,"stationary player crowd has no body crossings")
    capture(first,actor("Lobby"),"LOBBY / natural stop and nameplates")
    invoke(first,{kind="Queue",action="Register"})
    print("M112 SOLO PASS: add second real client")
    waitFor(function() return #Players:GetPlayers()==2 end,600)
    local second; for _,p in ipairs(Players:GetPlayers()) do if p~=first then second=p end end
    waitFor(function() return rt.prologue:active(second) and actor("Prologue") end,60)
    waitFor(function() return rt.queue:snapshot(second).state=="MatchReady" end,15)
    invoke(second,{kind="Prologue",action="Accept"})
    waitFor(function() return rt.rounds.policy.phase=="Active" end,40)
    local owner,spy
    for _,p in ipairs(Players:GetPlayers()) do
        if rt.roles:get(p)=="Owner" then owner=p elseif rt.roles:get(p)=="Spy" then spy=p end
        local report=invoke(p,"Report",audit)
        check(report.chat=="PASS","chat disabled in actual client")
        print("M112 CLIENT METRICS",p.Name,Http:JSONEncode(report))
    end
    check(owner and spy and owner~=spy,"Owner and Spy are actual Players")
    waitFor(function() return rt.mimics:count("Match")==6 end,100,"two humans plus six R15 mimics")
    auditRigs()
    local stable={}; for id,a in pairs(rt.mimics.values) do stable[id]={a.preset,a.actor.name,a.mover.model} end
    local function arrivedGround(a) return a.mover.root.Position.Y<15 and not a.working and next(a.seen)~=nil end
    waitFor(function() return actor("Match",arrivedGround) end,90,"physical ground-floor arrival")
    capture(owner,actor("Match",arrivedGround),"MATCH / ground floor")
    waitFor(function() return actor("Match",function(a) return a.mover.root.Position.Y>20 and not a.working end) end,120,"physical upper-floor arrival")
    capture(owner,actor("Match",function(a) return a.mover.root.Position.Y>20 and not a.working end),"MATCH / upper floor")
    prompt(owner,"OwnerConsole","Созвать собрание")
    if rt.rounds.policy.phase~="Council" then
        waitFor(function() return rt.rounds.policy.elapsed>=30 end,35)
        prompt(owner,"OwnerConsole","Созвать собрание")
    end
    check(rt.rounds.policy.phase=="Council","physical council prompt")
    local snapshot=rt.rounds:snapshot(owner)
    for _,member in ipairs(snapshot.members) do
        check(not member.name:find("персонаж"),"clean council participant nickname")
        if type(member.id)=="string" then check(member.name==rt.actors:get(member.id).name,"council identity stable") end
    end
    print("M112 CAPTURE READY COUNCIL / ordinary voting UI")
    task.spawn(function() invoke(owner,{model=actor("Match").mover.model,label="COUNCIL / voting nicknames",ui=true},view,120) end)
    task.wait(1)
    for _,a in pairs(rt.mimics.values) do if a.context=="Match" then
        check(a.mover.motion.paused and a.mover.root.Anchored,"council freezes R15 animation and body")
    end end
    local paused=rt.scope:now(); task.wait(1); check(rt.scope:now()==paused,"world clock pauses")
    waitFor(function() return rt.rounds.policy.phase=="Active" end,30)
    print("M112 TWO PASS: add third real client during the round")
    waitFor(function() return #Players:GetPlayers()==3 end,600)
    local third; for _,p in ipairs(Players:GetPlayers()) do if p~=first and p~=second then third=p end end
    waitFor(function() return rt.prologue:active(third) and actor("Prologue") end,70)
    check(not rt.rounds.policy.participants[third.UserId],"late visitor has private prologue outside active match")
    waitFor(function() return rt.mimics:count("Lobby")==rt.settings.lobbyDensity-3 end,100,"lobby population reduces as online grows")
    auditRigs()
    for id,s in pairs(stable) do local a=rt.mimics.values[id]; if a then check(a.preset==s[1] and a.actor.name==s[2] and a.mover.model==s[3],"actor appearance stays stable "..id) end end
    -- Cancel and immediately request a new private scene while creation can yield.
    for _=1,3 do invoke(third,{kind="Prologue",action="Lobby"}); invoke(third,{kind="Prologue",action="Replay"}) end
    waitFor(function() return actor("Prologue",function(a) return a.owner==third end) end,60)
    check(rt.mimics:count("Prologue")==1,"repeated scene entry leaves one guide")
    auditRigs()
    invoke(third,{kind="Prologue",action="Lobby"})
    waitFor(function() return rt.mimics:count("Prologue")==0 end,5)
    waitFor(function() return rt.mimics.metrics.upperArrivals>0 and rt.mimics.metrics.orders>0 end,120,"physical match Guest requests")
    prompt(spy,"StudyWindow","Открыть окно"); prompt(spy,"Safe","Осмотреть")
    prompt(spy,"Social.Egress","Выйти в холл"); prompt(spy,"MainExit","Покинуть особняк")
    check(rt.rounds.policy.result.winner=="Spy","human Spy physical extraction")
    waitFor(function() return rt.rounds.policy.phase=="Waiting" end,20)
    for _,p in ipairs(Players:GetPlayers()) do invoke(p,{kind="Queue",action="Cancel"}); invoke(p,{kind="Manual"}) end
    check(rt.mimics:count("Match")==0 and next(rt.rounds.policy.mimics)==nil,"round reset releases R15 actors")
    auditRigs()
    -- A second full round verifies per-round actors, slots, names and tracks reset.
    invoke(first,{kind="Queue",action="Register"}); invoke(second,{kind="Queue",action="Register"})
    waitFor(function() return rt.rounds.policy.phase=="Active" end,40)
    waitFor(function() return rt.mimics:count("Match")==6 end,100)
    auditRigs()
    local repeatSpy=if rt.roles:get(first)=="Spy" then first else second
    prompt(repeatSpy,"StudyWindow","Открыть окно"); prompt(repeatSpy,"Safe","Осмотреть")
    prompt(repeatSpy,"Social.Egress","Выйти в холл"); prompt(repeatSpy,"MainExit","Покинуть особняк")
    check(rt.rounds.policy.result.winner=="Spy","second physical round extraction")
    waitFor(function() return rt.rounds.policy.phase=="Waiting" end,20)
    for _,p in ipairs({first,second}) do invoke(p,{kind="Queue",action="Cancel"}) end
    check(rt.mimics:count("Match")==0,"second round releases actors")
    invoke(third,{kind="Prologue",action="Replay"})
    waitFor(function() return actor("Prologue",function(a) return a.owner==third end) end,60)
    local departing=actor("Prologue",function(a) return a.owner==third end)
    local privateRoot=rt.prologue.records[third].scene.root
    third:Kick("M11.2 isolated disconnect test complete")
    waitFor(function() return #Players:GetPlayers()==2 and not rt.prologue.records[third] end,15)
    check(not privateRoot.Parent and not departing.mover.model.Parent and rt.mimics.practice[third]==nil,"actual disconnect removes private scene and guide")
    waitFor(function() return not rt.mimics.creating and Rig.metrics.pending==0 end,20)
    auditRigs()
    print("M112 METRICS",Http:JSONEncode({rig=Rig.metrics,mimics=rt.mimics.metrics,crowd=rt.mimics.crowd.metrics}))
    print("M112 STUDIO SUITE PASS: actual 1/2/3 clients, all contexts, anti-clone, crowd, delivery, council, TWO rounds, replay, disconnect and cleanup")
    require(script.Parent.Motion).run()
end
local ok,err=xpcall(run,debug.traceback)
if not ok then warn("M112 STUDIO FAIL",err) end
