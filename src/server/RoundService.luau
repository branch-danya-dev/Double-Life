local Players = game:GetService("Players")
local Policy = require(script.Parent.RoundPolicy)
local RoundService = {}
RoundService.__index = RoundService
function RoundService.new(config, roles, tell, finished)
    return setmetatable({policy = Policy.new(config, 2), roles = roles, tell = tell,
        finished = finished, protocol = {}, roster = {}, reported = 0}, RoundService)
end
function RoundService:allows(player, neutral)
    local p = self.policy
    if p.phase == "Waiting" then return neutral == true end
    return p.phase == "Active" and p.participants[player.UserId] == true
        and (not p.detained or p.detained.id ~= player.UserId)
end
function RoundService:sync()
    local p, session = self.policy, self.session
    session.scope.running = p.phase == "Active" or p.phase == "Waiting"
    session.state.finished = p.phase == "Results"
    local paused = not session.scope.running
    for _, mover in ipairs({session.guard.mover, session.requests.npc}) do
        if mover.root.Parent then
            if mover.root.Anchored ~= paused then
                mover.root.Anchored = paused
            end
            -- Physics can restore automatic ownership when an assembly is rebuilt,
            -- unanchored, or gains/loses a welded service tray.
            -- Reassert on subsequent Heartbeats as well, after the physics transition settles.
            if not paused and (mover.root:GetNetworkOwnershipAuto() or mover.root:GetNetworkOwner() ~= nil) then
                mover.root:SetNetworkOwner(nil)
            end
            if paused then mover.humanoid:MoveTo(mover.root.Position) end
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do self:lockCharacter(player) end
end
function RoundService:lockCharacter(player)
    local p = self.policy
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root then
        root.Anchored = p.participants[player.UserId] == true and (p.phase == "Council" or p.phase == "Results"
            or (p.phase == "Active" and p.detained ~= nil and p.detained.id == player.UserId))
    end
end
function RoundService:report()
    local p = self.policy
    if p.phase ~= "Results" or self.reported == p.roundId then return end
    self.reported = p.roundId
    self.session.interactions:clear()
    if self.session.events then self.session.events:cancel() end
    self:sync()
    self.finished:Fire({roundId = p.roundId, winner = p.result.winner, reason = p.result.reason})
end
function RoundService:extract(id)
    if self.policy:extract(id) then self:report(); return true end
    return false
end
function RoundService:callCouncil(player)
    if self.roles:get(player) ~= "Owner" or not self:allows(player, false) then return false end
    if not self.policy:council(player.UserId) then
        self.tell(player, "Одно собрание за раунд; доступно через 30 секунд активной игры.")
        return false
    end
    self.session.interactions:clear()
    self:sync()
    return true
end
function RoundService:vote(player, target, roundId, attach)
    local validTarget = (typeof(target) == "number" and target % 1 == 0)
        or (typeof(target) == "string" and self.policy.mimics[target] == true)
    if not validTarget or typeof(attach) ~= "boolean" then return false end
    local proof = if attach then self.session.evidence:description(player.UserId) else nil
    if attach and not proof then return false end
    if not self.policy:vote(player.UserId, target, roundId) then return false end
    self.protocol[player.UserId] = {voter = player.UserId, target = target, evidence = proof}
    return true
end
function RoundService:leave(player)
    self.policy:leave(player.UserId)
    self.protocol[player.UserId] = nil
    for id, entry in pairs(self.protocol) do
        if entry.target == player.UserId then self.protocol[id] = nil end
    end
    self:report()
end
function RoundService:snapshot(player)
    local p = self.policy
    local members, protocol = {}, {}
    for _, member in ipairs(self.roster) do
        if p.participants[member.id] then table.insert(members, {id = member.id, name = member.name}) end
    end
    for id in pairs(p.mimics) do
        local actor = self.session.actors:get(id)
        if actor then table.insert(members, {id=id,name=actor.name .. " · персонаж"}) end
    end
    for _, entry in pairs(self.protocol) do table.insert(protocol, entry) end
    local result
    if p.phase == "Results" then result = {winner = p.result.winner, reason = p.result.reason, roles = self.roster} end
    return {phase = p.phase, roundId = p.roundId, remaining = math.ceil(p.remaining),
        activeRemaining = math.ceil(if p.phase == "Council" then p.savedRemaining else p.remaining),
        participating = p.participants[player.UserId] == true, members = members,
        canCall = p.phase == "Active" and not p.councilUsed and p.elapsed >= p.config.COUNCIL_DELAY
            and self.roles:get(player) == "Owner" and p.participants[player.UserId] == true,
        voted = p.cast[player.UserId] == true, protocol = protocol, result = result,
        search = if p.detained then {id = p.detained.id, remaining = math.ceil(p.detained.untilTime - p.elapsed)} else nil}
end
function RoundService:tick(dt)
    local players = Players:GetPlayers()
    local queue = self.session.queue
    local eligible = if queue then queue:eligible() else players
    local action, target = self.policy:tick(dt, #eligible)
    if action == "Start" then
        local ids = self.roles:assign(eligible)
        local spies = {}
        self.roster = {}
        for _, player in ipairs(players) do
            local role = self.roles:get(player)
            if table.find(ids, player.UserId) then
                if role == "Spy" then table.insert(spies, player.UserId) end
                table.insert(self.roster, {id = player.UserId, name = player.Name, role = role})
            end
        end
        self.policy:activate(ids, spies)
        if queue then queue.policy:start(ids) end
        self.rebuild(true)
    elseif action == "Search" then
        local player = if type(target)=="number" then Players:GetPlayerByUserId(target) else nil
        local actor = target and self.session.actors:get(target)
        if player then self.session.dossier:search(player) end
        self.session.interactions:clear()
        for _, other in ipairs(players) do
            self.tell(other, if player or actor then "Досмотр: " .. (if player then player.Name else actor.name) .. ". Пауза для него — 12 с; роль не раскрывается."
                else "Большинства нет. Никто не задержан; игра продолжается.")
        end
    elseif action == "Reset" then
        self.roles:clear()
        self.roster, self.protocol = {}, {}
        self.policy.participants, self.policy.votes, self.policy.cast, self.policy.detained = {}, {}, {}, nil
        self.policy.mimics = {}
        if queue then queue.policy:reset() end
        self.rebuild(false)
    elseif action == "Countdown" or action == "Waiting" then
        if queue then
            if action=="Countdown" then
                local ids={}; for _,p in ipairs(eligible) do table.insert(ids,p.UserId) end
                queue.policy:select(ids)
            else queue.policy.selected=nil end
        end
        self.session.interactions:clear()
    end
    self:report()
    self:sync()
end
return RoundService
