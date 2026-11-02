local Catalog = require("../src/server/ProgressionCatalog")
local Schema = require("../src/server/ProfileSchema")
local Policy = require("../src/server/ProgressionPolicy")
local Store = require("../src/server/ProfileStore")
local Memory = require("./MemoryStore")
local count, now = 0, 100
local function check(value, message) assert(value, message); count += 1 end
local adapter = Memory.new(Schema.copy)
local store = Store.new(adapter, Schema, Policy, Catalog, {now = function() return math.floor(now) end,
    wait = function(seconds) now += seconds end, jitter = function() return 0 end, leaseSeconds = 120})
local award = {role = "Spy", won = true, xp = 75, roleXp = 40, tokens = 28}
store:load(1, "old-connection")
store:enqueue(1, {kind = "Award", id = "round-one", award = award, at = 100})
store:flush(1)
store:enqueue(1, {kind = "Buy", id = "buy-title", item = "ObserverTitle"})
store:enqueue(1, {kind = "Equip", id = "equip-title", item = "ObserverTitle", slot = "Title"})
adapter.faults.User_1 = {"before", "before", "before"}
check(not store:close(1, now + 20), "all three close attempts fail")
local old = store.entries[1]
print("REPRO failed close:", old.status, "closing", old.closing, "queue", #old.queue, "token", old.token)
local restored = store:load(1, "new-connection", now + 20)
print("REPRO same-server reconnect:", restored and restored.status, "token", restored and restored.token)
check(restored and restored.token == "new-connection" and restored.status == "Ready", "failed close -> same-server reconnect must acquire NEW token")
check(restored.profile.tokens == 8 and restored.profile.inventory.ObserverTitle and restored.profile.equipped.Title == "ObserverTitle",
    "pending purchase/equip drained without progress loss")
check(restored.profile.roleXp.Spy == 40 and #restored.profile.history == 1 and restored.profile.stats.played == 1,
    "role XP, history and stats survive failed close")
check(old.token == "old-connection" and old.status == "Closed", "old token is never relabelled")
check(not store:enqueue(1, {kind = "Buy", id = "stale", item = "TealCard"}, old.token), "old callback cannot enqueue for new connection")
check(not store:flush(1, false, nil, old.token) and not store:close(1, now + 20, old.token), "stale flush/close cannot affect new lease")
store:enqueue(1, {kind = "Award", id = "round-two", award = award, at = 101}, restored.token)
check(store:flush(1, false, nil, restored.token) and restored.profile.tokens == 36 and restored.profile.stats.played == 2,
    "next round awards work after recovery")
check(store:load(1, "unretired-token") == nil, "load never lends a live entry to a different token")

local function fixture()
    local f = {time = 100}
    f.adapter = Memory.new(Schema.copy)
    f.options = {now = function() return math.floor(f.time) end, wait = function(n) f.time += n end,
        jitter = function() return 0 end, leaseSeconds = 120}
    f.store = Store.new(f.adapter, Schema, Policy, Catalog, f.options)
    return f
end
local function grant(s, id, token)
    return s:enqueue(id, {kind = "Award", id = token .. ":round", award = award, at = 100}, token)
end
-- Release committed but all three responses failed. Reconcile the exact batch before takeover.
local ambiguous = fixture()
local ae = ambiguous.store:load(2, "ambiguous-old")
grant(ambiguous.store, 2, ae.token)
ambiguous.store:enqueue(2, {kind = "Buy", id = "ambiguous-buy", item = "ObserverTitle"}, ae.token)
ambiguous.adapter.faults.User_2 = {"after", "before", "before"}
check(not ambiguous.store:close(2, 120) and #ae.queue == 2, "unknown release outcome retains pending batch")
check(ambiguous.adapter.data.User_2.tokens == 8 and ambiguous.adapter.data.User_2.lease.expires == 0, "release may already have committed")
local anew = ambiguous.store:load(2, "ambiguous-new", 130)
check(anew and anew.profile.tokens == 8 and anew.profile.stats.played == 1 and anew.unconfirmed == 0,
    "unknown release reconciles without double reward or debit")
ambiguous.store:enqueue(2, {kind = "Buy", id = "repeat-buy", item = "ObserverTitle"}, anew.token)
check(ambiguous.store:flush(2) and anew.profile.tokens == 8, "ordinary repeat purchase after reconnect remains idempotent")

-- Timeout before a retry, then recovery while the original lease is still valid.
local timed = fixture()
timed.store:load(3, "timeout-old"); grant(timed.store, 3, "timeout-old")
timed.adapter.faults.User_3 = {"before"}
check(not timed.store:close(3, 101) and #timed.store.entries[3].queue == 1, "short close deadline retains the award")
local timedNew = timed.store:load(3, "timeout-new", 120)
check(timedNew and timedNew.profile.tokens == 28 and timedNew.profile.roleXp.Spy == 40, "retry after timeout safely drains old queue")

-- Once fenced, NEVER replay an old uncommitted operation under a fresh lease.
local fenced = fixture()
local fe = fenced.store:load(4, "fenced-old")
grant(fenced.store, 4, fe.token); fenced.store:flush(4)
fenced.store:enqueue(4, {kind = "Buy", id = "unconfirmed-buy", item = "ObserverTitle"}, fe.token)
fenced.adapter.faults.User_4 = {"before", "before", "before"}
fenced.store:close(4, 120)
fenced.time += 121
local other = Store.new(fenced.adapter, Schema, Policy, Catalog, fenced.options)
local oe = other:load(4, "foreign-live")
grant(other, 4, oe.token); other:flush(4)
local blocked, blockedWhy = fenced.store:load(4, "fenced-new", fenced.time + 20)
check(blocked and blocked.status == "Locked" and blocked.token == "fenced-new", "new connection honestly sees foreign lease conflict")
check(blockedWhy == nil and fenced.adapter.data.User_4.tokens == 56 and #fe.queue == 1, "fenced queue preserved, foreign progress untouched")
check(not fenced.store:flush(4, false, nil, fe.token), "old writer cannot overwrite foreign owner")
other:close(4, fenced.time + 20)
local fn = fenced.store:load(4, "fenced-new", fenced.time + 20)
check(fn.status == "Ready" and fn.profile.tokens == 56 and not fn.profile.inventory.ObserverTitle and fn.unconfirmed == 1,
    "fresh authoritative profile reports unconfirmed purchase without replay")
fenced.store:enqueue(4, {kind = "Buy", id = "explicit-new-buy", item = "ObserverTitle"}, fn.token)
check(fenced.store:flush(4) and fn.profile.tokens == 36, "new explicit purchase remains available after fenced recovery")

local known = fixture()
local ke = known.store:load(5, "known-old"); grant(known.store, 5, ke.token)
known.adapter.faults.User_5 = {"after", "before", "before"}
known.store:flush(5); ke.closing = true; known.time += 121
local kn = known.store:load(5, "known-new", known.time + 20)
check(kn and kn.profile.stats.played == 1 and kn.profile.tokens == 28 and kn.unconfirmed == 0,
    "expired lease uses receipts/sequence to distinguish confirmed ambiguous award")

-- Deterministic coroutine scheduler: real yields in the same production lifecycle module.
local Sessions = require("../src/server/ProfileSessions")
local function asyncFixture(seconds)
    local f = fixture()
    f.jobs, f.notifications, f.warnings, f.serial = {}, {}, {}, 0
    local function schedule(co, at)
        f.serial += 1; table.insert(f.jobs, {co = co, at = at, serial = f.serial})
    end
    local function spawn(fn) schedule(coroutine.create(fn), f.time) end
    local function wait(n) coroutine.yield(math.max(n, 0.001)) end
    f.options.wait = wait
    f.sessions = Sessions.new(f.store, {now = function() return f.time end, spawn = spawn, wait = wait,
        jitter = function() return 0 end, recoverySeconds = seconds or 180,
        warn = function(why, pending) table.insert(f.warnings, {why = why, pending = pending}) end,
        changed = function(c)
            assert(f.sessions:isCurrent(c.id, c.token), "obsolete callbacks must not publish")
            table.insert(f.notifications, {token = c.token, status = c.status, retrying = c.retrying})
        end})
    function f:run(secondsToRun)
        local target, steps = self.time + secondsToRun, 0
        while #self.jobs > 0 do
            table.sort(self.jobs, function(a, b) return a.at < b.at or (a.at == b.at and a.serial < b.serial) end)
            if self.jobs[1].at > target then break end
            local job = table.remove(self.jobs, 1); self.time = job.at
            local ok, delay = coroutine.resume(job.co); assert(ok, tostring(delay))
            if coroutine.status(job.co) ~= "dead" then schedule(job.co, self.time + delay) end
            steps += 1; assert(steps < 10000, "retry loop must be bounded")
        end
        self.time = target
    end
    f.spawn = spawn
    return f
end

local rapid = asyncFixture()
rapid.sessions:start(10, "first"); rapid:run(0)
grant(rapid.store, 10, "first")
rapid.store:enqueue(10, {kind = "Buy", id = "rapid-buy", item = "ObserverTitle"}, "first")
rapid.adapter.faults.User_10 = {"before", "before", "before"}
rapid.sessions:stop(10, "first")
check(rapid.store.entries[10].closing and not rapid.store:enqueue(10, {id = "after-remove"}, "first"), "remove immediately fences new operations")
rapid.sessions:start(10, "second"); rapid:run(0.2)
check(rapid.sessions.current[10].retrying and rapid.store.entries[10].token == "first", "second connection waits while old close yields")
rapid.sessions:stop(10, "second"); rapid.sessions:start(10, "third"); rapid:run(20)
local r = rapid.store.entries[10]
check(r.token == "third" and r.status == "Ready" and r.profile.tokens == 8, "third rapid reconnect recovers one award and one purchase")
check(rapid.sessions.current[10].status == "Ready" and not rapid.sessions.current[10].retrying, "recovery stops after confirmed acquisition")
local secondReady = false
for _, n in ipairs(rapid.notifications) do if n.token == "second" and n.status == "Ready" then secondReady = true end end
check(not secondReady, "obsolete second connection never publishes success")
rapid.sessions:stop(10, "first"); rapid:run(1)
check(r.status == "Ready" and rapid.adapter.data.User_10.lease.owner == "third", "delayed old removal cannot close latest session")
grant(rapid.store, 10, "third"); rapid.store:flush(10)
check(r.profile.stats.played == 2 and r.profile.tokens == 36, "ordinary next round recovers after rapid reconnect")

local loading = asyncFixture()
loading.adapter.onUpdate = function()
    loading.adapter.onUpdate = nil
    coroutine.yield(5)
end
loading.sessions:start(11, "loading-old"); loading:run(0)
check(loading.store.entries[11].busy, "load suspended in adapter")
loading.sessions:stop(11, "loading-old"); loading.sessions:start(11, "loading-new"); loading:run(15)
check(loading.store.entries[11].token == "loading-new" and loading.store.entries[11].status == "Ready", "leave during Loading cancels old acquisition and recovers new one")
check(loading.adapter.data.User_11.lease.owner == "loading-new" and #loading.jobs == 0, "no abandoned writer after loading cancellation")

local lostLoad = asyncFixture()
lostLoad.adapter.faults.User_12 = {"after"}
lostLoad.sessions:start(12, "lost-load-old"); lostLoad:run(0)
check(lostLoad.adapter.data.User_12.lease.owner == "lost-load-old", "load commit can precede lost response")
lostLoad.sessions:stop(12, "lost-load-old"); lostLoad.sessions:start(12, "lost-load-new"); lostLoad:run(15)
check(lostLoad.store.entries[12].token == "lost-load-new" and lostLoad.store.entries[12].status == "Ready", "unknown load acquisition released without waiting for lease expiry")
check(lostLoad.adapter.data.User_12.stats.played == 0 and lostLoad.adapter.data.User_12.tokens == 0, "cancelled load cannot invent progress")

local outage = asyncFixture(35)
outage.sessions:start(13, "outage-old"); outage:run(0)
grant(outage.store, 13, "outage-old"); outage.store:flush(13)
outage.store:enqueue(13, {kind = "Buy", id = "outage-buy", item = "ObserverTitle"}, "outage-old")
outage.adapter.onUpdate = function() error("persistent isolated outage") end
outage.sessions:stop(13, "outage-old"); outage.sessions:start(13, "outage-new"); outage:run(45)
check(not outage.sessions.current[13].retrying and outage.sessions.current[13].status == "Unavailable", "bounded outage ends with explicit unavailable status")
check(#outage.jobs == 0 and #outage.adapter.calls < 45, "outage has bounded attempts and no infinite background worker")
check(outage.adapter.data.User_13.tokens == 28 and #outage.store.entries[13].queue == 1, "outage preserves stored balance and pending queue")
check(not outage.store:enqueue(13, {kind = "Buy", id = "offline", item = "TealCard"}, "outage-new"), "offline reconnect cannot purchase against old entry")
outage.adapter.onUpdate = nil
outage.sessions:start(13, "outage-next"); outage:run(10)
check(outage.store.entries[13].status == "Ready" and outage.store.entries[13].profile.tokens == 8, "later retry drains retained purchase after outage")

local foreign = asyncFixture()
local foreignStore = Store.new(foreign.adapter, Schema, Policy, Catalog, foreign.options)
foreignStore:load(14, "other-server")
foreign.sessions:start(14, "waiting-connection"); foreign:run(15)
check(foreign.sessions.current[14].status == "Locked" and foreign.sessions.current[14].retrying, "live foreign lease shows conflict while retrying")
check(foreign.adapter.data.User_14.lease.owner == "other-server", "recovery does not steal a live foreign lease")
foreignStore:close(14, foreign.time + 20)
foreign:run(15)
check(foreign.store.entries[14].status == "Ready" and foreign.adapter.data.User_14.lease.owner == "waiting-connection", "foreign release recovers without another user login")

local parallel = asyncFixture()
parallel.sessions:start(15, "parallel"); parallel:run(0)
grant(parallel.store, 15, "parallel")
parallel.adapter.faults.User_15 = {"after"}
parallel.sessions:stop(15, "parallel")
local shutdownOk
parallel.spawn(function() shutdownOk = parallel.sessions:shutdown(25) end)
parallel:run(30)
check(shutdownOk and parallel.store.entries[15].status == "Closed", "parallel remove and BindToClose wait for the same serialized writer")
check(parallel.adapter.data.User_15.tokens == 28 and parallel.adapter.data.User_15.lease.expires == 0, "parallel release commits pending reward once")
check(parallel.sessions:start(15, "after-shutdown") == nil, "shutdown cannot start new recovery workers")

local shutdownLoading = asyncFixture()
shutdownLoading.adapter.onUpdate = function() shutdownLoading.adapter.onUpdate = nil; coroutine.yield(5) end
shutdownLoading.sessions:start(16, "shutdown-loading"); shutdownLoading:run(0)
local loadingShutdownOk
shutdownLoading.spawn(function() loadingShutdownOk = shutdownLoading.sessions:shutdown(25) end)
shutdownLoading:run(30)
check(loadingShutdownOk and shutdownLoading.store.entries[16].status == "Closed", "shutdown cancels suspended acquisition")
check(shutdownLoading.adapter.data.User_16 == nil and #shutdownLoading.notifications == 0, "shutdown callback creates no defaults and publishes no stale success")

local shutdownFail = asyncFixture()
shutdownFail.sessions:start(17, "shutdown-fail"); shutdownFail:run(0)
grant(shutdownFail.store, 17, "shutdown-fail")
shutdownFail.adapter.onUpdate = function() error("shutdown outage") end
local failedShutdown
shutdownFail.spawn(function() failedShutdown = shutdownFail.sessions:shutdown(2) end)
shutdownFail:run(10)
check(failedShutdown == false and #shutdownFail.store.entries[17].queue == 1, "shutdown failure is not reported as successful saving")
check(shutdownFail.adapter.data.User_17.tokens == 0 and #shutdownFail.warnings > 0, "unconfirmed shutdown keeps data intact and emits warning")
local slow = asyncFixture()
slow.adapter.onUpdate = function() slow.adapter.onUpdate = nil; coroutine.yield(30) end
slow.sessions:start(18, "slow-old"); slow:run(0)
slow.sessions:stop(18, "slow-old"); slow.sessions:start(18, "slow-new"); slow:run(22)
check(slow.store.entries[18].busy and slow.store.entries[18].token == "slow-old", "close deadline cannot replace an in-flight writer")
check(slow.sessions.current[18].retrying and slow.sessions.current[18].status ~= "Ready", "slow load remains visibly recovering after first close deadline")
slow:run(25)
check(slow.store.entries[18].token == "slow-new" and slow.store.entries[18].status == "Ready", "slow canceled callback eventually releases the key for the current connection")

local malformed = asyncFixture()
malformed.adapter.data.User_19 = {schemaVersion = 99, tokens = 765}
malformed.sessions:start(19, "future-schema"); malformed:run(10)
check(malformed.sessions.current[19].status == "UnsupportedVersion" and not malformed.sessions.current[19].retrying,
    "permanent schema error stops automatic retries with honest status")
check(malformed.adapter.data.User_19.tokens == 765 and #malformed.adapter.calls == 1, "recovery never overwrites unsupported data with defaults")
print("PASS: " .. count .. " M4.1 reconnect, lifecycle and fencing assertions")
