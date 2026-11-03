-- Admission/backoff is independent of engine yields. A timed-out call keeps its
-- one outstanding slot until it really returns; no retry storm behind a timeout.
local P={}; P.__index=P
function P.new(now) return setmetatable({now=now,pending=nil,nextAt=0,failures=0,serial=0},P) end
function P:begin(key)
    if self.pending or self.now()<self.nextAt then return nil end
    self.serial+=1; self.pending={id=self.serial,key=key,at=self.now()}; return self.pending
end
function P:expired(token) return self.pending==token and self.now()-token.at>=8 end
function P:finish(token,success)
    if self.pending~=token then return false end
    self.pending=nil
    self.failures=if success then 0 else math.min(self.failures+1,4)
    self.nextAt=self.now()+(if success then 0.2 else math.min(30,2^self.failures))
    return true
end
return P
