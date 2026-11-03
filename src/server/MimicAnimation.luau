local Catalog=require(script.Parent.MimicAppearance)
local Motion={}; Motion.__index=Motion
function Motion.new(model,serial)
    local humanoid=model:FindFirstChildOfClass("Humanoid")
    local animator=humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
    animator.Parent=humanoid -- Server-created, server-played; no Animate LocalScript.
    local self=setmetatable({animator=animator,tracks={},assets={},mode=nil,paused=false,gesture=false,serial=serial,alive=true},Motion)
    local ids=table.clone(Catalog.animations)
    ids.Idle=if serial%3==0 then ids.IdleLook else ids.Idle; ids.IdleLook=nil
    for name,id in pairs(ids) do
        local asset=Instance.new("Animation"); asset.AnimationId="rbxassetid://"..id
        local ok,track=pcall(function() return animator:LoadAnimation(asset) end)
        if not ok then asset:Destroy(); self:destroy(); return nil,"AnimationLoad" end
        track.Looped=name=="Idle" or name=="Walk" or name=="Run"
        track.Priority=if name=="Idle" then Enum.AnimationPriority.Idle elseif track.Looped then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Action
        self.tracks[name],self.assets[name]=track,asset
    end
    return self
end
function Motion:ready()
    for _,track in pairs(self.tracks) do if track.Length<=0 then return false end end
    return true
end
-- One admission-time recovery for optional gestures/idle variation. Locomotion
-- is required: never replace a missing walk with a sliding neutral pose.
function Motion:fallback()
    if self.recovered then return end
    self.recovered=true
    for _,name in ipairs({"Idle","Wave","Point","Cheer"}) do
        local old=self.tracks[name]
        if old.Length<=0 then
            local asset=Instance.new("Animation"); asset.AnimationId="rbxassetid://"..Catalog.animations.Idle
            local ok,track=pcall(function() return self.animator:LoadAnimation(asset) end)
            if ok then
                old:Stop(0); old:Destroy(); self.assets[name]:Destroy()
                track.Looped=name=="Idle"; track.Priority=Enum.AnimationPriority.Idle
                self.tracks[name],self.assets[name]=track,asset
            else asset:Destroy() end
        end
    end
end
function Motion:update(speed,gesture,paused)
    if not self.alive then return end
    if paused then
        for _,t in pairs(self.tracks) do if t.IsPlaying then t:AdjustSpeed(0) end end
        self.paused=true; return
    elseif self.paused then
        for _,t in pairs(self.tracks) do if t.IsPlaying then t:AdjustSpeed(1) end end
        self.paused=false
    end
    local moving=speed>(if self.mode=="Walk" or self.mode=="Run" then 0.35 else 0.8)
    local mode=if moving then (if speed>=13 then "Run" else "Walk") else "Idle"
    if mode~=self.mode then
        if self.mode then self.tracks[self.mode]:Stop(0.2) end
        self.tracks[mode]:Play(0.2); self.mode=mode
        if moving then for _,k in ipairs({"Wave","Point","Cheer"}) do self.tracks[k]:Stop(0.15) end end
    end
    if moving then self.tracks[mode]:AdjustSpeed(math.clamp(speed/(if mode=="Run" then 16 else 8),0.3,2)) end
    if gesture and not self.gesture and not moving then
        local name=if gesture=="Point" or gesture=="Cheer" then gesture else "Wave"
        self.tracks[name]:Play(0.2)
    end
    self.gesture=gesture or false
end
function Motion:destroy()
    if not self.alive then return end
    self.alive=false
    for _,track in pairs(self.tracks) do track:Stop(0); track:Destroy() end
    for _,asset in pairs(self.assets) do asset:Destroy() end
    table.clear(self.tracks); table.clear(self.assets)
end
return Motion
