local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local Store = require(script.Parent.CommerceStore)
local Policy = require(script.Parent.CommercePolicy)
local Catalog = require(script.Parent.CommerceCatalog)
local Settings = require(script.Parent.MonetizationSettings)
local Progression = require(script.Parent.ProgressionCatalog)
local Service = {}
Service.__index = Service
function Service.new(rt, tell, options)
    options = options or {}
    assert(not (options.market or options.commerceAdapter or options.commerceSettings or options.commerceId) or game:GetService("RunService"):IsStudio(), "Commerce injection is Studio-only")
    local settings = options.commerceSettings or Settings
    local adapter = options.commerceAdapter
    -- Off means no commerce DataStore API calls, including reads or default-account writes.
    if not adapter then
        adapter = if settings.enabled and settings.isolatedDataStoreVerified then require(script.Parent.DataStoreAdapter).new(settings)
            else {mode = "Disabled", update = function() error("Commerce disabled") end}
    end
    local market = options.market or require(script.Parent.MarketplaceAdapter).new()
    local self = setmetatable({rt = rt, tell = tell, settings = settings, market = market, busy = {}, last = {},
        generations = {}, waves = {}, effects = {}, nextEffect = 0, purchasesSeen = {}, refreshAt = {}, injected = options.market ~= nil,
        userId = options.commerceId or function(player) return player.UserId end}, Service)
    self.store = Store.new(adapter, task.wait)
    self.policy = Policy.new(self.store, market, settings, function(id)
        for _, player in ipairs(Players:GetPlayers()) do
            if self.userId(player) == id then
                local e = rt.profiles:entry(player)
                return e and e.status == "Ready" and not e.closing and e.profile.lease.expires > os.time() or false
            end
        end
        return false
    end)
    market:bind(function(info)
        local decision = self.policy:receipt(info)
        if decision == "PurchaseGranted" and not self.purchasesSeen[info.PurchaseId] then
            self.purchasesSeen[info.PurchaseId] = true
            for _, player in ipairs(Players:GetPlayers()) do if self.userId(player) == info.PlayerId then rt.telemetry:emit(player, "Purchase") end end
        end
        return decision
    end, function(player, pass)
        if pass == settings.passId and self.generations[player] then
            local before = self.policy.ownership[self.userId(player)]
            local owns = self.policy:owns(self.userId(player))
            if owns and not before then rt.telemetry:emit(player, "Purchase") end
        end
    end)
    return self
end
function Service:socialPhase()
    local phase = self.rt.rounds.policy.phase
    return phase == "Waiting" or phase == "Results"
end
function Service:add(player)
    local generation = {}
    self.generations[player] = generation
    if not self.policy:enabled() then return end
    task.spawn(function()
        local id = self.userId(player)
        self.policy:owns(id)
        for _ = 1, 30 do
            if self.generations[player] ~= generation then return end
            if self.policy.ready(id) then
                local p = self.store:mutate(id, {kind = "Read"})
                if self.generations[player] == generation then self.policy:adopt(id, p) end
                return
            end
            task.wait(1)
        end
    end)
end
function Service:remove(player)
    self.generations[player], self.effects[player], self.waves[player], self.last[player] = nil, nil, nil, nil
end
function Service:request(player, action, key)
    local now = os.clock()
    if now < (self.last[player] or 0) or self.busy[player] then return false end
    self.last[player] = now + 1
    if action == "Open" then
        self.rt.telemetry:emit(player, "ShopOpen")
        local id = self.userId(player)
        if self.policy:enabled() and self.policy.ready(id) and now >= (self.refreshAt[player] or 0) then
            self.refreshAt[player], self.busy[player] = now + 15, true
            local generation = self.generations[player]
            task.spawn(function()
                self.policy:owns(id)
                local p = self.store:mutate(id, {kind = "Read"})
                if self.generations[player] == generation then self.policy:adopt(id, p) end
                self.busy[player] = nil
            end)
        end
        return true
    end
    if not self:socialPhase() then return false end
    if action == "Wave" then
        if now < (self.waves[player] or 0) + 8 then return false end
        self.waves[player] = now; return true
    end
    local id = self.userId(player)
    if not self.policy:enabled() or not self.policy.ready(id) then return false end
    self.busy[player] = true
    local generation = self.generations[player]
    local ok = pcall(function()
        if action == "Prompt" then
            local allowed = self.policy:offer(id, key, Catalog)
            if allowed and self.generations[player] == generation and self:socialPhase() then
                self.last[player] = os.clock() + 10
                local item = Catalog[key]
                self.rt.telemetry:emit(player, "Offer")
                self.market:prompt(player, self.settings[item.setting], item.kind)
            end
        elseif action == "Style" and type(key) == "boolean" then
            if key and self.policy:owns(id) ~= true then return end
            local p = self.store:mutate(id, {kind = "Style", selected = key})
            if p then self.policy:adopt(id, p) end
        elseif action == "Effect" then
            local p = self.store:mutate(id, {kind = "Use", id = Http:GenerateGUID(false), at = os.time()})
            if p then self.policy:adopt(id, p) end
        end
    end)
    self.busy[player] = nil
    return ok
end
function Service:tick()
    local now = os.clock()
    if not self:socialPhase() then self.effects = {}; return end
    for _, player in ipairs(Players:GetPlayers()) do
        local id = self.userId(player)
        local p = self.policy.accounts[id]
        local effect = self.effects[player]
        if effect and now >= effect.untilTime and not self.busy[player] then
            self.busy[player] = true
            self.effects[player] = nil
            task.spawn(function()
                local latest = self.store:mutate(id, {kind = "Complete", id = effect.id})
                if latest then self.policy:adopt(id, latest) end
                self.busy[player] = nil
            end)
        elseif not effect and not self.busy[player] and p and p.effect and not p.effect.complete and now >= self.nextEffect then
            self.effects[player] = {id = p.effect.id, untilTime = now + 4}
            self.nextEffect = now + 10 -- one nearby visual per server; never in Active
        end
    end
end
function Service:snapshot(player)
    local id = self.userId(player)
    local p = self.policy.accounts[id]
    local enabled = self.policy:enabled()
    return {enabled = enabled, ready = enabled and self.policy.ready(id) and p ~= nil,
        supporter = self.policy.ownership[id] == true, selected = p and p.showSupporter or false,
        charges = p and p.credits or 0, pendingEffect = p and p.effect and not p.effect.complete or false,
        offers = {Supporter = {id = if enabled and not self.injected then self.settings.passId else 0, kind = "Pass"},
            Celebration = {id = if enabled and not self.injected then self.settings.productId else 0, kind = "Product"}}}
end
function Service:public()
    if not self:socialPhase() then return {} end
    local result = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local entry = self.rt.profiles:entry(player)
        local data = entry and entry.profile
        local title, card = "", "Default"
        if data then
            local item = Progression.items[data.equipped.Title]
            if item and data.inventory[data.equipped.Title] then title = item.name end
            if data.equipped.Card == "TealCard" or data.equipped.Card == "AmberCard" then card = data.equipped.Card end
        end
        local id = self.userId(player)
        local p = self.policy.accounts[id]
        if self.policy.ownership[id] == true and p and p.showSupporter then title, card = "Supporter", "Supporter" end
        table.insert(result, {id = player.UserId, name = player.DisplayName, title = title, card = card,
            effect = if self.effects[player] then "Celebration" elseif os.clock() < (self.waves[player] or -10) + 3 then "Wave" else nil})
    end
    return result
end
return Service
