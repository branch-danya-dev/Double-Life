local Suite={}
function Suite.run(loadScript)
    local n=0; local function check(ok,label) assert(ok,label); n+=1 end
    local now=0; local tasks={}; local loads=0
    local function signal()
        local s={connections={}}
        function s:Connect(f)
            local c={f=f,alive=true}; function c:Disconnect() self.alive=false end
            table.insert(self.connections,c); return c
        end
        function s:fire(v) for _,c in ipairs(self.connections) do if c.alive then c.f(v) end end end
        return s
    end
    local world={DescendantAdded=signal(),models={}}
    function world:GetDescendants() return self.models end
    local heartbeat=signal()
    local function model()
        local m={attrs={MimicName="Fiction",MimicReady=false},children={},DescendantAdded=signal(),Destroying=signal(),Parent=world}
        function m:IsA(k) return k=="Model" end
        function m:GetAttribute(k) return self.attrs[k] end
        function m:SetAttribute(k,v) self.attrs[k]=v end
        function m:GetChildren() return self.children end
        m.GetDescendants=m.GetChildren
        function m:IsDescendantOf(w) return self.Parent==w end
        function m:FindFirstChild(name) for _,v in ipairs(self.children) do if v.Name==name then return v end end end
        function m:FindFirstChildOfClass(kind) for _,v in ipairs(self.children) do if v:IsA(kind) then return v end end end
        for _,name in ipairs({"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot","HumanoidRootPart","Shirt","Pants","Hair","Label"}) do
            local kind=if name=="Shirt" or name=="Pants" then name elseif name=="Hair" then "Accessory" elseif name=="Label" then "BillboardGui" else "BasePart"
            table.insert(m.children,{Name=name,Parent=m,IsA=function(_,k) return k==kind end,FindFirstChild=function() return {} end})
        end
        table.insert(world.models,m); return m
    end
    local a,b,c=model(),model(),model()
    local legacy=model(); legacy.attrs.MimicReady=nil
    local content={PreloadAsync=function(_,models,callback)
        loads+=1
        local success=coroutine.yield(models[1])
        callback("asset",if success then "Success" else "Failure")
    end}
    local env=setmetatable({workspace=world,game={GetService=function(_,k) return if k=="ContentProvider" then content else {Heartbeat=heartbeat} end},
        os={clock=function() return now end},Enum={AssetFetchStatus={Success="Success"}},task={spawn=function(f)
            local co=coroutine.create(f); local ok,m=coroutine.resume(co); assert(ok,m); table.insert(tasks,{co=co,model=m})
        end}},{__index=getfenv()})
    loadScript(env)
    check(legacy.children[1].LocalTransparencyModifier==nil,"legacy NPC and before-reference are untouched")
    local function frame(dt) now+=dt; heartbeat:fire(dt) end
    for _,m in ipairs({a,b,c}) do check(m.children[1].LocalTransparencyModifier==1,"hidden immediately on replication") end
    frame(1); check(loads==0,"partial server rig never preloads/reveals")
    for _,m in ipairs({a,b,c}) do m.attrs.MimicReady=true end
    frame(1); check(loads==2,"two outstanding client preloads maximum")
    for _=1,100 do frame(0.1) end; check(loads==2,"stalled API cannot start another request")
    local first=tasks[1]; check(coroutine.resume(first.co,true),"first content load returns")
    frame(0.1); check(first.model.children[1].LocalTransparencyModifier>0 and first.model.children[1].LocalTransparencyModifier<1,"smooth reveal after content")
    frame(0.4); check(first.model.attrs.MimicClientReady and first.model.children[1].LocalTransparencyModifier==0,"complete appearance becomes visible")
    check(loads==3,"third request starts only after slot released")
    local second=tasks[2]; second.model.Destroying:fire(); second.model.Parent=nil
    check(not second.model.DescendantAdded.connections[1].alive,"despawn disconnects descendant observer")
    check(coroutine.resume(second.co,true),"late completion after destruction is harmless")
    local third=tasks[3]; check(coroutine.resume(third.co,false),"failure returned")
    frame(1); check(loads==3 and third.model.children[1].LocalTransparencyModifier==1,"failed content stays hidden during backoff")
    frame(5); check(loads==4,"bounded retry after backoff")
    check(coroutine.resume(tasks[4].co,false),"second failure")
    frame(11); check(loads==5,"third attempt permitted")
    check(coroutine.resume(tasks[5].co,false),"third failure")
    frame(100); check(loads==5 and not third.model.attrs.MimicClientReady,"repeated failures stop at three requests without broken avatar")
    print("M11.1 actual client appearance gate:",n,"assertions PASS")
end
return Suite
