-- Exercise actual Requests.start/prompt callbacks/complete; only engine effects
-- (rendering, background scheduling, network) are replaced. Ledger/Policy are real.
local Ledger = require("../src/server/RequestLedger")
local Policy = require("../src/server/ProgressionPolicy")
local Config = require("../src/shared/Config")
local Catalog = require("../src/server/ProgressionCatalog")
local Suite = {}
local count = 0
local function check(ok, why) assert(ok, why); count += 1 end

local function fixture(loadRequests)
    local f = {now = 0, players = {}, records = {}, calls = {}, prompts = {}}
    function f:add(id, role)
        local p = {UserId = id, role = role}
        self.players[id] = p
        local r = Policy.round(role, "connection:" .. id)
        r.active, r.moving = 45, 12
        self.records[id] = r
        return p
    end
    f.staff, f.other, f.guest = f:add(1, "Staff"), f:add(2, "Staff"), f:add(3, "Guest")
    local scope = {alive = true, running = true, now = function() return f.now end, delay = function() end}
    local world = {layout = {groups = {["Service.Targets"] = {"target1", "target2"}}},
        object = function(_, id) return {Name = id, Position = 0} end,
        point = function() return 0 end, approach = function() return 0 end,
        block = function() return {Destroy = function() end} end}
    local bindings = {}
    local interactions = {
        prompt = function(part, action) return {part = part.Name, action = action} end,
        bind = function(_, p, callback) bindings[p.part .. ":" .. p.action] = callback end,
    }
    local env = setmetatable({
        game = {GetService = function(_, name)
            assert(name == "Players")
            return {GetPlayerByUserId = function(_, id) return f.players[id] end}
        end},
        script = {Parent = {RequestLedger = "Ledger", NpcMover = "Mover"}},
        require = function(id)
            if id == "Ledger" then return Ledger end
            assert(id == "Mover")
            return {new = function() return {} end}
        end,
        task = {spawn = function() return {} end}, -- no real-time worker in deterministic test
        Color3 = {fromRGB = function() return 0 end},
        Vector3 = {new = function() return 0 end},
        Enum = {KeyCode = {F = "F"}},
    }, {__index = getfenv()})
    local Requests = loadRequests(env)
    -- Visual tray construction is irrelevant to when progression is emitted.
    Requests.carry = function() end
    f.service = Requests.start(world, {get = function(_, p) return p.role end}, interactions,
        {react = function() end}, function() end, {FireClient = function() end}, Config, scope,
        function(p, kind, amount)
            table.insert(f.calls, {id = p.UserId, kind = kind, amount = amount})
            Policy.action(f.records[p.UserId], kind)
        end, function() end)
    f.scope = scope
    function f:pantry(p) bindings["Service.Pantry:Принять заказ / взять сок"](p) end
    function f:deliver(p) bindings["target2:Доставить сок"](p) end
    function f:order(requester, worker)
        local request = assert(self.service.ledger:create(requester.UserId, 2, self.now))
        self:pantry(worker); self:pantry(worker)
        return request
    end
    function f:credit(id, kind)
        local n = 0
        for _, c in ipairs(self.calls) do if c.id == id and c.kind == kind then n += 1 end end
        return n
    end
    return f
end

function Suite.reproduce(loadRequests)
    local f = fixture(loadRequests)
    local r = f:order(f.guest, f.staff)
    Policy.action(f.records[1], "Painting")
    local award = Policy.reward(f.records[1], "Spy", Catalog.rules)
    assert(r.state == "Carrying" and award and award.xp == 50 and award.tokens == 19,
        "Expected the M8 pickup + painting exploit; it is no longer reproducible")
    print("M8 BASELINE REPRODUCED: undelivered Carrying + Painting, active=45 moving=12 => 50 XP / 19 tokens")
end

function Suite.run(loadRequests)
    count = 0
    do
        local f = fixture(loadRequests)
        local request = f:order(f.guest, f.staff)
        check(request.state == "Carrying", "real pantry callbacks pick up the order")
        check(not f.records[1].actions.ServicePickup and #f.calls == 0, "pickup is not completed work")
        f:pantry(f.staff)
        Policy.action(f.records[1], "Painting")
        local award, why = Policy.reward(f.records[1], "Spy", Catalog.rules)
        check(not award and why == "InsufficientActivity", "pickup + painting cannot qualify")
        check(f:credit(1, "ServicePickup") == 0, "repeated pickup cannot confirm a stage")
    end
    for _, failure in ipairs({"Expire", "Cancel", "ResetCharacter", "StaffLeave", "RequesterLeave", "RoundReset", "Paused", "WrongWorker", "NoPickup"}) do
        local f = fixture(loadRequests)
        local r = if failure == "NoPickup" then assert(f.service.ledger:create(3, 2, 0)) else f:order(f.guest, f.staff)
        if failure == "Expire" then f.now = r.expires; f.service.ledger:expire(f.now)
        elseif failure == "Cancel" then f.service.ledger:remove(3, f.now)
        elseif failure == "ResetCharacter" then f.service:resetCharacter(f.staff)
        elseif failure == "StaffLeave" then f.service:remove(f.staff); f.players[1] = nil
        elseif failure == "RequesterLeave" then f.service:remove(f.guest); f.players[3] = nil
        elseif failure == "RoundReset" then f.scope.alive = false
        elseif failure == "Paused" then f.scope.running = false
        elseif failure == "NoPickup" then f.service.ledger:accept(1, 0, false) end
        check(not f.service:complete(r, if failure == "WrongWorker" then 2 else 1), failure .. " cannot deliver stale/unowned work")
        check(f:credit(1, "ServicePickup") == 0 and f:credit(1, "Delivery") == 0, failure .. " no retroactive credit")
        Policy.action(f.records[1], "Painting")
        check(not Policy.reward(f.records[1], "Spy", Catalog.rules), failure .. " no unearned qualification")
    end
    for _, receiver in ipairs({"OtherStaff", "NPC", "Reconnect"}) do
        local f = fixture(loadRequests)
        local r = f:order(f.guest, f.staff)
        f.service:remove(f.staff)
        f.records[1].left = true
        local executor
        if receiver == "Reconnect" then
            f.staff = f:add(1, "Staff")
            -- A connection arriving mid-round is not eligible for the old round.
            f.records[1].left = true
            executor = 1
        elseif receiver == "NPC" then executor = 0 else executor = 2 end
        check(not f.service:complete(r, executor), "released pickup cannot transfer to " .. receiver)
        f.now = Config.REQUEST_NPC_DELAY
        check(f.service.ledger:accept(executor, f.now, executor == 0) == r, "new executor claims same request")
        check(f.service.ledger:pickup(r, executor, f.now), "new executor must pick up itself")
        check(f.service:complete(r, executor), "new executor completes its own work")
        check(not f.records[1].actions.ServicePickup and not Policy.reward(f.records[1], "Spy", Catalog.rules), "first/left connection receives no credit")
        if executor == 2 then
            local award = Policy.reward(f.records[2], "Spy", Catalog.rules)
            check(award and award.tokens == 19 and award.xp == 50, "replacement staff earns own delivery")
        elseif executor == 0 then
            check(f:credit(1, "ServicePickup") == 0 and f:credit(2, "ServicePickup") == 0, "NPC never confirms human pickup")
        end
    end
    do
        local f = fixture(loadRequests)
        f:pantry(f.guest)
        check(#f.calls == 0, "non-staff pantry action cannot award")
        local r = f:order(f.guest, f.staff)
        f.players[1] = nil
        check(f.service:complete(r, 1), "ledger can finish while executor is absent")
        check(f:credit(1, "ServicePickup") == 0 and f:credit(1, "Delivery") == 0, "no client means no staff credit")
    end
    do
        local f = fixture(loadRequests)
        local r = f:order(f.guest, f.staff)
        f.staff.role = "Guest"
        f:deliver(f.staff)
        check(r.state == "Carrying" and #f.calls == 0, "non-staff delivery prompt is denied")
    end
    for _, gate in ipairs({"Qualified", "Short", "Stationary", "AFK"}) do
        local f = fixture(loadRequests)
        f.records[1].active = if gate == "Short" then 44 elseif gate == "AFK" then 0 else 45
        f.records[1].moving = if gate == "Stationary" then 11 elseif gate == "AFK" then 0 else 12
        local r = f:order(f.guest, f.staff)
        f:deliver(f.staff)
        check(r.state == "Delivered" and f.service.ledger.scores[1] == Config.REQUEST_POINTS, "successful delivery keeps session points")
        check(f:credit(1, "ServicePickup") == 1 and f:credit(1, "Delivery") == 1, "both completed stages emitted once")
        f:deliver(f.staff)
        check(not f.service:complete(r, 1), "repeat completion rejected by real ledger")
        check(f:credit(1, "ServicePickup") == 1 and f:credit(1, "Delivery") == 1, "repeat prompt cannot emit stages again")
        local award = Policy.reward(f.records[1], "Spy", Catalog.rules)
        check((award ~= nil) == (gate == "Qualified"), "existing activity/movement gates remain")
        if award then check(award.xp == 50 and award.tokens == 19, "ordinary losing participation reward unchanged") end
        check(not Policy.reward(f.records[1], "Spy", Catalog.rules), "one round settles at most once")
    end
    do
        local f = fixture(loadRequests)
        f:order(f.guest, f.staff); f:deliver(f.staff)
        f.now = Config.REQUEST_COOLDOWN
        f:order(f.guest, f.staff); f:deliver(f.staff)
        check(f:credit(1, "Delivery") == 2 and f.service.ledger.scores[1] == 2 * Config.REQUEST_POINTS, "two actual orders keep session scoring")
        local award = Policy.reward(f.records[1], "Spy", Catalog.rules)
        check(award and award.xp == 50 and award.tokens == 19, "two deliveries do not duplicate progression action types")
    end
    do
        local f = fixture(loadRequests)
        f:order(f.guest, f.staff)
        Policy.action(f.records[1], "Painting"); Policy.action(f.records[1], "Refreshment")
        local award = Policy.reward(f.records[1], "Spy", Catalog.rules)
        check(award and award.tokens == 19, "staff retains other lawful ways to qualify")
    end
    print("M8.1 staff delivery:", count, "assertions PASS")
end
return Suite
