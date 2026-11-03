local Policy = {}
Policy.__index = Policy
Policy.events = {Join = true, SessionSeconds = true, FirstMatch = true, RepeatMatch = true, MatchStarted = true,
    Waiting = true, Countdown = true, Active = true, Council = true, Results = true, Win = true, Loss = true,
    ShopOpen = true, Offer = true, Purchase = true}
for _,name in ipairs({"FirstMeaningfulAction","PrologueStarted","PrologueCheckpoint","PrologueCompleted","PrologueSkipped","PrologueInterrupted",
    "QueueEntered","OpponentFound","MatchReady","ReadyAccepted","ReadyDeclined","QueueCancelled","QueueTimeout","MatchmakingFailed","TransportFailed",
    "QueueToStart","RealHumans","LobbyMimics","MatchMimics","RoundFinished","RoundActiveSeconds","FirstMatchCompleted","NextMatchQueued",
    "Exit","SessionEnded","ActiveSeconds","TransferArrived","TransferDeparted"}) do Policy.events[name]=true end
local values={cohort={["1"]=true,["2"]=true,["3-4"]=true,["5-7"]=true,["8-15"]=true},
    context={Lobby=true,Prologue=true,Match=true,Results=true},
    detail={None=true,Local=true,Remote=true,Reset=true,Abandoned=true,Timeout=true,Objective=true,Transfer=true,Departure=true,Over900=true}}
for _,n in ipairs({30,60,180,300,600,900}) do values.detail["Under"..n]=true end
for n=1,25 do values.detail["Step"..n]=true end
function Policy.new(send, now)
    return setmetatable({send = send, now = now, last = {},budgets={},global={tokens=120,at=now()},
        stats={accepted=0,failed=0,invalid=0,rateLimited=0}}, Policy)
end
local function spend(b,now,capacity,rate)
    b.tokens=math.min(capacity,b.tokens+math.max(0,now-b.at)*rate); b.at=now
    if b.tokens<1 then return false end
    b.tokens-=1; return true
end
function Policy:emit(player, event, value,fields,trustedTransition)
    if not Policy.events[event] or (value ~= nil and (type(value) ~= "number" or value ~= value or value < 0 or value > 86400)) then self.stats.invalid+=1; return false end
    if fields~=nil then
        if type(fields)~="table" then self.stats.invalid+=1; return false end
        for k,v in pairs(fields) do if not values[k] or not values[k][v] then self.stats.invalid+=1; return false end end
        for k in pairs(values) do if fields[k]==nil then self.stats.invalid+=1; return false end end
        fields=table.clone(fields)
    end
    local state = self.last[player] or {}
    self.last[player] = state
    local now = self.now()
    local delay = if event == "ShopOpen" or event == "Offer" then 15 else 1
    if not trustedTransition and now < (state[event] or 0) then self.stats.rateLimited+=1; return false end
    local budget=self.budgets[player] or {tokens=64,at=now}; self.budgets[player]=budget
    if not spend(budget,now,64,0.5) or not spend(self.global,now,120,4) then self.stats.rateLimited+=1; return false end
    state[event] = now + delay
    local ok,result=pcall(self.send, player, event, value or 1,fields)
    if not ok or result==false then self.stats.failed+=1; return false end
    self.stats.accepted+=1
    return true
end
function Policy:remove(player) self.last[player],self.budgets[player]=nil,nil end
return Policy
