assert(game:GetService("RunService"):IsStudio(),"Studio only")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local modules=game.ServerScriptService.DoubleLifeServer
local driver=Instance.new("RemoteFunction"); driver.Name,driver.Parent="M6TestDriver",RS
local audit=Instance.new("RemoteFunction"); audit.Name,audit.Parent="M8AuditDriver",RS
local rt=require(modules.Game).start({prologue=false,adapter=require(script.Parent.MemoryStore).new(require(modules.ProfileSchema).copy)})
rt.roles.random={NextInteger=function(_,_,high) return high end}
local function check(ok,msg) assert(ok,msg); print("M9 PASS",msg) end
local function waitFor(f,seconds,msg)
    local untilTime=os.clock()+seconds
    repeat if f() then return end; task.wait(0.1) until os.clock()>untilTime
    error(msg or "timeout")
end
local function invoke(p,c,remote)
    local done,ok,result=false,false,nil
    task.spawn(function() ok,result=pcall(function() return (remote or driver):InvokeClient(p,c) end); done=true end)
    waitFor(function() return done end,120,"client response")
    assert(ok,tostring(result)); return result
end
local function prompt(p,id,action)
    local pos=if rt.world.objects[id] then rt.world:approach(id) else rt.world:point(id)
    invoke(p,{kind="Walk",position=pos})
    invoke(p,{kind="Prompt",part=rt.world:object(id).Name,action=action})
end
local function run()
    print("M9 WAIT ONE: start one client; add second only after SOLO PASS")
    waitFor(function() return #Players:GetPlayers()==1 end,120)
    local first=Players:GetPlayers()[1]
    task.wait(30)
    check(rt.rounds.policy.phase=="Waiting","one real player never starts full round")
    check(rt.mimics:count("Lobby")>=3,"moving lobby mimics exist")
    check(#Players:GetPlayers()==1,"mimics do not become Roblox Players")
    print("M9 SOLO PASS: add second real client")
    waitFor(function() return #Players:GetPlayers()==2 end,600)
    waitFor(function() return rt.rounds.policy.phase=="Active" end,40)
    local owner,spy
    for _,p in ipairs(Players:GetPlayers()) do
        if rt.roles:get(p)=="Owner" then owner=p elseif rt.roles:get(p)=="Spy" then spy=p end
        check(invoke(p,"Report",audit).chat=="PASS","client chat and FakeMemory")
    end
    check(owner and spy and owner~=spy,"two actual players are Owner and Spy")
    waitFor(function() return rt.mimics:count("Match")==6 end,90,"six match mimics")
    local target
    for id in pairs(rt.rounds.policy.mimics) do
        target=target or id
        check(rt.actors:get(id).kind=="Mimic" and rt.actors:get(id).role=="Guest","mimic has separate Guest actor")
        check(rt.profiles.round[id]==nil and rt.profiles.store.entries[id]==nil,"no mimic profile")
    end
    prompt(owner,"OwnerConsole","Созвать собрание")
    if rt.rounds.policy.phase~="Council" then
        waitFor(function() return rt.rounds.policy.elapsed>=30 end,35)
        prompt(owner,"OwnerConsole","Созвать собрание")
    end
    check(rt.rounds.policy.phase=="Council","human owner calls council")
    invoke(owner,{kind="Vote",roundId=rt.rounds.policy.roundId,target=target})
    invoke(spy,{kind="Vote",roundId=rt.rounds.policy.roundId,target=target})
    local paused=rt.scope:now(); task.wait(2)
    check(rt.scope:now()==paused,"mimic and world clock pause")
    waitFor(function() return rt.rounds.policy.phase=="Active" end,30)
    check(rt.rounds.policy.detained and rt.rounds.policy.detained.id==target,"human majority can search a mimic")
    waitFor(function() return rt.mimics.metrics.matchActions>=4 and rt.mimics.metrics.upperArrivals>=1
        and rt.mimics.metrics.orders>=1 end,120,"physical match mimic activities, upper floor and request")
    check(true,"match mimics reach upper floor and place a real service request")
    prompt(spy,"StudyWindow","Открыть окно")
    prompt(spy,"Safe","Осмотреть")
    prompt(spy,"Social.Egress","Выйти в холл")
    prompt(spy,"MainExit","Покинуть особняк")
    check(rt.rounds.policy.result.winner=="Spy","real spy extraction decides match")
    print("M9 METRICS",Http:JSONEncode(rt.mimics.metrics))
    check(rt.mimics.metrics.maxWorkers<=2,"bounded pathfinding workers")
    local lobby=rt.lobby.root
    waitFor(function() return rt.rounds.policy.phase=="Waiting" end,20)
    for _,p in ipairs(Players:GetPlayers()) do invoke(p,{kind="Queue",action="Cancel"}); invoke(p,{kind="Manual"}) end
    check(rt.lobby.root==lobby and lobby.Parent==workspace,"lobby survives round rebuild")
    check(rt.mimics:count("Match")==0 and next(rt.rounds.policy.mimics)==nil,"match actors cleaned on reset")
    check(first.Parent==Players,"first visitor retained as real player")
    print("M9 STUDIO SUITE PASS: one/two humans, lobby, six match mimics, council, extraction and reset")
end
local ok,err=xpcall(run,debug.traceback)
if not ok then warn("M9 STUDIO FAIL",err) end
