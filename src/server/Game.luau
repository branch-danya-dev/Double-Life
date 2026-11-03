local Game = {}
local runtime
function Game.start(options)
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
    local EventDirector = require(script.Parent.EventDirector)
    local ProfileService = require(script.Parent.ProfileService)
    local SocialService = require(script.Parent.SocialService)
    local CommerceService = require(script.Parent.CommerceService)
    local Telemetry = require(script.Parent.Telemetry)
    local ActorRegistry = require(script.Parent.ActorRegistry)
    local LobbyWorld = require(script.Parent.LobbyWorld)
    local Matchmaking = require(script.Parent.Matchmaking)
    local MimicService = require(script.Parent.MimicService)
    local PrologueService = require(script.Parent.PrologueService)

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
    local eventRemote = remote("RemoteEvent", "EventAction")
    local profileRemote = remote("RemoteEvent", "ProfileAction")
    local socialRemote = remote("RemoteEvent", "SocialAction")
    local commerceRemote = remote("RemoteEvent", "CommerceAction")
    local queueRemote = remote("RemoteEvent", "QueueAction")
    local prologueRemote = remote("RemoteEvent", "PrologueAction")
    local function event(name)
        local value = Instance.new("BindableEvent")
        value.Name, value.Parent = name, script.Parent
        return value
    end
    local completed, finished = event("TaskCompleted"), event("RoundFinished")
    local eventSignals = {}
    for _, name in ipairs({"EventStarted", "EventParticipated", "EventFinished", "GuestIncidentTriggered"}) do
        eventSignals[name] = event(name)
    end
    local function tell(player, message)
        if player.Parent == Players then update:FireClient(player, "Notice", message) end
    end
    local roles = Roles.new(Config, update)
    local rounds = RoundService.new(Config, roles, tell, finished)
    runtime = {roles = roles, rounds = rounds, taskCompleted = completed, roundFinished = finished, eventSignals = eventSignals,
        alive = true, actors = ActorRegistry.new(), metrics = {maxRebuildMs = 0, maxHeartbeatMs = 0}}
    runtime.profiles = ProfileService.new(runtime, tell, options)
    runtime.telemetry = Telemetry.new(runtime, options and options.analytics)
    runtime.commerce = CommerceService.new(runtime, tell, options)
    local function rebuild(starting)
        local began = os.clock()
        if runtime.mimics then runtime.mimics:reset() end
        if runtime.scope then
            runtime.events:cancel()
            runtime.scope:destroy()
            for id in pairs(runtime.requests.trays) do runtime.requests:clearTray(id) end
        end
        local scope, state = Clock.new(), {finished = false}
        local interactions = Interactions.new(state, function(player, neutral)
            return scope.alive and rounds:allows(player, neutral)
        end)
        local world = if runtime.world then runtime.world:reset() else World.build()
        local evidence = Evidence.new(world, interactions, tell)
        local function onTask(player, kind, amount)
            if scope.alive and rounds.policy.phase == "Active" then
                completed:Fire({roundId = rounds.policy.roundId, userId = player.UserId, kind = kind, amount = amount})
            end
        end
        local function onActivity(player, key)
            if scope.alive and runtime.scope == scope then runtime.events:activity(player, key) end
        end
        local function tool(player, role) return runtime.profiles:tool(player, role) end
        local dossier = Dossier.start(world, roles, interactions, update, tell, Config,
            function(id) if scope.alive then rounds:extract(id) end end, evidence, onTask, onActivity, scope, tool)
        local guard = GuardService.start(world, Config, scope)
        local requests = Requests.start(world, roles, interactions, guard, tell, update, Config, scope, onTask, onActivity)
        requests.actors = runtime.actors
        local access = WorldEvents.start(world, roles, interactions, guard, tell, Config, scope, onActivity, tool, onTask)
        local council = interactions.prompt(world.console, "Созвать собрание", "Пульт владельца · 1 раз", 1)
        council.KeyboardKeyCode = Enum.KeyCode.C
        interactions:bind(council, function(player)
            if rounds:callCouncil(player) then
                completed:Fire({roundId = rounds.policy.roundId, userId = player.UserId, kind = "Council", amount = 1})
            end
        end)
        runtime.scope, runtime.state, runtime.world = scope, state, world
        runtime.interactions, runtime.dossier, runtime.guard = interactions, dossier, guard
        runtime.requests, runtime.evidence = requests, evidence
        runtime.access = access
        runtime.social = SocialService.new(runtime, tell, onTask)
        runtime.events = EventDirector.new({world = world, scope = scope, rounds = rounds, roles = roles,
            interactions = interactions, guard = guard, tell = tell, update = update, config = Config, signals = eventSignals,
            actors = runtime.actors})
        rounds.session = runtime
        if starting then runtime.profiles:beginRound(rounds.policy.roundId) end
        for index, player in ipairs(Players:GetPlayers()) do
            dossier:add(player)
            if player.Character and not (runtime.prologue and runtime.prologue:active(player)) then
                -- A new round starts everyone in the foyer, with no carry-over positioning.
                local position = if starting and rounds.policy.participants[player.UserId] then world:spawn(index)
                    elseif runtime.lobby then runtime.lobby:position(index) else world:spawn(index)
                player.Character:PivotTo(CFrame.new(position))
            end
            if starting then tell(player, "Раунд начался. Ваша роль и личные цели — в панели. H — правила.") end
        end
        rounds:sync()
        runtime.metrics.maxRebuildMs = math.max(runtime.metrics.maxRebuildMs, (os.clock() - began) * 1000)
    end
    rounds.rebuild = rebuild
    rebuild(false)
    runtime.lobby = LobbyWorld.build(runtime)
    runtime.queue = Matchmaking.new(runtime, queueRemote)
    runtime.mimics = MimicService.new(runtime)
    assert(not options or options.prologue~=false or RunService:IsStudio(),"Prologue override is Studio-only")
    runtime.prologue = PrologueService.new(runtime,prologueRemote,tell,not options or options.prologue~=false)
    game:BindToClose(function() runtime.alive=false end)

    local function snapshot(player)
        local round = rounds:snapshot(player)
        return {role = if round.participating then roles:get(player) else "Waiting",
            paintings = runtime.dossier:count(player), requiredPaintings = Config.GUEST_PAINTINGS,
            servicePoints = runtime.requests.ledger.scores[player.UserId] or 0,
            refreshments = runtime.requests.received[player.UserId] or 0,
            evidence = runtime.evidence:description(player.UserId), hasDossier = runtime.dossier:has(player), round = round,
            queue = runtime.queue:snapshot(player), prologue = runtime.prologue:snapshot(player), activities = runtime.events:snapshot(player), profile = runtime.profiles:snapshot(player),
            social = runtime.social:snapshot(player), commerce = runtime.commerce:snapshot(player), publicStyles = runtime.commerce:public()}
    end
    getState.OnServerInvoke = snapshot
    local lastAction, lastProfileAction, lastSocialAction = {}, {}, {}
    socialRemote.OnServerEvent:Connect(function(player, action, target, roundId)
        if os.clock() < (lastSocialAction[player.UserId] or 0) then return end
        lastSocialAction[player.UserId] = os.clock() + 0.25
        if not runtime.social:request(player, action, target, roundId) then tell(player, "Действие недоступно: проверьте расстояние, участника и время ожидания.") end
    end)
    commerceRemote.OnServerEvent:Connect(function(player, action, key) runtime.commerce:request(player, action, key) end)
    profileRemote.OnServerEvent:Connect(function(player, kind, item, slot)
        if os.clock() < (lastProfileAction[player.UserId] or 0) then return end
        lastProfileAction[player.UserId] = os.clock() + 0.5
        local ok, why = runtime.profiles:request(player, kind, item, slot)
        if not ok then tell(player, if why == "PhaseLocked" then "Покупки и выбор доступны в ожидании или итогах."
            elseif why == "Busy" then "Подождите перед следующим действием с профилем." else "Действие с профилем недоступно. Проверьте сохранение и выбранный предмет.") end
    end)
    eventRemote.OnServerEvent:Connect(function(player, action, roundId, kind)
        local now = os.clock() -- Transport spam throttle; event deadlines use SessionClock only.
        if now < (lastAction[player.UserId] or 0) then return end
        lastAction[player.UserId] = now + 0.25
        if roundId ~= rounds.policy.roundId then return end
        if action == "Start" and typeof(kind) == "string" then runtime.events:start(player, kind, roundId)
        elseif action == "DropRelic" and rounds:allows(player, false) then runtime.events:drop(player) end
    end)
    actionRemote.OnServerEvent:Connect(function(player, action, roundId, target, attach)
        local now = os.clock()
        if now < (lastAction[player.UserId] or 0) then return end
        lastAction[player.UserId] = now + 0.25
        if roundId ~= rounds.policy.roundId then return end
        if action == "Vote" then
            local accepted = rounds:vote(player, target, roundId, attach)
            if accepted then
                completed:Fire({roundId = roundId, userId = player.UserId, kind = "Vote", amount = 1})
            end
            tell(player, if accepted then "Голос принят. Изменить его нельзя." else "Голос отклонён: проверьте участника, улику и фазу собрания.")
        elseif action == "DropEvidence" and rounds:allows(player, false) then
            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then runtime.evidence:drop(player) end
        end
    end)
    local connected = {}
    local spawnSlots = {}
    local function resetCharacter(player)
        runtime.prologue:resetCharacter(player)
        runtime.social:remove(player)
        runtime.events:resetCharacter(player)
        runtime.dossier:resetCharacter(player)
        runtime.requests:resetCharacter(player)
        runtime.evidence:drop(player)
    end
    local function addPlayer(player)
        if connected[player] then return end
        connected[player] = true
        local used = {}
        for _, slot in pairs(spawnSlots) do used[slot] = true end
        for slot = 1, 15 do if not used[slot] then spawnSlots[player] = slot; break end end
        player.RespawnLocation = runtime.lobby.spawn
        runtime.actors:addHuman(player)
        task.spawn(function() runtime.queue:add(player) end)
        runtime.profiles:add(player)
        runtime.prologue:add(player)
        runtime.telemetry:add(player)
        runtime.commerce:add(player)
        runtime.dossier:add(player)
        local function characterAdded(character)
            resetCharacter(player)
            local function configure(part)
                if part:IsA("BasePart") then part.CollisionGroup = "DoubleLifeActors" end
            end
            for _, part in ipairs(character:GetDescendants()) do configure(part) end
            character.DescendantAdded:Connect(configure)
            local humanoid = character:WaitForChild("Humanoid", 10)
            local root = character:WaitForChild("HumanoidRootPart", 10)
            -- CharacterAdded precedes engine placement at RespawnLocation. Route
            -- only after parenting/rig creation and the following simulation step.
            local spawnDeadline = os.clock() + 10
            while not character:IsDescendantOf(workspace) and player.Character == character
                and player.Parent == Players and os.clock() < spawnDeadline do RunService.Heartbeat:Wait() end
            RunService.Heartbeat:Wait()
            if root and player.Parent == Players and player.Character == character and character:IsDescendantOf(workspace) then
                local position=runtime.prologue:position(player) or (if rounds.policy.participants[player.UserId] then runtime.world:spawn(spawnSlots[player] or 1)
                    else runtime.lobby:position(spawnSlots[player] or 1)
                )
                character:PivotTo(CFrame.new(position))
            end
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
        runtime.prologue:remove(player)
        runtime.queue:remove(player)
        runtime.actors:remove(player.UserId)
        runtime.lobby.interactions:remove(player)
        runtime.social:remove(player)
        runtime.commerce:remove(player)
        runtime.telemetry:remove(player)
        runtime.profiles:remove(player)
        runtime.events:remove(player)
        rounds:leave(player) -- Determine the result before removing the private role.
        runtime.evidence:drop(player)
        runtime.dossier:remove(player)
        runtime.requests:remove(player)
        runtime.interactions:remove(player)
        roles:remove(player)
        connected[player], lastAction[player.UserId] = nil, nil
        spawnSlots[player] = nil
        lastProfileAction[player.UserId] = nil
        lastSocialAction[player.UserId] = nil
    end)
    for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end
    local broadcast = 0
    RunService.Heartbeat:Connect(function(dt)
        runtime.metrics.maxHeartbeatMs = math.max(runtime.metrics.maxHeartbeatMs, dt * 1000)
        rounds:tick(dt)
        runtime.scope:advance(dt)
        runtime.events:tick()
        runtime.social:tick()
        runtime.commerce:tick()
        runtime.telemetry:tick()
        runtime.profiles:tick(dt)
        runtime.prologue:tick(dt)
        runtime.mimics:tick(dt)
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
