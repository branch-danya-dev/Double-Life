local Players=game:GetService("Players")
local Policy=require(script.Parent.AnalyticsPolicy)
local Retention=require(script.Parent.RetentionPolicy)
local Service={}; Service.__index=Service
function Service.new(rt,send,clock)
    local studio=game:GetService("RunService"):IsStudio()
    assert((not send and not clock) or studio,"Telemetry injection is Studio-only")
    local self=setmetatable({rt=rt,now=clock or os.clock,queue={},positions={},observed={},lastSample=0,lastPhase="",lastRound=0,
        delivery={sent=0,failed=0,dropped=0,studio=0},populationAt=0},Service)
    local function enqueue(p,event,value,fields)
        if studio then self.delivery.studio+=1; return true end
        if #self.queue>=128 then self.delivery.dropped+=1; return false end
        table.insert(self.queue,{p,event,value,fields}); return true
    end
    self.policy=Policy.new(send or enqueue,self.now)
    self.retention=Retention.new(function(...) return self.policy:emit(...) end,self.now)
    -- A bounded single worker isolates slow external calls from game interactions.
    if not studio then task.spawn(function()
        while rt.alive or #self.queue>0 do
            local item=table.remove(self.queue,1)
            if item then
                local f=item[4]; local fields=f and {CustomField01=f.cohort,CustomField02=f.context,CustomField03=f.detail}
                local ok=pcall(function() game:GetService("AnalyticsService"):LogCustomEvent(item[1],"DL_"..item[2],item[3],fields) end)
                if ok then self.delivery.sent+=1 else self.delivery.failed+=1 end
            end
            task.wait(0.25)
        end
    end) end
    rt.roundFinished.Event:Connect(function(payload) self:finished(payload) end)
    rt.taskCompleted.Event:Connect(function(payload)
        local p=Players:GetPlayerByUserId(payload.userId)
        if p and payload.roundId==rt.rounds.policy.roundId and rt.rounds.policy.participants[p.UserId] then self:activity(p) end
    end)
    return self
end
function Service:emit(p,event,value)
    if not self.retention.records[p] then return false end
    return self.policy:emit(p,event,value)
end
function Service:add(p)
    if p.Parent~=Players or not p:IsA("Player") then return false end
    return self.retention:add(p,#Players:GetPlayers(),false)
end
function Service:arrival(p)
    local r=self.retention.records[p]
    if r and not r.arrival then r.arrival=true; self.retention:out(p,"TransferArrived",1) end
end
function Service:activity(p) self.retention:activity(p) end
function Service:lesson(p,kind,step) self.retention:prologue(p,kind,step) end
function Service:registered(p)
    local e=self.rt.queue.policy.entries[p.UserId]
    if e then
        local key=e.serial..":"..e.joined
        self.retention:queue(p,key,#Players:GetPlayers()); self.observed[p]=key
    end
end
function Service:matched(p,remote) self.retention:ready(p,remote) end
function Service:decision(p,accepted)
    local e=self.rt.queue.policy.entries[p.UserId]
    if e and e.state=="MatchReady" then self.retention:ready(p,e.remoteReady==true); self.retention:decision(p,accepted) end
end
function Service:cancelled(p,timeout) self.retention:cancel(p,timeout); self.observed[p]=nil end
function Service:failure(p,transport) self.retention:failure(p,transport) end
function Service:started()
    local rt=self.rt; local ids=rt.rounds.policy.participants; local humans=0
    for _,p in ipairs(Players:GetPlayers()) do if ids[p.UserId] then humans+=1 end end
    for _,p in ipairs(Players:GetPlayers()) do
        if ids[p.UserId] then self.retention:start(p,rt.rounds.policy.roundId,humans,rt.mimics and rt.mimics:count("Lobby") or 0,rt.mimics and rt.mimics:count("Match") or 0) end
    end
end
function Service:finished(payload)
    local rt=self.rt
    for _,p in ipairs(Players:GetPlayers()) do
        if rt.rounds.policy.participants[p.UserId] and self.retention:finish(p,payload.roundId,rt.rounds.policy.elapsed,payload.reason) then
            local record=rt.profiles.round[p.UserId]
            local visit=self.retention.records[p]
            if payload.reason~="SpyLeft" and record and record.startPlayed==0 and not visit.legacyFirst then
                visit.legacyFirst=true; self:emit(p,"FirstMatch")
            end
            self:emit(p,if (rt.roles:get(p)=="Spy")== (payload.winner=="Spy") then "Win" else "Loss")
        end
    end
end
function Service:remove(p)
    local r=self.retention.records[p]
    if r then self:emit(p,"SessionSeconds",math.min(86400,self.now()-r.joined)) end
    local transfer=self.rt.queue and self.rt.queue.sending[p]~=nil
    if not transfer then self.retention:cancel(p,false) end
    self.retention:remove(p,transfer)
    self.policy:remove(p); self.positions[p],self.observed[p]=nil,nil
end
function Service:tick()
    local now=self.now(); if now-self.lastSample<0.5 then return end; self.lastSample=now
    local rt=self.rt; local round=rt.rounds.policy
    local changed=round.phase~=self.lastPhase or round.roundId~=self.lastRound
    self.lastPhase,self.lastRound=round.phase,round.roundId
    for _,p in ipairs(Players:GetPlayers()) do
        if not self.retention.records[p] then continue end
        if changed then self:emit(p,round.phase) end
        local entry=rt.queue.policy.entries[p.UserId]; local previous=self.observed[p]
        if entry then
            local key=entry.serial..":"..entry.joined
            if previous~=key then self:registered(p); self.observed[p]=key end
            if entry.state=="MatchReady" then self.retention:ready(p,entry.remoteReady==true) end
        elseif previous then self:cancelled(p,true); self.observed[p]=nil end
        local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        local pos=root and root.Position; local last=self.positions[p]
        self.retention:sample(p,pos~=nil and last~=nil and (pos-last).Magnitude>0.5,hum~=nil and hum.Health>0)
        self.positions[p]=pos
        if now>=self.populationAt then
            self.retention:out(p,"RealHumans",#Players:GetPlayers())
            self.retention:out(p,"LobbyMimics",rt.mimics:count("Lobby"))
            self.retention:out(p,"MatchMimics",rt.mimics:count("Match"))
        end
    end
    if now>=self.populationAt then self.populationAt=now+30 end
end
function Service:health()
    return {policy=table.clone(self.policy.stats),delivery=table.clone(self.delivery),pending=#self.queue,
        duplicateTransitions=self.retention.duplicates,invalidTransitions=self.retention.invalid}
end
return Service
