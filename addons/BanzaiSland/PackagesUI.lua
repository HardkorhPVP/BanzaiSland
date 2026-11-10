-- The package creator: build an extension from tabs (Details, Features, Settings, Handlers), or share one as
-- text (Import and Export). Nothing here runs code: saving only stores the package; the player switches it on.
local ADDON,ns=...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local K,L,C=ns.Packages,ns.L,ns.C
if not K then return end
local E=ns.Extensions
local win,restoreSettings,Paint,Chrome
local draft,savedId,dirty,painting
local tab,lastForm="details","details"
local index={features=1,settings=1,handlers=1}
local limits={features=8,settings=12,handlers=12}
local confirmDelete,confirmFull,warnKey
local share={reviewed=nil,stage=0,mode="import"}
local rows,tabButtons,fields={}, {}, {}
local shareBox,shareFrame
local bar={}

------------------------------------------------------------------------------------------------
-- widgets (same look and the same text-box care as the settings window)
------------------------------------------------------------------------------------------------
local function Label(parent,text,x,y,width,size)
    local fs=ns.Text(parent,"medium",size or 12,C.muted)
    fs:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);fs:SetWidth(width);fs:SetJustifyH("LEFT");fs:SetText(text)
    return fs
end
local function Button(parent,text,x,y,width,fn)
    local b=CreateFrame("Button",nil,parent);b:SetSize(width,30);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    b.bg=ns.CreatePill(b,30,"ARTWORK",0);b.bg:SetWidth(width);b.bg:SetColor(1,1,1,.1)
    b.text=ns.Text(b,"bold",12.5,C.fg,"CENTER");b.text:SetPoint("CENTER");b.text:SetText(text)
    b:SetScript("OnClick",fn)
    b:SetScript("OnEnter",function() b.bg:SetColor(1,1,1,.17) end)
    b:SetScript("OnLeave",function() b.bg:SetColor(1,1,1,.1) end)
    return b
end
local function Caption(parent,text,x,y,width)
    local fs=ns.Text(parent,"bold",10,C.muted)
    fs:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);fs:SetWidth(width);fs:SetJustifyH("LEFT");fs:SetText(text:upper())
    return fs
end
local function Line(parent,x,y,width,maxLetters,onEdit)
    local e=CreateFrame("EditBox",nil,parent);e:SetSize(width,30);e:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    e.bg=ns.CreatePill(e,30,"BACKGROUND",0);e.bg:SetWidth(width);e.bg:SetColor(1,1,1,.08)
    ns.UseFont(e,"medium",12.5);e:SetTextColor(C.fg[1],C.fg[2],C.fg[3]);e:SetTextInsets(16,16,0,0)
    e:SetAutoFocus(false);e:SetMaxLetters(maxLetters)
    e:SetScript("OnEditFocusGained",function(self) self.bg:SetColor(1,1,1,.16) end)
    e:SetScript("OnEditFocusLost",function(self) self.bg:SetColor(1,1,1,.08) end)
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    -- only what the player typed or pasted counts (the game also reports its own layout changes)
    e:SetScript("OnTextChanged",function(self,userInput) if userInput and not self.locked then onEdit(self:GetText() or "") end end)
    return e
end
-- the multi-line box: the text moves inside a clipped frame to follow the cursor; the layout is touched only when a
-- value really changes (otherwise the game reports the cursor again every frame and clicks never take)
local function Body(parent,x,y,width,height,maxLetters,onEdit)
    local frame=CreateFrame("Frame",nil,parent);frame:SetSize(width,height);frame:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    frame.body=ns.CreateBody(frame,"BACKGROUND",0);frame.body:SetRadius(14);frame.body:SetColor(1,1,1,.065)
    local host=CreateFrame("Frame",nil,frame)
    host:SetPoint("TOPLEFT",14,-12);host:SetPoint("BOTTOMRIGHT",-14,12)
    if host.SetClipsChildren then host:SetClipsChildren(true) end
    local viewH=height-24
    local e=CreateFrame("EditBox",nil,host);e:SetWidth(width-28);e:SetHeight(viewH)
    local offset,placed,textHeight=0,false,nil
    local function Move(v)
        local limit=math.max(0,(e:GetHeight() or 0)-(host:GetHeight() or 0))
        local want=math.min(limit,math.max(0,v))
        if want==offset and placed then return end
        offset,placed=want,true
        e:ClearAllPoints();e:SetPoint("TOPLEFT",host,"TOPLEFT",0,offset)
    end
    Move(0)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel",function(_,delta) Move(offset-delta*32) end)
    ns.UseFont(e,"medium",12);e:SetTextColor(C.fg[1],C.fg[2],C.fg[3])
    e:SetAutoFocus(false);e:SetMultiLine(true);e:SetMaxLetters(maxLetters)
    local caret=e:CreateTexture(nil,"OVERLAY");caret:SetColorTexture(C.fg[1],C.fg[2],C.fg[3],1)
    local cx,cy,ch,blink,focused=0,0,14,0,false
    local function PlaceCaret()
        caret:ClearAllPoints();caret:SetPoint("TOPLEFT",e,"TOPLEFT",cx,cy);caret:SetSize(1.5,math.max(10,ch))
    end
    caret:Hide()
    e:SetScript("OnEditFocusGained",function() focused=true;blink=0;PlaceCaret();caret:Show();frame.body:SetColor(1,1,1,.12) end)
    e:SetScript("OnEditFocusLost",function() focused=false;caret:Hide();frame.body:SetColor(1,1,1,.065) end)
    e:SetScript("OnUpdate",function(_,dt)
        if not focused then return end
        blink=blink+dt
        if blink>.55 then blink=0;caret:SetShown(not caret:IsShown()) end
    end)
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    e:SetScript("OnTextChanged",function(self,userInput)
        local h=math.max(viewH,(self:GetNumLines() or 1)*15+16)
        if h~=textHeight then
            textHeight=h
            self:SetHeight(h)
            Move(offset)
        end
        if userInput then onEdit(self:GetText() or "") end
    end)
    e:SetScript("OnTabPressed",function(self) self:Insert("    ");onEdit(self:GetText() or "") end)
    e:SetScript("OnCursorChanged",function(_,cursorX,cursorY,_,cursorHeight)
        local nx,ny,nh=cursorX or 0,cursorY or 0,cursorHeight or 14
        if nx~=cx or ny~=cy or nh~=ch then
            blink=0;if focused then caret:Show() end
            cx,cy,ch=nx,ny,nh
            PlaceCaret()
        end
        local pos=-ny
        if pos<offset then Move(pos)
        elseif pos+nh>offset+host:GetHeight() then Move(pos+nh-host:GetHeight()) end
    end)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown",function()
        e:SetFocus();e:SetCursorPosition(#(e:GetText() or ""))
    end)
    e.Reset=function() offset,placed=0,false;Move(0) end
    return e,frame
end

------------------------------------------------------------------------------------------------
-- the draft being edited
------------------------------------------------------------------------------------------------
local function Item(t)
    if t=="details" then return draft end
    local list=draft and draft[t]
    if not list then return end
    if index[t]>#list then index[t]=#list end
    if index[t]<1 then index[t]=1 end
    return list[index[t]]
end
local function Say(why,detail) if win then win.message={why=why,detail=detail};win.note=nil end end
local function Note(text) if win then win.note=text;win.message=nil end end
local function Edited()
    if painting or not win then return end
    dirty=true;confirmDelete=nil;confirmFull=nil;warnKey=nil;win.message=nil;win.note=nil
    Chrome()
end
local function Guard(key)
    if not dirty then return true end
    if warnKey==key then warnKey=nil;return true end
    warnKey=key;Say("unsaved");Chrome();return false
end
local function Fresh()
    draft=K.NewDraft();savedId=nil;dirty=false
    index={features=1,settings=1,handlers=1}
    confirmDelete,confirmFull,warnKey=nil,nil,nil
end
local function LoadSaved(id)
    local p=id and K.Get(id)
    if not p then Fresh();return end
    draft=K.Copy(p);savedId=id;dirty=false
    index={features=1,settings=1,handlers=1}
    confirmDelete,confirmFull,warnKey=nil,nil,nil
end

------------------------------------------------------------------------------------------------
-- fields: each is a caption and a widget bound to one key of the current item
------------------------------------------------------------------------------------------------
-- the icon and colour picker: a grid of glyphs and a row of colours in a small drawer, like the extension settings
local lookPop,lookCatcher,OpenLook
local LOOK_COLS,LOOK_CELL,LOOK_GAP,LOOK_PAD=8,30,4,12
local function CloseLook() if lookPop and lookPop:IsShown() then lookPop:Hide() end end
local function ColorRGB(id,colors)
    if id=="accent" then return ns.Accent() end
    for _,c in ipairs(colors) do if c.id==id and c.rgb then return c.rgb end end
    return C.fg
end
local function PaintLook()
    local pop=lookPop;local item=pop and pop.item
    if not item then return end
    local a=ns.Accent()
    local tint=ColorRGB(item.color or "default",pop.colors)
    for _,cell in ipairs(pop.cells) do
        cell.icon:SetVertexColor(tint[1],tint[2],tint[3],1)
        cell.hl:SetColor(a[1],a[2],a[3],cell.id==item.art and .30 or 0)
    end
    pop.own.bg:SetColor(a[1],a[2],a[3],item.art==nil and .35 or .10)
    for _,sw in ipairs(pop.swatches) do
        local on=(sw.id=="default" and item.color==nil) or sw.id==item.color
        sw.hl:SetColor(a[1],a[2],a[3],on and .30 or 0)
        local c=ColorRGB(sw.id,pop.colors)
        sw.dot:SetVertexColor(c[1],c[2],c[3],sw.id=="default" and .45 or 1)
    end
    pop.pinned.bg:SetColor(a[1],a[2],a[3],item.place=="pinned" and .35 or .10)
    pop.bubble.bg:SetColor(a[1],a[2],a[3],item.place=="bubble" and .35 or .10)
end
local function LookChanged() Edited();PaintLook();if win then Paint() end end
local function Tip(frame,text)
    frame:SetScript("OnEnter",function(f) if GameTooltip then GameTooltip:SetOwner(f,"ANCHOR_TOP");GameTooltip:SetText(text,1,1,1);GameTooltip:Show() end end)
    frame:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
end
local function BuildLook()
    lookCatcher=CreateFrame("Button",nil,win)
    lookCatcher:SetAllPoints(UIParent)
    lookCatcher:SetFrameLevel(win:GetFrameLevel()+40)
    lookCatcher:RegisterForClicks("AnyUp")
    lookCatcher:SetScript("OnClick",CloseLook)
    lookCatcher:Hide()
    local pop=CreateFrame("Frame",nil,win)
    lookPop=pop
    pop:SetFrameLevel(win:GetFrameLevel()+41)
    pop:EnableMouse(true);pop:SetClampedToScreen(true)
    pop.body=ns.CreateBody(pop,"BACKGROUND",0);pop.body:SetColor(.10,.10,.12,1);pop.body:SetRadius(14)
    local inner=LOOK_COLS*LOOK_CELL+(LOOK_COLS-1)*LOOK_GAP
    pop.colors=E.Colors()
    local y=LOOK_PAD
    local function Head(text)
        local t=ns.Text(pop,"bold",10,C.muted);t:SetPoint("TOPLEFT",pop,"TOPLEFT",LOOK_PAD,-y);t:SetText(text)
        y=y+16
        return t
    end
    Head(L["ART"])
    pop.own=Button(pop,L["Extension's own icon"],LOOK_PAD,-y,inner,function() pop.item.art=nil;LookChanged() end)
    y=y+36
    pop.cells={}
    local arts=E.Art()
    for i,art in ipairs(arts) do
        local cell=CreateFrame("Button",nil,pop);cell:SetSize(LOOK_CELL,LOOK_CELL)
        local col,row=(i-1)%LOOK_COLS,math.floor((i-1)/LOOK_COLS)
        cell:SetPoint("TOPLEFT",pop,"TOPLEFT",LOOK_PAD+col*(LOOK_CELL+LOOK_GAP),-(y+row*(LOOK_CELL+LOOK_GAP)))
        cell.hl=ns.CreateBody(cell,"BACKGROUND",1);cell.hl:SetRadius(9);cell.hl:SetColor(1,1,1,0)
        cell.icon=ns.Image(cell,art.id,"ARTWORK",0);cell.icon:SetSize(18,18);cell.icon:SetPoint("CENTER",cell,"CENTER",0,0)
        cell.id=art.id
        Tip(cell,art.name)
        cell:SetScript("OnClick",function() pop.item.art=art.id;LookChanged() end)
        pop.cells[i]=cell
    end
    y=y+math.ceil(#arts/LOOK_COLS)*(LOOK_CELL+LOOK_GAP)+4
    Head(L["COLOR"])
    pop.swatches={}
    for i,c in ipairs(pop.colors) do
        local sw=CreateFrame("Button",nil,pop);sw:SetSize(LOOK_CELL,LOOK_CELL)
        local col,row=(i-1)%LOOK_COLS,math.floor((i-1)/LOOK_COLS)
        sw:SetPoint("TOPLEFT",pop,"TOPLEFT",LOOK_PAD+col*(LOOK_CELL+LOOK_GAP),-(y+row*(LOOK_CELL+LOOK_GAP)))
        sw.hl=ns.CreateBody(sw,"BACKGROUND",1);sw.hl:SetRadius(9);sw.hl:SetColor(1,1,1,0)
        sw.dot=ns.Image(sw,"Circle","ARTWORK",0);sw.dot:SetSize(18,18);sw.dot:SetPoint("CENTER",sw,"CENTER",0,0)
        sw.id=c.id
        Tip(sw,c.name)
        sw:SetScript("OnClick",function() pop.item.color=(c.id~="default") and c.id or nil;LookChanged() end)
        pop.swatches[i]=sw
    end
    y=y+math.ceil(#pop.colors/LOOK_COLS)*(LOOK_CELL+LOOK_GAP)+4-LOOK_GAP
    pop.baseH=y+LOOK_PAD
    pop.placeLabel=ns.Text(pop,"bold",10,C.muted);pop.placeLabel:SetPoint("TOPLEFT",pop,"TOPLEFT",LOOK_PAD,-y);pop.placeLabel:SetText(L["KEPT-UP BUBBLES SHOW"])
    y=y+16
    local half=math.floor((inner-8)/2)
    pop.pinned=Button(pop,L["Pinned"],LOOK_PAD,-y,half,function() pop.item.place=pop.item.place~="pinned" and "pinned" or nil;LookChanged() end)
    pop.bubble=Button(pop,L["With other bubbles"],LOOK_PAD+half+8,-y,half,function() pop.item.place=pop.item.place~="bubble" and "bubble" or nil;LookChanged() end)
    y=y+34
    pop.placeH=y+LOOK_PAD-pop.baseH
    pop:SetSize(inner+2*LOOK_PAD,pop.baseH)
    pop:SetScript("OnShow",function() lookCatcher:Show() end)
    pop:SetScript("OnHide",function() lookCatcher:Hide();pop.owner=nil end)
    win:HookScript("OnHide",CloseLook)
    pop:Hide()
end
OpenLook=function(owner)
    local item=Item("features");if not item then return end
    if not lookPop then BuildLook() end
    if lookPop:IsShown() and lookPop.owner==owner then CloseLook();return end
    lookPop.owner,lookPop.item=owner,item
    local bubble=item.kind=="bubble"
    lookPop.placeLabel:SetShown(bubble);lookPop.pinned:SetShown(bubble);lookPop.bubble:SetShown(bubble)
    lookPop:SetHeight(lookPop.baseH+(bubble and lookPop.placeH or 0))
    PaintLook()
    lookPop:ClearAllPoints()
    local h=lookPop:GetHeight()
    local bottom=owner:GetBottom()
    if bottom and bottom-h-4<8 then lookPop:SetPoint("BOTTOMLEFT",owner,"TOPLEFT",0,4)
    else lookPop:SetPoint("TOPLEFT",owner,"BOTTOMLEFT",0,-4) end
    lookPop:Show()
end
local OnOff={{v=true,label=L["On"]},{v=false,label=L["Off"]}}
local function FeatureValues()
    local v={}
    for _,f in ipairs(draft and draft.features or {}) do if type(f.id)=="string" then v[#v+1]={v=f.id,label=(f.name and f.name~="" and f.name or f.id)} end end
    return v
end
local function ChoicesText(item)
    local out={}
    for _,c in ipairs(item.choices or {}) do out[#out+1]=tostring(c.id).."="..tostring(c.name) end
    return table.concat(out,", ")
end
local function ParseChoices(text)
    local list={}
    for part in text:gmatch("[^,]+") do
        local id,name=part:match("^%s*([A-Za-z0-9_%-]+)%s*=%s*(.-)%s*$")
        if id and name and name~="" then list[#list+1]={id=id,name=name} end
    end
    return list
end
-- changing a setting's kind drops what the other kinds do not allow
local function SetSettingType(item,v)
    item.type=v
    item.min,item.max,item.step,item.choices,item.default=nil,nil,nil,nil,nil
    if v=="toggle" then item.default=false
    elseif v=="slider" then item.min,item.max,item.step,item.default=0,10,1,5
    else item.choices={{id="a",name="A"},{id="b",name="B"}};item.default="a" end
end
local specs={
    details={
        {key="id",kind="line",label=L["Package id"],x=234,y=-146,w=524,max=64,lock=function() return savedId~=nil end},
        {key="name",kind="line",label=L["Name"],x=234,y=-212,w=524,max=64},
        {key="author",kind="line",label=L["Author"],x=234,y=-278,w=300,max=64},
        {key="version",kind="line",label=L["Version"],x=546,y=-278,w=212,max=32},
        {key="notes",kind="line",label=L["Notes"],x=234,y=-344,w=524,max=1024},
        {key="full",kind="cycle",label=L["Lua access"],x=234,y=-410,w=524,none=false,
            values={{v=false,label=L["Sandbox: read-only game queries (recommended)"]},{v=true,label=L["Full Lua: like a normal addon (only for code you trust)"]}},
            set=function(item,v) item.full=v and true or nil;confirmFull=nil end},
    },
    features={
        {key="id",kind="line",label=L["Feature id"],x=234,y=-196,w=250,max=64,
            set=function(item,text)
                local old=item.id;item.id=text
                for _,h in ipairs(draft.handlers) do if h.feature==old then h.feature=text end end
            end},
        {key="kind",kind="cycle",label=L["Shows"],x=500,y=-196,w=120,values={{v="card",label=L["Card"]},{v="bubble",label=L["Bubble"]}},
            set=function(item,v) item.kind=v;if v~="bubble" then item.place=nil end end},
        {key="default",kind="cycle",label=L["Starts"],x=630,y=-196,w=128,values=OnOff},
        {key="name",kind="line",label=L["Name"],x=234,y=-262,w=524,max=64},
        {key="description",kind="line",label=L["Description"],x=234,y=-328,w=524,max=160},
        {key="look",kind="look",label=L["Look: icon and colour"],x=234,y=-394,w=524},
        {key="sound",kind="cycle",label=L["Suggested sound (the player can change it)"],x=234,y=-460,w=524,none="none",
            valuesFn=function() local v={};for i,s in ipairs(E.Sounds()) do v[i]={v=s.id,label=s.name} end return v end},
    },
    settings={
        {key="key",kind="line",label=L["Setting key"],x=234,y=-196,w=250,max=64},
        {key="type",kind="cycle",label=L["Kind"],x=500,y=-196,w=258,
            values={{v="toggle",label=L["Switch"]},{v="slider",label=L["Slider"]},{v="choice",label=L["Choice"]}},set=SetSettingType},
        {key="name",kind="line",label=L["Name"],x=234,y=-262,w=524,max=64},
        {key="description",kind="line",label=L["Description"],x=234,y=-328,w=524,max=160},
        {key="default",kind="cycle",label=L["Starts"],x=234,y=-394,w=524,values=OnOff,show=function(i) return i.type=="toggle" end,id="defaultToggle"},
        {key="min",kind="num",label=L["Smallest"],x=234,y=-394,w=120,max=12,show=function(i) return i.type=="slider" end},
        {key="max",kind="num",label=L["Largest"],x=364,y=-394,w=120,max=12,show=function(i) return i.type=="slider" end},
        {key="step",kind="num",label=L["Step"],x=494,y=-394,w=120,max=12,show=function(i) return i.type=="slider" end},
        {key="default",kind="num",label=L["Starts at"],x=624,y=-394,w=134,max=12,show=function(i) return i.type=="slider" end,id="defaultNumber"},
        {key="choices",kind="line",label=L["Choices (id=Name, id=Name)"],x=234,y=-394,w=524,max=600,show=function(i) return i.type=="choice" end,
            get=ChoicesText,set=function(item,text) item.choices=ParseChoices(text) end},
        {key="default",kind="line",label=L["Starts as (a choice id)"],x=234,y=-460,w=524,max=64,show=function(i) return i.type=="choice" end,id="defaultChoice"},
    },
    handlers={
        {key="name",kind="line",label=L["Handler name"],x=234,y=-192,w=340,max=64},
        {key="enabled",kind="cycle",label=L["Status"],x=586,y=-192,w=172,values=OnOff,none=true,
            set=function(item,v) if v then item.enabled=nil else item.enabled=false end end},
        {key="events",kind="line",label=L["Events (comma separated, up to 8)"],x=234,y=-252,w=524,max=600},
        {key="unit",kind="line",label=L["Unit filter (optional)"],x=234,y=-312,w=150,max=32},
        {key="interval",kind="num",label=L["Interval (s)"],x=394,y=-312,w=110,max=8},
        {key="feature",kind="cycle",label=L["Output"],x=514,y=-312,w=244,valuesFn=FeatureValues},
        {key="code",kind="body",label=L["Lua body: event, state, ctx, ... returns a payload or nil"],x=234,y=-376,w=524,h=144,max=8192},
    },
}
local function CycleValues(spec) return spec.valuesFn and spec.valuesFn() or spec.values end
local function CycleLabel(spec,item)
    local current=item[spec.key]
    if current==nil then current=spec.none end
    for _,e in ipairs(CycleValues(spec)) do if e.v==current then return e.label end end
    return L["(none)"]
end
local function Build(tabName,spec)
    local f={spec=spec,tab=tabName}
    f.caption=Caption(win,spec.label,spec.x+16,spec.y,spec.w)
    local function Write(item,value)
        if spec.set then spec.set(item,value) else item[spec.key]=value end
    end
    if spec.kind=="line" or spec.kind=="num" then
        f.widget=Line(win,spec.x,spec.y-18,spec.w,spec.max or 64,function(text)
            local item=Item(tabName);if not item then return end
            if spec.kind=="num" then Write(item,tonumber(text)) else
                if spec.key=="default" and spec.id=="defaultChoice" then item.default=text~="" and text or nil
                else Write(item,text) end
            end
            Edited()
        end)
        f.frame=f.widget
    elseif spec.kind=="look" then
        f.widget=Button(win,"",spec.x,spec.y-18,spec.w,function() OpenLook(f.widget) end)
        f.widget.preview=CreateFrame("Frame",nil,f.widget);f.widget.preview:SetSize(22,22);f.widget.preview:SetPoint("LEFT",f.widget,"LEFT",10,0)
        f.widget.preview.body=ns.CreateBody(f.widget.preview,"BACKGROUND",0);f.widget.preview.body:SetRadius(11);f.widget.preview.body:SetColor(0,0,0,1)
        f.widget.preview.icon=ns.Image(f.widget.preview,"Bell","ARTWORK",0);f.widget.preview.icon:SetSize(14,14);f.widget.preview.icon:SetPoint("CENTER")
        f.frame=f.widget
    elseif spec.kind=="cycle" then
        f.widget=Button(win,"",spec.x,spec.y-18,spec.w,function()
            local item=Item(tabName);if not item then return end
            local values=CycleValues(spec)
            if #values==0 then return end
            local current=item[spec.key]
            if current==nil then current=spec.none end
            local at=0
            for i,e in ipairs(values) do if e.v==current then at=i;break end end
            local nextValue=values[at%#values+1].v
            if spec.none~=nil and nextValue==spec.none and not spec.set then item[spec.key]=nil
            else Write(item,nextValue) end
            Edited();Paint()
        end)
        f.frame=f.widget
    else
        f.widget,f.frame=Body(win,spec.x,spec.y-18,spec.w,spec.h,spec.max,function(text)
            local item=Item(tabName);if not item then return end
            Write(item,text);Edited()
        end)
    end
    fields[#fields+1]=f
    return f
end
local function RefreshField(f)
    local spec,item=f.spec,Item(f.tab)
    local on=item~=nil and f.tab==tab and (not spec.show or spec.show(item))
    f.caption:SetShown(on);f.frame:SetShown(on)
    if not on then if f.widget.ClearFocus and f.widget.GetText then f.widget:ClearFocus() end return end
    if spec.kind=="look" then
        local artName,colorName=L["Extension's own icon"],L["Default"]
        for _,a in ipairs(E.Art()) do if a.id==item.art then artName=a.name end end
        local colors=E.Colors()
        for _,c in ipairs(colors) do if c.id==item.color then colorName=c.name end end
        f.widget.text:SetText(artName..", "..colorName)
        local tint=item.color and ColorRGB(item.color,colors) or (item.art and C.fg or C.muted)
        f.widget.preview.icon:SetTexture("Interface\\AddOns\\BanzaiSland\\Media\\"..(item.art or "Bell"))
        f.widget.preview.icon:SetVertexColor(tint[1],tint[2],tint[3],1)
    elseif spec.kind=="cycle" then
        f.widget.text:SetText(CycleLabel(spec,item))
    else
        local value
        if spec.get then value=spec.get(item)
        else value=item[spec.key] end
        local text=value==nil and "" or tostring(value)
        if f.widget:GetText()~=text then
            f.widget:SetText(text)
            if f.widget.Reset then f.widget.Reset() end
        end
        local locked=spec.lock and spec.lock() or false
        f.widget.locked=locked
        if f.widget.EnableMouse then f.widget:EnableMouse(not locked) end
        f.widget:SetAlpha(locked and .55 or 1)
    end
end
local function SetShareText(text)
    painting=true
    shareBox:SetText(text or "")
    if shareBox.Reset then shareBox.Reset() end
    shareBox:SetCursorPosition(0)
    painting=false
end

------------------------------------------------------------------------------------------------
-- painting
------------------------------------------------------------------------------------------------
local function EnabledNow(id)
    for _,e in ipairs(E.List()) do if e.id==id then return e.enabled end end
    return false
end
local function Summary(p,state)
    local who=p.author and p.author~="" and p.author or L["unknown author"]
    local line=string.format(L["%s, by %s: %d features, %d settings, %d handlers."],p.name,who,#p.features,#p.settings,#p.handlers)
    local power=p.full and L["It asks for FULL Lua access, like a normal addon."] or L["Its code runs in a small sandbox with read-only game queries."]
    local action
    if state=="new" then action=L["Read the code above. Press Install to add it; it starts switched off."]
    elseif state=="changed" then action=L["It replaces the installed package with the same id. Press Install to update it; it will be switched off."]
    else action=L["Identical to the installed package: nothing to change."] end
    return line.." "..power.."\n"..action
end
local function StatusText()
    if win.message then return K.Reason(win.message.why,win.message.detail) end
    if win.note then return win.note end
    if tab=="share" then
        if share.reviewed then return share.reviewed end
        if share.mode=="export" then return L["Copy this string (Ctrl+A, then Ctrl+C) and send it to someone."] end
        return L["Paste a package string in the box, then press Review to read it."]
    end
    if confirmDelete then return L["Press Delete again to remove this package."] end
    if dirty then return L["Unsaved changes. Save stores the package; a changed package is switched off until you turn it on."] end
    if savedId and tab=="handlers" then
        -- the handler being edited: how it last ran and exactly what it sent
        local p=K.Get(savedId)
        local h=p and p.handlers[index.handlers]
        if h then
            local s=K.Status(savedId,index.handlers)
            local lines={h.name..": "..K.Reason(s.reason)..(s.error and (" - "..s.error) or "")}
            if s.lastEvent then
                lines[#lines+1]=string.format(L["Last run: %s, %d s ago"],s.lastEvent,math.floor(s.lastAgo or 0))
                lines[#lines+1]=s.last and (L["Sent:"].." "..s.last) or L["Sent nothing."]
            else lines[#lines+1]=L["Has not run yet this session. Test runs it once."] end
            return table.concat(lines,"\n")
        end
    end
    if savedId then
        local lines,p={},K.Get(savedId)
        if p then
            for i,h in ipairs(p.handlers) do
                local s=K.Status(savedId,i)
                lines[#lines+1]=h.name..": "..K.Reason(s.reason)..(s.error and (" - "..s.error) or "")
            end
        end
        return table.concat(lines,"\n")
    end
    return L["A new package. Fill in the tabs and press Save."]
end
Chrome=function()
    if not win then return end
    local list=K.List()
    local shown=0
    local pending=savedId==nil
    for i,row in ipairs(rows) do
        local r,label,id
        if pending and i==1 then label=(draft and draft.name~="" and draft.name or L["New package"]);id=false
        else
            r=list[i-(pending and 1 or 0)]
            if r then label=r.name;id=r.id end
        end
        row.id=id
        row:SetShown(id~=nil)
        if id~=nil then
            local sel=(id==false) or id==savedId
            row.text:SetText(label);row.text:SetTextColor(unpack(sel and ns.Accent() or C.fg))
            row.bg:SetColor(1,1,1,sel and .13 or .04)
            if id==false then row.dot:SetText(L["New"])
            else row.dot:SetText(r.broken and L["Damaged"] or (EnabledNow(r.id) and L["On"] or L["Off"])) end
        end
    end
    win.trust.text:SetText(K.Trusted() and L["Package code allowed"] or L["Allow package code"])
    for name,b in pairs(tabButtons) do
        b.text:SetTextColor(unpack(name==tab and ns.Accent() or C.fg))
        b.bg:SetColor(1,1,1,name==tab and .16 or .08)
    end
    local isShare=tab=="share"
    local isList=tab=="features" or tab=="settings" or tab=="handlers"
    for _,e in pairs(bar) do e:SetShown(isList) end
    if isList then
        local items=draft[tab]
        local noun=({features=L["Feature"],settings=L["Setting"],handlers=L["Handler"]})[tab]
        local item=Item(tab)
        if item then
            local nm=item.name or item.key or ""
            bar.label:SetText(string.format(L["%s %d of %d: %s"],noun,index[tab],#items,nm))
        else bar.label:SetText(string.format(L["No %s yet"],noun:lower())) end
        bar.add:SetAlpha(#items<limits[tab] and 1 or .4)
        bar.remove:SetAlpha(item and 1 or .4)
    end
    local saved=savedId~=nil
    win.enable.text:SetText(saved and EnabledNow(savedId) and L["Disable"] or L["Enable"])
    for _,b in ipairs({win.enable,win.test,win.export,win.delete}) do b:SetAlpha(saved and 1 or .4) end
    win.delete.text:SetText(confirmDelete and L["Delete?"] or L["Delete"])
    for _,b in ipairs({win.save,win.enable,win.test,win.export,win.delete,win.discard}) do b:SetShown(not isShare) end
    win.shareSave:SetShown(isShare);win.shareBack:SetShown(isShare)
    win.shareSave.text:SetText(share.reviewed and L["Install"] or L["Review"])
    win.status:SetText(StatusText())
end
Paint=function()
    if not win then return end
    if lookPop and lookPop:IsShown() and (tab~="features" or lookPop.item~=Item("features")) then CloseLook() end
    painting=true
    for _,f in ipairs(fields) do RefreshField(f) end
    painting=false
    shareFrame:SetShown(tab=="share");win.shareCaption:SetShown(tab=="share")
    if tab~="share" and shareBox then shareBox:ClearFocus() end
    Chrome()
end
function K.IsOpen() return win and win:IsShown() or false end
-- read-only view of the window's parts, for the tests
function K.UIState() return {fields=fields,draft=draft,tab=tab,saved=savedId,dirty=dirty} end
function K.Close() if win then win:Hide() end end

local function ShowTab(name)
    if name=="share" then lastForm=tab~="share" and tab or lastForm else lastForm=name end
    tab=name;warnKey=nil
    Paint()
end
local function AddItem()
    local list=draft and draft[tab];if not list then return end
    if #list>=limits[tab] then Note(string.format(L["Up to %d allowed."],limits[tab]));Chrome();return end
    local n=#list+1
    if tab=="features" then list[n]={id="feature"..n,kind="card",name=L["New feature"],description="",default=true}
    elseif tab=="settings" then list[n]={key="setting"..n,type="toggle",name=L["New setting"],description="",default=false}
    else
        local first=draft.features[1]
        list[n]={name=L["New handler"],events="BAG_UPDATE_DELAYED",unit="",interval=1,feature=first and first.id or nil,code=K.Sample(first and first.kind or "card")}
    end
    index[tab]=n;Edited();Paint()
end
local function RemoveItem()
    local list=draft and draft[tab];if not list or not list[index[tab]] then return end
    table.remove(list,index[tab])
    if index[tab]>#list then index[tab]=math.max(1,#list) end
    Edited();Paint()
end
local function Save()
    confirmDelete=nil
    if draft.full and not (savedId and (K.Get(savedId) or {}).full) and not confirmFull then
        confirmFull=true;Say("full_lua");Chrome();return
    end
    local ok,why,id=K.Save(draft)
    if ok then
        LoadSaved(id);Say(why)
        Paint()
    else
        Say(why,id);Chrome()
    end
end
local function Review()
    local text=shareBox:GetText() or ""
    local p,state,detail=K.Compare(text)
    if not p then Say(state,detail);Chrome();return end
    if state=="same" then Say("same");Chrome();return end
    SetShareText(K.Serialize(p))
    share.reviewed=Summary(p,state);share.stage=1;win.message=nil;win.note=nil
    Chrome()
end
local function ShareInstall()
    if not share.reviewed then Review();return end
    local text=shareBox:GetText() or ""
    local p=K.Read(text)
    if p and p.full and share.stage<2 then share.stage=2;Say("full_lua");Chrome();return end
    local ok,why,detail=K.Install(text)
    if ok then
        local id=detail
        share.reviewed=nil;share.stage=0
        LoadSaved(id);tab="details";lastForm="details"
        Paint();Say(why);Chrome()
    else Say(why,detail);Chrome() end
end
local function OpenShare(mode,text)
    share.mode=mode;share.reviewed=nil;share.stage=0;win.message=nil;win.note=nil
    SetShareText(text or "")
    ShowTab("share")
    shareBox:SetFocus()
    if mode=="export" then shareBox:HighlightText() end
end

function K.Open(arg)
    local settings=_G.BanzaiSlandSettingsFrame
    if settings and settings:IsShown() then restoreSettings=settings;settings:Hide() end
    if not win then
        win=CreateFrame("Frame","BanzaiSlandPackagesEditor",UIParent)
        win:SetSize(780,690);win:SetPoint("CENTER");win:SetFrameStrata("DIALOG");win:SetClampedToScreen(true)
        win:SetScale(math.min(1,(UIParent:GetWidth()-30)/780,(UIParent:GetHeight()-30)/690))
        win:EnableMouse(true);win:SetMovable(true);win:RegisterForDrag("LeftButton")
        win:SetScript("OnDragStart",function(self) self:StartMoving() end)
        win:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        win:SetScript("OnHide",function()
            if shareBox then shareBox:ClearFocus() end
            for _,f in ipairs(fields) do if f.widget.ClearFocus and f.widget.GetText then f.widget:ClearFocus() end end
            if restoreSettings then local s=restoreSettings;restoreSettings=nil;s:Show() end
        end)
        win.body=ns.CreateBody(win,"BACKGROUND",0);win.body:SetColor(0.03,0.03,0.04,0.97);win.body:SetRadius(26)
        local rule=win:CreateTexture(nil,"BORDER");rule:SetColorTexture(1,1,1,.06);rule:SetWidth(1)
        rule:SetPoint("TOPLEFT",win,"TOPLEFT",221,-100);rule:SetPoint("BOTTOMLEFT",win,"BOTTOMLEFT",221,26)
        local title=ns.Text(win,"extra",20,C.fg);title:SetPoint("TOPLEFT",win,"TOPLEFT",24,-20);title:SetText(L["Package creator"])
        local close=CreateFrame("Button",nil,win);close:SetSize(26,26);close:SetPoint("TOPRIGHT",win,"TOPRIGHT",-14,-16)
        close.x=ns.Image(close,"Close","ARTWORK",0);close.x:SetSize(14,14);close.x:SetPoint("CENTER",close,"CENTER",0,0)
        close.x:SetVertexColor(C.muted[1],C.muted[2],C.muted[3],1)
        close:SetScript("OnEnter",function() close.x:SetVertexColor(1,1,1,1) end)
        close:SetScript("OnLeave",function() close.x:SetVertexColor(C.muted[1],C.muted[2],C.muted[3],1) end)
        close:SetScript("OnClick",function() win:Hide() end)
        local warning=Label(win,L["Build an extension from tabs, or import one from text. Only install packages you trust: read the code first. Packages can only show cards and bubbles."],22,-52,736,11.5)
        warning:SetWordWrap(true)
        win.trust=Button(win,"",22,-102,190,function()
            if ns.Developer then ns.Developer.SetTrusted(not ns.Developer.Trusted()) end;win.message=nil;win.note=nil;Chrome()
        end)
        Button(win,L["New package"],22,-140,94,function()
            if not Guard("new") then return end
            Fresh();tab="details";lastForm="details";win.message=nil;win.note=nil;Paint()
        end)
        Button(win,L["Import"],122,-140,90,function()
            if tab~="share" and not Guard("import") then return end
            OpenShare("import","")
        end)
        for i=1,9 do
            local row=Button(win,"",22,-180-(i-1)*32,190,function(self)
                if self.id==false then
                    if tab=="share" then ShowTab(lastForm) end
                    return
                end
                if self.id==savedId and tab~="share" then return end
                if not Guard("row"..tostring(self.id)) then return end
                LoadSaved(self.id);tab="details";lastForm="details";win.message=nil;win.note=nil;Paint()
            end)
            row.text:ClearAllPoints();row.text:SetPoint("LEFT",10,0);row.text:SetWidth(132);row.text:SetJustifyH("LEFT")
            row.dot=ns.Text(row,"medium",10,C.muted,"RIGHT");row.dot:SetPoint("RIGHT",-8,0)
            rows[i]=row
        end
        local tabs={{"details",L["Details"],234,122},{"features",L["Features"],362,122},{"settings",L["Settings"],490,122},{"handlers",L["Handlers"],618,140}}
        for _,t in ipairs(tabs) do
            local b=Button(win,t[2],t[3],-104,t[4],function() ShowTab(t[1]);win.message=nil;win.note=nil;Chrome() end)
            tabButtons[t[1]]=b
        end
        -- the item bar of the list tabs
        bar.prev=Button(win,"<",234,-146,36,function()
            if index[tab]>1 then index[tab]=index[tab]-1;Paint() end
        end)
        bar.next=Button(win,">",276,-146,36,function()
            local list=draft[tab];if list and index[tab]<#list then index[tab]=index[tab]+1;Paint() end
        end)
        bar.label=Label(win,"",322,-153,270,12)
        bar.add=Button(win,L["Add"],600,-146,76,AddItem)
        bar.remove=Button(win,L["Remove"],682,-146,76,RemoveItem)
        for _,name in ipairs({"details","features","settings","handlers"}) do
            for _,spec in ipairs(specs[name]) do Build(name,spec) end
        end
        -- the share view (Import and Export)
        win.shareCaption=Caption(win,L["Package text"],250,-146,508)
        shareBox,shareFrame=Body(win,234,-164,524,370,140000,function()
            if painting then return end
            share.reviewed=nil;share.stage=0;win.message=nil;win.note=nil;Chrome()
        end)
        win.shareSave=Button(win,L["Review"],234,-552,110,ShareInstall)
        win.shareBack=Button(win,L["Back"],352,-552,96,function() ShowTab(lastForm);win.message=nil;win.note=nil;Chrome() end)
        -- bottom row of the form view
        win.save=Button(win,L["Save"],234,-552,84,Save)
        win.enable=Button(win,L["Enable"],324,-552,84,function()
            if not savedId then Say("not_found");Chrome();return end
            if dirty then Say("unsaved");Chrome();return end
            if EnabledNow(savedId) then E.SetEnabled(savedId,false);win.message=nil;win.note=nil
            else
                if not K.Trusted() then Say("trust_required");Chrome();return end
                E.SetEnabled(savedId,true);K.Restart(savedId);win.message=nil;win.note=nil
            end
            Chrome()
        end)
        win.test=Button(win,L["Test"],414,-552,84,function()
            if not savedId then Say("not_found");Chrome();return end
            if dirty then Say("unsaved");Chrome();return end
            local p=K.Get(savedId);if not p then Say("invalid_package");Chrome();return end
            if tab=="handlers" and p.handlers[index.handlers] then
                -- on the Handlers tab, Test runs the handler being edited and the status line shows what it sent
                local h=p.handlers[index.handlers]
                if h.enabled~=false then K.Test(savedId,index.handlers) end
                win.note=nil;win.message=nil;Chrome();return
            end
            local lines={}
            for i,h in ipairs(p.handlers) do
                if h.enabled==false then lines[#lines+1]=h.name..": "..K.Reason("disabled")
                else
                    local ok,why=K.Test(savedId,i)
                    local s=K.Status(savedId,i)
                    lines[#lines+1]=h.name..": "..K.Reason(ok and why or s.reason)
                end
            end
            Note(table.concat(lines,"\n"));Chrome()
        end)
        win.export=Button(win,L["Export"],504,-552,84,function()
            if not savedId then Say("not_found");Chrome();return end
            if dirty then Say("unsaved");Chrome();return end
            local text=K.Export(savedId)
            if not text then Say("not_found");Chrome();return end
            OpenShare("export",text)
        end)
        win.delete=Button(win,L["Delete"],594,-552,84,function()
            if not savedId then Say("not_found");Chrome();return end
            if not confirmDelete then confirmDelete=savedId;win.message=nil;win.note=nil;Chrome();return end
            K.Delete(savedId);confirmDelete=nil
            local list=K.List()
            if list[1] then LoadSaved(list[1].id) else Fresh() end
            tab="details";Paint();Say("deleted");Chrome()
        end)
        win.discard=Button(win,L["Discard"],684,-552,74,function()
            if savedId then LoadSaved(savedId) else Fresh() end
            win.message=nil;win.note=nil;Paint()
        end)
        win.status=Label(win,"",234,-596,524,14)
        win.status:SetTextColor(unpack(C.fg));win.status:SetWordWrap(true);win.status:SetHeight(84)
        K.OnChanged=function() if win:IsShown() then Chrome() end end
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="BanzaiSlandPackagesEditor" end
        local list=K.List()
        if list[1] then LoadSaved(list[1].id) else Fresh() end
    end
    win:Show()
    win.message=nil;win.note=nil
    if arg=="import" then
        OpenShare("import","")
    elseif type(arg)=="string" and K.Get(arg) then
        if tab=="share" then tab=lastForm end
        if arg~=savedId then LoadSaved(arg) end
        tab="details";lastForm="details";Paint()
    else
        Paint()
    end
end
