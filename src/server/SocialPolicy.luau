-- Round-local authority. Service supplies validated living participants and distances.
local Policy = {}
Policy.__index = Policy
Policy.signals = {Here = "↓", Wait = "…", Help = "!", Suspicious = "?"}
function Policy.new()
    return setmetatable({passes = {}, issued = 0, grantAt = 0, items = {
        Parcel = {home = "Collection", place = "Collection"}, Cloth = {home = "Stand", place = "Stand"},
    }, offers = {}, plants = {}, traces = {}, signalsAt = {}, deliveries = {}, delivered = 0}, Policy)
end
function Policy:grant(ownerRole, target, now)
    if ownerRole ~= "Owner" or not target or self.issued >= 3 or now < self.grantAt
        or (self.passes[target] or 0) > now then return false end
    self.issued += 1
    self.grantAt, self.passes[target] = now + 15, now + 60
    return true
end
function Policy:usePass(id, now)
    if (self.passes[id] or 0) <= now then return false end
    self.traces.Reader = now + 45
    return true
end
function Policy:holding(id)
    for key, item in pairs(self.items) do if item.owner == id then return key end end
    return nil
end
function Policy:cancelOffers(source)
    for target, offer in pairs(self.offers) do if offer.from == source then self.offers[target] = nil end end
end
function Policy:pickup(id, key, now)
    local item = self.items[key]
    if not item or item.owner or self:holding(id) or (item.readyAt or 0) > now then return false end
    item.owner, item.place, item.returnAt = id, nil, now + 45
    if key == "Parcel" then self.traces.Collection = now + 60 end
    return true
end
function Policy:offer(id, target, now)
    local key = self:holding(id)
    if not key or id == target or self:holding(target) then return false end
    self.offers[target] = {from = id, key = key, untilTime = now + 8}
    return true
end
function Policy:accept(id, source, now)
    local offer = self.offers[id]
    if not offer or offer.from ~= source or offer.untilTime <= now or self:holding(id)
        or self.items[offer.key].owner ~= source then return false end
    self.items[offer.key].owner = id -- hand-off never extends the return deadline
    self:cancelOffers(source)
    return true
end
function Policy:drop(id, now)
    local key = self:holding(id)
    if not key then return nil end
    local item = self.items[key]
    item.owner, item.place = nil, "Dropped"
    self:cancelOffers(id)
    item.returnAt = math.min(item.returnAt, now + 15)
    return key
end
function Policy:deliver(id, role, now)
    if (role ~= "Guest" and role ~= "Staff") or self:holding(id) ~= "Parcel"
        or self.deliveries[id] or self.delivered >= 6 then return false end
    self.deliveries[id], self.delivered = true, self.delivered + 1
    local item = self.items.Parcel
    self:cancelOffers(id)
    item.owner, item.place, item.readyAt, item.returnAt = nil, item.home, now + 10, nil
    return true
end
function Policy:plant(id, now)
    if self:holding(id) ~= "Cloth" or (self.plants[id] or 0) >= 2 then return false end
    self.plants[id] = (self.plants[id] or 0) + 1
    self.traces.Fabric = now + 45
    local item = self.items.Cloth
    self:cancelOffers(id)
    item.owner, item.place, item.readyAt, item.returnAt = nil, item.home, now + 20, nil
    return true
end
function Policy:signal(id, key, now)
    if not Policy.signals[key] or now < (self.signalsAt[id] or 0) then return false end
    self.signalsAt[id] = now + 8
    return true
end
function Policy:tick(now)
    for _, item in pairs(self.items) do
        if item.returnAt and item.returnAt <= now then item.owner, item.place, item.returnAt = nil, item.home, nil end
    end
    for key, at in pairs(self.traces) do if at <= now then self.traces[key] = nil end end
    for id, offer in pairs(self.offers) do if offer.untilTime <= now then self.offers[id] = nil end end
end
function Policy:remove(id, now)
    self:drop(id, now)
    self.passes[id], self.offers[id] = nil, nil
    for target, offer in pairs(self.offers) do if offer.from == id then self.offers[target] = nil end end
end
return Policy
