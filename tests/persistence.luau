local Catalog = require("../src/server/ProgressionCatalog")
local Schema = require("../src/server/ProfileSchema")
local Policy = require("../src/server/ProgressionPolicy")
local Store = require("../src/server/ProfileStore")
local Memory = require("./MemoryStore")
local count, now, waits = 0, 100, {}
local function check(value, message) assert(value, message); count += 1 end
local adapter = Memory.new(Schema.copy)
local function coordinator()
    return Store.new(adapter, Schema, Policy, Catalog, {now = function() return math.floor(now) end,
        wait = function(n) now += n; table.insert(waits, n) end, jitter = function() return 0.2 end, leaseSeconds = 120})
end
local award = {role = "Spy", won = true, xp = 75, roleXp = 40, tokens = 28}
local function grant(id) return {kind = "Award", id = id, award = award, at = math.floor(now)} end
local a, b = coordinator(), coordinator()
local e = a:load(1, "serverA:connection1")
check(e.status == "Ready" and adapter.data.User_1.tokens == 0, "new profile acquired atomically")
check(b:load(1, "serverB:connection1").status == "Locked", "concurrent session conflict")
check(a:enqueue(1, grant("serverA:round1:1")), "enqueue server scoped award")
adapter.faults.User_1 = {"after", "replay"}
check(a:flush(1) and e.profile.tokens == 28 and e.profile.stats.played == 1, "unknown outcome and repeated callback give one grant")
check(#waits == 1 and waits[1] == 1.2, "bounded jittered backoff")
check(a:enqueue(1, grant("serverA:round1:1")) and #e.queue == 0, "duplicate result receipt avoids queued award")
check(a:enqueue(1, {kind = "Buy", id = "buy1", item = "ObserverTitle"}), "purchase queued")
adapter.faults.User_1 = {"after"}
check(a:flush(1) and e.profile.tokens == 8 and e.profile.inventory.ObserverTitle, "ambiguous purchase atomically debits once")
a:enqueue(1, {kind = "Buy", id = "buy2", item = "ObserverTitle"}); a:flush(1)
check(e.profile.tokens == 8, "different repeated purchase id still cannot double spend")
a:enqueue(1, {kind = "Equip", id = "equip", item = "Prybar", slot = "Spy"}); a:flush(1)
check(e.profile.equipped.Spy == "Prybar", "game-unlocked selection persisted")
adapter.faults.User_1 = {"after"}
check(a:close(1, math.floor(now) + 20) and e.status == "Closed", "unknown release outcome retried safely")
check(a:close(1, math.floor(now) + 20), "duplicate shutdown/release is harmless")
local b2 = coordinator(); local rejoined = b2:load(1, "serverB:connection2")
check(rejoined.status == "Ready" and rejoined.profile.tokens == 8 and rejoined.profile.equipped.Spy == "Prybar", "reload preserves progress and selection")
check(not a:enqueue(1, grant("stale")) and not a:flush(1), "old released connection cannot write")
b2:enqueue(1, grant("serverB:round1:1")); b2:flush(1)
check(rejoined.profile.stats.played == 2 and rejoined.profile.tokens == 36, "same round number on different server is distinct")
-- A worker cannot overtake an in-flight retry; arrivals during a yield remain queued.
local seenBusy = false
adapter.onUpdate = function(key)
    if key == "User_1" then
        adapter.onUpdate = nil
        seenBusy = select(2, b2:flush(1)) == "Busy"
        b2:enqueue(1, {kind = "Buy", id = "orderedBuy", item = "TealCard"})
    end
end
b2:enqueue(1, grant("orderedAward")); adapter.faults.User_1 = {"before"}
check(b2:flush(1) and seenBusy and #rejoined.queue == 1 and rejoined.profile.tokens == 64, "one writer, new operation remains ordered behind retry")
check(b2:flush(1) and rejoined.profile.tokens == 39, "queued purchase follows award")
-- All retries fail: no default save; reject new mutations until exact pending batch recovers.
b2:enqueue(1, grant("recover")); adapter.faults.User_1 = {"before", "before", "before"}
local callCount = #adapter.calls
check(not b2:flush(1) and rejoined.status == "Unavailable" and #adapter.calls == callCount + 3, "bounded retries on throttle")
check(not b2:enqueue(1, {kind = "Buy", id = "offlineBuy", item = "AmberCard"}), "offline purchases disabled")
check(adapter.data.User_1.tokens == 39 and #rejoined.queue == 1, "pending operation retained without replacing stored balance")
check(b2:flush(1) and rejoined.profile.tokens == 67, "same lease recovery commits pending operation once")
-- Unknown outcome exhausted; reconnect reads the committed write even if old server crashes.
b2:enqueue(1, grant("crashAward")); adapter.faults.User_1 = {"after", "before", "before"}
check(not b2:flush(1) and adapter.data.User_1.tokens == 95, "unknown outcome may already be durable")
now += 121
local c = coordinator(); local newer = c:load(1, "serverC:new")
check(newer.status == "Ready" and newer.profile.tokens == 95, "expired crash lease permits new session without progress loss")
check(not b2:flush(1) and rejoined.status == "LostLease" and adapter.data.User_1.tokens == 95, "old pending retry cannot overwrite newer session")
check(c:enqueue(1, grant("serverC:round1:1")) and c:flush(1) and newer.profile.tokens == 123, "new owner can continue")
-- Deleted/corrupt/future records and failed loads are never recreated from cached defaults.
adapter.data.User_2 = Schema.new(Catalog); adapter.data.User_2.tokens = 777
adapter.faults.User_2 = {"before", "before", "before"}
local failed = coordinator(); local failedEntry = failed:load(2, "failed")
check(failedEntry.status == "Unavailable" and failedEntry.profile == nil, "failed load provides no writable default")
check(not failed:enqueue(2, grant("no")) and not failed:flush(2) and adapter.data.User_2.tokens == 777, "failed load never destroys real balance")
check(failed:close(2, math.floor(now) + 20), "failed loading connection closes without writing")
check(failed:load(2, "reconnect").profile.tokens == 777, "reconnect safely recovers existing account")
adapter.data.User_3 = {schemaVersion = 9, tokens = 500}
local invalid = coordinator()
check(invalid:load(3, "future").status == "UnsupportedVersion" and adapter.data.User_3.tokens == 500, "future schema preserved")
adapter.data.User_4 = {schemaVersion = 1, tokens = -5}
check(invalid:load(4, "malformed").status == "Malformed" and adapter.data.User_4.tokens == -5, "corrupt account retained for repair")
adapter.data.User_5 = {schemaVersion = 0, xp = 150, tokens = 40}
check(invalid:load(5, "migration").profile.reputationXp == 150 and adapter.data.User_5.schemaVersion == 1, "migration atomic with lease acquisition")
local deleted = coordinator(); deleted:load(6, "deleted"); adapter.data.User_6 = nil
check(not deleted:flush(6) and adapter.data.User_6 == nil, "deleted key cannot be recreated by old cache")
-- Lease expiry is fencing even if nobody has taken over yet.
local expiring = coordinator(); expiring:load(7, "expired"); now += 121
check(not expiring:enqueue(7, grant("tooLate")) and not expiring:flush(7), "expired owner must reconnect")
local release = coordinator(); release:load(8, "shutdown"); release:enqueue(8, grant("shutdownAward"))
adapter.faults.User_8 = {"before"}
check(release:close(8, math.floor(now) + 20) and adapter.data.User_8.tokens == 28 and adapter.data.User_8.lease.expires == 0, "BindToClose path drains queue and releases")
local timeout = coordinator(); local timeoutEntry = timeout:load(9, "deadline")
timeout:enqueue(9, grant("lateShutdown")); adapter.faults.User_9 = {"before", "before", "before"}
check(not timeout:close(9, math.floor(now) + 1) and #timeoutEntry.queue == 1, "shutdown deadline does not pretend a failed write succeeded")
local bounded = coordinator(); local boundedEntry = bounded:load(10, "bounded")
for i = 1, 80 do bounded:enqueue(10, grant("bounded:" .. i)); bounded:flush(10) end
check(#boundedEntry.profile.receipts == 64 and #boundedEntry.profile.history == 10, "persistent ledgers bounded")
local before = boundedEntry.profile.stats.played
-- Replaying a previously applied batch sequence after receipt eviction is still fenced.
boundedEntry.queue = {{kind = "Award", id = "bounded:1", award = award, at = 100, seq = 1}}
check(bounded:flush(10) and boundedEntry.profile.stats.played == before, "monotonic sequence protects old retry beyond receipt window")
print("PASS: " .. count .. " M4 storage, concurrency and failure assertions")
