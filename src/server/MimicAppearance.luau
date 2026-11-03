-- Fictional identities and Roblox-owned free catalogue assets. No account lookup.
local A={seed=271828}
A.body={
    Classic={},
    Man={Torso=86500008,RightArm=86500036,LeftArm=86500054,LeftLeg=86500064,RightLeg=86500078},
    Woman={Torso=86499666,RightArm=86499698,LeftArm=86499716,LeftLeg=86499753,RightLeg=86499793},
}
A.animations={Idle=507766388,IdleLook=507766666,Walk=507777826,Run=507767714,Wave=507770239,Point=507770453,Cheer=507770677}
local skins={{234,192,151},{194,145,103},{128,83,59},{242,213,180},{166,113,78},{92,62,46}}
local function preset(name,style,body,shirt,pants,hair,skin,height,width,head,hat)
    return {name=name,style=style,body=body,Shirt=shirt,Pants=pants,HairAccessory=tostring(hair),
        HatAccessory=hat and tostring(hat) or "",skin=skins[skin],Head=head or 0,
        HeightScale=height,WidthScale=width,DepthScale=width,HeadScale=0.95,
        BodyTypeScale=if body=="Classic" then 0 else 0.3,ProportionScale=0.15}
end
-- Ten everyday, six smart-casual, four expressive looks: 50/30/20 over a full bag.
A.presets={
    preset("MiraVell","Everyday","Woman",398633584,398633812,376526888,1,0.98,0.90,10725626210),
    preset("LeonArden","Everyday","Man",144076358,144076760,376548738,3,1.02,0.96,10725826963),
    preset("NikaFane","Everyday","Classic",3670737444,398635338,7193454569,5,0.94,0.90),
    preset("FelixVale","Everyday","Man",382538059,382538503,63690008,2,0.98,1.00),
    preset("AdaMorn","Everyday","Woman",398634295,398634487,9244150641,6,1.01,0.94,10725626210),
    preset("OscarReed","Everyday","Classic",607785314,398633812,376548738,4,1.00,1.00,10725826963),
    preset("VeraLinden","Everyday","Woman",3670737444,144076760,2956239660,4,0.95,0.88),
    preset("MaxElvar","Everyday","Man",398633584,398635338,376524487,1,1.05,0.92,10725826963),
    preset("LinaOrrel","Everyday","Woman",382538059,398634487,9244148336,2,0.97,0.98,10725626210),
    preset("IrisVoss","Everyday","Classic",144076358,382538503,7193455510,3,0.96,0.92),
    preset("TheoWren","SmartCasual","Man",398635081,398633812,376548738,4,1.04,0.92,10725826963),
    preset("RinaCole","SmartCasual","Woman",398634295,398633812,62724852,2,1.00,0.88,10725626210),
    preset("EmilBrook","SmartCasual","Man",607785314,144076760,376548738,6,1.01,0.94),
    preset("SanaVale","SmartCasual","Woman",398635081,398634487,7193454569,3,0.96,0.90,10725626210),
    preset("NoelAsh","SmartCasual","Classic",398635081,382538503,376524487,5,1.02,0.96,10725826963),
    preset("TessaFern","SmartCasual","Woman",398634295,144076760,9244150641,1,1.03,0.94),
    preset("KaiMoss","Expressive","Classic",3670737444,398635338,451221329,4,0.95,1.00),
    preset("ZoeRill","Expressive","Woman",607785314,398634487,2956239660,5,1.04,0.88,10725626210),
    preset("EliStorm","Expressive","Man",382538059,398633812,1103003368,2,0.98,0.96,10725826963),
    preset("AriaGlen","Expressive","Classic",398633584,382538503,451221329,6,1.01,0.92),
}
-- Integer arithmetic stays exact in Luau doubles; deterministic across servers/tests.
function A.noise(seed,index)
    return ((seed%2147483647)*48271+(index%2147483647)*69621)%2147483647
end
function A.order(seed)
    local result={}; for i=1,#A.presets do result[i]=i end
    local state=seed
    for i=#result,2,-1 do state=A.noise(state,i); local j=state%i+1; result[i],result[j]=result[j],result[i] end
    return result
end
function A.pick(seed,serial,used)
    local order=A.order(seed)
    for offset=0,#order-1 do
        local id=order[(serial-1+offset)%#order+1]
        if not used[id] then return id end
    end
    return nil
end
function A.pause(seed,step) return 2.5+A.noise(seed,step)%55/10 end
-- Distinct standing places around each lobby object, clear of its solid prop.
function A.lobbyOffset(id) return ((id-1)%5-2)*3.5,math.floor((id-1)/5)*3.5 end
-- Pantry floor north of Service.Home: outside the solid counter and cloth stand.
function A.matchOffset(id) return -10+(id-1)%5*3.5,-17+math.floor((id-1)/5)*3.5 end
return A
