local Queue=require("../src/server/QueuePolicy")
local Pool=require("../src/server/MatchPool")
local Settings=require("../src/server/MatchSettings")
local Suite={}
function Suite.run(loadService)
    local count=0
    local function check(ok,why) assert(ok,why); count+=1 end
    local function copy(v)
        if type(v)~="table" then return v end
        local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
    end
    local function scenario()
        local shared={state=Pool.empty(),now=0,guid=0,sends={}}
        local function server(job)
            local players={list={}}
            function players:GetPlayers() return self.list or {} end
            local failure={}
            function failure:Connect(callback) self.callback=callback end
            local transport={enabled=true}
            function transport:update(transform)
                if self.failUpdate then error("memory unavailable") end
                -- UpdateAsync may retry; discard a speculative transform.
                transform(copy(shared.state))
                shared.state=transform(copy(shared.state))
                if self.afterUpdate then local cb=self.afterUpdate; self.afterUpdate=nil; cb() end
                return copy(shared.state)
            end
            function transport:send(p,target,match,token)
                if self.failSend then error("transport unavailable") end
                table.insert(shared.sends,{player=p,target=target,matchId=match,ticket=token})
            end
            local http={GenerateGUID=function() shared.guid+=1; return job..":"..shared.guid end}
            local engine={JobId=job,GameId=100,PlaceId=200}
            function engine:GetService(name)
                return ({Players=players,HttpService=http,TeleportService={TeleportInitFailed=failure}})[name]
            end
            local modules={QueuePolicy=Queue,MatchPool=Pool,MatchSettings=Settings,MatchTransport={new=function() return transport end}}
            local env=setmetatable({game=engine,os={clock=function() return shared.now end,time=function() return shared.now end},
                task={spawn=function(f) f() end,wait=function() error("unexpected unbounded loop") end},
                script={Parent=setmetatable({},{__index=function(_,k) return k end})},
                require=function(name) return assert(modules[name],name) end},{__index=getfenv()})
            local remote={OnServerEvent={Connect=function(self,cb) self.callback=cb end}}
            local rt={alive=false,rounds={policy={participants={}}},lobby={}}
            local service=loadService(env).new(rt,remote)
            local function add(id,data)
                local p={UserId=id,Parent=players,GetJoinData=function() return data or {} end}
                table.insert(players.list or {},p)
                service:add(p); return p
            end
            return {q=service,add=add,transport=transport,failed=failure,players=players,remote=remote}
        end
        return shared,server
    end
    for _,mode in ipairs({"Success","SendFailure","MemoryFailure","CancelDuringYield","CancelAfterSend","InitFailure","StaleInitFailure","ArrivalForgery","Timeout","Disconnect"}) do
        local s,new=scenario(); local a,b=new("A"),new("B")
        local pa,pb=a.add(1),b.add(2)
        check(not a.q:register(pa),"duplicate registration does not replace ticket")
        a.q:poll(); check(#s.sends==0,"one server visitor cannot teleport")
        if mode=="SendFailure" then b.transport.failSend=true end
        if mode=="MemoryFailure" then b.transport.failUpdate=true end
        if mode=="CancelDuringYield" then b.transport.afterUpdate=function() b.q:cancel(pb) end end
        b.q:poll()
        if mode=="MemoryFailure" then
            check(b.q.status=="MatchmakingFailed" and #s.sends==0,"MemoryStore refusal fails closed")
            b.transport.failUpdate=false; b.q:poll(); check(#s.sends==1,"memory retry makes progress")
        elseif mode=="SendFailure" then
            check(b.q.status=="TransportFailed" and not b.q.sending[pb],"throwing teleport releases in-flight state")
            check(b.q.policy.entries[2]~=nil and s.state.matches[next(s.state.matches)]==nil,"failure requeues and releases pair")
        elseif mode=="CancelDuringYield" then
            check(#s.sends==0 and not b.q.policy.entries[2],"cancel while UpdateAsync yields prevents teleport")
        else
            check(#s.sends==1 and s.sends[1].target=="A","actual service sends only reserved remote human")
            local sent=s.sends[1]
            b.q:poll(); check(#s.sends==1,"repeated poll does not duplicate teleport")
            if mode=="Success" then
                b.q:remove(pb); pb.Parent=nil
                local arrived=a.add(2,{SourceGameId=100,SourcePlaceId=200,TeleportData=sent})
                a.q:poll(); a.q:eligible(); s.now=4
                check(#a.q:eligible()==2,"arrival, atomic confirmation and local ready delay permit actual pair")
                check(a.q.players[2]==arrived and a.q.approved[2],"destination owns actual arrived Player")
            elseif mode=="ArrivalForgery" then
                local p=a.add(2,{SourceGameId=100,SourcePlaceId=200,TeleportData={matchId=sent.matchId,ticket="fake"}})
                a.q:poll(); a.q:eligible(); s.now=4
                check(#a.q:eligible()==0 and a.q.tokens[2]~=sent.ticket,"forged arrival never completes pair")
                check(a.q.players[2]==p,"visitor can remain safely in lobby")
            elseif mode=="CancelAfterSend" then
                b.q:cancel(pb); s.now=100; b.q:poll()
                check(not b.q.policy.entries[2] and not b.q.sending[pb],"explicit cancellation never auto re-registers")
            elseif mode=="Timeout" then
                s.now=100; b.q:poll()
                check(not b.q.sending[pb] and b.q.errors==1,"missing teleport arrival has bounded retry")
            elseif mode=="Disconnect" then
                b.q:remove(pb); pb.Parent=nil; s.now=100; a.q:poll()
                check(not s.state.tickets["2"] and #a.q:eligible()==0,"disconnect/crash lease cannot manufacture opponent")
            else
                local data=if mode=="StaleInitFailure" then {matchId="old",ticket="old"} else sent
                b.failed.callback(pb,nil,nil,nil,{GetTeleportData=function() return data end})
                if mode=="StaleInitFailure" then check(b.q.sending[pb]~=nil and b.q.errors==0,"stale transport callback cannot cancel newer assignment")
                else check(not b.q.sending[pb] and b.q.errors==1,"matching transport failure releases and retries") end
            end
        end
    end
    print("M9 actual matchmaking runtime:",count,"assertions PASS")
end
return Suite
