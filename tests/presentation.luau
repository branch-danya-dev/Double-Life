local Art=require("../src/server/MansionArtPlan")
local Layout=require("../src/server/MansionLayout")
local P=require("../src/shared/Presentation")
local count=0
local function check(ok,message) assert(ok,message); count+=1 end
local before=#Layout.geometry
local parts=Art.build(Layout)
check(#parts>600 and #parts<=Art.budgets.staticParts,"authored room coverage within native part budget")
check(#Layout.geometry==before,"art cannot append collision surfaces")
local collisions,invalid,roots=0,0,{}
for _,s in ipairs(parts) do
    if s.collide or s.query then collisions+=1 end
    if not Art.palette[s.color] then invalid+=1 end
    for i=1,3 do
        if s.size[i]<=0 or s.size[i]~=s.size[i] or math.abs(s.position[i])>1000 then invalid+=1 end
    end
    roots[s.name]=true
end
check(collisions==0,"no art raycast/collision can block prompts, drops or navigation")
check(invalid==0,"all asset specifications finite with known palette and positive size")
for room in pairs(Art.rooms) do
    check(roots[room.."Rug"] and roots[room.."Pendant"] and roots[room.."Opal"],"room identity "..room)
end
check(roots.LibraryCase and roots.BookSpine,"recognizable library props")
check(roots.StairRunner and roots.StairNosing,"both stairs have legible treads")
check(roots.EntryPillar and roots.FoyerFan,"recognizable entrance motif")
check(Art.budgets.lights==22 and Art.budgets.particles==0,"bounded effects without lighting multiplication")
for _,size in ipairs({{320,568},{390,844},{640,360},{844,390},{1024,768},{1280,720},{1920,1080}}) do
    local l=P.layout(size[1],size[2])
    check(l.panelWidth<=size[1]-24 and l.panelHeight<=size[2]-100,"panel fits "..size[1].."x"..size[2])
    check(l.statusWidth+150<=size[1] and l.buttonHeight>=44,"status avoids menu; touch targets "..size[1])
end
check(P.layout(844,390).compact and not P.layout(1280,720).compact,"landscape compact threshold")
check(P.label("en-us","Rules")=="Help" and P.label("ru-ru","Rules")=="Правила","locale selected")
check(P.label("fr-fr","Rules")=="Правила" and P.label("ru-ru","unknown")=="unknown","safe localization fallback")
for key in pairs(P.labels.ru) do check(P.labels.en[key]~=nil,"menu translation "..key) end
local function state()
    return {round={roundId=1,phase="Active"},hasDossier=false,evidence=nil,social={held=nil},paintings=0,refreshments=0,activities={event={hasRelic=false}}}
end
local a,b=state(),state()
check(P.feedback(nil,b)==nil and P.feedback(a,b)==nil,"no phantom feedback on join/idle")
b.hasDossier=true
check(P.feedback(a,b)~=nil and P.held(b),"local dossier pickup feedback")
b.round.roundId=2
check(P.feedback(a,b)==nil,"round reset cannot replay pickup")
b.round.roundId=1; b.round.phase="Council"
check(P.feedback(a,b)==nil,"phase change cancels feedback")
b=state(); b.evidence={kind="Seal"}
check(P.feedback(a,b)~=nil and P.held(b),"local evidence feedback")
b=state(); b.social.held="Parcel"
check(P.feedback(a,b)~=nil and P.held(b),"transfer feedback")
a=b; b=state()
check(P.feedback(a,b)~=nil and not P.held(b),"release clears held state")
a=state(); b=state(); b.paintings=1
check(P.feedback(a,b)~=nil,"painting acknowledgement")
b=state(); b.refreshments=1
check(P.feedback(a,b)~=nil,"delivery acknowledgement")
b=state(); b.activities.event.hasRelic=true
check(P.held(b) and not P.held(nil),"relic / loading inventory")
for _,uri in pairs(P.audio) do check(string.sub(uri,1,18)=="rbxasset://sounds/","audio restricted to engine resources") end
print("PASS: "..count.." M7 art, budgets, responsive UI and private feedback assertions; "..#parts.." static art parts")
