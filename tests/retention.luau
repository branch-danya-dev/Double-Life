local Config=require("../src/shared/Config")
local R=require("../src/server/RetentionPolicy")
local A=require("../src/server/AnalyticsPolicy")
local T=require("../src/server/TuningConfig")
local Settings=require("../src/server/MatchSettings")
local Queue=require("../src/server/QueuePolicy")
local Pool=require("../src/server/MatchPool")
local Sink=require("./TelemetrySink")
local n=0
local function check(ok,why) assert(ok,why); n+=1 end
local function setup()
    local time=0; local function now() return time end
    local sink=Sink.new(now); local a=A.new(function(...) return sink:send(...) end,now)
    local r=R.new(function(...) return a:emit(...) end,now)
    return r,sink,a,function(v) time=v end,now
end
for _,arrival in ipairs({30,300,720}) do
    local r,s,_,at,now=setup(); local q=Queue.new(Settings,now)
    r:add(1,1); q:register(1,false); r:queue(1,1,1); r:prologue(1,"Started")
    at(5); r:prologue(1,"Checkpoint",1); r:prologue(1,"Checkpoint",1)
    check(#s:find("FirstMeaningfulAction")==1 and s:find("FirstMeaningfulAction")[1].value==5,"first successful action latency")
    at(arrival); r:add(2,2); q:register(2,false); r:queue(2,2,2); q:eligible()
    r:ready(1,false); r:ready(1,false); r:ready(2,false)
    check(s:find("OpponentFound",1)[1].value==arrival,"wait for actual second human")
    check(s:find("MatchReady",1)[1].value==arrival and #s:find("MatchReady",1)==1,"ready once")
    check(#q:eligible()==0 and #s:find("MatchStarted")==0,"invitation has no successful start")
    r:decision(1,true); r:decision(1,true); q:consent(1,true)
    r:decision(2,true); q:consent(2,true); at(arrival+3)
    check(#q:eligible()==2,"two consenting humans eligible")
    r:prologue(1,"Interrupted"); r:start(1,1,2,4,6); r:start(1,1,2,4,6); r:start(2,1,2,4,6)
    check(#s:find("ReadyAccepted",1)==1 and #s:find("MatchStarted")==2,"duplicate boundaries rejected")
    check(s:find("QueueToStart",1)[1].value==arrival+3,"queue duration monotonic")
    at(arrival+3+Config.ROUND_SECONDS+30); r:finish(1,1,Config.ROUND_SECONDS,"Timeout"); r:finish(1,1,Config.ROUND_SECONDS,"Timeout")
    check(#s:find("FirstMatchCompleted")==1 and s:find("RoundActiveSeconds")[1].value==Config.ROUND_SECONDS,"full configured active match once")
    check(s:find("RoundFinished")[1].value==Config.ROUND_SECONDS+30,"wall time includes council independently")
    r:queue(1,3,2); at(arrival+Config.ROUND_SECONDS+50); r:start(1,2,2,4,6); at(arrival+2*Config.ROUND_SECONDS+50); r:finish(1,2,Config.ROUND_SECONDS,"Timeout")
    check(not r:finish(1,1,Config.ROUND_SECONDS,"Timeout"),"stale prior round cannot replay completion")
    check(not r:start(1,1,2,4,6),"stale prior start cannot replace current match")
    check(#s:find("NextMatchQueued")==1 and #s:find("RepeatMatch")==1,"repeat completion distinct from queue")
    check(s:find("MatchStarted")[1].fields.cohort=="2","human-only start cohort")
end
do
    local r,s,_,at=setup(); r:add(1,1); r:queue(1,1,1)
    for t=1,900 do at(t); r:sample(1,false,true) end
    check(not r:start(1,1,1,8,8),"eight mimics cannot create a human match")
    r:cancel(1,true); r:remove(1,false)
    check(#s:find("MatchStarted")==0 and #s:find("OpponentFound")==0,"solo fifteen minutes is not conversion")
    check(s:find("QueueTimeout")[1].value==900 and s:find("Exit")[1].fields.detail=="Over900","solo timeout/exit trace")
    check(s:find("ActiveSeconds")[1].value==0,"idle presence not active time")
    check(next(r.records)==nil,"disconnect cleans all visit state")
end
for _,humans in ipairs({2,3,5,8,15}) do
    local r,s,_,at=setup()
    for p=1,humans do r:add(p,humans); r:queue(p,p,humans) end
    at(30)
    for p=1,humans do r:ready(p,false); r:start(p,1,humans,0,math.max(0,8-humans)) end
    check(#s:find("MatchStarted")==humans,"concurrent registration real-only starts")
    for _,e in ipairs(s:find("RealHumans")) do check(e.value==humans and e.fields.cohort==R.cohort(humans),"cohort and population remain separate") end
end
do
    local r,s,_,at=setup(); r:add(1,1); r:prologue(1,"Started")
    for step=1,25 do at(step*8); r:prologue(1,"Checkpoint",step); r:prologue(1,"Checkpoint",step) end
    r:prologue(1,"Completed"); r:prologue(1,"Completed")
    check(#s:find("PrologueCheckpoint")==25 and #s:find("PrologueCompleted")==1,"full prologue dedupe")
    for i,e in ipairs(s:find("PrologueCheckpoint")) do check(e.value==8 and e.fields.detail=="Step"..i,"checkpoint dwell trace") end
    r:prologue(1,"Started"); r:prologue(1,"Skipped"); r:prologue(1,"Skipped")
    check(#s:find("PrologueSkipped")==1,"early replay skip once")
    at(210); r:prologue(1,"Started"); r:prologue(1,"Checkpoint",1); r:prologue(1,"Reset"); r:prologue(1,"Reset")
    check(#s:find("PrologueInterrupted")==1,"death plus CharacterAdded reset is one interruption")
    r:prologue(1,"Checkpoint",1)
    check(#s:find("PrologueCheckpoint")==26,"death does not duplicate checkpoint conversion")
    r:remove(1,false)
    check(s:find("Exit")[1].fields.context=="Prologue","exit preserves interrupted context")
    r:add(1,1); check(#s:find("Join")==2,"reconnect is a new server visit")
    r:prologue(1,"Started"); r:prologue(1,"Checkpoint",0); r:prologue(1,"Checkpoint",26)
    check(r.invalid==2,"invalid checkpoints rejected")
end
for _,delay in ipairs({0,29,30,59,60,179,180,299,300,599,600,899,900,1000}) do
    local r,s,_,at=setup(); r:add(1,1); at(delay); r:remove(1,false); r:remove(1,false)
    check(#s:find("Exit")==1 and s:find("Exit")[1].fields.detail==R.exitBucket(delay),"exclusive exit bucket")
end
do
    local r,s,a,at=setup(); r:add(1,1); r:queue(1,1,1); at(300); r:ready(1,true); r:decision(1,false); r:cancel(1,false)
    check(s:find("OpponentFound")[1].fields.detail=="Remote" and s:find("OpponentFound")[1].fields.cohort=="1","remote peer never inflates local human count")
    check(#s:find("ReadyDeclined")==1 and #s:find("QueueCancelled")==1,"decline and cancel distinct")
    r:queue(1,2,1); r:failure(1,false); r:failure(1,true)
    check(#s:find("MatchmakingFailed")==1 and #s:find("TransportFailed")==1 and #s:find("MatchStarted")==0,"failures cannot imply conversion")
    r:remove(1,true); check(#s:find("Exit")==0 and #s:find("TransferDeparted")==1,"transport departure not churn")
    r:add(1,1,true); check(#s:find("TransferArrived")==1 and #s:find("Join")==1,"validated arrival classified")
    s.failed=true; at(305); r:activity(1); check(a.stats.failed==1 and r.records[1].firstAction,"sink failure cannot undo gameplay state")
    s.failed=false; r:activity(1); check(#s:find("FirstMeaningfulAction")==0,"no ambiguous delivery retry duplicate")
end
do
    local _,s,a,at=setup()
    local fields={cohort="1",context="Lobby",detail="None"}
    for _,v in ipairs({-1,math.huge,0/0,"text"}) do check(not a:emit(1,"Join",v),"invalid metric value") end
    check(not a:emit(1,"SecretRole",1),"no role event")
    for _,f in ipairs({{name="Alice"},{cohort="1",context="Lobby",detail="Owner"},{cohort="1",context="Lobby",detail="None",ticket="secret"}}) do
        check(not a:emit(1,"Join",1,f),"no free text/PII/tickets")
    end
    for _=1,1000 do a:emit(1,"MatchmakingFailed",1,fields,true) end
    check(#s.events<=64 and a.stats.rateLimited>0,"bounded spam burst")
    at(60); check(a:emit(1,"Join",1,fields),"budget refills with monotonic time")
    a:remove(1); check(a.last[1]==nil and a.budgets[1]==nil,"policy cleanup")
end
do
    local r,s,_,at=setup(); r:add(1,1); at(1); r:sample(1,true,true); at(2); r:sample(1,false,true)
    at(35); r:sample(1,false,true); at(36); r:sample(1,true,false); r:remove(1,false)
    check(s:find("ActiveSeconds")[1].value==2,"engaged time bounded, dead/idle excluded")
    check(#s:find("FirstMeaningfulAction")==0,"movement alone not meaningful action")
end
do
    local r,s,_,at=setup(); r:add(1,2); r:start(1,1,2,4,6); at(20); r:finish(1,1,20,"SpyLeft")
    check(#s:find("RoundFinished")==1 and #s:find("FirstMatchCompleted")==0,"abandoned round excluded from completion")
end
do
    local r,s,a,at=setup()
    for p=1,15 do r:add(p,15); r:queue(p,p,15); r:prologue(p,"Started") end
    for step=1,25 do
        at(step*8)
        for p=1,15 do
            r:prologue(p,"Checkpoint",step)
            if step%4==0 then
                r:out(p,"RealHumans",15); r:out(p,"LobbyMimics",0); r:out(p,"MatchMimics",0)
            end
        end
    end
    for p=1,15 do r:prologue(p,"Completed") end
    check(#s:find("PrologueCheckpoint")==375,"fifteen simultaneous prologues retain every checkpoint")
    check(#s:find("PrologueCompleted")==15,"fifteen real completions")
    check(a.stats.rateLimited==0 and a.stats.failed==0,"normal fifteen-person trace fits event budget")
end
local defaults=T.resolve(Settings)
for k,v in pairs(Settings) do check(defaults[k]==v,"M9 settings unchanged") end
for key,bounds in pairs(T.bounds) do
    for _,v in ipairs({bounds[1],bounds[2]}) do check(T.resolve(Settings,{[key]=v})[key]==v,"reviewed boundary applies") end
    for _,v in ipairs({bounds[1]-1,bounds[2]+1,0/0,math.huge,1.5,"x"}) do check(not pcall(T.resolve,Settings,{[key]=v}),"unsafe configuration rejected") end
end
check(T.resolve(Settings,{allowSkip=false,allowInvite=false}).allowSkip==false,"explicit test switches")
check(not pcall(T.resolve,Settings,{tokens=100}),"reward hotfix impossible")
check(not pcall(T.resolve,Settings,{crossServerEnabled=true}),"transport gate cannot be bypassed by tuning")
-- Two physical servers share the existing atomic pool, no synthetic local CCU.
local pool=Pool.empty(); Pool.register(pool,1,"A","a",0,Settings); Pool.register(pool,2,"B","b",0,Settings)
Pool.match(pool,"m",1,Settings)
check(pool.tickets["1"].match==pool.tickets["2"].match,"remote pool joins real users")
print("M11 retention traces, quality and tuning:",n,"assertions PASS")
