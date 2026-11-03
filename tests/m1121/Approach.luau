-- Capture driver: use the same reservation contract as production AI jobs.
-- A failed fixed pixel is not a reason to teleport or waive the safety checks.
local Approach={}
function Approach.run(mover,crowd,point,seed,trace)
    for attempt=1,3 do
        local target=crowd:slot(point,mover,seed+(attempt-1)*3)
        local ok=false
        if target then
            ok=mover:move(target,mover.scope:now()+30,function() return not mover.scope.alive end)
        end
        crowd:release(mover)
        if trace then trace(attempt,target,ok) end
        if ok then return true,target end
        if not mover.scope.alive then break end
    end
    mover:stop(); return false
end
return Approach
