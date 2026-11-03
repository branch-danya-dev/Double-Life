local A=require("../src/server/MimicAppearance")
local P=require("../src/server/MimicLoadPolicy")
local n=0; local function check(ok,msg) assert(ok,msg); n+=1 end
local styles,names,looks={},{},{}
for _,p in ipairs(A.presets) do
    styles[p.style]=(styles[p.style] or 0)+1
    check(not names[p.name],"fictional identities unique"); names[p.name]=true
    check(p.Shirt>0 and p.Pants>0 and tonumber(p.HairAccessory)>0,"fully dressed descriptions")
    check(A.body[p.body]~=nil,"known R15 body")
    check(p.HeightScale>=0.9 and p.HeightScale<=1.05 and p.WidthScale>=0.85 and p.WidthScale<=1,"walkable scale range")
    local key=table.concat({p.body,p.Shirt,p.Pants,p.HairAccessory,p.Head,table.concat(p.skin,",")},":")
    check(not looks[key],"no duplicate outfits"); looks[key]=true
end
check(#A.presets==20 and styles.Everyday==10 and styles.SmartCasual==6 and styles.Expressive==4,"approved 50/30/20 catalogue")
for _,seed in ipairs({0,1,271828,2147483646}) do
    local used={}; local order=A.order(seed)
    for i=1,20 do
        local id=A.pick(seed,i,used)
        check(id~=nil and not used[id],"twenty neighbouring identities without clones")
        check(id==order[i] and id==A.order(seed)[i],"seed replay is deterministic")
        used[id]=true
    end
    check(A.pick(seed,21,used)==nil,"full catalogue cannot silently duplicate a neighbour")
    used[order[3]]=nil; check(A.pick(seed,21,used)==order[3],"despawn releases a slot")
end
check(table.concat(A.order(1),",")~=table.concat(A.order(2),","),"configurable seed changes the order")
for i=1,20 do check(A.pause(i,4)>=2.5 and A.pause(i,4)<=7.9,"bounded staggered pauses") end
local minSpacing=math.huge; local bounded=true; local stable=true
for i=1,20 do
    local x,z=A.lobbyOffset(i); local againX,againZ=A.lobbyOffset(i)
    bounded=bounded and math.abs(x)<=7 and z>=0 and z<=10.5
    stable=stable and x==againX and z==againZ
    for j=i+1,20 do local u,v=A.lobbyOffset(j); minSpacing=math.min(minSpacing,math.sqrt((u-x)^2+(v-z)^2)) end
end
check(minSpacing>=3.5,"different actors cannot stand in the same lobby slot")
check(bounded,"lobby offsets stay inside the floor and away from solid interest props")
check(stable,"standing offset stays stable for an appearance")
local layout=require("../src/server/MansionLayout")
local home,pantry
for _,node in ipairs(layout.nodes) do if node.id=="Service.Home" then home=node.position end end
for _,room in ipairs(layout.rooms) do if room.id=="Pantry" then pantry=room end end
for i=1,20 do
    local dx,dz=A.matchOffset(i); local x,z=home[1]+dx,home[3]+dz
    check(x>pantry.min[1]+2 and x<pantry.max[1]-2 and z>pantry.min[3]+2 and z<pantry.max[3]-2,"match spawn has floor and wall clearance")
    for _,node in ipairs(layout.nodes) do if node.room=="Pantry" and node.kind=="Object" then
        check(math.abs(x-node.position[1])>node.size[1]/2+2 or math.abs(z-node.position[3])>node.size[3]/2+2,"match spawn clears solid pantry furniture")
    end end
    for j=i+1,20 do local u,v=A.matchOffset(j); check((u-dx)^2+(v-dz)^2>=3.5^2,"match spawn slots do not overlap") end
end
local time=0; local policy=P.new(function() return time end)
local first=policy:begin(1)
check(first~=nil and policy:begin(2)==nil,"one outstanding asset request")
time=7.9; check(not policy:expired(first),"load budget not prematurely expired")
time=8; check(policy:expired(first),"eight second admission deadline")
check(policy:begin(2)==nil,"timeout does not spawn unbounded outstanding requests")
check(policy:finish(first,false) and policy.pending==nil,"late completion releases actual engine slot")
check(policy:begin(2)==nil,"failure cooldown")
time=10; local second=policy:begin(2); check(second~=nil,"bounded retry after cooldown")
check(not policy:finish(first,true) and policy.pending==second,"stale callback cannot release a new load")
policy:finish(second,true); check(policy.failures==0,"successful request resets backoff")
for i=1,8 do
    time+=40; local token=policy:begin(i); check(token~=nil,"retry eventually permitted")
    policy:finish(token,false); check(policy.nextAt-time<=30,"bounded exponential backoff")
end
print("M11.1 appearance allocation and load policy:",n,"assertions PASS")
