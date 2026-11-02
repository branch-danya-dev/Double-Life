-- Platform-independent coordinator. Fake and real adapters share this exact path.
local Policy = {}
Policy.__index = Policy
function Policy.new(store, market, settings, ready)
    return setmetatable({store = store, market = market, settings = settings, ready = ready,
        ownership = {}, accounts = {}}, Policy)
end
function Policy:enabled()
    local s = self.settings
    return s.enabled == true and s.isolatedDataStoreVerified == true and s.passId > 0 and s.productId > 0
end
function Policy:adopt(id, p)
    if p and (not self.accounts[id] or p.revision >= self.accounts[id].revision) then self.accounts[id] = p end
end
function Policy:owns(id)
    if not self:enabled() then self.ownership[id] = nil; return nil end
    local ok, owns = pcall(function() return self.market:owns(id, self.settings.passId) end)
    -- Failure is UNKNOWN, never a grant. A later verified lookup can restore the cosmetic.
    self.ownership[id] = if ok and type(owns) == "boolean" then owns else nil
    return self.ownership[id]
end
function Policy:receipt(info)
    if not self:enabled() or type(info) ~= "table" or type(info.PlayerId) ~= "number"
        or info.PlayerId <= 0 or info.PlayerId % 1 ~= 0 or info.ProductId ~= self.settings.productId
        or type(info.PurchaseId) ~= "string" or #info.PurchaseId == 0 or #info.PurchaseId > 128
        or not self.ready(info.PlayerId) then return "NotProcessedYet" end
    local granted, p = self.store:grant(info.PlayerId, info.ProductId, info.PurchaseId)
    if not granted then return "NotProcessedYet" end
    self:adopt(info.PlayerId, p)
    return "PurchaseGranted"
end
function Policy:offer(id, key, catalog)
    if not self:enabled() or not self.ready(id) then return false, "Unavailable" end
    local item = catalog[key]
    if not item or not item.cosmetic then return false, "UnknownOffer" end
    if item.kind == "Pass" then
        local owned = self:owns(id)
        if owned ~= false then return false, if owned then "Owned" else "Unavailable" end
    else
        local p = self.store:mutate(id, {kind = "Read"})
        if not p then return false, "Unavailable" end
        local count = 0
        for _ in pairs(p.purchases) do count += 1 end
        -- Reserve space for outstanding/offline sales; never prune even at the hard limit.
        if count >= self.store.capacity - 100 then return false, "Capacity" end
    end
    local ok, info = pcall(function() return self.market:info(self.settings[item.setting], item.kind) end)
    if not ok or type(info) ~= "table" or info.IsForSale ~= true then return false, "Unavailable" end
    return true
end
return Policy
