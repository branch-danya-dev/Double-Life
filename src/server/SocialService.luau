local Players = game:GetService("Players")
local Policy = require(script.Parent.SocialPolicy)
local Service = {}
Service.__index = Service
function Service.new(rt, tell, onTask)
    local self = setmetatable({rt = rt, tell = tell, onTask = onTask, policy = Policy.new(), nextAction = {}, marks = {}}, Service)
    local w, interactions = rt.world, rt.interactions
    local function block(name, position, color)
        local part = w.block(name, Vector3.new(1.5, 1, 1.5), position, color)
        part.CanCollide = false
        return part
    end
    self.reader, self.egress = w:object("Social.PassReader"), w:object("Social.Egress")
    self.collection, self.stand = w:object("Social.ParcelHome"), w:object("Social.Cloth")
    self.delivery, self.plantSpot = w:object("Social.Delivery"), w:object("Social.TraceSpot")
    self.parts, self.homes, self.prompts = {}, {}, {}
    local function bind(part, action, object, seconds, fn)
        local p = interactions.prompt(part, action, object, seconds)
        interactions:bind(p, fn)
        return p
    end
    bind(self.egress, "Выйти в холл", "Выход изнутри · 8 с", 1, function()
        rt.access.open(w.studyDoor, 8)
    end)
    for key, home in pairs({Parcel = self.collection, Cloth = self.stand}) do
        local part = block("Social" .. key, home.Position + Vector3.new(0, 1.3, 0), home.Color)
        self.parts[key], self.homes[key] = part, part.CFrame
        self.prompts[key] = bind(part, "Подобрать", if key == "Parcel" then "Экспонат → служебный холл, этаж 1" else "Ткань → терраса, этаж 2", 1, function(player)
            if self.policy:pickup(player.UserId, key, rt.scope:now()) then self:tick() end
        end)
    end
    bind(self.reader, "Приложить пропуск", "Проход на 10 с · пропуск владельца на 60 с", 1, function(player)
        if self.policy:usePass(player.UserId, rt.scope:now()) then
            rt.access.open(w.studyDoor, 10)
            onTask(player, "Access", 1)
            tell(player, "Проход открыт на 10 с. На считывателе остался след; через дверь могут пройти другие.")
        else tell(player, "Нужен действующий пропуск владельца. Выбор участника — J у пульта.") end
    end)
    bind(self.delivery, "Передать экспонат", "Поручение гостю/персоналу · один раз", 2, function(player)
        if self.policy:deliver(player.UserId, rt.roles:get(player), rt.scope:now()) then
            onTask(player, "Collection", 1); tell(player, "Экспонат доставлен. Проверенное поручение выполнено.")
        end
    end)
    bind(self.plantSpot, "Оставить ткань", "Нейтральный след · 3 с · максимум дважды", 3, function(player)
        if self.policy:plant(player.UserId, rt.scope:now()) then
            rt.guard:react("Glass", self.plantSpot.Position)
            tell(player, "Ткань у рамы заметна 45 с. Она не доказывает, кто и зачем её оставил.")
        end
    end)
    for key, part in pairs({Reader = self.reader, Collection = self.collection, Fabric = self.plantSpot}) do
        local p = bind(part, "Проверить изменение", "След без имени · не доказательство вины", 1, function(player)
            if rt.roles:get(player) ~= "CounterAgent" then tell(player, "Подробный осмотр доступен контрразведке."); return end
            local untilTime = self.policy.traces[key]
            tell(player, if untilTime then ({Reader = "Считыватель ещё тёплый: допуск использовали менее 45 с назад.",
                Collection = "Пыль на месте экспоната смещена менее 60 с назад.",
                Fabric = "У рамы ткань. Её можно перенести: происхождение и владелец неизвестны."})[key] else "Свежего изменения нет.")
            if untilTime then onTask(player, "Trace", 1) end
        end)
        p.KeyboardKeyCode = Enum.KeyCode.F
    end
    return self
end
function Service:valid(player)
    local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local human = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return root and human and human.Health > 0 and player.Parent == Players and self.rt.rounds:allows(player, false) and root or nil
end
function Service:near(player, position, targetCharacter)
    local root = self:valid(player)
    if not root or (root.Position - position).Magnitude > 9 then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {player.Character, targetCharacter or self.rt.world.console}
    return workspace:Raycast(root.Position, position - root.Position, params) == nil
end
function Service:request(player, action, target, roundId)
    if roundId ~= self.rt.rounds.policy.roundId or not self:valid(player) then return false end
    local id, now = player.UserId, self.rt.scope:now()
    if now < (self.nextAction[id] or 0) then return false end
    self.nextAction[id] = now + 0.5
    if action == "Drop" then self:drop(player); return true end
    if action == "Signal" then
        if not self.policy:signal(id, target, now) then return false end
        if self.marks[id] then self.marks[id]:Destroy() end
        local mark = Instance.new("BillboardGui")
        mark.Name, mark.Size, mark.StudsOffset, mark.MaxDistance = "ContextSignal", UDim2.fromOffset(45, 45), Vector3.new(0, 4, 0), 40
        mark.Adornee, mark.Parent = player.Character:FindFirstChild("Head"), self.rt.world.map
        local label = Instance.new("TextLabel")
        label.Size, label.Text, label.TextSize, label.BackgroundTransparency = UDim2.fromScale(1, 1), Policy.signals[target], 32, 0.25
        label.Parent = mark
        self.marks[id] = mark
        self.rt.scope:delay(3, function() mark:Destroy(); if self.marks[id] == mark then self.marks[id] = nil end end)
        return true
    end
    if type(target) ~= "number" or target % 1 ~= 0 then return false end
    local other = Players:GetPlayerByUserId(target)
    local root = self:valid(other)
    if not root or other == player then return false end
    if action == "Grant" then
        if not self:near(player, self.rt.world.console.Position) then return false end
        return self.policy:grant(self.rt.roles:get(player), target, now)
    end
    if not self:near(player, root.Position, other.Character) then return false end
    if action == "Offer" then return self.policy:offer(id, target, now) end
    if action == "Accept" then return self.policy:accept(id, target, now) end
    return false
end
function Service:drop(player)
    local key = self.policy:drop(player.UserId, self.rt.scope:now())
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if key then self.parts[key].CFrame = if root then CFrame.new(self.rt.world:dropPoint(root.Position, self.homes[key].Position, 0.55)) else self.homes[key] end
end
function Service:remove(player)
    self:drop(player)
    self.policy:remove(player.UserId, self.rt.scope:now())
    if self.marks[player.UserId] then self.marks[player.UserId]:Destroy(); self.marks[player.UserId] = nil end
end
function Service:tick()
    local now = self.rt.scope:now()
    self.policy:tick(now)
    for key, item in pairs(self.policy.items) do
        local part = self.parts[key]
        self.prompts[key].Enabled = not item.owner and now >= (item.readyAt or 0)
        part.Transparency = if self.prompts[key].Enabled or item.owner then 0 else 1
        part.CanQuery = not item.owner
        if item.owner then
            local player = Players:GetPlayerByUserId(item.owner)
            local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root then part.CFrame = root.CFrame * CFrame.new(1.5, -0.5, -1) end
        end
        if item.place == item.home then part.CFrame = self.homes[key] end
    end
    self.reader.Color = if self.policy.traces.Reader then Color3.fromRGB(245, 168, 62) else Color3.fromRGB(72, 130, 143)
    self.collection.Color = if self.policy.traces.Collection then Color3.fromRGB(227, 212, 171) else Color3.fromRGB(176, 157, 114)
    self.plantSpot.Transparency = if self.policy.traces.Fabric then 0 else 0.85
end
function Service:snapshot(player)
    local p, id, now = self.policy, player.UserId, self.rt.scope:now()
    local offer = p.offers[id]
    return {passSeconds = math.max(0, math.ceil((p.passes[id] or 0) - now)), held = p:holding(id),
        offer = if offer and offer.untilTime > now then {from = offer.from, item = offer.key} else nil,
        grants = if self.rt.roles:get(player) == "Owner" then 3 - p.issued else nil}
end
return Service
