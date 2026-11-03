-- Diagnostic wrapper only; does not modify production movement decisions.
local Probe={}
local function xyz(v) return {x=v.X,y=v.Y,z=v.Z} end
function Probe.run(mover,crowd,target,seconds)
    local record={from=xyz(mover.root.Position),target=xyz(target),waypoints={},
        targetFree=crowd:free(target,mover,3.2),targetFloor=crowd:floor(target)==true}
    local start=mover.scope:now(); local walk=crowd.walk
    crowd.walk=function(self,m,point,deadline,valid)
        if m~=mover then return walk(self,m,point,deadline,valid) end
        local before=m.scope:now()
        local entry={from=xyz(m.root.Position),point=xyz(point),free=self:free(Vector3.new(point.X,m.root.Position.Y,point.Z),m,3.2)}
        local result=walk(self,m,point,deadline,valid)
        entry.reached=result; entry.to=xyz(m.root.Position); entry.seconds=m.scope:now()-before
        entry.valid=valid(); entry.deadlineReached=m.scope:now()>=deadline
        entry.stopFree=self:free(m.root.Position,m,3.2)
        table.insert(record.waypoints,entry); return result
    end
    local ok,result=pcall(function() return mover:move(target,start+seconds,function() return not mover.scope.alive end) end)
    crowd.walk=walk
    record.seconds=mover.scope:now()-start; record.reached=ok and result==true
    record.to=xyz(mover.root.Position); record.alive=mover.scope.alive; record.running=mover.scope.running
    record.failure=if not ok then tostring(result) elseif record.reached then nil
        elseif not record.targetFree then 'OccupiedFixedTarget'
        elseif #record.waypoints==0 then 'PathDidNotProduceWalkableWaypoints'
        else 'WaypointRejectedOrTimedOut'
    -- Studio truncates a single print around 1 KiB. Keep the summary and each
    -- waypoint in separate bounded records so failed arrivals remain diagnosable.
    local points=record.waypoints
    record.waypoints=nil; record.waypointCount=#points
    print('M1121 MOVE DIAGNOSTIC',game:GetService('HttpService'):JSONEncode(record))
    for i,entry in ipairs(points) do
        print('M1121 WAYPOINT',i,game:GetService('HttpService'):JSONEncode(entry))
    end
    record.waypoints=points
    assert(ok,tostring(result)); return result,record
end
return Probe
