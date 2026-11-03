assert(game:GetService("RunService"):IsStudio(),"Studio only")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local modules=game.ServerScriptService.DoubleLifeServer
local driver=Instance.new("RemoteFunction"); driver.Name,driver.Parent="M6TestDriver",RS
local audit=Instance.new("RemoteFunction"); audit.Name,audit.Parent="M8AuditDriver",RS
local sink=require(script.Parent.TelemetrySink).new(os.clock)
local rt=require(modules.Game).start({analytics=function(...) return sink:send(...) end,adapter=require(script.Parent.MemoryStore).new(require(modules.ProfileSchema).copy)})
local content=require(modules.PrologueContent)
local function check(ok,msg) assert(ok,msg); print("M11 PASS",msg) end
local function waitFor(f,seconds,msg)
    local deadline=os.clock()+seconds
    repeat if f() then return end; task.wait(0.1) until os.clock()>deadline
    error(msg or "timeout")
end
local function invoke(p,c,remote)
    local done,ok,value=false,false,nil
    task.spawn(function() ok,value=pcall(function() return (remote or driver):InvokeClient(p,c) end); done=true end)
    waitFor(function() return done end,120,"client response")
    assert(ok,tostring(value)); return value
end
local function action(p)
    invoke(p,{kind="LessonReady"})
    local s=invoke(p,{kind="Snapshot"}).prologue
    local step=s.step
    if content.steps[step].kind=="Music" then invoke(p,{kind="LessonDance",step=step})
    else
        local route=invoke(p,{kind="Walk",position=s.target})
        print("M11 ROUTE",step,Http:JSONEncode({seconds=route.seconds,distance=route.distance}))
        invoke(p,{kind="LessonPrompt"})
    end
    waitFor(function() return rt.prologue.records[p].policy.step~=step end,5,"physical step did not advance "..step)
end
local function run()
    print("M11 WAIT ONE: start one client; add second only after FULL SOLO PASS")
    waitFor(function() return #Players:GetPlayers()==1 end,120)
    local p=Players:GetPlayers()[1]
    waitFor(function() return rt.prologue:active(p) end,15,"first join scene")
    local r=rt.prologue.records[p]
    local began=os.clock()
    action(p)
    check(os.clock()-r.policy.started<60,"first meaningful physical action within sixty seconds")
    check(rt.rounds.policy.phase=="Waiting" and not rt.roles.values[p.UserId],"solo prologue never assigns Owner/Spy")
    local interrupted=false
    local faulted=false
    while rt.prologue:active(p) do
        if r.policy.step==12 and not interrupted then
            interrupted=true
            invoke(p,{kind="Prologue",action="Lobby"})
            check(r.scene==nil and r.carry==nil,"interrupting clue checkpoint clears private carry")
            invoke(p,{kind="Prologue",action="Replay"})
            waitFor(function() return rt.prologue:active(p) end,8)
            check(r.policy.step==10 and not r.scene.world.studyDoor.CanCollide,"resume restores earlier access prerequisite")
        end
        local failing=r.policy.step==2 and not faulted
        if failing then sink.failed=true end
        action(p)
        if failing then
            sink.failed=false; faulted=true
            check(rt.telemetry:health().policy.failed>0,"failed analytics sink does not block physical checkpoint")
        end
    end
    check(r.policy.state=="Completed","all twenty-five physical steps complete")
    waitFor(function() return rt.profiles:entry(p).profile.onboarding.state=="Completed" end,8,"acknowledged marker")
    local profile=rt.profiles:entry(p).profile
    check(profile.tokens==0 and profile.reputationXp==0 and profile.stats.played==0 and #profile.history==0,"no training currency XP match or history")
    check(r.scene==nil and rt.mimics:count("Prologue")==0,"completed scene and actors cleaned")
    check(#sink:find("Join",p)==1 and #sink:find("FirstMeaningfulAction",p)==1,"real join and first action emitted once")
    check(#sink:find("PrologueCompleted",p)==1 and #sink:find("MatchStarted")==0,"solo completion is not competitive conversion")
    check(rt.mimics:count("Lobby")>=3,"solo lobby has mimics independent of human count")
    print("M11 SOLO DURATION",os.clock()-began)
    invoke(p,{kind="Prologue",action="Replay"}); waitFor(function() return rt.prologue:active(p) end,8)
    invoke(p,{kind="Prologue",action="Skip"})
    check(not rt.prologue:active(p) and r.policy.state=="Skipped","skip at first step")
    task.wait(1)
    check(rt.profiles:entry(p).profile.onboarding.state=="Completed","replay skip cannot downgrade completed marker")
    invoke(p,{kind="Prologue",action="Replay"}); waitFor(function() return rt.prologue:active(p) end,8)
    action(p); action(p)
    local oldCharacter=p.Character
    oldCharacter:FindFirstChildOfClass("Humanoid").Health=0
    waitFor(function() return p.Character~=oldCharacter and p.Character and p.Character:FindFirstChild("HumanoidRootPart") end,15,"actual respawn")
    check(r.policy.step==1 and rt.prologue:active(p),"actual death resumes chapter without a match or reward")
    action(p)
    invoke(p,{kind="Prologue",action="Lobby"})
    check(not rt.prologue:active(p) and not rt.queue.policy.entries[p.UserId],"return to lobby cancels search safely")
    invoke(p,{kind="Prologue",action="Replay"}); waitFor(function() return rt.prologue:active(p) end,8)
    action(p); action(p)
    invoke(p,{kind="Prologue",action="Skip"}); check(not rt.prologue:active(p),"skip in middle")
    check(invoke(p,"Report",audit).chat=="PASS","chat remains disabled")
    print("M11 FULL SOLO PASS: add second real client")
    waitFor(function() return #Players:GetPlayers()==2 end,600)
    local other; for _,v in ipairs(Players:GetPlayers()) do if v~=p then other=v end end
    waitFor(function() return rt.prologue:active(other) end,15)
    invoke(p,{kind="Prologue",action="Replay"}); waitFor(function() return rt.prologue:active(p) end,8)
    invoke(p,{kind="Queue",action="Register"})
    local firstRoot,secondRoot=r.scene.root,rt.prologue.records[other].scene.root
    check(firstRoot~=secondRoot and (rt.prologue:position(p)-rt.prologue:position(other)).Magnitude>150,"simultaneous private spaces separated")
    rt.rounds.rebuild(false)
    check(r.scene.root==firstRoot and rt.prologue.records[other].scene.root==secondRoot and firstRoot.Parent~=nil,"public world rebuild preserves private scenes")
    local otherStep=rt.prologue.records[other].policy.step
    action(p)
    check(rt.prologue.records[other].policy.step==otherStep,"one visitor cannot advance the other scene")
    waitFor(function() return rt.queue:snapshot(p).state=="MatchReady" end,10)
    check(rt.rounds.policy.phase=="Waiting","ready invitation does not silently start a match")
    invoke(p,{kind="Prologue",action="Accept"})
    check(not rt.prologue:active(p) and rt.prologue:active(other),"first acceptance preserves other visitor's control")
    invoke(other,{kind="Prologue",action="Defer"}); check(rt.prologue.records[other].policy.deferred,"defer waits for checkpoint")
    action(other)
    waitFor(function() return rt.rounds.policy.phase=="Active" end,30,"two-player transition")
    local roles={}; for _,v in ipairs(Players:GetPlayers()) do roles[rt.roles:get(v)]=true end
    check(roles.Owner and roles.Spy,"only actual humans become Owner and Spy after acceptance")
    check(firstRoot.Parent==nil and secondRoot.Parent==nil and rt.mimics:count("Prologue")==0,"two-phase transition cleans both scenes")
    check(invoke(other,"Report",audit).chat=="PASS","second client chat gate")
    check(#sink:find("MatchStarted")==2,"two actual start events after consent")
    local function physical(p,id,label)
        local pos=if rt.world.objects[id] then rt.world:approach(id) else rt.world:point(id)
        invoke(p,{kind="Walk",position=pos}); invoke(p,{kind="Prompt",part=rt.world:object(id).Name,action=label})
    end
    local function extract()
        local spy
        for _,human in ipairs(Players:GetPlayers()) do if rt.roles:get(human)=="Spy" then spy=human end end
        assert(spy,"human spy")
        physical(spy,"StudyWindow","Открыть окно"); physical(spy,"Safe","Осмотреть")
        physical(spy,"Social.Egress","Выйти в холл"); physical(spy,"MainExit","Покинуть особняк")
        waitFor(function() return rt.rounds.policy.phase=="Results" end,10)
    end
    waitFor(function() return rt.mimics:count("Match")==6 end,90)
    check(#Players:GetPlayers()==2 and #sink:find("Join")==2,"six match mimics do not create visits")
    extract()
    task.wait(1)
    check(#sink:find("FirstMatchCompleted")==2 and #sink:find("RoundFinished")==2,"first actual extraction reported once per human")
    waitFor(function() return rt.rounds.policy.phase=="Active" end,35,"natural second round")
    check(#sink:find("NextMatchQueued")==2 and #sink:find("MatchStarted")==4,"natural reset and repeat start")
    extract(); task.wait(1)
    check(#sink:find("RepeatMatch")==2,"repeat match requires completion")
    waitFor(function() return rt.rounds.policy.phase=="Waiting" end,20)
    for _,human in ipairs(Players:GetPlayers()) do invoke(human,{kind="Queue",action="Cancel"}) end
    print("M11 TWO CLIENT PASS: add third real client for multi-client regression")
    waitFor(function() return #Players:GetPlayers()==3 end,600)
    local third
    for _,human in ipairs(Players:GetPlayers()) do if human~=p and human~=other then third=human end end
    waitFor(function() return rt.prologue:active(third) end,15)
    invoke(third,{kind="Prologue",action="Skip"})
    for _,human in ipairs({p,other}) do invoke(human,{kind="Queue",action="Register"}) end
    -- Synchronize this fixture's three invitation deadlines before eligibility.
    -- Sequential client invocations otherwise select a legitimate two-person
    -- roster before the third visitor's later readiness delay has elapsed.
    local cohortReady=os.clock()+3
    for _,human in ipairs(Players:GetPlayers()) do rt.queue.policy.entries[human.UserId].readyAt=cohortReady end
    waitFor(function() return rt.rounds.policy.phase=="Active" end,40)
    check(#sink:find("MatchStarted")==7,"three real starts in multi-client regression")
    for _,e in ipairs(sink:find("MatchStarted")) do check(e.fields.cohort=="2" or e.fields.cohort=="3-4","cohorts count actual players only") end
    for _,human in ipairs(Players:GetPlayers()) do check(invoke(human,"Report",audit).chat=="PASS","multi-client chat gate") end
    extract(); task.wait(1)
    check(#sink:find("RoundFinished")==7,"three-player actual finish and preserved win condition")
    local counts={}; for _,e in ipairs(sink.events) do counts[e.event]=(counts[e.event] or 0)+1 end
    print("M11 COUNTS",Http:JSONEncode(counts))
    print("M11 HEALTH",Http:JSONEncode(rt.telemetry:health()))
    for _,human in ipairs(Players:GetPlayers()) do invoke(human,{kind="Manual"}) end
    print("M11 STUDIO SUITE PASS: solo prologue, sink fault, two-human first/repeat matches and three-client regression")
end
local ok,err=xpcall(run,debug.traceback)
if not ok then warn("M11 STUDIO FAIL",err) end
