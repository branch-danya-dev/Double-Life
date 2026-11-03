local C=require("../src/server/PrologueContent")
local P=require("../src/server/ProloguePolicy")
local Schema=require("../src/server/ProfileSchema")
local Progression=require("../src/server/ProgressionPolicy")
local Catalog=require("../src/server/ProgressionCatalog")
local Store=require("../src/server/ProfileStore")
local Memory=require("./MemoryStore")
local Queue=require("../src/server/QueuePolicy")
local Pool=require("../src/server/MatchPool")
local Settings=require("../src/server/MatchSettings")
local count=0
local function check(ok,why) assert(ok,why); count+=1 end
local now=0
local function clock() return now end
do
    local p=P.new(clock,C)
    local keys={}
    for index,step in ipairs(C.steps) do
        check(not keys[step.key],"unique checkpoint identifier"); keys[step.key]=true
        check(not p:act("Forged"),"remote-like arbitrary step cannot advance")
        check(p.step==index and p:act(step.key),"ordered physical checkpoint")
        check(not p:act(step.key),"duplicate trigger cannot repeat checkpoint")
        now+=15
    end
    check(p.state=="Completed" and p.firstAction==0,"full physical sequence has a measurable first action")
    check(not p:leave("Skip"),"completed scene is terminal")
    check(p:resume() and p.step==1,"explicit replay starts from arrival")
end
for _,time in ipairs({30,300,720}) do
    now=0; local p=P.new(clock,C); local q=Queue.new(Settings,clock)
    q:register(1,false); check(#q:eligible()==0,"solo scene never creates a match")
    now=time; q:register(2,false); q:eligible(); now+=4
    check(q:snapshot(1).state=="MatchReady" and #q:eligible()==0,"opponent arrival offers without interrupting scene")
    check(p.state=="Active","scene remains controlled at 30s/5m/12m")
    q:cancel(2); check(#q:eligible()==0,"decline releases local reservation")
    q:register(2,true); q:eligible(); now+=4; q:consent(1,true)
    p:leave("Match")
    check(#q:eligible()==2 and p.state=="Suspended","explicit consent enables two-real-player transition")
end
for _,index in ipairs({1,7,14,22}) do
    now=0; local p=P.new(clock,C)
    for i=1,index-1 do p:act(C.steps[i].key) end
    check(p:leave("Skip") and p.state=="Skipped","skip at start or middle")
    check(not p:act(C.steps[index].key),"no late trigger after skip")
    check(p:resume() and p.step==1,"skipped scenario can be replayed")
end
for _,index in ipairs({7,11,17,24}) do
    local p=P.new(clock,C)
    for i=1,index-1 do p:act(C.steps[i].key) end
    local generation=p.generation
    check(p:resetCharacter() and p.step==C.chapterStart(index),"death restores a usable chapter checkpoint")
    check(p.generation>generation,"old character callbacks are fenced")
end
do
    now=0; local a,b=P.new(clock,C),P.new(clock,C)
    a:act("Welcome"); check(b.step==1,"parallel visitors do not share progress")
    now=C.maximumSeconds; check(a:tick()=="Timeout" and a.state=="Suspended","bounded scene lifetime")
    check(not a:act("Portrait"),"late timeout callback cannot advance")
    check(a:resume() and a.step==2,"timeout progress is resumable")
end
do
    local old=Schema.new(Catalog); old.onboarding=nil
    local migrated=Schema.normalize(old,Catalog)
    check(migrated and migrated.onboarding.state=="Unseen","old profile migrates without reset")
    for _,bad in ipairs({false,"Done",{version=2,state="Completed",at=0},{version=1,state="Forged",at=0},{version=1,state="Skipped",at=-1}}) do
        local raw=Schema.new(Catalog); raw.onboarding=bad
        check(Schema.normalize(raw,Catalog)==nil,"malformed marker fails closed")
    end
end
for _,fault in ipairs({"before","after","replay"}) do
    now=1000
    local adapter=Memory.new(Schema.copy)
    local store=Store.new(adapter,Schema,Progression,Catalog,{now=clock,wait=function(s) now+=s end,jitter=function() return 0 end,leaseSeconds=120})
    local e=store:load(10,"one")
    check(e.status=="Ready","profile ready in isolated memory")
    local op={id="intro-skip",kind="Onboarding",state="Skipped",at=1000}
    check(store:enqueue(10,op,"one"),"server-owned skip marker queued")
    adapter.faults.User_10={fault}
    check(store:flush(10,false,nil,"one"),"marker survives before/after/replay write response")
    check(e.profile.onboarding.state=="Skipped","only acknowledged profile reflects marker")
    check(store:enqueue(10,op,"one") and store:flush(10,false,nil,"one"),"idempotent repeated skip")
    check(e.profile.tokens==0 and e.profile.reputationXp==0 and e.profile.stats.played==0 and #e.profile.history==0,"no fake match or reward")
    check(store:enqueue(10,{id="intro-complete",kind="Onboarding",state="Completed",at=1001},"one"),"replay completion may upgrade skip")
    check(store:flush(10,false,nil,"one") and e.profile.onboarding.state=="Completed","completed saved")
    check(store:enqueue(10,{id="later-skip",kind="Onboarding",state="Skipped",at=1002},"one") and store:flush(10,false,nil,"one"),"later skip is harmless")
    check(e.profile.onboarding.state=="Completed","completion cannot be downgraded")
    check(store:close(10,now+20,"one"),"marker closes with existing session machinery")
    local nextEntry=store:load(10,"two")
    check(nextEntry.status=="Ready" and nextEntry.profile.onboarding.state=="Completed","reconnect sees committed marker")
end
do
    local s=Pool.empty()
    Pool.register(s,1,"A","a",0,Settings,false); Pool.register(s,2,"B","b",0,Settings,true)
    check(Pool.match(s,"ready",0,Settings)~=nil,"held learner still finds remote opponent")
    check(not Pool.consented(s,"ready"),"no teleport before both consents")
    check(not Pool.ready(s,"ready","A",{[1]=true,[2]=true},0),"fake presence cannot bypass consent")
    Pool.register(s,1,"A","a",1,Settings,true)
    check(Pool.consented(s,"ready"),"explicit acceptance unlocks transport")
    Pool.arrive(s,2,"b","ready","A",2)
    check(Pool.consume(s,"ready","A",{[1]=true,[2]=true},2),"actual consented arrival can commit once")
    now=0; local q=Queue.new(Settings,clock); q:register(1,false); q.entries[1].remoteReady=true
    check(#q:eligible()==0 and q:snapshot(1).state=="MatchReady","remote invitation visible to one local learner")
    q.entries[1].remoteReady=nil; q:eligible()
    check(q:snapshot(1).state=="Queued","expired remote invitation clears")
end
print("M10 prologue, isolation, consent and persistence:",count,"assertions PASS")
