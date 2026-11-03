local Catalog=require("../src/server/MimicAppearance")
local Suite={}
function Suite.run(loadMotion)
    local n=0; local function check(ok,msg) assert(ok,msg); n+=1 end
    local loads,assets,tracks=0,{},{}
    local failAt
    local animator={}
    function animator:LoadAnimation(asset)
        loads+=1; if loads==failAt then error("simulated load failure") end
        local track={Length=2,IsPlaying=false,plays=0,speed=1,asset=asset}
        function track:Play() self.IsPlaying=true; self.plays+=1 end
        function track:Stop() self.IsPlaying=false end
        function track:AdjustSpeed(v) self.speed=v end
        function track:Destroy() self.destroyed=true end
        table.insert(tracks,track); return track
    end
    local humanoid={FindFirstChildOfClass=function() return animator end}
    local model={FindFirstChildOfClass=function() return humanoid end}
    local engine={new=function(kind)
        assert(kind=="Animation")
        local asset={Destroy=function(self) self.destroyed=true end}; table.insert(assets,asset); return asset
    end}
    local env=setmetatable({Instance=engine,Enum={AnimationPriority={Idle="Idle",Movement="Movement",Action="Action"}},
        script={Parent={MimicAppearance="catalog"}},require=function() return Catalog end},{__index=getfenv()})
    local Motion=loadMotion(env)
    local m=Motion.new(model,1)
    check(m~=nil and loads==6 and m:ready(),"six cached tracks per rig")
    m:update(0,false,false); check(m.mode=="Idle" and m.tracks.Idle.IsPlaying,"server idle starts")
    for _=1,100 do m:update(0,false,false) end
    check(loads==6 and m.tracks.Idle.plays==1,"idle ticks never reload or restart tracks")
    m:update(0.6,false,false); check(m.mode=="Idle","movement hysteresis at rest")
    m:update(4,false,false); check(m.mode=="Walk" and m.tracks.Walk.speed==0.5,"walk follows actual speed")
    check(not m.tracks.Idle.IsPlaying,"previous base track crossfades out")
    m:update(0.5,false,false); check(m.mode=="Walk","walking hysteresis avoids jitter")
    m:update(16,false,false); check(m.mode=="Run" and m.tracks.Run.speed==1,"run uses actual velocity")
    m:update(0,false,false); check(m.mode=="Idle" and not m.tracks.Run.IsPlaying,"stop restores idle")
    m:update(0,"Wave",false); m:update(0,"Wave",false)
    check(m.tracks.Wave.plays==1,"greeting edge plays once")
    m:update(0,false,false); m:update(0,"Point",false)
    check(m.tracks.Point.plays==1,"object observation gesture")
    m:update(0,"Point",true); check(m.paused and m.tracks.Idle.speed==0 and m.tracks.Point.speed==0,"Council freezes every active track")
    m:update(0,false,false); check(not m.paused and m.tracks.Idle.speed==1,"Council resume restores playback")
    m:update(8,"Wave",false); check(not m.tracks.Point.IsPlaying and not m.tracks.Wave.IsPlaying,"movement cancels gestures")
    local oldWave=m.tracks.Wave; oldWave.Length=0
    m:fallback()
    check(oldWave.destroyed and m:ready(),"unavailable optional gesture recovers to native neutral animation")
    check(m.tracks.Wave.asset.AnimationId=="rbxassetid://"..Catalog.animations.Idle,"fallback uses verified standard idle")
    local recoveredLoads=loads; m:fallback()
    check(loads==recoveredLoads,"fallback loads at most once per admission")
    m.tracks.Walk.Length=0; check(not m:ready(),"unloaded animation cannot admit a visible rig")
    m:destroy(); m:destroy()
    for _,track in ipairs(tracks) do check(track.destroyed and not track.IsPlaying,"despawn destroys tracks") end
    for _,asset in ipairs(assets) do check(asset.destroyed,"despawn destroys animation instances") end
    local old=loads; m:update(12,true,false); check(loads==old,"destroyed controller cannot restart")
    failAt=loads+3; local failed=Motion.new(model,2)
    check(failed==nil,"load failure returns without a partial controller")
    for _,track in ipairs(tracks) do check(track.destroyed,"load failure cleans already loaded tracks") end
    for _,asset in ipairs(assets) do check(asset.destroyed,"load failure cleans every asset instance") end
    print("M11.1 actual Animator controller:",n,"assertions PASS")
end
return Suite
