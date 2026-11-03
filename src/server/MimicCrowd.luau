local Policy=require(script.Parent.MimicCrowdPolicy)
local Crowd={}; Crowd.__index=Crowd
function Crowd.new()
    return setmetatable({people={},slots={},metrics={waits=0,detours=0,occupied=0,deferred=0,maxPeople=0}},Crowd)
end
function Crowd:update(players,actors,extras)
    local people,models={},{}
    local function add(key,model)
        if #people>=64 or not model then return end
        local root=model:FindFirstChild('HumanoidRootPart')
        if root then table.insert(people,{key=key,position=root.Position}); table.insert(models,model) end
    end
    for _,p in ipairs(players) do add(p,p.Character) end
    for _,a in pairs(actors) do add(a.mover,a.mover.model) end
    for _,m in ipairs(extras) do if m then add(m,m.model) end end
    self.people=people; self.metrics.maxPeople=math.max(self.metrics.maxPeople,#people)
    local filter=RaycastParams.new(); filter.FilterType=Enum.RaycastFilterType.Exclude
    filter.FilterDescendantsInstances=models; filter.RespectCanCollide=true; self.filter=filter
    local overlap=OverlapParams.new(); overlap.FilterType=Enum.RaycastFilterType.Exclude
    overlap.FilterDescendantsInstances=models; overlap.RespectCanCollide=true; overlap.MaxParts=16; self.overlap=overlap
end
function Crowd:free(point,own,radius)
    if not Policy.free(point,self.people,own,radius or Policy.spacing) then return false end
    for key,p in pairs(self.slots) do
        if key~=own and math.abs(p.Y-point.Y)<Policy.vertical and Policy.distance(point,p)<(radius or Policy.spacing) then return false end
    end
    return true
end
function Crowd:floor(point)
    local hit=workspace:Raycast(point+Vector3.new(0,2,0),Vector3.new(0,-8,0),self.filter)
    return hit and hit.Normal.Y>0.65 and point.Y-hit.Position.Y>=1 and point.Y-hit.Position.Y<=5
end
function Crowd:clear(from,to)
    local delta=to-from
    return delta.Magnitude<0.1 or not workspace:Blockcast(CFrame.new(from),Vector3.new(3,3,3),delta,self.filter)
end
function Crowd:slot(point,own,seed)
    for i=1,25 do
        local x,z=Policy.offset(i,seed); local candidate=point+Vector3.new(x,0,z)
        -- Blockcast excludes initial overlaps. Query the standing volume as well.
        if self:free(candidate,own) and self:floor(candidate)
            and #workspace:GetPartBoundsInBox(CFrame.new(candidate),Vector3.new(3,3,3),self.overlap)==0 then
            self.slots[own]=candidate; return candidate
        end
    end
    self.metrics.deferred+=1; return nil
end
function Crowd:release(own) self.slots[own]=nil end
function Crowd:walk(mover,waypoint,deadline,valid)
    local detour,side,changes=nil,if mover.preset%2==0 then 1 else -1,0
    local waitUntil
    while valid() and mover.scope:now()<deadline do
        local from=mover.root.Position
        -- Humanoid MoveTo completes about one stud from its goal. A tighter
        -- threshold waits forever at an engine-completed waypoint.
        if mover:near(waypoint,1.25) and self:free(from,mover,Policy.radius) then mover:stop(); return true end
        if detour and mover:near(detour,1.25) then detour=nil end
        local target=detour or waypoint
        local delta=Vector3.new(target.X-from.X,0,target.Z-from.Z)
        if delta.Magnitude<0.1 then mover:stop(); return false end
        local direction=delta.Unit
        local ahead=from+direction*math.min(delta.Magnitude,Policy.lookAhead)
        local blocker=Policy.blocker(from,ahead,self.people,mover,Policy.radius)
        if blocker then
            mover:stop(); self.metrics.occupied+=1
            local candidate
            if not detour and changes<2 then
                for _,sign in ipairs({side,-side}) do
                    local offset=Vector3.new(-direction.Z,0,direction.X)*sign*4.5
                    local p=Vector3.new(blocker.position.X,from.Y,blocker.position.Z)+offset
                    if self:free(p,mover,Policy.radius) and self:floor(p) and self:clear(from,p)
                        and not Policy.blocker(from,p,self.people,mover,Policy.radius) then candidate=p; side=sign; break end
                end
            end
            if candidate then
                detour=candidate; changes+=1; self.metrics.detours+=1; waitUntil=nil
            else
                if not waitUntil then waitUntil=mover.scope:now()+1.4; self.metrics.waits+=1 end
                if mover.scope:now()>=waitUntil then return false end
            end
        else
            waitUntil=nil; mover.destination=target; mover.humanoid:MoveTo(target)
        end
        task.wait(0.1)
    end
    mover:stop(); return false
end
return Crowd
