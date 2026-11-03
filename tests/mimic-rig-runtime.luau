local Catalog=require("../src/server/MimicAppearance")
local Policy=require("../src/server/MimicLoadPolicy")
local Suite={}
function Suite.run(loadRig)
    local n=0; local function check(ok,label) assert(ok,label); n+=1 end
    local env=setmetatable({game={GetService=function() return {} end},script={Parent={NpcMover="mover",MimicAppearance="catalog",MimicLoadPolicy="policy",MimicAnimation="motion"}},
        require=function(key) return if key=="catalog" then Catalog elseif key=="policy" then Policy else {} end,
        Enum={HumanoidRigType={R15="R15"},AccessoryType={Hair="Hair"}}},{__index=getfenv()})
    local Rig=loadRig(env)
    local function fixture(kind)
        local description={Shirt=Catalog.presets[1].Shirt,Pants=Catalog.presets[1].Pants,HairAccessory="",destroyed=false}
        description.accessories={{AssetId=tonumber(Catalog.presets[1].HairAccessory),AccessoryType="Hair"}}
        function description:GetAccessories(includeRigid) assert(includeRigid); return self.accessories end
        function description:Destroy() self.destroyed=true end
        local h={RigType="R15",GetAppliedDescription=function() return description end}
        local model={parts={},items={}}
        function model:IsA(k) return k=="Model" end
        function model:FindFirstChild(k) return self.parts[k] end
        function model:FindFirstChildOfClass(k) return if k=="Humanoid" then h else self.parts[k] end
        function model:GetDescendants() return self.items end
        for _,name in ipairs({"HumanoidRootPart","Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot","Shirt","Pants"}) do model.parts[name]={} end
        for _=1,15 do
            local attachment={IsDescendantOf=function(_,m) return m==model end}
            table.insert(model.items,{IsA=function(_,k) return k==kind end,Part0={},Part1={},Attachment0=attachment,Attachment1=attachment})
        end
        table.insert(model.items,{IsA=function(_,k) return k=="Accessory" end,FindFirstChild=function() return {} end})
        return model,h,description
    end
    for _,kind in ipairs({"Motor6D","AnimationConstraint"}) do
        local m,h,d=fixture(kind)
        check(Rig.validate(m,1),kind.." R15 admitted")
        check(d.destroyed,"applied description released")
        h.RigType="R6"; check(not Rig.validate(m,1),"R6 rejected"); h.RigType="R15"
        for _,name in ipairs({"Head","UpperTorso","LowerTorso","LeftHand","RightHand","LeftFoot","RightFoot","HumanoidRootPart","Shirt","Pants"}) do
            local part=m.parts[name]; m.parts[name]=nil; check(not Rig.validate(m,1),"missing "..name); m.parts[name]=part
        end
        local joint=table.remove(m.items,1); check(not Rig.validate(m,1),"missing animated joint"); table.insert(m.items,1,joint)
        local accessory=table.remove(m.items); check(not Rig.validate(m,1),"missing visible accessory"); table.insert(m.items,accessory)
        d.Shirt=0; check(not Rig.validate(m,1),"missing requested shirt"); d.Shirt=Catalog.presets[1].Shirt
        d.Pants=0; check(not Rig.validate(m,1),"missing requested pants"); d.Pants=Catalog.presets[1].Pants
        d.accessories[1].AssetId=1; check(not Rig.validate(m,1),"unapproved replacement hair")
        d.accessories[1].AssetId=tonumber(Catalog.presets[1].HairAccessory)
        d.accessories[1].AccessoryType="Hat"; check(not Rig.validate(m,1),"wrong accessory type")
        d.accessories[1].AccessoryType="Hair"
        check(Rig.validate(m,1),"layered hair need not occupy legacy HairAccessory string")
    end
    check(not Rig.validate(nil,1),"no block fallback on missing model")
    print("M11.1 actual R15 admission:",n,"assertions PASS")
end
return Suite
