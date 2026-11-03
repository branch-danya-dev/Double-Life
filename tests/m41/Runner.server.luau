-- Short engine integration only. Profile disconnects reuse one real Player/UserId.
-- Seeded account is test data, not a played match; no DataStore service is accessed.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local server = game.ServerScriptService.DoubleLifeServer
local Schema = require(server.ProfileSchema)
local Memory = require(script.Parent.MemoryStore)
local driver = Instance.new("RemoteFunction")
driver.Name, driver.Parent = "M41TestDriver", RS
local adapter = Memory.new(Schema.copy)
local rt = require(server.Game).start({prologue=false,adapter = adapter})
local function check(ok, message) assert(ok, message); print("M4.1 PASS", message) end
local function waitFor(predicate, seconds)
    local deadline = os.clock() + seconds
    repeat if predicate() then return end; task.wait(0.1) until os.clock() >= deadline
    error("condition timed out")
end
local ok, err = xpcall(function()
    waitFor(function() return #Players:GetPlayers() == 1 end, 180)
    local player = Players:GetPlayers()[1]
    local id, profiles = player.UserId, rt.profiles
    waitFor(function() local e = profiles:entry(player); return e and e.status == "Ready" end, 20)
    task.wait(5)
    local e = profiles:entry(player)
    profiles.store:enqueue(id, {kind = "Award", id = "M41-seeded-prior-round", at = os.time(),
        award = {role = "Spy", won = true, xp = 75, roleXp = 40, tokens = 28}}, e.token)
    check(profiles.store:flush(id, false, nil, e.token), "seed isolated prior account")
    driver:InvokeClient(player, {action = "Equip", item = "Prybar", slot = "Spy"})
    waitFor(function() return profiles:entry(player).profile.equipped.Spy == "Prybar" end, 10)
    check(driver:InvokeClient(player, {}).tokens == 28, "real client reads own confirmed profile")
    local oldToken = e.token
    adapter.onUpdate = function() error("M41 injected outage") end
    driver:InvokeClient(player, {action = "Buy", item = "ObserverTitle"})
    profiles:remove(player)
    profiles:add(player) -- same Player/UserId, exactly the production profile lifecycle hooks
    task.wait(5)
    local unavailable = driver:InvokeClient(player, {})
    check(unavailable.retrying and unavailable.status ~= "Ready", "client sees automatic recovery, no false saved status")
    check(not profiles:request(player, "Buy", "TealCard"), "purchase blocked during recovery")
    check(adapter.data["User_" .. id].tokens == 28 and #profiles.store.entries[id].queue == 1, "failed close retains unconfirmed purchase")
    print("M4.1 RECOVERY UI: outage remains for 15 seconds")
    task.wait(15)
    adapter.onUpdate = nil
    waitFor(function() local x = profiles:entry(player); return x and x.status == "Ready" end, 35)
    local recovered = profiles:entry(player)
    check(recovered.token ~= oldToken and recovered.profile.tokens == 8 and recovered.profile.inventory.ObserverTitle,
        "same-server recovery adopts fresh token and purchases exactly once")
    check(recovered.profile.equipped.Spy == "Prybar" and recovered.profile.roleXp.Spy == 40 and #recovered.profile.history == 1,
        "role XP, equipped loadout and history retained")
    driver:InvokeClient(player, {action = "Buy", item = "ObserverTitle"})
    check(driver:InvokeClient(player, {}).tokens == 8, "repeat client purchase cannot double debit")
    check(not profiles.store:flush(id, false, nil, oldToken) and not profiles.store:close(id, os.time() + 5, oldToken),
        "stale scheduled writer cannot close or overwrite fresh session")
    adapter.faults["User_" .. id] = {"after", "before", "before"}
    profiles:remove(player); profiles:add(player)
    task.wait(0.1)
    profiles:remove(player); profiles:add(player)
    waitFor(function() local x = profiles:entry(player); return x and x.status == "Ready" end, 35)
    check(profiles:entry(player).profile.tokens == 8, "rapid third connection survives unknown release outcome")
    check(driver:InvokeClient(player, {}).status == "Ready", "real client receives recovered snapshot")
    print("M4.1 RECOVERED UI: holding for 15 seconds")
    task.wait(15)
    check(profiles:shutdown(), "BindToClose path finishes successfully")
    check(adapter.data["User_" .. id].lease.expires == 0, "shutdown released confirmed lease")
    profiles:add(player)
    check(profiles:entry(player) == nil, "shutdown cancels profile reopening")
    local stopped = driver:InvokeClient(player, {})
    check(stopped.status == "Unavailable" and not stopped.retrying, "client never sees Ready from a stopped connection")
    print("M4.1 STUDIO PASS: real client; simulated profile reconnect; injected failures; real DataStore NOT TESTED")
end, debug.traceback)
if not ok then warn("M4.1 STUDIO FAIL", err) end
