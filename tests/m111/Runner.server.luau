assert(game:GetService("RunService"):IsStudio(),"Studio-only visual review")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
local modules=game.ServerScriptService.DoubleLifeServer
local Catalog=require(modules.MimicAppearance)
local Rig=require(modules.MimicRig)
local Before=require(modules.BeforeM11Rig)
local rt=require(modules.Game).start({prologue=false,tuning={lobbyDensity=0},adapter=require(script.Parent.MemoryStore).new(require(modules.ProfileSchema).copy)})
local remote=Instance.new("RemoteEvent"); remote.Name,remote.Parent="M111Review",RS
local stage=Instance.new("Folder"); stage.Name,stage.Parent="M111ReviewStage",workspace
local floor=Instance.new("Part"); floor.Anchored=true; floor.Size=Vector3.new(100,1,60); floor.Position=Vector3.new(0,-0.5,300)
floor.Material=Enum.Material.WoodPlanks; floor.Color=Color3.fromRGB(65,47,40); floor.Parent=stage
local wall=Instance.new("Part"); wall.Anchored=true; wall.Size=Vector3.new(100,16,1); wall.Position=Vector3.new(0,7.5,314)
wall.Color=Color3.fromRGB(196,184,160); wall.Material=Enum.Material.Plaster; wall.Parent=stage
local lamp=Instance.new("Part"); lamp.Anchored=true; lamp.Transparency=1; lamp.Position=Vector3.new(0,12,295); lamp.Parent=stage
local light=Instance.new("PointLight"); light.Brightness=0.8; light.Range=60; light.Color=Color3.fromRGB(255,234,208); light.Parent=lamp
local scope=require(modules.SessionClock).new()
local movers={}; local actors={}; local player; local mode="After"; local ids={1,8,11,12,17}; local group=0; local gesture=false; local busy=true
local function check(ok,label) assert(ok,label); print("M111 PASS",label) end
local function status(label) stage:SetAttribute("ReviewStatus",label); print("M111 REVIEW",label) end
local function place(index) return Vector3.new(-19+(index-1)*8,3.3,300) end
Run.Heartbeat:Connect(function(dt)
    scope:advance(dt)
    for _,m in ipairs(movers) do if m.root.Parent then m:animate(os.clock(),gesture,false) end end
end)
local function destroyAll()
    for _,m in ipairs(movers) do if m.destroy then m:destroy() else m.model:Destroy() end end
    table.clear(movers); table.clear(actors)
end
local function make(id,serial,position,before,refresh)
    local deadline=os.clock()+45; local m,name
    repeat
        if before then m,name=Before.new(stage,serial,position,scope)
        else m,name=Rig.new(stage,serial,position,scope,id,refresh) end
        if m then break end
        task.wait(1)
    until os.clock()>deadline
    assert(m,"Avatar unavailable "..id.." "..tostring(name))
    return m
end
local function lineup(profile)
    for i,m in ipairs(movers) do
        m:stop(); m.model:PivotTo(CFrame.new(place(i))*CFrame.Angles(0,if profile then math.pi/2 else 0,0))
    end
    if player.Character then player.Character:PivotTo(CFrame.new(place(6))*CFrame.Angles(0,if profile then math.pi/2 else 0,0)) end
    remote:FireClient(player,"Camera",Vector3.new(1,6,264),Vector3.new(1,3.1,300))
end
local function show()
    destroyAll(); gesture=false
    for i,id in ipairs(ids) do
        local m=make(id,id,place(i),mode=="Before"); table.insert(movers,m); table.insert(actors,m.model)
    end
    lineup(false); status(mode.." · mixed catalogue · 5 mimics + 1 actual Player")
    remote:FireClient(player,"Models",actors)
end
local function verifyAssets()
    local idsToCheck={}
    for _,p in ipairs(Catalog.presets) do
        for _,key in ipairs({"Shirt","Pants","Head"}) do if p[key]>0 then idsToCheck[p[key]]=true end end
        idsToCheck[tonumber(p.HairAccessory)]=true
    end
    idsToCheck[62724852]=true
    for _,body in pairs(Catalog.body) do for _,id in pairs(body) do idsToCheck[id]=true end end
    for _,id in pairs(Catalog.animations) do idsToCheck[id]=true end
    local ordered={}; for id in pairs(idsToCheck) do table.insert(ordered,id) end; table.sort(ordered)
    for _,id in ipairs(ordered) do
        local info=game:GetService("MarketplaceService"):GetProductInfoAsync(id,Enum.InfoType.Asset)
        check(info.Creator.CreatorTargetId==1 or info.Creator.Id==1,"Roblox creator for asset "..id)
        print("M111 ASSET",Http:JSONEncode({id=id,name=info.Name,type=info.AssetTypeId,creator=info.Creator.CreatorTargetId or info.Creator.Id,price=info.PriceInRobux}))
        task.wait(0.3)
    end
end
local function run()
    repeat task.wait(0.1) until #Players:GetPlayers()==1
    player=Players:GetPlayers()[1]
    repeat task.wait(0.1) until player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    task.wait(2); rt.queue:cancel(player)
    status("Checking official asset metadata and all 20 R15 presets")
    verifyAssets()
    -- Cold API failure admits no substitute body at all.
    Rig.configureForTest(true)
    local cold=Rig.new(stage,20,place(1),scope,20)
    check(cold==nil and Rig.metrics.live==0,"cold failure defers without a block rig")
    Rig.configureForTest(false); task.wait(3)
    Rig.configureForTest(false,10)
    local done=0; local initial=Rig.metrics.requests
    for id=1,4 do task.spawn(function()
        local m=Rig.new(stage,id,place(1),scope,id)
        check(m==nil,"slow cold creation defers concurrent caller "..id); done+=1
    end) end
    local deadline=os.clock()+16
    repeat task.wait(0.1) until done==4 or os.clock()>deadline
    check(done==4 and Rig.metrics.requests==initial+1 and Rig.metrics.maxPending==1,"four callers share one bounded engine request")
    check(Rig.metrics.timeouts==1,"slow engine call has an eight-second admission deadline")
    repeat task.wait(0.1) until Rig.metrics.pending==0 or os.clock()>deadline
    check(Rig.templates[1] and Rig.metrics.live==0,"late result fills cache without spawning an orphan")
    Rig.configureForTest(false)
    for id=1,#Catalog.presets do
        local began=os.clock(); local m=make(id,id,place(1),false)
        check(Rig.validate(m.model,id),"R15 clothing joints and accessories preset "..id)
        check(m.motion:ready(),"six animation tracks loaded preset "..id)
        print("M111 RIG",Http:JSONEncode({id=id,seconds=os.clock()-began,parts=#m.model:GetDescendants(),hip=m.humanoid.HipHeight}))
        m:destroy(); task.wait(0.3)
    end
    check(Rig.metrics.live==0 and Rig.metrics.tracks==0,"twenty rigs release every track")
    local description=Rig.description(6)
    player.Character:FindFirstChildOfClass("Humanoid"):ApplyDescriptionAsync(description); description:Destroy()
    player.Character:FindFirstChildOfClass("Humanoid").DisplayName="REAL PLAYER · reference outfit"
    show(); busy=false
    print("M111 CATALOGUE READY",Http:JSONEncode(Rig.metrics))
end
remote.OnServerEvent:Connect(function(p,action)
    if p~=player or busy then return end
    busy=true
    local ok,err=xpcall(function()
        if action=="Before" or action=="After" then mode=action; show()
        elseif action=="Front" or action=="Profile" then gesture=false; lineup(action=="Profile"); status(mode.." · "..action)
        elseif action=="Walk" then
            gesture=false
            for _,m in ipairs(movers) do m.humanoid:MoveTo(m.root.Position+Vector3.new(16,0,0)) end
            status(mode.." · Walk (server Animator)")
        elseif action=="Stop" then for _,m in ipairs(movers) do m:stop() end; gesture=false; status(mode.." · Stop → Idle")
        elseif action=="Wave" then gesture="Wave"; status(mode.." · Wave (server Animator)")
        elseif action=="Next" then
            group=(group+1)%5; ids=if group==0 then {1,8,11,12,17} else {(group-1)*5+1,(group-1)*5+2,(group-1)*5+3,(group-1)*5+4,(group-1)*5+5}; show()
        elseif action=="Failure" then
            mode="After"; Rig.configureForTest(true)
            local m=make(ids[1],ids[1],place(1),false,true)
            check(m.source=="Cache" and Rig.validate(m.model,ids[1]),"real injected API failure uses identical validated R15 cache")
            movers[1]:destroy(); movers[1]=m
            Rig.configureForTest(false); status("API FAILURE · identical cached R15 · no visible replacement")
        end
    end,debug.traceback)
    busy=false
    if not ok then warn("M111 STUDIO FAIL",err) end
end)
local ok,err=xpcall(run,debug.traceback)
if not ok then warn("M111 STUDIO FAIL",err) end
