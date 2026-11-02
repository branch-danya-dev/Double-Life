-- A separate atomic account: durable receipt tombstones AND charge balance in ONE key.
-- Never prune purchases/uses. At capacity fail closed; migrate before selling more.
-- No full cached overwrite, no M4 bounded receipts, no dependency on a profile lease.
local Store = {}
Store.__index = Store
Store.capacity = 4000
local function integer(n, max)
    return type(n) == "number" and n == n and n % 1 == 0 and n >= 0 and n <= max
end
local function identity(s)
    return type(s) == "string" and #s > 0 and #s <= 128 and not string.find(s, "[%c]")
end
function Store.normalize(raw)
    if raw == nil then return {version = 1, purchases = {}, uses = {}, credits = 0, revision = 0, showSupporter = false} end
    if type(raw) ~= "table" or raw.version ~= 1 or type(raw.purchases) ~= "table" or type(raw.uses) ~= "table"
        or not integer(raw.credits, Store.capacity) or not integer(raw.revision, 1000000000000)
        or type(raw.showSupporter) ~= "boolean" then return nil end
    local p = {version = 1, purchases = {}, uses = {}, credits = raw.credits, revision = raw.revision, showSupporter = raw.showSupporter}
    local purchases, uses = 0, 0
    for id, product in pairs(raw.purchases) do
        if not identity(id) or not integer(product, 9007199254740991) or product == 0 then return nil end
        p.purchases[id], purchases = product, purchases + 1
    end
    for id, at in pairs(raw.uses) do
        if not identity(id) or not integer(at, 1000000000000) then return nil end
        p.uses[id], uses = at, uses + 1
    end
    if purchases > Store.capacity or uses > Store.capacity or purchases - uses ~= p.credits then return nil end
    if raw.effect ~= nil then
        local e = raw.effect
        if type(e) ~= "table" or not identity(e.id) or p.uses[e.id] ~= e.at or type(e.complete) ~= "boolean" then return nil end
        p.effect = {id = e.id, at = e.at, complete = e.complete}
    end
    return p
end
function Store.new(adapter, wait)
    return setmetatable({adapter = adapter, wait = wait or function() end}, Store)
end
function Store:mutate(id, op)
    if not integer(id, 9007199254740991) or id == 0 then return nil, "InvalidUser" end
    for attempt = 1, 3 do
        local reason
        local ok, value = pcall(function()
            return self.adapter:update("Commerce_" .. id, function(raw)
                local p = Store.normalize(raw)
                if not p then reason = "Malformed"; return nil end
                if op.kind == "Grant" then
                    if not identity(op.purchase) or not integer(op.product, 9007199254740991) or op.product == 0 then reason = "InvalidReceipt"; return nil end
                    if p.purchases[op.purchase] then
                        if p.purchases[op.purchase] ~= op.product then reason = "ReceiptConflict"; return nil end
                        return p
                    end
                    local count = 0
                    for _ in pairs(p.purchases) do count += 1 end
                    if count >= Store.capacity then reason = "Capacity"; return nil end
                    p.purchases[op.purchase], p.credits = op.product, p.credits + 1
                elseif op.kind == "Use" then
                    if not identity(op.id) or not integer(op.at, 1000000000000) then reason = "InvalidUse"; return nil end
                    if p.uses[op.id] then return p end
                    if p.effect and not p.effect.complete then return p end -- resume durable pending visual, no second debit
                    if p.effect and op.at - p.effect.at < 60 then reason = "Cooldown"; return nil end
                    if p.credits <= 0 then reason = "Empty"; return nil end
                    p.uses[op.id], p.credits = op.at, p.credits - 1
                    p.effect = {id = op.id, at = op.at, complete = false}
                elseif op.kind == "Complete" then
                    if not p.effect or p.effect.id ~= op.id then reason = "StaleEffect"; return nil end
                    p.effect.complete = true
                elseif op.kind == "Style" then
                    if type(op.selected) ~= "boolean" then reason = "InvalidStyle"; return nil end
                    p.showSupporter = op.selected
                elseif op.kind == "Read" then return p
                else reason = "InvalidOperation"; return nil end
                p.revision += 1
                return p
            end)
        end)
        if ok then return if value then Store.normalize(value) else nil, reason or (if value then "Confirmed" else "Unavailable") end
        if attempt < 3 then self.wait(attempt) end
    end
    return nil, "Unavailable"
end
function Store:grant(id, product, purchase)
    local p, reason = self:mutate(id, {kind = "Grant", product = product, purchase = purchase})
    return p and p.purchases[purchase] == product or false, p, reason
end
return Store
