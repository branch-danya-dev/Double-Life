-- Isolated Studio load fixture; shares the M6 physical client driver.
task.spawn(function()
    local function run()
        assert(game:GetService("RunService"):IsStudio(), "Studio only")
        local Players = game:GetService("Players")
        local modules = game.ServerScriptService.DoubleLifeServer
        local driver = Instance.new("RemoteFunction")
        driver.Name, driver.Parent = "M6TestDriver", game.ReplicatedStorage
        local rt = require(modules.Game).start({prologue=false,adapter = require(script.Parent.MemoryStore).new(require(modules.ProfileSchema).copy)})
        local naturalTick = rt.rounds.policy.tick
        rt.rounds.policy.tick = function(self, dt) return naturalTick(self, dt, 0) end
        assert(rt.profiles.adapter.mode == "FakeMemory", "isolated memory only")
        local function waitFor(condition, seconds)
            local deadline = os.clock() + seconds
            repeat if condition() then return end; task.wait(0.1) until os.clock() > deadline
            error("M7 load probe timed out")
        end
        waitFor(function() return #Players:GetPlayers() == 15 end, 600)
        task.wait(12)
        print("M7 LOAD PASS isolated memory; 15 real clients ready")
        -- Release the fixture gate; preserve natural countdown and round duration.
        rt.rounds.policy.tick = naturalTick
        local static, oldMap, oldScope = rt.world.static, rt.world.map, rt.scope
        waitFor(function() return rt.rounds.policy.phase == "Active" end, 30)
        assert(rt.world.static == static and oldMap.Parent == nil and not oldScope.alive, "round cleanup")
        local pending, failures = 15, {}
        for index, p in ipairs(Players:GetPlayers()) do
            task.spawn(function()
                local ok, err = pcall(function()
                    local snapshot = driver:InvokeClient(p, {kind = "Snapshot"})
                    assert(snapshot.round.participating, "real participant")
                    local id = if index % 2 == 0 then "Service.Target2" else "Social.TraceSpot"
                    local position = rt.world:approach(id) + Vector3.new((index % 3 - 1) * 3, 0, 0)
                    local result = driver:InvokeClient(p, {kind = "Walk", position = position})
                    print(string.format("M7 LOAD WALK %s %s %.2fs %.1fstuds", p.Name, id, result.seconds, result.distance))
                    driver:InvokeClient(p, {kind = "Manual"})
                end)
                if not ok then table.insert(failures, tostring(err)) end
                pending -= 1
            end)
        end
        waitFor(function() return pending == 0 end, 180)
        assert(#failures == 0, table.concat(failures, "\n"))
        local parts = 0
        for _, p in ipairs(rt.world.level:GetDescendants()) do if p:IsA("BasePart") then parts += 1 end end
        print("M7 LOAD METRICS", game:GetService("HttpService"):JSONEncode({players = #Players:GetPlayers(),
            parts = parts, instances = #rt.world.level:GetDescendants(), world = rt.world.metrics,
            game = rt.metrics, guard = rt.guard.mover.metrics, service = rt.requests.npc.metrics}))
        print("M7 LOAD PASS 15; independent Studio load fixture")
    end
    local ok, err = xpcall(run, debug.traceback)
    if not ok then warn("M7 LOAD FAIL", err) end
end)
