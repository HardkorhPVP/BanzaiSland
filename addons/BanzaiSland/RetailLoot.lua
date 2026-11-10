-- Summarize other party/raid members' boss drops without duplicating personal loot/upgrade cards.
local ADDON,ns=...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
if not ns.ClientFeature("retail") then return end
local R,I,L,C=ns.Retail,ns.Island,ns.L,ns.C
local Read,Call=R.Read,R.Call
local B={batches={},names={},serial=0,epoch=0}
R.BossLoot=B
local function Enabled() return ns.db and ns.db.retailBossLoot~=false end
-- Only the boss-loot event is replaced. Keep Blizzard's boss-defeat banner registered.
function B.ApplyNative()
    local frame=_G.BossBanner
    local want=Enabled() and I.built and frame and frame~=UIParent
    if B.nativeFrame and (not want or B.nativeFrame~=frame) then
        if B.nativeLootRegistered then Call(B.nativeFrame.RegisterEvent,B.nativeFrame,"ENCOUNTER_LOOT_RECEIVED") end
        B.nativeFrame,B.nativeLootRegistered=nil,nil
    end
    if not want then return end
    if B.nativeFrame~=frame then
        local registered=Call(frame.IsEventRegistered,frame,"ENCOUNTER_LOOT_RECEIVED")
        if not Read(registered,"boolean") then return end
        B.nativeFrame,B.nativeLootRegistered=frame,registered
    end
    Call(frame.UnregisterEvent,frame,"ENCOUNTER_LOOT_RECEIVED")
end

local function Self(name)
    local me,realm=Call(UnitFullName,"player")
    if not Read(me,"string") then me=Call(UnitName,"player") end
    if not Read(me,"string") then return false end
    return name==me or (Read(realm,"string") and name==me.."-"..realm)
end
local function Recipient(entry)
    local name=ns.ShowName and ns.ShowName(entry.player) or entry.player
    local hex=entry.class and ns.ClassHex and ns.ClassHex(entry.class) -- BanzaiSland 0.3.0: one class-colour authority
    if hex then
        name=hex..name.."|r"
    end
    return name
end
function B.Card(batch)
    local pages=math.ceil(#batch.entries/4)
    batch.page=math.min(batch.page or 1,pages)
    local lines,rows={},{}
    for index=(batch.page-1)*4+1,math.min(batch.page*4,#batch.entries) do
        local entry=batch.entries[index]
        local icon=Call(C_Item and C_Item.GetItemIconByID,entry.itemID)
        local text=L["%s: %s"]:format(Recipient(entry),entry.link)
        if entry.quantity>1 then text=L["%s ×%d"]:format(text,entry.quantity) end
        if Read(icon,"number") then text=("|T%d:14:14|t "):format(icon)..text end
        lines[#lines+1]=text
        rows[#rows+1]={recipient=Recipient(entry),link=entry.link,itemID=entry.itemID,quantity=entry.quantity,icon=Read(icon,"number") and icon or nil}
    end
    local item={kind="won",key=batch.key,builderType="retailBossLoot",group="loot",glyph="Chest",tone=C.gold,
        cap=L["BOSS LOOT"],capColor=C.gold,title=batch.name or L["Boss loot"],color=C.fg,
        res=(#batch.entries==1 and L["%d drop"] or L["%d drops"]):format(#batch.entries),resColor=C.muted,
        line=table.concat(lines,"\n"),bossLootRows=rows,hold=5,onClick=false}
    if pages>1 then
        item.button={label=L["More loot (%d/%d)"]:format(batch.page,pages),fn=function()
            if batch.epoch~=B.epoch or not Enabled() then return false end
            batch.page=batch.page%math.ceil(#batch.entries/4)+1
            B.Show(batch)
            return false -- The refreshed page retains its button and reading time.
        end}
    end
    return item
end
function B.Show(batch)
    if not Enabled() or not I.built or batch.epoch~=B.epoch or B.batches[batch.encounter]~=batch or #batch.entries==0 then return end
    I:PushReplace(B.Card(batch))
end
function B.Sample()
    return B.Card({key="sampleBossLoot",name=L["Boss loot"],entries={
        {player="Thrall",class="SHAMAN",itemID=1482,link="|cff0070dd|Hitem:1482|h[Shadowfang]|h|r",quantity=1},
        {player="Jaina",class="MAGE",itemID=17182,link="|cffff8000|Hitem:17182|h[Sulfuras, Hand of Ragnaros]|h|r",quantity=1},
    }})
end
-- A shared layout for live cards and passive builder previews.
function B.Layout(w,item,look)
    if w.bossLoot then
        w.bossLoot:Hide()
        for _,row in ipairs(w.bossLoot.rows) do
            if row.tooltipOpen and GameTooltip then GameTooltip:Hide() end
            row.tooltipOpen=nil;row.entry=nil
        end
    end
    local entries=item.bossLootRows
    if not entries or #entries==0 or (look and look.line==false) then return end
    if not w.bossLoot then
        local f=CreateFrame("Frame",nil,w.frame)
        f:SetFrameLevel(w.frame:GetFrameLevel()+10)
        f.rows={}
        for index=1,4 do
            local row=CreateFrame("Frame",nil,f)
            row:EnableMouse(true)
            row.bg=ns.CreateBody(row,"BACKGROUND",0)
            row.bg:SetColor(1,1,1,.055);row.bg:SetRadius(8)
            row.icon=row:CreateTexture(nil,"ARTWORK")
            row.icon:SetSize(30,30);row.icon:SetPoint("TOPLEFT",row,"TOPLEFT",10,-11)
            row.recipient=ns.Text(row,"medium",11.5,C.muted)
            row.recipient:SetPoint("TOPLEFT",row,"TOPLEFT",50,-8)
            row.recipient:SetJustifyH("LEFT");row.recipient:SetMaxLines(1)
            row.item=ns.Text(row,"medium",14,C.fg)
            row.item:SetPoint("TOPLEFT",row,"TOPLEFT",50,-24)
            row.item:SetJustifyH("LEFT");row.item:SetWordWrap(true);row.item:SetMaxLines(2)
            row:SetScript("OnEnter",function(self)
                if not self.entry or not GameTooltip then return end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                if not pcall(GameTooltip.SetHyperlink,GameTooltip,self.entry.link) then
                    GameTooltip:Hide();return
                end
                self.tooltipOpen=true;GameTooltip:Show()
            end)
            row:SetScript("OnLeave",function(self)
                if self.tooltipOpen and GameTooltip then GameTooltip:Hide() end
                self.tooltipOpen=nil
            end)
            row:SetScript("OnHide",function(self)
                if self.tooltipOpen and GameTooltip then GameTooltip:Hide() end
                self.tooltipOpen=nil
            end)
            f.rows[index]=row
        end
        w.bossLoot=f
    end
    w.names:Hide()
    local f=w.bossLoot
    local width=(w.cardWidth or ns.WIDE)-32
    f:ClearAllPoints();f:SetPoint("TOPLEFT",w.frame,"TOPLEFT",14,-64);f:SetWidth(width)
    local offset=0
    for index,row in ipairs(f.rows) do
        local entry=entries[index]
        row.entry=entry;row:SetShown(entry~=nil)
        if entry then
            row:SetWidth(width)
            row:ClearAllPoints();row:SetPoint("TOPLEFT",f,"TOPLEFT",0,-offset)
            row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.recipient:SetWidth(width-60);row.recipient:SetText(entry.recipient)
            row.item:SetWidth(width-60)
            row.item:SetText(entry.quantity>1 and L["%s ×%d"]:format(entry.link,entry.quantity) or entry.link)
            local height=math.max(52,24+(row.item:GetStringHeight() or 14)+10)
            row:SetHeight(height);offset=offset+height+6
        end
    end
    f:SetHeight(offset-6);f:Show()
    local height=64+offset-6+14+(item.button and 40 or 0)
    if item.button and w.btn then
        w.btn:ClearAllPoints();w.btn:SetPoint("BOTTOMLEFT",w.frame,"TOPLEFT",14,-(height-14))
    end
    w.frame:SetHeight(height)
    return height
end

local function Prune()
    local count,oldest=0,nil
    for _,batch in pairs(B.batches) do
        count=count+1
        if not oldest or batch.created<oldest.created then oldest=batch end
    end
    if count>8 then B.batches[oldest.encounter]=nil end
end
function B.Loot(encounter,itemID,link,quantity,player,class)
    if not Enabled() or not I.built or R.loading or not R.ready
        or (Call(IsInGroup)~=true and Call(IsInRaid)~=true) then return end
    if not Read(encounter,"number") or not Read(itemID,"number") or not Read(link,"string")
        or not Read(quantity,"number") or quantity<1 or not Read(player,"string") or Self(player) then return end
    local raidIndex=Call(UnitInRaid,player)
    if Call(UnitInParty,player)~=true and not (Read(raidIndex,"number") and raidIndex>0) then return end
    local batch=B.batches[encounter]
    if not batch or GetTime()-batch.created>180 then
        B.serial=B.serial+1
        batch={encounter=encounter,key="bossLoot:"..B.serial,epoch=B.epoch,created=GetTime(),entries={},byKey={},page=1,name=B.names[encounter]}
        B.batches[encounter]=batch;Prune()
    end
    local key=player..":"..link
    local entry=batch.byKey[key]
    if entry then entry.quantity=entry.quantity+math.floor(quantity)
    elseif #batch.entries<80 then
        entry={player=player,itemID=itemID,link=link,quantity=math.floor(quantity),class=Read(class,"string") and class or nil}
        batch.entries[#batch.entries+1]=entry;batch.byKey[key]=entry
    else return end
    if not batch.pending then
        batch.pending=true
        C_Timer.After(.4,function() batch.pending=nil;if batch.epoch==B.epoch then B.Show(batch) end end)
    end
end
function B.Apply()
    B.ApplyNative()
    if Enabled() then return end
    B.epoch=B.epoch+1;B.batches={}
    for _,list in ipairs({I.queue or {},I.held or {}}) do
        for index=#list,1,-1 do
            local key=list[index].key
            if Read(key,"string") and key:find("^bossLoot:") then table.remove(list,index) end
        end
    end
    local current=I.current
    if current and Read(current.key,"string") and current.key:find("^bossLoot:") then current.dur=current.t or 0 end
end
local ev=CreateFrame("Frame")
ev:SetScript("OnEvent",function(_,event,a,b,c,d,e,f)
    if event=="PLAYER_LOGIN" or event=="ADDON_LOADED" then B.ApplyNative()
    elseif event=="ENCOUNTER_LOOT_RECEIVED" then B.Loot(a,b,c,d,e,f)
    elseif event=="LOADING_SCREEN_ENABLED" or event=="PLAYER_ENTERING_WORLD" then
        B.epoch=B.epoch+1;B.batches={};B.names={}
    elseif Read(a,"number") and Read(b,"string") then
        B.ApplyNative()
        if event=="ENCOUNTER_START" then B.batches[a]=nil end
        B.names[a]=b
        if B.batches[a] then B.batches[a].name=b end
        local count=0;for _ in pairs(B.names) do count=count+1 end
        if count>32 then B.names={[a]=b} end
    end
end)
for _,event in ipairs({"ENCOUNTER_LOOT_RECEIVED","ENCOUNTER_START","ENCOUNTER_END","BOSS_KILL","LOADING_SCREEN_ENABLED","PLAYER_ENTERING_WORLD","PLAYER_LOGIN","ADDON_LOADED"}) do
    pcall(ev.RegisterEvent,ev,event)
end

B.ApplyNative()
