if not game:GetService("RunService"):IsStudio() then return end
local Game = require(game.ServerScriptService.DoubleLifeServer.Game)
local Players = game:GetService("Players")
local driver = Instance.new("RemoteFunction")
driver.Name, driver.Parent = "M1TestDriver", game.ReplicatedStorage
local function eventually(predicate, seconds, message)
    local deadline = os.clock() + seconds
    repeat if predicate() then return end; task.wait(0.1) until os.clock() > deadline
    error(message)
end
local function check(value, message) assert(value, message); print("M1 PASS", message) end
local ok, err = pcall(function()
    eventually(function() return Game.get() end, 10, "bootstrap did not finish")
    local runtime = Game.get()
    local guard, requests = runtime.guard, runtime.requests
    local mover = guard.mover
    local initial = mover.root.Position
    task.wait(4)
    check((mover.root.Position - initial).Magnitude > 3, "NPC patrol moves physically")
    check(mover.root:GetNetworkOwner() == nil, "NPC owned by server")
    local samples, previous = 0, mover.root.Position
    local monitor = game:GetService("RunService").Heartbeat:Connect(function()
        if (mover.root.Position - previous).Magnitude > 8 then samples += 1 end
        previous = mover.root.Position
    end)
    check(guard:react("Glass", Vector3.new(18, 3.5, -17)), "noise accepted")
    check(not guard:react("Glass", Vector3.new(18, 3.5, -17)), "noise replay rejected")
    eventually(function() return mover:near(Vector3.new(18, 3.5, -17), 5) end, 17, "guard did not reach noise")
    check(true, "NPC reaches investigation target")
    eventually(function() return guard.policy.state == "Return" end, 20, "no return state")
    eventually(function() return guard.policy.state == "Patrol" end, 25, "no patrol recovery")
    check(true, "investigation -> return -> patrol without owner")
    check(not guard:react("Window", Vector3.new(-23, 3.5, 58)), "mandatory patrol interval rejects fresh noise")
    task.wait(12.2)
    local request = assert(requests.ledger:create(987654321, 1, os.clock()))
    eventually(function() return request.state == "Carrying" end, 15, "NPC did not accept request")
    check(guard.policy.state == "Investigate", "service dispatch diverts guard")
    eventually(function() return request.state == "Delivered" end, 20, "NPC did not deliver physically")
    check(requests.npc:near(requests.targets[1].approach, 5), "delivery at real destination")
    check(requests.ledger.scores[0] == nil, "NPC generates no currency")
    eventually(function() return guard.policy.state == "Patrol" end, 40, "guard did not return after service")
    monitor:Disconnect()
    check(samples == 0, "NPC has no teleport-sized movement steps")
    task.wait(12.2)
    -- An unreachable target must time out and recover, without a teleport.
    check(guard:react("UnreachableFixture", Vector3.new(500, 3.5, 500)), "unreachable test accepted")
    eventually(function() return guard.policy.state == "Return" end, 23, "path failure never returned")
    eventually(function() return guard.policy.state == "Patrol" end, 25, "path failure stuck guard")
    check(true, "unreachable path recovers")
    if #Players:GetPlayers() > 0 then
        local player = Players:GetPlayers()[1]
        eventually(function() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end, 15, "no character")
        local root = player.Character.HumanoidRootPart
        local prompt = runtime.world.safe:FindFirstChildOfClass("ProximityPrompt")
        local original = root.CFrame
        root.CFrame = CFrame.new(0, 4, -15)
        check(not runtime.interactions:inReach(player, prompt), "far interaction rejected")
        root.CFrame = CFrame.new(0, 4, 68)
        check(runtime.interactions:inReach(player, prompt), "near visible interaction allowed")
        root.CFrame = CFrame.new(-30, 4, 0)
        local paintingPrompt = runtime.world.map.Painting2:FindFirstChildOfClass("ProximityPrompt")
        check(not runtime.interactions:inReach(player, paintingPrompt), "nearby through wall interaction rejected")
        root.CFrame = original
    end
    workspace:SetAttribute("M1TestsPassed", true)
    print("M1 STUDIO SUITE PASS", #Players:GetPlayers(), "clients")
    require(script.Parent.Playthrough)(runtime, driver, eventually, check)
end)
if not ok then workspace:SetAttribute("M1TestsPassed", false); error("M1 STUDIO SUITE FAIL: " .. tostring(err)) end
