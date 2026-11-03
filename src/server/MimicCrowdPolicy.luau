-- Pure geometry used by spawn, standing slots and short movement segments.
local P={spacing=4.2,radius=3.2,vertical=4,lookAhead=6}
function P.distance(a,b) return math.sqrt((a.X-b.X)^2+(a.Z-b.Z)^2) end
function P.blocker(from,to,people,own,radius)
    local dx,dz=to.X-from.X,to.Z-from.Z
    local length2=dx*dx+dz*dz; local nearest,rank
    for _,p in ipairs(people) do
        if p.key~=own and math.abs(p.position.Y-from.Y)<P.vertical then
            local q=p.position
            local t=if length2<0.001 then 0 else math.clamp(((q.X-from.X)*dx+(q.Z-from.Z)*dz)/length2,0,1)
            local d=math.sqrt((q.X-from.X-t*dx)^2+(q.Z-from.Z-t*dz)^2)
            -- A player can deliberately enter a body. Permit only motion away.
            local escaping=P.distance(from,q)<radius and P.distance(to,q)>P.distance(from,q)+0.4 and t==0
            if d<radius and not escaping and (not rank or t<rank) then nearest,rank=p,t end
        end
    end
    return nearest
end
function P.free(point,people,own,radius)
    for _,p in ipairs(people) do
        if p.key~=own and math.abs(p.position.Y-point.Y)<P.vertical and P.distance(point,p.position)<radius then return false end
    end
    return true
end
function P.offset(index,seed)
    if index==1 then return 0,0 end
    local angle=((index-2+seed%8)%8)*math.pi/4
    local radius=if index<=9 then 4.6 elseif index<=17 then 7.8 else 10
    return math.cos(angle)*radius,math.sin(angle)*radius
end
return P
