assert(game:GetService("RunService"):IsStudio(),"Studio only")
local modules=game.ServerScriptService.DoubleLifeServer
local rt=require(modules.Game).start({prologue=false,adapter=require(script.Parent.MemoryStore).new(require(modules.ProfileSchema).copy)})
assert(rt.profiles.adapter.mode=="FakeMemory","review must use isolated memory")
task.spawn(function()
    local player=game.Players:GetPlayers()[1] or game.Players.PlayerAdded:Wait()
    local deadline=os.clock()+15
    repeat task.wait(0.25) until rt.profiles:snapshot(player).status=="Ready" or os.clock()>deadline
    assert(rt.profiles:snapshot(player).status=="Ready","review profile must load in memory")
    print("M7 REVIEW PASS isolated memory profile Ready")
end)
local tick=rt.rounds.policy.tick
rt.rounds.policy.tick=function(self,dt) return tick(self,dt,0) end
local event=Instance.new("RemoteEvent"); event.Name,event.Parent="M7Review",game.ReplicatedStorage
local dark=false
event.OnServerEvent:Connect(function(_,action)
    if action=="Blackout" then dark=not dark; rt.events:setBlackout(dark); print("M7 REVIEW blackout",dark) end
end)
local lighting=game:GetService("Lighting")
local normal=rt.events.scene.lamps[1].light.Brightness
rt.events:setBlackout(true)
for _,lamp in ipairs(rt.events.scene.lamps) do assert(math.abs(lamp.light.Brightness-0.1)<0.001,"main lamp blackout safety level") end
for _,p in ipairs(rt.world.temporary:GetChildren()) do
    if p.Name=="SafePathLight" then assert(p:FindFirstChildOfClass("PointLight").Brightness>0,"emergency lights survive") end
end
rt.events:setBlackout(false)
for _,lamp in ipairs(rt.events.scene.lamps) do assert(lamp.light.Brightness==normal,"restore calibrated lamps") end
print("M7 REVIEW PASS calibrated blackout and restoration")
print("M7 REVIEW ready; isolated memory store; Waiting held; camera inspection is not movement evidence")
print("M7 REVIEW lighting",lighting.Brightness,lighting.ExposureCompensation,tostring(lighting.Ambient),rt.events.scene.lamps[1].light.Brightness)
