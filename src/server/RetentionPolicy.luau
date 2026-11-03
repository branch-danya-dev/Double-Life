-- Monotonic, server-only visit state. No names, roles, tickets or IDs reach sink.
local R={}; R.__index=R
local function seconds(v) return math.clamp(v,0,86400) end
function R.cohort(n)
    return if n<=1 then "1" elseif n==2 then "2" elseif n<=4 then "3-4" elseif n<=7 then "5-7" else "8-15"
end
function R.exitBucket(n)
    for _,v in ipairs({30,60,180,300,600,900}) do if n<v then return "Under"..v end end
    return "Over900"
end
function R.new(emit,now)
    return setmetatable({emit=emit,now=now,records={},serial=0,duplicates=0,invalid=0},R)
end
function R:out(p,event,value,detail,context)
    local r=self.records[p]; if not r then self.invalid+=1; return false end
    return self.emit(p,event,seconds(value or 1),{cohort=r.cohort,context=context or r.context,detail=detail or "None"},true)
end
function R:add(p,humans,arrival)
    if self.records[p] then self.duplicates+=1; return false end
    self.serial+=1
    self.records[p]={id=self.serial,joined=self.now(),sample=self.now(),active=0,cohort=R.cohort(humans),context="Lobby",completed=0,queues=0}
    self:out(p,if arrival then "TransferArrived" else "Join",1)
    return true
end
function R:activity(p)
    local r=self.records[p]; if not r then return end
    r.engaged=self.now()
    if not r.firstAction then r.firstAction=true; self:out(p,"FirstMeaningfulAction",self.now()-r.joined) end
end
function R:sample(p,moving,alive)
    local r=self.records[p]; if not r then return end
    local now=self.now(); local dt=math.clamp(now-r.sample,0,2); r.sample=now
    -- Movement is engagement, but never counts as the first meaningful action.
    if moving then r.engaged=now end
    if alive and r.engaged and now-r.engaged<=30 then r.active+=dt end
end
function R:queue(p,serial,humans)
    local r=self.records[p]; if not r then return end
    if r.queue and r.queue.id==serial then self.duplicates+=1; return end
    r.context=if r.lesson then "Prologue" else "Lobby"
    r.cohort=R.cohort(humans); r.queue={id=serial,at=self.now()}; r.queues+=1
    self:out(p,"QueueEntered",1)
    if r.completed>0 then self:out(p,"NextMatchQueued",self.now()-(r.finishedAt or self.now())) end
end
function R:ready(p,remote)
    local r=self.records[p]; local q=r and r.queue; if not q or q.started then return end
    if q.ready then self.duplicates+=1; return end
    q.ready=true
    self:out(p,"OpponentFound",self.now()-q.at,if remote then "Remote" else "Local")
    self:out(p,"MatchReady",self.now()-q.at,if remote then "Remote" else "Local")
end
function R:decision(p,accepted)
    local r=self.records[p]; local q=r and r.queue
    if not q or not q.ready or q.started then return false end
    if q.decision~=nil then self.duplicates+=1; return false end
    q.decision=accepted
    self:out(p,if accepted then "ReadyAccepted" else "ReadyDeclined",self.now()-q.at)
    return true
end
function R:cancel(p,timeout)
    local r=self.records[p]; if not r or not r.queue or r.queue.started then return end
    self:out(p,if timeout then "QueueTimeout" else "QueueCancelled",self.now()-r.queue.at)
    r.queue=nil
end
function R:failure(p,transport)
    local r=self.records[p]; if not r then return end
    self:out(p,if transport then "TransportFailed" else "MatchmakingFailed",1)
end
function R:prologue(p,kind,step)
    local r=self.records[p]; if not r then return end
    if kind=="Started" then
        if r.lesson then self.duplicates+=1; return end
        r.context="Prologue"; r.lesson={at=self.now(),checkpoint=self.now(),seen={}}
        self:out(p,"PrologueStarted",1); return
    end
    local l=r.lesson; if not l then return end
    if kind=="Checkpoint" then
        if type(step)~="number" or step%1~=0 or step<1 or step>25 then self.invalid+=1; return end
        l.reset=false; self:activity(p)
        if l.seen[step] then self.duplicates+=1; return end
        l.seen[step]=true
        self:out(p,"PrologueCheckpoint",self.now()-l.checkpoint,"Step"..step)
        l.checkpoint=self.now()
    elseif kind=="Reset" then
        if l.reset then self.duplicates+=1; return end
        l.reset=true
        self:out(p,"PrologueInterrupted",self.now()-l.checkpoint,"Reset"); l.checkpoint=self.now()
        -- Repeated chapter actions are not new checkpoint conversions in this visit.
    elseif kind=="Completed" or kind=="Skipped" or kind=="Interrupted" then
        self:out(p,"Prologue"..kind,self.now()-l.at)
        r.lesson=nil; r.context="Lobby"
    end
end
function R:start(p,id,humans,lobbyMimics,matchMimics)
    local r=self.records[p]; if not r or humans<2 then return false end
    if r.match and r.match.id>=id then self.duplicates+=1; return false end
    r.context="Match"; r.cohort=R.cohort(humans); r.match={id=id,at=self.now(),finished=false}
    if r.queue then r.queue.started=true; self:out(p,"QueueToStart",self.now()-r.queue.at) end
    self:out(p,"MatchStarted",1)
    self:out(p,"RealHumans",humans); self:out(p,"LobbyMimics",lobbyMimics); self:out(p,"MatchMimics",matchMimics)
    return true
end
function R:finish(p,id,activeSeconds,reason)
    local r=self.records[p]; local m=r and r.match
    if not m or m.id~=id or m.finished then self.duplicates+=1; return false end
    m.finished=true; r.context="Results"
    local detail=if reason=="SpyLeft" then "Abandoned" elseif reason=="Timeout" then "Timeout" else "Objective"
    self:out(p,"RoundFinished",self.now()-m.at,detail)
    self:out(p,"RoundActiveSeconds",activeSeconds,detail)
    if detail~="Abandoned" then
        r.completed+=1; r.finishedAt=self.now()
        self:out(p,if r.completed==1 then "FirstMatchCompleted" else "RepeatMatch",self.now()-m.at,detail)
    end
    return true
end
function R:remove(p,transfer)
    local r=self.records[p]; if not r then return false end
    local duration,context=self.now()-r.joined,r.context
    if r.lesson then self:prologue(p,"Interrupted") end
    self:out(p,if transfer then "TransferDeparted" else "Exit",duration,R.exitBucket(duration),context)
    self:out(p,"ActiveSeconds",r.active,"None",context)
    self:out(p,"SessionEnded",duration,if transfer then "Transfer" else "Departure",context)
    self.records[p]=nil; return true
end
return R
