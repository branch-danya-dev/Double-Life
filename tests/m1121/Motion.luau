-- Optional focused continuation after Integration's SUITE PASS. Actual production
-- scene/actors, physical client and Humanoid routes; no body teleports or new walls.
local Approach=require(script.Parent.Approach)
local Probe=require(script.Parent.MoveProbe)
local Motion={}
function Motion.run()
    assert(game:GetService('RunService'):IsStudio(),'Studio only')
    local rt=require(game.ServerScriptService.DoubleLifeServer.Game).get()
    local players=game:GetService('Players'):GetPlayers(); assert(#players==2)
    local driver=game.ReplicatedStorage.M6TestDriver
    local view=game.ReplicatedStorage.M112ContextView
    local connections={}; local controlled
    local function connect(f)
        local c=game:GetService('RunService').Heartbeat:Connect(f)
        table.insert(connections,c); return c
    end
    local function body()
    local function call(p,c) return driver:InvokeClient(p,c) end
    local function untilReady(f,seconds)
        local deadline=os.clock()+seconds
        repeat if f() then return end; task.wait(0.1) until os.clock()>deadline
        error('M112 motion timeout')
    end
    -- Gather at an existing lobby interest point by walking, using production
    -- slots and paths. This is an ordinary context, not a posed avatar catalogue.
    untilReady(function() return rt.mimics:count('Lobby')==4 and not rt.mimics.creating end,60)
    untilReady(function()
        for _,a in pairs(rt.mimics.values) do a.next=math.huge end
        return rt.mimics.busy==0
    end,70)
    local gathering=connect(function()
        for _,a in pairs(rt.mimics.values) do a.next=math.huge end
    end)
    local first=players[1]; local point=rt.lobby.spots[2]
    call(first,{kind='Walk',position=point})
    local sample
    for _,a in pairs(rt.mimics.values) do if a.context=='Lobby' then
        sample=a; controlled=a; a.working=true; rt.mimics.busy+=1
        local function gathered()
            return a.mover:near(point,10) and rt.mimics.crowd:free(a.mover.root.Position,a.mover,3.2)
                and rt.mimics.crowd:floor(a.mover.root.Position)
        end
        for attempt=1,3 do
            if gathered() then break end
            local target=rt.mimics.crowd:slot(point,a.mover,a.preset+(attempt-1)*3)
            local reached=target and a.mover:move(target,a.mover.scope:now()+30,function() return false end)
            rt.mimics.crowd:release(a.mover)
            print('M112 GATHER ATTEMPT',a.actor.name,attempt,reached,a.mover.root.Position,target)
        end
        a.mover:stop(); a.working=false; rt.mimics.busy-=1; controlled=nil
        -- A safe neighbouring stop is the contract, not a particular pixel on
        -- the far side of the now occupied object. Never force a crossing.
        assert(gathered(),'physical lobby gathering in free supported interest area'); a.mover:lookAt(point)
    end end
    call(first,{kind='Manual'})
    print('M112 GROUP CAPTURE READY: actual Player and four AI at lobby interest object')
    view:InvokeClient(first,{model=sample.mover.model,label='LOBBY / real Player + four distinct guests',center=point+Vector3.new(0,1,0),wide=true})
    gathering:Disconnect()
    for _,a in pairs(rt.mimics.values) do a.next=0 end
    for _,p in ipairs(players) do call(p,{kind='Queue',action='Register'}) end
    untilReady(function() return rt.rounds.policy.phase=='Active' and rt.mimics:count('Match')==6 end,120)
    untilReady(function()
        for _,a in pairs(rt.mimics.values) do a.next=math.huge end
        return rt.mimics.busy==0 and not rt.mimics.creating
    end,70)
    local hold=connect(function()
        for _,a in pairs(rt.mimics.values) do a.next=math.huge end
    end)
    local names,used={},{}
    for _,v in pairs(rt.mimics.values) do
        names[v.actor.name]=true; used[v.appearanceContext]=used[v.appearanceContext] or {}; used[v.appearanceContext][v.preset]=true
    end
    for name in pairs(rt.mimics.names) do assert(names[name],'orphan nickname reservation') end
    for context,ids in pairs(rt.mimics.used) do for id in pairs(ids) do assert(used[context] and used[context][id],'orphan appearance reservation') end end
    assert(next(rt.mimics.crowd.slots)==nil,'idle slots released after previous resets and churn')
    print('M112 RESERVATIONS PASS: no orphan name, appearance or movement slot after churn')
    local a
    for _,v in pairs(rt.mimics.values) do if v.context=='Match' then a=v; break end end
    call(first,{kind='Walk',position=Vector3.new(0,21.5,24)})
    controlled=a; a.working=true; rt.mimics.busy+=1
    local function walk(point)
        return a.mover:move(point,rt.scope:now()+55,function() return not rt.scope.alive end)
    end
    -- Reproduce the original fixed-target approach with per-waypoint diagnostics.
    local fixed=Vector3.new(-18,21.5,24)
    local raw=Probe.run(a.mover,rt.mimics.crowd,fixed,55)
    print('M1121 LEGACY APPROACH',raw)
    local ok=Approach.run(a.mover,rt.mimics.crowd,fixed,a.preset,function(attempt,target,reached)
        print('M1121 RESERVED APPROACH',attempt,target,reached)
    end)
    assert(ok,'reserved physical approach to promenade')
    -- Deterministic reproduction of the missing precondition: a fixed endpoint
    -- occupied by the standing player must yield, not clip through that player.
    local occupied=first.Character.HumanoidRootPart.Position
    local refused,diagnostic=Probe.run(a.mover,rt.mimics.crowd,occupied,12)
    assert(not refused and diagnostic.failure=='OccupiedFixedTarget','occupied fixed endpoint is safely refused')
    assert(Approach.run(a.mover,rt.mimics.crowd,fixed,a.preset),'physical recovery from occupied endpoint')
    print('M1121 APPROACH REGRESSION PASS: occupied fixed pixel refused; reserved approach succeeds')
    call(first,{kind='Manual'})
    print('M112 MOTION CAPTURE READY: promenade, stationary real Player; continue to start six physical crossings')
    view:InvokeClient(first,{model=a.mover.model,label='PROMENADE / stationary Player / physical crossing',center=Vector3.new(0,23,24),
        camera=CFrame.lookAt(Vector3.new(0,27,30),Vector3.new(0,22,24))})
    print('M112 MOTION START IN 5 SECONDS')
    task.wait(5)
    local result={samples=0,overlaps=0,minDistance=100,arrivals=0,detoursBefore=rt.mimics.crowd.metrics.detours}
    local monitor=connect(function()
        local p=first.Character.HumanoidRootPart.Position; local q=a.mover.root.Position
        local distance=Vector2.new(p.X-q.X,p.Z-q.Z).Magnitude
        if math.abs(p.Y-q.Y)<4 then
            result.samples+=1; result.minDistance=math.min(result.minDistance,distance)
            if distance<2 then result.overlaps+=1 end
        end
    end)
    for i=1,6 do
        if walk(Vector3.new(if i%2==1 then 18 else -18,21.5,24)) then result.arrivals+=1 end
        a.mover:stop(); task.wait(2)
    end
    monitor:Disconnect(); a.working=false; rt.mimics.busy-=1; controlled=nil
    result.detours=rt.mimics.crowd.metrics.detours-result.detoursBefore
    print('M112 MOTION METRICS',game:GetService('HttpService'):JSONEncode(result))
    assert(result.overlaps==0 and result.arrivals==6 and result.detours>0,'physical human avoidance')
    hold:Disconnect()
    for _,v in pairs(rt.mimics.values) do v.next=0 end
    print('M112 MOTION PASS: six crossings, no stationary-human body intersections')
    print('M1121 WIDE PASS: six physical crossings with full-scene camera')
    end
    local ok,err=xpcall(body,debug.traceback)
    for _,c in ipairs(connections) do c:Disconnect() end
    if controlled then
        controlled.mover:stop(); rt.mimics.crowd:release(controlled.mover)
        controlled.working=false; rt.mimics.busy-=1
    end
    for _,v in pairs(rt.mimics.values) do v.next=0 end
    assert(ok,err)
end
return Motion
