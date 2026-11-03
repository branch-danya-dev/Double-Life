assert(game:GetService("RunService"):IsStudio(),"Studio only")
local world=workspace:WaitForChild("DoubleLifeMansion")
local modules=game.ServerScriptService:WaitForChild("DoubleLifeServer")
-- Wait for the fixture to build the world before observing the already-started runtime.
local rt=require(modules.Game).start()
assert(rt.profiles.adapter.mode=="FakeMemory","M7 fixture must use isolated memory")
print("M7 PASS isolated memory adapter")
local budget=require(modules.MansionArtPlan).budgets
local static=world:WaitForChild("StaticGeometry")
local art=static:WaitForChild("ArtDeco")
local function check(ok,msg) assert(ok,msg); print("M7 PASS",msg) end
local function audit(round)
    task.wait(2)
    if not round.Parent then return end
    local count,lights=0,0
    for _,p in ipairs(art:GetDescendants()) do
        if p:IsA("BasePart") then count+=1; assert(not p.CanCollide and not p.CanQuery and not p.CanTouch,"decoration collision") end
    end
    check(count<=budget.staticParts,"art budget / collision exclusion "..count)
    for _,d in ipairs(world:GetDescendants()) do if d:IsA("Light") then lights+=1 end end
    check(lights==budget.lights,"exactly 22 lights after reset")
    check(world.StaticGeometry==static and static.ArtDeco==art,"static art survives round reset")
    local decorated=0
    for _,d in ipairs(round:GetDescendants()) do
        if d:IsA("BasePart") and d.Parent:IsA("BasePart") then
            decorated+=1; assert(not d.CanQuery and not d.CanCollide,"interactive detail cannot occlude prompt")
        end
    end
    check(decorated>35 and decorated<=budget.roundParts,"interactive art budget "..decorated)
    local l=game:GetService("Lighting")
    check(l.ClockTime>18 and l:FindFirstChild("MansionHaze") and l:FindFirstChild("MansionGrade"),"evening lighting / atmospheric grade")
    local rigs=0
    for _,npc in ipairs(round.NPCs:GetChildren()) do
        if npc:GetAttribute("MansionNPC") then
            rigs+=1
            check(npc.Humanoid.HipHeight==0 and npc.HumanoidRootPart:FindFirstChild("Left LegJoint")~=nil,"animated rig retains R6 ground contact")
        end
    end
    check(rigs==budget.animatedNPCs,"bounded animated NPCs")
end
world.ChildAdded:Connect(function(child) if child.Name=="Round" then task.spawn(audit,child) end end)
audit(world:WaitForChild("Round"))
