-- Pure account mutations and bounded per-round earning. No client-supplied rewards/prices.
local Policy = {}
function Policy.level(xp, maximum, step)
    local level = 1
    while level < maximum and xp >= step * level * (level + 1) / 2 do level += 1 end
    return level
end
function Policy.unlock(p, catalog)
    local unlocked = {}
    local level = Policy.level(p.reputationXp, 10, 50)
    for id, item in pairs(catalog.items) do
        if item.level and level >= item.level and not p.inventory[id] then p.inventory[id] = true; table.insert(unlocked, id) end
    end
    table.sort(unlocked)
    return unlocked
end
function Policy.round(role, connection)
    return {role = role, connection = connection, active = 0, moving = 0, actions = {}, left = false}
end
function Policy.action(record, key)
    if not record or record.left or record.finished then return false end
    if key == "ServicePickup" and record.role ~= "Staff" then return false end
    -- Exact bounded action keys from trusted server hooks, never a client action id.
    local allowed = {Painting = true, Refreshment = true, Delivery = true, Relic = true, Music = true,
        Incident = true, Window = true, Safe = true, Journal = true, Council = true, Vote = true,
        Access = true, Collection = true, Trace = true, ServicePickup = true}
    if not allowed[key] or record.actions[key] then return false end
    record.actions[key] = true
    return true
end
function Policy.reward(record, winner, rules)
    if not record or record.finished or record.left then return nil, "NotParticipant" end
    record.finished = true
    local count = 0
    for _ in pairs(record.actions) do count += 1 end
    if record.active < rules.minimumActive or record.moving < rules.minimumMoving or count < rules.minimumActions then
        return nil, "InsufficientActivity"
    end
    local won = (record.role == "Spy") == (winner == "Spy")
    count = math.min(count, rules.actionCap)
    return {role = record.role, won = won, xp = rules.participationXp + count * rules.actionXp + (if won then rules.victoryXp else 0),
        roleXp = rules.roleXp + (if won then rules.roleVictoryXp else 0),
        tokens = rules.tokens + count * rules.actionTokens + (if won then rules.victoryTokens else 0)}
end
function Policy.apply(p, op, catalog)
    for _, receipt in ipairs(p.receipts) do if receipt.id == op.id then return receipt.ok, receipt.reason end end
    if op.kind=="Onboarding" then
        if (op.state~="Skipped" and op.state~="Completed") or type(op.at)~="number" or op.at%1~=0
            or op.at<0 or op.at>1000000000000 then return false,"InvalidOnboarding" end
        if p.onboarding.state~="Completed" then p.onboarding={version=1,state=op.state,at=op.at} end
        return true,"OnboardingSaved"
    end
    if op.kind == "Award" then
        local a = op.award
        if type(a) ~= "table" or not table.find(catalog.roles, a.role) or type(a.won) ~= "boolean" then return false, "InvalidAward" end
        for _, key in ipairs({"xp", "roleXp", "tokens"}) do
            local n = a[key]
            if type(n) ~= "number" or n ~= n or n < 0 or n > 1000 or n % 1 ~= 0 then return false, "InvalidAward" end
        end
        if type(op.at) ~= "number" or op.at < 0 or op.at > 1000000000000 or op.at % 1 ~= 0 then return false, "InvalidAward" end
        p.reputationXp = math.min(10000000, p.reputationXp + a.xp)
        p.roleXp[a.role] = math.min(10000000, p.roleXp[a.role] + a.roleXp)
        p.tokens = math.min(1000000, p.tokens + a.tokens)
        p.stats.played = math.min(1000000, p.stats.played + 1)
        local s = p.stats.roles[a.role]
        s.played = math.min(1000000, s.played + 1)
        if a.won then p.stats.wins = math.min(1000000, p.stats.wins + 1); s.wins = math.min(1000000, s.wins + 1); p.achievements.FirstWin = true end
        p.achievements.FirstRound = true
        local all = true
        for _, role in ipairs(catalog.roles) do if p.stats.roles[role].played == 0 then all = false end end
        if all then p.achievements.AllRoles = true end
        table.insert(p.history, {id = op.id, role = a.role, won = a.won, xp = a.xp, tokens = a.tokens, at = op.at})
        while #p.history > 10 do table.remove(p.history, 1) end
        Policy.unlock(p, catalog)
        return true, "Awarded"
    end
    local item = catalog.items[op.item]
    if not item then return false, "UnknownItem" end
    if op.kind == "Buy" then
        if p.inventory[op.item] then return true, "Owned" end
        if type(item.price) ~= "number" or item.price % 1 ~= 0 or item.price < 0 then return false, "NotForSale" end
        if p.tokens < item.price then return false, "InsufficientTokens" end
        p.tokens -= item.price
        p.inventory[op.item] = true
        return true, "Purchased"
    elseif op.kind == "Equip" then
        if not p.inventory[op.item] then return false, "Locked" end
        if item.slot ~= op.slot or p.equipped[op.slot] == nil then return false, "WrongSlot" end
        p.equipped[op.slot] = op.item
        return true, "Equipped"
    end
    return false, "UnknownOperation"
end
return Policy
