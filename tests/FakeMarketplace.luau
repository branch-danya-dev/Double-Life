-- Test-only; no platform prompt or purchase can be made through this adapter.
local Fake = {}
function Fake.new()
    local self = {ownership = {}, failure = false, forSale = true, prompts = {}, lookups = 0}
    function self:owns(id, _pass)
        self.lookups += 1
        if self.failure then error("ownership API unavailable") end
        return self.ownership[id] == true
    end
    function self:info(_id, _kind)
        if self.failure then error("product API unavailable") end
        return {IsForSale = self.forSale} -- no fake Robux price
    end
    function self:prompt(player, id, kind) table.insert(self.prompts, {player = player, id = id, kind = kind}) end
    function self:bind(receipt, passFinished) self.receipt, self.passFinished = receipt, passFinished end
    return self
end
return Fake
