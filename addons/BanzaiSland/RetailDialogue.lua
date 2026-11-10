-- Mirror Retail Talking Head presentation while Blizzard retains audio and conversation playback.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
if not ns.ClientFeature("retail") then return end
local R, I, C, L = ns.Retail, ns.Island, ns.C, ns.L
local Read, Call = R.Read, R.Call
local BLUE={.40,.72,1}
local D={serial=0}
R.Dialogue=D
-- Use the animation selected for this line, rather than the model's default idle.
local function StopPortrait(model)
    if not model then return end
    Call(model.StopAnimKit,model)
    model:SetScript("OnAnimFinished",nil)
    model.dialogueAnimationSerial=nil
end
local function AnimatePortrait(model)
    local active=model.dialogueActive
    if not active or active~=D.active or GetTime()>=active.ends or not model.dialogueLoaded
        or model.dialogueAnimationSerial==active.serial then return end
    local anim=active.animation
    if not anim then return end
    StopPortrait(model)
    model.dialogueAnimationSerial=active.serial
    if anim.kit>0 and type(model.PlayAnimKit)=="function" then
        Call(model.PlayAnimKit,model,anim.kit,true)
        return
    end
    if type(model.SetAnimation)~="function" then return end
    local loop=anim.loop
    local first=(GetTime()-active.started<1 and anim.intro>0) and anim.intro or loop
    Call(model.SetAnimation,model,first,0)
    model:SetScript("OnAnimFinished",function(self)
        if self.dialogueActive~=D.active or D.active~=active or GetTime()>=active.ends-1.5 then
            self:SetScript("OnAnimFinished",nil)
            Call(self.SetAnimation,self,0,0)
        else Call(self.SetAnimation,self,loop,0) end
    end)
end

local function Frame()
    local frame=_G.TalkingHeadFrame
    if not frame or frame==UIParent or not frame.MainFrame or frame.MainFrame==UIParent then return end
    return frame
end
local function RemoveCards()
    for _,list in ipairs({I.queue or {},I.held or {}}) do
        for index=#list,1,-1 do if list[index].retailDialogue then table.remove(list,index) end end
    end
    if I.current and I.current.retailDialogue then I.current.dur=I.current.t or 0 end
end
local function Restore()
    D.suppressNative=false
    for region,alpha in pairs(D.hiddenRegions or {}) do Call(region.SetAlpha,region,alpha) end
    local frame=D.hidden
    local button=frame and frame.MainFrame and frame.MainFrame.CloseButton
    if button and D.mouse~=nil then Call(button.EnableMouse,button,D.mouse) end
    if D.hiddenModel then
        Call(D.hiddenModel.SetModelAlpha,D.hiddenModel,D.modelAlpha or 1)
        if Read(D.modelShown,"boolean") then Call(D.hiddenModel.SetShown,D.hiddenModel,D.modelShown) end
    end
    D.modelShown=nil
    D.hiddenRegions,D.hiddenModel,D.modelAlpha,D.hidden,D.mouse=nil,nil,nil,nil,nil
end
local function HideOriginal()
    local frame=Frame()
    if not frame or not ns.db or not ns.db.retailTalkingHeadHide then Restore() return end
    if D.hidden~=frame then
        Restore()
        D.hidden=frame
        local button=frame.MainFrame.CloseButton
        if button then D.mouse=Call(button.IsMouseEnabled,button);Call(button.EnableMouse,button,false) end
    end
    D.suppressNative=true
    D.hiddenRegions=D.hiddenRegions or {}
    D.alphaHooks=D.alphaHooks or setmetatable({},{__mode="k"})
    -- Only direct visual children are touched. Never scale/fade/hide the native root or UIParent.
    for _,key in ipairs({"MainFrame","NameFrame","TextFrame","BackgroundFrame","PortraitFrame"}) do
        local region=frame[key]
        if region and region~=UIParent and region~=frame and Call(region.GetParent,region)==frame
            and type(region.SetAlpha)=="function" then
            if D.hiddenRegions[region]==nil then D.hiddenRegions[region]=Call(region.GetAlpha,region) or 1 end
            if not D.alphaHooks[region] and hooksecurefunc then
                local ok=pcall(hooksecurefunc,region,"SetAlpha",function(self,alpha)
                    if D.suppressNative and D.hiddenRegions and D.hiddenRegions[self]~=nil
                        and not D.enforcingAlpha and Read(alpha,"number") and alpha~=0 then
                        D.enforcingAlpha=true
                        Call(self.SetAlpha,self,0)
                        D.enforcingAlpha=nil
                    end
                end)
                if ok then D.alphaHooks[region]=true end
            end
            Call(region.SetAlpha,region,0)
        end
    end
    local model=frame.MainFrame.Model
    if model and model~=UIParent and model~=frame and Call(model.GetParent,model)==frame.MainFrame
        and not (I.wn and model==I.wn.dialoguePortrait) then
        if D.hiddenModel~=model then
            D.hiddenModel,D.modelAlpha=model,Call(model.GetModelAlpha,model) or 1
            D.modelShown=Call(model.IsShown,model)
        end
        D.modelHooks=D.modelHooks or setmetatable({},{__mode="k"})
        if not D.modelHooks[model] and type(model.HookScript)=="function" then
            local ok=pcall(model.HookScript,model,"OnShow",function(self)
                if D.suppressNative and D.hiddenModel==self then Call(self.Hide,self) end
            end)
            if ok then D.modelHooks[model]=true end
        end
        Call(model.SetModelAlpha,model,0)
        -- Hide the native renderer only. The root still owns and plays Blizzard's voice.
        if Call(model.IsShown,model)~=false then Call(model.Hide,model) end
    end
end

local function SyncOriginal()
    if ns.db and ns.db.retailTalkingHead and ns.db.retailTalkingHeadHide and not D.nativeFallback then
        HideOriginal()
    else Restore() end
end
function D.IsUrgent(item)
    return item.urgent and item.builderType~="rare" and not item.retailDialogue
end
-- Keep ordinary news beneath the dialogue, without interrupting its voice or timer.
local previews, showing, strip = {}, nil, nil
local function StripBusy() return showing or #previews>0 end
local function BuildStrip(w)
    if strip then return strip end
    strip=CreateFrame("Frame",nil,w.frame)
    strip:SetHeight(24)
    local rule=strip:CreateTexture(nil,"ARTWORK")
    rule:SetColorTexture(1,1,1,.08);rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT",strip,"TOPLEFT",0,4)
    rule:SetPoint("BOTTOMRIGHT",strip,"TOPRIGHT",0,4)
    strip.icon=ns.RoundIcon and ns.RoundIcon(strip,20) or strip:CreateTexture(nil,"ARTWORK")
    strip.icon:SetSize(20,20);strip.icon:SetPoint("LEFT",strip,"LEFT",0,0)
    strip.result=ns.Text(strip,"bold",12,C.muted,"RIGHT")
    strip.result:SetPoint("RIGHT",strip,"RIGHT",0,0)
    strip.title=ns.Text(strip,"medium",12,C.fg)
    strip.title:SetPoint("LEFT",strip,"LEFT",28,0)
    strip.title:SetPoint("RIGHT",strip.result,"LEFT",-8,0)
    strip:Hide()
    return strip
end
local function PaintStrip()
    if not strip or not showing then return end
    local item=showing.item
    local title,result=item.title or item.cap or "",item.res or ""
    if item.kind=="gain" then
        title=L[item.unit or "XP"]
        result=item.fmt and item.fmt(item.amount or 0) or ("+"..ns.Comma(item.amount or 0))
    elseif item.kind=="toast" and item.amount and item.amount>0 then
        result=L["+%s XP"]:format(ns.Comma(item.amount))
    end
    strip.title:SetText(title)
    strip.result:SetText(result)
    if item.icon then
        strip.icon:SetTexture(item.icon);strip.icon:SetVertexColor(1,1,1,1)
    else
        local tone=item.tone or item.color or C.muted
        strip.icon:SetTexture(ns.MEDIA..(item.glyph or (item.kind=="gain" and "Coin" or "Star")))
        strip.icon:SetVertexColor(tone[1],tone[2],tone[3],1)
    end
end
local function RelayoutStrip()
    local current=I.current
    if not current or current.retailDialogue~=D.active or not I.wn then return end
    local height=R.LayoutDialogue(I.wn,current)
    if height then ns.STATES.won.h=height;I.sh.t=height;I.awake=true end
end
function D.ClearPreviews()
    previews,showing={},nil
    if strip then strip:Hide() end
end
function D.HasExtension(id,key)
    local function match(e) return e and e.item.extensionOwner==id and (not key or e.item.extensionKey==key) end
    if match(showing) then return true end
    for _,e in ipairs(previews) do if match(e) then return true end end
    return false
end
function D.RemoveExtension(id,key)
    local function match(e) return e and e.item.extensionOwner==id and (not key or e.item.extensionKey==key) end
    for n=#previews,1,-1 do if match(previews[n]) then table.remove(previews,n) end end
    if match(showing) then showing=table.remove(previews,1) end
    if not showing and strip then strip:Hide() else PaintStrip() end
    RelayoutStrip()
end
function D.HidePreviews() if strip then strip:Hide() end end
function D.Takes(item)
    if not D.active or GetTime()>=D.active.ends or not ns.db.retailTalkingHead
        or D.IsUrgent(item) or item.replay or item.retailDialogue then return false end
    if item.kind~="won" and item.kind~="toast" and item.kind~="gain" then return false end
    -- The normal quiet/hold policy still applies before an item can become a preview.
    if ns.db.dnd or (ns.db.quietInRaid and IsInRaid and IsInRaid()) then return false end
    if item.kind~="gain" and not item.urgent and not item.released and I.ShouldHold and I:ShouldHold() then return false end
    if item.kind=="won" and item.format and item.count and not item.res then item.res=item.format(item.count) end
    if item.kind=="won" then I:Record(item) end
    if (item.kind=="gain" or item.kind=="toast") and I.Refresh then I:Refresh() end
    local copy={}
    for k,v in pairs(item) do copy[k]=v end
    local function Merge(entry)
        local old=entry.item
        if not copy.key or old.key~=copy.key then return false end
        if not copy.replace and old.format and old.count and copy.count then
            copy.count=old.count+copy.count;copy.res=copy.format(copy.count)
        end
        entry.item=copy;return true
    end
    if showing and Merge(showing) then showing.t=0;PaintStrip();return true end
    for _,entry in ipairs(previews) do if Merge(entry) then return true end end
    previews[#previews+1]={item=copy,t=0}
    if #previews>12 then table.remove(previews,1) end
    if not showing then showing=table.remove(previews,1);PaintStrip() end
    RelayoutStrip()
    return true
end
function D.LayoutPreviews(w,height,width)
    if not StripBusy() then if strip then strip:Hide() end return height end
    local frame=BuildStrip(w)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT",w.frame,"TOPLEFT",14,-height-4)
    frame:SetWidth(width-32)
    PaintStrip();frame:Show()
    return height+38
end
function D.StepPreviews(dt)
    if ns.Extensions then
        for n=#previews,1,-1 do if not ns.Extensions.Valid(previews[n].item) then table.remove(previews,n) end end
        if showing and not ns.Extensions.Valid(showing.item) then D.RemoveExtension(showing.item.extensionOwner,showing.item.extensionKey) end
    end
    local current=I.current
    local visible=current and current.retailDialogue==D.active and I.state=="won"
    if strip then strip:SetShown(visible and StripBusy() and true or false) end
    if not visible or not showing then return end
    showing.t=showing.t+dt
    if showing.t>=(#previews>0 and 2.2 or 3.2) then
        showing=table.remove(previews,1)
        PaintStrip();RelayoutStrip()
    end
end

function D.Close()
    if D.active and type(BanzaiSland_TalkingHeadDebug)=="function" then D.lastPortraitDebug=BanzaiSland_TalkingHeadDebug() end
    SyncOriginal()
    D.active=nil
    D.ClearPreviews()
    RemoveCards()
    if I.built then I:SetActivity("talkingHead",nil) end
    if I.wn and I.wn.dialoguePortrait then StopPortrait(I.wn.dialoguePortrait);I.wn.dialoguePortrait:Hide() end
end
function D.ResetPortrait()
    local w=I.wn
    if not w then return end
    w.dialogueSerial,w.dialogueDisplay=nil,nil
    local model=w.dialoguePortrait
    if not model then return end
    StopPortrait(model)
    model.dialogueActive,model.dialogueLoaded,model.dialogueCameraSerial=nil,false,nil
    model.dialogueRetryToken,model.dialogueRetryActive=nil,nil
    Call(model.ClearModel,model)
    model:SetAlpha(0)
    model:Hide()
end
function D.Dismiss()
    local frame=Frame()
    if D.active and D.active.demo then D.Close() return true end
    -- Use Blizzard's close routine: it owns the voice handle and conversation dismissal.
    if frame and type(frame.CloseImmediately)=="function" then
        local ok=pcall(frame.CloseImmediately,frame)
        if ok then D.Close() return true end
    end
    Restore()
    return false
end
function D.Show()
    local active=D.active
    if not active or GetTime()>=active.ends or not I.built or not ns.db.retailTalkingHead then return end
    if I.rolls and #I.rolls>0 then return end
    local current=I.current
    if current and D.IsUrgent(current) then return end
    for _,queued in ipairs(I.queue) do
        if D.IsUrgent(queued) then
            if not current then I:Pump() end
            return
        end
    end
    if current and not current.retailDialogue then
        I.current=nil
        if not D.Takes(current) then table.insert(I.queue,1,current) end
    end
    local index=1
    while index<=#I.queue do
        local queued=I.queue[index]
        if not queued.retailDialogue and D.Takes(queued) then table.remove(I.queue,index) else index=index+1 end
    end
    local item={kind="won",key="retailTalkingHead",builderType="retailDialogue",group="world",urgent=true,exact=true,
        transient=true,replay=active.demo,retailDialogue=active,glyph="Speaker",tone=BLUE,cap=L["DIALOGUE"],capColor=BLUE,
        title=active.name,color=C.fg,line=active.text,res=L["%ds"]:format(math.ceil(active.ends-GetTime())),resColor=C.muted,
        hold=math.max(1,active.ends-GetTime()),onClick=false,
        progress=function() return math.max(0,math.min(1,(active.ends-GetTime())/active.duration)) end,
        live=function(card)
            local left=active.ends-GetTime()
            if D.active~=active or left<=0 then card.dur=card.t or 0 return "" end
            return L["%ds"]:format(math.ceil(left))
        end,
        button={label=L["Dismiss"],fn=D.Dismiss},
    }
    I:PushReplace(item)
end
function D.UpdateBubble()
    local active=D.active
    I:SetActivity("talkingHead",active and ns.db.retailTalkingHead and ns.db.bubbleRetailDialogue~=false and {
        glyph="Speaker",tone=BLUE,priority=2,tip=active.name,tip2=L["Click to view the dialogue"],
        onClick=D.Show,text=function() return L["%ds"]:format(math.max(0,math.ceil(active.ends-GetTime()))) end,
    } or nil)
end
local function Capture()
    if not ns.db or not ns.db.retailTalkingHead or not I.built then Restore() return end
    local display,camera,_,duration,line,total,name,text=Call(C_TalkingHead and C_TalkingHead.GetCurrentLineInfo)
    if not Read(name,"string") or not Read(text,"string") or text=="" or not Read(duration,"number") or duration<=0 then
        D.nativeFallback=true;D.Close();return
    end
    D.nativeFallback=nil
    local signature=name..":"..text..":"..(Read(line,"number") and line or 0)
    if D.active and D.active.signature==signature and GetTime()<D.active.ends then return end
    D.serial=D.serial+1
    local kit,intro,loop=Call(C_TalkingHead and C_TalkingHead.GetCurrentLineAnimationInfo)
    local animation
    if Read(kit,"number") then
        animation={kit=kit,intro=Read(intro,"number") and intro or 0,loop=Read(loop,"number") and loop or 0}
    end
    D.active={name=name,text=text,duration=duration,started=GetTime(),ends=GetTime()+duration,signature=signature,animation=animation,
        display=Read(display,"number") and display or nil,camera=Read(camera,"number") and camera or nil,serial=D.serial}
    D.Show()
    D.UpdateBubble()
end
local hooked
local function Hook()
    local frame=Frame()
    if not frame or hooked==frame or not frame.HookScript then return end
    hooked=frame
    SyncOriginal()
    frame:HookScript("OnShow",function()
        D.nativeFallback=nil;SyncOriginal()
        C_Timer.After(0,Capture)
    end)
    frame:HookScript("OnHide",function() D.Close() end)
    if type(frame.PlayCurrent)=="function" and hooksecurefunc then
        pcall(hooksecurefunc,frame,"PlayCurrent",function() D.nativeFallback=nil;SyncOriginal();C_Timer.After(0,Capture) end)
    end
end
function D.Apply()
    Hook()
    SyncOriginal()
    D.UpdateBubble()
    if not ns.db.retailTalkingHead then D.Close() else
        if not ns.db.retailTalkingHeadHide then Restore() end
    end
end
local function PortraitCamera(model,active)
    if not model.dialogueLoaded or not model:IsShown() or model.dialogueCameraSerial==active.serial then return end
    model.dialogueCameraSerial=active.serial
    -- Use a normal portrait camera for the small avatar, not a custom Talking Head scene transform.
    Call(model.SetPosition,model,0,0,0)
    Call(model.SetFacing,model,0)
    Call(model.SetPitch,model,0)
    Call(model.SetRoll,model,0)
    Call(model.SetCamDistanceScale,model,1)
    Call(model.RefreshCamera,model)
    local cameraOK=type(model.SetCamera)=="function" and pcall(model.SetCamera,model,0)
    local zoomOK=type(model.SetPortraitZoom)=="function" and pcall(model.SetPortraitZoom,model,1)
    model.dialogueCameraOK=cameraOK and zoomOK
    model.dialogueCameraMode="portrait"
end
local function RetryPortrait(model,active)
    local token={}
    model.dialogueRetryToken=token
    model.dialogueRetryActive=active
    for _,delay in ipairs({.6,1.5}) do
        C_Timer.After(delay,function()
            if model.dialogueRetryToken~=token or model.dialogueLoaded or D.active~=active
                or model.dialogueActive~=active or GetTime()>=active.ends then return end
            model.dialogueRetries=(model.dialogueRetries or 0)+1
            Call(model.SetDisplayInfo,model,active.display)
        end)
    end
end
function R.LayoutDialogue(w,item)
    local active=item.retailDialogue
    if not active or active~=D.active then
        if w.dialoguePortrait then w.dialoguePortrait:Hide() end
        if not active then SyncOriginal();D.HidePreviews() end
        return
    end
    local width=w.cardWidth or ns.WIDE
    local look=ns.CardLook and ns.CardLook(item)
    local details=not look or look.line~=false
    w.names:SetMaxLines(0)
    w.names:SetWordWrap(true)
    w.names:ClearAllPoints()
    w.names:SetPoint("TOPLEFT",w.frame,"TOPLEFT",14,-64)
    w.names:SetWidth(width-32)
    local textHeight=details and math.max(14,w.names:GetStringHeight() or 14) or 0
    w.bar:ClearAllPoints()
    w.bar:SetPoint("TOPLEFT",w.frame,"TOPLEFT",14,-64-textHeight-10)
    w.bar:SetWidth(width-32)
    local height=64+textHeight+10+4+14+40
    w.btn:ClearAllPoints()
    w.btn:SetPoint("BOTTOMLEFT",w.frame,"TOPLEFT",14,-height+14)
    if active.display and active.display>0 and (not look or look.layout~="centered") then
        if not w.dialoguePortrait then
            local model=CreateFrame("PlayerModel",nil,w.frame)
            model:SetSize(40,40)
            model:SetPoint("TOPLEFT",w.frame,"TOPLEFT",14,-14)
            model:SetScript("OnModelLoaded",function(self)
                self.dialogueLoadEvents=(self.dialogueLoadEvents or 0)+1
                local active=self.dialogueActive
                if not active or active~=D.active then return end
                -- OnModelLoaded can fire inside SetDisplayInfo, before the renderer is shown.
                C_Timer.After(0,function()
                    if self.dialogueActive~=active or D.active~=active then return end
                    local display=Call(self.GetDisplayInfo,self)
                    if Read(display,"number") and display~=active.display then return end
                    self.dialogueLoaded=true
                    self.dialogueRetryToken=nil
                    PortraitCamera(self,active)
                    AnimatePortrait(self)
                    RelayoutStrip()
                end)
            end)
            w.dialoguePortrait=model
        end
        local model=w.dialoguePortrait
        local ok=true
        model.dialogueActive=active
        local hidden=not model:IsShown()
        if w.dialogueSerial~=active.serial or w.dialogueDisplay~=active.display or hidden then
            if w.dialogueDisplay~=active.display or hidden then
                StopPortrait(model)
                model.dialogueLoaded=false
                model.dialogueCameraSerial=nil
                model:SetAlpha(0)
                model.dialogueRetryToken=nil
                Call(model.ClearModel,model)
                -- A hidden PlayerModel may discard its scene. Show it before loading or setting its camera.
                if hidden then model:Show() end
                model.dialogueLoads=(model.dialogueLoads or 0)+1
                ok=type(model.SetDisplayInfo)=="function" and pcall(model.SetDisplayInfo,model,active.display)
                if ok and not model.dialogueLoaded then RetryPortrait(model,active) end
            end
            if ok then
                w.dialogueSerial,w.dialogueDisplay=active.serial,active.display
                PortraitCamera(model,active)
                if not model.dialogueLoaded and model.dialogueRetryActive~=active then RetryPortrait(model,active) end
            end
        end
        if ok then
            PortraitCamera(model,active)
            AnimatePortrait(model)
            -- Keep the renderer alive while loading; its icon only steps aside when it is ready.
            if not model:IsShown() then model:Show() end
            local ready=model.dialogueLoaded and model.dialogueCameraOK~=false
            model:SetAlpha(ready and 1 or 0)
            w.icon:Hide()
            w.tile:SetShown(not ready)
            w.glyph:SetShown(not ready)
        else
            model:Hide();w.icon:Hide();w.tile:Show();w.glyph:Show()
        end
    elseif w.dialoguePortrait then w.dialoguePortrait:Hide() end
    if not active.demo then HideOriginal() end
    return D.LayoutPreviews(w,height,width)
end
function D.Demo()
    if D.active and not D.active.demo then return end
    local sample=R.Sample("retailDialogue")
    D.active={name=sample.title,text=L["There is much to do, champion. Our next adventure awaits."],duration=12,ends=GetTime()+12,demo=true}
    D.Show()
end
function BanzaiSland_TalkingHeadDebug()
    local active=D.active
    if not active and D.lastPortraitDebug then
        local snapshot={last=true}
        for key,value in pairs(D.lastPortraitDebug) do snapshot[key]=value end
        return snapshot
    end
    local w=I.wn
    local model=w and w.dialoguePortrait
    return {
        name=active and active.name,serial=active and active.serial,
        expectedDisplay=active and active.display,expectedCamera=active and active.camera,
        remaining=active and math.max(0,active.ends-GetTime()),
        current=I.current and I.current.retailDialogue==active or false,
        loaded=model and model.dialogueLoaded,shown=model and Call(model.IsShown,model),
        parentShown=w and Call(w.frame.IsShown,w.frame),
        alpha=model and Call(model.GetAlpha,model),modelAlpha=model and Call(model.GetModelAlpha,model),
        actualDisplay=model and Call(model.GetDisplayInfo,model),asset=model and Call(model.GetModelFileID,model),
        loads=model and model.dialogueLoads,loadEvents=model and model.dialogueLoadEvents,
        retries=model and model.dialogueRetries,cameraOK=model and model.dialogueCameraOK,
        cameraMode=model and model.dialogueCameraMode,
        fallback=w and Call(w.glyph.IsShown,w.glyph),layout=w and w.layout,
    }
end
local ev=CreateFrame("Frame")
local since=0
ev:SetScript("OnEvent",function(_,event)
    if event=="TALKINGHEAD_REQUESTED" then
        Hook()
        D.nativeFallback=nil;SyncOriginal()
        C_Timer.After(0,Capture)
    elseif event=="LOADING_SCREEN_ENABLED" or event=="PLAYER_ENTERING_WORLD" then D.Close();D.ResetPortrait()
    elseif event=="TALKINGHEAD_CLOSE" then D.Close()
    else Hook() end
end)
ev:SetScript("OnUpdate",function(_,dt)
    D.StepPreviews(dt)
    since=since+dt;if since<.2 then return end;since=0
    SyncOriginal()
    local active=D.active
    if not active then return end
    if GetTime()>=active.ends or not ns.db.retailTalkingHead then D.Close() return end
    local current=I.current
    if current and current.retailDialogue==active then
        if not active.demo then HideOriginal() end
    else
        SyncOriginal()
        D.HidePreviews()
        if not current or not D.IsUrgent(current) then D.Show() end
    end
end)
for _,event in ipairs({"TALKINGHEAD_REQUESTED","TALKINGHEAD_CLOSE","ADDON_LOADED","PLAYER_LOGIN","LOADING_SCREEN_ENABLED","PLAYER_ENTERING_WORLD"}) do pcall(ev.RegisterEvent,ev,event) end
