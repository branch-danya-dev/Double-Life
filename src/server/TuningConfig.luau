-- Reviewed, static configuration only. No remote flags, experiments or reward knobs.
local T={}
T.bounds={targetSize={2,15},lobbyDensity={0,8},maxMimics={0,8},aiWorkers={1,2},queueSeconds={60,1800},readySeconds={3,30},prologueOfferSeconds={0,60}}
T.defaults={prologueOfferSeconds=0,allowSkip=true,allowInvite=true}
function T.resolve(base,overrides)
    local result=table.clone(base)
    for k,v in pairs(T.defaults) do result[k]=v end
    for k,v in pairs(overrides or {}) do
        local bounds=T.bounds[k]
        assert(bounds or k=="allowSkip" or k=="allowInvite","Unknown tuning key")
        if bounds then assert(type(v)=="number" and v==v and v%1==0 and v>=bounds[1] and v<=bounds[2],"Unsafe tuning value")
        else assert(type(v)=="boolean","Boolean tuning value required") end
        result[k]=v
    end
    for k,b in pairs(T.bounds) do local v=result[k]; assert(type(v)=="number" and v%1==0 and v>=b[1] and v<=b[2],"Unsafe base tuning") end
    return table.freeze(result)
end
return T
