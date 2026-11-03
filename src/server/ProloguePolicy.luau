local P={}; P.__index=P
function P.new(now,content)
    return setmetatable({now=now,content=content,state="Active",step=1,started=now(),generation=1,completed={},deferred=false},P)
end
function P:act(key)
    local expected=self.content.steps[self.step]
    if self.state~="Active" or not expected or expected.key~=key or self.completed[key] then return false end
    self.completed[key]=true; self.firstAction=self.firstAction or self.now()
    self.step+=1
    if self.step>#self.content.steps then self.state="Completed" end
    return true
end
function P:leave(kind)
    if self.state~="Active" then return false end
    self.state=if kind=="Skip" then "Skipped" else "Suspended"
    self.deferred=false; self.generation+=1; return true
end
function P:resume()
    if self.state=="Active" then return false end
    if self.state=="Completed" or self.state=="Skipped" then self.step,self.completed=1,{} end
    self.state,self.started,self.generation="Active",self.now(),self.generation+1
    return true
end
function P:resetCharacter()
    if self.state~="Active" then return false end
    self.step=self.content.chapterStart(self.step)
    for index=self.step,#self.content.steps do self.completed[self.content.steps[index].key]=nil end
    self.generation+=1; return true
end
function P:tick()
    if self.state=="Active" and self.now()-self.started>=self.content.maximumSeconds then self:leave("Timeout"); return "Timeout" end
    return nil
end
return P
