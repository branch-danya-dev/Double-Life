-- Bounded, local identity admission. No account lookups and no live actor redressing.
local Catalog=require(script.Parent.MimicAppearance)
local Identity={}
local similar={['О']='o',['о']='o',['С']='c',['с']='c',['А']='a',['а']='a',
    ['Е']='e',['е']='e',['Р']='p',['р']='p',['Х']='x',['х']='x',['М']='m',['Т']='t',['В']='b',
    ['І']='i',['і']='i',['Ӏ']='i',['Ν']='n',['Ο']='o',['ο']='o',['Α']='a',['Ε']='e'}
function Identity.key(name)
    local text=tostring(name)
    for from,to in pairs(similar) do text=text:gsub(from,to) end
    return (text:lower():gsub('[%s_%p]',''):gsub('0','o'):gsub('[1l]','i'))
end
function Identity.names(players,reserved)
    local used={}
    for name in pairs(reserved or {}) do used[Identity.key(name)]=true end
    for _,p in ipairs(players) do used[Identity.key(p.Name)]=true; used[Identity.key(p.DisplayName)]=true end
    return used
end
function Identity.name(preset,used)
    local base=Catalog.presets[preset].name
    for suffix=0,99 do
        local name=base..(if suffix==0 then '' else tostring(suffix+1))
        if not used[Identity.key(name)] then return name end
    end
    return nil
end
local bodyKeys={'Torso','LeftArm','RightArm','LeftLeg','RightLeg'}
function Identity.preset(id)
    local p=Catalog.presets[id]; local f={Shirt=p.Shirt,Pants=p.Pants,Head=p.Head,Face=0,hair={[tonumber(p.HairAccessory)]=true}}
    for _,k in ipairs(bodyKeys) do f[k]=Catalog.body[p.body][k] or 0 end
    return f
end
function Identity.description(d)
    local f={Shirt=d.Shirt,Pants=d.Pants,Head=d.Head,Face=d.Face,hair={}}
    for _,k in ipairs(bodyKeys) do f[k]=d[k] end
    -- Roblox normalizes layered hair out of HairAccessory into accessories.
    for token in tostring(d.HairAccessory):gmatch('%d+') do f.hair[tonumber(token)]=true end
    for _,a in ipairs(d:GetAccessories(true)) do
        if tostring(a.AccessoryType):match('Hair$') then f.hair[a.AssetId]=true end
    end
    return f
end
function Identity.conflict(a,b)
    if a.Shirt~=b.Shirt or a.Pants~=b.Pants then return false end
    local hair=false; for id in pairs(a.hair) do if b.hair[id] then hair=true; break end end
    local body=a.Head==b.Head
    for _,key in ipairs(bodyKeys) do if a[key]~=b[key] then body=false end end
    -- Matching clothes + shared hair OR body/head is already a near clone.
    -- Deliberately ignore tiny scale, colour and face differences at game distance.
    return hair or body
end
function Identity.pick(seed,serial,used,humans)
    local denied=table.clone(used)
    for id=1,#Catalog.presets do
        local p=Identity.preset(id)
        for _,h in ipairs(humans) do if Identity.conflict(p,h) then denied[id]=true; break end end
    end
    return Catalog.pick(seed,serial,denied)
end
return Identity
