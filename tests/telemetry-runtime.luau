local Analytics=require("../src/server/AnalyticsPolicy")
local Retention=require("../src/server/RetentionPolicy")
local Queue=require("../src/server/QueuePolicy")
local Settings=require("../src/server/MatchSettings")
local Sink=require("./TelemetrySink")
local Suite={}
function Suite.run(loadService)
    local n=0; local function check(ok,why) assert(ok,why); n+=1 end
    local time=0; local function now() return time end
    local players={list={}}
    function players:GetPlayers() return self.list end
    function players:GetPlayerByUserId(id) for _,p in ipairs(self.list) do if p.UserId==id then return p end end end
    local signals={}
    local function signal(name)
        local event={}; function event:Connect(cb) signals[name]=cb end; return {Event=event}
    end
    local rt={alive=false,roundFinished=signal("finished"),taskCompleted=signal("task"),
        profiles={round={}},roles={get=function() return "Guest" end},
        rounds={policy={phase="Waiting",roundId=0,participants={},elapsed=0}},
        queue={policy=Queue.new(Settings,now),sending={}},mimics={count=function(_,context) return if context=="Match" then 6 else 4 end}}
    local engine={GetService=function(_,name)
        if name=="Players" then return players end
        if name=="RunService" then return {IsStudio=function() return true end} end
        error("unexpected external service "..name)
    end}
    local modules={AnalyticsPolicy=Analytics,RetentionPolicy=Retention}
    local env=setmetatable({game=engine,script={Parent=setmetatable({},{__index=function(_,k) return k end})},
        require=function(k) return modules[k] end},{__index=getfenv()})
    local sink=Sink.new(now)
    local service=loadService(env).new(rt,function(...) return sink:send(...) end,now); rt.telemetry=service
    local function add(id)
        local p={UserId=id,Parent=players,IsA=function(_,kind) return kind=="Player" end}
        table.insert(players.list,p); service:add(p); rt.queue.policy:register(id,false); service:registered(p); return p
    end
    local p=add(1)
    check(not service:add({Parent=players,IsA=function() return false end}),"Model cannot enter telemetry")
    service:add(p); check(#sink:find("Join")==1,"duplicate add fenced")
    time=30; service:tick(); check(#sink:find("MatchStarted")==0,"solo tick never emits start")
    service:lesson(p,"Started"); time=35; service:lesson(p,"Checkpoint",1)
    check(sink:find("FirstMeaningfulAction")[1].value==35,"actual runtime clock injection")
    local other=add(2); rt.queue.policy:eligible(); service:decision(p,true); service:decision(other,false)
    service:tick()
    check(#sink:find("OpponentFound")==2 and sink:find("OpponentFound",p)[1].value==35,"runtime ready and latency")
    check(#sink:find("ReadyAccepted")==1 and #sink:find("ReadyDeclined")==1,"runtime decisions")
    rt.queue.policy:cancel(2); service:cancelled(other,false); time=36; service:tick()
    check(#sink:find("QueueTimeout")==0 and #sink:find("QueueCancelled")==1,"explicit cancel is never timeout")
    rt.queue.policy:register(2,true); service:registered(other)
    rt.queue.policy:consent(1,true); rt.queue.policy:start({1,2})
    rt.rounds.policy.participants={[1]=true,[2]=true}; rt.rounds.policy.roundId=1; rt.rounds.policy.phase="Active"; rt.rounds.policy.elapsed=0.7
    service:started(); service:started(); time=40; service:tick()
    check(#sink:find("MatchStarted")==2,"actual start hook independent of elapsed==0")
    check(sink:find("RealHumans",p)[#sink:find("RealHumans",p)].value==2,"six mimics excluded from human count")
    signals.task({userId="m:1",roundId=1}); signals.task({userId=2,roundId=0})
    check(#sink:find("FirstMeaningfulAction",other)==0,"mimic and stale task excluded")
    signals.task({userId=2,roundId=1}); signals.task({userId=2,roundId=1})
    check(#sink:find("FirstMeaningfulAction",other)==1,"real successful task once")
    time=490; rt.rounds.policy.elapsed=420; rt.profiles.round={[1]={startPlayed=0},[2]={startPlayed=3}}
    signals.finished({roundId=1,winner="Defenders",reason="Timeout"}); signals.finished({roundId=1,winner="Defenders",reason="Timeout"})
    check(#sink:find("FirstMatchCompleted")==2 and #sink:find("FirstMatch")==1,"session and known-account completion separate")
    check(#sink:find("RoundFinished")==2 and #sink:find("Win")==2,"duplicate round callback excluded")
    rt.queue.policy:reset(); time=491; service:tick()
    check(#sink:find("NextMatchQueued")==2,"natural reset queues next round")
    time=500; rt.rounds.policy.roundId=2; rt.rounds.policy.elapsed=0; service:started()
    time=920; rt.rounds.policy.elapsed=420; signals.finished({roundId=2,winner="Defenders",reason="Timeout"})
    check(#sink:find("RepeatMatch")==2,"second completion")
    check(#sink:find("FirstMatch")==1,"unqualified unchanged profile cannot duplicate legacy first match")
    service:failure(p,false); service:failure(p,true)
    check(#sink:find("TransportFailed")==1 and #sink:find("MatchmakingFailed")==1,"classified runtime faults")
    service:arrival(other); service:arrival(other); check(#sink:find("TransferArrived")==1,"validated arrival hook deduped")
    rt.queue.sending[p]={}; service:remove(p); service:remove(p)
    check(#sink:find("TransferDeparted")==1 and #sink:find("Exit",p)==0,"inflight removal separate from churn")
    service:remove(other); check(#sink:find("Exit",other)==1 and service.retention.records[other]==nil,"ordinary disconnect cleanup")
    local newcomer=add(3); sink.failed=true; service:activity(newcomer)
    check(service:health().policy.failed==1 and service.retention.records[newcomer].firstAction,"failed sink returns without changing gameplay")
    check(service:health().pending==0,"Studio has no external delivery queue")
    sink.failed=false; time=2000; rt.queue.policy:eligible(); service:tick()
    check(#sink:find("QueueTimeout",newcomer)==1,"expiry before first sample still records timeout")
    print("M11 actual telemetry runtime:",n,"assertions PASS")
end
return Suite
