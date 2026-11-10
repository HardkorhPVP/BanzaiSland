-- Public notifications are data, never frames or caller callbacks. Keep ownership private.
local ADDON,ns=...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local I,L,C=ns.Island,ns.L,ns.C
local E={};ns.Extensions=E
local registry,records,bubbles={},{},{}
local ready,epoch=false,0
local frame=CreateFrame("Frame")
local totalRegistered=0
local globalBucket={tokens=10,at=GetTime()}
local sweep,Wake
local function Read(v,t) return ns.Readable(v) and type(v)==t end
local function Plain(v) return Read(v,"table") and getmetatable(v)==nil end
local function Number(v) return Read(v,"number") and v==v and v~=math.huge and v~=-math.huge end
local function Id(v) return Read(v,"string") and #v>0 and #v<=64 and v:match("^[A-Za-z0-9_%-]+$")~=nil end
local function Text(v,limit)
    if not Read(v,"string") or #v>limit or v:find("[%z\1-\8\11\12\14-\31\127]") then return false end
    local pos,depth=1,0
    while true do
        local p=v:find("|",pos,true)
        if not p then return depth==0 end
        local code=v:sub(p+1,p+1)
        if code=="|" then pos=p+2
        elseif code=="c" and v:sub(p+2,p+9):match("^%x%x%x%x%x%x%x%x$") then depth=depth+1;pos=p+10
        elseif code=="r" and depth>0 then depth=depth-1;pos=p+2
        else return false end
    end
end
local function Fields(payload,allowed)
    if not Plain(payload) then return false end
    for k in pairs(payload) do if not Read(k,"string") or not allowed[k] then return false end end
    return true
end
local cardFields={title=true,text=true,caption=true,icon=true,group=true,duration=true,ttl=true,feature=true,progress=true,countdown=true,barColor=true}
local bubbleFields={text=true,tooltip=true,icon=true,ttl=true,persistent=true,feature=true,countdown=true,progress=true,bar=true,barColor=true}
local groups={loot=true,social=true,alerts=true,world=true}
local colorMap -- filled in with the colour list below
local function Icon(v)
    return type(v)=="nil" or (Number(v) and v>0 and v%1==0)
        or (Read(v,"string") and #v>0 and #v<=256 and v:match("^[A-Za-z0-9_%. /\\%-]+$")~=nil)
end
local function Clamp(v,default,lo,hi)
    if type(v)=="nil" then return default end
    if not Number(v) then return end
    return math.max(lo,math.min(hi,v))
end
local function Normalize(p,bubble)
    if not Fields(p,bubble and bubbleFields or cardFields) or not Icon(p.icon) then return end
    if type(p.feature)~="nil" and not Id(p.feature) then return end
    if bubble then
        -- an optional thin bar along the bottom: a fixed fill (progress), or for a countdown bubble bar=true to show it draining
        local progress,barColor,bar
        if type(p.progress)~="nil" then progress=Clamp(p.progress,nil,0,1);if not progress then return end end
        if type(p.bar)~="nil" then
            if not Read(p.bar,"boolean") or type(p.countdown)=="nil" or type(p.progress)~="nil" then return end
            bar=p.bar or nil
        end
        if type(p.barColor)~="nil" then
            if not Read(p.barColor,"string") or not colorMap[p.barColor] or (not progress and not bar) then return end
            barColor=p.barColor
        end
        -- a countdown bubble shows the time left, counted down by Island; its text is only a short label before the time
        if type(p.countdown)~="nil" then
            local cd=Clamp(p.countdown,nil,1,3600)
            if not cd or type(p.ttl)~="nil" or type(p.persistent)~="nil" then return end
            if not Text(p.text or "",16) or (type(p.tooltip)~="nil" and not Text(p.tooltip,1024)) then return end
            return {text=p.text or "",tooltip=p.tooltip or "",icon=p.icon,countdown=cd,feature=p.feature,progress=progress,bar=bar,barColor=barColor}
        end
        if not Text(p.text,24) or (type(p.tooltip)~="nil" and not Text(p.tooltip,1024)) then return end
        if type(p.persistent)~="nil" and not Read(p.persistent,"boolean") then return end
        -- a persistent bubble stays until the extension removes it; it never carries a ttl
        if p.persistent==true then
            if type(p.ttl)~="nil" then return end
            return {text=p.text,tooltip=p.tooltip or "",icon=p.icon,persistent=true,feature=p.feature,progress=progress,barColor=barColor}
        end
        if type(p.ttl)=="nil" then return end
        local ttl=Clamp(p.ttl,nil,1,120);if not ttl then return end
        return {text=p.text,tooltip=p.tooltip or "",icon=p.icon,ttl=ttl,feature=p.feature,progress=progress,barColor=barColor}
    end
    if not Text(p.title,160) or p.title=="" or (type(p.text)~="nil" and not Text(p.text,1024))
        or (type(p.caption)~="nil" and not Text(p.caption,160)) then return end
    local group=type(p.group)=="nil" and "alerts" or p.group
    if not Read(group,"string") or not groups[group] then return end
    local duration=Clamp(p.duration,5,2,10);local ttl=Clamp(p.ttl,20,2,60)
    if not duration or not ttl then return end
    -- an optional bar: a fixed fill (progress, 0 to 1) or one that drains by itself (countdown, seconds), not both
    if type(p.progress)~="nil" and type(p.countdown)~="nil" then return end
    local progress,countdown,barColor
    if type(p.progress)~="nil" then progress=Clamp(p.progress,nil,0,1);if not progress then return end end
    if type(p.countdown)~="nil" then countdown=Clamp(p.countdown,nil,1,3600);if not countdown then return end end
    if type(p.barColor)~="nil" then
        if not Read(p.barColor,"string") or not colorMap[p.barColor] or (not progress and not countdown) then return end
        barColor=p.barColor
    end
    return {title=p.title,text=p.text or "",caption=p.caption,icon=p.icon,group=group,duration=duration,ttl=ttl,feature=p.feature,
        progress=progress,countdown=countdown,barColor=barColor}
end
local function Equal(a,b)
    for k,v in pairs(a) do if b[k]~=v then return false end end
    for k,v in pairs(b) do if a[k]~=v then return false end end
    return true
end
local function Key(id,key) return "extension:"..id..":"..key end
-- Bubble art the player can pick from: Island's own glyphs plus a set made for extensions.
-- Each id is a file in Media (white on transparent), tinted by the chosen color.
local artList={
    {id="Potion",name=L["Potion"]},{id="Cup",name=L["Drink"]},{id="Flask",name=L["Flask"]},{id="Heart",name=L["Heart"]},
    {id="Skull",name=L["Skull"]},{id="Sword",name=L["Sword"]},{id="Shield",name=L["Shield"]},{id="Hammer",name=L["Hammer"]},
    {id="Flame",name=L["Flame"]},{id="Bolt",name=L["Lightning"]},{id="Snowflake",name=L["Snowflake"]},{id="Drop",name=L["Drop"]},
    {id="Gem",name=L["Gem"]},{id="Crown",name=L["Crown"]},{id="Key",name=L["Key"]},{id="Scroll",name=L["Scroll"]},
    {id="Book",name=L["Book"]},{id="Eye",name=L["Eye"]},{id="Hourglass",name=L["Hourglass"]},{id="Clock",name=L["Clock"]},
    {id="Bell",name=L["Bell"]},{id="Alert",name=L["Alert"]},{id="Star",name=L["Star"]},{id="Check",name=L["Check"]},
    {id="Plus",name=L["Plus"]},{id="Coin",name=L["Coin"]},{id="Bag",name=L["Bag"]},{id="Pouch",name=L["Pouch"]},
    {id="Chest",name=L["Chest"]},{id="Armor",name=L["Armor"]},{id="Herb",name=L["Herb"]},{id="Ore",name=L["Ore"]},
    {id="Fish",name=L["Fish"]},{id="Paw",name=L["Paw"]},{id="Quiver",name=L["Quiver"]},{id="Shuriken",name=L["Shuriken"]},
    {id="Person",name=L["Person"]},{id="Chat",name=L["Chat"]},{id="Mail",name=L["Mail"]},{id="Speaker",name=L["Speaker"]},
    {id="Home",name=L["Home"]},{id="Door",name=L["Door"]},{id="Flag",name=L["Flag"]},{id="Compass",name=L["Compass"]},
    {id="Plane",name=L["Plane"]},{id="Moon",name=L["Moon"]},{id="Gear",name=L["Gear"]},{id="Power",name=L["Power"]},
}
local artMap={}
for _,a in ipairs(artList) do artMap[a.id]=a end
-- "original" keeps whatever icon the extension sent; "default" keeps the normal bubble tint
local colorList={
    {id="default",name=L["Default"]},{id="accent",name=L["BanzaiSland accent"]},{id="white",name=L["White"],rgb={1,1,1}},
    {id="red",name=L["Red"],rgb={.96,.36,.36}},{id="orange",name=L["Orange"],rgb={.98,.60,.26}},
    {id="yellow",name=L["Yellow"],rgb={.98,.83,.30}},{id="green",name=L["Green"],rgb={.36,.84,.50}},
    {id="teal",name=L["Teal"],rgb={.30,.82,.80}},{id="blue",name=L["Blue"],rgb={.36,.62,.98}},
    {id="purple",name=L["Purple"],rgb={.67,.51,.98}},{id="pink",name=L["Pink"],rgb={.98,.53,.78}},
    {id="grey",name=L["Grey"],rgb={.62,.65,.72}},
}
colorMap={}
for _,c in ipairs(colorList) do colorMap[c.id]=c end
-- Optional features declared at registration: up to eight switches, each for one kind of output.
-- the sounds a feature can suggest or the player can pick: Island's own list (none is "no sound")
local soundKeys={whisper=true,chime=true,ping=true,bell=true,horn=true,alert=true,friend=true}
local featureFields={id=true,kind=true,name=true,description=true,default=true,art=true,color=true,place=true,sound=true}
local placeNames={pinned=true,bubble=true}
local function Features(list)
    if type(list)=="nil" then return {},{} end
    if not Plain(list) then return end
    local n=0
    for k in pairs(list) do
        if not Number(k) or k<1 or k%1~=0 then return end
        n=n+1
    end
    if n>8 or n~=#list then return end
    local out,map={},{}
    for i=1,n do
        local f=list[i]
        if not Fields(f,featureFields) or not Id(f.id) or map[f.id] then return end
        if not Read(f.kind,"string") or (f.kind~="card" and f.kind~="bubble") then return end
        if not Text(f.name,64) or f.name=="" then return end
        if type(f.description)~="nil" and not Text(f.description,160) then return end
        if type(f.default)~="nil" and not Read(f.default,"boolean") then return end
        local e={id=f.id,kind=f.kind,name=f.name,description=f.description or "",default=f.default~=false}
        -- a suggested look for a card or bubble feature; the player can change it
        if type(f.sound)~="nil" then
            if not Read(f.sound,"string") or not soundKeys[f.sound] then return end
            e.sound=f.sound
        end
        if type(f.place)~="nil" then
            if f.kind~="bubble" or not Read(f.place,"string") or not placeNames[f.place] then return end
            e.place=f.place
        end
        if type(f.art)~="nil" or type(f.color)~="nil" then
            if type(f.art)~="nil" then
                if not Read(f.art,"string") or not artMap[f.art] then return end
                e.art=f.art
            end
            if type(f.color)~="nil" then
                if not Read(f.color,"string") or not colorMap[f.color] then return end
                e.color=f.color
            end
        end
        out[i]=e;map[f.id]=e
    end
    return out,map
end
local function Signature(list)
    local parts={}
    for i,f in ipairs(list) do parts[i]=table.concat({f.id,f.kind,f.name,f.description,tostring(f.default),tostring(f.art),tostring(f.color),tostring(f.place),tostring(f.sound)},"\1") end
    return table.concat(parts,"\2")
end
local function SettingSignature(list)
    local parts={}
    for i,d in ipairs(list) do
        local c={}
        for j,x in ipairs(d.choices or {}) do c[j]=x.id.."\3"..x.name end
        parts[i]=table.concat({d.key,d.type,d.name,d.description,tostring(d.default),tostring(d.min),tostring(d.max),tostring(d.step),table.concat(c,"\4")},"\1")
    end
    return table.concat(parts,"\2")
end
-- Optional settings declared at registration: up to twelve toggles, sliders and choices.
-- Declarative only: Island draws the controls and the extension reads the value with GetSetting.
local settingFields={key=true,type=true,name=true,description=true,default=true,min=true,max=true,step=true,choices=true}
local choiceFields={id=true,name=true}
local function Snap(s,v)
    v=math.max(s.min,math.min(s.max,v))
    v=s.min+math.floor((v-s.min)/s.step+.5)*s.step
    return tonumber(string.format("%.6g",math.max(s.min,math.min(s.max,v))))
end
local function Choices(list)
    if not Plain(list) then return end
    local n=0
    for k in pairs(list) do
        if not Number(k) or k<1 or k%1~=0 then return end
        n=n+1
    end
    if n<2 or n>8 or n~=#list then return end
    local out,map={},{}
    for i=1,n do
        local c=list[i]
        if not Fields(c,choiceFields) or not Id(c.id) or map[c.id] or not Text(c.name,64) or c.name=="" then return end
        out[i]={id=c.id,name=c.name};map[c.id]=true
    end
    return out,map
end
local function Settings(list)
    if type(list)=="nil" then return {},{} end
    if not Plain(list) then return end
    local n=0
    for k in pairs(list) do
        if not Number(k) or k<1 or k%1~=0 then return end
        n=n+1
    end
    if n>12 or n~=#list then return end
    local out,map={},{}
    for i=1,n do
        local d=list[i]
        if not Fields(d,settingFields) or not Id(d.key) or map[d.key] then return end
        if not Text(d.name,64) or d.name=="" then return end
        if type(d.description)~="nil" and not Text(d.description,160) then return end
        local e={key=d.key,type=d.type,name=d.name,description=d.description or ""}
        if d.type=="toggle" then
            if d.min~=nil or d.max~=nil or d.step~=nil or d.choices~=nil then return end
            if type(d.default)~="nil" and not Read(d.default,"boolean") then return end
            e.default=d.default==true
        elseif d.type=="slider" then
            if d.choices~=nil or not Number(d.min) or not Number(d.max) or not Number(d.step) then return end
            if d.max<=d.min or d.step<=0 or (d.max-d.min)/d.step>1000 then return end
            e.min,e.max,e.step=d.min,d.max,d.step
            if type(d.default)=="nil" then e.default=d.min
            elseif Number(d.default) and d.default>=d.min and d.default<=d.max then e.default=Snap(e,d.default)
            else return end
        elseif d.type=="choice" then
            if d.min~=nil or d.max~=nil or d.step~=nil then return end
            local choices,cmap=Choices(d.choices)
            if not choices then return end
            e.choices,e.choiceMap=choices,cmap
            if type(d.default)=="nil" then e.default=choices[1].id
            elseif Read(d.default,"string") and cmap[d.default] then e.default=d.default
            else return end
        else
            return
        end
        out[i]=e;map[d.key]=e
    end
    return out,map
end
local function Available(r) return r.audience=="both" or r.audience==ns.Client.kind end
local function Preferences()
    if not ns.db then return end
    if type(ns.db.extensions)~="table" then ns.db.extensions={version=1,enabled={}} end
    local p=ns.db.extensions
    -- Core's legacy default filler copies tables as RGB arrays, yielding {} here.
    -- Migrate that unversioned namespace without losing explicit enabled choices.
    if p.version==nil then p.version=1 end
    if p.version~=1 then return end -- do not overwrite a newer preferences schema
    if type(p.enabled)~="table" then p.enabled={} end
    if type(p.features)~="table" then p.features={} end
    if type(p.settings)~="table" then p.settings={} end
    if type(p.looks)~="table" then p.looks={} end
    return p
end
local function Enabled(r)
    local p=Preferences()
    return Available(r) and p~=nil and p.enabled[r.id]~=false
end
-- a feature is on when the player chose so, else by the extension's own default
local function FeatureOn(r,fid)
    local f=r.featureMap[fid]
    if not f then return false end
    local p=Preferences()
    local mine=p and p.features[r.id]
    local v
    if type(mine)=="table" then v=mine[fid] end
    if type(v)=="boolean" then return v end
    return f.default
end
-- the art and color a bubble feature uses: the player's pick, else the extension's suggestion, else the extension's own icon
local function Look(r,fid)
    local f=fid and r.featureMap[fid]
    local p=Preferences()
    local mine=p and p.looks[r.id]
    mine=type(mine)=="table" and type(mine[fid])=="table" and mine[fid] or nil
    local art,color,place,stay,sound
    if mine then
        if Read(mine.stay,"boolean") then stay=mine.stay end
        if Read(mine.sound,"string") and (mine.sound=="none" or soundKeys[mine.sound]) then sound=mine.sound end
        if Read(mine.art,"string") and (mine.art=="original" or artMap[mine.art]) then art=mine.art end
        if Read(mine.color,"string") and colorMap[mine.color] then color=mine.color end
        if Read(mine.place,"string") and placeNames[mine.place] then place=mine.place end
    end
    return art or (f and f.art) or "original",color or (f and f.color) or "default",place or (f and f.place) or "pinned",stay==true,sound or (f and f.sound) or "none"
end
-- the sound id for a new card or bubble of this feature, or nil: nothing chosen, none wanted, or one just played.
-- It is played through Island's own switches (the sound master switch and the card group's switch).
local function Chime(r,fid)
    if not fid or not ns.SoundId then return end
    local _,_,_,_,sound=Look(r,fid)
    if sound=="none" then return end
    local now=GetTime()
    if r.soundAt and now-r.soundAt<3 then return end
    r.soundAt=now
    return ns.SoundId(sound)
end
-- the player's value when it is valid for the declared setting, else the extension's default
local function SettingValue(r,key)
    local d=r.settingMap[key]
    if not d then return end
    local p=Preferences()
    local mine=p and p.settings[r.id]
    local v
    if type(mine)=="table" then v=mine[key] end
    if d.type=="toggle" then
        if type(v)=="boolean" then return v end
    elseif d.type=="slider" then
        if Number(v) and v>=d.min and v<=d.max then return Snap(d,v) end
    elseif type(v)=="string" and d.choiceMap[v] then
        return v
    end
    return d.default
end
local function FeatureOk(r,payload) return not payload.feature or FeatureOn(r,payload.feature) end
local function Reject(r,why)
    r.rejected=math.min(1000000,r.rejected+1);r.lastReason=why
    if why=="rate_limited" then r.limited=math.min(1000000,r.limited+1) end
    return false,why
end
local function Take(r)
    local now=GetTime()
    r.bucket.tokens=math.min(3,r.bucket.tokens+math.max(0,now-r.bucket.at)*.5);r.bucket.at=now
    globalBucket.tokens=math.min(10,globalBucket.tokens+math.max(0,now-globalBucket.at)*5);globalBucket.at=now
    if r.bucket.tokens<1 or globalBucket.tokens<1 then return false end
    r.bucket.tokens=r.bucket.tokens-1;globalBucket.tokens=globalBucket.tokens-1;return true
end
local function Match(item,id,key)
    return item and item.extensionOwner==id and (key==nil or item.extensionKey==key)
end
local function Preview(method,id,key)
    local found=false
    if ns.Voice and ns.Voice[method] then found=ns.Voice[method](id,key) or found end
    local d=type(ns.Retail)=="table" and ns.Retail.Dialogue
    if d and d[method] then found=d[method](id,key) or found end
    return found
end
local function Present(id,key)
    if Match(I.current,id,key) then return true end
    for _,list in ipairs({I.queue or {},I.held or {}}) do
        for _,item in ipairs(list) do if Match(item,id,key) then return true end end
    end
    return Preview("HasExtension",id,key)
end
local function Remove(id,key)
    for _,list in ipairs({I.queue or {},I.held or {}}) do
        for n=#list,1,-1 do if Match(list[n],id,key) then table.remove(list,n) end end
    end
    Preview("RemoveExtension",id,key)
    if Match(I.current,id,key) then
        I.current=nil
        if I.built then I:Pump() end
    end
end
local function ClearFeature(id,fid)
    for k,r in pairs(records) do if r.id==id and r.payload.feature==fid then records[k]=nil;Remove(id,r.key) end end
    for k,b in pairs(bubbles) do if b.id==id and b.payload.feature==fid then bubbles[k]=nil;I:SetActivity(k,nil) end end
end
local function Clear(id)
    -- Remove records first: a reentrant Pump must never revive another owned card.
    for k,r in pairs(records) do if r.id==id then records[k]=nil end end
    for k,b in pairs(bubbles) do if b.id==id then bubbles[k]=nil;I:SetActivity(k,nil) end end
    Remove(id)
end
function E.Valid(item)
    if not item.extensionOwner or item.replay then return true end
    local r=registry[item.extensionOwner]
    local rec=records[Key(item.extensionOwner,item.extensionKey)]
    return r and Enabled(r) and rec and FeatureOk(r,rec.payload) and (Match(I.current,r.id,rec.key) or GetTime()<rec.expires) and true or false
end
sweep=function()
    local now=GetTime()
    for k,rec in pairs(records) do
        if not Enabled(registry[rec.id]) or not FeatureOk(registry[rec.id],rec.payload) or (not Match(I.current,rec.id,rec.key) and now>=rec.expires) then
            records[k]=nil;Remove(rec.id,rec.key)
        elseif not Present(rec.id,rec.key) then records[k]=nil end
    end
    for k,b in pairs(bubbles) do
        if now>=b.expires or not Enabled(registry[b.id]) or not FeatureOk(registry[b.id],b.payload) then bubbles[k]=nil;I:SetActivity(k,nil) end
    end
    if not next(records) and not next(bubbles) then frame:SetScript("OnUpdate",nil) end
end
Wake=function()
    local elapsed=0
    if frame:GetScript("OnUpdate") then return end
    frame:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        if elapsed>=.25 then elapsed=0;sweep() end
    end)
end
local function Check(r,key,p,bubble)
    if not Id(key) then return Reject(r,"invalid_payload") end
    local normalized=Normalize(p,bubble)
    if not normalized then return Reject(r,"invalid_payload") end
    if normalized.feature then
        local f=r.featureMap[normalized.feature]
        if not f or f.kind~=(bubble and "bubble" or "card") then return Reject(r,"invalid_payload") end
    end
    if not Available(r) then return Reject(r,"unavailable_client") end
    if not ready or not I.built or not ns.db then return Reject(r,"not_ready") end
    if not Enabled(r) then return Reject(r,"disabled") end
    -- a switched-off feature is not an error: nothing is queued, no token is spent, it is only counted
    if normalized.feature and not FeatureOn(r,normalized.feature) then
        r.suppressed=math.min(1000000,r.suppressed+1)
        return false,"feature_disabled"
    end
    return normalized
end
local function Count(list,id)
    local mine,total=0,0
    for _,entry in pairs(list) do total=total+1;if entry.id==id then mine=mine+1 end end
    return mine,total
end
-- the tint for a chosen color: an rgb table, Island's accent, or nil for the normal tint
local function Tone(color)
    if color=="accent" then return ns.Accent(),true end
    local c=colorMap[color]
    return c and c.rgb or nil,c and c.rgb~=nil
end
-- a bubble is persistent when the extension sent it so, or the player chose to keep it up
local function Persistent(r,n)
    if n.countdown then return false end -- it ends by itself, whatever the player chose for the feature
    if n.persistent then return true end
    local _,_,_,stay=Look(r,n.feature)
    return stay
end
local function TimeLeft(sec)
    sec=math.max(0,math.floor(sec+.5))
    if sec>=3600 then return string.format("%d:%02d:%02d",math.floor(sec/3600),math.floor(sec/60)%60,sec%60) end
    return string.format("%d:%02d",math.floor(sec/60),sec%60)
end
-- a countdown: when it ends, or the time left while it is paused
local function NewTimer(seconds) return {total=seconds,ends=GetTime()+seconds} end
local function Left(t)
    if t.paused then return t.left end
    return math.max(0,t.ends-GetTime())
end
local MAX_PAUSE=600 -- a paused bubble is removed after ten minutes, so a forgotten pause cannot hold a slot for ever
local function BubbleAct(r,n,timer,barState)
    local art,color,place=Look(r,n.feature)
    local act={texture=n.icon,glyph="Bell",tone=C.muted,priority=1,static=true,
        tip=r.name,tip2=n.tooltip,text=function() return n.text end}
    if n.countdown and timer then
        -- not static: Island keeps redrawing the text while it counts down
        act.static=nil
        act.text=function() return (n.text~="" and (n.text.." ") or "")..TimeLeft(Left(timer)) end
    end
    if n.progress or (n.countdown and n.bar and timer) then
        act.progress=n.progress and function() return n.progress end or function() return Left(timer)/timer.total end
        act.noEase=n.progress==nil
        act.barState=barState
        local bt=Tone(n.barColor);if bt then act.barTone=bt end
        if n.progress then act.static=nil end -- keep the bubble refreshing so its bar can ease
    end
    if art~="original" then act.texture=nil;act.glyph=art;act.tone=C.fg end
    if color=="accent" then act.accentTone=true
    elseif colorMap[color] and colorMap[color].rgb then act.tone=colorMap[color].rgb;act.fixedTone=true end
    -- a persistent bubble can sit in the pinned slots (default) or with the coming-and-going bubbles
    if Persistent(r,n) and place=="pinned" then act.extPin=true end
    return act
end
-- re-draw this feature's live bubbles with the current look
local function Restyle(r,fid)
    for k,b in pairs(bubbles) do
        if b.id==r.id and b.payload.feature==fid and Enabled(r) then
            local keep=Persistent(r,b.payload)
            if keep~=b.persistent then
                b.persistent=keep
                b.expires=keep and math.huge or GetTime()+(b.payload.ttl or 60)
            end
            I:SetActivity(k,BubbleAct(r,b.payload,b.timer,b.barState))
        end
    end
end
local function Submit(r,key,p,bubble)
    local n,why=Check(r,key,p,bubble);if not n then return false,why end
    sweep()
    local k=Key(r.id,key);local list=bubble and bubbles or records
    local old=list[k]
    -- Updates, including duplicates, still consume a token. Duplicates never extend lifetimes.
    if not Take(r) then return Reject(r,"rate_limited") end
    if old and Equal(n,old.payload) then return true,"accepted" end
    local mine,total=Count(list,r.id)
    if not old and (mine>=(bubble and 2 or 5) or total>=(bubble and 10 or 20)) then return Reject(r,"capacity") end
    -- persistent bubbles never expire, so they have a smaller share: two per extension, six in all
    local keep=bubble and Persistent(r,n)
    if keep and not (old and old.persistent) then
        local pm,pt=0,0
        for _,b in pairs(bubbles) do if b.persistent then pt=pt+1;if b.id==r.id then pm=pm+1 end end end
        if pm>=2 or pt>=6 then return Reject(r,"capacity") end
    end
    if bubble then
        local timer=n.countdown and NewTimer(n.countdown) or nil
        bubbles[k]={id=r.id,key=key,payload=n,persistent=keep,timer=timer,barState=old and old.barState or {},expires=keep and math.huge or GetTime()+(n.ttl or n.countdown)}
        I:SetActivity(k,BubbleAct(r,n,timer,bubbles[k].barState))
        if not old and not (ns.db and ns.db.dnd) then
            local id=Chime(r,n.feature)
            if id and ns.PlayCardSound then ns.PlayCardSound(id,{},"alerts") end
        end
    else
        local timer
        local item={kind="won",key=k,extensionOwner=r.id,extensionKey=key,extensionName=r.name,
            title=n.title,line=n.text,cap=n.caption or r.name,icon=n.icon,
            group=n.group,hold=n.duration,color=C.fg,capColor=C.muted,onClick=false}
        -- the player's art and color (or the extension's suggestion) replace the icon; "original" keeps the icon sent
        local art,color=Look(r,n.feature)
        local tone=Tone(color)
        if art~="original" then item.icon=nil;item.glyph=art;item.tone=tone or C.fg
        elseif not n.icon then item.glyph="Bell";item.tone=tone or C.muted end
        if n.progress or n.countdown then
            -- the card's own bar, drawn by Island. A countdown drains on its own from the moment this card was accepted.
            local fill=n.progress
            timer=n.countdown and NewTimer(n.countdown) or nil
            item.progress=function() if timer then return Left(timer)/timer.total end return fill end
            local bt=Tone(n.barColor);if bt then item.barTone=bt end
            item.barBelow=true
            item.barSmooth=n.progress~=nil -- a fixed fill eases to its next value; a countdown already moves smoothly
            -- the bar must not change which card style this is, so say it outright
            if timer then
                -- the time left, on the right of the card, ticking by itself
                item.live=function() local left=Left(timer) return left>=60 and TimeLeft(left) or string.format("%ds",math.ceil(left)) end
            end
            item.builderType=(n.group=="loot" and "loot") or (n.group=="social" and "social") or (n.group=="world" and "progress") or "alerts"
        end
        records[k]={id=r.id,key=key,payload=n,timer=timer,expires=GetTime()+n.ttl}
        -- Remove an old preview/held representation before submitting its new location.
        -- Active cards can be safely rewritten by the standard renderer.
        if not old and not (ns.db and ns.db.dnd) then item.sound=Chime(r,n.feature) end
        if not Match(I.current,r.id,key) then Remove(r.id,key) end
        local ok=pcall(I.PushReplace,I,item)
        if not ok then records[k]=nil;Remove(r.id,key);return Reject(r,"adapter_error") end
        if not Present(r.id,key) then records[k]=nil end -- e.g. DND records only, or full native queue
    end
    if n.icon~=nil then r.icons[bubble and "bubble" or "card"]=n.icon end -- remembered for the settings page
    r.accepted=math.min(1000000,r.accepted+1);r.lastReason=nil;Wake()
    return true,"accepted"
end
local function Status(r)
    return {id=r.id,name=r.name,audience=r.audience,available=Available(r),enabled=Enabled(r),
        ready=ready and I.built and ns.db~=nil and true or false,accepted=r.accepted,rejected=r.rejected,
        rateLimited=r.limited,featureDisabled=r.suppressed,lastReason=r.lastReason}
end
local API={version=1,capabilities={features=true,settings=true,art=true,persistentBubbles=true,progress=true,countdownBubbles=true,pauseCountdown=true}}
function API.IsReady() return ready and I.built and ns.db~=nil and true or false end
-- the checks a registration goes through, without registering (also used to vet saved packages)
local function Parse(id,metadata)
    if not Id(id) or not Fields(metadata,{apiVersion=true,name=true,audience=true,features=true,settings=true})
        or not Text(metadata.name,64) or metadata.name=="" then return nil,"invalid_payload" end
    if not Number(metadata.apiVersion) or metadata.apiVersion~=1 then return nil,"unsupported_version" end
    if not Read(metadata.audience,"string") or (metadata.audience~="both" and metadata.audience~="retail" and metadata.audience~="forever") then return nil,"invalid_payload" end
    local features,featureMap=Features(metadata.features)
    if not features then return nil,"invalid_payload" end
    local settings,settingMap=Settings(metadata.settings)
    if not settings then return nil,"invalid_payload" end
    return features,featureMap,settings,settingMap
end
-- true plus the kind of each declared feature, or nil and the reason; nothing is registered
function E.CheckMetadata(id,metadata)
    local features,featureMap,settings=Parse(id,metadata)
    if not features then return nil,featureMap end
    local kinds={}
    for fid,f in pairs(featureMap) do kinds[fid]=f.kind end
    return true,kinds,#settings
end
function E.Signature(metadata)
    local features,_,settings=Parse("check",metadata)
    if not features then return end
    return metadata.name.."\5"..Signature(features).."\5"..SettingSignature(settings)
end
local function Register(id,metadata)
    local features,featureMap,settings,settingMap=Parse(id,metadata)
    if not features then return nil,featureMap end
    local old=registry[id]
    if old then
        if old.name==metadata.name and old.audience==metadata.audience and old.signature==Signature(features)
            and old.settingSignature==SettingSignature(settings) then return old.handle end
        return nil,"already_registered"
    end
    if totalRegistered>=32 then return nil,"capacity" end
    local r={id=id,name=metadata.name,audience=metadata.audience,accepted=0,rejected=0,limited=0,suppressed=0,features=features,featureMap=featureMap,icons={},
        settings=settings,settingMap=settingMap,signature=Signature(features),settingSignature=SettingSignature(settings),bucket={tokens=3,at=GetTime()}}
    local h={}
    function h:IsEnabled() return Enabled(r) end
    function h:GetStatus() return Status(r) end
    function h:IsFeatureEnabled(fid) return Id(fid) and Enabled(r) and FeatureOn(r,fid) or false end
    function h:GetSetting(key) if not Id(key) then return nil end return SettingValue(r,key) end
    function h:ShowCard(key,payload) return Submit(r,key,payload,false) end
    function h:SetBubble(key,payload) return Submit(r,key,payload,true) end
    function h:DismissCard(key)
        if not Id(key) then return Reject(r,"invalid_payload") end
        records[Key(id,key)]=nil;Remove(id,key);sweep();return true,"accepted"
    end
    function h:RemoveBubble(key)
        if not Id(key) then return Reject(r,"invalid_payload") end
        local k=Key(id,key);bubbles[k]=nil;I:SetActivity(k,nil);sweep();return true,"accepted"
    end
    -- stop a countdown where it is, or let it run again. They apply to the bubble and the card with that key.
    local function Hold(key,pause)
        if not Id(key) then return false,"invalid_payload" end
        local k=Key(id,key);local found=false
        local b=bubbles[k]
        if b and b.timer then
            found=true
            local t=b.timer
            if pause and not t.paused then t.left=Left(t);t.paused=true;b.expires=GetTime()+MAX_PAUSE
            elseif not pause and t.paused then t.ends=GetTime()+t.left;t.paused=nil;t.left=nil;b.expires=t.ends end
        end
        local c=records[k]
        if c and c.timer then
            found=true
            local t=c.timer
            if pause and not t.paused then t.left=Left(t);t.paused=true
            elseif not pause and t.paused then t.ends=GetTime()+t.left;t.paused=nil;t.left=nil end
        end
        if not found then return false,"not_found" end
        return true,"accepted"
    end
    function h:PauseCountdown(key) return Hold(key,true) end
    function h:ResumeCountdown(key) return Hold(key,false) end
    function h:Clear() Clear(id);sweep();return true,"accepted" end
    r.handle=h;registry[id]=r;totalRegistered=totalRegistered+1
    if E.OnChanged then pcall(E.OnChanged) end
    return h
end
-- Registrations that were refused, newest last: a plain record of what went wrong, so the page can say
-- why an extension is missing. Nothing the caller sent is kept beyond a checked id and name.
local failures={}
local function NoteFailure(id,metadata,why)
    local fid=Id(id) and id or "?"
    local name
    if type(metadata)=="table" then
        local ok,v=pcall(function() return metadata.name end)
        if ok and Text(v,64) and v~="" then name=v end
    end
    for i,f in ipairs(failures) do
        if f.id==fid and f.reason==why then f.count=f.count+1;f.name=name or f.name;table.remove(failures,i);failures[#failures+1]=f;return end
    end
    failures[#failures+1]={id=fid,name=name,reason=why,count=1}
    if #failures>20 then table.remove(failures,1) end
end
function API.Register(id,metadata)
    local handle,why=Register(id,metadata)
    if not handle then NoteFailure(id,metadata,why) end
    return handle,why
end
BanzaiSlandAPI=API
function E.Failures()
    local list={}
    for i=#failures,1,-1 do local f=failures[i];list[#list+1]={id=f.id,name=f.name,reason=f.reason,count=f.count} end
    return list
end
-- Addons whose TOC says `## X-BanzaiSland-Extension: 1` but that have not registered, with the reason the
-- game gives. Looked up from the addon list (cached for a few seconds: it is read on a ticker).
local scanned,scannedAt
local LOAD={DISABLED="disabled",DEP_DISABLED="dependency",DEP_MISSING="dependency",DEP_BANNED="dependency",DEP_CORRUPT="dependency",
    DEP_INCOMPATIBLE="dependency",DEP_INTERFACE_VERSION="dependency",INTERFACE_VERSION="outdated",INCOMPATIBLE="outdated",
    MISSING="broken",CORRUPT="broken",BANNED="broken"}
function E.Unregistered(force)
    local now=GetTime()
    if scanned and not force and scannedAt and now-scannedAt<5 then return scanned end
    local out={}
    local api=_G.C_AddOns
    local count=(api and api.GetNumAddOns) or GetNumAddOns
    local info=(api and api.GetAddOnInfo) or GetAddOnInfo
    local meta=(api and api.GetAddOnMetadata) or GetAddOnMetadata
    local loaded=(api and api.IsAddOnLoaded) or IsAddOnLoaded
    if type(count)=="function" and type(info)=="function" and type(meta)=="function" then
        local okc,n=pcall(count)
        for i=1,(okc and Number(n) and math.min(n,500) or 0) do
            local ok,a,title,_,_,reason=pcall(info,i)
            local name,why=a,reason
            if ok and type(a)=="table" then name,title,why=a.name,a.title,a.reason end
            if ok and Id(name) and not registry[name] then
                local okm,tag=pcall(meta,name,"X-BanzaiSland-Extension")
                if okm and tag=="1" then
                    local key=LOAD[why or ""]
                    if not key then
                        local okl,isLoaded=pcall(loaded,name)
                        key=(okl and isLoaded) and "noregister" or "notloaded"
                    end
                    local t=Read(title,"string") and title:gsub("[%c|]",""):sub(1,64) or name
                    out[#out+1]={id=name,title=t,reason=key}
                end
            end
        end
        table.sort(out,function(x,y) return x.id<y.id end)
    end
    scanned,scannedAt=out,now
    return out
end
function E.List()
    local list={}
    for _,r in pairs(registry) do if Available(r) then list[#list+1]=Status(r) end end
    table.sort(list,function(a,b) return a.id<b.id end);return list
end
function E.SetEnabled(id,value)
    local r=registry[id];local p=Preferences()
    if not r or not Available(r) or not p or type(value)~="boolean" then return end
    p.enabled[id]=value
    if not value then Clear(id);sweep() end
end
-- the features an extension declared, with the player's current choice (for the settings page)
function E.Features(id)
    local r=registry[id];local list={}
    if not r or not Available(r) then return list end
    for _,f in ipairs(r.features) do
        list[#list+1]={id=f.id,kind=f.kind,name=f.name,description=f.description,default=f.default,enabled=FeatureOn(r,f.id)}
    end
    return list
end
function E.SetFeature(id,fid,value)
    local r=registry[id];local p=Preferences()
    if not r or not Available(r) or not p or type(value)~="boolean" or not r.featureMap[fid] then return end
    if type(p.features[id])~="table" then p.features[id]={} end
    p.features[id][fid]=value
    if not value then ClearFeature(id,fid);sweep() end
end
-- the settings an extension declared, with the player's current value (for the settings page)
function E.Settings(id)
    local r=registry[id];local list={}
    if not r or not Available(r) then return list end
    for _,d in ipairs(r.settings) do
        local choices
        if d.choices then choices={};for i,c in ipairs(d.choices) do choices[i]={id=c.id,name=c.name} end end
        list[#list+1]={key=d.key,type=d.type,name=d.name,description=d.description,default=d.default,
            min=d.min,max=d.max,step=d.step,choices=choices,value=SettingValue(r,d.key)}
    end
    return list
end
function E.SetSetting(id,key,value)
    local r=registry[id];local p=Preferences()
    local d=r and r.settingMap[key]
    if not r or not Available(r) or not p or not d then return false end
    if d.type=="toggle" then
        if type(value)~="boolean" then return false end
    elseif d.type=="slider" then
        if not Number(value) then return false end
        value=Snap(d,value)
    elseif not Read(value,"string") or not d.choiceMap[value] then
        return false
    end
    if type(p.settings[id])~="table" then p.settings[id]={} end
    p.settings[id][key]=value
    return true
end
-- back to the extension's own defaults for its features and settings; the master switch is left alone
function E.ResetDefaults(id)
    local r=registry[id];local p=Preferences()
    if not r or not Available(r) or not p then return false end
    p.settings[id]=nil;p.features[id]=nil;p.looks[id]=nil
    for _,f in ipairs(r.features) do if not f.default then ClearFeature(id,f.id) end end
    sweep()
    for _,f in ipairs(r.features) do if f.kind=="bubble" then Restyle(r,f.id) end end
    return true
end
-- the art library and the colors, for the picker
function E.Art() local list={};for i,a in ipairs(artList) do list[i]={id=a.id,name=a.name} end return list end
-- the sounds for the picker, in Island's order, "none" first
function E.Sounds()
    local list={{id="none",name=L["None"]}}
    for _,s in ipairs(ns.SOUNDS or {}) do if soundKeys[s.key] then list[#list+1]={id=s.key,name=s.name} end end
    return list
end
function E.Colors() local list={};for i,c in ipairs(colorList) do list[i]={id=c.id,name=c.name,rgb=c.rgb} end return list end
-- what a bubble feature looks like now; `custom` says the player changed it
function E.Look(id,fid)
    local r=registry[id]
    if not r or not Available(r) or not r.featureMap[fid] or r.featureMap[fid].kind==nil then return end
    local art,color,place,stay,sound=Look(r,fid)
    local p=Preferences();local mine=p and p.looks[id] and p.looks[id][fid]
    return {art=art,color=color,place=place,kind=r.featureMap[fid].kind,stay=stay,sound=sound,custom=type(mine)=="table" and (mine.art~=nil or mine.color~=nil or mine.place~=nil or mine.stay~=nil or mine.sound~=nil)}
end
function E.SetLook(id,fid,art,color,place,stay,sound)
    local r=registry[id];local p=Preferences()
    if not r or not Available(r) or not p or not r.featureMap[fid] or r.featureMap[fid].kind==nil then return false end
    if art~=nil and not (Read(art,"string") and (art=="original" or artMap[art])) then return false end
    if color~=nil and not (Read(color,"string") and colorMap[color]) then return false end
    if place~=nil and not (r.featureMap[fid].kind=="bubble" and Read(place,"string") and placeNames[place]) then return false end
    if stay~=nil and not (r.featureMap[fid].kind=="bubble" and Read(stay,"boolean")) then return false end
    if sound~=nil and not (Read(sound,"string") and (sound=="none" or soundKeys[sound])) then return false end
    if type(p.looks[id])~="table" then p.looks[id]={} end
    if type(p.looks[id][fid])~="table" then p.looks[id][fid]={} end
    local mine=p.looks[id][fid]
    if art~=nil then mine.art=art end
    if color~=nil then mine.color=color end
    if place~=nil then mine.place=place end
    if stay~=nil then mine.stay=stay end
    if sound~=nil then mine.sound=sound end
    Restyle(r,fid)
    return true
end
-- the picture the settings page shows for an extension: the card's art, else the bubble's.
-- A chosen glyph wins; "the extension's own icon" uses the last icon it sent. nil = use the addon's TOC icon.
function E.Icon(id)
    local r=registry[id]
    if not r or not Available(r) then return end
    for _,kind in ipairs({"card","bubble"}) do
        for _,f in ipairs(r.features) do
            if f.kind==kind then
                local art,color=Look(r,f.id)
                if art~="original" then
                    local tone=Tone(color)
                    return {glyph=art,tone=tone or C.fg}
                end
            end
        end
        if r.icons[kind]~=nil then return {texture=r.icons[kind]} end
    end
end
function E.Clear(id) if registry[id] then Clear(id);sweep() end end
-- A package extension can be unregistered (its data lives in Island); a real addon's cannot.
function E.Remove(id)
    local r=registry[id]
    if not r or not Read(id,"string") or id:sub(1,4)~="Pkg_" then return false end
    Clear(id);sweep()
    registry[id]=nil;totalRegistered=math.max(0,totalRegistered-1)
    if E.OnChanged then pcall(E.OnChanged) end
    return true
end
function E.Report()
    local list=E.List()
    if #list==0 then ns.Print(L["No extensions registered."]) end
    for _,r in ipairs(list) do
        ns.Print(L["%s: %s; accepted %d, rejected %d, rate limited %d"]:format(r.name,
            r.enabled and L["Enabled"] or L["Disabled"],r.accepted,r.rejected,r.rateLimited))
    end
end
local function Reset()
    ready=false;epoch=epoch+1
    for id in pairs(registry) do Clear(id) end
    sweep()
end
frame:SetScript("OnEvent",function(_,event)
    if event=="LOADING_SCREEN_ENABLED" then Reset();return end
    Reset();local token=epoch
    C_Timer.After(0,function() if token==epoch then ready=true end end)
end)
for _,event in ipairs({"PLAYER_ENTERING_WORLD","LOADING_SCREEN_ENABLED","LOADING_SCREEN_DISABLED"}) do frame:RegisterEvent(event) end
