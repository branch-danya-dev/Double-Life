local Players=game:GetService("Players")
local Content=require(script.Parent.PrologueContent)
local Policy=require(script.Parent.ProloguePolicy)
local Scene=require(script.Parent.PrologueWorld)
local Clock=require(script.Parent.SessionClock)
local Interactions=require(script.Parent.Interactions)
local Ledger=require(script.Parent.RequestLedger)
local Events=require(script.Parent.EventPolicy)
local Config=require(game:GetService("ReplicatedStorage").DoubleLifeShared.Config)
local Service={}; Service.__index=Service
function Service.new(rt,remote,tell,enabled)
    local self=setmetatable({rt=rt,records={},slots={},seen={},last={},tell=tell,enabled=enabled,settings=rt.settings},Service)
    if enabled then rt.queue.hold=function(p) return not self.records[p] or self.records[p].loading or self:active(p) end end
    if enabled then
        rt.queue.onAccept=function(p) return self:accept(p) end
        rt.queue.onLobby=function(p) return self:leave(p,"Lobby") end
        rt.queue.onArrival=function(p)
            -- This reservation already carried explicit consent on the source
            -- server. A slow admission check may finish after local bootstrap.
            local r=self.records[p]
            if self:active(p) then self.rt.telemetry:lesson(p,"Interrupted"); r.policy:leave("Match"); self:cleanup(p); self:back(p) end
            rt.queue.policy:consent(p.UserId,true)
        end
    end
    remote.OnServerEvent:Connect(function(p,action)
        if not self.enabled or os.clock()<(self.last[p] or 0) then return end
        self.last[p]=os.clock()+0.5
        if action=="Replay" then self:start(p)
        elseif action=="Skip" or action=="Lobby" then self:leave(p,action)
        elseif action=="Accept" then self:accept(p)
        elseif action=="Defer" and self.settings.allowInvite then
            local r=self.records[p]; if r and self:active(p) and rt.queue:snapshot(p).state=="MatchReady" then r.policy.deferred=true end
        elseif action=="Decline" then
            rt.telemetry:decision(p,false)
            local r=self.records[p]; if r and r.policy then r.policy.deferred=false end
            rt.queue:cancel(p)
        end
    end)
    return self
end
function Service:active(p)
    local r=self.records[p]; return r~=nil and r.policy~=nil and r.policy.state=="Active" and r.scene~=nil
end
function Service:add(p)
    if not self.enabled then return end
    local r={loading=true}; self.records[p]=r
    task.spawn(function()
        local deadline=os.clock()+3
        repeat
            local e=self.rt.profiles:entry(p)
            if e and e.loaded and self.rt.queue.joined[p.UserId] then break end
            task.wait(0.1)
        until p.Parent~=Players or os.clock()>=deadline
        if self.records[p]~=r or p.Parent~=Players then return end
        if self.settings.prologueOfferSeconds>0 then task.wait(self.settings.prologueOfferSeconds) end
        if self.records[p]~=r or p.Parent~=Players then return end
        r.loading=false
        local e=self.rt.profiles:entry(p)
        local marker=e and e.profile and e.profile.onboarding
        if self.seen[p.UserId] or (marker and marker.state~="Unseen") or self.rt.queue.arrived[p.UserId] then
            self.rt.queue.policy:consent(p.UserId,true)
        else self:start(p) end
    end)
end
function Service:position(p)
    local r=self.records[p]
    if self:active(p) then
        local step=Content.steps[r.policy.step]
        return r.scene:point(step.target)
    end
end
function Service:clearCarry(r)
    if r.carry then r.carry:Destroy() end
    r.carry,r.clue,r.copy=nil,nil,nil
end
function Service:carry(p,r,name)
    self:clearCarry(r)
    local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local part=Instance.new("Part"); part.Name,part.Size,part.Color=name,Vector3.new(1.5,0.2,1),Color3.fromRGB(194,158,87)
    part.CanCollide,part.CanQuery,part.Massless=false,false,true
    part.CFrame,part.Parent=root.CFrame*CFrame.new(0,0,-2),r.scene.root
    local weld=Instance.new("WeldConstraint"); weld.Part0,weld.Part1,weld.Parent=root,part,part
    r.carry=part; return true
end
function Service:cleanup(p)
    local r=self.records[p]; if not r then return end
    self:clearCarry(r)
    if r.scope then r.scope:destroy() end
    if r.interactions then r.interactions:clear(); r.interactions:remove(p) end
    self.rt.mimics:removePractice(p)
    if r.scene then r.scene.root:Destroy() end
    if r.slot then self.slots[r.slot]=nil end
    r.scene,r.scope,r.interactions,r.guide,r.slot,r.music,r.request=nil,nil,nil,nil,nil,nil,nil
end
function Service:back(p)
    if p.Character then p.Character:PivotTo(CFrame.new(self.rt.lobby:position(1))) end
end
function Service:mark(p,state)
    self.seen[p.UserId]=true
    local r=self.records[p]; r.mark=state
    r.pending=self.rt.profiles:onboarding(p,state)
end
function Service:leave(p,kind)
    if kind=="Skip" and not self.settings.allowSkip then return false end
    local r=self.records[p]
    if not self:active(p) or not r.policy:leave(kind) then return false end
    self.rt.telemetry:lesson(p,if kind=="Skip" then "Skipped" else "Interrupted")
    if kind=="Skip" then self:mark(p,"Skipped") else self.rt.queue:cancel(p) end
    self:cleanup(p); self:back(p)
    if kind=="Skip" then self.rt.queue.policy:consent(p.UserId,true) end
    return true
end
function Service:accept(p)
    if not self.settings.allowInvite or self.rt.queue:snapshot(p).state~="MatchReady" then return false end
    self.rt.telemetry:decision(p,true)
    local r=self.records[p]
    if self:active(p) then self.rt.telemetry:lesson(p,"Interrupted"); r.policy:leave("Match"); self:cleanup(p); self:back(p) end
    return self.rt.queue.policy:consent(p.UserId,true)
end
function Service:refresh(r)
    for index,prompt in pairs(r.prompts) do prompt.Enabled=r.policy.state=="Active" and index==r.policy.step end
end
function Service:start(p)
    if not self.enabled or p.Parent~=Players or self.rt.rounds.policy.participants[p.UserId] or self:active(p) then return false end
    local selected=self.rt.queue.policy.selected
    if selected and table.find(selected,p.UserId) then return false end
    local r=self.records[p] or {}; self.records[p]=r
    self:cleanup(p)
    if r.policy then r.policy:resume(); r.policy:resetCharacter() else r.policy=Policy.new(os.clock,Content) end
    r.loading=false
    for slot=1,15 do if not self.slots[slot] then self.slots[slot]=p; r.slot=slot; break end end
    if not r.slot then r.policy:leave("Capacity"); self.rt.queue.policy:consent(p.UserId,true); return false end
    r.scope=Clock.new(); r.scene=Scene.build(self.rt.world,r.slot)
    -- Resuming recreates geometry; restore prerequisites from completed chapters.
    if Content.steps[r.policy.step].chapter>=3 then
        r.scene.world.studyDoor.CanCollide=false; r.scene.world.studyDoor.Transparency=0.8
    end
    r.ledger=Ledger.new(Config); r.prompts={}
    r.interactions=Interactions.new({finished=false},function(other)
        return other==p and self.records[p]==r and self:active(p) and r.scope.alive
    end)
    for index,step in ipairs(Content.steps) do
        local prompt=Interactions.prompt(r.scene:object(step.target),step.action,"Знакомство · сцена "..step.chapter,if step.kind=="Copy" then 3 else 0.7)
        -- Only one checkpoint per object is active, so it needs no multi-prompt offset.
        prompt.UIOffset=Vector2.zero; r.prompts[index]=prompt
        r.interactions:bind(prompt,function() self:act(p,step.key) end,true)
    end
    self:refresh(r)
    self.rt.telemetry:lesson(p,"Started")
    self.rt.queue.policy:consent(p.UserId,false)
    self.rt.mimics:addPractice(r.scene,r.scope,p,function(actor) if r.scope and r.scope.alive then r.guide=actor end end)
    if p.Character then p.Character:PivotTo(CFrame.new(self:position(p))) end
    return true
end
function Service:advance(p,key)
    local r=self.records[p]
    local step=r.policy.step
    if not r.policy:act(key) then return false end
    self.rt.telemetry:lesson(p,"Checkpoint",step)
    self.rt.mimics:greetPractice(p)
    if r.policy.state=="Completed" then
        self.rt.telemetry:lesson(p,"Completed")
        self:mark(p,"Completed"); self:cleanup(p); self:back(p); self.rt.queue.policy:consent(p.UserId,true)
    elseif r.policy.deferred and self.rt.queue:snapshot(p).state=="MatchReady" then self:accept(p)
    else self:refresh(r) end
    return true
end
function Service:resetCharacter(p)
    local r=self.records[p]
    if not self:active(p) then return end
    self.rt.telemetry:lesson(p,"Reset")
    r.policy:resetCharacter(); self:clearCarry(r)
    r.ledger,r.request,r.music=Ledger.new(Config),nil,nil
    r.interactions:clear(); self:refresh(r)
end
function Service:act(p,key)
    local r=self.records[p]
    if not self:active(p) then return false end
    local step=Content.steps[r.policy.step]
    if not step or step.key~=key then return false end
    local kind,now=step.kind,r.scope:now()
    if kind=="Order" then
        if not r.guide then self.tell(p,"Сопровождающий подходит. Повторите через секунду."); return false end
        r.request=r.ledger:create(r.guide.id,2,now)
        if not r.request or not r.ledger:accept(p.UserId,now,false) then return false end
    elseif kind=="Pickup" then
        if not r.request or not r.ledger:pickup(r.request,p.UserId,now) or not self:carry(p,r,"PracticeTray") then
            self:resetCharacter(p); self.tell(p,"Заказ истёк. Примите поручение снова."); return false
        end
    elseif kind=="Delivery" then
        if not r.carry or not r.request or not r.ledger:deliver(r.request,p.UserId,now) then
            self:resetCharacter(p); self.tell(p,"Доставка не завершена. Вернитесь к стойке."); return false
        end
        self:clearCarry(r)
        local cup=r.scene.world.block("PracticeJuice",Vector3.new(0.6,1,0.6),r.scene:object(step.target).Position+Vector3.new(0,1.6,0),Color3.fromRGB(255,180,64))
        cup.CanCollide=false
    elseif kind=="Access" then r.scene.world.studyDoor.CanCollide=false; r.scene.world.studyDoor.Transparency=0.8
    elseif kind=="Clue" then if not self:carry(p,r,"PracticeClue") then return false end; r.clue=true
    elseif kind=="DropClue" then if not r.clue then return false end; self:clearCarry(r)
    elseif kind=="Copy" then if not self:carry(p,r,"PracticeCopy") then return false end; r.copy=true
    elseif kind=="ReturnCopy" then if not r.copy then return false end; self:clearCarry(r)
    elseif kind=="MusicStart" or kind=="Music" then
        if kind=="Music" and r.music and (r.music.phase=="Announcing" or r.music.phase=="Running") then return false end
        r.music=Events.new(Config); r.music:start("Owner",true,"Music",now)
        if kind=="Music" then return true end
    elseif kind=="Blackout" or kind=="Restore" then
        for _,lamp in ipairs(r.scene.events.lamps) do lamp.light.Brightness=if kind=="Blackout" then 0.15 else 1.4 end
    elseif kind=="Signal" then
        local root=p.Character and p.Character:FindFirstChild("Head")
        if root then
            local sign=Instance.new("BillboardGui"); sign.Size,sign.StudsOffset,sign.Adornee,sign.Parent=UDim2.fromOffset(60,40),Vector3.new(0,2,0),root,r.scene.root
            local label=Instance.new("TextLabel"); label.Size,label.BackgroundTransparency,label.Text,label.TextSize,label.Parent=UDim2.fromScale(1,1),1,"◇",30,sign
            r.scope:delay(2,function() sign:Destroy() end)
        end
    end
    return self:advance(p,key)
end
function Service:tick(dt)
    for p,r in pairs(self.records) do
        if not self:active(p) then continue end
        r.scope:advance(dt)
        if r.policy:tick()=="Timeout" then self.rt.telemetry:lesson(p,"Interrupted"); self.rt.queue:cancel(p); self:cleanup(p); self:back(p); continue end
        if r.music then
            local now=r.scope:now(); local transition=r.music:advance(now)
            local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            local stage=r.scene.events.stage
            if root then
                local pos=root.Position; local d=pos-stage.Position
                r.music:sample(p.UserId,pos.X,pos.Z,math.abs(d.X)<stage.Size.X/2 and math.abs(d.Z)<stage.Size.Z/2 and d.Y>0 and d.Y<7,now)
            end
            local moving=r.music.phase=="Running" and r.music.beat=="Move"
            stage.Color=if moving then Color3.fromRGB(86,205,130) else Color3.fromRGB(231,173,81)
            r.scene.events.label.Text=if r.music.phase=="Running" then (if moving then "ДВИГАЙСЯ" else "ЗАМРИ") else "Музыкальная проба"
            if transition=="Finished" and Content.steps[r.policy.step].kind=="Music" then
                local participant=r.music.participants[p.UserId]
                if participant and participant.passes>=1 then self:advance(p,"Music")
                else self.tell(p,"Попробуйте ещё раз: двигайтесь на зелёный свет, остановитесь на золотой.") end
            end
        end
    end
end
function Service:remove(p)
    self:cleanup(p); self.records[p],self.last[p]=nil,nil
end
function Service:snapshot(p)
    local r=self.records[p]; local active=self:active(p)
    local step=active and Content.steps[r.policy.step]
    local saved="Только в этой сессии"
    local e=self.rt.profiles:entry(p)
    if r and r.mark and e and e.profile and e.profile.onboarding.state==r.mark then
        saved=if self.rt.profiles.adapter.mode=="FakeMemory" then "Подтверждено в тестовой памяти" else "Сохранение подтверждено"
    elseif r and r.pending then saved="Ожидаем подтверждения; пока только эта сессия" end
    return {active=active,available=self.enabled,allowSkip=self.settings.allowSkip,allowInvite=self.settings.allowInvite,state=r and r.policy and r.policy.state or "Lobby",step=active and r.policy.step or 0,
        total=#Content.steps,chapter=step and step.chapter,text=step and step.text,action=step and step.action,
        target=step and r.scene:point(step.target),object=step and r.scene:object(step.target),scene=active and r.scene.root,
        saved=saved,deferred=active and r.policy.deferred or false,elapsed=active and os.clock()-r.policy.started or 0,
        music=r and r.music and {phase=r.music.phase,beat=r.music.beat} or nil}
end
return Service
