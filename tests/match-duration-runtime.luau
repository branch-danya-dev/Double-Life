local Config = require("../src/shared/Config")
local Round = require("../src/server/RoundPolicy")
local Reward = require("../src/server/ProgressionPolicy")
local Catalog = require("../src/server/ProgressionCatalog")
local Suite = {}
function Suite.run(loadService)
    local n=0; local function check(ok,msg) assert(ok,msg); n+=1 end
    for _, scenario in ipairs({"Timeout", "LargeDt", "Extract90", "Extract1100", "SpyLeft", "CouncilLeave"}) do
        local humans={{UserId=1,Name="Owner"},{UserId=2,Name="Spy"},{UserId=3,Name="Spy2"}}
        local players={GetPlayers=function() return humans end,GetPlayerByUserId=function(_,id) return humans[id] end}
        local Service=loadService({RoundPolicy=Round},{game={GetService=function() return players end}})
        local roles={get=function(_,p) return if p.UserId==1 then "Owner" else "Spy" end,
            assign=function() return {1,2,3} end,clear=function() end}
        local finished,awards,xp,tokens=0,0,0,0
        local record
        local service=Service.new(Config,roles,function() end,{Fire=function(_,result)
            finished+=1
            local award=Reward.reward(record,result.winner,Catalog.rules)
            if award then awards+=1; xp+=award.xp; tokens+=award.tokens end
        end})
        service.sync=function() end -- Engine physics only; tick/report/snapshot are actual production methods.
        service.rebuild=function(active)
            if active then
                for i=1,6 do service.policy:addMimic("m:"..i) end
                record=Reward.round("Staff",1); record.active=90; record.moving=30
                Reward.action(record,"ServicePickup"); Reward.action(record,"Delivery")
            end
        end
        service.session={interactions={clear=function() end},events={cancel=function() end},
            actors={get=function(_,id) return {name=id} end}}
        service:tick(0); service:tick(Config.COUNTDOWN_SECONDS)
        check(service:snapshot(humans[1]).remaining==1200,"service starts authoritative timer")
        check(#service:snapshot(humans[1]).members==9,"real roster and six Guest identities preserved")
        if scenario=="Timeout" or scenario=="LargeDt" then
            service:tick(420); check(service.policy.phase=="Active","420 no longer ends match")
            check(service:callCouncil(humans[1]),"real service council")
            service:tick(24)
            local s=service:snapshot(humans[1])
            check(s.remaining==1 and s.activeRemaining==780,"council and match snapshot timers separate")
            service:tick(1); check(service.policy.remaining==780,"resume budget")
            service:tick(if scenario=="LargeDt" then 10000 else 780)
            check(service.policy.result.reason=="Timeout" and service.policy.elapsed==1200,"timeout once")
        elseif scenario=="SpyLeft" or scenario=="CouncilLeave" then
            service:tick(90)
            if scenario=="CouncilLeave" then service:callCouncil(humans[1]) end
            service:leave(humans[2]); check(finished==0,"first spy does not settle")
            service:leave(humans[3]); check(service.policy.result.reason=="SpyLeft","last spy settles")
        else
            service:tick(if scenario=="Extract90" then 90 else 1100)
            check(service:extract(2) and service.policy.result.reason=="Extraction","early extraction settles")
            check(xp==50 and tokens==19,"qualified losing staff retains 50 XP and 19 tokens")
        end
        check(finished==1 and awards==1,"one RoundFinished and one award")
        for _=1,3 do service:report(); service:extract(2); service:leave(humans[3]) end
        check(finished==1 and awards==1,"repeated callbacks cannot settle twice")
        check(Reward.reward(record,"Spy",Catalog.rules)==nil,"reward guard also rejects duplicate")
        service:tick(10000)
        check(service.policy.phase=="Waiting" and #service.roster==0 and next(service.policy.mimics)==nil,"results reset clears actors")
        service:tick(0); service:tick(Config.COUNTDOWN_SECONDS)
        check(service.policy.roundId==2 and service.policy.remaining==1200,"second round gets full budget")
        service:tick(90); service:extract(2); service:report()
        check(finished==2 and awards==2,"next round settles exactly once")
    end
    print("M12.0 runtime PASS: "..n.." assertions")
end
return Suite
