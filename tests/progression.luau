local Catalog = require("../src/server/ProgressionCatalog")
local Schema = require("../src/server/ProfileSchema")
local Policy = require("../src/server/ProgressionPolicy")
local count = 0
local function check(value, message) assert(value, message); count += 1 end
local p = Schema.new(Catalog)
check(Schema.normalize(p, Catalog) ~= nil, "new profile validates")
for level = 1, 10 do
    local threshold = 50 * (level - 1) * level / 2
    check(Policy.level(threshold, 10, 50) == level, "reputation threshold")
    if level > 1 then check(Policy.level(threshold - 1, 10, 50) == level - 1, "below reputation threshold") end
end
for level = 1, 5 do check(Policy.level(30 * (level - 1) * level / 2, 5, 30) == level, "role level threshold") end
check(Policy.level(10000000, 10, 50) == 10, "level cap")
for _, role in ipairs(Catalog.roles) do
    check(p.inventory[Catalog.defaults[role]] and p.equipped[role] == Catalog.defaults[role], "free competitive starter for " .. role)
    local r = Policy.round(role, "session")
    r.active, r.moving = 60, 15
    check(Policy.action(r, "Painting") and not Policy.action(r, "Painting"), "unique action only")
    Policy.action(r, "Refreshment")
    local award = Policy.reward(r, "Spy", Catalog.rules)
    check(award.xp >= 50 and award.roleXp >= 30, "meaningful first reward regardless of rare role")
    check(not Policy.reward(r, "Spy", Catalog.rules), "duplicate RoundFinished ignored")
    check(Policy.apply(p, {kind = "Award", id = role, award = award, at = 100}, Catalog), "award applies")
end
check(p.stats.played == 5 and p.stats.wins == 1 and p.achievements.AllRoles and p.achievements.FirstWin, "stats and achievements")
check(p.roleXp.Spy == 40 and p.roleXp.Guest == 30 and p.reputationXp == 265, "role XP separated from account XP")
check(p.inventory.Prybar and p.inventory.JournalLens, "general reputation unlocks both alternatives")
local idle = Policy.round("Guest", "session")
idle.active = 420
Policy.action(idle, "Painting"); Policy.action(idle, "Refreshment")
check(not Policy.reward(idle, "Defenders", Catalog.rules), "AFK has no reward despite tasks")
local waiting = Policy.round("Guest", "session")
waiting.moving = 20
Policy.action(waiting, "Painting"); Policy.action(waiting, "Refreshment")
check(not Policy.reward(waiting, "Defenders", Catalog.rules), "waiting has no active participation")
check(not Policy.reward(nil, "Spy", Catalog.rules), "late spectator has no round record")
local short = Policy.round("Spy", "s"); short.active, short.moving = 44, 20
Policy.action(short, "Safe"); Policy.action(short, "Window")
check(not Policy.reward(short, "Spy", Catalog.rules), "reconnect/short session cannot farm")
local left = Policy.round("Spy", "s"); left.active, left.moving, left.left = 420, 100, true
check(not Policy.reward(left, "Spy", Catalog.rules) and not Policy.action(left, "Safe"), "departed participant cannot earn")
local capped = Policy.round("Guest", "s"); capped.active, capped.moving = 420, 100
for _, key in ipairs({"Painting", "Refreshment", "Music", "Relic", "Incident", "Delivery"}) do Policy.action(capped, key) end
check(not Policy.action(capped, "arbitrary client award"), "unknown action rejected")
local maximum = Policy.reward(capped, "Defenders", Catalog.rules)
check(maximum.xp == 75 and maximum.tokens == 28, "actions capped at four regardless of repeats")
local fresh = Schema.new(Catalog)
check(not Policy.apply(fresh, {kind = "Equip", item = "Prybar", slot = "Spy"}, Catalog), "locked tool denied")
check(not Policy.apply(fresh, {kind = "Buy", item = "Prybar"}, Catalog), "tools cannot be purchased")
check(not Policy.apply(fresh, {kind = "Equip", item = "Lockpick", slot = "Owner"}, Catalog), "wrong slot denied")
check(not Policy.apply(fresh, {kind = "Buy", item = "ObserverTitle", price = 0}, Catalog), "client price ignored")
fresh.tokens = 50
check(Policy.apply(fresh, {kind = "Buy", item = "ObserverTitle"}, Catalog) and fresh.tokens == 30, "server catalogue price")
check(Policy.apply(fresh, {kind = "Buy", item = "ObserverTitle"}, Catalog) and fresh.tokens == 30, "double purchase does not double spend")
check(Policy.apply(fresh, {kind = "Equip", item = "ObserverTitle", slot = "Title"}, Catalog), "owned cosmetic equipped")
check(not Policy.apply(fresh, {kind = "Buy", item = "not in catalogue"}, Catalog), "unknown product denied")
check(not Policy.apply(fresh, {kind = "Award", award = {role = "Spy", won = true, xp = 0/0, roleXp = 1, tokens = 1}, at = 10}, Catalog), "invalid internal award rejected")
fresh.receipts = {{id = "already", ok = true, reason = "Awarded"}}
check(Policy.apply(fresh, {kind = "Award", id = "already", award = maximum, at = 10}, Catalog) and fresh.stats.played == 0, "persisted receipt suppresses replay")
for i = 1, 20 do Policy.apply(fresh, {kind = "Award", id = "match" .. i, award = maximum, at = i}, Catalog) end
check(#fresh.history == 10 and fresh.history[1].id == "match11", "bounded last ten matches")
local migrated = Schema.normalize({schemaVersion = 0, xp = 100, tokens = 42}, Catalog)
check(migrated and migrated.schemaVersion == 1 and migrated.reputationXp == 100 and migrated.tokens == 42, "v0 migration preserves balance")
check(not Schema.normalize({schemaVersion = false, tokens = 10}, Catalog), "false version is not a missing version")
check(not Schema.normalize({schemaVersion = 0, xp = false, tokens = 10}, Catalog), "false legacy XP is not a missing balance")
check(not Schema.normalize({}, Catalog), "empty stored table is corruption, not a new account")
check(not Schema.normalize({tokens = 500}, Catalog), "incomplete legacy account is not silently migrated to defaults")
for _, malformed in ipairs({false, "bad", {schemaVersion = 99}, {schemaVersion = 1}}) do
    check(not Schema.normalize(malformed, Catalog), "malformed/future record does not become defaults")
end
for _, value in ipairs({-1, 0/0, math.huge, 1.5, "100", 10000001}) do
    local broken = Schema.new(Catalog); broken.reputationXp = value
    check(not Schema.normalize(broken, Catalog), "invalid XP rejected")
end
for _, key in ipairs({"tokens", "roleXp", "stats", "inventory", "equipped", "lease", "history", "receipts"}) do
    local broken = Schema.new(Catalog); broken[key] = "bad"
    check(not Schema.normalize(broken, Catalog), "malformed " .. key .. " rejected")
end
local badHistory = Schema.new(Catalog); badHistory.history = {{id = "bad"}}
check(not Schema.normalize(badHistory, Catalog), "malformed history rejected")
local brokenEquipment = Schema.copy(fresh); brokenEquipment.equipped.Spy = "Unknown"
local repaired = Schema.normalize(brokenEquipment, Catalog)
check(repaired and repaired.equipped.Spy == "Lockpick" and repaired.tokens == fresh.tokens, "invalid selection falls back without losing economy")
check(Catalog.items.Prybar.window > Catalog.items.Lockpick.window and Catalog.items.Prybar.trace > Catalog.items.Lockpick.trace, "spy sidegrade has measurable cost")
check(Catalog.items.JournalLens.recent == 40 and Catalog.items.JournalLens.readCooldown > Catalog.items.Journal.readCooldown, "agent precision trades cooldown")
print("PASS: " .. count .. " M4 progression, schema and catalogue assertions")
