-- BanzaiSland: the chassis renderer. Dresses the island that Island.lua builds and animates with the
-- BANZAI construction:
--   BAMBOO   (0.1.0, approved) a small bamboo end-cap at each end of the glass, one-pixel accent
--            hairlines along the top and bottom edges, softly chamfered corners;
--   HAIRLINE (0.2.0) no caps: a four-sided one-pixel accent frame whose left / right lines simply grow
--            with the island's height and whose top / bottom lines grow with its width;
-- the Hardkorh parchment sheet when that material is picked, thin accent rings on the activity
-- bubbles, the player's original Banzai class identity on the level-up card and the details panel,
-- and (0.2.0) the integrated BANZAI SLAND wordmark set into the top line, with two measured hit zones.
--
-- Boundaries: Island.lua calls Decorate once from I:Build, ApplyMaterial from I:ApplyOpacity,
-- ApplyAccent from I:ApplyColors, Fade from its alpha step, and PaintRing for bubble rings.
-- Launcher.lua owns what the wordmark's halves do. Nothing here reads game events or touches the
-- cards' business logic; everything is anchored to the island frame, so the springs that resize it
-- move the dressing for free. Only the pieces whose geometry depends on the size (cap bodies, line
-- segment splits, the parchment tile) are refreshed, from OnSizeChanged; no texture is ever recreated.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)

local Theme = ns.Theme
local L = ns.L
local R = {}
ns.Renderer = R

local floor, max, min = math.floor, math.max, math.min
local STALK, STALK_END = Theme.MEDIA .. "Stalk", Theme.MEDIA .. "StalkEnd"
local CORNER_BAMBOO = 6   -- the glass surface's corner radius under the caps: softly chamfered, never a pill
local CORNER_HAIRLINE = 1 -- the thin frame meets at sharp corners

local function db() return ns.db or ns.defaults end

-- one physical pixel in `frame`'s units
local function Pixel(frame)
    local es = frame:GetEffectiveScale()
    local physH = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize()) or 768
    return (768 / (physH > 0 and physH or 768)) / ((es and es > 0) and es or 1)
end
R.Pixel = Pixel

local function Snap(t)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(true) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
end

-- a two-colour gradient on a texture (vertex colour when the client has no gradients)
local function Gradient(tex, orientation, from, to, alpha)
    alpha = alpha or 1
    if tex.SetGradient and CreateColor then
        tex:SetVertexColor(1, 1, 1, 1)
        tex:SetGradient(orientation, CreateColor(from[1], from[2], from[3], alpha), CreateColor(to[1], to[2], to[3], alpha))
    else
        tex:SetVertexColor((from[1] + to[1]) / 2, (from[2] + to[2]) / 2, (from[3] + to[3]) / 2, alpha)
    end
end
R.Gradient = Gradient

-- the eight tex coords of a vertical piece reading the texture's U along y (BANZAI panel pieces);
-- `flip` runs U the other way (a tip pointing up)
local function VCoords(u0, u1, flip)
    if flip then u0, u1 = u1, u0 end
    return u0, 0, u1, 0, u0, 1, u1, 1
end

function R.CornerLimit() return Theme.IsHairline() and CORNER_HAIRLINE or CORNER_BAMBOO end

-- ---------------------------------------------------------------- bamboo caps
-- One cap: a vertical stalk standing on the island's end, its cut tip above the island and its node
-- end below. The tips keep their drawn proportion; on a short island they are cropped at their body
-- side (never squashed), and the body between them repeats the stalk at fixed texel density.
local function MakeCap(I, side)
    local B = Theme.BAMBOO
    local d = B.diameter
    local strip = (B.texH / B.texD) * d
    local cap = { side = side, d = d, strip = strip, pieces = {} }
    local dress = I.dress
    local function piece(path, sub)
        local t = dress:CreateTexture(nil, "ARTWORK", nil, sub)
        t:SetTexture(path, path == STALK and "REPEAT" or "CLAMP", "CLAMP", "TRILINEAR")
        Snap(t)
        return t
    end
    cap.top = piece(STALK_END, 2)
    cap.body = piece(STALK, 1)
    cap.bottom = piece(STALK_END, 2)
    local axis = B.inset * d
    local point = side == "left" and "LEFT" or "RIGHT"
    local x = side == "left" and axis or -axis
    -- the three pieces hang from the island's top and bottom edges, so the springs move them for free
    cap.top:SetPoint("TOP" .. point, I.island, "TOP" .. point, x + (side == "left" and -strip / 2 or strip / 2), B.overhang)
    cap.bottom:SetPoint("BOTTOM" .. point, I.island, "BOTTOM" .. point, x + (side == "left" and -strip / 2 or strip / 2), -B.overhang)
    cap.body:SetPoint("TOP", cap.top, "BOTTOM", 0, 0)
    cap.body:SetPoint("BOTTOM", cap.bottom, "TOP", 0, 0)
    for _, t in ipairs({ cap.top, cap.body, cap.bottom }) do t:SetWidth(strip) end
    return cap
end

-- tip heights and texture coordinates for the island's current height
local function LayoutCap(I, cap)
    local B = Theme.BAMBOO
    local h = (I.island:GetHeight() or 0) + 2 * B.overhang
    if h <= 0 then return end
    local tipNatural = (B.tipPx / B.texD) * cap.d
    local minBody = cap.d * 0.6
    local tip = min(tipNatural, max(cap.d, (h - minBody) / 2))
    local gap = B.tipGap / (2 * B.tipPx)
    local share = (tip / tipNatural) * (0.5 - gap)      -- how much of the tip piece shows (its pointed end always)
    cap.top:SetHeight(tip)
    cap.bottom:SetHeight(tip)
    -- the cut tip occupies U 0 .. 0.5-gap with its point at U 0; the node end U 0.5+gap .. 1 with its end at 1
    cap.top:SetTexCoord(VCoords(0, share, true))
    cap.bottom:SetTexCoord(VCoords(1 - share, 1, false))
    local bodyH = max(0, h - 2 * tip)
    local period = (B.periodPx / B.texD) * cap.d
    local u1 = bodyH / (period * B.periods)
    cap.body:SetTexCoord(VCoords(0, max(0.001, u1), false))
    cap.body:SetShown(I.capsOn ~= false and bodyH > 0.5)
    cap.h = h
end

local function PaintCap(cap, side)
    local stops = Theme.Stops()
    -- the left cap carries the ramp's start, the right cap its end; each piece a gradient along its length
    local lo, hi = 0, 0.32
    if side == "right" then lo, hi = 0.68, 1 end
    local function at(f) return Theme.ColorAt(stops, lo + (hi - lo) * f) end
    -- vertical gradients take their first colour at the bottom
    Gradient(cap.top, "VERTICAL", at(0.75), at(1))
    Gradient(cap.body, "VERTICAL", at(0.25), at(0.75))
    Gradient(cap.bottom, "VERTICAL", at(0), at(0.25))
end

-- ---------------------------------------------------------------- hairlines
-- one physical pixel along the edges of the glass. Top: four segments (two runs, so the line can stop
-- for the wordmark and resume after it, the ramp flowing through); bottom: three segments; left and
-- right (HAIRLINE chassis): three segments each, the ramp's start on the left and its end on the right.
local TOP_SEGMENTS, SEGMENTS = 4, 3
local function MakeLine(I, sub)
    local t = I.dress:CreateTexture(nil, "ARTWORK", nil, sub or 3)
    t:SetColorTexture(1, 1, 1, 1)
    Snap(t)
    return t
end
local function MakeHairlines(I)
    local lines = { top = {}, bottom = {}, left = {}, right = {} }
    for i = 1, TOP_SEGMENTS do lines.top[i] = MakeLine(I) end
    for i = 1, SEGMENTS do lines.bottom[i] = MakeLine(I) end
    for i = 1, SEGMENTS do lines.left[i] = MakeLine(I) end
    for i = 1, SEGMENTS do lines.right[i] = MakeLine(I) end
    return lines
end

-- the wordmark's horizontal extent on the island, in island units from its left edge (nil when hidden)
local function BrandSpan(I)
    local b = I.brand
    if not (b and b.shown) then return nil end
    local w = I.island:GetWidth() or 0
    local bw = b:GetWidth() or 0
    local gap = Theme.BRAND.lineGap
    return (w - bw) / 2 - gap, (w + bw) / 2 + gap, w
end

-- a horizontal run of segments from x0 to x1 along an edge, colouring the ramp's fa .. fb across it;
-- each segment remembers its fractions so PaintHairlines can colour it (only when the runs change)
local function LayoutRun(I, segs, first, count, edge, x0, x1, px, show, fa, fb)
    local span = x1 - x0
    local seg = span / count
    for k = 0, count - 1 do
        local t = segs[first + k]
        t:ClearAllPoints()
        local a, b = x0 + k * seg, x0 + (k + 1) * seg
        if edge == "top" then
            t:SetPoint("TOPLEFT", I.island, "TOPLEFT", a, 0)
            t:SetPoint("BOTTOMRIGHT", I.island, "TOPLEFT", b, -px)
        else
            t:SetPoint("BOTTOMLEFT", I.island, "BOTTOMLEFT", a, 0)
            t:SetPoint("TOPRIGHT", I.island, "BOTTOMLEFT", b, px)
        end
        t.f0, t.f1 = fa + (fb - fa) * k / count, fa + (fb - fa) * (k + 1) / count
        t:SetShown(show and seg > 0.5)
    end
end

local function LayoutHairlines(I)
    local px = Pixel(I.island)
    local w, h = I.island:GetSize()
    w, h = w or 0, h or 0
    local hairline = Theme.IsHairline()
    local inset = hairline and 0 or CORNER_BAMBOO
    local show = I.hairOn ~= false
    local lines = I.hairlines
    -- top: two runs around the wordmark (lime -> emerald into BANZAI, violet -> purple out of SLAND),
    -- or one run in four segments when there is no wordmark
    local bl, br = BrandSpan(I)
    local split = bl and bl > inset + 2 and br < w - inset - 2
    if split then
        LayoutRun(I, lines.top, 1, 2, "top", inset, bl, px, show, 0, 0.4)
        LayoutRun(I, lines.top, 3, 2, "top", br, w - inset, px, show, 0.6, 1)
    else
        LayoutRun(I, lines.top, 1, TOP_SEGMENTS, "top", inset, w - inset, px, show, 0, 1)
    end
    LayoutRun(I, lines.bottom, 1, SEGMENTS, "bottom", inset, w - inset, px, show, 0, 1)
    local repaint = I.topSplit ~= split
    I.topSplit = split
    -- sides (HAIRLINE chassis): the full height, in three stacked segments that grow with it
    local seg = h / SEGMENTS
    for i = 1, SEGMENTS do
        local y0, y1 = (i - 1) * seg, i * seg
        local lt, rt = lines.left[i], lines.right[i]
        lt:ClearAllPoints()
        lt:SetPoint("TOPLEFT", I.island, "TOPLEFT", 0, -y0)
        lt:SetPoint("BOTTOMRIGHT", I.island, "TOPLEFT", px, -y1)
        rt:ClearAllPoints()
        rt:SetPoint("TOPRIGHT", I.island, "TOPRIGHT", 0, -y0)
        rt:SetPoint("BOTTOMLEFT", I.island, "TOPRIGHT", -px, -y1)
        local on = hairline and show and seg > 0.5
        lt:SetShown(on)
        rt:SetShown(on)
    end
    return repaint
end

local function PaintHairlines(I)
    local stops = Theme.Stops()
    local alpha = 0.85
    for _, edge in ipairs({ "top", "bottom" }) do
        for _, t in ipairs(I.hairlines[edge]) do
            Gradient(t, "HORIZONTAL", Theme.ColorAt(stops, t.f0 or 0), Theme.ColorAt(stops, t.f1 or 1), alpha)
        end
    end
    -- vertical gradients take their first colour at the bottom; the left line runs 0 .. 0.32 of the
    -- ramp top to bottom, the right line 0.68 .. 1, as the caps do
    for i = 1, SEGMENTS do
        local a, b = (i - 1) / SEGMENTS, i / SEGMENTS
        Gradient(I.hairlines.left[i], "VERTICAL", Theme.ColorAt(stops, 0.32 * b), Theme.ColorAt(stops, 0.32 * a), alpha)
        Gradient(I.hairlines.right[i], "VERTICAL", Theme.ColorAt(stops, 0.68 + 0.32 * b), Theme.ColorAt(stops, 0.68 + 0.32 * a), alpha)
    end
end

-- ---------------------------------------------------------------- parchment
local function MakeParchment(I)
    local P = Theme.PARCHMENT
    local under = CreateFrame("Frame", nil, I.anchor)
    under:SetFrameLevel(max(0, I.island:GetFrameLevel() - 1))
    under:SetAllPoints(I.island)
    under:EnableMouse(false)
    under:Hide()
    I.under = under
    local pieces = {}
    for i, piece in ipairs(Theme.ParchmentLayout(100, 40, 0, 0)) do
        local tex = P.textures[piece.texture]
        local t = under:CreateTexture(nil, "BACKGROUND", nil, piece.texture == "tile" and 0 or 1)
        t:SetTexture(tex[1], tex[2], tex[3], "TRILINEAR")
        Snap(t)
        pieces[i] = t
    end
    I.parchment = pieces
end

local function LayoutParchment(I)
    if not (I.under and I.under:IsShown()) then return end
    local pw, ph = I.island:GetSize()
    if not pw or pw <= 0 or not ph or ph <= 0 then return end
    local layout = Theme.ParchmentLayout(pw, ph, 0, 0)
    for i, piece in ipairs(layout) do
        local t = I.parchment[i]
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", I.under, "TOPLEFT", piece.x0, -piece.y0)
        t:SetPoint("BOTTOMRIGHT", I.under, "TOPLEFT", piece.x1, -piece.y1)
        t:SetTexCoord(unpack(piece.coords))
    end
end

-- ---------------------------------------------------------------- class badges
-- the player's original Banzai class identity (or a class-coloured disc when no art is available)
local function MakeBadge(parent, size)
    local badge = { frame = parent }
    badge.art = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    badge.art:SetSize(size, size)
    badge.disc = ns.Image(parent, "Circle", "ARTWORK", 1)
    badge.disc:SetSize(size * 0.8, size * 0.8)
    badge.disc:SetPoint("CENTER", badge.art, "CENTER", 0, 0)
    badge.size = size
    return badge
end

local function PaintBadge(badge)
    local path, token = Theme.PlayerClassArt()
    if path then
        badge.art:SetTexture(path)
        badge.art:Show()
        badge.disc:Hide()
        return
    end
    badge.art:Hide()
    local c = Theme.ClassColor()
    if db().classArt == false or not c then badge.disc:Hide() return end
    badge.disc:SetVertexColor(c[1], c[2], c[3], 0.9)
    badge.disc:Show()
end

-- ---------------------------------------------------------------- the BANZAI SLAND mark
-- One mark in two halves: the BANZAI bamboo wordmark texture (BANZAI UI's own identity) and SLAND in
-- the display face. `interactive` adds the two hit zones (measured from the drawn bounds, meeting at the
-- midpoint of the join so they never overlap), hover and tooltips. Used on the chassis and, without
-- interaction, in the settings header.
function R.MakeBrand(parent, height, interactive, level)
    local B = Theme.BRAND
    local f = CreateFrame("Frame", nil, parent)
    if level then f:SetFrameLevel(level) end
    f:EnableMouse(false)
    local pad = B.pad
    local bw = height * B.aspect
    f.banzai = f:CreateTexture(nil, "ARTWORK", nil, 2)
    f.banzai:SetTexture(B.texture, "CLAMP", "CLAMP", "TRILINEAR")
    f.banzai:SetTexCoord(B.crop[1], B.crop[2], B.crop[3], B.crop[4])
    f.banzai:SetSize(bw, height)
    f.banzai:SetPoint("LEFT", f, "LEFT", pad, 0)
    -- hover: the same letters once more on top, added, faint (as BANZAI UI's own wordmark does)
    f.glow = f:CreateTexture(nil, "ARTWORK", nil, 3)
    f.glow:SetTexture(B.texture, "CLAMP", "CLAMP", "TRILINEAR")
    f.glow:SetTexCoord(B.crop[1], B.crop[2], B.crop[3], B.crop[4])
    f.glow:SetAllPoints(f.banzai)
    if f.glow.SetBlendMode then f.glow:SetBlendMode("ADD") end
    f.glow:SetAlpha(B.hoverGlow)
    f.glow:Hide()
    local slandSize = height * (B.slandSize / B.height)
    f.sland = ns.Text(f, "display", slandSize, B.sland)
    ns.TextFlags(f.sland, "OUTLINE") -- readable where the mark straddles the glass edge and the world
    f.sland:SetText("SLAND")
    f.sland:SetPoint("BOTTOMLEFT", f.banzai, "BOTTOMRIGHT", B.gap, height * 0.12 + B.slandDy)
    local sw = f.sland:GetStringWidth() or 0
    f.banzaiWidth, f.slandWidth = bw, sw
    local total = pad + bw + B.gap + sw + pad
    f:SetSize(total, height + 2 * pad)
    f.height = height
    if interactive then
        -- the join: the BANZAI zone ends and the SLAND zone starts at the midpoint between the letters
        local joinX = pad + bw + B.gap / 2
        local bz = CreateFrame("Button", nil, f)
        bz:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        bz:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", joinX, 0)
        -- 0.2.1: the SLAND zone follows the text's rendered rect (top / bottom of the glyph box plus the
        -- pad), so a baseline nudge moves the hit and hover area with the letters; its left edge is the join
        local sz = CreateFrame("Button", nil, f)
        sz:SetPoint("TOP", f.sland, "TOP", 0, pad)
        sz:SetPoint("BOTTOM", f.sland, "BOTTOM", 0, -pad)
        sz:SetPoint("LEFT", f, "LEFT", joinX, 0)
        sz:SetPoint("RIGHT", f, "RIGHT", 0, 0)
        for _, z in ipairs({ bz, sz }) do
            z:RegisterForClicks("LeftButtonUp")
            z:EnableMouse(true)
        end
        f.banzaiZone, f.slandZone, f.joinX = bz, sz, joinX
        local function Tip(zone, title, line)
            if not GameTooltip then return end
            ns.PlaceTip(GameTooltip, zone, "BOTTOM")
            GameTooltip:SetText(title, 1, 1, 1)
            if line then GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
            GameTooltip:Show()
        end
        bz:SetScript("OnEnter", function(z) f.hoverBanzai = true R.PaintBrand(f) local a, b = ns.Launcher.BanzaiTip() Tip(z, a, b) end)
        bz:SetScript("OnLeave", function() f.hoverBanzai = false R.PaintBrand(f) if GameTooltip then GameTooltip:Hide() end end)
        bz:SetScript("OnClick", function() ns.Launcher.ClickBanzai() end)
        sz:SetScript("OnEnter", function(z) f.hoverSland = true R.PaintBrand(f) local a, b = ns.Launcher.SlandTip() Tip(z, a, b) end)
        sz:SetScript("OnLeave", function() f.hoverSland = false R.PaintBrand(f) if GameTooltip then GameTooltip:Hide() end end)
        sz:SetScript("OnClick", function() ns.Launcher.ClickSland() end)
    end
    R.PaintBrand(f)
    return f
end

-- colours of the mark for the material and the hover state (no movement, no scaling)
function R.PaintBrand(f)
    local B = Theme.BRAND
    f.glow:SetShown(f.hoverBanzai and true or false)
    local c
    if Theme.IsParchment() and f.onSheet then
        c = f.hoverSland and Theme.Ink(B.slandHover) or Theme.Ink(B.sland)
    else
        c = f.hoverSland and B.slandHover or B.sland
    end
    f.sland:SetTextColor(c[1], c[2], c[3])
end

-- the mark on the chassis: fixed on the island's top edge, centred; the chassis grows beneath it
local function MakeChassisBrand(I)
    local B = Theme.BRAND
    local f = R.MakeBrand(I.anchor, B.height, true, I.island:GetFrameLevel() + 3)
    f.onSheet = true
    f:SetPoint("CENTER", I.island, "TOP", 0, 0)
    f.shown = true
    I.brand = f
end

-- the mark needs room on the top edge; on a tiny idle island (the "percent" / "dot" styles) it waits.
-- Whenever it comes or goes, BANZAI UI is told (0.2.1: the host follows the mark, event-driven, no polling)
local function LayoutBrand(I)
    local f = I.brand
    if not f then return end
    local w = I.island:GetWidth() or 0
    local room = w >= (f:GetWidth() or 0) + 2 * Theme.BRAND.lineGap + 16
    local on = room and I.brandOn ~= false
    if on ~= f.shown then
        f.shown = on
        f:SetShown(on)
        if ns.Launcher then ns.Launcher.Announce(on) end
    end
end

-- ---------------------------------------------------------------- the boundaries
function R.Decorate(I)
    if I.dress then return end
    local dress = CreateFrame("Frame", nil, I.anchor)
    dress:SetFrameLevel(I.island:GetFrameLevel() + 2)
    dress:SetAllPoints(I.island)
    dress:EnableMouse(false)
    I.dress = dress
    I.caps = { left = MakeCap(I, "left"), right = MakeCap(I, "right") }
    I.hairlines = MakeHairlines(I)
    MakeParchment(I)
    MakeChassisBrand(I)
    if I.l and I.l.frame then
        I.l.badge = MakeBadge(I.l.frame, 44)
        I.l.badge.art:SetPoint("TOPRIGHT", I.l.frame, "TOPRIGHT", -16, -12)
    end
    if I.d and I.d.frame then
        I.d.badge = MakeBadge(I.d.frame, 26)
        I.d.badge.art:SetPoint("TOPRIGHT", I.d.frame, "TOPRIGHT", -46, -13)
    end
    -- the pieces whose geometry depends on the size follow every resize
    local function OnSize() R.Layout(I) end
    if I.island:GetScript("OnSizeChanged") then I.island:HookScript("OnSizeChanged", OnSize) else I.island:SetScript("OnSizeChanged", OnSize) end
    R.Layout(I)
    if ns.Launcher then ns.Launcher.Announce(I.brand and I.brand.shown or false) end
end

-- everything whose geometry depends on the island's size; the top line is repainted only when the
-- wordmark appears or goes (its runs change), never on a plain resize
function R.Layout(I)
    if not I.caps then return end
    LayoutBrand(I)
    LayoutCap(I, I.caps.left)
    LayoutCap(I, I.caps.right)
    if LayoutHairlines(I) then PaintHairlines(I) end
    LayoutParchment(I)
end

-- material and chassis edge: glass / solid shell colours are applied by the body itself
-- (Theme.ShellFill); here the corner shape, the caps or the side lines, the hairlines and the
-- parchment sheet follow the material and the edge style
function R.ApplyMaterial(I)
    if not I.dress then return end
    local settings = db()
    local hairline = Theme.IsHairline()
    local limit = R.CornerLimit()
    I.body:SetCornerLimit(limit, I.island)
    if I.ring and I.ring.body then I.ring.body:SetCornerLimit(limit, I.island) end
    local parchment = Theme.IsParchment()
    local caps = not hairline and settings.bambooCaps ~= false
    I.capsOn = caps
    for _, cap in pairs(I.caps) do
        cap.top:SetShown(caps)
        cap.bottom:SetShown(caps)
        cap.body:SetShown(caps and (cap.h or 0) > 0)
    end
    -- BAMBOO on parchment keeps 0.1.0's look (the paper's own worn edge, no lines); HAIRLINE always draws its frame
    local hair = settings.hairline ~= false and (hairline or not parchment)
    I.hairOn = hair
    I.body:SetShown(not parchment)
    I.under:SetShown(parchment)
    if parchment then
        local k = 0.91
        for _, t in ipairs(I.parchment) do t:SetVertexColor(k, k, k, 1) end
    end
    R.Layout(I)
    R.ApplyAccent(I)
end

function R.ApplyAccent(I)
    if not I.dress then return end
    PaintCap(I.caps.left, "left")
    PaintCap(I.caps.right, "right")
    PaintHairlines(I)
    if I.brand then R.PaintBrand(I.brand) end
    if I.l and I.l.badge then PaintBadge(I.l.badge) end
    if I.d and I.d.badge then PaintBadge(I.d.badge) end
    -- the bubble rings repaint through the island's own border pass
    if I.ApplyBubbleBorder and I.built then I:ApplyBubbleBorder() end
end

-- the dressing fades with the island
function R.Fade(I, alpha)
    if I.dress then I.dress:SetAlpha(alpha) end
    if I.under then I.under:SetAlpha(alpha) end
    if I.brand then I.brand:SetAlpha(alpha) end
end

-- a hollow ring (ns.CreateRing) painted with the accent ramp: lime at the top-left round to purple at
-- the bottom-right; `scale` (0..1) dims it (the "+n" chip)
function R.PaintRing(ring, scale)
    local a = 0.9 * (scale or 1)
    local c0, c1, c2, c3 = Theme.Accent(0), Theme.Accent(0.4), Theme.Accent(0.7), Theme.Accent(1)
    if not (ring.corners and ring.strips) then
        local c = Theme.Primary()
        ring:SetColor(c[1], c[2], c[3], a)
        return
    end
    local corners, strips = ring.corners, ring.strips
    corners[1]:SetVertexColor(c0[1], c0[2], c0[3], a)  -- top-left
    corners[2]:SetVertexColor(c1[1], c1[2], c1[3], a)  -- top-right
    corners[3]:SetVertexColor(c2[1], c2[2], c2[3], a)  -- bottom-left
    corners[4]:SetVertexColor(c3[1], c3[2], c3[3], a)  -- bottom-right
    Gradient(strips[1], "HORIZONTAL", c0, c1, a)       -- top
    Gradient(strips[2], "HORIZONTAL", c2, c3, a)       -- bottom
    Gradient(strips[3], "VERTICAL", c2, c0, a)         -- left (first colour at the bottom)
    Gradient(strips[4], "VERTICAL", c3, c1, a)         -- right
end

-- a one-line status for /banzaisland status and the tests
function R.Describe(I)
    if not (I and I.dress) then return "not built" end
    return string.format("edge %s, caps %s, hairlines %s, sides %s, parchment %s, corner %d, wordmark %s",
        Theme.ChassisEdge(), tostring(I.caps.left.top:IsShown()), tostring(I.hairlines.top[1]:IsShown()),
        tostring(I.hairlines.left[1]:IsShown()), tostring(I.under:IsShown()), R.CornerLimit(),
        tostring(I.brand and I.brand.shown or false))
end
