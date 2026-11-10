-- Island: the activity shelf. A click on a bubble (or on the "+N" chip) opens a small panel that
-- lists every live activity: what it is, what it is doing now, and buttons to pin it beside the
-- island and to move it up or down. Pins and order are kept per settings profile (ns.db.shelf),
-- so they work for Island's own bubbles and for extension bubbles alike. Clicking a row does what
-- the bubble does when it is right-clicked (stop tracking, print the run...).
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local min, max, floor = math.min, math.max, math.floor
local I, C = ns.Island, ns.C
local MEDIA = "Interface\\AddOns\\BanzaiSland\\Media\\"

local S = {}
ns.Shelf = S

local W, ROW_H, HEAD, FOOT, MAXROWS = 360, 46, 40, 14, 9
local frame, rows = nil, {}
local list, offset = {}, 0
local GOLD = C.gold or { 1, 0.82, 0.3 }

local function Data()
    local db = ns.db
    if type(db.shelf) ~= "table" then db.shelf = {} end
    if type(db.shelf.pins) ~= "table" then db.shelf.pins = {} end
    if type(db.shelf.order) ~= "table" then db.shelf.order = {} end
    return db.shelf
end

-- the pin state an activity has without any choice made on the shelf
local function DefaultPinned(act)
    return (act.pin and ns.db["pin" .. act.pin] and true) or (act.extPin and true) or false
end

function S.TogglePin(e)
    local d = Data()
    local want = not e.pinned
    d.pins[e.key] = want
    if want == DefaultPinned(e.act) then d.pins[e.key] = nil end   -- back to what it was: no override to keep
    I:UpdateBubble()
end

-- Writes the order as it is shown now (so a move changes only what was moved), keeping the places of
-- activities that are not running at the moment after them.
local function Materialize()
    local d = Data()
    local order, seen = {}, {}
    for _, e in ipairs(list) do order[#order + 1] = e.key seen[e.key] = true end
    for _, k in ipairs(d.order) do
        if not seen[k] and #order < 60 then order[#order + 1] = k seen[k] = true end
    end
    d.order = order
    return order
end

function S.Move(i, dir)
    local a, b = list[i], list[i + dir]
    if not (a and b) or a.pinned ~= b.pinned then return end
    local order = Materialize()
    local ia, ib
    for n, k in ipairs(order) do
        if k == a.key then ia = n elseif k == b.key then ib = n end
    end
    if not (ia and ib) then return end
    order[ia], order[ib] = order[ib], order[ia]
    I:UpdateBubble()
end

function S.ResetOrder()
    Data().order = {}
    I:UpdateBubble()
end

local function Tip(f, title, line)
    if not GameTooltip then return end
    ns.PlaceTip(GameTooltip, f, "BOTTOM")
    GameTooltip:SetText(title, 1, 1, 1)
    if line then GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
end

local function SmallButton(parent, glyph, flip)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(20, 20)
    b:EnableMouse(true)
    b.icon = ns.Image(b, glyph, "OVERLAY", 0)
    b.icon:SetSize(13, 13)
    b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    if flip then b.icon:SetTexCoord(0, 1, 1, 0) end
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
end

local function MakeRow(i)
    local r = CreateFrame("Frame", nil, frame)
    r:SetSize(W - 20, ROW_H)
    r:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -(HEAD + (i - 1) * ROW_H))
    r:EnableMouse(true)
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetColorTexture(1, 1, 1, 0.07)
    r.hl:SetAllPoints(r)
    r.hl:Hide()
    r.icon = ns.Image(r, "Moon", "ARTWORK", 0)
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", r, "LEFT", 10, 0)
    r.name = ns.Text(r, "bold", 12.5, C.fg)
    r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 42, -8)
    r.name:SetWidth(150)
    r.sub = ns.Text(r, "medium", 10.5, C.muted)
    r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.sub:SetWidth(150)
    r.value = ns.Text(r, "bold", 12.5, C.fg, "RIGHT")
    r.value:SetPoint("RIGHT", r, "RIGHT", -92, 0)
    r.value:SetWidth(78)
    r.down = SmallButton(r, "Chevron")
    r.down:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    r.up = SmallButton(r, "Chevron", true)
    r.up:SetPoint("RIGHT", r.down, "LEFT", -2, 0)
    r.pin = SmallButton(r, "Pin")
    r.pin:SetPoint("RIGHT", r.up, "LEFT", -6, 0)
    r.pin.icon:SetSize(15, 15)
    r:SetScript("OnEnter", function(f) f.hl:Show() end)
    r:SetScript("OnLeave", function(f)
        f.hl:Hide()
        if GameTooltip then GameTooltip:Hide() end
    end)
    r:SetScript("OnMouseUp", function(f, button)
        local e = f.entry
        if button ~= "RightButton" and e and e.act.onClick then pcall(e.act.onClick) end
    end)
    r.pin:SetScript("OnEnter", function(f)
        local e = f:GetParent().entry
        if e then Tip(f, e.pinned and L["Unpin"] or L["Pin"], e.pinned and L["Moves it back into the bubbles that come and go"] or L["Keeps it beside the island while it runs"]) end
    end)
    r.pin:SetScript("OnMouseUp", function(f) local e = f:GetParent().entry if e then S.TogglePin(e) end end)
    r.up:SetScript("OnEnter", function(f) Tip(f, L["Move up"]) end)
    r.up:SetScript("OnMouseUp", function(f) local p = f:GetParent() if p.entry then S.Move(p.idx, -1) end end)
    r.down:SetScript("OnEnter", function(f) Tip(f, L["Move down"]) end)
    r.down:SetScript("OnMouseUp", function(f) local p = f:GetParent() if p.entry then S.Move(p.idx, 1) end end)
    return r
end

local function Build()
    if frame then return frame end
    if not (I and I.island) then return nil end
    frame = CreateFrame("Frame", "BanzaiSlandShelfFrame", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame.body = ns.CreateBody(frame, "BACKGROUND", 0)
    local sr, sg, sb = ns.ShellRGB(0.03, 0.03, 0.04)
    frame.body:SetColor(sr, sg, sb, 0.96)
    frame.body:SetRadius(18)
    frame.title = ns.Text(frame, "bold", 13, C.fg)
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -14)
    frame.title:SetText(L["Live activities"])
    frame.count = ns.Text(frame, "medium", 11, C.muted, "RIGHT")
    frame.count:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -44, -16)
    frame.close = SmallButton(frame, "Close")
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    frame.close:SetScript("OnMouseUp", function() S.Close() end)
    frame.close:SetScript("OnEnter", function(f) Tip(f, L["Close"]) end)
    frame.empty = ns.Text(frame, "medium", 11.5, C.muted, "CENTER")
    frame.empty:SetPoint("TOP", frame, "TOP", 0, -(HEAD + 14))
    frame.empty:SetText(L["Nothing is running right now"])
    frame.reset = ns.Text(frame, "medium", 10.5, C.muted, "LEFT")
    frame.reset:SetText(L["Reset order"])
    frame.resetBtn = CreateFrame("Frame", nil, frame)
    frame.resetBtn:EnableMouse(true)
    frame.resetBtn:SetScript("OnMouseUp", function() S.ResetOrder() end)
    frame.resetBtn:SetScript("OnEnter", function(f) Tip(f, L["Reset order"], L["Back to the usual order, most urgent first"]) end)
    frame.resetBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    frame:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - (delta > 0 and 1 or -1)
        S.Refresh()
    end)
    local t = 0
    frame:SetScript("OnUpdate", function(_, dt)
        t = t + dt
        if t > 0.25 then t = 0 S.Refresh() end
    end)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "BanzaiSlandShelfFrame") end
    return frame
end

local function Place()
    frame:ClearAllPoints()
    local hp = I.gx == "left" and "LEFT" or I.gx == "right" and "RIGHT" or ""
    if I.up then
        frame:SetPoint("BOTTOM" .. hp, I.island, "TOP" .. hp, 0, 12)
    else
        frame:SetPoint("TOP" .. hp, I.island, "BOTTOM" .. hp, 0, -12 - ((ns.db.bubbleSide == "below") and 46 or 0))
    end
end

function S.Refresh()
    if not (frame and frame:IsShown()) then return end
    local pinned, regular = I:Ranked()
    list = {}
    for _, e in ipairs(pinned) do list[#list + 1] = { key = e.key, act = e.act, pinned = true } end
    for _, e in ipairs(regular) do list[#list + 1] = { key = e.key, act = e.act, pinned = false } end
    local n = #list
    offset = max(0, min(offset, n - MAXROWS))
    local shown = min(n - offset, MAXROWS)
    frame:SetSize(W, HEAD + max(1, shown) * ROW_H + FOOT)
    frame.count:SetText(n == 1 and L["1 active"] or L["%d active"]:format(n))
    frame.empty:SetShown(n == 0)
    for i = 1, MAXROWS do
        local r = rows[i] or MakeRow(i)
        rows[i] = r
        local e = list[offset + i]
        if i <= shown and e then
            r.entry, r.idx = e, offset + i
            I:PaintBubbleIcon(r, e.act)
            r.name:SetText(e.act.tip or L["Activity"])
            r.sub:SetText(e.act.tip2 or "")
            r.value:SetText(e.act.text and e.act.text() or "")
            if e.pinned then r.pin.icon:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
            else r.pin.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 0.8) end
            local gi = offset + i
            local canUp = gi > 1 and list[gi - 1].pinned == e.pinned
            local canDown = gi < n and list[gi + 1].pinned == e.pinned
            r.up.icon:SetAlpha(canUp and 1 or 0.2)
            r.down.icon:SetAlpha(canDown and 1 or 0.2)
            r:Show()
        else
            r.entry = nil
            r:Hide()
        end
    end
    local custom = next(Data().order) ~= nil
    frame.reset:SetShown(custom)
    frame.resetBtn:SetShown(custom)
    if custom then
        frame.reset:ClearAllPoints()
        frame.reset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 6)
        frame.resetBtn:ClearAllPoints()
        frame.resetBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 0)
        frame.resetBtn:SetSize(90, 18)
    end
end

-- called whenever the bubbles are rearranged, so an open shelf follows
function S.Changed() if frame and frame:IsShown() then S.Refresh() end end

function S.Recolor()
    if not frame then return end
    local sr, sg, sb = ns.ShellRGB(0.03, 0.03, 0.04)
    frame.body:SetColor(sr, sg, sb, 0.96)
end

function S.IsOpen() return frame and frame:IsShown() or false end

function S.Open()
    if not Build() then return end
    offset = 0
    Place()
    frame:Show()
    S.Refresh()
end

function S.Close() if frame then frame:Hide() end if GameTooltip then GameTooltip:Hide() end end
function S.Toggle() if S.IsOpen() then S.Close() else S.Open() end end
