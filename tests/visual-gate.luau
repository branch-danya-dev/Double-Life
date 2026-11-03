local UI=require('../src/shared/LobbyPresentation')
local Approach=require('./m1121/Approach')
local Guide=require('../src/shared/RoleGuide')
local n=0
local function check(ok,label) assert(ok,label); n+=1 end
for _,state in ipairs({'Lobby','Queued','MatchReady','Active'}) do
    local expected=UI.status({state=state})
    for humans=1,15 do
        local text=UI.status({state=state,realHumans=humans,lobbyMimics=math.max(0,6-humans)})
        check(text==expected,'same public status regardless of real/AI composition')
        check(not text:find('%d') and not text:find('персонаж') and not text:find('реаль'),'no invented public count or AI label')
    end
end
check(UI.status({state='unknown'})==UI.status({state='Lobby'}),'unknown state has safe game copy')
check(UI.status({state='Queued',transport='TransportFailed'}):find('Повторяем')~=nil,'transport error remains actionable')
check(UI.status({state='Queued',transport='MatchmakingFailed'})==UI.status({transport='TransportFailed'}),'both retry states')
check(not Guide.goal('Waiting'):find('реаль'),'waiting banner is neutral')
local scope={alive=true,now=function() return 100 end}
local reserved,attempts,releases,stops=false,0,0,0
local mover={scope=scope,stop=function() stops+=1 end}
local crowd={slot=function(_,point,own,seed)
    check(own==mover and point=='interest','reserve for the moving actor at the interest point')
    reserved=true; return {free=true,seed=seed}
end,release=function(_,own) check(own==mover,'release same actor'); reserved=false; releases+=1 end}
function mover:move(target,deadline,cancelled)
    check(reserved and target.free,'driver does not demand an occupied fixed pixel')
    check(deadline==130 and not cancelled(),'bounded production move deadline')
    attempts+=1; return attempts==2
end
local ok,target=Approach.run(mover,crowd,'interest',7)
check(ok and target.seed==10 and attempts==2,'next free slot after refused route')
check(not reserved and releases==2,'reservation released on success and refusal')
attempts=0; releases=0
mover.move=function() attempts+=1; return false end
check(not Approach.run(mover,crowd,'interest',7),'all routes refused, no fake arrival')
check(attempts==3 and releases==3 and stops==1,'at most three attempts and final stop')
crowd.slot=function() return nil end; attempts=0; releases=0
check(not Approach.run(mover,crowd,'interest',7),'no free slot defers')
check(attempts==0 and releases==3,'no path requested into occupied space')
scope.alive=false; releases=0
check(not Approach.run(mover,crowd,'interest',7) and releases==1,'cancelled scope does not retry')
print('M11.2.1 visual gate:',n,'assertions PASS')
