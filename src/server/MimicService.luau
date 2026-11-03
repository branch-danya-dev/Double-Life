local Policy=require(script.Parent.ActorPolicy)
local Settings=require(script.Parent.MatchSettings)
local Clock=require(script.Parent.SessionClock)
local Rig=require(script.Parent.MimicRig)
local Service={}; Service.__index=Service
function Service.new(rt)
    return setmetatable({rt=rt,values={},serial=0,busy=0,creating=false,nextCreate=0,lastTick=0,
        lobbyClock=Clock.new(),metrics={jobs=0,actions=0,matchActions=0,upperArrivals=0,orders=0,failures=0,maxWorkers=0}},Service)
end
function Service:count(context)
    local n=0; for _,a in pairs(self.values) do if a.context==context then n+=1 end end; return n
end
function Service:remove(a)
    self.rt.actors:remove(a.actor.id)
    self.rt.rounds.policy:removeMimic(a.actor.id)
    if a.context=="Match" and self.rt.events then self.rt.events.policy:remove(a.actor.id) end
    if a.context=="Match" and self.rt.requests then self.rt.requests.ledger:remove(a.actor.id,self.rt.scope:now()) end
    a.mover.model:Destroy(); self.values[a.actor.id]=nil
end
function Service:reset()
    self.matchGoal=nil
    local list={}; for _,a in pairs(self.values) do if a.context=="Match" then table.insert(list,a) end end
    for _,a in ipairs(list) do self:remove(a) end
end
function Service:addPractice(scene,scope,owner,ready)
    self.serial+=1; local serial=self.serial
    task.spawn(function()
        local ok,mover,name=pcall(Rig.new,scene.world.npcs,serial,scene.world:spawn(2),scope)
        if not ok then self.metrics.failures+=1; return end
        if not scope.alive then mover.model:Destroy(); return end
        local actor=self.rt.actors:addMimic(mover.model,name)
        self.values[actor.id]={actor=actor,mover=mover,context="Prologue",owner=owner,scene=scene,index=serial,next=0,seen={},gesture=0}
        ready(actor)
    end)
end
function Service:removePractice(owner)
    local list={}; for _,a in pairs(self.values) do if a.context=="Prologue" and a.owner==owner then table.insert(list,a) end end
    for _,a in ipairs(list) do self:remove(a) end
end
function Service:greetPractice(owner)
    for _,a in pairs(self.values) do if a.owner==owner then a.gesture=a.mover.scope:now()+3 end end
end
function Service:create(context)
    self.creating=true; self.serial+=1
    local serial=self.serial
    local scope=if context=="Lobby" then self.lobbyClock else self.rt.scope
    local parent=self.rt.lobby.root
    if context=="Match" then
        parent=self.rt.world.map:FindFirstChild("Mimics")
        if not parent then parent=Instance.new("Folder"); parent.Name,parent.Parent="Mimics",self.rt.world.map end
    end
    local pos=if context=="Lobby" then self.rt.lobby.entrance else self.rt.world:point("Service.Home")+Vector3.new(4,0,0)
    task.spawn(function()
        local ok,mover,name=pcall(Rig.new,parent,serial,pos,scope)
        self.creating=false
        if not ok then self.metrics.failures+=1; return end
        if not scope.alive or (context=="Match" and self.rt.rounds.policy.phase~="Active" and self.rt.rounds.policy.phase~="Council") then mover.model:Destroy(); return end
        local actor=self.rt.actors:addMimic(mover.model,name)
        self.values[actor.id]={actor=actor,mover=mover,context=context,index=serial,next=scope:now()+serial%3,seen={},gesture=0}
        if context=="Match" then self.rt.rounds.policy:addMimic(actor.id) end
    end)
end
function Service:tick(dt)
    self.lobbyClock:advance(dt)
    local phase=self.rt.rounds.policy.phase
    local humans=#game:GetService("Players"):GetPlayers()
    local matchHumans=0; for _ in pairs(self.rt.rounds.policy.participants) do matchHumans+=1 end
    if phase=="Active" and not self.matchGoal then self.matchGoal=Policy.mimicCount(matchHumans,Settings.targetSize,Settings.maxMimics) end
    local desired={Lobby=Policy.mimicCount(humans,Settings.lobbyDensity,Settings.maxMimics),
        Match=if phase=="Active" or phase=="Council" then self.matchGoal or 0 else 0}
    local now=os.clock()
    if not self.creating and now>=self.nextCreate then
        for _,context in ipairs({"Match","Lobby"}) do
            if self:count(context)<desired[context] then self.nextCreate=now+2; self:create(context); break end
        end
    end
    if now-self.lastTick<0.1 then return end
    self.lastTick=now
    for _,a in pairs(self.values) do
        local mover,scope=a.mover,a.mover.scope
        if not scope.alive or not mover.root.Parent then continue end
        local detained=self.rt.rounds.policy.detained
        local events=self.rt.events
        local dancing=a.context=="Match" and events.policy.phase=="Running" and events.policy.kind=="Music"
            and (mover.root.Position-events.scene.stage.Position).Magnitude<12
        local freeze=dancing and events.policy.beat=="Freeze"
        local paused=a.context=="Match" and (phase~="Active" or (detained and detained.id==a.actor.id))
        mover.root.Anchored=paused==true
        if not paused then
            if mover.root:GetNetworkOwnershipAuto() or mover.root:GetNetworkOwner()~=nil then mover.root:SetNetworkOwner(nil) end
            for _,p in ipairs(game:GetService("Players"):GetPlayers()) do
                local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if root and (root.Position-mover.root.Position).Magnitude<7 and now>(a.nextGreeting or 0) then
                    a.gesture=scope:now()+1.5; a.nextGreeting=now+18
                end
            end
            mover:animate(now,scope:now()<a.gesture)
            if dancing then events:sampleMimic(a.actor) end
        end
        if freeze then mover:stop() end
        if paused or freeze or a.working or scope:now()<a.next or self.busy>=Settings.aiWorkers then continue end
        if a.context=="Lobby" and not a.retiring then
            local staying=0
            for _,other in pairs(self.values) do if other.context=="Lobby" and not other.retiring then staying+=1 end end
            if staying>desired.Lobby then a.retiring=true end
        end
        a.working=true; self.busy+=1; self.metrics.jobs+=1; self.metrics.maxWorkers=math.max(self.metrics.maxWorkers,self.busy)
        task.spawn(function()
            local ok=pcall(function()
                local retiring=a.retiring
                local pos,id
                if a.context=="Lobby" then
                    pos=if retiring then self.rt.lobby.entrance else self.rt.lobby.spots[a.index%#self.rt.lobby.spots+1]
                elseif a.context=="Prologue" then
                    local ids={"Painting1","Service.Target2","Events.Stage","Social.TraceSpot"}
                    id=ids[a.index%#ids+1]; pos=a.scene.world:approach(id)
                else
                    local ids={"Painting1","Service.Target2","Painting2","Events.Stage","Painting3","Social.TraceSpot"}
                    id=ids[a.index%#ids+1]
                    pos=if self.rt.world.objects[id] then self.rt.world:approach(id) else self.rt.world:point(id)
                end
                if mover:move(pos,scope:now()+30,function()
                    return not scope.alive or not self.values[a.actor.id] or (dancing and events.policy.beat=="Freeze")
                end) then
                    if retiring then self:remove(a); return end
                    a.gesture=scope:now()+2; self.metrics.actions+=1
                    if a.context=="Match" then
                        self.metrics.matchActions+=1
                        if mover.root.Position.Y>15 then self.metrics.upperArrivals+=1 end
                        if id=="Service.Target2" and self.rt.requests:createForActor(a.actor,2) then self.metrics.orders+=1 end
                        self.rt.events:actorActivity(a.actor,id)
                    end
                    a.seen[id or "Lobby"]=true
                    mover.model:SetAttribute("Activity",if id=="Service.Target2" then "Заказ сока" elseif id=="Events.Stage" then "Музыка"
                        elseif id=="Social.TraceSpot" then "Осмотр следов" else "Осмотр галереи")
                end
                a.index+=1
            end)
            if not ok then self.metrics.failures+=1 end
            a.working=false; self.busy-=1; a.next=scope:now()+3+a.index%5
        end)
    end
end
return Service
