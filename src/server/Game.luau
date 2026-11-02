local Game = {}
local runtime
function Game.start()
    if runtime then return runtime end
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local PhysicsService = game:GetService("PhysicsService")
    local Config = require(ReplicatedStorage:WaitForChild("DoubleLifeShared").Config)
    local Roles = require(script.Parent.Roles)
    local Interactions = require(script.Parent.Interactions)
    local World = require(script.Parent.World)
    local Dossier = require(script.Parent.Dossier)
    local GuardService = require(script.Parent.GuardService)
    local Requests = require(script.Parent.Requests)
    local WorldEvents = require(script.Parent.WorldEvents)

    pcall(function() PhysicsService:RegisterCollisionGroup("DoubleLifeActors") end)
    PhysicsService:CollisionGroupSetCollidable("DoubleLifeActors", "DoubleLifeActors", false)
    local remotes = Instance.new("Folder")
    remotes.Name, remotes.Parent = "DoubleLifeRemotes", ReplicatedStorage
    local update = Instance.new("RemoteEvent")
    update.Name, update.Parent = "PersonalUpdate", remotes
    local getState = Instance.new("RemoteFunction")
    getState.Name, getState.Parent = "GetState", remotes
    local function tell(player, message) update:FireClient(player, "Notice", message) end
    local state = {finished = false}
    local roles = Roles.new(Config, update)
    local interactions = Interactions.new(state)
    local world = World.build()
    local dossier = Dossier.start(world, roles, interactions, update, tell, Config, state)
    local guard = GuardService.start(world, Config)
    local requests = Requests.start(world, roles, interactions, guard, tell, update, Config)
    WorldEvents.start(world, roles, interactions, guard, tell, Config)

    getState.OnServerInvoke = function(player)
        return {role = roles:get(player), paintings = dossier:count(player), requiredPaintings = Config.GUEST_PAINTINGS,
            servicePoints = requests.ledger.scores[player.UserId] or 0}
    end
    local connected = {}
    local function addPlayer(player)
        if connected[player] then return end
        connected[player] = true
        roles:add(player)
        dossier:add(player)
        local function characterAdded(character)
            dossier:resetCharacter(player)
            requests:resetCharacter(player)
            local function configure(part)
                if part:IsA("BasePart") then part.CollisionGroup = "DoubleLifeActors" end
            end
            for _, part in ipairs(character:GetDescendants()) do configure(part) end
            character.DescendantAdded:Connect(configure)
            local humanoid = character:WaitForChild("Humanoid", 10)
            if humanoid then humanoid.Died:Connect(function()
                dossier:resetCharacter(player)
                requests:resetCharacter(player)
            end) end
        end
        player.CharacterAdded:Connect(characterAdded)
        if player.Character then task.spawn(characterAdded, player.Character) end
    end
    Players.PlayerAdded:Connect(addPlayer)
    Players.PlayerRemoving:Connect(function(player)
        dossier:remove(player)
        requests:remove(player)
        interactions:remove(player)
        roles:remove(player, Players:GetPlayers())
        connected[player] = nil
    end)
    for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end

    runtime = {world = world, roles = roles, interactions = interactions, dossier = dossier,
        guard = guard, requests = requests, state = state}
    return runtime
end
function Game.get() return runtime end
return Game
