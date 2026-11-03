-- Local fixture only; never shipped. Explicit failure mode and bounded trace.
local S={}; S.__index=S
function S.new(now) return setmetatable({now=now,events={},failed=false,dropped=0},S) end
function S:send(p,event,value,fields)
    if self.failed then error("Synthetic sink failure") end
    if #self.events>=2048 then self.dropped+=1; return false end
    table.insert(self.events,{player=p,event=event,value=value,fields=fields and table.clone(fields),at=self.now()})
    return true
end
function S:find(event,p)
    local out={}; for _,e in ipairs(self.events) do if e.event==event and (not p or e.player==p) then table.insert(out,e) end end; return out
end
return S
