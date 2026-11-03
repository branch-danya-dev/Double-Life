assert(game:GetService("RunService"):IsStudio(),"Studio only")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local modules=game.ServerScriptService.DoubleLifeServer
local driver=Instance.new("RemoteFunction"); driver.Name,driver.Parent="M6TestDriver",RS
local audit=Instance.new("RemoteFunction"); audit.Name,audit.Parent="M8AuditDriver",RS
local rt=require(modules.Game).start({adapter=require(script.Parent.MemoryStore).new(require(modules.ProfileSchema).copy)})
local content=require(modules.PrologueContent)
local function check(ok,msg) assert(ok,msg); print("M10 PASS",msg) end
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
        print("M10 ROUTE",step,Http:JSONEncode({seconds=route.seconds,distance=route.distance}))
        invoke(p,{kind="LessonPrompt"})
    end
    waitFor(function() return rt.prologue.records[p].policy.step~=step end,5,"physical step did not advance "..step)
end
local function run()
    print("M10 WAIT ONE: start one client; add second only after FULL SOLO PASS")
    waitFor(function() return #Players:GetPlayers()==1 end,120)
    local p=Players:GetPlayers()[1]
    waitFor(function() return rt.prologue:active(p) end,15,"first join scene")
    local r=rt.prologue.records[p]
    local began=os.clock()
    action(p)
    check(os.clock()-r.policy.started<60,"first meaningful physical action within sixty seconds")
    check(rt.rounds.policy.phase=="Waiting" and not rt.roles.values[p.UserId],"solo prologue never assigns Owner/Spy")
    local interrupted=false
    while rt.prologue:active(p) do
        if r.policy.step==12 and not interrupted then
            interrupted=true
            invoke(p,{kind="Prologue",action="Lobby"})
            check(r.scene==nil and r.carry==nil,"interrupting clue checkpoint clears private carry")
            invoke(p,{kind="Prologue",action="Replay"})
            waitFor(function() return rt.prologue:active(p) end,8)
            check(r.policy.step==10 and not r.scene.world.studyDoor.CanCollide,"resume restores earlier access prerequisite")
        end
        action(p)
    end
    check(r.policy.state=="Completed","all twenty-five physical steps complete")
    waitFor(function() return rt.profiles:entry(p).profile.onboarding.state=="Completed" end,8,"acknowledged marker")
    local profile=rt.profiles:entry(p).profile
    check(profile.tokens==0 and profile.reputationXp==0 and profile.stats.played==0 and #profile.history==0,"no training currency XP match or history")
    check(r.scene==nil and rt.mimics:count("Prologue")==0,"completed scene and actors cleaned")
    print("M10 SOLO DURATION",os.clock()-began)
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
    print("M10 FULL SOLO PASS: add second real client")
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
    for _,v in ipairs(Players:GetPlayers()) do invoke(v,{kind="Manual"}) end
    print("M10 STUDIO SUITE PASS: full solo, skip/replay, private contexts, consent/defer and actual two-human match")
end
local ok,err=xpcall(run,debug.traceback)
if not ok then warn("M10 STUDIO FAIL",err) end
