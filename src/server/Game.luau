local Game = {}
local runtime
function Game.start()
    if runtime then return runtime end
    local Players = game:GetService("Players")
    local RS = game:GetService("ReplicatedStorage")
    local PhysicsService = game:GetService("PhysicsService")
    local RunService = game:GetService("RunService")
    local Config = require(RS:WaitForChild("DoubleLifeShared").Config)
    local Roles = require(script.Parent.Roles)
    local RoundService = require(script.Parent.RoundService)
    local Clock = require(script.Parent.SessionClock)
    local Interactions = require(script.Parent.Interactions)
    local World = require(script.Parent.World)
    local Dossier = require(script.Parent.Dossier)
    local Evidence = require(script.Parent.Evidence)
    local GuardService = require(script.Parent.GuardService)
    local Requests = require(script.Parent.Requests)
    local WorldEvents = require(script.Parent.WorldEvents)

    pcall(function() PhysicsService:RegisterCollisionGroup("DoubleLifeActors") end)
    PhysicsService:CollisionGroupSetCollidable("DoubleLifeActors", "DoubleLifeActors", false)
    local remotes = Instance.new("Folder")
    remotes.Name, remotes.Parent = "DoubleLifeRemotes", RS
    local function remote(class, name)
        local value = Instance.new(class)
        value.Name, value.Parent = name, remotes
        return value
    end
    local update = remote("RemoteEvent", "PersonalUpdate")
    local getState = remote("RemoteFunction", "GetState")
    local actionRemote = remote("RemoteEvent", "CouncilAction")
    local function event(name)
        local value = Instance.new("BindableEvent")
        value.Name, value.Parent = name, script.Parent
        return value
    end
    local completed, finished = event("TaskCompleted"), event("RoundFinished")
    local function tell(player, message)
        if player.Parent == Players then update:FireClient(player, "Notice", message) end
    end
    local roles = Roles.new(Config, update)
    local rounds = RoundService.new(Config, roles, tell, finished)
    runtime = {roles = roles, rounds = rounds, taskCompleted = completed, roundFinished = finished}
    local function rebuild(starting)
        if runtime.scope then
            runtime.scope:destroy()
            for id in pairs(runtime.requests.trays) do runtime.requests:clearTray(id) end
            runtime.world.map:Destroy()
        end
        local scope, state = Clock.new(), {finished = false}
        local interactions = Interactions.new(state, function(player, neutral)
            return scope.alive and rounds:allows(player, neutral)
        end)
        local world = World.build()
        local evidence = Evidence.new(world, interactions, tell)
        local function onTask(player, kind, amount)
            if scope.alive and rounds.policy.phase == "Active" then
                completed:Fire({roundId = rounds.policy.roundId, userId = player.UserId, kind = kind, amount = amount})
            end
        end
        local dossier = Dossier.start(world, roles, interactions, update, tell, Config,
            function(id) if scope.alive then rounds:extract(id) end end, evidence, onTask)
        local guard = GuardService.start(world, Config, scope)
        local requests = Requests.start(world, roles, interactions, guard, tell, update, Config, scope, onTask)
        WorldEvents.start(world, roles, interactions, guard, tell, Config, scope)
        local council = interactions.prompt(world.console, "Созвать собрание", "Пульт владельца · 1 раз", 1)
        council.KeyboardKeyCode = Enum.KeyCode.C
        interactions:bind(council, function(player) rounds:callCouncil(player) end)
        runtime.scope, runtime.state, runtime.world = scope, state, world
        runtime.interactions, runtime.dossier, runtime.guard = interactions, dossier, guard
        runtime.requests, runtime.evidence = requests, evidence
        rounds.session = runtime
        for index, player in ipairs(Players:GetPlayers()) do
            dossier:add(player)
            if player.Character then
                -- A new round starts everyone in the foyer, with no carry-over positioning.
                player.Character:PivotTo(CFrame.new((index % 5 - 2) * 4, 4, -16 + math.floor(index / 5) * 4))
            end
            if starting then tell(player, "Раунд начался. Ваша роль и личные цели — в панели. H — правила.") end
        end
        rounds:sync()
    end
    rounds.rebuild = rebuild
    rebuild(false)

    local function snapshot(player)
        local round = rounds:snapshot(player)
        return {role = if round.participating then roles:get(player) else "Waiting",
            paintings = runtime.dossier:count(player), requiredPaintings = Config.GUEST_PAINTINGS,
            servicePoints = runtime.requests.ledger.scores[player.UserId] or 0,
            refreshments = runtime.requests.received[player.UserId] or 0,
            evidence = runtime.evidence:description(player.UserId), hasDossier = runtime.dossier:has(player), round = round}
    end
    getState.OnServerInvoke = snapshot
    local lastAction = {}
    actionRemote.OnServerEvent:Connect(function(player, action, roundId, target, attach)
        local now = os.clock()
        if now < (lastAction[player.UserId] or 0) then return end
        lastAction[player.UserId] = now + 0.25
        if roundId ~= rounds.policy.roundId then return end
        if action == "Vote" then
            local accepted = rounds:vote(player, target, roundId, attach)
            tell(player, if accepted then "Голос принят. Изменить его нельзя." else "Голос отклонён: проверьте участника, улику и фазу собрания.")
        elseif action == "DropEvidence" and rounds:allows(player, false) then
            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then runtime.evidence:drop(player) end
        end
    end)
    local connected = {}
    local function resetCharacter(player)
        runtime.dossier:resetCharacter(player)
        runtime.requests:resetCharacter(player)
        runtime.evidence:drop(player)
    end
    local function addPlayer(player)
        if connected[player] then return end
        connected[player] = true
        runtime.dossier:add(player)
        local function characterAdded(character)
            resetCharacter(player)
            local function configure(part)
                if part:IsA("BasePart") then part.CollisionGroup = "DoubleLifeActors" end
            end
            for _, part in ipairs(character:GetDescendants()) do configure(part) end
            character.DescendantAdded:Connect(configure)
            local humanoid = character:WaitForChild("Humanoid", 10)
            if humanoid then humanoid.Died:Connect(function()
                if player.Character == character then resetCharacter(player) end
            end) end
            rounds:lockCharacter(player)
        end
        player.CharacterAdded:Connect(characterAdded)
        if player.Character then task.spawn(characterAdded, player.Character) end
    end
    Players.PlayerAdded:Connect(addPlayer)
    Players.PlayerRemoving:Connect(function(player)
        rounds:leave(player) -- Determine the result before removing the private role.
        runtime.evidence:drop(player)
        runtime.dossier:remove(player)
        runtime.requests:remove(player)
        runtime.interactions:remove(player)
        roles:remove(player)
        connected[player], lastAction[player.UserId] = nil, nil
    end)
    for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end
    local broadcast = 0
    RunService.Heartbeat:Connect(function(dt)
        rounds:tick(dt)
        runtime.scope:advance(dt)
        broadcast += dt
        if broadcast >= 0.5 then
            broadcast = 0
            for _, player in ipairs(Players:GetPlayers()) do update:FireClient(player, "Snapshot", snapshot(player)) end
        end
    end)
    return runtime
end
function Game.get() return runtime end
return Game
