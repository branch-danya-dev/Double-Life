local Players = game:GetService("Players")
local Ledger = require(script.Parent.RequestLedger)
local Mover = require(script.Parent.NpcMover)
local Requests = {}
Requests.__index = Requests

function Requests.start(world, roles, interactions, guard, tell, update, config, scope, onTask, onActivity)
    local self = setmetatable({scope = scope, onTask = onTask, onActivity = onActivity, received = {}, ledger = Ledger.new(config), trays = {}, world = world,
        tell = tell, update = update, roles = roles, config = config, guard = guard}, Requests)
    self.pantry = world:object("Service.Pantry")
    self.home = world:point("Service.Home")
    self.targets = {}
    for index, id in ipairs(world.layout.groups["Service.Targets"]) do
        table.insert(self.targets, {name = if index == 1 then "Бальный зал · этаж 1" else "Архив · этаж 2",
            position = world:approach(id), approach = world:approach(id), part = world:object(id)})
    end
    local function bind(part, action, name, callback, key)
        local p = interactions.prompt(part, action, name, 0.75)
        if key then p.KeyboardKeyCode = key end
        interactions:bind(p, callback, true)
    end
    for index, target in ipairs(self.targets) do
        bind(target.part, "Заказать сок сюда", target.name, function(player)
            local request, reason = self.ledger:create(player.UserId, index, scope:now())
            tell(player, if request then "Запрос принят: сок принесут к этому столику." else reason)
        end)
        bind(target.part, "Доставить сок", target.name, function(player)
            if roles:get(player) ~= config.ROLE_STAFF then tell(player, "Доставку выполняет персонал."); return end
            local request = self.ledger:assigned(player.UserId)
            if not request or request.target ~= index then tell(player, "Это не точка вашего заказа."); return end
            self:complete(request, player.UserId)
        end, Enum.KeyCode.F)
    end
    bind(self.pantry, "Принять заказ / взять сок", "Стойка персонала", function(player)
        if roles:get(player) ~= config.ROLE_STAFF then tell(player, "Здесь персонал получает заказы."); return end
        local request = self.ledger:assigned(player.UserId)
        if not request then
            request = self.ledger:accept(player.UserId, scope:now(), false)
            tell(player, if request then "Заказ принят. Ещё раз нажмите: взять сок. Доставка: " .. self.targets[request.target].name else "Нет свободных заказов.")
        elseif self.ledger:pickup(request, player.UserId, scope:now()) then
            self:carry(player.UserId, player.Character)
            self:dispatch(request)
            tell(player, "Несите сок: " .. self.targets[request.target].name .. ". У столика удерживайте F.")
        else
            tell(player, "У вас уже есть сок для доставки.")
        end
    end)
    self.npc = Mover.new(world.npcs, "ServiceAssistant", self.home, Color3.fromRGB(68, 129, 104), scope)
    self.worker = task.spawn(function()
        while scope.alive and self.npc.model.Parent do
            if not self.npc:waitRunning() then break end
            self.lastTick = scope:now()
            local ok, err = pcall(function() self:runNpc() end)
            if not ok then
                warn("Service recovery:", err)
                self.ledger:release(0, scope:now())
                self:clearTray(0)
                self.npc:stop()
            end
            task.wait(0.5)
        end
    end)
    task.spawn(function()
        while scope.alive and world.map.Parent do
            for _, request in ipairs(self.ledger:expire(scope:now())) do
                if request.executor then self:clearTray(request.executor) end
                local player = Players:GetPlayerByUserId(request.userId)
                if player then tell(player, "Запрос истёк. Можно заказать снова.") end
            end
            task.wait(1)
        end
    end)
    return self
end

function Requests:clearTray(executor)
    if self.trays[executor] then self.trays[executor]:Destroy(); self.trays[executor] = nil end
end

function Requests:carry(executor, model)
    self:clearTray(executor)
    local root = model and model:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local tray = Instance.new("Part")
    tray.Name, tray.Size, tray.Color = "JuiceTray", Vector3.new(2, 0.3, 1.4), Color3.fromRGB(255, 180, 64)
    tray.CanCollide, tray.CanQuery, tray.Massless = false, false, true
    tray.CFrame, tray.Parent = root.CFrame * CFrame.new(0, 0, -1.5), model
    local weld = Instance.new("WeldConstraint")
    weld.Part0, weld.Part1, weld.Parent = root, tray, tray
    self.trays[executor] = tray
end

function Requests:dispatch(request)
    -- A public service visit draws a routine guard check, with no criminal identity.
    self.guard:react("Service" .. request.target, self.targets[request.target].approach)
end

function Requests:complete(request, executor)
    if not self.scope.alive or not self.scope.running then return false end
    if not self.ledger:deliver(request, executor, self.scope:now()) then return false end
    self:clearTray(executor)
    local target = self.targets[request.target]
    local cup = self.world.block("DeliveredJuice", Vector3.new(0.6, 1, 0.6), target.part.Position + Vector3.new(0, 1.6, 0), Color3.fromRGB(255, 180, 64))
    cup.CanCollide = false
    self.scope:delay(12, function() cup:Destroy() end)
    local requester = Players:GetPlayerByUserId(request.userId)
    if requester then
        self.received[request.userId] = (self.received[request.userId] or 0) + 1
        self.onTask(requester, "Refreshment", 1)
        self.onActivity(requester, "Refreshment")
        self.tell(requester, "Сок доставлен к выбранному столику.")
    end
    local staff = if executor ~= 0 then Players:GetPlayerByUserId(executor) else nil
    if staff then
        self.onTask(staff, "Delivery", self.config.REQUEST_POINTS)
        self.update:FireClient(staff, "ServicePoints", self.ledger.scores[executor])
        self.tell(staff, "Доставлено. +" .. self.config.REQUEST_POINTS .. " сессионных очков.")
    end
    return true
end

function Requests:runNpc()
    self.npc.label.Text = "Персонал · ожидает заказ"
    -- A failed return is retried physically; never pick up supplies from across the map.
    if not self.npc:move(self.home, self.scope:now() + self.world.navigation.serviceSeconds, function() return not self.scope.alive end) then return end
    local request = self.ledger:accept(0, self.scope:now(), true)
    if not request then return end
    self.npc.label.Text = "Персонал · несёт сок"
    if not self.ledger:pickup(request, 0, self.scope:now()) then return end
    self:carry(0, self.npc.model)
    self:dispatch(request)
    local function cancelled() return not self.scope.alive or not self.ledger:active(request, self.scope:now()) or request.executor ~= 0 end
    local reached = self.npc:move(self.targets[request.target].approach, math.min(request.expires, self.scope:now() + self.world.navigation.serviceSeconds), cancelled)
    if reached and not cancelled() then self:complete(request, 0)
    else self.ledger:release(0, self.scope:now()); self:clearTray(0) end
    self.npc.label.Text = "Персонал · возвращается"
    self.npc:move(self.home, self.scope:now() + self.world.navigation.serviceSeconds, function() return not self.scope.alive end)
end

function Requests:resetCharacter(player)
    self.ledger:release(player.UserId, self.scope:now())
    self:clearTray(player.UserId)
end

function Requests:remove(player)
    local request = self.ledger.requests[player.UserId]
    if request and request.executor then self:clearTray(request.executor) end
    self:clearTray(player.UserId)
    self.ledger:remove(player.UserId, self.scope:now())
end

return Requests
