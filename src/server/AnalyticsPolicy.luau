local Policy = {}
Policy.__index = Policy
Policy.events = {Join = true, SessionSeconds = true, FirstMatch = true, RepeatMatch = true, MatchStarted = true,
    Waiting = true, Countdown = true, Active = true, Council = true, Results = true, Win = true, Loss = true,
    ShopOpen = true, Offer = true, Purchase = true}
function Policy.new(send, now)
    return setmetatable({send = send, now = now, last = {}}, Policy)
end
function Policy:emit(player, event, value)
    if not Policy.events[event] or (value ~= nil and (type(value) ~= "number" or value ~= value or value < 0 or value > 86400)) then return false end
    local state = self.last[player] or {}
    self.last[player] = state
    local now = self.now()
    local delay = if event == "ShopOpen" or event == "Offer" then 15 else 1
    if now < (state[event] or 0) then return false end
    state[event] = now + delay
    pcall(self.send, player, event, value or 1)
    return true
end
return Policy
