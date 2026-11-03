local Actor=require("../src/server/ActorPolicy")
local Plan=require("../src/server/RolePlan")
local Round=require("../src/server/RoundPolicy")
local Config=require("../src/shared/Config")
local Settings=require("../src/server/MatchSettings")
local Queue=require("../src/server/QueuePolicy")
local Pool=require("../src/server/MatchPool")
local count=0
local function check(ok,why) assert(ok,why); count+=1 end
for humans=0,15 do
    local ids={}; for id=1,humans do table.insert(ids,id) end
    local roles=Plan.assign(ids,function(i) return i end,"M9")
    local owners,spies=0,{}
    for id,role in pairs(roles) do
        check(table.find(ids,id)~=nil,"real roster only")
        if role=="Owner" then owners+=1 elseif role=="Spy" then table.insert(spies,id) end
    end
    check(owners==(if humans>=2 then 1 else 0),"one real owner at threshold")
    check(#spies==(if humans>=8 then 2 elseif humans>=2 then 1 else 0),"spies depend on humans alone")
    local missing=Actor.mimicCount(humans,Settings.targetSize,Settings.maxMimics)
    check(missing>=0 and humans+missing<=15,"bounded total composition")
    if humans>=8 then check(missing==0,"human growth replaces mimics") end
    local r=Round.new(Config,2)
    check((r:tick(0,humans)=="Countdown")== (humans>=2),"one human never starts")
    if humans>=2 then
        r:tick(Config.COUNTDOWN_SECONDS,humans)
        check(r:activate(ids,spies),"real human roster activates")
        for i=1,missing do
            local a=Actor.mimic("m:"..i,{},"Fictional"..i)
            check(a.role=="Guest" and not Actor.canProfile(a) and not Actor.canVote(a),"mimics isolated from profiles and votes")
            r:addMimic(a.id)
        end
        r:tick(Config.COUNCIL_DELAY,humans); check(r:council(1),"owner council")
        check(not r:vote("m:1",1,r.roundId),"no mimic votes")
        if missing>0 then
            for _,id in ipairs(ids) do r:vote(id,"m:1",r.roundId) end
            check(r:majority()=="m:1","humans can search mimic")
            r:removeMimic("m:1"); check(r:majority()==nil,"despawn clears stale targets")
        end
        r:tick(Config.COUNCIL_SECONDS,humans)
        check(r:extract(spies[#spies]),"either real spy can win")
        check(r:tick(Config.RESULT_RESET_SECONDS,humans)=="Reset","normal reset")
    end
end
do
    local r=Round.new(Config,2); r:tick(0,2); r:tick(12,2); r:activate({1,2},{2})
    for i=1,8 do r:addMimic("m:"..i) end
    r:tick(30,2); r:council(1); r:vote(1,2,r.roundId)
    check(r:majority()==nil,"one human cannot unilaterally convict the opponent")
    r:tick(25,2); r:tick(Config.ROUND_SECONDS,2)
    check(r.result.winner=="Defenders","mimics cannot prevent timeout")
end
do
    local now=0; local q=Queue.new(Settings,function() return now end)
    check(not q:register("m:1"),"actor cannot register")
    check(q:register(1) and not q:register(1),"idempotent registration")
    check(#q:eligible()==0,"solo queue")
    q:register(2,false); q:eligible(); now=4
    check(#q:eligible()==1,"consent can hold prologue participant")
    check(q:snapshot(2).needsConsent,"explicit ready invitation")
    q:consent(2,true); check(#q:eligible()==2,"accepted real pair")
    q:select(q:eligible()); q:register(3)
    check(#q:eligible()==2,"late join cannot alter reserved roster")
    q:cancel(2); check(#q:eligible()==1,"countdown membership loss visible")
    q:reset(); now=8; q:eligible(); now=12
    q:start(q:eligible()); check(not q:cancel(1),"queue cancel is not leaving an active role")
    q:leave(1); q:reset(); now=1000
    check(#q:ordered()==0,"queue TTL ends stale registrations")
end
-- Atomic coordinator traces emulate independent source servers, retries and failover.
for _,case in ipairs({"Arrive","Cancel","Crash","WrongToken","WrongDestination","Duplicate","Capacity"}) do
    local s=Pool.empty()
    check(Pool.register(s,1,"A","a",0,Settings),"A registers human")
    check(not Pool.register(s,"m:1","A","fake",0,Settings),"mimic cannot enter shared pool")
    check(not Pool.match(s,"alone",0,Settings),"solo cannot reserve")
    check(Pool.register(s,2,"B","b",1,Settings),"B registers opponent")
    check(not Pool.register(s,1,"B","stolen",1,Settings),"lease prevents concurrent sessions")
    local m=Pool.match(s,"ab",2,Settings)
    check(m and #m.ids==2 and m.target=="A","one atomic cross-server assignment")
    check(not Pool.match(s,"race",2,Settings),"second coordinator cannot double assign")
    check(not Pool.ready(s,"ab","A",{[1]=true},3),"no fake successful start before arrival")
    if case=="Cancel" then
        check(Pool.cancel(s,2,"B","b",3),"cancel own ticket")
        check(s.matches.ab==nil and s.tickets["1"].match==nil,"pair released on cancel")
    elseif case=="Crash" then
        Pool.prune(s,100); check(next(s.tickets)==nil and next(s.matches)==nil,"crash leases expire")
        check(Pool.register(s,1,"C","reconnect",101,Settings),"reconnect after stale lease")
    elseif case=="WrongToken" then
        check(not Pool.arrive(s,2,"forged","ab","A",3),"join data cannot forge admission")
        check(not Pool.cancel(s,2,"B","forged",3),"wrong cancellation token")
    elseif case=="WrongDestination" then
        check(not Pool.arrive(s,2,"b","ab","C",3),"wrong job rejects ticket")
    else
        check(Pool.arrive(s,2,"b","ab","A",3),"server verifies arrival")
        check(Pool.ready(s,"ab","A",{[1]=true,[2]=true},3),"only actual present pair is ready")
        check(Pool.consume(s,"ab","A",{[1]=true,[2]=true},3),"commit once")
        check(not Pool.consume(s,"ab","A",{[1]=true,[2]=true},3),"repeated callback cannot commit twice")
        check(not Pool.match(s,"duplicate",4,Settings),"consumed tombstone blocks duplicate assignment")
        if case=="Capacity" then
            for id=3,Settings.poolLimit do check(Pool.register(s,id,"C","t"..id,4,Settings),"bounded pool fills") end
            check(not Pool.register(s,Settings.poolLimit+1,"C","overflow",4,Settings),"bounded pool refuses overflow")
        end
    end
end
print("M9 actors/queue/multi-server:",count,"assertions PASS")
