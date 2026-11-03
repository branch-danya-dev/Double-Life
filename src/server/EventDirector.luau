local Players = game:GetService("Players")
local Policy = require(script.Parent.EventPolicy)
local Practice = require(script.Parent.PracticePolicy)
local Scene = require(script.Parent.EventWorld)
local Director = {}
Director.__index = Director
function Director.new(context)
    local self = setmetatable(context, Director)
    self.policy, self.practice = Policy.new(self.config), Practice.new(self.config)
    self.scene, self.permits, self.reported = Scene.build(self.world), {}, 0
    local random = Random.new()
    self.choose = function(low, high) return random:NextInteger(low, high) end
    self.lights = {}
    for _, lamp in ipairs(self.scene.lamps) do
        table.insert(self.lights, {lamp = lamp, brightness = lamp.light.Brightness, color = lamp.part.Color})
    end
    local function bind(part, action, name, callback, neutral)
        local prompt = self.interactions.prompt(part, action, name, 0.75)
        self.interactions:bind(prompt, callback, neutral)
        return prompt
    end
    self.menuPrompt = bind(self.scene.console, "Выбрать мероприятие", "Пульт мероприятий", function(player)
        if self.roles:get(player) ~= "Owner" then self.tell(player, "Мероприятие выбирает владелец."); return end
        self.permits[player.UserId] = self.scope:now() + 20
        self.update:FireClient(player, "EventMenu")
    end)
    bind(self.scene.pedestal, "Вернуть реликвию", "Постамент · бальный зал, этаж 1", function(player)
        if self.policy:deliver(player.UserId, self.rounds:allows(player, false), self.scope:now()) then self:reportFinish()
        else self.tell(player, "Принесите реликвию во время поиска.") end
    end)
    bind(self.scene.bell, "Позвать охрану", "Сигнальный колокольчик", function(player)
        if self.guard:react("PracticeBell", self.world:point("Guard.Bell")) then
            self:activity(player, "Noise")
            self.tell(player, "Охрана осмотрит место и вернётся к патрулю.")
        else self.tell(player, "Охрана занята. Дождитесь возвращения к патрулю.") end
    end, true)
    return self
end
function Director:signal(name, payload)
    payload.roundId = self.rounds.policy.roundId
    self.signals[name]:Fire(payload) -- Server-only integration point, never a public remote.
end
function Director:start(player, kind, roundId)
    if roundId ~= self.rounds.policy.roundId or not self.scope.alive then return false end
    local reason = self.policy:reason(self.roles:get(player), self.rounds:allows(player, false), self.scope:now())
    if not reason and ((self.permits[player.UserId] or -1) < self.scope:now()
        or not self.interactions:inReach(player, self.menuPrompt)) then reason = "Откройте меню у пульта мероприятий и оставайтесь рядом." end
    if reason then self.update:FireClient(player, "EventNotice", reason); return false end
    local ok, why = self.policy:start(self.roles:get(player), true, kind, self.scope:now())
    self.update:FireClient(player, "EventNotice", if ok then "Объявление началось. Участие добровольное." else why)
    if ok then self.permits[player.UserId] = nil end
    return ok
end
function Director:activity(player, key)
    if not self.scope.alive or not self.scope.running then return end
    local phase = self.rounds.policy.phase
    if phase == "Waiting" then
        local practiceKey = if string.sub(key, 1, 8) == "Painting" then "Painting" else key
        self.practice:activity(player.UserId, practiceKey, self.scope:now())
    elseif phase == "Active" then
        local eligible = self.rounds:allows(player, false)
        if self.policy:neutral(player.UserId, self.roles:get(player), eligible, key, self.scope:now(), self.choose) then
            self.tell(player, "Вы освоились в особняке. Продолжайте свои занятия.")
        end
    end
end
function Director:participated(id)
    self:signal("EventParticipated", {eventId = self.policy.serial, kind = self.policy.kind, userId = id})
end
-- Trusted server actors use the same incident and music rules, never Player APIs.
function Director:validMimic(actor)
    return self.actors and actor and self.actors:get(actor.id)==actor and actor.kind=="Mimic"
        and actor.role=="Guest" and self.rounds.policy.mimics[actor.id] and self.scope.alive
        and self.scope.running and self.rounds.policy.phase=="Active" and actor.model.Parent~=nil
end
function Director:actorActivity(actor, key)
    if not self:validMimic(actor) then return false end
    if key~="Painting1" and key~="Painting2" and key~="Painting3" and key~="Social.TraceSpot" then return false end
    local position=if self.world.objects[key] then self.world:approach(key) else self.world:point(key)
    local root=actor.model:FindFirstChild("HumanoidRootPart")
    if not root or (root.Position-position).Magnitude>6 then return false end
    return self.policy:neutral(actor.id,"Guest",true,key,self.scope:now(),self.choose)
end
function Director:sampleMimic(actor)
    if not self:validMimic(actor) then return false end
    local root=actor.model:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local pos=root.Position
    local offset=pos-self.scene.stage.Position
    local inside=math.abs(offset.X)<self.scene.stage.Size.X/2 and math.abs(offset.Z)<self.scene.stage.Size.Z/2
        and offset.Y>0 and offset.Y<7
    return self.policy:sample(actor.id,pos.X,pos.Z,inside,self.scope:now())
end
function Director:spawnRelic()
    local position = self.scene.relicSpots[self.choose(1, #self.scene.relicSpots)]
    self.relic = self.world.block("EventRelic", Vector3.new(1.3, 1.8, 1.3), position, self.world.gold, Enum.Material.Neon)
    self.relic.CanCollide, self.relic.Massless = false, true
    self.relicPrompt = self.interactions.prompt(self.relic, "Взять реликвию", "Реликвия · отнесите на постамент", 0.75)
    self.interactions:bind(self.relicPrompt, function(player)
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local ok, first = self.policy:pickup(player.UserId, self.rounds:allows(player, false))
        if not ok then return end
        self.relicPrompt.Enabled, self.relic.Anchored, self.relic.CanQuery = false, false, false
        self.relic.CFrame = root.CFrame * CFrame.new(0, 0, -2)
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1, weld.Parent = root, self.relic, self.relic
        if first then self:participated(player.UserId) end
        self.tell(player, "Реликвия у вас: верните на постамент в бальном зале, этаж 1. G — положить в доступном месте.")
    end)
end
function Director:drop(player)
    if not self.policy:drop(player.UserId) or not self.relic then return false end
    local weld = self.relic:FindFirstChildOfClass("WeldConstraint")
    if weld then weld:Destroy() end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local position = if root then root.Position else self.scene.pedestal.Position
    local spots = table.clone(self.scene.relicSpots)
    table.sort(spots, function(a, b) return (a - position).Magnitude < (b - position).Magnitude end)
    self.relic.Anchored, self.relic.CanQuery, self.relic.Position = true, true, spots[1]
    self.relicPrompt.Enabled = true
    return true
end
function Director:clearRelic()
    if self.relic then self.relic:Destroy() end
    self.relic, self.relicPrompt = nil, nil
end
function Director:reportFinish()
    local p = self.policy
    if p.phase ~= "Finished" or self.reported == p.serial then return end
    self.reported, self.attention = p.serial, nil
    self:clearRelic()
    local humanAwards={}
    for id,points in pairs(p.awards) do if type(id)=="number" then humanAwards[id]=points end end
    self:signal("EventFinished", {eventId = p.serial, kind = p.kind, cancelled = p.cancelled, awards = humanAwards})
    for id, points in pairs(p.awards) do
        local player = if type(id)=="number" then Players:GetPlayerByUserId(id) else nil
        if player then self.tell(player, "Мероприятие завершено: +" .. points .. " сессионных очков.") end
    end
end
function Director:setBlackout(enabled)
    for _, saved in ipairs(self.lights) do
        if saved.lamp.part.Parent then
            saved.lamp.light.Brightness = if enabled then 0.1 else saved.brightness
            saved.lamp.part.Color = if enabled then Color3.fromRGB(45, 50, 62) else saved.color
        end
    end
    self.blackout = enabled
end
function Director:cancel()
    self.policy:finish(self.scope:now(), true)
    self:reportFinish()
    self.policy.pendingIncident, self.policy.incident = nil, nil
    self.attention, self.permits = nil, {}
    self.practice:clear()
    self:clearRelic()
    self:setBlackout(false)
end
function Director:remove(player)
    self:drop(player)
    self.policy:remove(player.UserId)
    self.practice.records[player.UserId], self.permits[player.UserId] = nil, nil
end
function Director:resetCharacter(player)
    self:drop(player)
    self.policy.trials[player.UserId] = nil
end
function Director:tick()
    local phase, now = self.rounds.policy.phase, self.scope:now()
    if phase ~= self.lastPhase then
        self.permits = {}
        if phase ~= "Waiting" then self.practice:clear() end
        if phase == "Results" then self:cancel() end
        self.lastPhase = phase
    end
    if not self.scope.alive or not self.scope.running or phase ~= "Active" then return end
    local p = self.policy
    local transition = p:advance(now)
    if transition == "Running" then
        self:signal("EventStarted", {eventId = p.serial, kind = p.kind})
        self.attention = {untilTime = now + 10, point = self.world:point("Guard.Event")}
        if p.kind == "Relic" then self:spawnRelic() end
    elseif transition == "Finished" then self:reportFinish() end
    if self.attention then
        if now >= self.attention.untilTime or self.guard:react("Event" .. p.serial, self.attention.point) then self.attention = nil end
    end
    if p.phase == "Running" and p.kind == "Music" then
        for _, player in ipairs(Players:GetPlayers()) do
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            local pos = if root then root.Position else Vector3.zero
            local offset = pos - self.scene.stage.Position
            local inside = self.rounds:allows(player, false) and humanoid ~= nil and humanoid.Health > 0
                and math.abs(offset.X) < self.scene.stage.Size.X / 2 and math.abs(offset.Z) < self.scene.stage.Size.Z / 2 and offset.Y > 0 and offset.Y < 7
            if p:sample(player.UserId, pos.X, pos.Z, inside, now) then self:participated(player.UserId) end
        end
    end
    local incident = p:advanceIncident(now)
    if incident == "Started" then
        if type(p.incident.source)=="number" then
            self:signal("GuestIncidentTriggered", {kind = p.incident.kind, userId = p.incident.source})
        end
        if p.incident.kind == "Blackout" then self:setBlackout(true)
        else
            local spots = self.world:points("Guard.Incidents")
            p.incident.point = spots[self.choose(1, #spots)]
        end
    elseif incident == "Finished" then self:setBlackout(false) end
    if p.incident and p.incident.kind == "Inspection" and not p.incident.dispatched then
        p.incident.dispatched = self.guard:react("GuestIncident", p.incident.point)
    end
    local dancing = p.phase == "Running" and p.kind == "Music"
    self.scene.beacon.Color = if dancing and p.beat == "Move" then Color3.fromRGB(86, 205, 130) else Color3.fromRGB(231, 173, 81)
    self.scene.stage.Color = self.scene.beacon.Color
    self.scene.label.Text = if dancing then (if p.beat == "Move" then "ДВИГАЙСЯ" else "ЗАМРИ") .. " · " .. p.beatIndex .. "/3 · " .. math.max(0, math.ceil(p.endsAt - now)) .. " с"
        elseif p.phase == "Running" then "Найдите реликвию → постамент в бальном зале, этаж 1" else "Площадка мероприятий"
end
function Director:snapshot(player)
    local p, now, phase = self.policy, self.scope:now(), self.rounds.policy.phase
    local entry = p.participants[player.UserId]
    local event = {phase = p.phase, kind = p.kind, id = p.serial, remaining = math.max(0, math.ceil((p.endsAt or now) - now)),
        beat = p.beat, beatIndex = p.beatIndex, score = p.scores[player.UserId] or 0,
        passes = if entry then entry.passes or 0 else 0, reward = p.awards and p.awards[player.UserId] or 0,
        hasRelic = p.carrier == player.UserId, delivered = p.delivered, cancelled = p.cancelled, paused = phase == "Council"}
    local incident = if p.incident then {kind = p.incident.kind, remaining = math.max(0, math.ceil(p.incident.endsAt - now))} else nil
    local practice
    if phase == "Waiting" then
        local r = self.practice:get(player.UserId, now)
        practice = {step = r.step, remaining = math.max(0, math.ceil(r.endsAt - now))}
    end
    local owner
    if self.roles:get(player) == "Owner" and self.rounds.policy.participants[player.UserId] then
        owner = {usesLeft = self.config.EVENT_LIMIT - p.used, cooldown = math.max(0, math.ceil(p.readyAt - now)),
            reason = p:reason("Owner", self.rounds:allows(player, false), now)}
    end
    return {event = event, incident = incident, practice = practice, owner = owner}
end
return Director
