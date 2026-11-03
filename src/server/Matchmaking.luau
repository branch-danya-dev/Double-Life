local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local Queue=require(script.Parent.QueuePolicy)
local Pool=require(script.Parent.MatchPool)
local Settings=require(script.Parent.MatchSettings)
local Transport=require(script.Parent.MatchTransport)
local Service={}; Service.__index=Service
function Service.new(rt, remote)
    local self=setmetatable({rt=rt,policy=Queue.new(Settings,os.clock),settings=Settings,tokens={},players={},
        sending={},last={},approved={},arrived={},joined={},transport=Transport.new(Settings),status="Local",errors=0},Service)
    remote.OnServerEvent:Connect(function(p,action)
        if os.clock()<(self.last[p] or 0) then return end
        self.last[p]=os.clock()+0.5
        if action=="Register" then self:register(p)
        elseif action=="Cancel" then self:cancel(p)
        elseif action=="Accept" then
            if self.onAccept then self.onAccept(p) else self.policy:consent(p.UserId,true) end
        elseif action=="Decline" then self:cancel(p)
        elseif action=="Lobby" and not rt.rounds.policy.participants[p.UserId] and p.Character then
            if not self.onLobby or not self.onLobby(p) then p.Character:PivotTo(CFrame.new(rt.lobby:position(1))) end
        end
    end)
    if self.transport.enabled then
        game:GetService("TeleportService").TeleportInitFailed:Connect(function(p,_,_,_,options)
            local attempt=self.sending[p]
            local ok,data=pcall(function() return options:GetTeleportData() end)
            if attempt and ok and type(data)=="table" and data.matchId==attempt.id and data.ticket==attempt.token then
                self.sending[p]=nil; self.status="TransportFailed"; self.errors+=1; self:cancel(p); self:register(p)
            end
        end)
        task.spawn(function()
            while rt.alive do self:poll(); task.wait(Settings.retrySeconds) end
        end)
    end
    return self
end
function Service:register(p)
    if p.Parent~=Players then return false end
    if self.policy.entries[p.UserId] then return false end
    self.tokens[p.UserId]=self.tokens[p.UserId] or Http:GenerateGUID(false)
    return self.policy:register(p.UserId,not (self.hold and self.hold(p)))
end
function Service:add(p)
    self.players[p.UserId]=p
    self.tokens[p.UserId]=Http:GenerateGUID(false)
    if self.transport.enabled then
        local ok,data=pcall(function() return p:GetJoinData() end)
        local td=ok and data.TeleportData
        if type(td)=="table" and type(td.ticket)=="string" and #td.ticket<=100 and type(td.matchId)=="string" and #td.matchId<=100
            and data.SourceGameId==game.GameId and data.SourcePlaceId==game.PlaceId then
            local accepted=false
            local success,state=pcall(function() return self.transport:update(function(s)
                s=s or Pool.empty(); Pool.prune(s,os.time())
                Pool.arrive(s,p.UserId,td.ticket,td.matchId,game.JobId,os.time())
                return s
            end) end)
            if success then
                local t=state.tickets[tostring(p.UserId)]
                accepted=t and t.token==td.ticket and t.server==game.JobId and t.arrived==true
            end
            if p.Parent~=Players then return end
            if accepted then self.tokens[p.UserId]=td.ticket; self.arrived[p.UserId]=true else self.status="ArrivalRejected"; self.errors+=1 end
        end
    end
    self:register(p)
    self.joined[p.UserId]=true
    if self.arrived[p.UserId] and self.onArrival then self.onArrival(p) end
end
function Service:cancel(p)
    if not self.policy:cancel(p.UserId) then return false end
    self.sending[p]=nil
    self.approved[p.UserId]=nil
    if self.transport.enabled then
        local id,token=p.UserId,self.tokens[p.UserId]
        self.tokens[id]=nil
        task.spawn(function()
            local ok=pcall(function() self.transport:update(function(s)
                s=s or Pool.empty(); Pool.cancel(s,id,game.JobId,token,os.time()); return s
            end) end)
            if not ok then self.errors+=1 end
        end)
    end
    return true
end
function Service:remove(p)
    if not self.sending[p] then self:cancel(p) end
    self.policy:leave(p.UserId)
    self.players[p.UserId],self.tokens[p.UserId],self.last[p],self.sending[p],self.approved[p.UserId]=nil,nil,nil,nil,nil
    self.arrived[p.UserId],self.joined[p.UserId]=nil,nil
end
function Service:poll()
    if self.busy then return end
    for p,attempt in pairs(self.sending) do
        if os.clock()>=attempt.deadline then
            self.sending[p]=nil; self.status="TransportFailed"; self.errors+=1
            self:cancel(p); self:register(p)
        end
    end
    self.busy=true
    local now,matchId=os.time(),Http:GenerateGUID(false)
    local registrations,present={},{}
    for id,p in pairs(self.players) do
        if p.Parent==Players then
            present[id]=true
            local r=self.policy.entries[id]
            if r and r.state~="Active" and not self.sending[p] then registrations[id]={token=self.tokens[id],consent=r.consent} end
        end
    end
    local ok,state=pcall(function() return self.transport:update(function(s)
        s=s or Pool.empty(); Pool.prune(s,now)
        for id,r in pairs(registrations) do Pool.register(s,id,game.JobId,r.token,now,Settings,r.consent) end
        Pool.match(s,matchId,now,Settings)
        for id in pairs(s.matches) do Pool.consume(s,id,game.JobId,present,now) end
        return s
    end) end)
    self.busy=false
    if not ok then
        self.status="MatchmakingFailed"; self.errors+=1; self.approved={}
        for _,r in pairs(self.policy.entries) do r.remoteReady=nil end
        return
    end
    self.status="Staging"
    local approved={}
    for id,registration in pairs(registrations) do
        local token=registration.token
        local p,t=self.players[id],state.tickets[tostring(id)]
        local m=t and t.match and state.matches[t.match]
        local entry=self.policy.entries[id]
        if entry then entry.remoteReady=m~=nil and t.token==token end
        if p and p.Parent==Players and self.policy.entries[id] and self.tokens[id]==token and t and t.token==token and m then
            if m.target==game.JobId and m.committed then approved[id]=true
            elseif m.target~=game.JobId and entry.consent and Pool.consented(state,m.id) and not self.sending[p] then
                self.sending[p]={id=m.id,token=token,deadline=os.clock()+Settings.assignmentLease}
                local sent=pcall(function() self.transport:send(p,m.target,m.id,token) end)
                if not sent then self.sending[p]=nil; self.status="TransportFailed"; self.errors+=1; self:cancel(p); self:register(p) end
            end
        end
    end
    self.approved=approved
end
function Service:eligible()
    local list={}
    for _,id in ipairs(self.policy:eligible()) do
        local p=self.players[id]
        if p and p.Parent==Players and (not self.transport.enabled or self.approved[id]) and not self.sending[p] then table.insert(list,p) end
    end
    return list
end
function Service:snapshot(p)
    local s=self.policy:snapshot(p.UserId)
    s.transport=self.status
    s.realHumans=#Players:GetPlayers()
    s.lobbyMimics=self.rt.mimics and self.rt.mimics:count("Lobby") or 0
    s.matchMimics=self.rt.mimics and self.rt.mimics:count("Match") or 0
    return s
end
return Service
