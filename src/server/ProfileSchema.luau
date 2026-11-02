-- Pure validation: a failed read or corrupt record is never treated as a new account.
local Schema = {}
function Schema.integer(value, maximum)
    return type(value) == "number" and value == value and value >= 0 and value <= maximum and value % 1 == 0
end
function Schema.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = Schema.copy(v) end
    return result
end
function Schema.new(catalog)
    local p = {schemaVersion = 1, revision = 0, reputationXp = 0, tokens = 0, roleXp = {},
        stats = {played = 0, wins = 0, roles = {}}, history = {}, inventory = {}, equipped = {Title = "", Card = ""},
        achievements = {}, receipts = {}, sessionSeq = 0, lease = {owner = "", expires = 0}}
    for _, role in ipairs(catalog.roles) do
        p.roleXp[role], p.stats.roles[role] = 0, {played = 0, wins = 0}
        p.inventory[catalog.defaults[role]], p.equipped[role] = true, catalog.defaults[role]
    end
    return p
end
function Schema.normalize(raw, catalog)
    if raw == nil then return Schema.new(catalog) end
    if type(raw) ~= "table" then return nil, "Malformed" end
    local version = if raw.schemaVersion == nil then 0 else raw.schemaVersion
    if version ~= 0 and version ~= 1 then return nil, "UnsupportedVersion" end
    if version == 0 and (raw.tokens == nil or (raw.xp == nil and raw.reputationXp == nil)) then return nil, "Malformed" end
    local p = Schema.new(catalog)
    -- v0 was a minimal account with xp/tokens. Missing fields are migrated, never invalid values.
    local function number(value, default, maximum)
        if value == nil and version == 0 then return default end
        if not Schema.integer(value, maximum) then error("Malformed number") end
        return value
    end
    local ok = pcall(function()
        p.reputationXp = number(if version == 0 then (if raw.xp ~= nil then raw.xp else raw.reputationXp) else raw.reputationXp, 0, 10000000)
        p.tokens, p.revision = number(raw.tokens, 0, 1000000), number(raw.revision, 0, 1000000000000)
        for _, key in ipairs({"roleXp", "stats", "inventory", "equipped", "history", "receipts", "achievements"}) do
            if raw[key] ~= nil and type(raw[key]) ~= "table" then error("Malformed table") end
            if raw[key] == nil and version == 1 then error("Missing table") end
        end
        local stats = raw.stats or {}
        p.stats.played, p.stats.wins = number(stats.played, 0, 1000000), number(stats.wins, 0, 1000000)
        if p.stats.wins > p.stats.played or (stats.roles ~= nil and type(stats.roles) ~= "table") then error("Malformed stats") end
        for _, role in ipairs(catalog.roles) do
            p.roleXp[role] = number((raw.roleXp or {})[role], 0, 10000000)
            local s = (stats.roles or {})[role] or {}
            p.stats.roles[role] = {played = number(s.played, 0, 1000000), wins = number(s.wins, 0, 1000000)}
            if p.stats.roles[role].wins > p.stats.roles[role].played then error("Malformed role stats") end
        end
        for id in pairs(catalog.items) do
            local owned = (raw.inventory or {})[id]
            if owned ~= nil and type(owned) ~= "boolean" then error("Malformed inventory") end
            if owned then p.inventory[id] = true end
        end
        for slot in pairs(p.equipped) do
            local id = (raw.equipped or {})[slot]
            if id ~= nil and type(id) ~= "string" then error("Malformed equipment") end
            if id and catalog.items[id] and catalog.items[id].slot == slot and p.inventory[id] then p.equipped[slot] = id end
        end
        for _, id in ipairs({"FirstRound", "FirstWin", "AllRoles"}) do
            if (raw.achievements or {})[id] == true then p.achievements[id] = true end
        end
        for index = math.max(1, #(raw.history or {}) - 9), #(raw.history or {}) do
            local h = raw.history[index]
            if type(h) ~= "table" or type(h.id) ~= "string" or #h.id > 180 or not table.find(catalog.roles, h.role)
                or type(h.won) ~= "boolean" or not Schema.integer(h.xp, 1000) or not Schema.integer(h.tokens, 1000)
                or not Schema.integer(h.at, 1000000000000) then error("Malformed history") end
            table.insert(p.history, {id = h.id, role = h.role, won = h.won, xp = h.xp, tokens = h.tokens, at = h.at})
        end
        for index = math.max(1, #(raw.receipts or {}) - 63), #(raw.receipts or {}) do
            local r = raw.receipts[index]
            if type(r) ~= "table" or type(r.id) ~= "string" or #r.id > 180 or type(r.ok) ~= "boolean"
                or type(r.reason) ~= "string" or #r.reason > 80 then error("Malformed receipt") end
            table.insert(p.receipts, {id = r.id, ok = r.ok, reason = r.reason})
        end
        p.sessionSeq = number(raw.sessionSeq, 0, 1000000000)
        local lease = raw.lease
        if lease ~= nil then
            if type(lease) ~= "table" or type(lease.owner) ~= "string" or #lease.owner > 120
                or not Schema.integer(lease.expires, 1000000000000) then error("Malformed lease") end
            p.lease = {owner = lease.owner, expires = lease.expires}
        elseif version == 1 then error("Missing lease") end
    end)
    if not ok then return nil, "Malformed" end
    return p
end
return Schema
