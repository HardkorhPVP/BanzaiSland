-- BanzaiSland (from Island): settings window (/banzaisland or /bsl, or right-click the island).
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local min, max, floor = math.min, math.max, math.floor
local C = ns.C
local W, PAD, ROW = 780, 22, 36

local win
local refreshers = {}

local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end

-- iOS style switch
local function Switch(parent, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(36, 20)
    b.track = ns.CreatePill(b, 20, "ARTWORK", 0)
    b.track:SetWidth(36)
    b.knob = ns.Image(b, "Circle", "ARTWORK", 2)
    b.knob:SetSize(16, 16)
    b.pos = get() and 1 or 0

    local function paint()
        local p = b.pos
        local on = ns.Accent()
        b.knob:SetPoint("LEFT", b, "LEFT", 2 + 16 * p, 0)
        b.track:SetColor(0.24 + (on[1] - 0.24) * p, 0.25 + (on[2] - 0.25) * p, 0.29 + (on[3] - 0.29) * p, 1)
    end
    local function animate(_, dt)
        local target = get() and 1 or 0
        local d = dt / 0.14
        b.pos = (target > b.pos) and min(target, b.pos + d) or max(target, b.pos - d)
        paint()
        if b.pos == target then b:SetScript("OnUpdate", nil) end
    end
    b:SetScript("OnClick", function()
        set(not get())
        b:SetScript("OnUpdate", animate)
    end)
    -- snap to the current value (also used by pages that re-bind the switch to another record)
    function b.Sync()
        b.pos = get() and 1 or 0
        b:SetScript("OnUpdate", nil)
        paint()
    end
    refreshers[#refreshers + 1] = b.Sync
    paint()
    return b
end

local function Slider(parent, lo, hi, step, get, set, fmt)
    local SW = 120
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(SW, 18)
    s:EnableMouse(true)
    s.track = ns.CreatePill(s, 4, "ARTWORK", 0)
    s.track:SetColor(1, 1, 1, 0.13)
    s.track:SetWidth(SW)
    s.fill = ns.CreatePill(s, 4, "ARTWORK", 1)
    s.knob = ns.Image(s, "Circle", "ARTWORK", 2)
    s.knob:SetSize(14, 14)
    s.label = ns.Text(parent, "bold", 12, C.muted, "RIGHT")
    s.label:SetPoint("RIGHT", s, "LEFT", -10, 0)

    local function paint()
        local v = get()
        local f = clamp((v - lo) / (hi - lo), 0, 1)
        local x = f * (SW - 14)
        local col = ns.Accent()
        s.knob:SetPoint("LEFT", s, "LEFT", x, 0)
        s.fill:SetColor(col[1], col[2], col[3], 1)
        s.fill:SetWidth(max(4, x + 7))
        s.label:SetText(fmt(v))
    end
    local function drag()
        local x = GetCursorPosition() / s:GetEffectiveScale()
        local f = clamp((x - (s:GetLeft() or 0) - 7) / (SW - 14), 0, 1)
        local v = lo + f * (hi - lo)
        v = floor(v / step + 0.5) * step
        if v ~= get() then
            set(v)
            paint()
        end
    end
    s:SetScript("OnMouseDown", function() s:SetScript("OnUpdate", drag) end)
    s:SetScript("OnMouseUp", function() s:SetScript("OnUpdate", nil) end)
    s:SetScript("OnHide", function() s:SetScript("OnUpdate", nil) end)
    refreshers[#refreshers + 1] = paint
    paint()
    return s
end

local function PickColor(color, onChange)
    local r, g, b = color[1], color[2], color[3]
    local function apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        color[1], color[2], color[3] = nr, ng, nb
        onChange()
    end
    local function cancel()
        color[1], color[2], color[3] = r, g, b
        onChange()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false, swatchFunc = apply, cancelFunc = cancel,
        })
    else
        ColorPickerFrame.func, ColorPickerFrame.cancelFunc = apply, cancel
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

local function Swatch(parent, color, default, onChange)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(22, 22)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.ring = ns.Image(b, "Circle", "ARTWORK", 0)
    b.ring:SetAllPoints(b)
    b.ring:SetVertexColor(1, 1, 1, 0.25)
    b.dot = ns.Image(b, "Circle", "ARTWORK", 1)
    b.dot:SetSize(18, 18)
    b.dot:SetPoint("CENTER", b, "CENTER", 0, 0)
    local function paint() b.dot:SetVertexColor(color[1], color[2], color[3], 1) end
    local function changed()
        paint()
        onChange()
    end
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            color[1], color[2], color[3] = default[1], default[2], default[3]
            changed()
        else
            PickColor(color, changed)
        end
    end)
    refreshers[#refreshers + 1] = paint
    paint()
    return b
end

local function PillButton(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 30)
    -- BanzaiSland 0.2.0: softly chamfered control surfaces instead of capsules
    local UI = ns.Theme.UI
    b.bg = ns.CreateControl(b, UI.radius, "ARTWORK", 0)
    b.bg:SetColor(unpack(UI.control))
    b.text = ns.Text(b, "bold", 12.5, C.fg, "CENTER")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b:SetScript("OnEnter", function() b.bg:SetColor(unpack(UI.controlHover)) end)
    b:SetScript("OnLeave", function() b.bg:SetColor(unpack(UI.control)) end)
    b:SetScript("OnClick", onClick)
    return b
end

-- ---------------------------------------------------------------- dropdown menus
-- A choice pill shows what's picked; clicking it drops down a list of every choice.
local menu, catcher
local MENU_ROW, MENU_MAX, MENU_PAD = 26, 10, 6

local function CloseMenu()
    if menu and menu:IsShown() then menu:Hide() end
end
ns.CloseSettingsMenu = CloseMenu

local function PaintMenu()
    local m = menu
    local n = #m.values
    local shown = min(n, MENU_MAX)
    local a = ns.Accent()
    for i = 1, shown do
        local row = m.rows[i]
        local v = m.values[i + m.offset]
        local text, col = m.label(v)
        row.value = v
        row.text:SetText(text)
        local on = (v == m.current)
        col = on and a or col or C.fg
        row.text:SetTextColor(col[1], col[2], col[3])
        row.check:SetShown(on)
        row.check:SetVertexColor(a[1], a[2], a[3])
        row.hl:SetWidth(m:GetWidth() - 2 * MENU_PAD)
        row:Show()
    end
    for i = shown + 1, #m.rows do m.rows[i]:Hide() end
    m.up:SetShown(m.offset > 0)
    m.down:SetShown(m.offset + shown < n)
end

local function BuildMenu()
    -- clicking anywhere outside the list closes it (the pill that opened it included)
    catcher = CreateFrame("Button", nil, win)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameLevel(win:GetFrameLevel() + 40)
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", CloseMenu)
    catcher:Hide()

    menu = CreateFrame("Frame", nil, win)
    menu:SetFrameLevel(win:GetFrameLevel() + 41)
    menu:EnableMouse(true)
    menu:EnableMouseWheel(true)
    menu:SetClampedToScreen(true)
    menu.body = ns.CreateBody(menu, "BACKGROUND", 0)
    menu.body:SetColor(0.04, 0.09, 0.07, 0.98)
    menu.body:SetRadius(ns.Theme.UI.groupRadius)
    menu.rows = {}
    for i = 1, MENU_MAX do
        local row = CreateFrame("Button", nil, menu)
        row:SetHeight(MENU_ROW)
        row:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PAD, -MENU_PAD - (i - 1) * MENU_ROW)
        row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -MENU_PAD, -MENU_PAD - (i - 1) * MENU_ROW)
        row.hl = ns.CreateControl(row, 5, "BACKGROUND", 1)
        row.hl:SetColor(1, 1, 1, 0)
        row.text = ns.Text(row, "bold", 12.5, C.fg, "LEFT")
        row.text:SetPoint("LEFT", row, "LEFT", 12, 0)
        row.check = ns.Image(row, "Check", "ARTWORK", 0)
        row.check:SetSize(12, 12)
        row.check:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row:SetScript("OnEnter", function() row.hl:SetColor(1, 1, 1, 0.08) end)
        row:SetScript("OnLeave", function() row.hl:SetColor(1, 1, 1, 0) end)
        row:SetScript("OnClick", function()
            local pick, v = menu.onPick, row.value
            CloseMenu()
            if pick then pick(v) end
        end)
        menu.rows[i] = row
    end
    -- more above / more below: scroll with the mouse wheel
    menu.up = ns.Image(menu, "Chevron", "OVERLAY", 0)
    menu.up:SetSize(10, 10)
    menu.up:SetTexCoord(0, 1, 1, 0)
    menu.up:SetPoint("TOP", menu, "TOP", 0, -1)
    menu.up:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
    menu.down = ns.Image(menu, "Chevron", "OVERLAY", 0)
    menu.down:SetSize(10, 10)
    menu.down:SetPoint("BOTTOM", menu, "BOTTOM", 0, 1)
    menu.down:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
    menu.measure = ns.Text(menu, "bold", 12.5, C.fg, "LEFT")
    menu.measure:Hide()
    menu:SetScript("OnMouseWheel", function(_, delta)
        local top = max(0, #menu.values - MENU_MAX)
        menu.offset = max(0, min(top, menu.offset - delta))
        PaintMenu()
    end)
    menu:SetScript("OnShow", function() catcher:Show() end)
    menu:SetScript("OnHide", function() catcher:Hide() menu.owner = nil end)
    win:HookScript("OnHide", CloseMenu)
    menu:Hide()
end

-- open the list under `owner` (or above it when there's no room below); clicking the same pill again closes it
local function OpenMenu(owner, values, label, current, onPick)
    if not menu then BuildMenu() end
    if menu:IsShown() and menu.owner == owner then CloseMenu() return end
    menu.owner, menu.values, menu.label, menu.current, menu.onPick = owner, values, label, current, onPick
    -- start scrolled so the current choice is in view
    local at = 1
    for i, v in ipairs(values) do if v == current then at = i end end
    menu.offset = max(0, min(#values - MENU_MAX, at - floor(MENU_MAX / 2)))
    local widest = 0
    for _, v in ipairs(values) do
        menu.measure:SetText((label(v)))
        widest = max(widest, menu.measure:GetStringWidth() or 0)
    end
    local w = max(owner:GetWidth(), widest + 54)
    local h = min(#values, MENU_MAX) * MENU_ROW + 2 * MENU_PAD
    menu:SetSize(w, h)
    menu:ClearAllPoints()
    local below = owner:GetBottom() and win:GetBottom() and (owner:GetBottom() - h - 4 < win:GetBottom() + 8)
    if below then
        menu:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", 0, 4)
    else
        menu:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -4)
    end
    menu:Show()
    PaintMenu()
end

-- a pill that opens a dropdown: a little chevron on its right
local function Droppable(button)
    button.chev = ns.Image(button, "Chevron", "OVERLAY", 0)
    button.chev:SetSize(9, 9)
    button.chev:SetPoint("RIGHT", button, "RIGHT", -13, 0)
    button.chev:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
    button.text:ClearAllPoints()
    button.text:SetPoint("CENTER", button, "CENTER", -6, 0)
    return button
end

local function RefreshAll()
    for i = 1, #refreshers do refreshers[i]() end
end
ns.RefreshSettings = RefreshAll

local function Build()
    local db = ns.db
    win = CreateFrame("Frame", "BanzaiSlandSettingsFrame", UIParent)
    win:SetFrameStrata("DIALOG")
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win.body = ns.CreateBody(win, "BACKGROUND", 0)
    win.body:SetColor(0.03, 0.03, 0.04, 0.97)
    win.body:SetRadius(ns.Theme.UI.windowRadius)
    -- 0.2.0: a window still on upstream's near-black default moves to Banzai Glass; a colour the player
    -- picked is kept
    do
        local bg, old = db.panelBgColor, { 0.03, 0.03, 0.04 }
        if type(bg) == "table" and math.abs(bg[1] - old[1]) + math.abs(bg[2] - old[2]) + math.abs(bg[3] - old[3]) < 0.005 then
            local g = ns.Theme.COLORS.glass
            db.panelBgColor = { g[1], g[2], g[3] }
        end
    end
    -- optional border: a rounded body slightly larger than the window, behind it
    local edge = CreateFrame("Frame", nil, win)
    edge:SetFrameLevel(max(0, win:GetFrameLevel() - 1))
    edge.body = ns.CreateBody(edge, "BACKGROUND", 0)
    edge:Hide()
    function ns.ApplyPanelStyle()
        local d = ns.db
        local bg = d.panelBgColor or ns.defaults.panelBgColor
        win.body:SetColor(bg[1], bg[2], bg[3], d.panelBgAlpha or ns.defaults.panelBgAlpha)
        if not d.panelBorderOn then edge:Hide() return end
        local t = d.panelBorderSize or 2
        local c = d.panelBorderColor or ns.defaults.panelBorderColor
        if d.panelBorderClass then
            local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[select(2, UnitClass("player"))]
            if cc then c = { cc.r, cc.g, cc.b } end
        end
        edge:ClearAllPoints()
        edge:SetPoint("TOPLEFT", win, "TOPLEFT", -t, t)
        edge:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", t, -t)
        edge.body:SetRadius(ns.Theme.UI.windowRadius + t)
        edge.body:SetColor(c[1], c[2], c[3], d.panelBorderAlpha or ns.defaults.panelBorderAlpha)
        edge:Show()
    end
    ns.ApplyPanelStyle()
    tinsert(UISpecialFrames, "BanzaiSlandSettingsFrame")

    local close = CreateFrame("Button", nil, win)
    close:SetSize(26, 26)
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -14, -16)
    close.x = ns.Image(close, "Close", "ARTWORK", 0)
    close.x:SetSize(14, 14)
    close.x:SetPoint("CENTER", close, "CENTER", 0, 0)
    close.x:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
    close:SetScript("OnEnter", function() close.x:SetVertexColor(1, 1, 1, 1) end)
    close:SetScript("OnLeave", function() close.x:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1) end)
    close:SetScript("OnClick", function() win:Hide() end)

    -- ---------------------------------------------------------------- layout
    -- A sidebar on the left picks a page; the page scrolls on the right. Rows sit in rounded
    -- groups, like a phone's settings.
    local H = 580
    local SIDE = 200                         -- sidebar width
    local CX = SIDE + 26                     -- content left edge
    local CW = W - CX - 30                   -- content width
    local GAP_X = 16                         -- row padding inside a group

    win:SetSize(W, H)
    local side = CreateFrame("Frame", nil, win)
    side:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
    side:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 0, 0)
    side:SetWidth(SIDE)
    local rule = win:CreateTexture(nil, "BORDER")
    rule:SetColorTexture(1, 1, 1, 0.06)
    rule:SetWidth(1)
    rule:SetPoint("TOPLEFT", win, "TOPLEFT", SIDE, -18)
    rule:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", SIDE, 18)

    -- 0.2.0 header: the BANZAI B logo, the BANZAI SLAND mark, the version in the information font
    local logo = side:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(ns.Theme.LOGO)
    logo:SetSize(34, 34)
    logo:SetPoint("TOPLEFT", side, "TOPLEFT", 18, -20)
    local title = ns.Renderer.MakeBrand(side, ns.Theme.BRAND.settingsHeight, false)
    title:SetPoint("LEFT", logo, "RIGHT", 4, 5)
    win.brand = title
    local ver = ns.Text(side, "medium", 10.5, C.muted)
    ver:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -22)
    local v = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)
    local okV, version = pcall(v or function() end, ADDON, "Version")
    ver:SetText(L["Version %s"]:format((okV and version) or ns.VERSION or "?"))

    local scroll = CreateFrame("ScrollFrame", nil, win)
    scroll:SetPoint("TOPLEFT", win, "TOPLEFT", CX, -18)
    scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -24, 18)
    if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end

    -- a thin bar that shows where you are on a long page (0.2.0: an emerald -> violet gradient)
    local thumb = CreateFrame("Frame", nil, win)
    thumb:SetWidth(4)
    thumb.bg = ns.CreateControl(thumb, 2, "ARTWORK", 0)
    thumb:Hide()

    local pages, navs, meta = {}, {}, {}
    local TABS = {
        [6] = { {6, L["Look"]}, {12, L["Placement"]}, {7, L["Motion"]} },
        [2] = { {2, L["Items"]}, {1, L["Progress"]}, {17, ns.ClientFeature("legacy") and L["Legacy"] or L["Talents"]}, {23, L["Catch up"]}, {13, L["Social"]}, {3, L["Alerts"]}, {14, L["World"]} },
        [4] = { {4, L["Layout"]}, {20, L["Pinned"]}, {21, L["Types"]} },
        [5] = { {15, L["Timers"]}, {18, L["Buff pills"]} },
        [8] = { {8, L["Behavior"]}, {16, L["Vendor"]}, {9, L["Try it"]} },
        [41] = { {41, L["About"]}, {42, L["Credits"]}, {43, L["Upstream"]} }, -- BanzaiSland
    }
    if ns.ClientFeature("retail") then table.insert(TABS[2],{24,L["Retail"]}) end
    local parents, remembered = {}, {}
    for parent, tabs in pairs(TABS) do
        for _, tab in ipairs(tabs) do parents[tab[1]] = parent end
    end
    local function Parent(index) return parents[index] or index end
    local activeIndex
    local searchIndex, searchRows = {}, {}
    local searchPage, searchBox, searchHint, searchEmpty
    local lastPage, highlighted = 6, nil
    local section
    local Reflow
    local page, y, group, gy, rowsInGroup
    local current
    local want, at = 0, 0

    local function MaxScroll()
        if not current then return 0 end
        return max(0, (current.h or 0) - (H - 36 - (current.fixedTop or 0)))
    end
    local function PaintThumb()
        local m = MaxScroll()
        if m <= 1 then thumb:Hide() return end
        local inset = current.fixedTop or 0
        local view = H - 36 - inset
        local th = max(30, view * view / (view + m))
        thumb:SetHeight(th)
        thumb.bg:SetGradient("VERTICAL", ns.Theme.COLORS.violet, ns.Theme.COLORS.emerald, 0.55)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", win, "TOPRIGHT", -10, -18 - inset - (view - th) * (at / m))
        thumb:Show()
    end
    scroll:SetScript("OnMouseWheel", function(_, delta)
        CloseMenu()
        want = clamp(want - delta * 60, 0, MaxScroll())
        scroll:SetScript("OnUpdate", function(self, dt)
            at = at + (want - at) * min(1, dt * 14)
            if math.abs(want - at) < 0.5 then at = want self:SetScript("OnUpdate", nil) end
            self:SetVerticalScroll(at)
            PaintThumb()
        end)
    end)

    local function Paint(i)
        local n = navs[i]
        local on = activeIndex and Parent(activeIndex) == i
        local UI = ns.Theme.UI
        -- 0.2.0: a dark translucent selected surface with a narrow gradient indicator on its left
        if on then
            n.bg:SetColor(unpack(UI.navSelected))
            n.bar:Show()
            n.icon:SetVertexColor(C.fg[1], C.fg[2], C.fg[3], 1)
            n.text:SetTextColor(C.fg[1], C.fg[2], C.fg[3])
        else
            n.bg:SetColor(1, 1, 1, n.over and UI.navHover[4] or 0)
            n.bar:Hide()
            n.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
            local col = n.over and C.fg or C.muted
            n.text:SetTextColor(col[1], col[2], col[3])
        end
    end
    local function Select(index, sidebar)
        CloseMenu()
        local parent = Parent(index)
        if sidebar and TABS[parent] then index = remembered[parent] or TABS[parent][1][1] end
        if highlighted then
            highlighted:SetTextColor(C.fg[1], C.fg[2], C.fg[3])
            highlighted = nil
        end
        if index ~= 22 then lastPage = index end
        activeIndex, remembered[parent] = index, index
        scroll:SetScript("OnUpdate", nil)
        for i, p in pairs(pages) do
            p:Hide()
            if p.previewDock then p.previewDock:Hide() end
        end
        current = pages[index]
        current:Show()
        if current.previewDock then current.previewDock:Show() end
        -- Only the controls scroll below the builder's fixed preview area.
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", win, "TOPLEFT", CX, -18 - (current.fixedTop or 0))
        scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -24, 18)
        scroll:SetScrollChild(current)
        want, at = 0, 0
        scroll:SetVerticalScroll(0)
        for i in pairs(navs) do Paint(i) end
        PaintThumb()
    end
    refreshers[#refreshers + 1] = function() for i in pairs(navs) do Paint(i) end end

    -- the sidebar: groups of pages, in this order
    local NAV = {
        { head = L["APPEARANCE"] },
        { page = 6, name = L["Appearance"], icon = "Drop", sub = L["How the island looks and moves."] },
        { page = 11, name = L["Card Builder"], icon = "Tile", sub = L["Lay out each kind of card your way."] },
        { page = 40, name = L["Preview"], icon = "Eye", sub = L["Synthetic cards, bubbles and prompts to inspect the BanzaiSland look. Nothing here answers the game."] },
        { head = L["FEATURES"] },
        { page = 25, name = L["Sounds"], icon = "Speaker", sub = L["Choose and preview sounds for each kind of card."] },
        { page = 2, name = L["Notifications"], icon = "Bell", sub = L["Choose what appears, one group at a time."] },
        { page = 4, name = L["Bubbles"], icon = "Clock", sub = L["Choose bubble types, placement and pins."] },
        { page = 5, name = L["Activities"], icon = "Speaker", sub = L["Timers and buffs."] },
        { head = L["MORE"] },
        { page = 10, name = L["Controls"], title = L["Keys & Controller (beta)"], badge = L["BETA"], icon = "Pad", sub = L["Answer cards with keys or a controller."] },
        { page = 8, name = L["General"], icon = "Gear", sub = L["Behavior, vendor helpers and sample cards."] },
        { page = 27, name = L["Profiles"], icon = "Tile", sub = L["Keep separate setups for your characters."] },
        { page = 41, name = L["About & Credits"], icon = "Book", sub = L["BanzaiSland %s. A GPLv3 fork of Island by Devin (subtlegrind), independently maintained."]:format(ns.VERSION or "") },
    }
    if type(ns.Extensions) == "table" then
        table.insert(NAV, 10, { page = 26, name = L["Extensions"], icon = "Tile", sub = L["Addons that send cards and bubbles through BanzaiSland."] })
    end
    table.insert(NAV, 10, { page = 28, name = L["Supported Addons"], icon = "Tile", sub = L["Addons BanzaiSland works with, and their options. Only the ones you have installed show."] })
    local ny = -116
    for _, n in ipairs(NAV) do
        if n.head then
            ny = ny - 10
            local h = ns.Text(side, "bold", 9.5, ns.Theme.UI.heading)
            h:SetPoint("TOPLEFT", side, "TOPLEFT", 24, ny)
            h:SetText(n.head)
            -- 0.2.0: a small gradient tick before each group heading
            local tick = side:CreateTexture(nil, "ARTWORK")
            tick:SetColorTexture(1, 1, 1, 1)
            tick:SetSize(6, 2)
            tick:SetPoint("RIGHT", h, "LEFT", -4, 0)
            ns.Renderer.Gradient(tick, "HORIZONTAL", ns.Theme.COLORS.lime, ns.Theme.COLORS.emerald, 0.9)
            ny = ny - 18
        else
            local b = CreateFrame("Button", nil, side)
            b:SetSize(SIDE - 28, 29)
            b:SetPoint("TOPLEFT", side, "TOPLEFT", 14, ny)
            b.bg = ns.CreateBody(b, "BACKGROUND", 0)
            b.bg:SetRadius(ns.Theme.UI.navRadius)
            -- 0.2.0: the selected indicator, a narrow vertical gradient line on the left
            b.bar = b:CreateTexture(nil, "ARTWORK", nil, 1)
            b.bar:SetColorTexture(1, 1, 1, 1)
            b.bar:SetSize(2, 17)
            b.bar:SetPoint("LEFT", b, "LEFT", 3, 0)
            ns.Renderer.Gradient(b.bar, "VERTICAL", ns.Theme.COLORS.violet, ns.Theme.COLORS.lime, 1)
            b.bar:Hide()
            b.icon = ns.Image(b, n.icon, "ARTWORK", 0)
            b.icon:SetSize(15, 15)
            b.icon:SetPoint("LEFT", b, "LEFT", 12, 0)
            b.text = ns.Text(b, "medium", 13, C.muted)
            b.text:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
            b.text:SetText(n.name)
            if n.badge then
                -- a small tag on the right of the button (BETA)
                local tag = ns.Text(b, "bold", 9, C.muted, "RIGHT")
                tag:SetPoint("RIGHT", b, "RIGHT", -10, 0)
                tag:SetText(n.badge)
            end
            local index = n.page
            b:SetScript("OnEnter", function() b.over = true Paint(index) end)
            b:SetScript("OnLeave", function() b.over = false Paint(index) end)
            b:SetScript("OnClick", function() Select(index, true) end)
            navs[index] = b
            meta[index] = n
            ny = ny - 31
        end
    end

    local function CloseGroup()
        if not group then return end
        if gy == 0 then group.empty = true group:Hide() group = nil return end
        group:SetHeight(gy)
        group.body:SetRadius(ns.Theme.UI.groupRadius)
        y = y - gy
        group = nil
    end
    local function CloseSection()
        CloseGroup()
        if section then section.bottom = y section = nil end
    end
    Reflow = function(p)
        local shift = 0
        for _, s in ipairs(p.sections) do
            s.header:ClearAllPoints()
            s.header:SetPoint("TOPLEFT", p, "TOPLEFT", 0, s.headerY + shift)
            s.chev:SetRotation(s.open and 0 or -math.pi / 2)
            for _, block in ipairs(s.blocks) do
                block.frame:ClearAllPoints()
                block.frame:SetPoint("TOPLEFT", p, "TOPLEFT", block.x, block.y + shift)
                block.frame:SetShown(s.open and not block.frame.empty)
            end
            if not s.open then shift = shift + math.max(0, s.top - s.bottom - 38) end
        end
        p.h = p.fullHeight - shift
        p:SetHeight(p.h)
        if current == p then
            want, at = math.min(want, MaxScroll()), math.min(at, MaxScroll())
            scroll:SetVerticalScroll(at)
            PaintThumb()
        end
    end
    local function Block(frame, x, yy)
        if section then section.blocks[#section.blocks + 1] = {frame = frame, x = x, y = yy} end
    end
    local function Finish()
        CloseSection()
        if page then page.fullHeight = -y + 24 Reflow(page) end
    end
    local function Page(index)
        Finish()
        page = CreateFrame("Frame", nil, scroll)
        page:SetWidth(CW)
        page:Hide()
        pages[index] = page
        page.sections = {}
        page.index = index
        local m = meta[Parent(index)] or {}
        local head = ns.Text(page, "extra", 21, C.fg)
        head:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -8)
        head:SetText(m.title or m.name or "")
        local sub = ns.Text(page, "medium", 12, C.muted)
        sub:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
        sub:SetText(m.sub or "")
        page.heading, page.subtitle = head, sub
        -- 0.2.0: a thin BANZAI gradient structural line under the page header
        page.rule = {}
        for i = 1, 3 do
            local seg = page:CreateTexture(nil, "ARTWORK")
            seg:SetColorTexture(1, 1, 1, 1)
            seg:SetHeight(1)
            seg:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * CW / 3, -56)
            seg:SetPoint("TOPRIGHT", page, "TOPLEFT", i * CW / 3, -56)
            if seg.SetSnapToPixelGrid then seg:SetSnapToPixelGrid(true) end
            local stops = ns.Theme.STOPS.banzai
            ns.Renderer.Gradient(seg, "HORIZONTAL", ns.Theme.ColorAt(stops, (i - 1) / 3), ns.Theme.ColorAt(stops, i / 3), 0.55)
            page.rule[i] = seg
        end
        local tabs = TABS[Parent(index)]
        if tabs then
            local tabWidth = CW / #tabs
            for i, tab in ipairs(tabs) do
                local button = CreateFrame("Button", nil, page)
                button:SetSize(tabWidth - 4, 28)
                button:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * tabWidth, -64)
                button.text = ns.Text(button, "medium", 12, index == tab[1] and ns.Accent() or C.muted)
                button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
                button.text:SetText(tab[2])
                button.text:SetWidth(tabWidth - 8)
                button.text:SetJustifyH("CENTER")
                local target = tab[1]
                button:SetScript("OnClick", function() Select(target) end)
                if index == target then
                    local underline = button:CreateTexture(nil, "ARTWORK")
                    local ac = ns.Accent()
                    underline:SetColorTexture(ac[1], ac[2], ac[3], 1)
                    underline:SetHeight(2)
                    -- The indicator follows the visible label, including font changes.
                    underline:SetPoint("TOP", button.text, "BOTTOM", 0, -5)
                    local function sizeUnderline()
                        underline:SetWidth(math.min(tabWidth - 8, button.text:GetStringWidth() or 0))
                    end
                    sizeUnderline()
                    refreshers[#refreshers + 1] = function()
                        local color = ns.Accent()
                        button.text:SetTextColor(color[1], color[2], color[3])
                        underline:SetColorTexture(color[1], color[2], color[3], 1)
                        sizeUnderline()
                    end
                end
            end
        end
        y = tabs and -100 or -66
    end
    local function OpenGroup()
        group = CreateFrame("Frame", nil, page)
        group:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
        group:SetWidth(CW)
        Block(group, 0, y)
        group.body = ns.CreateBody(group, "BACKGROUND", 0)
        group.body:SetColor(1, 1, 1, 0.045)
        gy, rowsInGroup = 0, 0
    end
    local function Section(label, collapsed)
        CloseSection()
        section = {top = y, open = not collapsed, blocks = {}, headerY = y - 14, label = label}
        local s, p = section, page
        p.sections[#p.sections + 1] = s
        local button = CreateFrame("Button", nil, p)
        button:SetSize(CW, 24)
        button:SetPoint("TOPLEFT", p, "TOPLEFT", 0, s.headerY)
        local fs = ns.Text(button, "bold", 10, ns.Theme.UI.heading)
        fs:SetPoint("LEFT", button, "LEFT", GAP_X, 0)
        fs:SetText(label)
        -- 0.2.0: a small gradient tick before each section heading
        local tick = button:CreateTexture(nil, "ARTWORK")
        tick:SetColorTexture(1, 1, 1, 1)
        tick:SetSize(8, 2)
        tick:SetPoint("RIGHT", fs, "LEFT", -5, 0)
        ns.Renderer.Gradient(tick, "HORIZONTAL", ns.Theme.COLORS.emerald, ns.Theme.COLORS.violet, 0.9)
        s.header = button
        s.chev = ns.Image(button, "Chevron", "ARTWORK", 0)
        s.chev:SetSize(9, 9)
        s.chev:SetPoint("RIGHT", button, "RIGHT", -GAP_X, 0)
        s.chev:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
        button:SetScript("OnClick", function() CloseMenu() s.open = not s.open Reflow(p) end)
        button:SetScript("OnEnter", function() fs:SetTextColor(C.fg[1], C.fg[2], C.fg[3]) end)
        button:SetScript("OnLeave", function() local hc = ns.Theme.UI.heading fs:SetTextColor(hc[1], hc[2], hc[3]) end)
        y = y - 38
        OpenGroup()
    end
    local function Row(label)
        if not group then OpenGroup() end
        if rowsInGroup > 0 then
            local line = group:CreateTexture(nil, "BORDER")
            line:SetColorTexture(1, 1, 1, 0.06)
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", group, "TOPLEFT", GAP_X, -gy)
            line:SetPoint("TOPRIGHT", group, "TOPRIGHT", 0, -gy)
        end
        local fs = ns.Text(group, "medium", 13, C.fg)
        fs:SetPoint("LEFT", group, "TOPLEFT", GAP_X, -gy - ROW / 2)
        fs:SetText(label)
        local anchorY, g = -gy - ROW / 2, group
        local context = meta[Parent(page.index)] or {}
        local tabName = ""
        for _, tab in ipairs(TABS[Parent(page.index)] or {}) do
            if tab[1] == page.index then tabName = tab[2] end
        end
        searchIndex[#searchIndex + 1] = {
            label = label, page = page, section = section, group = g, offset = gy,
            text = fs, context = (context.name or "") .. " " .. tabName .. " " .. (section and section.label or ""),
        }
        gy = gy + ROW
        rowsInGroup = rowsInGroup + 1
        return function(widget)
            widget:SetParent(g)
            if widget.label then widget.label:SetParent(widget) end
            widget:ClearAllPoints()
            widget:SetPoint("RIGHT", g, "TOPRIGHT", -GAP_X, anchorY)
            -- the label stops short of the control (a long one is cut off with "...")
            fs:SetPoint("RIGHT", widget, "LEFT", -14, 0)
            fs:SetJustifyH("LEFT")
        end
    end
    local function Note(text)
        CloseGroup()
        local fs = ns.Text(page, "medium", 11.5, C.muted)
        fs:SetPoint("TOPLEFT", page, "TOPLEFT", GAP_X, y - 8)
        Block(fs, GAP_X, y - 8)
        fs:SetWidth(CW - GAP_X * 2)
        if fs.SetWordWrap then fs:SetWordWrap(true) end
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        local th = (fs.GetStringHeight and fs:GetStringHeight()) or 14
        y = y - 8 - max(14, th) - 6
    end
    local function Toggle(label, key, after, enabled)
        local button = Switch(page, function() return db[key] and (not enabled or enabled()) end, function(v)
            if enabled and not enabled() then return end
            db[key] = v
            if after then after(v) end
        end)
        Row(label)(button)
        searchIndex[#searchIndex].keywords = key:gsub("(%l)(%u)", "%1 %2")
        if enabled then
            local function sync()
                local on = enabled()
                button:SetEnabled(on)
                button:SetAlpha(on and 1 or 0.35)
            end
            refreshers[#refreshers + 1] = sync
            sync()
        end
    end
    -- a pill that drops down a list of values
    -- a stepping button grows (to the left) when its text is longer than it, and goes back after
    local function FitPill(button, width)
        local need = (button.text:GetStringWidth() or 0) + 30 + (button.chev and 14 or 0)
        local w = math.max(width, need)
        button:SetWidth(w)
        button.bg:SetWidth(w)
    end
    local function MakeCycle(key, values, describe, onChange, width)
        local button
        local function paint()
            local text, col = describe(db[key])
            col = col or C.fg
            button.text:SetText(text)
            button.text:SetTextColor(col[1], col[2], col[3])
            FitPill(button, width or 150)
        end
        button = Droppable(PillButton(page, "", width or 150, function()
            OpenMenu(button, values, describe, db[key], function(v)
                db[key] = v
                paint()
                if onChange then onChange(v) end
            end)
        end))
        refreshers[#refreshers + 1] = paint
        paint()
        return button
    end
    local function Cycle(label, key, values, describe, onChange)
        Row(label)(MakeCycle(key, values, describe, onChange))
        local words = {(key:gsub("(%l)(%u)", "%1 %2"))}
        for _, value in ipairs(values) do
            local ok, name = pcall(describe, value)
            if ok and type(name) == "string" then words[#words+1] = name end
        end
        searchIndex[#searchIndex].keywords = table.concat(words, " ")
    end
    -- a colour choice: which colour (a stepping button) with the colour itself beside it
    local function ColorChoice(label, cycle, swatch)
        local box = CreateFrame("Frame", nil, page)
        box:SetSize(150 + 12 + 22, 30)
        cycle:SetParent(box)
        cycle:ClearAllPoints()
        cycle:SetPoint("LEFT", box, "LEFT", 0, 0)
        swatch:SetParent(box)
        swatch:ClearAllPoints()
        swatch:SetPoint("RIGHT", box, "RIGHT", 0, 0)
        Row(label)(box)
    end
    -- two buttons side by side, outside any group
    local function Buttons(labelA, fnA, labelB, fnB)
        CloseGroup()
        local bw = (CW - 10) / 2
        local function IndexButton(button, label)
            local context = meta[Parent(page.index)] or {}
            searchIndex[#searchIndex+1] = {label=label, page=page, section=section, group=button,
                offset=0, text=button.text, context=(context.name or "") .. " " .. (section and section.label or "")}
        end
        local a = PillButton(page, labelA, bw, fnA)
        IndexButton(a, labelA)
        a:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
        Block(a, 0, y)
        if labelB then
            local b = PillButton(page, labelB, bw, fnB)
            IndexButton(b, labelB)
            b:SetPoint("TOPLEFT", page, "TOPLEFT", bw + 10, y)
            Block(b, bw + 10, y)
        end
        y = y - 40
    end
    local function refresh() ns.Island:Refresh() end

    Page(1)
    Section(L["PROGRESS"])
    Toggle(L["Kill and reputation gains"], "showKills")
    Toggle(L["Quest cards"], "showQuests")
    Toggle(L["Quest objective progress"], "showQuestProgress")
    Toggle(L["Skill ups"], "showSkillUps")
    Toggle(L["Level up celebration"], "showLevelUp")
    Page(17)
    Section(ns.ClientFeature("legacy") and L["LEGACY AND TALENTS"] or L["TALENTS"])
    Toggle(L["Unspent talent reminder"], "talentReminder", function() ns.ApplyTalentReminder() end)
    if ns.ClientFeature("legacy") then
        Toggle(L["Unspent legacy reminder"], "legacyReminder", function() ns.ApplyLegacyReminder() end)
    end
    if ns.ClientFeature("legacy") then
        Toggle(L["Legacy challenge completions"], "showLegacyChallenges", function() ns.ApplyLegacyChallengeProgress() end)
    end
    if ns.ClientFeature("legacy") then
        Toggle(L["Partial legacy progress"], "legacyPartialProgress", function() ns.ApplyLegacyChallengeProgress() end)
    end

    if ns.ClientFeature("retail") then
        Page(24)
        Section(L["PROGRESSION AND REWARDS"])
        local function retailApply() ns.Retail.Apply() end
        Toggle(L["Renown and Paragon reward cards"],"retailRenown",retailApply)
        Toggle(L["Warband labels and duplicate protection"],"retailWarband")
        Toggle(L["Item level and upgrade track details"],"retailGear")
        Toggle(L["Great Vault progress and reward reminder"],"retailVault",retailApply)
        Toggle(L["Mythic+ completion summaries"],"retailMythic")
        Toggle(L["Delve completion summaries"],"retailDelves")
        Toggle(L["Profession Knowledge and specialization updates"],"retailKnowledge",retailApply)
        Toggle(L["Crafting order completion cards"],"retailOrders")
        Toggle(L["Talent loadout changes"],"retailLoadouts")
        Toggle(L["Dungeon Finder and role-check notices"],"retailQueues")
        Section(L["COLLECTIONS AND HOUSING"])
        Toggle(L["Mount, pet, toy and appearance unlocks"],"retailCollections")
        Toggle(L["New housing decor"],"retailHousing")
        Section(L["TALKING HEAD"])
        Toggle(L["Talking Head dialogue cards"],"retailTalkingHead",function() ns.Retail.Dialogue.Apply() end)
        Toggle(L["Hide the original Talking Head while its card is visible"],"retailTalkingHeadHide",function() ns.Retail.Dialogue.Apply() end)
        Note(L["Blizzard keeps playing the dialogue. BanzaiSland shows the speaker, text and remaining time; dismissing uses the game's own close action. Item level is informational and does not replace stat-based upgrade detection."])
    end

    Page(23)
    Section(L["WHILE YOU WERE AWAY"])
    Toggle(L["Catch up after AFK"], "catchUp", function() ns.CatchUp.Apply() end)
    Toggle(L["Away timer and catch-up bubble"], "catchUpBubble", function() ns.CatchUp.Apply() end)
    Cycle(L["Show a digest after"], "catchUpMinimum", {0, 60, 120, 300}, function(v)
        if v == 0 then return L["Any time away"] end
        return v == 60 and L["1 minute away"] or L["%d minutes away"]:format((v or 60)/60)
    end)
    Cycle(L["Keep updates for"], "catchUpExpire", {15,30,60,120}, function(v) return L["%d minutes"]:format(v or 60) end)
    Note(L["Updates are collected while you are AFK and logged in. A digest appears when you return. Dismiss keeps it available from the bubble or /banzaisland catchup; Clear updates removes it. Updates expire and are cleared on reload or logout."])
    Section(L["INCLUDE IN CATCH UP"])
    if ns.ClientFeature("retail") then
        Toggle(L["Retail progression and rewards"],"catchUpRetailProgress")
        Toggle(L["Collection unlocks"],"catchUpCollections")
        Toggle(L["Housing decor"],"catchUpHousing")
    end
    Toggle(L["Whispers"], "catchUpWhispers")
    Toggle(L["Auction sold, won, outbid, expired"], "catchUpAuctions")
    Toggle(L["New mail"], "catchUpMail")
    Toggle(L["Tracked hearthstone and profession cooldowns"], "catchUpCooldowns")
    if ns.ClientFeature("legacy") then
        Toggle(L["Legacy challenge completions"], "catchUpLegacy")
    end
    Toggle(L["Group invites, ready checks and queues"], "catchUpSocial")
    Note(L["Urgent prompts remain active while you are away. Catch-up entries for invites, ready checks and queues are informational. Click a whisper to reply through Pigeon when available."])
    Buttons(L["Show a sample"], function() ns.CatchUp.Demo() end, L["Clear updates"], function() ns.CatchUp.Clear() end)
    Page(13)
    Section(L["GROUP AND SOCIAL"])
    Toggle(L["Ready checks"], "promptReady")
    Toggle(L["Invites, duels, summons, resurrections"], "promptRequests")
    Toggle(L["Release spirit, graveyard and corpse"], "promptDeath")
    Toggle(L["Battleground ready to enter"], "promptBattleground")
    Toggle(L["Bind on pickup / equip confirmations"], "promptLootConfirm")
    Toggle(L["Enchant and other confirmations"], "promptConfirmations", function() ns.ApplyConfirmations() end)
    Toggle(L["Forced layer change (world refresh)"], "promptRefresh")
    Toggle(L["Whisper preview"], "showWhispers", function() ns.ApplyPigeon() end)
    Section(L["PEOPLE AND MAIL"], true)
    Toggle(L["New mail"], "alertMail")
    Toggle(L["Friends online / offline"], "alertFriends")
    Toggle(L["Guild members online / offline"], "alertGuild")
    Toggle(L["Calendar invites"], "alertCalendar")
    Toggle(L["Party joins, leaves, disconnects, leader"], "groupParty")
    Toggle(L["Raid joins, leaves, disconnects, leader"], "groupRaid")
    Note(L["Reminders repeat every 5 minutes."])


    Page(2)
    Section(L["ITEMS"])
    Toggle(L["Item toasts"], "toastItems")
    if ns.ClientFeature("retail") then
        Toggle(L["Party and raid boss-loot summaries"],"retailBossLoot",function() ns.Retail.BossLoot.Apply() end)
        Note(L["Groups other players' boss drops by encounter, with recipient names and item links. Your own drops use the normal loot and upgrade cards."])
    end
    local qualityNames = { [0] = L["Any"], L["Common"], L["Uncommon"], L["Rare"], L["Epic"] }
    Toggle(L["Upgrade toasts (needs ItemTree, Lootified or Pawn)"], "toastUpgrades", nil, ns.CanCheckUpgrades)
    Toggle(L["Reward toasts"], "toastRewards")
    Toggle(L["Upgrade details on loot rolls"], "rollUpgrades", nil, ns.CanCheckUpgrades)
    Section(L["UPGRADE DETECTION"], true)
    Cycle(L["Lowest item quality"], "itemMinQuality", { 0, 1, 2, 3, 4 }, function(v)
        return qualityNames[v or 0] or L["Any"], ns.QualityColor(v or 0)
    end)
    Note(L["Which upgrade checker to use (ItemTree, Lootified or Pawn) is chosen in Supported Addons."])
    Section(L["LOOT ROLLS"])
    Toggle(L["Loot rolls"], "lootRolls", function() ns.ApplyLootRolls() end)
    Toggle(L["Roll winners"], "showRollWinners")
    Section(L["GAINS"], true)
    Toggle(L["Money toasts"], "toastMoney")
    Toggle(L["Show money in a coin bubble instead"], "moneyBubble")
    Toggle(L["Currency toasts"], "toastCurrency")
    Toggle(L["Reputation toasts"], "toastRep")
    Toggle(L["Auction sold, won, outbid, expired"], "toastAuction")
    Page(16)
    Section(L["VENDOR"])
    Toggle(L["Sell grey items at vendors"], "vendorSell")
    Toggle(L["Repair at vendors"], "vendorRepair")
    Note(L["Hold Shift while opening a vendor to skip both that time."])

    Page(14)
    Section(L["WORLD"])
    Toggle(L["Discovery cards"], "showDiscoveries")
    Toggle(L["Zone changes"], "zoneCards")
    Toggle(L["Area changes within a zone"], "subzoneCards")
    Toggle(L["Rare mob spotted"], "showRares")

    Page(3)
    Section(L["GEAR AND BAGS"])
    Toggle(L["Low durability"], "alertDurability")
    Toggle(L["Bags nearly full"], "alertBags")
    if ns.ClientFeature("reagents") then
        Toggle(L["Low ammo and reagents"], "alertReagents")
    end
    Toggle(L["Buffs about to expire"], "alertBuffs")
    Section(L["THRESHOLDS AND REMINDERS"], true)
    Row(L["Durability threshold"])(Slider(page, 5, 75, 5, function() return db.durabilityThreshold or 25 end, function(v)
        db.durabilityThreshold = v
        if ns.UpdateRepairDot then ns.UpdateRepairDot() end
    end, function(v) return floor(v + 0.5) .. "%" end))
    Toggle(L["Low durability reminder"], "durabilityReminder")
    Toggle(L["Red armor icon while repairs are needed"], "repairDot", function() ns.UpdateRepairDot() end)
    Row(L["Bag full threshold"])(Slider(page, 1, 20, 1, function() return db.bagThreshold or 3 end, function(v)
        db.bagThreshold = v
    end, function(v)
        v = floor(v + 0.5)
        return (v == 1 and L["%d slot free"] or L["%d slots free"]):format(v)
    end))
    Toggle(L["Bags nearly full reminder"], "bagReminder")
    Page(4)
    local act = function() if ns.ApplyActivities then ns.ApplyActivities() end end
    Section(L["BUBBLES BESIDE THE ISLAND"])
    Cycle(L["Bubbles shown at once"], "bubbleCount", { 0, 1, 2, 3, 4, 5, 6 }, function(v)
        v = tonumber(v) or 1
        if v == 0 then return L["None"] end
        return v == 1 and L["1 bubble"] or L["%d bubbles"]:format(v)
    end, function() ns.Island:UpdateBubble() end)
    Toggle(L["Only urgent bubbles (breath, breaks, ready check, restart)"], "bubblesUrgentOnly", function() ns.Island:UpdateBubble() end)
    Toggle(L["Timers show a bar on their bubble"], "bubbleBars", function() ns.Island:UpdateBubble() end)
    Toggle(L["Rested"], "showRested", refresh)
    local SIDE = { right = L["Right"], left = L["Left"], below = L["Underneath"] }
    Cycle(L["Bubbles sit"], "bubbleSide", { "right", "left", "below" }, function(v) return SIDE[v] or L["Right"] end, function()
        ns.Island.awake = true
    end)
    Toggle(L["Tint the bubble icons with the accent"], "accentBubbles", function() ns.Island:ApplyColors() end)

    Page(21)
    Section(L["TRAVEL AND COOLDOWNS"])
    Toggle(L["Flight timer"], "liveFlight")
    Toggle(L["Hearthstone cooldown (last 10 minutes)"], "liveHearth")
    Section(L["COMBAT AND GROUP"], true)
    Toggle(L["Breath, fatigue and feign death"], "liveTimers", function() ns.ApplyQuiet() end)
    Toggle(L["Battleground queue"], "liveQueue")
    Toggle(L["Instance run timer, gold and XP"], "instanceTracker", function() if ns.Instance then ns.Instance.Refresh() end end)
    Toggle(L["Raid lockout reset, inside a saved raid"], "liveLockout", act)
    Toggle(L["Ready check countdown"], "liveReady", act)
    Toggle(L["Pull timers, countdowns and breaks"], "livePull", act)
    if ns.ClientFeature("retail") then
        Section(L["RETAIL BUBBLES"])
        local retailBubbles=function() ns.Retail.Apply() end
        Toggle(L["Great Vault reward ready"],"bubbleRetailVault",retailBubbles)
        Toggle(L["Unspent profession Knowledge"],"bubbleRetailKnowledge",retailBubbles)
        Toggle(L["Dungeon Finder queue"],"bubbleRetailQueue",retailBubbles)
        Toggle(L["Talking Head dialogue"],"bubbleRetailDialogue",function() ns.Retail.Dialogue.Apply() end)
        Note(L["Retail bubbles have their own toggles and follow your bubble limit and urgency setting. Vault and Knowledge bubbles can remain visible with their reminder cards disabled."])
    end
    Section(L["MORE BUBBLE TYPES"], true)
    Toggle(L["Server restart countdown"], "liveShutdown", act)
    Toggle(L["Fishing lure"], "liveLure", act)
    Toggle(L["Active tracking (herbs, minerals)"], "liveTracking", act)
    if ns.ClientFeature("ammo") then
        Toggle(L["Ammo count (arrows, bullets, thrown)"], "liveAmmo", function() if ns.UpdateAmmoBubble then ns.UpdateAmmoBubble() end end)
    end
    Section(L["BESIDE THE ISLAND, LEFT"])
    Toggle(L["Flask when a profession cooldown is ready"], "liveProfCD", act)

    Note(L["Flight times are learned the first time you fly a route. When more is running than fits, the most urgent ones show."])
    Page(20)
    Section(L["PINNED BUBBLES"])
    local pinUpd = function() ns.Island:UpdateBubble() end
    if ns.ClientFeature("ammo") then
        Toggle(L["Pin the ammo count"], "pinAmmo", pinUpd)
    end
    Toggle(L["Pin active tracking"], "pinTracking", pinUpd)
    Toggle(L["Pin the resting moon"], "pinRested", pinUpd)
    Note(L["A pinned bubble always shows, on the other side of the island from the bubbles that come and go (beside the warning dot), and doesn't count toward Bubbles shown at once."])
    Page(15)
    Section(L["FLIGHT AND COUNTDOWN OPTIONS"])
    Toggle(L["Run summary when leaving an instance"], "instanceSummary")
    Toggle(L["Hide the game's Request Stop button"], "flightHideStop", function() if ns.ApplyFlightStop then ns.ApplyFlightStop() end end)
    Toggle(L["Also show the game's big countdown numbers"], "showGameCountdown", function() if ns.QuietCountdown then ns.QuietCountdown() end end)

    Page(18)
    Section(L["BY YOUR UNIT FRAME"])
    Toggle(L["Buff pills"], "sealPill", function() ns.Seals:Check() end)
    local sideNames = { below = L["Below"], above = L["Above"], left = L["Left"], right = L["Right"] }
    Cycle(L["Buff pills come out"], "sealSide", { "below", "above", "right", "left" }, function(v)
        return sideNames[v or "below"] or L["Below"]
    end)
    Toggle(L["Hide the Cooldown Manager's own buff icons"], "buffHideBlizzard", function() ns.Seals:Check() end)
    if ns.ClientFeature("paladinSeals") then
        Toggle(L["Paladins: warn in combat with no seal"], "sealWarn", function() ns.Seals:Check() end)
    end
    Note(ns.ClientFeature("paladinSeals") and L["A pill for each buff you track in the game's Cooldown Manager (Tracked Buffs and Tracked Bars) while it's up, with its time left. Pick the buffs in the Cooldown Manager's settings; keep the Cooldown Manager turned on, and hide its own icons here if the pills replace them. Paladins also see their seal even when it isn't tracked there."] or L["A pill for each buff you track in the game's Cooldown Manager (Tracked Buffs and Tracked Bars) while it's up, with its time left. Pick the buffs in the Cooldown Manager's settings; keep the Cooldown Manager turned on, and hide its own icons here if the pills replace them."])

    Page(6)
    local isl = ns.Island
    local function look() isl:ApplyLook() RefreshAll() end
    -- the accent swatch always shows the colour in use; picking one makes it your own
    local function syncAccent()
        if db.accentMode ~= "custom" then
            local a = ns.Accent()
            db.accent[1], db.accent[2], db.accent[3] = a[1], a[2], a[3]
        end
    end
    local barShown = {}
    local function syncBar()
        local b = ns.BarColor()
        barShown[1], barShown[2], barShown[3] = b[1], b[2], b[3]
    end
    local function recolor()
        syncBar()
        syncAccent()
        isl:ApplyColors()
        isl:Refresh()
        RefreshAll()
    end
    syncAccent()
    -- BanzaiSland: the BANZAI visual language first; everything below it is upstream Island's own look
    -- (scoped in a block: Build() is close to Lua's 200 active locals)
    do
        local Theme = ns.Theme
        local function banzai() isl:ApplyLook() RefreshAll() end
        Section(L["BANZAI"])
        local MATN = { glass = L["Banzai Glass"], solid = L["Solid"], parchment = L["Hardkorh Parchment"] }
        Cycle(L["Material"], "material", Theme.MATERIALS, function(v) return MATN[v or "glass"] or L["Banzai Glass"] end, banzai)
        -- 0.2.0: CHASSIS EDGE STYLE - bamboo (end-caps and hairlines) or hairline (a four-sided thin frame)
        local EDGEN = { bamboo = L["Bamboo"], hairline = L["Hairline"] }
        Cycle(L["Chassis edge"], "chassisEdge", Theme.CHASSIS, function(v) return EDGEN[v or "bamboo"] or L["Bamboo"] end, banzai)
        local ACCN = { banzai = L["Banzai"], class = L["Class"], hardkorh = L["Hardkorh"] }
        Cycle(L["Accent"], "accentTheme", Theme.ACCENTS, function(v)
            return ACCN[v or "banzai"] or L["Banzai"], Theme.Primary()
        end, function() syncBar() syncAccent() banzai() end)
        Toggle(L["Bamboo end-caps"], "bambooCaps", banzai)
        Toggle(L["Accent hairlines"], "hairline", banzai)
        Toggle(L["Accent rings on bubbles"], "bubbleRing", banzai)
        Toggle(L["Original Banzai class artwork"], "classArt", banzai)
        Cycle(L["Display font"], "displayFont", Theme.DISPLAY_FONTS, function(v)
            return Theme.DisplayFontLabel(v or "auto")
        end, function() ns.ApplyFont() RefreshAll() end)
        Note("BANZAI Default uses Shojumaru at 105%. Automatic uses that default only when the complete string is supported; otherwise it uses the Information Font. This choice is independent of BANZAI UI.")
    end
    Section(L["LOOK"])
    Row(L["Size"])(Slider(page, 0.7, 1.6, 0.05, function() return db.scale end, function(v)
        db.scale = v
        isl:ApplyPosition()
    end, function(v) return floor(v * 100 + 0.5) .. "%" end))
    Row(L["Text size"])(Slider(page, 0.85, 1.3, 0.05, function() return db.textScale or 1 end, function(v)
        db.textScale = v
        ns.ApplyTextSize()
    end, function(v) return floor(v * 100 + 0.5) .. "%" end))
    -- Font: Automatic is Open Sans, or the game's font on Korean and Chinese clients
    local fonts = { "auto", "island", "game" }
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM.List then
        for _, name in ipairs(LSM:List("font") or {}) do fonts[#fonts + 1] = name end
    end
    local FONTN = { auto = L["Automatic"], island = L["Information font (Open Sans)"], game = L["Game font"] }
    Cycle(L["Font"], "font", fonts, function(v)
        v = v or "auto"
        if v == "auto" then local loc = ns.LOCALE return (loc == "koKR" or loc == "zhCN" or loc == "zhTW") and L["Automatic (game)"] or L["Automatic"] end
        return FONTN[v] or v
    end, function()
        ns.ApplyFont()
        RefreshAll()
    end)
    local OUTLN = { none = L["None"], thin = L["Thin"], thick = L["Thick"] }
    Cycle(L["Font outline"], "fontOutline", { "none", "thin", "thick" }, function(v)
        return OUTLN[v or "none"] or L["None"]
    end, function()
        ns.ApplyFont()
        RefreshAll()
    end)
    local LOOK = { modern = L["Modern"], forever = L["Forever"] }
    Cycle(L["Style"], "lookStyle", { "modern", "forever" }, function(v)
        return LOOK[v] or L["Modern"]
    end, look)
    -- pill and card fill (Modern style); right-click the swatch for the default black
    db.shellColor = db.shellColor or { unpack(ns.defaults.shellColor) }
    Row(L["Pill and card color"])(Swatch(page, db.shellColor, ns.defaults.shellColor, function()
        isl:ApplyOpacity()
    end))
    Row(L["Opacity"])(Slider(page, 0.3, 1, 0.05, function() return db.opacity or 1 end, function(v)
        db.opacity = v
        isl:ApplyOpacity()
    end, function(v) return v >= 0.999 and L["Solid"] or (floor(v * 100 + 0.5) .. "%") end))
    local IDLE = { full = L["Level and %"], percent = L["Percent"], bar = L["Bar only"], dot = L["Dot"], hidden = L["Hidden"] }
    Cycle(L["Idle style"], "idleStyle", { "full", "percent", "bar", "dot", "hidden" }, function(v) return IDLE[v] or L["Level and %"] end, look)
    -- the bar swatch shows the colour in use; picking one goes back to your own
    syncBar()
    local BARN = { theme = L["Banzai accent"], custom = L["My own"], class = L["Class color"] }
    ColorChoice(L["Bar color"],
        MakeCycle("barMode", { "theme", "custom", "class" }, function(v)
            return BARN[v or "theme"] or L["Banzai accent"], (v == "class") and ns.ClassColor() or (v == "theme" and ns.Theme.Primary()) or nil
        end, function() syncBar() recolor() end),
        Swatch(page, barShown, ns.defaults.xpColor, function()
            db.xpColor[1], db.xpColor[2], db.xpColor[3] = barShown[1], barShown[2], barShown[3]
            db.barMode = "custom"
            recolor()
        end))
    refreshers[#refreshers + 1] = syncBar
    if ns.QuestXPAvailable and ns.QuestXPAvailable() then
        Toggle(L["Completed quest XP on the bar"], "questXPBar", function()
            ns.QuestXPDirty()
            ns.Island:Refresh()
        end)
        db.questXPColor = db.questXPColor or { unpack(ns.defaults.questXPColor) }
        Row(L["Completed quest color"])(Swatch(page, db.questXPColor, ns.defaults.questXPColor, recolor))
    end
    Section(L["MORE COLORS"], true)
    Row(L["Rested color"])(Swatch(page, db.restColor, ns.defaults.restColor, recolor))
    local ACC = { theme = L["Banzai accent"], bar = L["Bar color"], class = L["Class color"], custom = L["My own"] }
    ColorChoice(L["Accent color"],
        MakeCycle("accentMode", { "theme", "bar", "class", "custom" }, function(v)
            return ACC[v or "theme"] or L["Banzai accent"], (v == "class") and ns.ClassColor() or (v == "theme" and ns.Theme.Primary()) or nil
        end, recolor),
        Swatch(page, db.accent, barShown, function()
            local a, x = db.accent, ns.BarColor()
            -- right-click puts it back on the bar colour; anything else is your own pick
            local same = math.abs(a[1] - x[1]) + math.abs(a[2] - x[2]) + math.abs(a[3] - x[3]) < 0.01
            db.accentMode = same and "bar" or "custom"
            recolor()
        end))
    Section(L["ISLAND BORDER"], true)
    local function border() isl:ApplyBorder() end
    Toggle(L["Border"], "borderOn", border)
    Toggle(L["Bubble borders (match island border)"], "bubbleBorderOn", border)
    Row(L["Border thickness"])(Slider(page, 1, 12, 1, function() return db.borderSize or 2 end, function(v)
        db.borderSize = v
        border()
    end, function(v) return floor(v + 0.5) .. " px" end))
    db.borderColor = db.borderColor or { unpack(ns.defaults.borderColor) }
    Toggle(L["Use class color"], "borderClass", border)
    Row(L["Border color"])(Swatch(page, db.borderColor, ns.defaults.borderColor, border))
    Row(L["Border opacity"])(Slider(page, 0.1, 1, 0.05, function() return db.borderAlpha or 1 end, function(v)
        db.borderAlpha = v
        border()
    end, function(v) return floor(v * 100 + 0.5) .. "%" end))
    local LSMB = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSMB and LSMB.List then
        local borders = { "solid" }
        for _, name in ipairs(LSMB:List("border") or {}) do
            if name ~= "None" then borders[#borders + 1] = name end
        end
        if #borders > 1 then
            Cycle(L["Border texture"], "borderTexture", borders, function(v)
                return (v == nil or v == "solid") and L["Solid color"] or v
            end, border)
        end
    end
    Section(L["SETTINGS WINDOW"], true)
    local function panel() ns.ApplyPanelStyle() end
    Toggle(L["Window border"], "panelBorderOn", panel)
    Row(L["Window border thickness"])(Slider(page, 1, 12, 1, function() return db.panelBorderSize or 2 end, function(v)
        db.panelBorderSize = v
        panel()
    end, function(v) return floor(v + 0.5) .. " px" end))
    db.panelBorderColor = db.panelBorderColor or { unpack(ns.defaults.panelBorderColor) }
    Toggle(L["Use class color"], "panelBorderClass", panel)
    Row(L["Window border color"])(Swatch(page, db.panelBorderColor, ns.defaults.panelBorderColor, panel))
    Row(L["Window border opacity"])(Slider(page, 0.1, 1, 0.05, function() return db.panelBorderAlpha or 0.25 end, function(v)
        db.panelBorderAlpha = v
        panel()
    end, function(v) return floor(v * 100 + 0.5) .. "%" end))
    db.panelBgColor = db.panelBgColor or { unpack(ns.defaults.panelBgColor) }
    Row(L["Window background color"])(Swatch(page, db.panelBgColor, ns.defaults.panelBgColor, panel))
    Row(L["Window background opacity"])(Slider(page, 0.3, 1, 0.01, function() return db.panelBgAlpha or 0.97 end, function(v)
        db.panelBgAlpha = v
        panel()
    end, function(v) return floor(v * 100 + 0.5) .. "%" end))
    y = y - 10   -- breathing room under the group above
    Buttons(L["Reset window look"], function()
        db.panelBorderClass = ns.defaults.panelBorderClass
        db.panelBorderOn, db.panelBorderSize, db.panelBorderAlpha = ns.defaults.panelBorderOn, ns.defaults.panelBorderSize, ns.defaults.panelBorderAlpha
        db.panelBgAlpha = ns.defaults.panelBgAlpha
        for _, k in ipairs({ "panelBorderColor", "panelBgColor" }) do
            for i = 1, 3 do db[k][i] = ns.defaults[k][i] end
        end
        panel()
        RefreshAll()
    end)
    Note(L["Pick Game font if letters show up as boxes or question marks. Quest log, SCT and Pigeon pick up a font change after /reload. Hidden shows nothing until a card comes; hover its spot to bring up your details. The accent colors the percent, the switches and the highlights. Picking a color in the swatch makes it your own; right-click it to go back to the bar color."])
    Page(12)
    Section(L["PLACEMENT"])
    local POS = { top = L["Top"], bottom = L["Bottom"], free = L["Custom"] }
    Cycle(L["Position"], "position", { "top", "bottom", "free" }, function(v) return POS[v] or L["Top"] end, function()
        isl:ApplyPosition()
        RefreshAll()
    end)
    -- which edge stays put when the island opens, so it can sit at the side of the screen
    local GROW = { auto = L["Auto"], center = L["Center"], left = L["Left edge"], right = L["Right edge"] }
    Cycle(L["Grows from"], "growX", { "auto", "center", "left", "right" }, function(v) return GROW[v or "auto"] or L["Auto"] end, function()
        isl:ApplyPosition()
        RefreshAll()
    end)
    local OPENS = { auto = L["Auto"], down = L["Down"], up = L["Up"] }
    Cycle(L["Cards open"], "growY", { "auto", "down", "up" }, function(v) return OPENS[v or "auto"] or L["Auto"] end, function()
        isl:ApplyPosition()
        RefreshAll()
    end)
    -- X and Y: the middle of the resting island, in pixels from the middle of the screen
    local function NumberBox(get, set)
        local e = CreateFrame("EditBox", nil, page)
        e:SetSize(70, 26)
        e:SetAutoFocus(false)
        e.bg = ns.CreateControl(e, ns.Theme.UI.radius, "BACKGROUND", 0)
        e.bg:SetWidth(70)
        e.bg:SetColor(1, 1, 1, 0.08)
        ns.UseFont(e, "bold", 12.5)
        e:SetTextColor(C.fg[1], C.fg[2], C.fg[3])
        e:SetJustifyH("CENTER")
        e:SetTextInsets(6, 6, 0, 0)
        e:SetMaxLetters(6)
        local function show()
            if e.HasFocus and e:HasFocus() then return end
            local v = get()
            e:SetText(v and tostring(floor(v + 0.5)) or "")
        end
        local function commit(self)
            local v = tonumber(self:GetText())
            if v then set(floor(v + 0.5)) end
            show()
        end
        e:SetScript("OnEnterPressed", function(self) commit(self) self:ClearFocus() end)
        e:SetScript("OnTabPressed", function(self) commit(self) self:ClearFocus() end)
        e:SetScript("OnEscapePressed", function(self) self:ClearFocus() show() end)
        e:SetScript("OnEditFocusGained", function(self)
            self.bg:SetColor(1, 1, 1, 0.16)
            self:HighlightText()
        end)
        e:SetScript("OnEditFocusLost", function(self) self.bg:SetColor(1, 1, 1, 0.08) show() end)
        refreshers[#refreshers + 1] = show
        show()
        return e
    end
    local coords = CreateFrame("Frame", nil, page)
    coords:SetSize(14 + 6 + 70 + 14 + 14 + 6 + 70, 26)
    local function here() local x, y = isl:ReadCenter() return x, y end
    local xb = NumberBox(function() return (select(1, here())) end, function(v)
        local _, y = here()
        isl:MoveTo(v, y or 0)
    end)
    local yb = NumberBox(function() return (select(2, here())) end, function(v)
        local x = here()
        isl:MoveTo(x or 0, v)
    end)
    local xl = ns.Text(coords, "bold", 12, C.muted)
    xl:SetText(L["X"])
    xl:SetPoint("LEFT", coords, "LEFT", 0, 0)
    xb:SetParent(coords)
    xb:SetPoint("LEFT", xl, "RIGHT", 6, 0)
    local yl = ns.Text(coords, "bold", 12, C.muted)
    yl:SetText(L["Y"])
    yl:SetPoint("LEFT", xb, "RIGHT", 14, 0)
    yb:SetParent(coords)
    yb:SetPoint("LEFT", yl, "RIGHT", 6, 0)
    Row(L["Coordinates"])(coords)
    local FADEN = { off = L["Stay"], dim = L["Dim"], hide = L["Hide"] }
    Cycle(L["In combat the island"], "combatFade", { "off", "dim", "hide" }, function(v) return FADEN[v] or L["Stay"] end)
    Toggle(L["Lock position"], "locked", function(v)
        if not v then ns.Print(L["unlocked. Drag the island where you want it."]) end
    end)
    Note(L["X and Y are the middle of the island in pixels from the middle of the screen; right and up are positive. Typing them, or dragging the island, sets Position to Custom. Below the middle of the screen cards open upward. The game's Edit Mode, ElvUI's movers and EllesmereUI's unlock mode can move the island too. Cards and loot rolls always show in combat."])

    Page(7)
    Section(L["FEEL"])
    local FEEL = { snappy = L["Snappy"], smooth = L["Smooth"], calm = L["Calm"] }
    Cycle(L["Animation"], "feel", { "snappy", "smooth", "calm" }, function(v) return FEEL[v] or L["Smooth"] end, function()
        ns.ApplyFeel()
        isl:Demo()
    end)
    Row(L["Card time"])(Slider(page, 0.6, 2.0, 0.1, function() return db.cardTime or 1 end, function(v)
        db.cardTime = v
    end, function(v) return floor(v * 100 + 0.5) .. "%" end))
    Section(L["HOW LONG EACH KIND STAYS"], true)
    local TIMEN = { short = L["Short"], normal = L["Normal"], long = L["Long"] }
    local times = { "short", "normal", "long" }
    local function Time(label, key) Cycle(label, key, times, function(v) return TIMEN[v] or L["Normal"] end) end
    Time(L["Loot, money and reputation"], "timeLoot")
    Time(L["Whispers, friends and group"], "timeSocial")
    Time(L["Alerts and timers"], "timeAlerts")
    Time(L["Zones, quests, skills and rares"], "timeWorld")
    Page(25)
    Section(L["SOUNDS"])
    Toggle(L["Sounds"], "sounds")
    Section(L["SOUND DETAILS"], true)
    Toggle(L["Loot and money"], "soundLoot")
    Toggle(L["Whispers, friends and group"], "soundSocial")
    Toggle(L["Alerts and timers"], "soundAlerts")
    Toggle(L["Rares"], "soundWorld")
    Toggle(L["Invites, ready checks and other questions"], "soundPrompts")
    local keys, names = {}, {}
    for _, snd in ipairs(ns.SOUNDS) do keys[#keys + 1] = snd.key names[snd.key] = snd.name end
    local function name(v) return names[v] or L["Default"] end
    local function CardSound(event)
        local box = CreateFrame("Frame", nil, page)
        box:SetHeight(30)
        local preview = PillButton(box, L["Preview"], 74, function() ns.PreviewCardSound(event.key) end)
        FitPill(preview, 74)
        preview:SetPoint("RIGHT", box, "RIGHT", 0, 0)
        local button
        local function paint()
            button.text:SetText(name(ns.GetCardSoundChoice(event.key)))
            FitPill(button, 150)
            box:SetWidth(button:GetWidth() + 10 + preview:GetWidth())
        end
        button = Droppable(PillButton(box, "", 150, function()
            OpenMenu(button, keys, name, ns.GetCardSoundChoice(event.key), function(choice)
                ns.SetCardSoundChoice(event.key, choice)
                paint()
            end)
        end))
        button:SetPoint("LEFT", box, "LEFT", 0, 0)
        Row(event.label)(box)
        local words = {event.key, event.group, L["Preview"]}
        for _, key in ipairs(keys) do words[#words + 1] = name(key) end
        searchIndex[#searchIndex].keywords = table.concat(words, " ")
        refreshers[#refreshers + 1] = paint
        paint()
    end
    local groupLabels = {
        loot = L["LOOT"], social = L["SOCIAL CARDS"], alerts = L["ALERTS AND TIMERS"],
        world = L["RARE ALERTS"], prompts = L["QUESTIONS AND LOOT ROLLS"],
    }
    local soundGroups = {}
    for _, event in ipairs(ns.CARD_SOUNDS) do
        if (not event.feature or ns.ClientFeature(event.feature)) and not soundGroups[event.group] then
            soundGroups[event.group] = true
            Section(groupLabels[event.group] or L["OTHER SOUNDS"], true)
            for _, row in ipairs(ns.CARD_SOUNDS) do
                if row.group == event.group and (not row.feature or ns.ClientFeature(row.feature)) then CardSound(row) end
            end
        end
    end
    Note(L["Use Preview to hear the selected sound, even when sounds are muted. None and silent defaults do not play. These follow your Sound Effects volume."])

    Page(8)
    Section(L["BEHAVIOR"])
    Toggle(L["Do Not Disturb"], "dnd", function(v) ns.SetDND(v) end)
    local profileLink = PillButton(page, "", 150, function() Select(27, true) end)
    Row(L["Settings profile"])(profileLink)
    refreshers[#refreshers + 1] = function()
        profileLink.text:SetText(ns.Profiles.Active() == ns.Profiles.DEFAULT and L["Default"] or ns.Profiles.Active())
    end
    profileLink.text:SetText(ns.Profiles.Active() == ns.Profiles.DEFAULT and L["Default"] or ns.Profiles.Active())
    Toggle(L["Details on hover"], "hoverDetails")
    Toggle(L["Minimap button"], "minimapButton", function() if ns.ApplyMinimapButton then ns.ApplyMinimapButton() end end)
    Section(L["CARD BEHAVIOR"], true)
    Toggle(L["Hold cards until combat ends"], "holdInCombat")
    Toggle(L["No cards in raids"], "quietInRaid")
    Toggle(L["Reputation at max level"], "repAtMax", refresh)
    Section(L["GAME UI"], true)
    Toggle(L["Hide Blizzard XP bar"], "hideBlizzard", function(v)
        if v then ns.ApplyBlizzardBar() else ns.Print(L["type /reload to bring the Blizzard bar back."]) end
    end)
    Toggle(L["Hide Blizzard zone text"], "hideZoneText", function(v)
        if v then ns.ApplyZoneText() else ns.Print(L["type /reload to bring the Blizzard zone text back."]) end
    end)
    Toggle(L["Red error text under the island"], "showErrors", function() ns.ApplyQuiet() end)
    Toggle(L["Hide the game's pop-ups the island covers"], "hideBlizzardPopups", function(v)
        if v then ns.ApplyQuiet() else ns.ApplyQuiet() ns.Print(L["type /reload to bring all of the game's pop-ups back."]) end
    end)
    Note(L["Scroll the mouse wheel over the island to look back through past cards."])

    -- Extensions library (page 26): who has registered with Island, search, filter, sort, details.
    -- Uses the data the API already keeps plus the addon's own TOC fields; nothing here is trusted
    -- as markup, and no extension code runs from this page.
    if type(ns.Extensions) == "table" then
    Page(26)
    do
        local ext = ns.Extensions
        local pg = page
        local ROWH, ROWGAP, LIST_TOP = 58, 6, -152
        local GREEN, AMBER = { 0.43, 0.85, 0.56 }, { 0.95, 0.72, 0.30 }
        local state = { filter = "all", sort = "name", query = "", open = nil, tab = "overview", listScroll = 0 }
        local ATTN = { invalid_payload = true, capacity = true, adapter_error = true }
        local ORDER = { attention = 1, active = 2, waiting = 3, disabled = 4 }
        local info = {}

        local function Clean(v, limit)
            if type(v) ~= "string" then return nil end
            v = v:gsub("[%c|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if v == "" then return nil end
            if #v > limit then v = v:sub(1, limit):gsub("[\192-\255][\128-\191]*$", "") .. "..." end
            return v
        end
        local function Meta(id, field, limit)
            local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
            if not get then return nil end
            local ok, value = pcall(get, id, field)
            return ok and Clean(value, limit) or nil
        end
        -- TOC details of the addon whose folder name is the extension id (read once, plain text)
        local function Info(id)
            if not info[id] then
                info[id] = { version = Meta(id, "Version", 32), author = Meta(id, "Author", 64), notes = Meta(id, "Notes", 1024),
                    website = Meta(id, "X-Website", 200), category = Meta(id, "X-BanzaiSland-Category", 40),
                    icon = Meta(id, "IconTexture", 200) }
            end
            return info[id]
        end
        local function StatusOf(e)
            if not e.enabled then return "disabled" end
            if e.rejected > 0 and ATTN[e.lastReason or ""] then return "attention" end
            if not e.ready then return "waiting" end
            return "active"
        end
        local STATUS = { active = L["Active"], disabled = L["Disabled"], attention = L["Needs attention"], waiting = L["Waiting"] }
        local function StatusColor(s)
            if s == "active" then return GREEN end
            if s == "attention" then return AMBER end
            return C.muted
        end
        local FILTERS = { "all", "enabled", "disabled", "attention" }
        local FILTER_NAME = { all = L["All"], enabled = L["Enabled"], disabled = L["Disabled"], attention = L["Needs attention"] }
        local SORTS = { "name", "status" }
        local SORT_NAME = { name = L["Sort: Name"], status = L["Sort: Status"] }
        local AUDIENCE = { both = L["Both clients"], forever = L["Forever only"], retail = L["Retail only"] }
        local REASON = {
            not_ready = L["BanzaiSland was not ready yet"], disabled = L["It was switched off"],
            unavailable_client = L["Not available on this client"], invalid_payload = L["It sent something BanzaiSland could not show"],
            rate_limited = L["It sent too many at once"], capacity = L["Too many at once"],
            already_registered = L["It registered twice"], unsupported_version = L["Newer API than BanzaiSland supports"],
            adapter_error = L["BanzaiSland could not show it"],
        }

        -- ---- data
        local function Collect()
            local all, attention = ext.List(), 0
            local items, q = {}, state.query:lower()
            for _, e in ipairs(all) do
                local s = StatusOf(e)
                if s == "attention" then attention = attention + 1 end
                local i = Info(e.id)
                local ok = state.filter == "all" or (state.filter == "enabled" and e.enabled)
                    or (state.filter == "disabled" and not e.enabled) or (state.filter == "attention" and s == "attention")
                if ok and q ~= "" then
                    local hay = (e.name .. " " .. e.id .. " " .. (i.author or "") .. " " .. (i.notes or "")):lower()
                    ok = hay:find(q, 1, true) ~= nil
                end
                if ok then items[#items + 1] = { e = e, info = i, status = s } end
            end
            table.sort(items, function(a, b)
                if state.sort == "status" and a.status ~= b.status then return ORDER[a.status] < ORDER[b.status] end
                local an, bn = a.e.name:lower(), b.e.name:lower()
                if an ~= bn then return an < bn end
                return a.e.id < b.e.id
            end)
            return items, all, attention
        end

        -- ---- list view
        local list = CreateFrame("Frame", nil, pg)
        list:SetPoint("TOPLEFT", pg, "TOPLEFT", 0, 0)
        list:SetSize(CW, 10)
        local count = ns.Text(list, "medium", 11.5, C.muted)
        count:SetPoint("TOPLEFT", list, "TOPLEFT", GAP_X, -118)
        local searchBox = CreateFrame("EditBox", nil, list)
        searchBox:SetSize(CW, 30)
        searchBox:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -72)
        searchBox:SetAutoFocus(false)
        searchBox:SetMaxLetters(40)
        searchBox.bg = ns.CreateControl(searchBox, ns.Theme.UI.radius, "BACKGROUND", 0)
        searchBox.bg:SetWidth(CW)
        searchBox.bg:SetColor(1, 1, 1, 0.08)
        ns.UseFont(searchBox, "medium", 12.5)
        searchBox:SetTextColor(C.fg[1], C.fg[2], C.fg[3])
        searchBox:SetTextInsets(16, 16, 0, 0)
        local hint = ns.Text(searchBox, "medium", 12.5, C.muted)
        hint:SetPoint("LEFT", searchBox, "LEFT", 16, 0)
        hint:SetText(L["Search extensions"])
        local function paintHint() hint:SetShown((searchBox:GetText() or "") == "" and not (searchBox.HasFocus and searchBox:HasFocus())) end
        searchBox:SetScript("OnEditFocusGained", function(self) self.bg:SetColor(1, 1, 1, 0.16) paintHint() end)
        searchBox:SetScript("OnEditFocusLost", function(self) self.bg:SetColor(1, 1, 1, 0.08) paintHint() end)
        searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

        local function MenuPill(width, values, names, get, set)
            local button
            local function paint()
                button.text:SetText(names[get()] or "")
                FitPill(button, width)
            end
            button = Droppable(PillButton(list, "", width, function()
                OpenMenu(button, values, function(v) return names[v] end, get(), function(v) set(v) paint() end)
            end))
            paint()
            return button
        end
        local Refresh, ShowList, ShowDetail
        -- the extension's picture: its card art, else its bubble art, else the addon's own icon, else a plain tile
        local function PaintExtIcon(tex, fallback, id, tocIcon)
            local pic = ext.Icon(id)
            local shown = false
            tex:SetTexCoord(0, 1, 0, 1)
            tex:SetVertexColor(1, 1, 1, 1)
            if pic and pic.glyph then
                tex:SetTexture("Interface\\AddOns\\BanzaiSland\\Media\\" .. pic.glyph)
                tex:SetVertexColor(pic.tone[1], pic.tone[2], pic.tone[3], 1)
                shown = true
            elseif pic and pic.texture ~= nil then
                shown = pcall(tex.SetTexture, tex, tonumber(pic.texture) or pic.texture)
                if shown then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
            end
            if not shown and tocIcon and (tonumber(tocIcon) or tocIcon:match("^[%w_%. /\\%-]+$")) then
                shown = pcall(tex.SetTexture, tex, tonumber(tocIcon) or tocIcon)
            end
            tex:SetShown(shown)
            fallback:SetShown(not shown)
        end
        local sortPill = MenuPill(150, SORTS, SORT_NAME, function() return state.sort end, function(v) state.sort = v Refresh() end)
        sortPill:SetPoint("TOPLEFT", list, "TOPLEFT", CW - sortPill:GetWidth(), -110)
        local filterPill = MenuPill(150, FILTERS, FILTER_NAME, function() return state.filter end, function(v) state.filter = v Refresh() end)
        filterPill:SetPoint("RIGHT", sortPill, "LEFT", -8, 0)
        -- the one switch that lets packages run their code (Forever only); it sits beside the page title
        if ns.Developer and ns.Developer.SetTrusted then
            local allow = Switch(list, function() return ns.Developer.Trusted() end, function(v) ns.Developer.SetTrusted(v) end)
            allow:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -32)
            local allowLabel = ns.Text(list, "medium", 12, C.fg)
            allowLabel:SetPoint("RIGHT", allow, "LEFT", -10, 0)
            allowLabel:SetText(L["Allow package code"])
            searchIndex[#searchIndex + 1] = { label = L["Allow package code"], page = pg, group = allow, offset = 0,
                text = allowLabel, keywords = "package packages trusted lua code handlers", context = L["Extensions"] }
        end
        searchBox:SetScript("OnTextChanged", function(self)
            state.query = self:GetText() or ""
            paintHint()
            Refresh()
        end)
        local empty = ns.Text(list, "medium", 12, C.muted)
        empty:SetPoint("TOPLEFT", list, "TOPLEFT", GAP_X, LIST_TOP - 10)
        empty:SetWidth(CW - GAP_X * 2)
        empty:SetWordWrap(true)
        empty:SetJustifyH("LEFT")
        -- problems: registrations Island refused, and extensions installed but never registered
        local REG_REASON = {
            unsupported_version = L["It needs a newer BanzaiSland API than this one"], invalid_payload = L["Its registration was not valid"],
            capacity = L["BanzaiSland already has the most extensions it allows"], already_registered = L["It registered again with different details"],
        }
        local MISSING = {
            disabled = L["Switched off in the AddOns list"], dependency = L["A required addon is missing or switched off"],
            outdated = L["Marked out of date for this game version"], broken = L["The game could not load it"],
            notloaded = L["Not loaded"], noregister = L["Loaded, but it has not registered with BanzaiSland"],
        }
        local probHead = ns.Text(list, "bold", 10.5, C.muted)
        probHead:SetText(L["PROBLEMS"])
        local probRows = {}
        local function MakeProblem(n)
            local r = CreateFrame("Frame", nil, list)
            r:SetSize(CW, 46)
            r.body = ns.CreateBody(r, "BACKGROUND", 0)
            r.body:SetRadius(12)
            r.body:SetColor(1, 1, 1, 0.03)
            r.dot = ns.Image(r, "Circle", "ARTWORK", 0)
            r.dot:SetSize(7, 7)
            r.dot:SetPoint("LEFT", r, "LEFT", 16, 0)
            r.dot:SetVertexColor(AMBER[1], AMBER[2], AMBER[3], 1)
            r.name = ns.Text(r, "bold", 12.5, C.fg)
            r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 34, -8)
            r.name:SetPoint("RIGHT", r, "RIGHT", -16, 0)
            r.note = ns.Text(r, "medium", 11.5, C.muted)
            r.note:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
            r.note:SetPoint("RIGHT", r, "RIGHT", -16, 0)
            probRows[n] = r
            return r
        end
        local function Problems()
            local out = {}
            if ext.Failures then
                for _, f in ipairs(ext.Failures()) do
                    local name = f.name or f.id
                    if f.id ~= "?" and f.name and f.name ~= f.id then name = f.name .. "  (" .. f.id .. ")" end
                    if f.count > 1 then name = name .. "  x" .. f.count end
                    out[#out + 1] = { name = name, note = L["Refused: %s"]:format(REG_REASON[f.reason] or tostring(f.reason)) }
                end
            end
            if ns.Packages and ns.Packages.Problems then
                for _, p in ipairs(ns.Packages.Problems()) do
                    out[#out + 1] = { name = p.name .. "  (" .. p.id .. ")", note = ns.Packages.Reason(p.reason, p.detail) }
                end
            end
            if ext.Unregistered then
                for _, u in ipairs(ext.Unregistered()) do
                    out[#out + 1] = { name = u.title ~= u.id and (u.title .. "  (" .. u.id .. ")") or u.id, note = MISSING[u.reason] or u.reason }
                end
            end
            return out
        end
        local pkgButton, importButton
        -- where the developer documentation lives (a file in Island's folder; the game cannot open it)
        local docsLine = ns.Text(list, "medium", 11.5, C.muted)
        docsLine:SetText(L["Developer docs: %s"]:format("Interface\\AddOns\\BanzaiSland\\docs\\EXTENSIONS.md"))
        docsLine:SetWidth(CW - GAP_X * 2)
        docsLine:SetJustifyH("LEFT")
        docsLine:SetWordWrap(true)
        if ns.Packages and ns.Packages.Open then
            pkgButton = PillButton(list, L["Package creator"], 200, function() ns.Packages.Open() end)
            importButton = PillButton(list, L["Import"], 120, function() ns.Packages.Open("import") end)
        end

        local rows = {}
        local function Open(id)
            state.listScroll = at
            state.open, state.tab = id, "overview"
            want, at = 0, 0
            scroll:SetVerticalScroll(0)
            ShowDetail()
        end
        local function MakeRow(n)
            local row = CreateFrame("Button", nil, list)
            row:SetSize(CW, ROWH)
            row.body = ns.CreateBody(row, "BACKGROUND", 0)
            row.body:SetRadius(14)
            row.body:SetColor(1, 1, 1, 0.045)
            row.fallback = ns.Image(row, "Tile", "ARTWORK", 0)
            row.fallback:SetSize(26, 26)
            row.fallback:SetPoint("LEFT", row, "LEFT", 16, 0)
            row.fallback:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
            row.tex = row:CreateTexture(nil, "ARTWORK")
            row.tex:SetSize(28, 28)
            row.tex:SetPoint("LEFT", row, "LEFT", 15, 0)
            row.chev = ns.Image(row, "Chevron", "ARTWORK", 0)
            row.chev:SetSize(9, 9)
            row.chev:SetPoint("RIGHT", row, "RIGHT", -16, 0)
            row.chev:SetRotation(-math.pi / 2)
            row.chev:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
            row.switch = Switch(row, function() return row.item and row.item.e.enabled end, function(v)
                if row.item then ext.SetEnabled(row.item.e.id, v) Refresh() end
            end)
            row.switch:SetPoint("RIGHT", row, "RIGHT", -40, 0)
            row.status = ns.Text(row, "medium", 11.5, C.muted, "RIGHT")
            row.status:SetPoint("RIGHT", row.switch, "LEFT", -14, 0)
            row.dot = ns.Image(row, "Circle", "ARTWORK", 0)
            row.dot:SetSize(7, 7)
            row.dot:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
            row.name = ns.Text(row, "bold", 13, C.fg)
            row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 56, -12)
            row.name:SetPoint("RIGHT", row.dot, "LEFT", -12, 0)
            row.note = ns.Text(row, "medium", 11.5, C.muted)
            row.note:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
            row.note:SetPoint("RIGHT", row.dot, "LEFT", -12, 0)
            row:SetScript("OnEnter", function() row.body:SetColor(1, 1, 1, 0.08) end)
            row:SetScript("OnLeave", function() row.body:SetColor(1, 1, 1, 0.045) end)
            row:SetScript("OnClick", function() if row.item then Open(row.item.e.id) end end)
            rows[n] = row
            return row
        end
        local function Bind(row, item)
            row.item = item
            if not row.switch:GetScript("OnUpdate") then row.switch.Sync() end
            local e, i = item.e, item.info
            row.name:SetText(i.version and (e.name .. "  " .. i.version) or e.name)
            row.note:SetText(i.notes or (e.id ~= e.name and e.id or ""))
            row.status:SetText(STATUS[item.status])
            local color = StatusColor(item.status)
            row.status:SetTextColor(color[1], color[2], color[3])
            row.dot:SetVertexColor(color[1], color[2], color[3], 1)
            PaintExtIcon(row.tex, row.fallback, e.id, i.icon)
            row.name:SetAlpha(e.enabled and 1 or 0.55)
            row.note:SetAlpha(e.enabled and 1 or 0.55)
        end

        -- ---- details view
        local detail = CreateFrame("Frame", nil, pg)
        detail:SetPoint("TOPLEFT", pg, "TOPLEFT", 0, -70)
        detail:SetSize(CW, 10)
        local back = PillButton(detail, L["Back"], 90, function()
            state.open = nil
            ShowList()
            want, at = state.listScroll, state.listScroll
            scroll:SetVerticalScroll(at)
        end)
        back:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
        local card = CreateFrame("Frame", nil, detail)
        card:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -44)
        card:SetSize(CW, 112)
        card.body = ns.CreateBody(card, "BACKGROUND", 0)
        card.body:SetRadius(16)
        card.body:SetColor(1, 1, 1, 0.045)
        card.fallback = ns.Image(card, "Tile", "ARTWORK", 0)
        card.fallback:SetSize(36, 36)
        card.fallback:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -18)
        card.fallback:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
        card.tex = card:CreateTexture(nil, "ARTWORK")
        card.tex:SetSize(40, 40)
        card.tex:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -16)
        card.name = ns.Text(card, "extra", 17, C.fg)
        card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 68, -16)
        card.name:SetPoint("RIGHT", card, "RIGHT", -150, 0)
        card.meta = ns.Text(card, "medium", 11.5, C.muted)
        card.meta:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
        card.meta:SetPoint("RIGHT", card, "RIGHT", -150, 0)
        card.status = ns.Text(card, "bold", 11.5, C.muted)
        card.status:SetPoint("TOPLEFT", card.meta, "BOTTOMLEFT", 0, -6)
        card.switch = Switch(card, function() return card.item and card.item.e.enabled end, function(v)
            if card.item then ext.SetEnabled(card.item.e.id, v) Refresh() end
        end)
        card.switch:SetPoint("TOPRIGHT", card, "TOPRIGHT", -18, -18)
        card.enabledLabel = ns.Text(card, "medium", 12, C.muted, "RIGHT")
        card.enabledLabel:SetPoint("RIGHT", card.switch, "LEFT", -10, 0)
        card.enabledLabel:SetText(L["Enabled"])
        card.clear = PillButton(card, L["Clear notifications"], 170, function()
            if card.item then ext.Clear(card.item.e.id) end
        end)
        card.clear:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -16, 14)
        -- a package lives inside Island, so it can be edited and removed here (an addon cannot)
        card.edit = PillButton(card, L["Edit"], 80, function()
            if card.item and ns.Packages then ns.Packages.Open(card.item.e.id) end
        end)
        card.edit:SetPoint("RIGHT", card.clear, "LEFT", -8, 0)
        card.remove = PillButton(card, L["Remove"], 100, function()
            if not (card.item and ns.Packages) then return end
            if not card.removeArmed then
                card.removeArmed = true
                card.remove.text:SetText(L["Remove?"])
                return
            end
            card.removeArmed = false
            card.remove.text:SetText(L["Remove"])
            ns.Packages.Delete(card.item.e.id)
            state.open = nil
            ShowList()
        end)
        card.remove:SetPoint("RIGHT", card.edit, "LEFT", -8, 0)

        local tabs = {}
        local function PaintTabs()
            local a = ns.Accent()
            for key, t in pairs(tabs) do
                local on = state.tab == key
                t.text:SetTextColor(on and a[1] or C.muted[1], on and a[2] or C.muted[2], on and a[3] or C.muted[3])
                t.line:SetShown(on)
                t.line:SetColorTexture(a[1], a[2], a[3], 1)
            end
        end
        local function MakeTab(key, label)
            local t = CreateFrame("Button", nil, detail)
            t:SetHeight(28)
            t:SetWidth(40)
            t.text = ns.Text(t, "medium", 12.5, C.muted, "LEFT")
            t.text:SetPoint("LEFT", t, "LEFT", 2, 0)
            t.text:SetText(label)
            t.line = t:CreateTexture(nil, "ARTWORK")
            t.line:SetHeight(2)
            t.line:SetPoint("TOPLEFT", t.text, "BOTTOMLEFT", 0, -5)
            -- the button is exactly as wide as its label, so tabs never overlap
            local w = max(30, t.text:GetStringWidth() or 0)
            t.line:SetWidth(w)
            t:SetWidth(w + 6)
            t:SetScript("OnClick", function() state.tab = key state.armed = false ShowDetail() end)
            tabs[key] = t
        end
        MakeTab("overview", L["Overview"])
        MakeTab("features", L["Features"])
        MakeTab("settings", L["Settings"])
        MakeTab("permissions", L["Permissions"])
        -- the Features and Settings tabs only exist for an extension that declared some
        local function PlaceTabs(hasFeatures, hasSettings)
            tabs.features:SetShown(hasFeatures)
            tabs.settings:SetShown(hasSettings)
            local x = 0
            for _, key in ipairs({ "overview", "features", "settings", "permissions" }) do
                local t = tabs[key]
                if (key ~= "features" or hasFeatures) and (key ~= "settings" or hasSettings) then
                    local w = max(30, t.text:GetStringWidth() or 0)
                    t.line:SetWidth(w)
                    t:SetWidth(w + 6)
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", detail, "TOPLEFT", x, -168)
                    x = x + t:GetWidth() + 18
                end
            end
        end

        local panel = CreateFrame("Frame", nil, detail)
        panel:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -204)
        panel:SetSize(CW, 10)
        panel.body = ns.CreateBody(panel, "BACKGROUND", 0)
        panel.body:SetRadius(16)
        panel.body:SetColor(1, 1, 1, 0.045)
        local fields = {}
        for n = 1, 12 do
            local f = {}
            f.label = ns.Text(panel, "bold", 10, C.muted)
            f.value = ns.Text(panel, "medium", 12.5, C.fg)
            f.value:SetWordWrap(true)
            f.value:SetWidth(CW - GAP_X * 2)
            fields[n] = f
        end
        local website = CreateFrame("EditBox", nil, panel)
        website:SetSize(CW - GAP_X * 2, 26)
        website:SetAutoFocus(false)
        website.bg = ns.CreateControl(website, ns.Theme.UI.radius, "BACKGROUND", 0)
        website.bg:SetWidth(CW - GAP_X * 2)
        website.bg:SetColor(1, 1, 1, 0.08)
        ns.UseFont(website, "medium", 12)
        website:SetTextColor(C.fg[1], C.fg[2], C.fg[3])
        website:SetTextInsets(10, 10, 0, 0)
        website:SetMaxLetters(200)
        website:SetScript("OnTextChanged", function(self, user) if user then self:SetText(self.value or "") end end)
        website:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        website:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        website:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

        local featureRows = {}
        local detailItem, PaintDetail

        -- art and color picker for a card or bubble feature: a grid of glyphs and a row of colors
        local lookPop, lookCatcher
        local LOOK_COLS, LOOK_CELL, LOOK_GAP, LOOK_PAD = 8, 30, 4, 12
        local function CloseLook()
            if lookPop and lookPop:IsShown() then lookPop:Hide() end
        end
        local function ColorOf(colorId, colors)
            if colorId == "accent" then return ns.Accent() end
            for _, c in ipairs(colors) do
                if c.id == colorId and c.rgb then return c.rgb end
            end
            return C.fg
        end
        local function PaintLook()
            local pop = lookPop
            local l = pop and pop.ext and ext.Look(pop.ext, pop.fid)
            if not l then CloseLook() return end
            local a = ns.Accent()
            local tint = ColorOf(l.color, pop.colors)
            for _, cell in ipairs(pop.cells) do
                cell.icon:SetVertexColor(tint[1], tint[2], tint[3], 1)
                cell.hl:SetColor(a[1], a[2], a[3], cell.id == l.art and 0.30 or 0)
            end
            pop.orig.bg:SetColor(a[1], a[2], a[3], l.art == "original" and 0.35 or 0.10)
            local soundName = L["None"]
            for _, s in ipairs(ext.Sounds()) do if s.id == l.sound then soundName = s.name end end
            pop.sound.text:SetText(L["Sound: %s"]:format(soundName))
            pop.sound.bg:SetColor(a[1], a[2], a[3], l.sound ~= "none" and 0.35 or 0.10)
            pop.stay.bg:SetColor(a[1], a[2], a[3], l.stay and 0.35 or 0.10)
            pop.placePinned.bg:SetColor(a[1], a[2], a[3], l.place == "pinned" and 0.35 or 0.10)
            pop.placeBubble.bg:SetColor(a[1], a[2], a[3], l.place == "bubble" and 0.35 or 0.10)
            for _, sw in ipairs(pop.swatches) do
                sw.hl:SetColor(a[1], a[2], a[3], sw.id == l.color and 0.30 or 0)
                local c = ColorOf(sw.id, pop.colors)
                sw.dot:SetVertexColor(c[1], c[2], c[3], sw.id == "default" and 0.45 or 1)
            end
        end
        local function PickLook(art, color, place, stay, sound)
            local pop = lookPop
            if pop and pop.ext then ext.SetLook(pop.ext, pop.fid, art, color, place, stay, sound) end
            PaintLook()
            if PaintDetail then PaintDetail() end
        end
        local function Tip(frame, text)
            frame:SetScript("OnEnter", function(f)
                if GameTooltip then GameTooltip:SetOwner(f, "ANCHOR_TOP") GameTooltip:SetText(text, 1, 1, 1) GameTooltip:Show() end
            end)
            frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        end
        local function BuildLook()
            lookCatcher = CreateFrame("Button", nil, win)
            lookCatcher:SetAllPoints(UIParent)
            lookCatcher:SetFrameLevel(win:GetFrameLevel() + 40)
            lookCatcher:RegisterForClicks("AnyUp")
            lookCatcher:SetScript("OnClick", CloseLook)
            lookCatcher:Hide()
            local pop = CreateFrame("Frame", nil, win)
            lookPop = pop
            pop:SetFrameLevel(win:GetFrameLevel() + 41)
            pop:EnableMouse(true)
            pop:SetClampedToScreen(true)
            pop.body = ns.CreateBody(pop, "BACKGROUND", 0)
            pop.body:SetColor(0.10, 0.10, 0.12, 1)
            pop.body:SetRadius(14)
            local inner = LOOK_COLS * LOOK_CELL + (LOOK_COLS - 1) * LOOK_GAP
            local width = inner + 2 * LOOK_PAD
            pop.colors = ext.Colors()
            local y = LOOK_PAD
            local function Label(text)
                local t = ns.Text(pop, "bold", 10, C.muted)
                t:SetPoint("TOPLEFT", pop, "TOPLEFT", LOOK_PAD, -y)
                t:SetText(text)
                y = y + 16
            end
            Label(L["ART"])
            pop.orig = PillButton(pop, L["Extension's own icon"], inner, function() PickLook("original", nil) end)
            pop.orig:SetPoint("TOPLEFT", pop, "TOPLEFT", LOOK_PAD, -y)
            y = y + 36
            pop.cells = {}
            local arts = ext.Art()
            for i, art in ipairs(arts) do
                local cell = CreateFrame("Button", nil, pop)
                cell:SetSize(LOOK_CELL, LOOK_CELL)
                local col, row = (i - 1) % LOOK_COLS, floor((i - 1) / LOOK_COLS)
                cell:SetPoint("TOPLEFT", pop, "TOPLEFT", LOOK_PAD + col * (LOOK_CELL + LOOK_GAP), -(y + row * (LOOK_CELL + LOOK_GAP)))
                cell.hl = ns.CreateBody(cell, "BACKGROUND", 1)
                cell.hl:SetRadius(9)
                cell.hl:SetColor(1, 1, 1, 0)
                cell.icon = ns.Image(cell, art.id, "ARTWORK", 0)
                cell.icon:SetSize(18, 18)
                cell.icon:SetPoint("CENTER", cell, "CENTER", 0, 0)
                cell.id = art.id
                Tip(cell, art.name)
                cell:SetScript("OnClick", function() PickLook(art.id, nil) end)
                pop.cells[i] = cell
            end
            y = y + math.ceil(#arts / LOOK_COLS) * (LOOK_CELL + LOOK_GAP) + 4
            Label(L["COLOR"])
            pop.swatches = {}
            for i, c in ipairs(pop.colors) do
                local sw = CreateFrame("Button", nil, pop)
                sw:SetSize(LOOK_CELL, LOOK_CELL)
                local col, row = (i - 1) % LOOK_COLS, floor((i - 1) / LOOK_COLS)
                sw:SetPoint("TOPLEFT", pop, "TOPLEFT", LOOK_PAD + col * (LOOK_CELL + LOOK_GAP), -(y + row * (LOOK_CELL + LOOK_GAP)))
                sw.hl = ns.CreateBody(sw, "BACKGROUND", 1)
                sw.hl:SetRadius(9)
                sw.hl:SetColor(1, 1, 1, 0)
                sw.dot = ns.Image(sw, "Circle", "ARTWORK", 0)
                sw.dot:SetSize(18, 18)
                sw.dot:SetPoint("CENTER", sw, "CENTER", 0, 0)
                sw.id = c.id
                Tip(sw, c.name)
                sw:SetScript("OnClick", function() PickLook(nil, c.id) end)
                pop.swatches[i] = sw
            end
            y = y + math.ceil(#pop.colors / LOOK_COLS) * (LOOK_CELL + LOOK_GAP) + 4 - LOOK_GAP
            -- a sound when a new card or bubble of this feature arrives: each press moves to the next and plays it
            Label(L["SOUND"])
            pop.sound = PillButton(pop, "", inner, function()
                local l = lookPop and lookPop.ext and ext.Look(lookPop.ext, lookPop.fid)
                if not l then return end
                local list, nextId = ext.Sounds(), nil
                for i, s in ipairs(list) do if s.id == l.sound then nextId = (list[i + 1] or list[1]).id end end
                nextId = nextId or list[1].id
                PickLook(nil, nil, nil, nil, nextId)
                if nextId ~= "none" and ns.PreviewSound then ns.PreviewSound(nextId) end
            end)
            pop.sound:SetPoint("TOPLEFT", pop, "TOPLEFT", LOOK_PAD, -y)
            y = y + 36
            -- bubbles only: where a persistent bubble sits
            pop.baseH = y + LOOK_PAD
            pop.stayLabel = ns.Text(pop, "bold", 10, C.muted)
            pop.stayLabel:SetPoint("TOPLEFT", pop, "TOPLEFT", LOOK_PAD, -y)
            pop.stayLabel:SetText(L["BUBBLE"])
            y = y + 16
            pop.stay = PillButton(pop, L["Keep it up until it is removed"], inner, function()
                local l = lookPop and lookPop.ext and ext.Look(lookPop.ext, lookPop.fid)
                if l then PickLook(nil, nil, nil, not l.stay) end
            end)
            pop.stay:SetPoint("TOPLEFT", pop, "TOPLEFT", LOOK_PAD, -y)
            y = y + 40
            pop.placeLabel = ns.Text(pop, "bold", 10, C.muted)
            pop.placeLabel:SetPoint("TOPLEFT", pop, "TOPLEFT", LOOK_PAD, -y)
            pop.placeLabel:SetText(L["KEPT-UP BUBBLES SHOW"])
            y = y + 16
            local half = floor((inner - 8) / 2)
            pop.placePinned = PillButton(pop, L["Pinned"], half, function() PickLook(nil, nil, "pinned") end)
            pop.placePinned:SetPoint("TOPLEFT", pop, "TOPLEFT", LOOK_PAD, -y)
            pop.placeBubble = PillButton(pop, L["With other bubbles"], half, function() PickLook(nil, nil, "bubble") end)
            pop.placeBubble:SetPoint("TOPLEFT", pop, "TOPLEFT", LOOK_PAD + half + 8, -y)
            y = y + 34
            pop.placeH = y + LOOK_PAD - pop.baseH
            pop:SetSize(width, pop.baseH)
            pop:SetScript("OnShow", function() lookCatcher:Show() end)
            pop:SetScript("OnHide", function() lookCatcher:Hide() pop.owner = nil end)
            win:HookScript("OnHide", CloseLook)
            pop:Hide()
        end
        local function OpenLook(owner, id, fid)
            if not lookPop then BuildLook() end
            if lookPop:IsShown() and lookPop.owner == owner then CloseLook() return end
            CloseMenu()
            lookPop.owner, lookPop.ext, lookPop.fid = owner, id, fid
            local l = ext.Look(id, fid)
            local isBubble = l and l.kind == "bubble"
            lookPop.stayLabel:SetShown(isBubble)
            lookPop.stay:SetShown(isBubble)
            lookPop.placeLabel:SetShown(isBubble)
            lookPop.placePinned:SetShown(isBubble)
            lookPop.placeBubble:SetShown(isBubble)
            lookPop:SetHeight(lookPop.baseH + (isBubble and lookPop.placeH or 0))
            PaintLook()
            lookPop:ClearAllPoints()
            local h = lookPop:GetHeight()
            local below = owner:GetBottom() and win:GetBottom() and (owner:GetBottom() - h - 4 < win:GetBottom() + 8)
            if below then
                lookPop:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 4)
            else
                lookPop:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
            end
            lookPop:Show()
        end

        -- one row per declared feature: kind tag, name, description, switch and a look
        for n = 1, 8 do
            local f = {}
            f.kind = ns.Text(panel, "bold", 10, C.muted)
            f.name = ns.Text(panel, "bold", 13, C.fg)
            f.name:SetWidth(CW - GAP_X * 2 - 60)
            f.desc = ns.Text(panel, "medium", 11.5, C.muted)
            f.desc:SetWordWrap(true)
            f.desc:SetWidth(CW - GAP_X * 2 - 60)
            f.switch = Switch(panel, function() return f.feature and f.feature.enabled end, function(v)
                if f.feature and detailItem then ext.SetFeature(detailItem.e.id, f.feature.id, v) PaintDetail() end
            end)
            f.preview = CreateFrame("Frame", nil, panel)
            f.preview:SetSize(28, 28)
            f.preview.body = ns.CreateBody(f.preview, "BACKGROUND", 0)
            f.preview.body:SetRadius(14)
            f.preview.body:SetColor(0, 0, 0, 1)
            f.preview.icon = ns.Image(f.preview, "Bell", "ARTWORK", 0)
            f.preview.icon:SetSize(16, 16)
            f.preview.icon:SetPoint("CENTER", f.preview, "CENTER", 0, 0)
            f.look = Droppable(PillButton(panel, "", 200, function()
                if f.feature and detailItem then OpenLook(f.look, detailItem.e.id, f.feature.id) end
            end))
            featureRows[n] = f
        end

        -- one row per declared setting: name, description and a control (switch, slider or choice pill)
        local function ExtSlider()
            local SW = 120
            local sl = CreateFrame("Frame", nil, panel)
            sl:SetSize(SW, 18)
            sl:EnableMouse(true)
            sl.track = ns.CreatePill(sl, 4, "ARTWORK", 0)
            sl.track:SetColor(1, 1, 1, 0.13)
            sl.track:SetWidth(SW)
            sl.fill = ns.CreatePill(sl, 4, "ARTWORK", 1)
            sl.knob = ns.Image(sl, "Circle", "ARTWORK", 2)
            sl.knob:SetSize(14, 14)
            sl.label = ns.Text(panel, "bold", 12, C.muted, "RIGHT")
            sl.label:SetPoint("RIGHT", sl, "LEFT", -10, 0)
            function sl.Paint()
                local d = sl.d
                if not d then return end
                local f = clamp((sl.value - d.min) / (d.max - d.min), 0, 1)
                local x = f * (SW - 14)
                local col = ns.Accent()
                sl.knob:ClearAllPoints()
                sl.knob:SetPoint("LEFT", sl, "LEFT", x, 0)
                sl.fill:SetColor(col[1], col[2], col[3], 1)
                sl.fill:SetWidth(max(4, x + 7))
                sl.label:SetText(string.format("%g", sl.value))
            end
            local function drag()
                local d = sl.d
                if not d then return end
                local x = GetCursorPosition() / sl:GetEffectiveScale()
                local f = clamp((x - (sl:GetLeft() or 0) - 7) / (SW - 14), 0, 1)
                local v = d.min + f * (d.max - d.min)
                v = d.min + floor((v - d.min) / d.step + 0.5) * d.step
                v = tonumber(string.format("%.6g", clamp(v, d.min, d.max)))
                if v ~= sl.value then
                    sl.value = v
                    if sl.onChange then sl.onChange(v) end
                    sl.Paint()
                end
            end
            sl:SetScript("OnMouseDown", function() sl:SetScript("OnUpdate", drag) end)
            sl:SetScript("OnMouseUp", function() sl:SetScript("OnUpdate", nil) end)
            sl:SetScript("OnHide", function() sl:SetScript("OnUpdate", nil) end)
            return sl
        end
        local settingRows = {}
        for n = 1, 12 do
            local r = {}
            r.name = ns.Text(panel, "bold", 13, C.fg)
            r.name:SetWidth(CW - GAP_X * 2 - 210)
            r.desc = ns.Text(panel, "medium", 11.5, C.muted)
            r.desc:SetWordWrap(true)
            r.desc:SetWidth(CW - GAP_X * 2 - 210)
            r.switch = Switch(panel, function() return r.d and r.d.value == true end, function(v)
                if r.d and detailItem then ext.SetSetting(detailItem.e.id, r.d.key, v) r.d.value = v end
            end)
            r.slider = ExtSlider()
            r.slider.onChange = function(v)
                if r.d and detailItem then ext.SetSetting(detailItem.e.id, r.d.key, v) r.d.value = v end
            end
            r.pill = Droppable(PillButton(panel, "", 150, function()
                local d = r.d
                if not d or not detailItem then return end
                local ids, names = {}, {}
                for i, c in ipairs(d.choices) do ids[i] = c.id names[c.id] = c.name end
                OpenMenu(r.pill, ids, function(v) return names[v] end, d.value, function(v)
                    if ext.SetSetting(detailItem.e.id, d.key, v) then d.value = v end
                    r.pill.text:SetText(names[d.value] or "")
                    FitPill(r.pill, 150)
                end)
            end))
            settingRows[n] = r
        end
        -- footer on the Features and Settings tabs: which profile holds these choices, and a reset
        local foot = {}
        foot.text = ns.Text(panel, "medium", 11.5, C.muted)
        foot.text:SetWidth(CW - GAP_X * 2)
        foot.text:SetWordWrap(true)
        foot.link = PillButton(panel, L["Open Profiles"], 150, function() Select(27, true) end)
        foot.reset = PillButton(panel, L["Reset to defaults"], 190, function()
            if not detailItem then return end
            if not state.armed then
                state.armed = true
                PaintDetail()
                return
            end
            state.armed = false
            ext.ResetDefaults(detailItem.e.id)
            CloseLook()
            RefreshAll()
        end)

        local function SetPage(h)
            pg.fullHeight = h
            Reflow(pg)
        end
        local function Fill(item)
            local e, i = item.e, item.info
            local rowsOut = {}
            local declared = ext.Features(e.id)
            for _, fr in ipairs(featureRows) do
                fr.kind:Hide() fr.name:Hide() fr.desc:Hide() fr.switch:Hide() fr.preview:Hide() fr.look:Hide()
            end
            for _, sr in ipairs(settingRows) do
                sr.name:Hide() sr.desc:Hide() sr.switch:Hide() sr.slider:Hide() sr.slider.label:Hide() sr.pill:Hide()
            end
            foot.text:Hide() foot.link:Hide() foot.reset:Hide()
            local function Footer(yy)
                foot.text:ClearAllPoints()
                foot.text:SetPoint("TOPLEFT", panel, "TOPLEFT", GAP_X, -yy)
                foot.text:SetText(string.format(L["These choices are saved in the profile %s."], ns.Profiles and ns.Profiles.Active() or "Default"))
                foot.text:Show()
                yy = yy + max(15, foot.text:GetStringHeight() or 15) + 10
                foot.link:ClearAllPoints()
                foot.link:SetPoint("TOPLEFT", panel, "TOPLEFT", GAP_X, -yy)
                foot.link:Show()
                foot.reset.text:SetText(state.armed and L["Click again to reset"] or L["Reset to defaults"])
                foot.reset:ClearAllPoints()
                foot.reset:SetPoint("LEFT", foot.link, "RIGHT", 10, 0)
                foot.reset:Show()
                return yy + 30 + 14
            end
            if state.tab == "settings" then
                local list = ext.Settings(e.id)
                local yy = 14
                for n, sr in ipairs(settingRows) do
                    local d = list[n]
                    if d then
                        sr.d = d
                        sr.name:ClearAllPoints()
                        sr.name:SetPoint("TOPLEFT", panel, "TOPLEFT", GAP_X, -yy)
                        sr.name:SetText(d.name)
                        sr.name:Show()
                        local used = 20
                        if d.description ~= "" then
                            sr.desc:ClearAllPoints()
                            sr.desc:SetPoint("TOPLEFT", panel, "TOPLEFT", GAP_X, -yy - used)
                            sr.desc:SetText(d.description)
                            sr.desc:Show()
                            used = used + max(14, sr.desc:GetStringHeight() or 14) + 2
                        end
                        if d.type == "toggle" then
                            if not sr.switch:GetScript("OnUpdate") then sr.switch.Sync() end
                            sr.switch:ClearAllPoints()
                            sr.switch:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -GAP_X, -yy)
                            sr.switch:Show()
                        elseif d.type == "slider" then
                            sr.slider.d = d
                            sr.slider.value = d.value
                            sr.slider:ClearAllPoints()
                            sr.slider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -GAP_X, -yy - 1)
                            sr.slider.Paint()
                            sr.slider:Show()
                            sr.slider.label:Show()
                        else
                            local names = {}
                            for _, c in ipairs(d.choices) do names[c.id] = c.name end
                            sr.pill.text:SetText(names[d.value] or "")
                            FitPill(sr.pill, 150)
                            sr.pill:ClearAllPoints()
                            sr.pill:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -GAP_X, -yy + 4)
                            sr.pill:Show()
                            used = max(used, 34)
                        end
                        yy = yy + used + 14
                    else
                        sr.d = nil
                    end
                end
                for _, f in ipairs(fields) do f.label:Hide() f.value:Hide() end
                website:Hide()
                yy = Footer(yy)
                panel:SetHeight(yy + 2)
                return yy
            end
            if state.tab == "features" then
                local yy = 14
                for n, fr in ipairs(featureRows) do
                    local d = declared[n]
                    if d then
                        fr.feature = d
                        fr.kind:ClearAllPoints()
                        fr.kind:SetPoint("TOPLEFT", panel, "TOPLEFT", GAP_X, -yy)
                        fr.kind:SetText(d.kind == "bubble" and L["BUBBLE"] or L["CARD"])
                        fr.kind:Show()
                        fr.name:ClearAllPoints()
                        fr.name:SetPoint("TOPLEFT", panel, "TOPLEFT", GAP_X, -yy - 15)
                        fr.name:SetText(d.name)
                        fr.name:Show()
                        local used = 15 + 18
                        if d.description ~= "" then
                            fr.desc:ClearAllPoints()
                            fr.desc:SetPoint("TOPLEFT", panel, "TOPLEFT", GAP_X, -yy - used)
                            fr.desc:SetText(d.description)
                            fr.desc:Show()
                            used = used + max(14, fr.desc:GetStringHeight() or 14) + 2
                        end
                        local look = ext.Look(e.id, d.id)
                        if look then
                            local arts, colors = ext.Art(), ext.Colors()
                            local artName, colorName = L["Extension's own icon"], ""
                            for _, a in ipairs(arts) do if a.id == look.art then artName = a.name end end
                            for _, c in ipairs(colors) do if c.id == look.color then colorName = c.name end end
                            fr.look.text:SetText(artName .. ", " .. colorName)
                            FitPill(fr.look, 200)
                            local tint = look.color == "accent" and ns.Accent() or C.muted
                            if look.color ~= "accent" and look.color ~= "default" then
                                for _, c in ipairs(colors) do if c.id == look.color and c.rgb then tint = c.rgb end end
                            elseif look.color == "default" and look.art ~= "original" then
                                tint = C.fg
                            end
                            fr.preview.icon:SetTexture("Interface\\AddOns\\BanzaiSland\\Media\\" .. (look.art == "original" and "Bell" or look.art))
                            fr.preview.icon:SetVertexColor(tint[1], tint[2], tint[3], 1)
                            fr.preview:ClearAllPoints()
                            fr.preview:SetPoint("TOPLEFT", panel, "TOPLEFT", GAP_X, -yy - used + 2)
                            fr.preview:Show()
                            fr.look:ClearAllPoints()
                            fr.look:SetPoint("LEFT", fr.preview, "RIGHT", 10, 0)
                            fr.look:Show()
                            used = used + 36
                        end
                        if not fr.switch:GetScript("OnUpdate") then fr.switch.Sync() end
                        fr.switch:ClearAllPoints()
                        fr.switch:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -GAP_X, -yy - 14)
                        fr.switch:Show()
                        yy = yy + used + 14
                    end
                end
                for _, f in ipairs(fields) do f.label:Hide() f.value:Hide() end
                website:Hide()
                yy = Footer(yy)
                panel:SetHeight(yy + 2)
                return yy
            end
            if state.tab == "overview" then
                rowsOut[#rowsOut + 1] = { L["DESCRIPTION"], i.notes or L["This extension did not provide a description."] }
                if i.author then rowsOut[#rowsOut + 1] = { L["AUTHOR"], i.author } end
                rowsOut[#rowsOut + 1] = { L["VERSION"], i.version or L["Not listed"] }
                if i.category then rowsOut[#rowsOut + 1] = { L["CATEGORY"], i.category } end
                rowsOut[#rowsOut + 1] = { L["SHOWS ON"], AUDIENCE[e.audience] or e.audience }
                rowsOut[#rowsOut + 1] = { L["FEATURES"], #declared == 0 and L["None declared"] or string.format(L["%d, see the Features tab"], #declared) }
                local nset = #ext.Settings(e.id)
                rowsOut[#rowsOut + 1] = { L["SETTINGS"], nset == 0 and L["None declared"] or string.format(L["%d, see the Settings tab"], nset) }
                rowsOut[#rowsOut + 1] = { L["EXTENSION ID"], e.id }
                rowsOut[#rowsOut + 1] = { L["ACTIVITY"], string.format(L["%d shown, %d refused, %d rate limited"], e.accepted, e.rejected, e.rateLimited) }
                if e.lastReason then rowsOut[#rowsOut + 1] = { L["LAST PROBLEM"], REASON[e.lastReason] or L["Unknown"] } end
                if i.website then rowsOut[#rowsOut + 1] = { L["WEBSITE"], false } end
            else
                rowsOut[#rowsOut + 1] = { L["CAN"], L["Show cards and bubbles in the Loot, Social, Alerts and World groups, following your card settings and Do Not Disturb."] }
                rowsOut[#rowsOut + 1] = { L["CANNOT"], L["Add buttons, play sounds, answer game prompts, run game actions or open frames."] }
                rowsOut[#rowsOut + 1] = { L["LIMITS"], L["Three cards in a burst and one every two seconds, up to five cards and two bubbles at a time."] }
                if e.id:sub(1, 4) == "Pkg_" and ns.Packages then
                    rowsOut[#rowsOut + 1] = { L["NOTE"], L["Installed from a package. Edit opens it in the package creator; Remove deletes it."] }
                else
                    rowsOut[#rowsOut + 1] = { L["REMOVING"], L["This extension is an addon. BanzaiSland cannot uninstall it: switch it off here, or delete its folder from the AddOns folder."] }
                end
            end
            local yy = 14
            website:Hide()
            for n, f in ipairs(fields) do
                local r = rowsOut[n]
                if r then
                    f.label:ClearAllPoints()
                    f.label:SetPoint("TOPLEFT", panel, "TOPLEFT", GAP_X, -yy)
                    f.label:SetText(r[1])
                    f.label:Show()
                    yy = yy + 15
                    if r[2] then
                        f.value:ClearAllPoints()
                        f.value:SetPoint("TOPLEFT", panel, "TOPLEFT", GAP_X, -yy)
                        f.value:SetText(r[2])
                        f.value:Show()
                        yy = yy + max(15, f.value:GetStringHeight() or 15) + 12
                    else
                        f.value:Hide()
                        website:ClearAllPoints()
                        website:SetPoint("TOPLEFT", panel, "TOPLEFT", GAP_X, -yy)
                        website.value = i.website
                        website:SetText(i.website)
                        website:Show()
                        yy = yy + 26 + 12
                    end
                else
                    f.label:Hide()
                    f.value:Hide()
                end
            end
            panel:SetHeight(yy + 2)
            return yy
        end
        PaintDetail = function()
            local items = ext.List()
            local item
            for _, e in ipairs(items) do
                if e.id == state.open then item = { e = e, info = Info(e.id), status = StatusOf(e) } end
            end
            if not item then state.open = nil ShowList() return end
            local rebound = not card.item or card.item.e.id ~= item.e.id
            card.item = item
            local isPackage = ns.Packages ~= nil and item.e.id:sub(1, 4) == "Pkg_"
            card.edit:SetShown(isPackage)
            card.remove:SetShown(isPackage)
            if rebound then card.removeArmed = false card.remove.text:SetText(L["Remove"]) end
            detailItem = item
            -- a different extension, or a state changed elsewhere: make the knob match
            local want = item.e.enabled and 1 or 0
            if rebound or (card.switch.pos ~= want and not card.switch:GetScript("OnUpdate")) then card.switch.Sync() end
            local hasFeatures = #ext.Features(item.e.id) > 0
            local hasSettings = #ext.Settings(item.e.id) > 0
            if (state.tab == "features" and not hasFeatures) or (state.tab == "settings" and not hasSettings) then state.tab = "overview" end
            PlaceTabs(hasFeatures, hasSettings)
            local e, i = item.e, item.info
            card.name:SetText(e.name)
            local bits = {}
            if i.version then bits[#bits + 1] = i.version end
            if i.author then bits[#bits + 1] = i.author end
            card.meta:SetText(#bits > 0 and table.concat(bits, "  ·  ") or e.id)
            card.status:SetText(STATUS[item.status])
            local color = StatusColor(item.status)
            card.status:SetTextColor(color[1], color[2], color[3])
            PaintExtIcon(card.tex, card.fallback, e.id, i.icon)
            PaintTabs()
            local used = Fill(item)
            SetPage(70 + 204 + used + 40)
        end

        local function PaintList()
            local items, all, attention = Collect()
            local total = #all
            local text = total == 1 and L["1 extension"] or string.format(L["%d extensions"], total)
            if attention > 0 then
                text = text .. ", " .. (attention == 1 and L["1 needs attention"] or string.format(L["%d need attention"], attention))
            end
            count:SetText(text)
            for n = 1, max(#items, #rows) do
                local row = rows[n] or (items[n] and MakeRow(n))
                if row then
                    if items[n] then
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, LIST_TOP - (n - 1) * (ROWH + ROWGAP))
                        Bind(row, items[n])
                        row:Show()
                    else
                        row.item = nil
                        row:Hide()
                    end
                end
            end
            local bottom = LIST_TOP - #items * (ROWH + ROWGAP)
            if #items == 0 then
                empty:SetText(total == 0 and L["No extensions registered. Optional addons can send cards and bubbles through BanzaiSland. Extensions follow your card visibility settings and cannot answer game prompts."]
                    or L["No extensions match."])
                empty:Show()
                bottom = LIST_TOP - 70
            else
                empty:Hide()
            end
            local probs = Problems()
            local shown = math.min(#probs, 12)
            probHead:SetShown(shown > 0)
            if shown > 0 then
                probHead:ClearAllPoints()
                probHead:SetPoint("TOPLEFT", list, "TOPLEFT", GAP_X, bottom - 14)
                bottom = bottom - 14 - 22
            end
            for n = 1, math.max(shown, #probRows) do
                local r = probRows[n] or (n <= shown and MakeProblem(n))
                if r then
                    if n <= shown then
                        r:ClearAllPoints()
                        r:SetPoint("TOPLEFT", list, "TOPLEFT", 0, bottom)
                        r.name:SetText(probs[n].name)
                        r.note:SetText(probs[n].note)
                        r:Show()
                        bottom = bottom - 52
                    else
                        r:Hide()
                    end
                end
            end
            if pkgButton then
                pkgButton:ClearAllPoints()
                pkgButton:SetPoint("TOPLEFT", list, "TOPLEFT", 0, bottom - 10)
                importButton:ClearAllPoints()
                importButton:SetPoint("TOPLEFT", list, "TOPLEFT", 210, bottom - 10)
                bottom = bottom - 10 - 40
            end
            docsLine:ClearAllPoints()
            docsLine:SetPoint("TOPLEFT", list, "TOPLEFT", GAP_X, bottom - 4)
            bottom = bottom - 4 - 32
            SetPage(-bottom + 24)
        end

        ShowList = function()
            state.armed = false
            detail:Hide()
            list:Show()
            PaintList()
        end
        ShowDetail = function()
            list:Hide()
            detail:Show()
            PaintDetail()
        end

        -- the sidebar count of extensions that need attention
        local badge
        if navs[26] then
            badge = ns.Text(navs[26], "bold", 9.5, AMBER, "RIGHT")
            badge:SetPoint("RIGHT", navs[26], "RIGHT", -10, 0)
        end
        local lastCount
        local function PaintBadge(attention)
            if badge and attention ~= lastCount then
                lastCount = attention
                badge:SetText(attention > 0 and tostring(attention) or "")
            end
        end
        Refresh = function()
            local _, _, attention = Collect()
            PaintBadge(attention)
            if not pg:IsShown() then return end
            if state.open then PaintDetail() else PaintList() end
        end
        refreshers[#refreshers + 1] = Refresh
        pg:SetScript("OnShow", function() Refresh() end)
        -- statuses change while the window is open (rejections, readiness): look again each second
        local tick, waited = CreateFrame("Frame", nil, win), 0
        tick:SetScript("OnUpdate", function(_, dt)
            waited = waited + dt
            if waited < 1 then return end
            waited = 0
            if win:IsShown() and not (searchBox.HasFocus and searchBox:HasFocus()) then Refresh() end
        end)
        win:HookScript("OnShow", function() Refresh() end)

        searchIndex[#searchIndex + 1] = { label = L["Search extensions"], page = pg, group = searchBox, offset = 0,
            text = hint, keywords = "extension extensions addon api", context = L["Extensions"] }
        detail:Hide()
        list:Show()
        pg.fullHeight = 400
        y = -400
        PaintList()
    end
    end

    -- Supported addons (page 28): the addons Island works with, and their options. Only the ones that
    -- are installed show; nothing here appears for an addon you do not have.
    Page(28)
    do
        local function Has(name)
            local f = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
            if not f then return false end
            local ok, v = pcall(f, name)
            return ok and v and true or false
        end
        local names, shown = {}, {}
        local function Want(id, label)
            if Has(id) then names[#names + 1] = label shown[id] = true end
        end
        Want("RXPGuides", "RestedXP Guides")
        Want("Polestar", "Polestar")
        Want("TomTom", "TomTom")
        Want("Spoken", "Spoken")
        Want("Pigeon", "Pigeon")
        Want("RareScanner", "RareScanner")
        Want("ItemTree", "ItemTree")
        Want("Lootified", "Lootified")
        Want("Pawn", "Pawn")
        if #names == 0 then
            Note(L["No supported addons found. BanzaiSland works with RestedXP Guides, Polestar, TomTom, Spoken, Pigeon, RareScanner, ItemTree, Lootified and Pawn."])
        else
            Note(L["Found: %s"]:format(table.concat(names, ", ")))
        end
        if shown.RXPGuides then
            Section(L["RESTEDXP GUIDES"])
            local rxpApply = function() if ns.RXP then ns.RXP:Apply() end end
            Toggle(L["Navigation bubble follows RestedXP Guides"], "navRXP", function() if ns.Nav then ns.Nav:CheckRXP() ns.Nav:ApplyRXPArrow() end end)
            Toggle(L["Hide RestedXP Guides' own arrow"], "navHideRXP", function() if ns.Nav then ns.Nav:ApplyRXPArrow() end end)
            Toggle(L["Step list as tiles with icons"], "navTiles", function() local R = ns.RXP or (ns.Nav and ns.Nav.RXP) if R and R.RefreshDrawer then R:RefreshDrawer() end end)
            Toggle(L["Card when a guide step starts"], "rxpStepCards")
            Toggle(L["Bubble with the current guide step"], "rxpStepBubble", rxpApply)
            Toggle(L["Guide progress bar on that bubble"], "rxpStepBubbleBar", rxpApply)
            Toggle(L["Short bubble when a step is done"], "rxpDoneBubble")
            Toggle(L["Hide RestedXP's own guide window (use the step bubble's panel)"], "rxpHideWindow", rxpApply)
        end
        if shown.Polestar then
            Section(L["POLESTAR"])
            local psApply = function() if ns.PS then ns.PS:Apply() end end
            Toggle(L["Navigation bubble follows Polestar"], "navPolestar", function() if ns.Nav then ns.Nav:CheckRXP() ns.Nav:ApplyRXPArrow() end end)
            Toggle(L["Hide Polestar's own arrow"], "navHidePolestar", function() if ns.Nav then ns.Nav:ApplyRXPArrow() end end)
            Toggle(L["Step list as tiles with icons"], "navTiles", function() local R = ns.RXP if R and R.RefreshDrawer then R:RefreshDrawer() end end)
            Toggle(L["Card when a guide step starts"], "polestarStepCards")
            Toggle(L["Bubble with the current guide step"], "polestarStepBubble", psApply)
            Toggle(L["Guide progress bar on that bubble"], "polestarStepBubbleBar", psApply)
            Toggle(L["Hide Polestar's own guide window (use the step bubble's panel)"], "polestarHideWindow", psApply)
        end
        if shown.TomTom then
            Section(L["TOMTOM"])
            Toggle(L["Navigation bubble follows TomTom"], "navTomTom", function() if ns.Nav then ns.Nav:ApplyTomTomArrow() end end)
            Toggle(L["Hide TomTom's own arrow"], "navHideTomTom", function() if ns.Nav then ns.Nav:ApplyTomTomArrow() end end)
        end
        if shown.Spoken then
            Section(L["SPOKEN"])
            Toggle(L["Spoken voiceovers (needs Spoken)"], "spokenCard", function() if ns.Voice then ns.Voice:ApplyHide() end end)
            Toggle(L["Small news in a strip during voiceovers"], "spokenTicker")
            Toggle(L["Hide Spoken's own window"], "spokenHide", function() if ns.Voice then ns.Voice:ApplyHide() end end)
        end
        if shown.Pigeon then
            Section(L["PIGEON"])
            Toggle(L["Whispers open in Pigeon (needs Pigeon)"], "usePigeon", function() ns.ApplyPigeon() end)
            Toggle(L["Hold cards while typing in Pigeon"], "holdWhileTyping")
        end
        if shown.RareScanner then
            Section(L["RARESCANNER"])
            Toggle(L["RareScanner finds (needs RareScanner)"], "useRareScanner")
        end
        if shown.ItemTree or shown.Lootified or shown.Pawn then
            Section(L["UPGRADE CHECKERS"])
            if shown.ItemTree then Toggle(L["Use ItemTree for upgrades (needs ItemTree)"], "itemTreeUpgrades", RefreshAll) end
            if shown.Lootified then Toggle(L["Use Lootified for upgrades (needs Lootified)"], "lootifiedUpgrades", RefreshAll) end
            if shown.Pawn then Toggle(L["Use Pawn for upgrades (needs Pawn)"], "pawnUpgrades", RefreshAll) end
            Note(L["Upgrade cards need an available evaluator enabled here. ItemTree is checked first, then Lootified and Pawn. ItemTree may report upgrades for any enabled specialization; item-level-only results are ignored."])
        end
    end

    Page(27)
    do
        local PR = ns.Profiles
        local names, others, deletable = {}, {}, {}
        local state = { copy = nil, remove = nil, pending = nil }
        local nameBox
        local function shown(name) return name == PR.DEFAULT and L["Default"] or name end
        local function describe(name)
            if not name or name == "" then return L["None"] end
            return shown(name)
        end
        local function sync()
            for i = #names, 1, -1 do names[i] = nil end
            for i = #others, 1, -1 do others[i] = nil end
            for i = #deletable, 1, -1 do deletable[i] = nil end
            for _, n in ipairs(PR.List()) do
                names[#names + 1] = n
                if n ~= PR.Active() then others[#others + 1] = n end
                if n ~= PR.DEFAULT and n ~= PR.Active() then deletable[#deletable + 1] = n end
            end
            if not (state.copy and PR.Get(state.copy)) or state.copy == PR.Active() then state.copy = others[1] end
            if not (state.remove and PR.Get(state.remove)) or state.remove == PR.Active() then state.remove = deletable[1] end
        end
        refreshers[#refreshers + 1] = sync
        sync()
        local function ProfilePill(values, get, onPick)
            local button
            local function paint()
                local v = get()
                button.text:SetText(v and v ~= "" and shown(v) or L["None"])
                FitPill(button, 170)
            end
            button = Droppable(PillButton(page, "", 170, function()
                if #values == 0 then return end
                OpenMenu(button, values, describe, get(), function(v) onPick(v) paint() end)
            end))
            refreshers[#refreshers + 1] = paint
            paint()
            return button
        end
        local function Say(text) ns.Print(text) end
        local function Done(name, why)
            if name then return true end
            if why == "exists" then Say(L["A profile with that name already exists."])
            elseif why == "active" then Say(L["Switch to another profile first."])
            else Say(L["Type a name of up to 24 characters."]) end
        end
        -- risky buttons ask for a second click within a few seconds
        local function Confirm(key, text, fn)
            if state.pending == key then state.pending = nil fn() return end
            state.pending = key
            Say(text)
            if C_Timer and C_Timer.After then C_Timer.After(6, function() if state.pending == key then state.pending = nil end end) end
        end
        local function typed() return nameBox and nameBox:GetText() or "" end
        -- an empty name box makes a profile called "New Profile" (then "New Profile 2", ...)
        local function chosen()
            local t = typed():gsub("^%s+", ""):gsub("%s+$", "")
            if t == "" then return PR.Unique(L["New Profile"]) end
            return t
        end

        Section(L["IN USE"])
        -- the profile list, and a Reload button that shows only while a different profile is waiting
        local box = CreateFrame("Frame", nil, page)
        box:SetSize(170 + 8 + 90, 30)
        local pick = ProfilePill(names, function() return PR.Chosen() end, function(v)
            if v ~= PR.Chosen() then PR.Use(v) RefreshAll() end
        end)
        pick:SetParent(box)
        pick:ClearAllPoints()
        pick:SetPoint("RIGHT", box, "RIGHT", 0, 0)
        local reload = PillButton(box, L["Reload"], 90, function() PR.Reload() end)
        reload:SetPoint("RIGHT", pick, "LEFT", -8, 0)
        refreshers[#refreshers + 1] = function() reload:SetShown(PR.Chosen() ~= PR.Active()) end
        reload:SetShown(PR.Chosen() ~= PR.Active())
        Row(L["Profile for this character"])(box)
        Note(L["A profile holds every setting on these pages, the island's place on screen and your extension choices. Changing profile reloads the interface. Learned data such as flight times and dungeon history is shared by every profile."])
        Row(L["Character Profile"])(Switch(page, function() return PR.IsOwn() end, function(v)
            PR.SetOwn(v)
            RefreshAll()
        end))
        Note(L["On gives this character a profile of its own, copied from the one in use. Off goes back to Default and keeps it for later."])

        Section(L["CREATE AND RENAME"])
        nameBox = CreateFrame("EditBox", nil, page)
        nameBox:SetSize(170, 26)
        nameBox:SetAutoFocus(false)
        nameBox.bg = ns.CreateControl(nameBox, ns.Theme.UI.radius, "BACKGROUND", 0)
        nameBox.bg:SetColor(1, 1, 1, 0.08)
        ns.UseFont(nameBox, "bold", 12.5)
        nameBox:SetTextColor(C.fg[1], C.fg[2], C.fg[3])
        nameBox:SetJustifyH("CENTER")
        nameBox:SetTextInsets(6, 6, 0, 0)
        nameBox:SetMaxLetters(24)
        nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        nameBox:SetScript("OnEditFocusGained", function(self) self.bg:SetColor(1, 1, 1, 0.16) end)
        nameBox:SetScript("OnEditFocusLost", function(self) self.bg:SetColor(1, 1, 1, 0.08) end)
        Row(L["Name"])(nameBox)
        local function Made(name)
            if not Done(name) then return end
            nameBox:SetText("")
            Say(string.format(L["Profile %s created."], name))
            RefreshAll()
        end
        Buttons(L["New with default settings"], function() Made(PR.CreateDefaults(chosen())) end,
            L["New profile with current settings"], function() Made(PR.Create(chosen())) end)
        Buttons(L["Rename this profile"], function()
            if PR.Active() == PR.DEFAULT then Say(L["The Default profile cannot be renamed."]) return end
            local name, why = PR.Rename(PR.Active(), typed())
            if not Done(name, why) then return end
            nameBox:SetText("")
            RefreshAll()
        end)

        Section(L["COPY, RESET AND DELETE"])
        Row(L["Copy settings from"])(ProfilePill(others, function() return state.copy end, function(v) state.copy = v end))
        Buttons(L["Copy into this profile"], function()
            if not state.copy then return end
            Confirm("copy", L["Click again to replace this profile's settings. The interface will reload."], function()
                if PR.CopyInto(state.copy) then PR.Reload() end
            end)
        end, L["Reset this profile"], function()
            Confirm("reset", L["Click again to reset this profile to its defaults. The interface will reload."], function()
                if PR.Reset() then PR.Reload() end
            end)
        end)
        Row(L["Delete profile"])(ProfilePill(deletable, function() return state.remove end, function(v) state.remove = v end))
        Buttons(L["Delete selected profile"], function()
            if not state.remove then return end
            local target = state.remove
            Confirm("delete", L["Click again to delete this profile. Characters using it go back to Default."], function()
                Done(PR.Delete(target))
                RefreshAll()
            end)
        end)
    end

    Page(9)
    Section(L["PLAY A SAMPLE"])
    CloseGroup()
    Buttons(L["XP and level up"], function() ns.Island:Demo() end, L["Loot roll"], function() ns.Island:DemoRoll() end)
    Buttons(L["Ready check"], function() ns.DemoPrompts() end, L["Flight timer"], function() ns.DemoLive() end)
    Buttons(L["Pull timer"], function() ns.DemoPull() end, L["Server restart"], function() ns.DemoShutdown() end)
    Buttons(L["Toasts"], function() ns.DemoToasts() end, L["Alerts"], function() ns.DemoAlerts() end)
    Buttons(L["Zone"], function() ns.DemoZone() end, L["Quest, whisper, rare"], function() ns.DemoExtras() end)
    Buttons(L["Group changes"], function() ns.DemoGroup() end, L["Vendor visit"], function() ns.DemoVendor() end)
    Buttons(L["Talent reminder"], function() ns.DemoTalentReminder() end, L["Item confirmation"], function() ns.DemoConfirmation() end)
    if ns.ClientFeature("legacy") then
        Buttons(L["Legacy reminder"], function() ns.DemoLegacyReminder() end, L["Legacy challenge"], function() ns.DemoLegacyChallenge() end)
    end
    if ns.ClientFeature("legacy") then
        Buttons(L["Legacy objective"], function() ns.DemoLegacyChallenge(true) end, L["Legacy progress"], function() ns.DemoLegacyChallenge("partial") end)
    end
    Section(L["POSITION"])
    CloseGroup()
    Buttons(L["Reset position"], function()
        db.x, db.y, db.position = ns.defaults.x, ns.defaults.y, "top"
        db.cx, db.cy = nil, nil
        ns.Island:ApplyPosition()
        RefreshAll()
    end)

    -- BanzaiSland: Preview / Demo mode. Every scenario is synthetic (Builder samples, demo cards and
    -- bubbles); nothing on this page arms a secure button or answers a real game prompt.
    Page(40)
    do
        local PV = ns.Preview
        Section(L["PROOF SCENARIOS"])
        Note(L["SYNTHETIC PREVIEW: these cards, bubbles and prompts are made up. Preview buttons never answer the game, roll on loot or change your group."])
        CloseGroup()
        local list = PV and PV.SCENARIOS or {}
        for i = 1, #list, 2 do
            local a, b = list[i], list[i + 1]
            Buttons(a.label, function() PV.Run(a.id) end, b and b.label, b and function() PV.Run(b.id) end)
        end
        Section(L["TOUR"])
        CloseGroup()
        Buttons(L["Play every scenario"], function() if PV then PV.Tour() end end, L["Stop and clear"], function() if PV then PV.Stop() end end)
        Section(L["LOOK VARIANTS"])
        CloseGroup()
        Buttons(L["Banzai Glass + Banzai"], function() if PV then PV.Look("glass", "banzai") RefreshAll() end end,
            L["Class accent"], function() if PV then PV.Look(nil, "class") RefreshAll() end end)
        Buttons(L["Hardkorh accent"], function() if PV then PV.Look(nil, "hardkorh") RefreshAll() end end,
            L["Hardkorh Parchment"], function() if PV then PV.Look("parchment", "hardkorh") RefreshAll() end end)
        Buttons(L["Solid material"], function() if PV then PV.Look("solid", nil) RefreshAll() end end,
            L["Restore my look"], function() if PV then PV.RestoreLook() RefreshAll() end end)
        Buttons(L["Bamboo chassis"], function() if PV then PV.Edge("bamboo") RefreshAll() end end,
            L["Hairline chassis"], function() if PV then PV.Edge("hairline") RefreshAll() end end)
        Note(L["Look variants change your profile's material, chassis edge and accent so you can see them live; Restore my look puts back what you had before the first variant."])
        Section("DISPLAY FONT PREVIEW")
        Note("These sample strings use the selected display face. BANZAI Default is Shojumaru at 105%; Automatic falls back to the Information Font for unsupported strings.")
        local fontSamples = {
            "BANZAI   SLAND", "BUFFS   CHAT", "DAMAGE   HEALING", "READY CHECK",
            "CRACKLING JADE LIGHTNING", "MISTWEAVER   UNHOLY",
            "100%   +250   +9,800 XP", "12:40   1.4s   18%",
        }
        local previewText = ns.Text(page, "display", 18, C.fg)
        previewText:SetPoint("TOPLEFT", page, "TOPLEFT", GAP_X, y - 8)
        previewText:SetWidth(CW - GAP_X * 2)
        previewText:SetJustifyH("LEFT")
        previewText:SetText(table.concat(fontSamples, "\n"))
        Block(previewText, GAP_X, y - 8)
        y = y - 8 - 190
        local fontInfo = ns.Text(page, "medium", 10.5, C.muted)
        fontInfo:SetPoint("TOPLEFT", page, "TOPLEFT", GAP_X, y - 8)
        fontInfo:SetWidth(CW - GAP_X * 2)
        if fontInfo.SetWordWrap then fontInfo:SetWordWrap(true) end
        Block(fontInfo, GAP_X, y - 8)
        local function RefreshFontInfo()
            local info = ns.Theme.DisplayFontInfo(table.concat(fontSamples, " "))
            fontInfo:SetText(string.format("Selected: %s | by %s | license: %s | sample coverage: %s | required coverage: %s | fallback: %s\nSource: %s\nFile: %s | SHA-256: %s\n%s",
                info.name, tostring(info.author), tostring(info.license), tostring(info.coverage), tostring(info.requiredCoverage), info.fallback and "yes" or "no",
                tostring(info.source), tostring(info.file), tostring(info.sourceSha256 or "not applicable"),
                tostring(info.attribution or "")))
        end
        refreshers[#refreshers + 1] = RefreshFontInfo
        RefreshFontInfo()
        ns.ApplyFont()
    end

    -- BanzaiSland: About & Credits
    Page(41)
    Section(L["BANZAISLAND"])
    Note(L["BanzaiSland %s. Contextual Activities, Notifications & Progression: a BANZAI-themed activity HUD for World of Warcraft Retail and WoW Forever."]:format(ns.VERSION or ""))
    Note(L["Client: %s. Theme: %s."]:format(ns.Client and ns.Client.kind or "?", ns.Theme and ns.Theme.Describe() or "?"))
    Note(L["BanzaiSland is a GPLv3 fork of Island by Devin/subtlegrind. BanzaiSland is independently maintained and is not supported by the upstream Island author. BanzaiSland does not promise parity with upstream Island releases."])
    Note(L["Licence: GNU General Public License v3. The complete licence text is in LICENSE inside the addon folder; the source of this build is the addon folder itself."])
    Note(L["Slash commands: /banzaisland and /bsl. /bsl status prints the version, client and theme; /bsl preview opens the synthetic preview."])
    Note(L["The BANZAI SLAND mark on the chassis: BANZAI opens BANZAI UI's settings when BANZAI UI is loaded (its own public entry; never in combat), SLAND opens these settings. Without BANZAI UI the BANZAI half is branding."])

    Page(42)
    Section(L["CREDITS"])
    Note(L["Island 3.7.0 by Devin (CurseForge: subtlegrind), GPLv3: the cards, bubbles, prompts, progression, extension framework and everything that makes BanzaiSland work."])
    Note("BANZAI Default is Shojumaru at 105%. Automatic uses it only for fully supported strings; unsupported strings use the Information Font. This choice is independent of BANZAI UI.")
    Note(L["Open Sans: the information font, bundled by upstream Island with its notice in Media/Fonts."])
    Note(L["Original BANZAI class identity artwork, bamboo construction and Hardkorh parchment: Darren (BANZAI UI). Not Blizzard art."])
    Note(L["BANZAI visual language: deep green-black glass, lime, emerald, violet and purple, bamboo joints, whole-pixel edges."])

    Page(43)
    Section(L["UPSTREAM BASELINE"])
    Note(L["Upstream project: Island (CurseForge project 1734604), by Devin, CurseForge account subtlegrind."])
    Note(L["Exact version: Island 3.7.0, CurseForge file 9461050, archive Island-v3.7.0.zip (1,121,433 bytes)."])
    Note("SHA-256: 47262a842d7f213e1a178ce6dba6b2400a85b232b514aeacc92851c170812113")
    Note(L["Upstream releases are not merged automatically. BanzaiSland is updated for major WoW patches, confirmed defects, security and compatibility, and for BANZAI roadmap items Darren approves. Upstream attribution stays in every source file."])
    Note(L["The original Island addon must not run beside BanzaiSland: when Island is enabled for this character, BanzaiSland prints one notice at login and stays off for the session."])

    Page(10)
    Section(L["KEYS"])
    Toggle(L["Show the bound key on card buttons"], "keyHints", function() if ns.RefreshKeyHints then ns.RefreshKeyHints() end end)
    Note(L["Bind keys or controller buttons in the game's Key Bindings, under AddOns > BanzaiSland: the first, second, third, fourth and last button on a card, and closing a card. They answer invites, ready checks, loot rolls, deaths, summons and everything else with buttons."])
    Section(L["CONTROLLER"], true)
    Toggle(L["Answer cards with the controller"], "padCards", function() if ns.Pad then ns.Pad:Update() end end)
    Toggle(L["Guide button shows your details"], "padGuide", function() if ns.Pad then ns.Pad:ApplyGuide() end end)
    Toggle(L["Rumble on important cards"], "padRumble")
    Note(L["On a card, the D-pad picks a button, A presses it and B says no (Decline, Not ready, Pass). This only happens out of combat, so A still jumps in a fight; your Key Bindings keys work in combat too. Rumble comes with ready checks, invites, summons, resurrections, battlegrounds and pull timers. Turn on controller support in the game's settings first."])

    Page(11)
    -- The embedded preview updates without interrupting the card currently on the island.
    local Bd = ns.Builder
    local function Pick()
        local kind = db.builderPick or "zone"
        return Bd.Available(kind) and kind or "zone"
    end
    local dock = CreateFrame("Frame", nil, win)
    dock:SetPoint("TOPLEFT", win, "TOPLEFT", CX, -18)
    dock:SetSize(CW, 220)
    dock:Hide()
    page.previewDock, page.fixedTop = dock, 220
    page.heading:SetParent(dock)
    page.heading:ClearAllPoints()
    page.heading:SetPoint("TOPLEFT", dock, "TOPLEFT", 2, -8)
    page.subtitle:SetParent(dock)
    -- 0.2.0: the preview sits in a subtle Banzai Glass well with a one-pixel accent edge
    local mat = CreateFrame("Frame", nil, dock)
    mat:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, -60)
    mat:SetSize(CW, 150)
    mat.body = ns.CreateBody(mat, "BACKGROUND", 0)
    mat.body:SetColor(unpack(ns.Theme.UI.well))
    mat.body:SetRadius(ns.Theme.UI.groupRadius)
    local matEdge = CreateFrame("Frame", nil, mat)
    matEdge:SetPoint("TOPLEFT", mat, "TOPLEFT", -1, 1)
    matEdge:SetPoint("BOTTOMRIGHT", mat, "BOTTOMRIGHT", 1, -1)
    matEdge:SetFrameLevel(max(0, mat:GetFrameLevel() - 1))
    matEdge.ring = ns.CreateRing(matEdge)
    matEdge.ring:SetRadius(ns.Theme.UI.groupRadius, 1)
    ns.Renderer.PaintRing(matEdge.ring, ns.Theme.UI.wellEdge)
    refreshers[#refreshers + 1] = function() ns.Renderer.PaintRing(matEdge.ring, ns.Theme.UI.wellEdge) end
    local preview = Bd.CreatePreview(mat)
    preview.frame:SetPoint("TOP", mat, "TOP", 0, -10)
    y = -8
    local function PaintPreview()
        Bd.UpdatePreview(preview, Pick())
        Bd.FitPreview(preview, CW - 24, 130)
    end
    refreshers[#refreshers + 1] = PaintPreview
    PaintPreview()
    Buttons(L["Show a sample"], function() Bd.Preview(Pick()) end, L["Default"], function()
        Bd.Reset(Pick())
        RefreshAll()
        PaintPreview()
    end)
    local TYPEN = {}
    local typeKeys = {}
    for _, t in ipairs(Bd.TYPES) do typeKeys[#typeKeys + 1] = t.key TYPEN[t.key] = t.name end
    Section(L["CARD"])
    Cycle(L["Kind of card"], "builderPick", typeKeys, function(v) return TYPEN[v or "zone"] or L["Zone changes"] end, function(v)
        RefreshAll()
        PaintPreview()
    end)
    local function BCycle(label, field, values, names)
        local button
        local function paint()
            local v = Bd.Get(Pick())[field]
            button.text:SetText(names[tostring(v)] or tostring(v))
            FitPill(button, 190)
        end
        button = Droppable(PillButton(page, "", 190, function()
            OpenMenu(button, values, function(x) return names[tostring(x)] or tostring(x) end, Bd.Get(Pick())[field], function(x)
                Bd.Set(Pick(), field, x)
                paint()
                PaintPreview()
            end)
        end))
        Row(label)(button)
        local words = {}
        for _, value in pairs(names) do words[#words+1] = value end
        searchIndex[#searchIndex].keywords = table.concat(words, " ")
        refreshers[#refreshers + 1] = paint
        paint()
    end
    Section(L["LAYOUT"])
    BCycle(L["Layout"], "layout", { "classic", "icon", "centered" },
        { classic = L["Icon, text beside it"], icon = L["Icon, text centered"], centered = L["Centered, no icon"] })
    BCycle(L["Label on top"], "label", { true, false }, { ["true"] = L["Shown"], ["false"] = L["Hidden"] })
    Section(L["TYPOGRAPHY AND COLORS"], true)
    BCycle(L["Label color"], "labelColor", { "auto", "tone", "accent", "muted" },
        { auto = L["The card's own"], tone = L["Icon color"], accent = L["Accent color"], muted = L["Grey"] })
    BCycle(L["Title"], "title", { "normal", "large" }, { normal = L["Normal"], large = L["Large"] })
    BCycle(L["Second line"], "line", { true, false }, { ["true"] = L["Shown"], ["false"] = L["Hidden"] })
    Note(L["Changes update the preview above. Show a sample to try the card on the island. Buttons, countdown bars and rolling numbers stay available in every layout. XP and level-up cards keep their usual appearance."])

    Finish()

    -- Search uses the real row labels and their page/section context, including folded rows.
    -- Small edit distances also handle missing letters and adjacent transpositions.
    local function Normalize(value)
        return (value or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower():gsub("[%p%c]", " ")
    end
    local aliases = {
        L["taxi flight flying travel"], L["repair durability armor broken"],
        L["bags inventory slots space"], L["sound audio volume"],
        L["font text typography"], L["position placement move location"],
        L["upgrade equipment gear lootified pawn"], L["experience xp kills leveling"],
        L["colour color tint"], L["reset default restore"],
    }
    local function Words(value)
        local result = {}
        for word in Normalize(value):gmatch("%S+") do result[#result + 1] = word end
        return result
    end
    local function Distance(a, b, limit)
        if math.abs(#a - #b) > limit then return limit + 1 end
        local previous, older = {}, nil
        for j = 0, #b do previous[j] = j end
        for i = 1, #a do
            local row = {[0] = i}
            for j = 1, #b do
                row[j] = min(row[j-1]+1, previous[j]+1, previous[j-1]+(a:byte(i)==b:byte(j) and 0 or 1))
                if older and j > 1 and a:byte(i)==b:byte(j-1) and a:byte(i-1)==b:byte(j) then
                    row[j] = min(row[j], older[j-2]+1)
                end
            end
            older, previous = previous, row
        end
        return previous[#b]
    end
    local function Match(token, words)
        local best = 0
        for _, word in ipairs(words) do
            if token == word then best = max(best, 100)
            elseif word:find(token, 1, true) then best = max(best, 85)
            elseif #token >= 4 then
                local limit = #token >= 7 and 2 or 1
                local distance = Distance(token, word, limit)
                if distance <= limit then best = max(best, 65 - distance * 10) end
            end
        end
        return best
    end
    for _, entry in ipairs(searchIndex) do
        entry.words = Words(entry.label)
        entry.contextWords = Words(entry.context .. " " .. (entry.keywords or ""))
        entry.related = {}
        for _, alias in ipairs(aliases) do
            local words = Words(alias)
            local related = false
            for _, word in ipairs(words) do
                for _, own in ipairs(entry.words) do if own == word then related = true end end
            end
            if related then for _, word in ipairs(words) do entry.related[#entry.related+1] = word end end
        end
    end
    local function Find(query)
        local tokens, matches = Words(query), {}
        if #tokens == 0 then return matches end
        for order, entry in ipairs(searchIndex) do
            local score = 0
            for _, token in ipairs(tokens) do
                local hit = max(Match(token, entry.words), Match(token, entry.contextWords)*0.65, Match(token, entry.related)*0.7)
                if hit == 0 then score = 0 break end
                score = score + hit
            end
            if score > 0 then matches[#matches+1] = {entry=entry, score=score, order=order} end
        end
        table.sort(matches, function(a,b) return a.score == b.score and a.order < b.order or a.score > b.score end)
        return matches
    end
    local function Jump(entry)
        searchBox:ClearFocus()
        Select(entry.page.index)
        if entry.section then entry.section.open = true Reflow(entry.page) end
        local _, _, _, _, groupY = entry.group:GetPoint(1)
        want = clamp(-(groupY or 0) + entry.offset - 36, 0, MaxScroll())
        at = want
        scroll:SetVerticalScroll(at)
        PaintThumb()
        highlighted = entry.text
        local color = ns.Accent()
        highlighted:SetTextColor(color[1], color[2], color[3])
    end
    searchPage = CreateFrame("Frame", nil, scroll)
    searchPage:SetWidth(CW)
    searchPage.sections = {}
    searchPage:Hide()
    pages[22] = searchPage
    local searchTitle = ns.Text(searchPage, "extra", 21, C.fg)
    searchTitle:SetPoint("TOPLEFT", searchPage, "TOPLEFT", 2, -8)
    searchTitle:SetText(L["Search settings"])
    searchEmpty = ns.Text(searchPage, "medium", 12, C.muted)
    searchEmpty:SetPoint("TOPLEFT", searchPage, "TOPLEFT", 2, -42)
    searchEmpty:SetWidth(CW-16)
    searchEmpty:SetJustifyH("LEFT")
    searchBox = CreateFrame("EditBox", nil, side)
    searchBox:SetSize(side:GetWidth()-28, 30)
    searchBox:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -74)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(80)
    searchBox:SetTextInsets(10, 26, 0, 0)
    ns.UseFont(searchBox, "medium", 12)
    searchBox:SetTextColor(C.fg[1], C.fg[2], C.fg[3])
    searchBox.body = ns.CreateBody(searchBox, "BACKGROUND", 0)
    searchBox.body:SetColor(1, 1, 1, 0.08)
    searchBox.body:SetRadius(ns.Theme.UI.radius)
    searchHint = ns.Text(searchBox, "medium", 12, C.muted)
    searchHint:SetPoint("LEFT", searchBox, "LEFT", 10, 0)
    searchHint:SetText(L["Search settings"])
    local clearSearch = CreateFrame("Button", nil, searchBox)
    clearSearch:SetSize(24, 26)
    clearSearch:SetPoint("RIGHT", searchBox, "RIGHT", 0, 0)
    clearSearch.icon = ns.Image(clearSearch, "Close", "ARTWORK", 0)
    clearSearch.icon:SetSize(10, 10)
    clearSearch.icon:SetPoint("CENTER", clearSearch, "CENTER", 0, 0)
    clearSearch.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
    clearSearch:SetScript("OnClick", function() searchBox:SetText("") searchBox:ClearFocus() end)
    local results = {}
    searchBox:SetScript("OnTextChanged", function(self)
        local query = self:GetText() or ""
        searchHint:SetShown(query == "")
        clearSearch:SetShown(query ~= "")
        CloseMenu()
        if not query:find("%S") then
            results = {}
            if activeIndex == 22 then Select(lastPage) end
            return
        end
        results = Find(query)
        searchEmpty:SetText(#results == 0 and L["No settings found. Try another word."] or L["Select a result to open its setting."])
        for i, result in ipairs(results) do
            local row = searchRows[i]
            if not row then
                row = CreateFrame("Button", nil, searchPage)
                row:SetSize(CW, 52)
                row:SetPoint("TOPLEFT", searchPage, "TOPLEFT", 0, -72-(i-1)*56)
                row.body = ns.CreateBody(row, "BACKGROUND", 0)
                row.body:SetRadius(ns.Theme.UI.radius)
                row.body:SetColor(1, 1, 1, 0.045)
                row.label = ns.Text(row, "medium", 13, C.fg)
                row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -8)
                row.label:SetWidth(CW-24)
                row.label:SetJustifyH("LEFT")
                row.context = ns.Text(row, "medium", 10.5, C.muted)
                row.context:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -29)
                row.context:SetWidth(CW-24)
                row.context:SetJustifyH("LEFT")
                row:SetScript("OnClick", function() Jump(row.entry) end)
                row:SetScript("OnEnter", function() row.body:SetColor(1,1,1,0.10) end)
                row:SetScript("OnLeave", function() row.body:SetColor(1,1,1,0.045) end)
                searchRows[i] = row
            end
            row.entry = result.entry
            row.label:SetText(row.entry.label)
            row.context:SetText(row.entry.context)
            row:Show()
        end
        for i = #results+1, #searchRows do searchRows[i]:Hide() end
        searchPage.h = 84 + #results*56
        searchPage:SetHeight(searchPage.h)
        Select(22)
    end)
    searchBox:SetScript("OnEnterPressed", function() if results[1] then Jump(results[1].entry) end end)
    searchBox:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
    win:HookScript("OnHide", function() searchBox:ClearFocus() end)
    searchBox:SetText("")
    clearSearch:Hide()
    Select(6, true)
    ns.SelectSettingsPage = Select -- BanzaiSland: /bsl preview opens straight to a page
    win:SetScript("OnShow", RefreshAll)
    win:Hide()
end

function ns.ToggleSettings(pageIndex)
    if not ns.db then return end
    if ns.Packages and ns.Packages.IsOpen and ns.Packages.IsOpen() then
        ns.Packages.Close()
        if not win then Build() end
        win:Show()
        return
    end
    if not win then Build() end
    if pageIndex then
        win:Show()
        if ns.SelectSettingsPage then ns.SelectSettingsPage(pageIndex, true) end
        return
    end
    win:SetShown(not win:IsShown())
end
