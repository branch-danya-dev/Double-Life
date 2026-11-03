-- Optional focused continuation after Integration's SUITE PASS. Actual production
-- scene/actors, physical client and Humanoid routes; no body teleports or new walls.
local Motion={}
function Motion.run()
    assert(game:GetService('RunService'):IsStudio(),'Studio only')
    local rt=require(game.ServerScriptService.DoubleLifeServer.Game).get()
    local players=game:GetService('Players'):GetPlayers(); assert(#players==2)
    local driver=game.ReplicatedStorage.M6TestDriver
    local view=game.ReplicatedStorage.M112ContextView
    local function call(p,c) return driver:InvokeClient(p,c) end
    local function untilReady(f,seconds)
        local deadline=os.clock()+seconds
        repeat if f() then return end; task.wait(0.1) until os.clock()>deadline
        error('M112 motion timeout')
    end
    for _,p in ipairs(players) do call(p,{kind='Queue',action='Register'}) end
    untilReady(function() return rt.rounds.policy.phase=='Active' and rt.mimics:count('Match')==6 end,120)
    untilReady(function()
        for _,a in pairs(rt.mimics.values) do a.next=math.huge end
        return rt.mimics.busy==0 and not rt.mimics.creating
    end,70)
    local hold=game:GetService('RunService').Heartbeat:Connect(function()
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
    local first=players[1]
    call(first,{kind='Walk',position=Vector3.new(0,21.5,24)})
    a.working=true; rt.mimics.busy+=1
    local function walk(point)
        return a.mover:move(point,rt.scope:now()+55,function() return not rt.scope.alive end)
    end
    local ok=walk(Vector3.new(-18,21.5,24)); assert(ok,'physical route to promenade')
    call(first,{kind='Manual'})
    print('M112 MOTION CAPTURE READY: promenade, stationary real Player; continue to start six physical crossings')
    view:InvokeClient(first,{model=a.mover.model,label='PROMENADE / stationary Player / physical crossing',center=Vector3.new(0,23,24)})
    print('M112 MOTION START IN 25 SECONDS: camera CFrame.lookAt(Vector3.new(0,27,30),Vector3.new(0,22,24))')
    task.wait(25)
    local result={samples=0,overlaps=0,minDistance=100,arrivals=0,detoursBefore=rt.mimics.crowd.metrics.detours}
    local monitor=game:GetService('RunService').Heartbeat:Connect(function()
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
    monitor:Disconnect(); a.working=false; rt.mimics.busy-=1
    result.detours=rt.mimics.crowd.metrics.detours-result.detoursBefore
    print('M112 MOTION METRICS',game:GetService('HttpService'):JSONEncode(result))
    assert(result.overlaps==0 and result.arrivals==6 and result.detours>0,'physical human avoidance')
    hold:Disconnect()
    for _,v in pairs(rt.mimics.values) do v.next=0 end
    print('M112 MOTION PASS: six crossings, no stationary-human body intersections')
end
return Motion
