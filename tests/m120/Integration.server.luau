assert(game:GetService("RunService"):IsStudio(), "Studio only")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local modules=game.ServerScriptService.DoubleLifeServer
local Config=require(RS.DoubleLifeShared.Config)
local driver=Instance.new("RemoteFunction"); driver.Name,driver.Parent="M6TestDriver",RS
local view=Instance.new("RemoteFunction"); view.Name,view.Parent="M120View",RS
local rt=require(modules.Game).start({adapter=require(script.Parent.MemoryStore).new(require(modules.ProfileSchema).copy)})
rt.roles.random={NextInteger=function(_,_,high) return high end}
local finished=0; rt.roundFinished.Event:Connect(function(r) finished+=1; print("M120 FINISHED",r.roundId,r.reason) end)
local function check(ok,msg) assert(ok,msg); print("M120 PASS",msg) end
local function waitFor(f,seconds,msg)
    local deadline=os.clock()+seconds
    repeat if f() then return end; task.wait(0.05) until os.clock()>deadline
    error(msg or "deadline")
end
local function invoke(p,c,remote)
    local done,ok,value=false,false,nil
    task.spawn(function() ok,value=pcall(function() return (remote or driver):InvokeClient(p,c) end); done=true end)
    waitFor(function() return done end,180,"client response")
    assert(ok,tostring(value)); return value
end
local function prompt(p,id,action)
    invoke(p,{kind="Walk",position=if rt.world.objects[id] then rt.world:approach(id) else rt.world:point(id)})
    invoke(p,{kind="Prompt",part=rt.world:object(id).Name,action=action})
end
local function run()
    local assertions=require(script.Parent.Timeline).run(Config,require(modules.RoundPolicy),require(RS.DoubleLifeShared.RoundTime))
    print("M120 VIRTUAL TIMELINE PASS",assertions,"production policy virtual dt; NOT a physical 20-minute run")
    waitFor(function() return #Players:GetPlayers()==2 end,120,"exactly two real clients")
    local people=Players:GetPlayers(); table.sort(people,function(a,b) return a.Name<b.Name end)
    for _,p in ipairs(people) do
        waitFor(function() return rt.prologue.records[p]~=nil end,30)
        invoke(p,{kind="Prologue",action="Lobby"}); invoke(p,{kind="Queue",action="Cancel"})
    end
    for iteration=1,2 do
        print("M120 CAPTURE READY",iteration,"start gate; then ordinary 12-second countdown")
        invoke(people[1],{kind="Gate",round=iteration},view)
        for _,p in ipairs(people) do invoke(p,{kind="Queue",action="Register"}) end
        waitFor(function() return rt.rounds.policy.phase=="Active" end,35)
        local owner,spy
        for _,p in ipairs(people) do if rt.roles:get(p)=="Owner" then owner=p elseif rt.roles:get(p)=="Spy" then spy=p end end
        check(owner and spy and owner~=spy,"Owner/Spy are actual Players")
        waitFor(function() return rt.mimics:count("Match")==6 end,100,"six real R15 actors")
        check(#rt.rounds:snapshot(owner).members==8,"two humans plus six Guest mimics")
        for _,a in pairs(rt.mimics.values) do if a.context=="Match" then check(a.actor.role=="Guest","mimic remains Guest") end end
        for _,p in ipairs(people) do
            local audit=invoke(p,{kind="Audit",round=rt.rounds.policy.roundId},view)
            check(audit.start=="Игра · 20:00","actual client HUD 20:00 "..p.Name)
        end
        if iteration==1 then
            prompt(owner,"OwnerConsole","Созвать собрание")
            if rt.rounds.policy.phase~="Council" then
                waitFor(function() return rt.rounds.policy.elapsed>=30 end,35)
                prompt(owner,"OwnerConsole","Созвать собрание")
            end
            check(rt.rounds.policy.phase=="Council","physical council prompt")
            local elapsed,saved,clock=rt.rounds.policy.elapsed,rt.rounds.policy.savedRemaining,rt.scope:now()
            task.wait(2)
            check(rt.rounds.policy.elapsed==elapsed and rt.scope:now()==clock,"real active/world clocks pause")
            print("M120 COUNCIL PAUSE",saved,"active seconds; independent council",rt.rounds.policy.remaining)
            waitFor(function() return rt.rounds.policy.phase=="Active" end,30)
            check(rt.rounds.policy.remaining<=saved and rt.rounds.policy.remaining>saved-1,"council restores remainder without reset")
            local audit=invoke(owner,{kind="Audit",round=rt.rounds.policy.roundId},view)
            check(audit.council==true,"client Council HUD uses paused whole-match timer")
        end
        prompt(spy,"StudyWindow","Открыть окно"); prompt(spy,"Safe","Осмотреть")
        prompt(spy,"Social.Egress","Выйти в холл"); prompt(spy,"MainExit","Покинуть особняк")
        check(rt.rounds.policy.phase=="Results" and rt.rounds.policy.result.reason=="Extraction","physical early extraction "..iteration)
        check(rt.rounds.policy.elapsed<1200 and finished==iteration,"immediate single RoundFinished")
        print("M120 EXTRACTION ACTIVE SECONDS",iteration,rt.rounds.policy.elapsed)
        waitFor(function() return rt.rounds.policy.phase=="Waiting" end,20)
        for _,p in ipairs(people) do invoke(p,{kind="Queue",action="Cancel"}) end
        check(rt.mimics:count("Match")==0 and next(rt.rounds.policy.mimics)==nil,"Results reset releases actors")
    end
    check(finished==2,"two physical rounds exactly two completions")
    print("M120 STUDIO SUITE PASS: 2 actual clients +6 R15 Guests; HUD, council, two physical extractions, reset; 1200 timeout VIRTUAL ONLY")
end
local ok,err=xpcall(run,debug.traceback)
if not ok then warn("M120 STUDIO FAIL",err) end
