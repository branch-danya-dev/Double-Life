local Store = require("../src/server/CommerceStore")
local Policy = require("../src/server/CommercePolicy")
local Catalog = require("../src/server/CommerceCatalog")
local Settings = require("../src/server/MonetizationSettings")
local Schema = require("../src/server/ProfileSchema")
local Memory = require("./MemoryStore")
local Market = require("./FakeMarketplace")
local count = 0
local function check(ok, message) assert(ok, message); count += 1 end
local adapter, market = Memory.new(Schema.copy), Market.new()
local store = Store.new(adapter)
local ready = true
-- Synthetic IDs in test files only; they are never passed to Roblox.
local settings = {enabled = true, isolatedDataStoreVerified = true, passId = 101, productId = 202}
local policy = Policy.new(store, market, settings, function() return ready end)
local receipt = {PlayerId = 7, ProductId = 202, PurchaseId = "purchase-1"}
check(not Policy.new(store, market, Settings, function() return true end):enabled(), "shipping disabled and IDs zero")
local off = Policy.new(store, market, Settings, function() return true end)
check(off:receipt(receipt) == "NotProcessedYet" and #adapter.calls == 0, "off never saves fake grant")
check(not policy:offer(7, "unknown", Catalog), "unknown catalogue ID rejected")
check(policy:owns(7) == false and policy:offer(7, "Supporter", Catalog), "unowned pass can offer")
market.ownership[7] = true
check(policy:owns(7) and not policy:offer(7, "Supporter", Catalog), "owned pass closed")
market.failure = true
check(policy:owns(7) == nil and not policy:offer(7, "Supporter", Catalog), "ownership failure cannot grant")
market.failure = false; market.forSale = false
check(not policy:offer(7, "Celebration", Catalog), "closed product rejected")
market.forSale = true
check(policy:offer(7, "Celebration", Catalog), "configured product available with ready storage")
ready = false
check(policy:receipt(receipt) == "NotProcessedYet" and not policy:offer(7, "Celebration", Catalog), "unready profile defers purchase")
ready = true
for _, bad in ipairs({{}, {PlayerId = 7, ProductId = 999, PurchaseId = "x"}, {PlayerId = 0, ProductId = 202, PurchaseId = "x"},
    {PlayerId = 7, ProductId = 202, PurchaseId = ""}, {PlayerId = 7, ProductId = 202, PurchaseId = string.rep("x", 129)}}) do
    check(policy:receipt(bad) == "NotProcessedYet", "invalid receipt deferred")
end
adapter.faults.Commerce_7 = {"after", "before", "before"}
check(policy:receipt(receipt) == "NotProcessedYet", "ambiguous commit never acknowledged")
check(adapter.data.Commerce_7.credits == 1, "unknown response can have durable grant")
local foreign = Policy.new(Store.new(adapter), Market.new(), settings, function() return true end)
check(foreign:receipt(receipt) == "PurchaseGranted" and adapter.data.Commerce_7.credits == 1, "crash/reconnect/foreign server exact dedup")
check(policy:receipt(receipt) == "PurchaseGranted" and adapter.data.Commerce_7.credits == 1, "old server repeat exact dedup")
for i = 2, 100 do
    check(policy:receipt({PlayerId = 7, ProductId = 202, PurchaseId = "purchase-" .. i}) == "PurchaseGranted", "many permanent receipts")
end
check(policy:receipt(receipt) == "PurchaseGranted" and adapter.data.Commerce_7.credits == 100, "receipt survives beyond 64-entry M4 history")
adapter.faults.Commerce_7 = {"replay"}
local used = store:mutate(7, {kind = "Use", id = "use-1", at = 100})
check(used and used.credits == 99 and not used.effect.complete, "debit plus pending visual atomic under callback replay")
local repeatUse = foreign.store:mutate(7, {kind = "Use", id = "use-1", at = 100})
check(repeatUse.credits == 99, "same use from foreign server no second charge")
local reconnect = foreign.store:mutate(7, {kind = "Use", id = "new-use-after-crash", at = 1000})
check(reconnect.credits == 99 and reconnect.effect.id == "use-1", "pending visual resumes after crash, retains charge right")
check(not store:mutate(7, {kind = "Complete", id = "wrong"}), "stale visual completion rejected")
check(store:mutate(7, {kind = "Complete", id = "use-1"}).effect.complete, "visible effect completion confirmed")
check(not store:mutate(7, {kind = "Use", id = "too-fast", at = 130}), "persistent global cosmetic cooldown")
adapter.faults.Commerce_7 = {"after", "before", "before"}
check(not store:mutate(7, {kind = "Use", id = "use-2", at = 170}), "unknown use outcome")
check(foreign.store:mutate(7, {kind = "Use", id = "use-2", at = 170}).credits == 98, "retry unknown debit exact once")
local p = foreign.store:mutate(7, {kind = "Read"})
check(p.credits == 98 and p.purchases["purchase-1"] == 202 and p.uses["use-1"] == 100, "read never trims permanent tombstones")
local newer = Schema.copy(p); newer.revision += 10
policy:adopt(7, newer); policy:adopt(7, p)
check(policy.accounts[7].revision == newer.revision, "out-of-order confirmations cannot regress cache")
check(not store:grant(7, 999, "purchase-1"), "PurchaseId product mismatch fails closed")
adapter.data.Commerce_8 = {version = 1, credits = 12}
check(not store:grant(8, 202, "x") and adapter.data.Commerce_8.credits == 12, "corruption never replaced by defaults")
local full = Store.normalize(nil)
for i = 1, Store.capacity do full.purchases["r" .. i] = 202 end
full.credits = Store.capacity
adapter.data.Commerce_9 = full
check(not store:grant(9, 202, "overflow"), "capacity defers new receipt, no false grant")
check(store:grant(9, 202, "r1") and adapter.data.Commerce_9.credits == Store.capacity, "permanent duplicate still acknowledged at capacity")
check(not policy:offer(9, "Celebration", Catalog), "shop stops before durable capacity")
local settingsWithoutGate = Schema.copy(settings); settingsWithoutGate.isolatedDataStoreVerified = false
check(not Policy.new(store, market, settingsWithoutGate, function() return true end):enabled(), "enabled alone cannot bypass DataStore release gate")
local requests = 0
adapter.onUpdate = function()
    requests += 1
    if requests == 1 then coroutine.yield() end
end
local one = coroutine.create(function() check(policy:receipt({PlayerId = 10, ProductId = 202, PurchaseId = "race"}) == "PurchaseGranted", "yielded server confirms") end)
check(coroutine.resume(one), "first server in flight")
check(foreign:receipt({PlayerId = 10, ProductId = 202, PurchaseId = "race"}) == "PurchaseGranted", "competing server confirms")
check(coroutine.resume(one) and adapter.data.Commerce_10.credits == 1, "competing sessions grant one charge")
print("PASS: " .. count .. " M5 commerce, durable receipt and failure assertions")
