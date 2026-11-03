-- Screen-space nameplate spacing; human names keep priority. No fake player list.
local Players=game:GetService('Players')
local states={}; local elapsed=0
local function watch(v)
    if not v:IsA('BillboardGui') or v.Name~='MimicNameplate' or states[v] then return end
    local connection
    connection=v.Destroying:Connect(function() states[v]=nil; connection:Disconnect() end)
    states[v]=connection
end
workspace.DescendantAdded:Connect(watch)
for _,v in ipairs(workspace:GetDescendants()) do watch(v) end
game:GetService('RunService').Heartbeat:Connect(function(dt)
    elapsed+=dt; if elapsed<0.1 then return end; elapsed=0
    local camera=workspace.CurrentCamera; if not camera then return end
    local boxes,candidates={},{}
    local function project(head)
        local p,visible=camera:WorldToViewportPoint(head.Position+Vector3.new(0,2.5,0))
        return p,visible and (head.Position-camera.CFrame.Position).Magnitude<35
    end
    for _,p in ipairs(Players:GetPlayers()) do
        local head=p.Character and p.Character:FindFirstChild('Head')
        if head and p~=Players.LocalPlayer then local point,visible=project(head); if visible then table.insert(boxes,point) end end
    end
    for sign in pairs(states) do
        local head=sign.Parent; local model=head and head.Parent
        if head and model and model:GetAttribute('MimicClientReady') then
            local point,visible=project(head)
            sign.Enabled=false
            if visible then table.insert(candidates,{sign=sign,point=point,name=model.Name}) end
        end
    end
    table.sort(candidates,function(a,b) if math.abs(a.point.Z-b.point.Z)<0.1 then return a.name<b.name end; return a.point.Z<b.point.Z end)
    for _,c in ipairs(candidates) do
        local clear=true
        for _,p in ipairs(boxes) do if math.abs(p.X-c.point.X)<140 and math.abs(p.Y-c.point.Y)<34 then clear=false; break end end
        if clear then c.sign.Enabled=true; table.insert(boxes,c.point) end
    end
end)
