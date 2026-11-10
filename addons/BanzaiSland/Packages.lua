-- Extension packages: saved text that Island registers as a real extension at login.
-- A package is plain data (id, name, features, settings and handlers); it is never run as code until the
-- player has saved it, and a handler's Lua runs in a small sandbox unless the package asks for full Lua.
local ADDON,ns=...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
if ns.Client.kind~="forever" then return end
local L=ns.L
local K={};ns.Packages=K
local frame=CreateFrame("Frame")
local lifecycle={PLAYER_ENTERING_WORLD=true,LOADING_SCREEN_ENABLED=true,LOADING_SCREEN_DISABLED=true}
local MAX_PACKAGES,MAX_HANDLERS,MAX_BYTES,MAX_CODE=8,12,65536,8192
local handles,registered,runtime,problems={},{},{},{}
local active,epoch=false,0
local Rebuild,Run,InitAll
local function Changed() if K.OnChanged then pcall(K.OnChanged) end end
local function Readable(v) return ns.Readable(v) end
local function Str(v,limit,pattern)
    return Readable(v) and type(v)=="string" and #v<=limit and not v:find("%z") and (not pattern or v:find(pattern))~=nil
end
local function Plain(v) return Readable(v) and type(v)=="table" and getmetatable(v)==nil end
local function Error(v)
    local ok,s=pcall(tostring,v)
    return ((ok and s or L["Lua error"]):sub(1,256):gsub("|","||"))
end
local Copy
Copy=function(v,depth)
    if type(v)~="table" then return v end
    if (depth or 0)>8 then return end
    local t={}
    for k,x in next,v do t[k]=Copy(x,(depth or 0)+1) end
    return t
end

------------------------------------------------------------------------------------------------
-- A strict reader for the data text. It understands only what a package contains: tables, strings,
-- numbers, true and false. Nothing in it is ever executed.
------------------------------------------------------------------------------------------------
local MAX_DEPTH,MAX_NODES,MAX_STRING=6,4000,16384
local ESCAPES={n="\n",t="\t",r="\r",["\\"]="\\",['"']='"',["'"]="'",["\n"]="\n"}
local function Parse(text)
    if not Str(text,MAX_BYTES) then return nil,"too_big" end
    local pos,len,nodes=1,#text,0
    local function Fail(why) return nil,why or "bad_format",pos end
    local function Skip()
        while true do
            local _,e=text:find("^%s+",pos)
            if e then pos=e+1 end
            if text:sub(pos,pos+1)=="--" and text:sub(pos,pos+3)~="--[[" and text:sub(pos,pos+3)~="--[=" then
                local nl=text:find("\n",pos,true)
                pos=nl and nl+1 or len+1
            else return end
        end
    end
    local Value
    local function String()
        local q=text:sub(pos,pos)
        local out,n={},0
        if q=="[" then
            local eq=text:match("^%[(=*)%[",pos)
            if not eq then return Fail() end
            local close="]"..eq.."]"
            local from=pos+#eq+2
            if text:sub(from,from)=="\n" then from=from+1 end
            local e=text:find(close,from,true)
            if not e then return Fail() end
            local s=text:sub(from,e-1)
            if #s>MAX_STRING then return Fail("too_big") end
            pos=e+#close
            return s
        end
        pos=pos+1
        while true do
            local c=text:sub(pos,pos)
            if c=="" or c=="\n" then return Fail() end
            if c==q then pos=pos+1;break end
            if c=="\\" then
                local d=text:sub(pos+1,pos+1)
                if ESCAPES[d] then out[#out+1]=ESCAPES[d];pos=pos+2
                else
                    local digits=text:match("^%d%d?%d?",pos+1)
                    if not digits then return Fail() end
                    local code=tonumber(digits)
                    if code<1 or code>255 then return Fail() end
                    out[#out+1]=string.char(code);pos=pos+1+#digits
                end
            else
                local e=text:find("[\\\n"..q.."]",pos)
                local piece=text:sub(pos,(e or len+1)-1)
                if piece=="" then return Fail() end
                out[#out+1]=piece;pos=pos+#piece
            end
            n=n+1
            if n>MAX_STRING then return Fail("too_big") end
        end
        local s=table.concat(out)
        if #s>MAX_STRING then return Fail("too_big") end
        return s
    end
    local function Number()
        local s=text:match("^-?%d+%.?%d*[eE]?[+-]?%d*",pos)
        if not s then return Fail() end
        local v=tonumber(s)
        if not v or v~=v or v==math.huge or v==-math.huge then return Fail() end
        pos=pos+#s
        return v
    end
    local function Table(depth)
        if depth>MAX_DEPTH then return Fail("too_deep") end
        pos=pos+1
        local t,index={},0
        while true do
            Skip()
            local c=text:sub(pos,pos)
            if c=="" then return Fail() end
            if c=="}" then pos=pos+1;return t end
            local key,value
            local name=text:match("^([A-Za-z_][A-Za-z0-9_]*)%s*=[^=]",pos)
            if name then
                key=name;pos=text:find("=",pos,true)+1
                Skip()
                local why;value,why=Value(depth)
                if value==nil then return nil,why or "bad_format",pos end
            elseif c=="[" and not text:match("^%[=*%[",pos) then
                pos=pos+1;Skip()
                key=Value(depth)
                if type(key)~="string" and type(key)~="number" then return Fail() end
                Skip()
                if text:sub(pos,pos)~="]" then return Fail() end
                pos=pos+1;Skip()
                if text:sub(pos,pos)~="=" then return Fail() end
                pos=pos+1;Skip()
                local why;value,why=Value(depth)
                if value==nil then return nil,why or "bad_format",pos end
            else
                local why;value,why=Value(depth)
                if value==nil then return nil,why or "bad_format",pos end
                index=index+1;key=index
            end
            if t[key]~=nil then return Fail("duplicate") end
            t[key]=value
            Skip()
            local sep=text:sub(pos,pos)
            if sep=="," or sep==";" then pos=pos+1
            elseif sep~="}" then return Fail() end
        end
    end
    Value=function(depth)
        nodes=nodes+1
        if nodes>MAX_NODES then return Fail("too_big") end
        Skip()
        local c=text:sub(pos,pos)
        if c=="{" then return Table(depth+1)
        elseif c=='"' or c=="'" or (c=="[" and text:match("^%[=*%[",pos)) then return String()
        elseif c=="-" or c:match("^%d$") then return Number()
        elseif text:match("^true[^%w_]",pos) or text:sub(pos)=="true" then pos=pos+4;return true
        elseif text:match("^false[^%w_]",pos) or text:sub(pos)=="false" then pos=pos+5;return false end
        return Fail()
    end
    Skip()
    if text:sub(pos,pos)~="{" then return Fail() end
    local result,why,at=Value(0)
    if result==nil then return nil,why or "bad_format",at or pos end
    Skip()
    if pos<=len then return Fail("trailing") end
    return result
end
K.Parse=Parse

------------------------------------------------------------------------------------------------
-- Writing a package back out as text (the editor view and the export string)
------------------------------------------------------------------------------------------------
local function Quote(s) return (string.format("%q",s):gsub("\\\n","\\n"):gsub("\r","\\r")) end
local function LongString(s)
    s=s:gsub("\r\n?","\n")
    local n=0
    while s:find("]"..string.rep("=",n).."]",1,true) or s:find("]"..string.rep("=",n).."$") do n=n+1 end
    local eq=string.rep("=",n)
    return "["..eq.."[\n"..s.."\n]"..eq.."]"
end
local function Num(n) return string.format("%.14g",n) end
local function Scalar(v)
    if type(v)=="string" then return Quote(v) end
    if type(v)=="number" then return Num(v) end
    return tostring(v)
end
local function Fields(t,order,indent)
    local parts={}
    for _,k in ipairs(order) do
        local v=t[k]
        if v~=nil then
            if type(v)=="table" then
                local inner={}
                for _,c in ipairs(v) do inner[#inner+1]="{ id = "..Quote(c.id)..", name = "..Quote(c.name).." }" end
                parts[#parts+1]=indent..k.." = { "..table.concat(inner,", ").." },"
            else parts[#parts+1]=indent..k.." = "..Scalar(v)..",";end
        end
    end
    return table.concat(parts,"\n")
end
local PKG_ORDER={"id","name","author","version","notes","full"}
local FEATURE_ORDER={"id","kind","name","description","default","art","color","place","sound"}
local SETTING_ORDER={"key","type","name","description","default","min","max","step","choices"}
local HANDLER_ORDER={"name","events","unit","interval","feature","enabled"}
function K.Serialize(p)
    local out={"{",Fields(p,PKG_ORDER,"  ")}
    out[#out+1]="  features = {"
    for _,f in ipairs(p.features) do out[#out+1]="    {\n"..Fields(f,FEATURE_ORDER,"      ").."\n    }," end
    out[#out+1]="  },"
    out[#out+1]="  settings = {"
    for _,s in ipairs(p.settings) do out[#out+1]="    {\n"..Fields(s,SETTING_ORDER,"      ").."\n    }," end
    out[#out+1]="  },"
    out[#out+1]="  handlers = {"
    for _,h in ipairs(p.handlers) do
        out[#out+1]="    {\n"..Fields(h,HANDLER_ORDER,"      ").."\n      code = "..LongString(h.code)..",\n    },"
    end
    out[#out+1]="  },"
    out[#out+1]="}"
    return table.concat(out,"\n")
end

------------------------------------------------------------------------------------------------
-- The export string: a prefix, the text in base64 and a checksum, so a cut-off paste is noticed
------------------------------------------------------------------------------------------------
local B64="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64INDEX={}
for i=1,64 do B64INDEX[B64:sub(i,i)]=i-1 end
local function Encode(s)
    local out={}
    for i=1,#s,3 do
        local a,b,c=s:byte(i,i+2)
        local n=a*65536+(b or 0)*256+(c or 0)
        local c1,c2,c3,c4=math.floor(n/262144)%64,math.floor(n/4096)%64,math.floor(n/64)%64,n%64
        out[#out+1]=B64:sub(c1+1,c1+1)..B64:sub(c2+1,c2+1)..(b and B64:sub(c3+1,c3+1) or "=")..(c and B64:sub(c4+1,c4+1) or "=")
    end
    return table.concat(out)
end
local function Decode(s)
    if #s%4~=0 then return end
    local out={}
    for i=1,#s,4 do
        local q=s:sub(i,i+3)
        local a,b,c,d=B64INDEX[q:sub(1,1)],B64INDEX[q:sub(2,2)],B64INDEX[q:sub(3,3)],B64INDEX[q:sub(4,4)]
        local pad3,pad4=q:sub(3,3)=="=",q:sub(4,4)=="="
        if not a or not b then return end
        if pad3 and not pad4 then return end
        if (pad3 or pad4) and i+3<#s then return end
        if (not pad3 and not c) or (not pad4 and not d) then return end
        local n=a*262144+b*4096+(c or 0)*64+(d or 0)
        out[#out+1]=string.char(math.floor(n/65536)%256)
        if not pad3 then out[#out+1]=string.char(math.floor(n/256)%256) end
        if not pad4 then out[#out+1]=string.char(n%256) end
    end
    return table.concat(out)
end
local function Checksum(s)
    local a,b=1,0
    for i=1,#s do a=(a+s:byte(i))%65521;b=(b+a)%65521 end
    return string.format("%04x%04x",b,a)
end
local PREFIX="ISLANDPKG1:"
K.Prefix=PREFIX
-- the text inside an export string, or the text itself when it already is the data
local function Unwrap(text)
    if not Str(text,MAX_BYTES*2) then return nil,"too_big" end
    local trimmed=text:gsub("^%s+",""):gsub("%s+$","")
    if trimmed=="" then return nil,"empty" end
    if trimmed:sub(1,#PREFIX)~=PREFIX then
        if trimmed:sub(1,1)=="{" or trimmed:sub(1,2)=="--" then return trimmed end
        return nil,"bad_prefix"
    end
    local body=trimmed:sub(#PREFIX+1):gsub("%s+","")
    local data,sum=body:match("^([A-Za-z0-9+/=]*):(%x%x%x%x%x%x%x%x)$")
    if not data then return nil,"bad_checksum" end
    local decoded=Decode(data)
    if not decoded or Checksum(decoded)~=sum:lower() then return nil,"bad_checksum" end
    return decoded
end

------------------------------------------------------------------------------------------------
-- Checking a package
------------------------------------------------------------------------------------------------
local lifecycleNames={PLAYER_ENTERING_WORLD=true,LOADING_SCREEN_ENABLED=true,LOADING_SCREEN_DISABLED=true}
local function EventList(text)
    if not Str(text,600) then return end
    local result,seen={},{}
    for name in text:gmatch("[^,%s]+") do
        if #name>64 or not name:match("^[A-Z][A-Z0-9_]*$") or lifecycleNames[name] or name:match("^ISLAND_") then return end
        if not seen[name] then result[#result+1]=name;seen[name]=true end
        if #result>8 then return end
    end
    if #result==0 then return end
    return result
end
local function OnlyKeys(t,allowed)
    if not Plain(t) then return false end
    for k in next,t do if type(k)~="string" or not allowed[k] then return false end end
    return true
end
local function List(t,max)
    if t==nil then return {} end
    if not Plain(t) then return end
    local n=0
    for k in next,t do
        if type(k)~="number" or k<1 or k%1~=0 then return end
        n=n+1
    end
    if n~=#t or n>max then return end
    return t
end
local topFields={id=true,name=true,author=true,version=true,notes=true,full=true,features=true,settings=true,handlers=true}
local handlerFields={name=true,events=true,unit=true,interval=true,feature=true,code=true,enabled=true}
local function PlainText(v,limit) return Str(v,limit) and not v:find("[|%c]") end
-- returns the checked copy, or nil, a reason and a detail
function K.Validate(data)
    if not OnlyKeys(data,topFields) then return nil,"invalid_field" end
    if not Str(data.id,64,"^Pkg_[A-Za-z0-9_%-]+$") then return nil,"invalid_id" end
    if not PlainText(data.name,64) or data.name=="" then return nil,"invalid_name" end
    for _,k in ipairs({"author","version"}) do
        if data[k]~=nil and not PlainText(data[k],k=="author" and 64 or 32) then return nil,"invalid_field",k end
    end
    if data.notes~=nil and (not Str(data.notes,1024) or data.notes:find("[%z\1-\8\11\12\14-\31\127|]")) then return nil,"invalid_field","notes" end
    if data.full~=nil and type(data.full)~="boolean" then return nil,"invalid_field","full" end
    local features,settings,handlers=List(data.features,8),List(data.settings,12),List(data.handlers,MAX_HANDLERS)
    if not features then return nil,"invalid_features" end
    if not settings then return nil,"invalid_settings" end
    if not handlers then return nil,"too_many_handlers" end
    local ok,kinds=ns.Extensions.CheckMetadata(data.id,{apiVersion=1,name=data.name,audience="forever",features=Copy(features),settings=Copy(settings)})
    if not ok then
        -- say which feature or setting it is
        for i,f in ipairs(features) do
            if not ns.Extensions.CheckMetadata(data.id,{apiVersion=1,name=data.name,audience="forever",features={Copy(f)},settings={}}) then return nil,"invalid_features","("..L["feature"].." "..i..")" end
        end
        for i,s in ipairs(settings) do
            if not ns.Extensions.CheckMetadata(data.id,{apiVersion=1,name=data.name,audience="forever",features={},settings={Copy(s)}}) then return nil,"invalid_settings","("..L["setting"].." "..i..")" end
        end
        return nil,"invalid_features",L["(check that ids and keys are unique)"]
    end
    local out={id=data.id,name=data.name,author=data.author,version=data.version,notes=data.notes,full=data.full==true or nil,
        features=Copy(features),settings=Copy(settings),handlers={}}
    for i,h in ipairs(handlers) do
        if not OnlyKeys(h,handlerFields) then return nil,"invalid_handler",i end
        if not PlainText(h.name,64) or h.name=="" then return nil,"invalid_handler",i end
        if not EventList(h.events) then return nil,"bad_events",i end
        if h.unit~=nil and h.unit~="" and not (Str(h.unit,32,"^[a-z]+%d*$")) then return nil,"bad_unit",i end
        if not Readable(h.interval) or type(h.interval)~="number" or h.interval~=h.interval or h.interval<.1 or h.interval>60 then return nil,"bad_interval",i end
        if h.enabled~=nil and type(h.enabled)~="boolean" then return nil,"invalid_handler",i end
        if not Str(h.feature,64) or not kinds[h.feature] then return nil,"bad_feature",i end
        if not Str(h.code,MAX_CODE) then return nil,"bad_code",i end
        local code=h.code:gsub("\r\n?","\n"):gsub("%s+$","")
        local fn,err=loadstring("return function(event, state, ctx, ...)\n"..code.."\nend","BanzaiSlandPackage")
        if not fn then return nil,"compile",i..": "..Error(err) end
        out.handlers[i]={name=h.name,events=table.concat(EventList(h.events),", "),unit=h.unit or "",interval=h.interval,feature=h.feature,code=code}
        if h.enabled==false then out.handlers[i].enabled=false end
    end
    if #K.Serialize(out)>MAX_BYTES then return nil,"too_big" end
    return out
end
-- text or an export string in, a checked package out
function K.Read(text)
    local body,why=Unwrap(text)
    if not body then return nil,why end
    local data,perr,at=Parse(body)
    if not data then return nil,perr,at end
    return K.Validate(data)
end
function K.Export(id)
    local p=K.Get(id);if not p then return end
    local text=K.Serialize(p)
    return PREFIX..Encode(text)..":"..Checksum(text)
end

------------------------------------------------------------------------------------------------
-- Storage (one account-wide list)
------------------------------------------------------------------------------------------------
local function Prefs()
    if not ns.db then return end
    if type(ns.db.packages)~="table" then ns.db.packages={} end
    local p=ns.db.packages
    if p.version==nil then p.version=1 end -- Core's table-default filler yields {}
    if p.version~=1 then return end
    if type(p.list)~="table" then p.list={} end
    return p
end
local vcache=setmetatable({},{__mode="k"})
local function Checked(r)
    local v=vcache[r]
    if v==nil then v=K.Validate(r) or false;vcache[r]=v end
    return v or nil
end
local function Find(id)
    local p=Prefs();if not p then return end
    for i,r in ipairs(p.list) do if type(r)=="table" and r.id==id then return r,i end end
end
function K.Get(id)
    local r=Find(id)
    if not r then return end
    local v=Checked(r)
    return v and Copy(v) or nil
end
function K.Text(id) local p=K.Get(id);return p and K.Serialize(p) end
function K.List()
    local out,p={},Prefs()
    if not p then return out end
    for i,r in ipairs(p.list) do
        if i>MAX_PACKAGES then break end
        if type(r)=="table" and type(r.id)=="string" then
            local v=Checked(r)
            local state=runtime[r.id]
            out[#out+1]={id=r.id,name=v and v.name or r.id,author=v and v.author,version=v and v.version,full=v and v.full==true or false,
                handlers=v and #v.handlers or 0,broken=v==nil,reload=state and state.reload or false}
        end
    end
    return out
end
function K.Refresh() Rebuild(false);if active then InitAll() end end
K.Copy=function(v) return Copy(v) end
function K.Trusted() return ns.Developer~=nil and ns.Developer.Trusted() end

------------------------------------------------------------------------------------------------
-- The sandbox a handler runs in
------------------------------------------------------------------------------------------------
local SAFE_GLOBALS={"assert","error","ipairs","next","pairs","pcall","select","tonumber","tostring","type","unpack",
    "GetTime","GetServerTime","date","time",
    "UnitName","UnitClass","UnitRace","UnitLevel","UnitExists","UnitIsDead","UnitIsPlayer","UnitIsUnit","UnitFactionGroup",
    "UnitHealth","UnitHealthMax","UnitPower","UnitPowerMax","UnitPowerType","UnitXP","UnitXPMax","GetXPExhaustion","IsResting",
    "UnitAffectingCombat","InCombatLockdown","UnitIsGhost","UnitCreatureType","UnitReaction","UnitInRaid","UnitInParty",
    "GetItemCount","GetItemInfo","GetMoney","GetSpellInfo","GetSpellCooldown",
    "GetZoneText","GetSubZoneText","GetRealZoneText","GetMinimapZoneText","IsInInstance","IsInGroup","IsInRaid","GetNumGroupMembers",
    "GetNumQuestLogEntries",
    -- group: roles, threat, who is dead or out of reach (read-only questions)
    "UnitGroupRolesAssigned","UnitThreatSituation","GetPartyAssignment","GetRaidRosterInfo","GetNumSubgroupMembers",
    "UnitGUID","UnitIsDeadOrGhost","UnitIsConnected","UnitIsGroupLeader","UnitInRange","UnitIsVisible",
    -- gear and spells
    "GetInventoryItemDurability","GetInventoryItemLink","GetInventoryItemID","GetItemCooldown","GetSpellTexture","IsSpellKnown",
    -- buffs and debuffs
    "UnitAura","UnitBuff","UnitDebuff",
    -- bags and ammo
    "GetContainerNumSlots","GetContainerNumFreeSlots","GetContainerItemInfo","GetContainerItemLink","GetInventoryItemCount",
    -- casts and cooldowns
    "UnitCastingInfo","UnitChannelInfo","IsUsableSpell","IsSpellInRange","GetActionCooldown",
    -- who is who
    "UnitIsEnemy","UnitCanAttack","UnitIsFriend","UnitCanCooperate","UnitClassification","UnitIsTapDenied",
    "UnitDetailedThreatSituation","GetRaidTargetIndex",
    -- progress and world
    "GetNumFactions","GetFactionInfo","GetNumSkillLines","GetSkillLineInfo","GetInstanceInfo","GetLootMethod",
    "UnitInBattleground","GetQuestLogTitle","GetQuestLogLeaderBoard",
    -- performance
    "GetFramerate","GetNetStats","GetGameTime",
    -- plain helpers
    "strsplit","strtrim","strjoin","strmatch","strfind","tContains","tinsert","floor","ceil","max","min"}
local SAFE_LIBS={math={"abs","acos","asin","atan","atan2","ceil","cos","deg","exp","floor","fmod","log","log10","max","min","modf","pi","pow","rad","random","sin","sqrt","tan"},
    string={"byte","char","find","format","gmatch","gsub","len","lower","match","rep","reverse","sub","upper"},
    table={"concat","getn","insert","maxn","remove","sort"}}
local function Sandbox()
    local env={}
    for _,name in ipairs(SAFE_GLOBALS) do
        local v=_G[name]
        if v~=nil then env[name]=v end
    end
    for lib,names in pairs(SAFE_LIBS) do
        local src,dst=_G[lib],{}
        if type(src)=="table" then for _,n in ipairs(names) do dst[n]=src[n] end end
        env[lib]=dst
    end
    return env
end
K.SafeGlobals=SAFE_GLOBALS

------------------------------------------------------------------------------------------------
-- Running handlers
------------------------------------------------------------------------------------------------
local function Signature(p)
    return ns.Extensions.Signature({apiVersion=1,name=p.name,audience="forever",features=Copy(p.features),settings=Copy(p.settings)})
end
local function Stop(pid,hid,reason,err)
    local pr=runtime[pid];local rt=pr and pr.handlers[hid]
    if rt then rt.fn=nil;rt.reason=reason or "disabled";if err then rt.error=err end end
    local h=handles[pid]
    if h then h:DismissCard(hid);h:RemoveBubble(hid) end
end
local function Fail(pid,hid,err,initial)
    local pr=runtime[pid];local rt=pr and pr.handlers[hid]
    if not rt then return false,"disabled" end
    rt.errors=math.min(1000000,rt.errors+1);rt.consecutive=rt.consecutive+1
    rt.error=Error(err);rt.reason="lua_error"
    if initial or rt.consecutive>=3 then Stop(pid,hid,"lua_error",rt.error) end
    Changed();return false,"lua_error"
end
-- a short plain-text picture of what a handler returned, for the creator's status line
local function Describe(payload)
    if payload==nil or payload==false then return nil end
    if not Plain(payload) then return type(payload) end
    local keys={}
    for k in next,payload do if type(k)=="string" then keys[#keys+1]=k end end
    table.sort(keys)
    local parts={}
    for _,k in ipairs(keys) do
        local v=payload[k]
        if type(v)=="string" then
            v=v:gsub("|","||")
            if #v>40 then v=v:sub(1,37).."..." end
            v='"'..v..'"'
        elseif type(v)=="number" then v=string.format("%.4g",v)
        else v=tostring(v) end
        parts[#parts+1]=k.." = "..v
    end
    local text="{ "..table.concat(parts,", ").." }"
    if #text>260 then text=text:sub(1,257).."..." end
    return text
end
Run=function(pid,hid,event,...)
    local pr=runtime[pid];local rt=pr and pr.handlers[hid]
    if not active or not rt or not rt.fn or pr.reload then return false,"disabled" end
    local handle=handles[pid]
    if not handle or not handle:IsEnabled() then rt.initialized=false;rt.state={};return false,"disabled" end
    if not BanzaiSlandAPI.IsReady() then return false,"not_ready" end
    if event~="ISLAND_INIT" and not rt.initialized then
        local ok,why=Run(pid,hid,"ISLAND_INIT")
        if not ok then return false,why end
    end
    local def=rt.def
    if event~="ISLAND_TEST" and event~="ISLAND_INIT" then
        if def.unit~="" and event:match("^UNIT_") then
            local unit=select(1,...)
            if not Readable(unit) or type(unit)~="string" or unit~=def.unit then return true,"filtered" end
        end
        local now=GetTime()
        if rt.at and now-rt.at<def.interval then return true,"throttled" end
        local b=pr.budget
        b.tokens=math.min(10,b.tokens+math.max(0,now-b.at)*10);b.at=now
        if b.tokens<1 then return true,"throttled" end
        b.tokens=b.tokens-1
        rt.at=now
    end
    if not handle:IsFeatureEnabled(def.feature) and event~="ISLAND_INIT" then return true,"feature_off" end
    local ok,payload=pcall(rt.fn,event,rt.state,rt.ctx or pr.ctx,...)
    if not ok then return Fail(pid,hid,payload,event=="ISLAND_INIT") end
    rt.consecutive=0;rt.error=nil
    if event~="ISLAND_INIT" then rt.lastEvent=event;rt.lastAt=GetTime();rt.last=Describe(payload) end
    if event=="ISLAND_INIT" then rt.initialized=true end
    if event=="ISLAND_INIT" or payload==nil or payload==false then rt.reason="no_output";Changed();return true,"no_output" end
    if Plain(payload) then
        local c={}
        for k,v in next,payload do c[k]=v end
        c.feature=def.feature;payload=c
    end
    local accepted,reason
    if pr.kinds[def.feature]=="bubble" then accepted,reason=handle:SetBubble(hid,payload)
    else accepted,reason=handle:ShowCard(hid,payload) end
    rt.reason=reason;Changed();return accepted,reason
end
local function Subscribe()
    frame:UnregisterAllEvents()
    for event in pairs(lifecycle) do frame:RegisterEvent(event) end
    if not active then return end
    local seen={}
    for pid,pr in pairs(runtime) do
        for hid,rt in pairs(pr.handlers) do
            if rt.fn then
                for _,event in ipairs(rt.events) do
                    if not seen[event] then
                        local ok,result=pcall(frame.RegisterEvent,frame,event)
                        if not ok or result==false then Stop(pid,hid,"invalid_events",L["Unknown or unavailable event."]);break end
                        seen[event]=true
                    end
                end
            end
        end
    end
end
local function Note(id,name,why,detail)
    problems[id]={id=id,name=name or id,reason=why,detail=detail}
end
-- register one saved package (once per session) and prepare its handlers
local function Setup(r,fresh)
    local p=Checked(r)
    if not p then Note(r.id,r.name,"invalid_package");return end
    problems[p.id]=nil
    local sig=Signature(p)
    local handle=handles[p.id]
    if handle and registered[p.id]~=sig then
        -- the name, features or settings changed: register it again under the new shape
        ns.Extensions.Remove(p.id);handles[p.id]=nil;registered[p.id]=nil;handle=nil
    end
    if not handle then
        local why
        handle,why=BanzaiSlandAPI.Register(p.id,{apiVersion=1,name=p.name,audience="forever",features=Copy(p.features),settings=Copy(p.settings)})
        if not handle then Note(p.id,p.name,why or "invalid_payload");return end
        handles[p.id]=handle;registered[p.id]=sig
        if fresh then ns.Extensions.SetEnabled(p.id,false) end
    end
    local kinds={}
    for _,f in ipairs(p.features) do kinds[f.id]=f.kind end
    local pr={handlers={},kinds=kinds,budget={tokens=10,at=GetTime()},reload=registered[p.id]~=sig,pkg=p}
    pr.ctx={
        setting=function(key) if type(key)~="string" then return nil end return handle:GetSetting(key) end,
        enabled=function(fid) if type(fid)~="string" then return false end return handle:IsFeatureEnabled(fid) end,
    }
    runtime[p.id]=pr
    if pr.reload then Note(p.id,p.name,"reload");return end
    local env=(p.full~=true) and Sandbox() or nil
    for i,h in ipairs(p.handlers) do
        local hid="h"..i
        local rt={state={},errors=0,consecutive=0,events=EventList(h.events) or {},reason="disabled",def=h}
        pr.handlers[hid]=rt
        -- this handler's own tools: what the package-wide ones do, plus stopping, restarting or removing its own timer
        local ctx={}
        for key,fn in pairs(pr.ctx) do ctx[key]=fn end
        ctx.pause=function() return (handle:PauseCountdown(hid)) end
        ctx.resume=function() return (handle:ResumeCountdown(hid)) end
        ctx.cancel=function() handle:DismissCard(hid);handle:RemoveBubble(hid) end
        rt.ctx=ctx
        local factory,err=loadstring("return function(event, state, ctx, ...)\n"..h.code.."\nend","BanzaiSlandPackage")
        if h.enabled==false then rt.reason="disabled"
        elseif factory then
            if env then setfenv(factory,env) end
            local ok,fn=pcall(factory)
            if ok and type(fn)=="function" then rt.fn=fn else rt.error=Error(fn);rt.reason="lua_error" end
        else rt.error=Error(err);rt.reason="lua_error" end
    end
end
Rebuild=function(fresh)
    for _,handle in pairs(handles) do handle:Clear() end
    runtime={}
    local p=Prefs()
    active=p~=nil and K.Trusted()
    if not p then Subscribe();Changed();return end
    -- packages register even while trusted Lua is off (so they stay listed); their handlers only run when it is on
    for i,r in ipairs(p.list) do
        if i>MAX_PACKAGES then break end
        if type(r)=="table" and type(r.id)=="string" then Setup(r,false) end
    end
    Subscribe();Changed()
end
InitAll=function()
    for pid,pr in pairs(runtime) do for hid in pairs(pr.handlers) do Run(pid,hid,"ISLAND_INIT") end end
end

------------------------------------------------------------------------------------------------
-- What the editor uses
------------------------------------------------------------------------------------------------
-- compare an incoming package with the saved one of the same id
function K.Compare(text)
    local p,why,detail=K.Read(text)
    if not p then return nil,why,detail end
    local old=K.Get(p.id)
    return p,old and (K.Serialize(old)==K.Serialize(p) and "same" or "changed") or "new"
end
-- Save a checked package: new ones register at once and start switched off; an update that changes code
-- or access switches the package off again, so new code never runs before the player turns it on
local function Commit(p)
    local prefs=Prefs();if not prefs then return false,"not_ready" end
    local old,index=Find(p.id)
    if not old and #prefs.list>=MAX_PACKAGES then return false,"capacity" end
    local fresh=old==nil
    local codeChanged=false
    if old then
        local before=Checked(old)
        local function Code(x) local t={x.full and "F" or "S"};for i,h in ipairs(x.handlers) do t[#t+1]=h.code.."\1"..h.events.."\1"..h.unit.."\1"..tostring(h.enabled) end return table.concat(t,"\2") end
        codeChanged=before==nil or Code(before)~=Code(p)
        prefs.list[index]=p
    else prefs.list[#prefs.list+1]=p end
    local pr=runtime[p.id]
    if pr then for hid in pairs(pr.handlers) do Stop(p.id,hid,"disabled") end end
    local h=handles[p.id]
    if h then h:Clear() end
    runtime[p.id]=nil
    vcache[p]=p
    active=true
    Setup(p,fresh)
    if codeChanged and handles[p.id] then ns.Extensions.SetEnabled(p.id,false) end
    Subscribe();Changed()
    if problems[p.id] and problems[p.id].reason=="reload" then return true,"updated_reload",p.id end
    if problems[p.id] then return false,problems[p.id].reason end
    return true,fresh and "installed" or (codeChanged and "updated_off" or "updated"),p.id
end
function K.Install(text)
    if not K.Trusted() then return false,"trust_required" end
    local p,why,detail=K.Read(text)
    if not p then return false,why,detail end
    return Commit(p)
end
-- the form editor hands over a table (not text)
function K.Save(data)
    if not K.Trusted() then return false,"trust_required" end
    local p,why,detail=K.Validate(data)
    if not p then return false,why,detail end
    return Commit(p)
end
-- a starting point: one card feature, one setting and one handler
function K.Sample(kind)
    if kind=="bubble" then
        return 'if event == "ISLAND_INIT" then return end\nstate.n = (state.n or 0) + 1\nreturn {\n    text = tostring(state.n),\n    tooltip = '..Quote(L["Times this handler has run"])..',\n    ttl = 20,\n}'
    end
    return 'if event == "ISLAND_INIT" then return end\nreturn {\n    title = '..Quote(L["Bags changed"])..',\n    text = event,\n    duration = 5, ttl = 20,\n}'
end
function K.NewDraft()
    local n=1
    while Find("Pkg_New"..n) do n=n+1 end
    return {id="Pkg_New"..n,name=L["New package"],author="",version="1",notes="",
        features={{id="note",kind="card",name=L["Show a card"],description="",default=true}},
        settings={},
        handlers={{name=L["Bag change"],events="BAG_UPDATE_DELAYED",unit="",interval=2,feature="note",code=K.Sample("card")}}}
end
function K.Template()
    local d=K.NewDraft()
    d.notes=L["What this package does."]
    d.settings={{key="seconds",type="slider",name=L["Card time"],description=L["How long the card stays."],default=5,min=2,max=15,step=1}}
    d.handlers[1].code='if event == "ISLAND_INIT" then return end\nreturn {\n    title = '..Quote(L["Bags changed"])..',\n    text = event,\n    duration = ctx.setting("seconds"), ttl = 20,\n}'
    return K.Serialize(d)
end
-- Developer rules from the old editor become one package of their own, once. The rules stay in the saved
-- data (an older Island still reads them); the package carries the same code with full Lua access.
function K.MigrateRules()
    local dev=ns.db and ns.db.developer
    local prefs=Prefs()
    if type(dev)~="table" or dev.migrated or not prefs or type(dev.rules)~="table" or #dev.rules==0 then return end
    if Find("Pkg_DeveloperRules") then dev.migrated=true;return end
    if #prefs.list>=MAX_PACKAGES then Note("Pkg_DeveloperRules",L["Developer rules"],"capacity");return end
    local data={id="Pkg_DeveloperRules",name=L["Developer rules"],author="",version="1",full=true,features={},settings={},handlers={}}
    local used,anyOn={}
    for _,r in ipairs(dev.rules) do
        if #data.handlers>=MAX_HANDLERS then break end
        if type(r)=="table" and (r.mode=="card" or r.mode=="bubble") then
            if not used[r.mode] then
                used[r.mode]=true
                data.features[#data.features+1]={id=r.mode,kind=r.mode,name=r.mode=="card" and L["Cards"] or L["Bubbles"],description="",default=true}
            end
            local h={name=r.name,events=r.events,unit=r.unit or "",interval=r.interval,feature=r.mode,code=r.code}
            if r.enabled~=true then h.enabled=false end
            data.handlers[#data.handlers+1]=h
            if r.enabled==true then anyOn=true end
        end
    end
    local p,why=K.Validate(data)
    if not p then
        -- some rule does not fit the package limits: keep the ones that do
        local keep={}
        for _,h in ipairs(data.handlers) do
            local trial=Copy(data);trial.handlers={h}
            if K.Validate(trial) then keep[#keep+1]=h end
        end
        data.handlers=keep
        if #keep==0 then dev.migrated=true;return end
        p=K.Validate(data)
        if not p then return end
    end
    prefs.list[#prefs.list+1]=p;vcache[p]=p
    dev.migrated=true
    local ext=ns.db.extensions
    if type(ext)=="table" and type(ext.enabled)=="table" then ext.enabled["Pkg_DeveloperRules"]=(anyOn==true) and ext.enabled["IslandDeveloper"]~=false end
end
function K.Delete(id)
    local prefs=Prefs();local _,index=Find(id)
    if not prefs or not index then return false,"not_found" end
    local pr=runtime[id]
    if pr then for hid in pairs(pr.handlers) do Stop(id,hid,"disabled") end end
    if handles[id] then handles[id]:Clear() end
    ns.Extensions.Remove(id);handles[id]=nil;registered[id]=nil
    table.remove(prefs.list,index);runtime[id]=nil;problems[id]=nil
    Subscribe();Changed();return true,"deleted"
end
function K.Restart(id)
    local r=Find(id);if not r then return false,"not_found" end
    if not K.Trusted() then return false,"trust_required" end
    local h=handles[id];if h then h:Clear() end
    runtime[id]=nil;active=true
    Setup(r,false);Subscribe();Changed()
    for hid in pairs((runtime[id] or {handlers={}}).handlers) do Run(id,hid,"ISLAND_INIT") end
    return true,"restarted"
end
function K.Test(id,index)
    return Run(id,"h"..index,"ISLAND_TEST")
end
function K.Status(id,index)
    local pr=runtime[id];local rt=pr and pr.handlers["h"..index]
    return {reason=rt and rt.reason or (pr and pr.reload and "reload") or "disabled",error=rt and rt.error,errors=rt and rt.errors or 0,reload=pr and pr.reload or false,
        last=rt and rt.last,lastEvent=rt and rt.lastEvent,lastAgo=rt and rt.lastAt and math.max(0,GetTime()-rt.lastAt) or nil}
end
function K.Problems()
    local out={}
    for _,pr in pairs(problems) do out[#out+1]={id=pr.id,name=pr.name,reason=pr.reason,detail=pr.detail} end
    for pid,pr in pairs(runtime) do
        for hid,rt in pairs(pr.handlers) do
            if rt.reason=="lua_error" and rt.error and not rt.fn then
                out[#out+1]={id=pid,name=pr.pkg.name,reason="handler",detail=(rt.def.name or hid)..": "..rt.error}
            end
        end
    end
    table.sort(out,function(a,b) return a.id<b.id end)
    return out
end
function K.Reason(why,detail)
    local names={empty=L["Paste or write a package first."],too_big=L["That text is too long to be a package."],bad_prefix=L["That is not a package string."],
        bad_checksum=L["The string is cut off or changed; copy it again."],bad_format=L["The package text could not be read."],
        too_deep=L["The package text is nested too deeply."],duplicate=L["A name appears twice in the package."],trailing=L["There is extra text after the package."],
        invalid_field=L["A package field is missing, misspelled or has the wrong kind of value."],invalid_id=L["The id must start with Pkg_ and use letters, numbers, _ or -."],
        invalid_name=L["The package needs a name of up to 64 characters."],invalid_features=L["The features are not valid."],invalid_settings=L["The settings are not valid."],
        too_many_handlers=L["A package can have up to 12 handlers."],invalid_handler=L["A handler is missing a name or has an unknown field."],
        bad_events=L["A handler's events must be uppercase event names (up to 8)."],bad_unit=L["A handler's unit must look like player or party1."],
        bad_interval=L["A handler's interval must be between 0.1 and 60 seconds."],bad_feature=L["A handler must name one of the package's features."],
        bad_code=L["A handler's code is missing or too long."],compile=L["A handler's Lua does not compile."],
        trust_required=L["Turn on Allow package code first."],capacity=L["Up to 8 packages can be installed."],not_ready=L["BanzaiSland is not ready"],not_found=L["Choose a package first."],
        installed=L["Installed and switched off. Switch it on in Extensions."],updated=L["Updated."],updated_off=L["Saved. The package is switched off until you turn it on."],updated_reload=L["Saved. Type /reload to use the new features and settings."],
        deleted=L["Deleted."],restarted=L["Restarted."],reload=L["Type /reload to use the new features and settings."],
        invalid_package=L["The saved package is damaged."],invalid_payload=L["BanzaiSland refused the package."],already_registered=L["Type /reload to use the new features and settings."],
        handler=L["A handler stopped after errors."],unsaved=L["Save or discard your changes first."],
        same=L["Identical to the installed package: nothing to change."],
        full_lua=L["Full Lua access can do anything an addon can, including things BanzaiSland cannot undo. Press Install once more only if you trust the author."],
        feature_off=L["That feature is switched off."]}
    local text=names[why] or (ns.Developer and ns.Developer.Reason and ns.Developer.Reason(why)) or tostring(why)
    if detail and type(detail)~="number" and why~="reload" then text=text.." "..tostring(detail) elseif type(detail)=="number" and why~="reload" then text=text.." ("..detail..")" end
    return text
end
frame:SetScript("OnEvent",function(_,event,...)
    if lifecycle[event] then
        epoch=epoch+1;local token=epoch;active=false
        for _,handle in pairs(handles) do handle:Clear() end
        runtime={};Subscribe()
        if event~="LOADING_SCREEN_ENABLED" then
            C_Timer.After(0,function()
                if epoch~=token then return end
                K.MigrateRules()
                Rebuild(false);InitAll()
            end)
        end
        return
    end
    for pid,pr in pairs(runtime) do
        for hid,rt in pairs(pr.handlers) do
            if rt.fn then for _,name in ipairs(rt.events) do if name==event then Run(pid,hid,event,...);break end end end
        end
    end
end)
Subscribe()
