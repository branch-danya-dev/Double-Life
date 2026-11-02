local Players = game:GetService("Players")
local Ledger = require(script.Parent.RequestLedger)
local Mover = require(script.Parent.NpcMover)
local Requests = {}
Requests.__index = Requests

function Requests.start(world, roles, interactions, guard, tell, update, config)
    local self = setmetatable({ledger = Ledger.new(config), trays = {}, world = world,
        tell = tell, update = update, roles = roles, config = config, guard = guard}, Requests)
    self.pantry = world.block("ServicePantry", Vector3.new(4, 3, 3), Vector3.new(-19, 2, 19), Color3.fromRGB(88, 133, 112))
    self.home = Vector3.new(-15, 3.5, 19)
    self.targets = {
        {name = "Холл у восточного столика", position = Vector3.new(20, 3.5, -10)},
        {name = "Холл у коридора", position = Vector3.new(-12, 3.5, 22)},
    }
    local function bind(part, action, name, callback, key)
        local p = interactions.prompt(part, action, name, 0.75)
        if key then p.KeyboardKeyCode = key end
        interactions:bind(p, callback)
    end
    for index, target in ipairs(self.targets) do
        target.part = world.block("ServicePoint" .. index, Vector3.new(2, 2, 2), target.position - Vector3.new(0, 2, 0), Color3.fromRGB(120, 163, 144))
        target.approach = target.position + Vector3.new(-3, 0, 0)
        bind(target.part, "Заказать сок сюда", target.name, function(player)
            local request, reason = self.ledger:create(player.UserId, index, os.clock())
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
            request = self.ledger:accept(player.UserId, os.clock(), false)
            tell(player, if request then "Заказ принят. Ещё раз нажмите: взять сок. Доставка: " .. self.targets[request.target].name else "Нет свободных заказов.")
        elseif self.ledger:pickup(request, player.UserId, os.clock()) then
            self:carry(player.UserId, player.Character)
            self:dispatch(request)
            tell(player, "Несите сок: " .. self.targets[request.target].name .. ". У столика удерживайте F.")
        else
            tell(player, "У вас уже есть сок для доставки.")
        end
    end)
    self.npc = Mover.new(world.map, "ServiceAssistant", self.home, Color3.fromRGB(68, 129, 104))
    task.spawn(function()
        while self.npc.model.Parent do
            local ok, err = pcall(function() self:runNpc() end)
            if not ok then
                warn("Service recovery:", err)
                self.ledger:release(0, os.clock())
                self:clearTray(0)
                self.npc:stop()
            end
            task.wait(0.5)
        end
    end)
    task.spawn(function()
        while world.map.Parent do
            for _, request in ipairs(self.ledger:expire(os.clock())) do
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
    self.guard:react("Service" .. request.target, self.targets[request.target].approach + Vector3.new(0, 0, 4))
end

function Requests:complete(request, executor)
    if not self.ledger:deliver(request, executor, os.clock()) then return false end
    self:clearTray(executor)
    local target = self.targets[request.target]
    local cup = self.world.block("DeliveredJuice", Vector3.new(0.6, 1, 0.6), target.part.Position + Vector3.new(0, 1.6, 0), Color3.fromRGB(255, 180, 64))
    cup.CanCollide = false
    task.delay(12, function() cup:Destroy() end)
    local requester = Players:GetPlayerByUserId(request.userId)
    if requester then self.tell(requester, "Сок доставлен к выбранному столику.") end
    local staff = if executor ~= 0 then Players:GetPlayerByUserId(executor) else nil
    if staff then
        self.update:FireClient(staff, "ServicePoints", self.ledger.scores[executor])
        self.tell(staff, "Доставлено. +" .. self.config.REQUEST_POINTS .. " сессионных очков.")
    end
    return true
end

function Requests:runNpc()
    self.npc.label.Text = "Персонал · ожидает заказ"
    -- A failed return is retried physically; never pick up supplies from across the map.
    if not self.npc:move(self.home, os.clock() + 14, function() return false end) then return end
    local request = self.ledger:accept(0, os.clock(), true)
    if not request then return end
    self.npc.label.Text = "Персонал · несёт сок"
    if not self.ledger:pickup(request, 0, os.clock()) then return end
    self:carry(0, self.npc.model)
    self:dispatch(request)
    local function cancelled() return not self.ledger:active(request, os.clock()) or request.executor ~= 0 end
    local reached = self.npc:move(self.targets[request.target].approach, math.min(request.expires, os.clock() + 20), cancelled)
    if reached and not cancelled() then self:complete(request, 0)
    else self.ledger:release(0, os.clock()); self:clearTray(0) end
    self.npc.label.Text = "Персонал · возвращается"
    self.npc:move(self.home, os.clock() + 14, function() return false end)
end

function Requests:resetCharacter(player)
    self.ledger:release(player.UserId, os.clock())
    self:clearTray(player.UserId)
end

function Requests:remove(player)
    local request = self.ledger.requests[player.UserId]
    if request and request.executor then self:clearTray(request.executor) end
    self:clearTray(player.UserId)
    self.ledger:remove(player.UserId, os.clock())
end

return Requests
