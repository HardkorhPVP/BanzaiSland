-- Island: the island itself. One black rounded shape whose width, height and corner
-- radius are driven by damped springs, with a content layer for each state.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs

local MEDIA = "Interface\\AddOns\\BanzaiSland\\Media\\"
ns.MEDIA = MEDIA

-- BanzaiSland: the neutral text colours come from the theme (readable on green glass)
local Theme = ns.Theme
local C = {
    fg    = Theme and Theme.COLORS.fg or { 0.925, 0.933, 0.957 },
    muted = Theme and Theme.COLORS.muted or { 0.553, 0.576, 0.647 },
    gold  = { 0.961, 0.788, 0.416 },
    quest = { 0.949, 0.820, 0.361 },
    disc  = { 0.373, 0.839, 0.753 },
}
ns.C = C

-- The Forever finish uses the action bar's dark bronze and small plaque corners.
-- Keep its colours together so the metal and stone can be tuned in one place.
local FOREVER = {
    fill = { 44 / 255, 40 / 255, 37 / 255 },
    fillTop = { 31 / 255, 27 / 255, 23 / 255 },
    fillMiddle = { 50 / 255, 44 / 255, 41 / 255 },
    fillBottom = { 32 / 255, 28 / 255, 25 / 255 },
    edge = { 86 / 255, 53 / 255, 33 / 255 },
    light = { 122 / 255, 87 / 255, 57 / 255 },
    shadow = { 38 / 255, 25 / 255, 17 / 255 },
    fg = { 0.941, 0.875, 0.698 },
    muted = { 0.749, 0.671, 0.537 },
    gold = { 208 / 255, 173 / 255, 125 / 255 },
    track = { 0.031, 0.027, 0.024, 0.85 },
    tick = { 0.031, 0.027, 0.024, 0.25 },
    buttonShade = 0.82,
    buttonHover = 1,
}
ns.ForeverPalette = FOREVER

local function LookColor(key)
    if ns.db and ns.db.lookStyle == "forever" then return FOREVER[key] end
    -- BanzaiSland 0.2.0: parchment ink is applied by the text itself (Theme.InkWrap), so the neutral
    -- colours stay the glass ones here and every text reads back exactly what it was given
    return C[key]
end
ns.LookColor = LookColor

-- The user's pill/card colour (Modern style only). A surface that has its own default shade passes it
-- in; it is kept while the colour is still the default black, so untouched settings look the same.
function ns.ShellRGB(dr, dg, db_)
    local c = ns.db and ns.db.lookStyle ~= "forever" and ns.db.shellColor
    if c and (c[1] > 0.001 or c[2] > 0.001 or c[3] > 0.001) then return c[1], c[2], c[3] end
    -- BanzaiSland: an untouched shell colour means the material's own green-black, never black
    if Theme then
        local tr, tg, tb = Theme.ShellFill(1)
        return tr, tg, tb
    end
    return dr or 0, dg or 0, db_ or 0
end

-- your class colour (or the one a class colour addon sets)
local classColor
function ns.ClassColor()
    if classColor then return classColor end
    if not UnitClass then return nil end
    local _, cls = UnitClass("player")
    if not cls then return nil end
    local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[cls]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls])
    if not c and C_ClassColor and C_ClassColor.GetClassColor then
        local ok, cc = pcall(C_ClassColor.GetClassColor, cls)
        if ok then c = cc end
    end
    if c and c.r then classColor = { c.r, c.g, c.b } end
    -- BanzaiSland 0.3.0: the game's own colour goes through the theme (Priest marked for the parchment ink)
    if classColor and not (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[cls]) and Theme and Theme.ClassScreen then
        classColor = Theme.ClassScreen(cls) or classColor
    end
    return classColor
end

-- the XP bar's colour: the one you picked, or your class colour
function ns.BarColor()
    local db = ns.db
    if not db then return C.fg end
    if db.barMode == "class" then return ns.ClassColor() or db.xpColor end
    if db.barMode == "theme" and Theme then return Theme.Primary() end -- BanzaiSland accent theme
    return db.xpColor
end

-- one colour for the details: the bar colour, your class colour, or one you pick
function ns.Accent()
    local db = ns.db
    if not db then return C.fg end
    local mode = db.accentMode or "bar"
    if mode == "theme" and Theme then return Theme.Primary() end -- BanzaiSland accent theme
    if mode == "class" then return ns.ClassColor() or ns.BarColor() or C.fg end
    if mode == "custom" and db.accent then return db.accent end
    return ns.BarColor() or C.fg
end

-- Sizes of the island in each state: width, height, corner radius.
local STATES = {
    idle    = { w = 208, h = 36,  r = 18, layer = "compact" },
    gain    = { w = 292, h = 36,  r = 18, layer = "compact" },
    toast   = { w = 364, h = 80,  r = 27, layer = "toast" },
    levelup = { w = 364, h = 136, r = 34, layer = "level" },
    detail  = { w = 364, h = 206, r = 34, layer = "detail" },
}
local WIDE = 364
ns.STATES, ns.WIDE = STATES, WIDE
local ROLL_H = 52
local DND_TONE = { 0.98, 0.66, 0.28 }
local STIFF, DAMP = 256, 20        -- island spring: quick with a small overshoot
local FADE = 1                     -- how long content fades take, as a share of normal

-- Animation feel: how bouncy the springs are and how quickly cards open and close.
local FEELS = {
    snappy = { 420, 31, 0.7 },
    smooth = { 256, 20, 1 },
    calm   = { 140, 20, 1.4 },
}
function ns.ApplyFeel()
    local f = FEELS[ns.db and ns.db.feel or "smooth"] or FEELS.smooth
    STIFF, DAMP, FADE = f[1], f[2], f[3]
end

-- the island's current spring (stiffness, damping), for panels that open with the same feel
function ns.SpringFeel() return STIFF, DAMP end

local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end

-- ---------------------------------------------------------------- building blocks

local FONTS = { medium = "OpenSans-Medium.ttf", bold = "OpenSans-Bold.ttf", extra = "OpenSans-ExtraBold.ttf" }

-- Fonts: Open Sans has no Korean or Chinese letters, so those clients get the game's own font
-- unless the player picks otherwise. "Font" in Look can also pick any LibSharedMedia font.
local CJK = { koKR = true, zhCN = true, zhTW = true }
local function GameFont() return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end
function ns.FontChoice()
    local pick = ns.db and ns.db.font or "auto"
    if pick == "auto" then pick = CJK[GetLocale and GetLocale() or ""] and "game" or "island" end
    return pick
end
function ns.FontPath(weight)
    -- BanzaiSland: the display weight is the theme's display face (titles, headlines, large labels); when the
    -- display font is off for this locale it falls back to the information font's heaviest weight
    if weight == "display" then
        local display = Theme and Theme.DisplayFontPath()
        if display then return display end
        weight = "extra"
    end
    local pick = ns.FontChoice()
    if pick == "game" then return GameFont() end
    if pick ~= "island" then
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        local path = LSM and LSM:Fetch("font", pick, true)
        if path then return path end
    end
    return MEDIA .. "Fonts\\" .. (FONTS[weight] or FONTS.medium)
end
BanzaiSland_FontPath = function(weight) return ns.FontPath(weight) end

-- every piece of text remembers its weight and size so a font or size change can redo it;
-- text on the island and its cards also follows the "Text size" setting, the settings window does not
local texts = setmetatable({}, { __mode = "k" })
local function OnIsland(frame)
    local top = ns.Island and ns.Island.anchor
    local n = 0
    while frame and top and n < 30 do
        if frame == top then return true end
        frame = frame.GetParent and frame:GetParent()
        n = n + 1
    end
    return false
end
-- BanzaiSland: on the island's sheet itself (the island frame and its card layers), where the parchment
-- material paints paper under the text; bubbles, pins and the warning dot stay glass and are not here
local function OnSheet(frame)
    local sheet = ns.Island and ns.Island.island
    local n = 0
    while frame and sheet and n < 30 do
        if frame == sheet then return true end
        frame = frame.GetParent and frame:GetParent()
        n = n + 1
    end
    return false
end
ns.OnSheet = OnSheet
-- Font outline: none, thin (OUTLINE) or thick (THICKOUTLINE)
local OUTLINES = { thin = "OUTLINE", thick = "THICKOUTLINE" }
function ns.FontFlags() return OUTLINES[ns.db and ns.db.fontOutline or "none"] or "" end
local function SetFace(fs, weight, size)
    local base = texts[fs]
    local flags = (base and base.flags) or ns.FontFlags() -- BanzaiSland: a text may pin its own outline
    local fallback = weight == "display" and ns.FontPath("extra") or GameFont()
    local font
    if weight == "display" then
        local text = fs.GetText and fs:GetText()
        font = Theme.DisplayFontPath(text)
        if font then size = size * Theme.DisplayFontScale(text) else font = fallback end
    else
        font = ns.FontPath(weight)
    end
    local ok = fs:SetFont(font or fallback, size, flags)
    if ok == false or not fs:GetFont() then
        fs:SetFont(fallback, size, flags)
    end
end
-- BanzaiSland: pin a font outline on one tracked text (the SLAND mark), kept across font and size changes
function ns.TextFlags(fs, flags)
    local base = texts[fs]
    if not base then return end
    base.flags = flags
    SetFace(fs, base[1], (base[4] or base[2]) * (base[3] and (ns.db and ns.db.textScale or 1) or 1))
end
local function Scale(base) return base[3] and (ns.db and ns.db.textScale or 1) or 1 end
-- Resize tracked text, including builder previews; only island text follows Text size.
function ns.ResizeText(fs, size)
    local base = texts[fs]
    if not base then return end
    if base[4] == size then return end
    base[2], base[4] = size, size
    SetFace(fs, base[1], size * Scale(base))
end

-- redo every piece of text: after a text size or font change
function ns.ApplyTextSize()
    for fs, base in pairs(texts) do SetFace(fs, base[1], base[2] * Scale(base)) end
end
ns.ApplyFont = ns.ApplyTextSize

-- for edit boxes and other text made outside ns.Text: use the chosen font and follow changes to it
function ns.UseFont(obj, weight, size)
    texts[obj] = { weight, size, false }
    SetFace(obj, weight, size)
end

function ns.Text(parent, weight, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local base = { weight, size, OnIsland(parent) }
    texts[fs] = base
    SetFace(fs, weight, size * Scale(base))
    -- BanzaiSland: text on the sheet shows its parchment ink while that material is on
    if Theme and Theme.InkWrap and base[3] and OnSheet(parent) then Theme.InkWrap(fs) end
    color = color or C.fg
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetJustifyH(justify or "LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end

local function Smooth(tex)
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
end

local function Solid(frame, layer, sub)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetColorTexture(1, 1, 1, 1)
    Smooth(t)
    return t
end

local function Image(frame, file, layer, sub)
    local t = frame:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    t:SetTexture(MEDIA .. file)
    Smooth(t)
    return t
end
ns.Image = Image

-- A hollow rounded ring around `frame`'s inner shape: `r` is the inner radius, `thick` the width.
-- Only the ring is painted, so whatever is inside (a see-through island) is never tinted.
function ns.CreateRing(frame)
    local ring = {}
    local corners, strips = {}, {}
    for i = 1, 4 do
        corners[i] = Image(frame, "CornerRing", "BACKGROUND", 0)
        strips[i] = Solid(frame, "BACKGROUND", 0)
        -- corners and strips all snap to the pixel grid, so every side comes out the same thickness
        if corners[i].SetSnapToPixelGrid then corners[i]:SetSnapToPixelGrid(true) end
        if strips[i].SetSnapToPixelGrid then strips[i]:SetSnapToPixelGrid(true) end
    end
    ring.corners, ring.strips = corners, strips -- BanzaiSland: the renderer paints gradient rings
    local lastBin
    function ring:SetColor(r, g, b, a)
        for i = 1, 4 do
            corners[i]:SetVertexColor(r, g, b, a or 1)
            strips[i]:SetVertexColor(r, g, b, a or 1)
        end
    end
    function ring:SetRadius(r, thick)
        local R = r + thick
        local bin = clamp(floor(r / R * 32), 0, 31)   -- cell b holds ratio (b + 0.5) / 32
        if bin ~= lastBin then
            lastBin = bin
            local x, y = (bin % 8) * 64, floor(bin / 8) * 64
            local l, rr, t, bt = (x + 0.5) / 512, (x + 63.5) / 512, (y + 0.5) / 256, (y + 63.5) / 256
            corners[1]:SetTexCoord(l, rr, t, bt)
            corners[2]:SetTexCoord(rr, l, t, bt)
            corners[3]:SetTexCoord(l, rr, bt, t)
            corners[4]:SetTexCoord(rr, l, bt, t)
        end
        local pts = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
        for i = 1, 4 do
            corners[i]:ClearAllPoints()
            corners[i]:SetPoint(pts[i], frame, pts[i], 0, 0)
            corners[i]:SetSize(R, R)
        end
        local t1, t2, t3, t4 = strips[1], strips[2], strips[3], strips[4]
        t1:ClearAllPoints() t1:SetPoint("TOPLEFT", frame, "TOPLEFT", R, 0) t1:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -R, -thick)
        t2:ClearAllPoints() t2:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", R, 0) t2:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -R, thick)
        t3:ClearAllPoints() t3:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -R) t3:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", thick, R)
        t4:ClearAllPoints() t4:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -R) t4:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -thick, R)
    end
    return ring
end

-- A rounded rectangle that fills `frame`, with a radius that can change every frame.
function ns.CreateBody(frame, layer, sub, overlap)
    local b = {}
    -- pieces meet edge to edge: any overlap shows as faint lines whenever the island is see-through
    -- (the opacity setting, or dimmed in combat)
    overlap = overlap or 0
    local function corner(point, l, r, t, bt)
        local tex = Image(frame, "Corner", layer or "BACKGROUND", sub)
        tex:SetTexCoord(l, r, t, bt)
        tex:SetPoint(point, frame, point, 0, 0)
        return tex
    end
    local tl = corner("TOPLEFT", 0, 1, 0, 1)
    local tr = corner("TOPRIGHT", 1, 0, 0, 1)
    local bl = corner("BOTTOMLEFT", 0, 1, 1, 0)
    local br = corner("BOTTOMRIGHT", 1, 0, 1, 0)
    local top, mid, bot = Solid(frame, layer, sub), Solid(frame, layer, sub), Solid(frame, layer, sub)
    local all = { tl, tr, bl, br, top, mid, bot }

    -- The pieces overlap by a hair so no seam shows on a solid body. A see-through body must not
    -- overlap at all, or the doubled-up strips show as faint lines.
    local solid, lastR = true, nil
    local trim, trimBin, trimShown
    local cornerLimit, cornerBase
    local function PaintRadius(r)
        if not (r and cornerLimit) then return r end
        local grow = cornerBase and max(0, (frame:GetHeight() - cornerBase:GetHeight()) / 2) or 0
        return min(r, cornerLimit + grow)
    end
    local styled, shaded, shadeH, shadeR, fillColors, white, lowerMid, fillAlpha
    local function ShadeColor(color, y, h)
        local p = clamp(y * 2 / h, 0, 2)
        local topColor, bottomColor = FOREVER.fillTop, FOREVER.fillMiddle
        if p > 1 then p, topColor, bottomColor = p - 1, FOREVER.fillMiddle, FOREVER.fillBottom end
        local cr = topColor[1] + (bottomColor[1] - topColor[1]) * p
        local cg = topColor[2] + (bottomColor[2] - topColor[2]) * p
        local cb = topColor[3] + (bottomColor[3] - topColor[3]) * p
        if color.SetRGBA then color:SetRGBA(cr, cg, cb, 1)
        else color.r, color.g, color.b, color.a = cr, cg, cb, 1 end
    end
    local function ShadeFill(r)
        if not styled then
            if shaded then
                for _, tex in ipairs(all) do tex:SetGradient("VERTICAL", white, white) end
                lowerMid:Hide()
                mid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, PaintRadius(lastR))
                shaded, shadeH, shadeR = false, nil, nil
            end
            return
        end
        local h = frame:GetHeight()
        if not h or h <= 0 or not r then return end
        if shaded and h == shadeH and r == shadeR then
            mid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, h / 2)
            return
        end
        if not fillColors then
            fillColors = {}
            white = CreateColor(1, 1, 1, 1)
            lowerMid = Solid(frame, layer, sub)
            all[#all + 1] = lowerMid
            lowerMid:SetAlpha(fillAlpha or 1)
            if lowerMid.SetSnapToPixelGrid then lowerMid:SetSnapToPixelGrid(not solid) end
            for i = 1, #all do fillColors[i] = { CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1) } end
        end
        -- Only the middle strip crosses the highlight. Split it at the centre rather than
        -- put another translucent fill on top of it; the two halves still meet edge to edge.
        mid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, h / 2)
        lowerMid:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -h / 2)
        lowerMid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, r)
        lowerMid:Show()
        for i, tex in ipairs(all) do
            local y1, y2 = 0, r
            if i == 3 or i == 4 or i == 7 then y1, y2 = h - r, h
            elseif i == 6 then y1, y2 = r, h / 2
            elseif i == 8 then y1, y2 = h / 2, h - r end
            local colors = fillColors[i]
            -- Each piece samples one shared vertical ramp, so their touching edges have
            -- identical colours without layering another see-through fill over the body.
            ShadeColor(colors[1], y2, h)
            ShadeColor(colors[2], y1, h)
            tex:SetGradient("VERTICAL", colors[1], colors[2])
        end
        shaded, shadeH, shadeR = true, h, r
    end
    local function LayoutTrim(r)
        if not trim then return end
        -- Each atlas cell keeps a roughly two-unit bevel at its reference radius. Using
        -- the same ratio for straight edges makes the corner joins meet exactly.
        local bin = clamp(floor((r - 6) / 2 + 0.5), 0, 15)
        local thickness = 2 * r / (6 + bin * 2)
        if trimBin ~= bin then
            trimBin = bin
            local x, y = (bin % 4) * 128, floor(bin / 4) * 128
            local l, rr, t, bt = (x + 2) / 512, (x + 126) / 512, (y + 2) / 512, (y + 126) / 512
            trim[1]:SetTexCoord(l, rr, t, bt)
            trim[2]:SetTexCoord(rr, l, t, bt)
            trim[3]:SetTexCoord(l, rr, bt, t)
            trim[4]:SetTexCoord(rr, l, bt, t)
            -- Sample the cell's straight end of the annulus for each edge. The same
            -- radial lighting gives corners and strips an identical dark inner lip.
            local u, outer = (x + 125.5) / 512, (y + 2) / 512
            local inner = (y + 2 + 248 / (6 + bin * 2)) / 512
            trim[5]:SetTexCoord(u, outer, u, inner, u, outer, u, inner)
            trim[6]:SetTexCoord(u, inner, u, outer, u, inner, u, outer)
            trim[7]:SetTexCoord(u, outer, u, outer, u, inner, u, inner)
            trim[8]:SetTexCoord(u, inner, u, inner, u, outer, u, outer)
        end
        for i = 1, 4 do trim[i]:SetSize(r, r) end
        trim[5]:SetPoint("TOPLEFT", frame, "TOPLEFT", r, 0)
        trim[5]:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -r, -thickness)
        trim[6]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", r, 0)
        trim[6]:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -r, thickness)
        trim[7]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -r)
        trim[7]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", thickness, r)
        trim[8]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -r)
        trim[8]:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -thickness, r)
    end
    function b:SetRadius(r)
        lastR = r
        r = PaintRadius(r)
        tl:SetSize(r, r) tr:SetSize(r, r) bl:SetSize(r, r) br:SetSize(r, r)
        local o = solid and overlap or 0
        top:SetPoint("TOPLEFT", frame, "TOPLEFT", r - o, 0)
        top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -r + o, -r)
        bot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", r - o, 0)
        bot:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -r + o, r)
        mid:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -r + o)
        mid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, r - o)
        ShadeFill(r)
        LayoutTrim(r)
    end
    -- A pulse keeps its own colour, but follows the shell's corners as it grows outward.
    function b:GetPaintRadius() return lastR and PaintRadius(lastR) or nil end
    function b:SetCornerLimit(limit, baseFrame)
        cornerLimit, cornerBase = limit, baseFrame
        if lastR then self:SetRadius(lastR) end
    end
    function b:SetColor(r, g, bl_, a)
        for i = 1, #all do all[i]:SetVertexColor(r, g, bl_, a or 1) end
        local was = solid
        solid = (a or 1) >= 0.999
        if solid ~= was then
            -- see-through: snap every piece to the pixel grid so neighbouring edges land on the same
            -- pixel (no sub-pixel coverage seams); solid keeps the smooth, overlapping pieces
            for i = 1, #all do
                local t = all[i]
                if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(not solid) end
                if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
            end
            if lastR then b:SetRadius(lastR) end
        end
    end
    -- Opt in only the island's visible shells. Settings controls and the level-up pulse
    -- also use CreateBody, and must retain their own colours.
    function b:SetStyle(style, opacity, plaque, tint)
        local forever = style == "forever"
        trimShown = forever
        local a = opacity or 1
        local previousLimit = cornerLimit
        cornerLimit = forever and plaque and 8 or nil
        cornerBase = nil
        styled = forever and CreateColor and all[1].SetGradient and true or false
        if not styled then ShadeFill(lastR) end
        -- SetVertexColor replaces the texture's vertex gradient in the client. Repaint after
        -- an explicit style/opacity update, while keeping settled radius updates cached.
        if styled then
            shadeH, shadeR = nil, nil
            fillAlpha = a
        end
        local fill = forever and FOREVER.fill
        -- Modern style only: the material's shell (BanzaiSland: green-black glass or solid), or the
        -- user's own pill/card colour when one was picked
        if not forever and tint ~= false then
            if Theme then
                local tr, tg, tb, ta = Theme.ShellFill(a)
                fill = { ns.ShellRGB(tr, tg, tb) }
                a = ta
            elseif ns.db and ns.db.shellColor then
                fill = ns.db.shellColor
            end
        end
        self:SetColor(styled and 1 or (fill and fill[1] or 0), styled and 1 or (fill and fill[2] or 0),
            styled and 1 or (fill and fill[3] or 0), a)
        -- The spring keeps its original radius. Only the painted main/card shell is squared;
        -- redraw immediately on a style switch even when opacity has not changed.
        if previousLimit ~= cornerLimit and lastR then self:SetRadius(lastR)
        elseif styled then ShadeFill(PaintRadius(lastR)) end
        if styled then
            -- Region alpha survives gradient/vertex repainting; do not rely on their alpha
            -- values multiplying together. This also includes the lazily created lower half.
            for _, tex in ipairs(all) do tex:SetAlpha(a) end
        elseif fillAlpha then
            for _, tex in ipairs(all) do tex:SetAlpha(1) end
            fillAlpha = nil
        end
        if forever and not trim then
            local function edgeCorner(point, left, right, top_, bottom)
                local tex = Image(frame, "CornerBronze", layer or "BACKGROUND", (sub or 0) + 1)
                tex:SetTexCoord(left, right, top_, bottom)
                tex:SetPoint(point, frame, point, 0, 0)
                return tex
            end
            trim = {
                edgeCorner("TOPLEFT", 0, 1, 0, 1),
                edgeCorner("TOPRIGHT", 1, 0, 0, 1),
                edgeCorner("BOTTOMLEFT", 0, 1, 1, 0),
                edgeCorner("BOTTOMRIGHT", 1, 0, 1, 0),
                Image(frame, "CornerBronze", layer or "BACKGROUND", (sub or 0) + 1), Image(frame, "CornerBronze", layer or "BACKGROUND", (sub or 0) + 1),
                Image(frame, "CornerBronze", layer or "BACKGROUND", (sub or 0) + 1), Image(frame, "CornerBronze", layer or "BACKGROUND", (sub or 0) + 1),
            }
            for i, tex in ipairs(trim) do
                -- The annular corners and straight edges meet without overlapping. Match the
                -- fill's snapped endpoints even while a translucent card is changing radius.
                if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(true) end
                if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
                local topColor = i <= 2 and FOREVER.light or FOREVER.edge
                local bottomColor = FOREVER.edge
                if i == 5 then topColor, bottomColor = FOREVER.light, FOREVER.light end
                if i == 6 then topColor, bottomColor = FOREVER.edge, FOREVER.edge end
                if tex.SetGradient and CreateColor then
                    tex:SetGradient("VERTICAL", CreateColor(bottomColor[1], bottomColor[2], bottomColor[3], 1),
                        CreateColor(topColor[1], topColor[2], topColor[3], 1))
                else
                    tex:SetVertexColor(FOREVER.edge[1], FOREVER.edge[2], FOREVER.edge[3], 1)
                end
            end
            if lastR then LayoutTrim(PaintRadius(lastR)) end
        end
        if trim then
            for _, tex in ipairs(trim) do
                tex:SetAlpha(a)
                tex:SetShown(forever)
            end
        end
    end
    function b:SetShown(show)
        for _, tex in ipairs(all) do tex:SetShown(show) end
        if lowerMid then lowerMid:SetShown(show and styled) end
        if trim then for _, tex in ipairs(trim) do tex:SetShown(show and trimShown) end end
    end
    -- BanzaiSland: a two-colour gradient over the whole body (settings thumb and wells); SetColor undoes it
    function b:SetGradient(orientation, from, to, alpha)
        for _, tex in ipairs(all) do
            if tex.SetGradient and CreateColor then
                tex:SetVertexColor(1, 1, 1, 1)
                tex:SetGradient(orientation, CreateColor(from[1], from[2], from[3], alpha or 1), CreateColor(to[1], to[2], to[3], alpha or 1))
            else
                tex:SetVertexColor((from[1] + to[1]) / 2, (from[2] + to[2]) / 2, (from[3] + to[3]) / 2, alpha or 1)
            end
        end
    end
    return b
end

-- BanzaiSland: a control surface with the pill's small interface (SetWidth, SetColor) on a softly
-- chamfered body that fills its frame; the settings window's buttons, menus and fields use it
function ns.CreateControl(frame, radius, layer, sub)
    local body = ns.CreateBody(frame, layer or "ARTWORK", sub or 0)
    body:SetRadius(radius or (Theme and Theme.UI.radius) or 6)
    local c = { body = body }
    function c:SetWidth() end          -- the body follows the frame
    function c:SetOffset() end
    function c:SetColor(r, g, b, a) body:SetColor(r, g, b, a) end
    function c:SetGradient(...) body:SetGradient(...) end
    function c:SetShown(v) body:SetShown(v) end
    function c:SetRadius(r) body:SetRadius(r) end
    return c
end

-- A horizontal capsule anchored to the left of `frame`.
function ns.CreatePill(frame, h, layer, sub)
    local p = {}
    local l = Image(frame, "Circle", layer, sub)
    l:SetTexCoord(0, 0.5, 0, 1)
    l:SetSize(h / 2, h)
    l:SetPoint("LEFT", frame, "LEFT", 0, 0)
    local m = Solid(frame, layer, sub)
    m:SetHeight(h)
    m:SetPoint("LEFT", l, "RIGHT", 0, 0)
    local r = Image(frame, "Circle", layer, sub)
    r:SetTexCoord(0.5, 1, 0, 1)
    r:SetSize(h / 2, h)
    r:SetPoint("LEFT", m, "RIGHT", 0, 0)

    function p:SetWidth(w)
        local show = w >= 0.5
        l:SetShown(show) m:SetShown(show) r:SetShown(show)
        if show then m:SetWidth(max(0.01, w - h)) end
    end
    function p:SetOffset(x)
        l:ClearAllPoints()
        l:SetPoint("LEFT", frame, "LEFT", x, 0)
    end
    function p:SetColor(cr, cg, cb, a)
        l:SetVertexColor(cr, cg, cb, a or 1)
        m:SetVertexColor(cr, cg, cb, a or 1)
        r:SetVertexColor(cr, cg, cb, a or 1)
    end
    return p
end

-- Card controls keep the pill's tiny interface so secure hover overlays and the selected
-- answer animation can repaint them without knowing which material is showing.
local cardButtons = setmetatable({}, { __mode = "k" })
function ns.CreateCardButton(frame, h)
    local p = { color = { 1, 1, 1, 0.10 }, textColor = C.fg }
    local pill = ns.CreatePill(frame, h, "ARTWORK", 0)
    local shell
    function p:ApplyStyle()
        local forever = ns.db and ns.db.lookStyle == "forever"
        local color = self.color
        if forever then
            if not shell then
                shell = ns.CreateBody(frame, "ARTWORK", 0)
                shell:SetRadius(6)
            end
            if not self.forever then
                pill:SetWidth(0)
                shell:SetStyle("forever", 1)
                shell:SetShown(true)
            end
            local blend = clamp((color[4] - 0.10) / 0.10, 0, 1)
            local brightness = FOREVER.buttonShade + (FOREVER.buttonHover - FOREVER.buttonShade) * blend
            -- Vertex colour replaces the gradient, so write the charcoal material itself
            -- rather than a near-white multiplier that turns the button pale gray.
            local fill = FOREVER.fill
            shell:SetColor(fill[1] * color[1] * brightness, fill[2] * color[2] * brightness,
                fill[3] * color[3] * brightness, 1)
        else
            if shell and self.forever then shell:SetShown(false) end
            if self.width then pill:SetWidth(self.width) end
            pill:SetColor(color[1], color[2], color[3], color[4])
        end
        self.forever = forever
        if frame.text then
            local tc = self.textColor
            if forever then
                if tc == C.fg then tc = FOREVER.fg elseif tc == C.muted then tc = FOREVER.muted end
            end
            frame.text:SetTextColor(tc[1], tc[2], tc[3])
        end
    end
    function p:SetWidth(w)
        self.width = w
        if ns.db and ns.db.lookStyle == "forever" then pill:SetWidth(0) else pill:SetWidth(w) end
    end
    function p:SetColor(r, g, b, a)
        local color = self.color
        color[1], color[2], color[3], color[4] = r, g, b, a or 1
        self:ApplyStyle()
    end
    function p:SetTextColor(color)
        self.textColor = color
        local tc = color
        if ns.db and ns.db.lookStyle == "forever" then
            if tc == C.fg then tc = FOREVER.fg elseif tc == C.muted then tc = FOREVER.muted end
        end
        frame.text:SetTextColor(tc[1], tc[2], tc[3])
    end
    -- BanzaiSland: colour by role (primary / alt / decline) from the theme; `hover` brightens, `muted` greys
    function p:SetRole(role, hover, muted)
        if not Theme then
            self:SetColor(1, 1, 1, hover and 0.20 or 0.10)
            self:SetTextColor(muted and C.muted or C.fg)
            return
        end
        local r, g, b, a, text = Theme.ButtonColors(role or "primary", hover, muted)
        self:SetColor(r, g, b, a)
        self:SetTextColor(text)
    end
    cardButtons[p] = true
    return p
end
function ns.RefreshCardButtons()
    for button in pairs(cardButtons) do button:ApplyStyle() end
end

-- An item icon with rounded corners.
function ns.RoundIcon(frame, size)
    local t = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    t:SetSize(size, size)
    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if frame.CreateMaskTexture and t.AddMaskTexture then
        local ok, mask = pcall(frame.CreateMaskTexture, frame)
        if ok and mask then
            mask:SetTexture(MEDIA .. "Tile", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(t)
            t:AddMaskTexture(mask)
        end
    end
    return t
end

-- Progress bar: track, rested reach, fill.
local function CreateBar(parent, h, withRest)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(h)
    f.h = h
    f.track = ns.CreatePill(f, h, "ARTWORK", 0)
    if Theme then f.track:SetColor(Theme.Track()) else f.track:SetColor(1, 1, 1, 0.13) end
    if withRest then
        f.quest = ns.CreatePill(f, h, "ARTWORK", 1)       -- quest XP waiting, after the rested part
        f.rest = ns.CreatePill(f, h, "ARTWORK", 2)
    end
    f.fill = ns.CreatePill(f, h, "ARTWORK", 3)
    function f:ApplyStyle(style)
        local forever = style == "forever"
        if forever and not self.ticks then
            self.ticks = {}
            for i = 1, 9 do
                local tick = Solid(self, "ARTWORK", 4)
                tick:SetWidth(1)
                tick:SetPoint("TOP", self, "TOPLEFT", 0, 0)
                tick:SetPoint("BOTTOM", self, "BOTTOMLEFT", 0, 0)
                tick:SetVertexColor(FOREVER.tick[1], FOREVER.tick[2], FOREVER.tick[3], FOREVER.tick[4])
                if tick.SetSnapToPixelGrid then tick:SetSnapToPixelGrid(true) end
                self.ticks[i] = tick
            end
        end
        if forever then
            self.track:SetColor(FOREVER.track[1], FOREVER.track[2], FOREVER.track[3], FOREVER.track[4])
        elseif Theme then
            self.track:SetColor(Theme.Track())
        else
            self.track:SetColor(1, 1, 1, 0.13)
        end
        if self.ticks then for _, tick in ipairs(self.ticks) do tick:SetShown(forever) end end
        self.tickWidth = nil
    end
    function f:Set(p, r, q)
        local w = self:GetWidth() or 0
        if w <= 0 then return end
        if self.ticks and self.tickWidth ~= w then
            self.tickWidth = w
            for i, tick in ipairs(self.ticks) do
                tick:SetPoint("TOP", self, "TOPLEFT", w * i / 10, 0)
                tick:SetPoint("BOTTOM", self, "BOTTOMLEFT", w * i / 10, 0)
            end
        end
        self.track:SetWidth(w)
        self.fill:SetWidth(p > 0.001 and max(self.h, w * p) or 0)
        if self.rest then self.rest:SetWidth(r > p + 0.002 and max(self.h, w * r) or 0) end
        if self.quest then
            q = q or 0
            local base = max(p, r)
            if q > base + 0.002 then
                local x = max(0, w * base - self.h / 2)          -- tucked under the part before it
                self.quest:SetOffset(x)
                self.quest:SetWidth(max(self.h, w * q - x))
            else
                self.quest:SetWidth(0)
            end
        end
    end
    return f
end
ns.CreateBar = CreateBar

-- ---------------------------------------------------------------- island

local I = { queue = {}, held = {}, history = {}, acts = {}, liveT = 0, state = "idle", p = 0, pT = 0, r = 0, rT = 0, q = 0, qT = 0, hit = 0, amtA = 0, amtT = 0,
            stateT = 0, detailT = 0, awake = true }
ns.Island = I

local function Spring(v) return { x = v, v = 0, t = v } end
local function Step(s, dt, k, c)
    s.v = s.v + (-k * (s.x - s.t) - c * s.v) * dt
    s.x = s.x + s.v * dt
end
local function Resting(s) return abs(s.x - s.t) < 0.05 and abs(s.v) < 0.5 end

function I:Build()
    if self.built then return end
    local db = ns.db

    local anchor = CreateFrame("Frame", "BanzaiSlandAnchor", UIParent)
    anchor:SetSize(2, 2)
    anchor:SetFrameStrata("HIGH")
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    self.anchor = anchor

    -- gold ring that pulses out on level up (sits behind the island)
    local ring = CreateFrame("Frame", nil, anchor)
    ring:SetFrameLevel(anchor:GetFrameLevel() + 1)
    ring.body = ns.CreateBody(ring, "BACKGROUND", 0, 0)
    ring.body:SetColor(C.gold[1], C.gold[2], C.gold[3], 1)
    ring:Hide()
    self.ring = ring

    local island = CreateFrame("Frame", "BanzaiSlandFrame", anchor)
    island:SetFrameLevel(anchor:GetFrameLevel() + 3)
    island:SetSize(STATES.idle.w, STATES.idle.h)
    if island.SetClipsChildren then island:SetClipsChildren(true) end
    island:EnableMouse(true)
    island:RegisterForDrag("LeftButton")
    self.island = island
    ring:SetPoint("CENTER", island, "CENTER", 0, 0)

    self.body = ns.CreateBody(island, "BACKGROUND", 0)
    self.body:SetColor(0, 0, 0, 1)

    -- optional border: its own frame pinned to every corner of the island, so it follows each size
    local border = CreateFrame("Frame", nil, anchor, BackdropTemplateMixin and "BackdropTemplate" or nil)
    border:SetFrameLevel(island:GetFrameLevel() + 10)
    border:SetPoint("TOPLEFT", island, "TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", island, "BOTTOMRIGHT", 0, 0)
    border:EnableMouse(false)
    border:Hide()
    self.border = border
    -- rounded ring for the plain-colour border: a second body just outside the island, behind it,
    -- so the border follows the pill's corners at every size
    local ringFrame = CreateFrame("Frame", nil, anchor)
    ringFrame:SetFrameLevel(max(0, island:GetFrameLevel() - 1))
    ringFrame:EnableMouse(false)
    ringFrame:Hide()
    self.borderRing = ringFrame
    self.borderRingBody = ns.CreateRing(ringFrame)

    self.sw, self.sh, self.sr = Spring(STATES.idle.w), Spring(STATES.idle.h), Spring(STATES.idle.r)
    self.roll = Spring(0)
    self.warn = Spring(0)
    self.errS = Spring(0)
    self.warnings = self.warnings or {}

    self.layers = {}
    self.bars = {}
    self:BuildCompact()
    self:BuildToast()
    self:BuildLevel()
    self:BuildDetail()
    self:BuildBubble()
    self:BuildWarnDot()
    self:BuildErrorPill()
    if self.BuildRoll then self:BuildRoll() end

    for name, l in pairs(self.layers) do
        l.a = (name == "compact") and 1 or 0
        l.target = l.a
        l.delay = 0
        l:SetAlpha(l.a)
        l:SetShown(l.a > 0)
    end

    island:SetScript("OnEnter", function() I.hover = true I:Settle() end)
    island:SetScript("OnLeave", function()
        I.hover = island.IsMouseOver and island:IsMouseOver() or false
        I:Settle()
    end)
    island:SetScript("OnMouseUp", function(_, button)
        if I.dragging then return end
        if button == "LeftButton" and IsAltKeyDown and IsAltKeyDown() then
            ns.SetDND(not ns.db.dnd)
        elseif button == "RightButton" then
            ns.ToggleSettings()
        elseif button == "LeftButton" and ns.db.locked then
            -- pinning the details only makes sense on the plain island; a click that lands on a
            -- card (or just after one closes) must not leave the details pinned open
            if I.state ~= "idle" and I.state ~= "detail" then return end
            if I.current or (I.rolls and #I.rolls > 0) then return end
            I.pinned = not I.pinned
            I:Settle()
        end
    end)
    if island.EnableMouseWheel then
        island:EnableMouseWheel(true)
        island:SetScript("OnMouseWheel", function(_, delta) I:ShowHistory(delta > 0 and 1 or -1) end)
    end
    island:SetScript("OnDragStart", function() I:StartDrag() end)
    island:SetScript("OnDragStop", function() I:StopDrag() end)

    anchor:SetScript("OnUpdate", function(_, dt) I:OnUpdate(dt) end)

    -- BanzaiSland: the chassis dressing (bamboo caps, hairlines, parchment, class badges)
    if ns.Renderer then ns.Renderer.Decorate(self) end

    self.built = true
    self.islA, self.ancA = 1, 1
    self:ApplyLook()
    if ns.db.dnd then ns.SetDND(true) end
end

-- Where the island sits. "top" and "bottom" are fixed spots; "free" puts the centre of the resting
-- island at (cx, cy): screen pixels from the middle of the screen, right and up. The anchor is the
-- size of the resting island and sits exactly where it rests, so edit modes can grab it.
-- Below the middle of the screen the island grows upward, so cards stay on screen.
local BOTTOM_Y = 150
function I:ApplyPosition()
    local db, a, isl = ns.db, self.anchor, self.island
    local sc = db.scale or 1
    a:SetScale(sc)
    a:SetSize(STATES.idle.w, STATES.idle.h)
    a:ClearAllPoints()
    local where = db.position or "top"
    local up
    if where == "bottom" then
        a:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, BOTTOM_Y / sc)
        up = true
    elseif where == "free" then
        if db.cx == nil or db.cy == nil then
            -- older versions kept the island's top edge from the top of the screen
            db.cx = (db.x or 0) * sc
            db.cy = UIParent:GetHeight() / 2 + ((db.y or -14) - 18) * sc
        end
        a:SetPoint("CENTER", UIParent, "CENTER", db.cx / sc, db.cy / sc)
        up = db.cy < 0
    else
        a:SetPoint("TOP", UIParent, "TOP", 0, -14)
        up = false
    end
    -- "Opens" setting: force cards down or up; auto keeps the screen-half rule above
    -- If the forced direction would push the tallest card (the details) off the screen, open the
    -- other way instead, as long as that way fits better.
    if db.growY == "up" or db.growY == "down" then
        up = db.growY == "up"
        local top, bottom, sh = a:GetTop(), a:GetBottom(), UIParent:GetHeight()
        if top and bottom and sh and sh > 0 then
            local k = a:GetEffectiveScale() / UIParent:GetEffectiveScale()
            local need = STATES.detail.h * sc
            local roomUp = sh - bottom * k          -- space from the island's bottom edge to the top of the screen
            local roomDown = top * k                -- space from its top edge to the bottom of the screen
            if up and roomUp < need and roomDown > roomUp then up = false
            elseif not up and roomDown < need and roomUp > roomDown then up = true end
        end
    end
    self.up = up
    -- horizontal grow point: "left" keeps the island's left edge fixed (grows right), "right" the
    -- right edge; otherwise it grows from the centre. Auto picks by the outer thirds of the screen.
    local gx = db.growX or "auto"
    if gx == "auto" then
        gx = "center"
        if where == "free" then
            local sw = UIParent:GetWidth()
            if sw and sw > 0 then
                local f = (db.cx + sw / 2) / sw
                if f < 1 / 3 then gx = "left" elseif f > 2 / 3 then gx = "right" end
            end
        end
    end
    if gx ~= "left" and gx ~= "right" then gx = nil end
    self.gx = gx
    local hp = gx == "left" and "LEFT" or gx == "right" and "RIGHT" or ""
    isl:ClearAllPoints()
    if up then
        isl:SetPoint("BOTTOM" .. hp, a, "BOTTOM" .. hp, 0, 0)    -- the bottom edge stays put; cards open upward
    else
        isl:SetPoint("TOP" .. hp, a, "TOP" .. hp, 0, 0)
    end
    for _, l in pairs(self.layers or {}) do
        if l.fixedLayer then
            l:ClearAllPoints()
            l:SetPoint("TOP" .. hp, isl, "TOP" .. hp, 0, 0)
        end
    end
    if self.editFrame then self:PaintEdit() end
    self.awake = true
end

-- the resting island's centre as (cx, cy) from the middle of the screen, read from where it is now
function I:ReadCenter()
    local a = self.anchor
    local x, y = a:GetCenter()
    if not x then return nil end
    local ux, uy = UIParent:GetCenter()
    local k = a:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * k - ux, y * k - uy
end

-- move to a spot (screen pixels from the middle); switches to free placement
function I:MoveTo(cx, cy)
    ns.db.cx, ns.db.cy = cx, cy
    ns.db.position = "free"
    self:ApplyPosition()
    if ns.RefreshSettings then ns.RefreshSettings() end
end

function I:StartDrag()
    if ns.db.locked and not self.editing then return end
    self.dragging = true
    self.pinned = false
    if GameTooltip then GameTooltip:Hide() end
    self:Settle()
    self.anchor:StartMoving()
end

function I:StopDrag()
    if not self.dragging then return end
    self.anchor:StopMovingOrSizing()
    self.dragging = false
    local cx, cy = self:ReadCenter()
    if cx then
        self:MoveTo(floor(cx + 0.5), floor(cy + 0.5))
    else
        self:ApplyPosition()
    end
end

-- Edit mode: the game's Edit Mode or ElvUI's movers show a box where the island rests; drag it
-- (or the island) to move it. EllesmereUI's unlock mode uses its own mover instead.
function I:SetEditing(on)
    on = on and true or false
    if on == (self.editing or false) then return end
    self.editing = on
    if on then self.pinned = false end
    self:Settle()
    if on and not self.editFrame then
        local f = CreateFrame("Frame", nil, self.anchor)
        f:SetFrameLevel(self.island:GetFrameLevel() + 20)
        f.body = ns.CreateBody(f, "BACKGROUND", 0)
        f.edge = ns.CreateBody(f, "BACKGROUND", 1)
        -- the name and coordinates sit inside the box, like the game's own Edit Mode labels, so
        -- nothing is cut off at the edge of the screen
        f.label = ns.Text(f, "bold", 12, C.fg, "CENTER")
        f.label:SetPoint("CENTER", f, "CENTER", 0, 7)
        f.label:SetText(L["BanzaiSland"])
        f.coords = ns.Text(f, "medium", 10.5, C.fg, "CENTER")
        f.coords:SetPoint("CENTER", f, "CENTER", 0, -8)
        f.coords:SetAlpha(0.75)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() I:StartDrag() end)
        f:SetScript("OnDragStop", function() I:StopDrag() end)
        local lx, ly
        f:SetScript("OnUpdate", function()
            if not I.dragging then return end
            local cx, cy = I:ReadCenter()
            if not cx then return end
            cx, cy = floor(cx + 0.5), floor(cy + 0.5)
            if cx ~= lx or cy ~= ly then        -- only redraw the text when the numbers change
                lx, ly = cx, cy
                f.coords:SetFormattedText(L["X %d   Y %d"], cx, cy)
            end
        end)
        self.editFrame = f
    end
    if self.editFrame then
        self.editFrame:SetShown(on)
        if on then self:PaintEdit() end
    end
end

function I:PaintEdit()
    local f, a = self.editFrame, self.anchor
    local w, h = max(STATES.idle.w, 120), max(STATES.idle.h, 30)
    f:ClearAllPoints()
    f:SetPoint("CENTER", a, "CENTER", 0, 0)
    f:SetSize(w + 12, h + 12)
    local ac = ns.Accent()
    f.edge:SetRadius(min(w, h) / 2 + 6)
    f.edge:SetColor(ac[1], ac[2], ac[3], 0.28)
    f.body:SetRadius(min(w, h) / 2 + 6)
    f.body:SetColor(0, 0, 0, 0.6)          -- dims the island underneath so the label reads clearly
    local cx, cy = self:ReadCenter()
    if cx then f.coords:SetFormattedText(L["X %d   Y %d"], floor(cx + 0.5), floor(cy + 0.5)) end
end

-- A side that points at the screen edge the island grows from has no room: use the other one.
function I:Flip(side)
    if side == self.gx then return (side == "left") and "right" or "left" end
    return side
end

-- Places a round thing (bubble, warning dot) level with the island's resting row. `side` is
-- "right" or "left"; `x` is the gap out from the island's edge. When the island grows upward the
-- row is its bottom edge, otherwise its top.
function I:Beside(f, side, x, hgt)
    side = self:Flip(side)
    -- the row is the resting pill's height, but a card is at least a full bubble tall: when a
    -- small pill (bar, dot, hidden) opens into a card the row eases out to the card's top line
    local row = STATES.idle.h
    if row < 36 and self.sh then row = clamp(self.sh.x, row, 36) end
    local off = (row - hgt) / 2
    f:ClearAllPoints()
    if self.up then
        if side == "left" then f:SetPoint("BOTTOMRIGHT", self.island, "BOTTOMLEFT", -x, off)
        else f:SetPoint("BOTTOMLEFT", self.island, "BOTTOMRIGHT", x, off) end
    else
        if side == "left" then f:SetPoint("TOPRIGHT", self.island, "TOPLEFT", -x, -off)
        else f:SetPoint("TOPLEFT", self.island, "TOPRIGHT", x, -off) end
    end
end

-- the navigation bubble: after the last activity bubble, or beside the island when there are none
function I:PlaceNav(f)
    local side = ns.db.bubbleSide or "right"
    if side ~= "below" then side = self:Flip(side) end
    local last = self.lastBubble
    -- the dot and pins make room for this pill: re-run the layout when its size changes
    local nw = f:GetWidth() or 0
    if self.navW ~= nw then self.navW = nw self.awake = true end
    f:ClearAllPoints()
    if side == "below" then
        if last then f:SetPoint("LEFT", last, "RIGHT", 6, 0)
        else f:SetPoint("TOP", self.island, "BOTTOM", 0, -6) end
    elseif last then
        if side == "left" then f:SetPoint("RIGHT", last, "LEFT", -6, 0)
        else f:SetPoint("LEFT", last, "RIGHT", 6, 0) end
    else
        self:Beside(f, side, 8, f:GetHeight() or 36)
    end
end

-- Opacity, accent colour, idle style, animation feel and text size together
local IDLE = {
    full    = { w = 208, h = 36, r = 18 },
    percent = { w = 64,  h = 36, r = 18 },
    bar     = { w = 150, h = 14, r = 7 },
    dot     = { w = 46,  h = 14, r = 7 },
    hidden  = { w = 208, h = 36, r = 18 },   -- invisible, but as easy to find with the mouse as "Level and %"
}
function I:ApplyOpacity()
    local o = ns.db.opacity or 1
    local style = ns.db.lookStyle
    self.body:SetStyle(style, o, true, true)
    if self.ring then self.ring.body:SetCornerLimit(style == "forever" and 8 or nil, self.island) end
    for _, b in ipairs(self.allBubbles or {}) do b.body:SetStyle(style, o, nil, true) end
    if self.warnDot then self.warnDot.body:SetStyle(style, o) end
    if self.errPill then self.errPill.body:SetStyle(style, o, true) end
    if ns.Nav and ns.Nav.frame and ns.Nav.frame.body then ns.Nav.frame.body:SetStyle(style, o) end
    if ns.Seals and ns.Seals.Recolor then ns.Seals.Recolor() end
    if ns.Shelf and ns.Shelf.Recolor then ns.Shelf.Recolor() end
    if ns.Renderer then ns.Renderer.ApplyMaterial(self) end -- BanzaiSland
end

-- Border around the island body. Solid colour edge by default; LibSharedMedia "border" textures
-- when present and picked. Off unless switched on.
-- shared by the island border and the bubble borders: colour (class colour when picked) and a
-- thickness rounded to whole physical pixels for `frame`
function I:BorderColor()
    local db = ns.db
    local c = db.borderColor or ns.defaults.borderColor
    if db.borderClass then
        local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[select(2, UnitClass("player"))]
        if cc then c = { cc.r, cc.g, cc.b } end
    end
    return c
end

function I:BorderPixels(frame)
    local size = clamp(ns.db.borderSize or 2, 1, 16)
    local es = frame:GetEffectiveScale()
    local physH = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize()) or 768
    local px = (768 / (physH > 0 and physH or 768)) / (es > 0 and es or 1)
    return max(1, floor(size / px + 0.5)) * px
end

-- Bubble / pin / chip / warning dot / error pill: sets the body radius and, when bubble borders
-- are on, a hollow ring just outside it. The ring frame is a child, so it hides and fades with it.
function I:SetBubbleRadius(f, r)
    f.body:SetRadius(r)
    -- BanzaiSland: the thin accent ring is on by default (bubbleRing); the upstream border ring wins when picked
    local banzaiRing = ns.Renderer and ns.db.bubbleRing ~= false and not ns.db.bubbleBorderOn
    if not (ns.db.bubbleBorderOn or banzaiRing) then
        if f.ringFrame then f.ringFrame:Hide() end
        return
    end
    local rf = f.ringFrame
    if not rf then
        rf = CreateFrame("Frame", nil, f)
        rf:SetFrameLevel(f:GetFrameLevel())
        f.ringFrame = rf
        f.ringBody = ns.CreateRing(rf)
        f.ringSize = nil
    end
    local size = self.bubbleBorderSize or self:BorderPixels(f)
    local c = self.bubbleBorderColor or self:BorderColor()
    if f.ringSize ~= size then
        f.ringSize = size
        rf:ClearAllPoints()
        rf:SetPoint("TOPLEFT", f, "TOPLEFT", -size, size)
        rf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", size, -size)
    end
    if f.ringColorKey ~= self.bubbleBorderKey then
        f.ringColorKey = self.bubbleBorderKey
        if banzaiRing then
            ns.Renderer.PaintRing(f.ringBody, f.isChip and 0.5 or nil)
        else
            f.ringBody:SetColor(c[1], c[2], c[3], ns.db.borderAlpha or 1)
        end
    end
    f.ringBody:SetRadius(f.body:GetPaintRadius() or r, size)
    rf:Show()
end

-- Optional rings on the bubbles, in the island border's colour, thickness and opacity
function I:ApplyBubbleBorder()
    local db = ns.db
    self.bubbleBorderKey = (self.bubbleBorderKey or 0) + 1
    self.bubbleBorderSize, self.bubbleBorderColor = nil, nil
    local list = {}
    if self.warnDot then list[#list + 1] = self.warnDot end
    if self.errPill then list[#list + 1] = self.errPill end
    for _, b in ipairs(self.allBubbles or {}) do list[#list + 1] = b end
    local banzaiRing = ns.Renderer and db.bubbleRing ~= false -- BanzaiSland
    if not (db.bubbleBorderOn or banzaiRing) then
        for _, f in pairs(list) do if f.ringFrame then f.ringFrame:Hide() end end
        return
    end
    if self.anchor then self.bubbleBorderSize = self:BorderPixels(self.anchor) end
    self.bubbleBorderColor = self:BorderColor()
    for _, f in pairs(list) do
        f.ringSize = nil
        local w, h = f:GetSize()
        if w and h and w > 0 then self:SetBubbleRadius(f, f.body:GetPaintRadius() or h / 2) end
    end
    self.awake = true
end

function I:ApplyBorder()
    local db, b, ring = ns.db, self.border, self.borderRing
    self:ApplyBubbleBorder()
    if not b then return end
    if ring then ring:Hide() end
    if not db.borderOn then b:Hide() return end
    local size = clamp(db.borderSize or 2, 1, 16)
    local c = self:BorderColor()
    local pick = db.borderTexture or "solid"
    local path
    if pick ~= "solid" then
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        path = LSM and LSM:Fetch("border", pick, true)
    end
    if not path and ring and self.borderRingBody then
        -- plain colour: rounded ring, outside the island
        b:Hide()
        -- whole physical pixels, so the top, sides and bottom all come out the same thickness
        size = self:BorderPixels(self.island)
        self.borderSize = size
        ring:ClearAllPoints()
        ring:SetPoint("TOPLEFT", self.island, "TOPLEFT", -size, size)
        ring:SetPoint("BOTTOMRIGHT", self.island, "BOTTOMRIGHT", size, -size)
        self.borderRingBody:SetColor(c[1], c[2], c[3], db.borderAlpha or 1)
        ring:SetAlpha(self.islA or 1)
        ring:Show()
        if self.sr then self.borderRingBody:SetRadius(self.body:GetPaintRadius() or self.sr.x, size) end
        return
    end
    if not b.SetBackdrop then b:Hide() return end
    b:SetBackdrop({ edgeFile = path or "Interface\\Buttons\\WHITE8X8", edgeSize = size })
    b:SetBackdropBorderColor(c[1], c[2], c[3], db.borderAlpha or 1)
    b:SetAlpha(self.islA or 1)
    b:Show()
end

function I:ApplyLook()
    local db = ns.db
    self:ApplyOpacity()
    self:ApplyBorder()
    local idle = IDLE[db.idleStyle or "full"] or IDLE.full
    STATES.idle.w, STATES.idle.h, STATES.idle.r = idle.w, idle.h, idle.r
    ns.ApplyFeel()
    ns.ApplyTextSize()
    self:ApplyPosition()
    if self.state == "idle" then self:SetState("idle") end
    self:ApplyColors()
end

function I:ApplyColors()
    local db = ns.db
    -- BanzaiSland: every text on the sheet re-reads its colour and text for the active material first
    if Theme and Theme.ReinkAll then Theme.ReinkAll() end
    local x, r = ns.BarColor(), db.restColor
    -- kept in the saved settings so Island Quest Log and Pigeon can match the bar
    db.barNow = { x[1], x[2], x[3] }
    for _, bar in ipairs(self.bars) do
        bar:ApplyStyle(db.lookStyle)
        if bar.rest then bar.rest:SetColor(r[1], r[2], r[3], 0.45) end
        local qc = db.questXPColor or ns.defaults.questXPColor
        if bar.quest then bar.quest:SetColor(qc[1], qc[2], qc[3], 0.45) end
    end
    local ac = ns.Accent()
    self.d.pct:SetTextColor(ac[1], ac[2], ac[3])
    self.t.amt:SetTextColor(ac[1], ac[2], ac[3])
    if (db.accentMode or "bar") ~= "bar" then
        self.c.pct:SetTextColor(ac[1], ac[2], ac[3])
    else
        local muted = LookColor("muted")
        self.c.pct:SetTextColor(muted[1], muted[2], muted[3])
    end
    local fg, muted, gold = LookColor("fg"), LookColor("muted"), LookColor("gold")
    -- Card payloads own their semantic colours. Repaint only the neutral fallback text
    -- when a style is changed while a card is already visible.
    local function NeutralText(fs, key)
        local cr, cg, cb = fs:GetTextColor()
        local plain, styled = C[key], FOREVER[key]
        local function Matches(color)
            return abs(cr - color[1]) < 0.002 and abs(cg - color[2]) < 0.002 and abs(cb - color[3]) < 0.002
        end
        local parchFg, parchMuted = Theme and Theme.COLORS.parchFg, Theme and Theme.COLORS.parchMuted
        local parch = key == "fg" and parchFg or parchMuted
        if Matches(plain) or Matches(styled) or (parch and Matches(parch)) then
            local color = LookColor(key)
            fs:SetTextColor(color[1], color[2], color[3])
        end
    end
    local style = db.lookStyle == "forever" and "forever" or ((Theme and Theme.IsParchment()) and "parchment" or "modern")
    if (self.paintStyle or "modern") ~= style then
        NeutralText(self.t.cap, "muted")
        NeutralText(self.t.title, "fg")
    end
    self.paintStyle = style
    self.c.lv:SetTextColor(fg[1], fg[2], fg[3])
    self.d.title:SetTextColor(fg[1], fg[2], fg[3])
    self.l.title:SetTextColor(fg[1], fg[2], fg[3])
    self.l.old:SetTextColor(gold[1], gold[2], gold[3])
    self.l.new:SetTextColor(gold[1], gold[2], gold[3])
    self.l.cap:SetTextColor(gold[1], gold[2], gold[3])
    self.d.subL:SetTextColor(muted[1], muted[2], muted[3])
    self.d.subR:SetTextColor(muted[1], muted[2], muted[3])
    -- BanzaiSland: bubbles are glass discs under every material, so their text keeps the glass colour
    local bubbleFg = db.lookStyle == "forever" and FOREVER.fg or C.fg
    for _, bubble in ipairs(self.allBubbles or {}) do bubble.text:SetTextColor(bubbleFg[1], bubbleFg[2], bubbleFg[3]) end
    for _, stat in ipairs(self.d.stats) do
        stat.label:SetTextColor(muted[1], muted[2], muted[3])
        stat.value:SetTextColor(fg[1], fg[2], fg[3])
    end
    self.d.stats[1].value:SetTextColor(r[1], r[2], r[3])
    ns.RefreshCardButtons()
    if ns.Renderer then ns.Renderer.ApplyAccent(self) end -- BanzaiSland
    self.liveAct = nil
    for _, b in ipairs(self.allBubbles or {}) do b.act = nil end
    self:UpdateBubble()
    self.awake = true
end

local function Layer(self, name, w, h)
    local f = CreateFrame("Frame", nil, self.island)
    if w then
        f:SetSize(w, h)
        local hp = self.gx == "left" and "LEFT" or self.gx == "right" and "RIGHT" or ""
        f:SetPoint("TOP" .. hp, self.island, "TOP" .. hp, 0, 0)
        f.fixedLayer = true
    else
        f:SetAllPoints(self.island)
    end
    self.layers[name] = f
    return f
end
ns.Layer = Layer

-- resting pill: level, bar, percent (or the amount just gained)
function I:BuildCompact()
    local f = Layer(self, "compact")
    local c = { frame = f }
    c.lv = ns.Text(f, "display", 15, C.fg)
    c.lv:SetPoint("LEFT", f, "LEFT", 13, 0)
    c.pct = ns.Text(f, "bold", 12.5, C.muted, "RIGHT")
    c.pct:SetPoint("RIGHT", f, "RIGHT", -13, 0)
    c.amt = ns.Text(f, "bold", 12.5, C.fg, "RIGHT")
    c.amt:SetPoint("RIGHT", f, "RIGHT", -13, 0)
    c.amt:SetAlpha(0)
    c.bar = CreateBar(f, 4, true)
    c.bar:SetPoint("LEFT", c.lv, "RIGHT", 10, 0)
    c.bar:SetPoint("RIGHT", f, "RIGHT", -57, 0)
    self.bars[#self.bars + 1] = c.bar
    self.c = c
end

-- quest / discovery card
-- Keep the value on the title row, reserving its width without circular anchors.
function ns.AlignCardRow(title, value, left, tail, cardWidth)
    local width = value:GetStringWidth() or 0
    title:SetWidth(math.max(1, (cardWidth or ns.WIDE) - left - 18 - width - 10 - (tail or 0)))
    value:ClearAllPoints()
    value:SetPoint("RIGHT", title, "RIGHT", width + 10, 0)
end

function I:BuildToast()
    local f = Layer(self, "toast", WIDE, STATES.toast.h)
    local t = { frame = f }
    t.tile = Image(f, "Tile", "ARTWORK", 0)
    t.tile:SetSize(40, 40)
    t.tile:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -14)
    t.icon = Image(f, "Check", "ARTWORK", 1)
    t.icon:SetSize(20, 20)
    t.icon:SetPoint("CENTER", t.tile, "CENTER", 0, 0)
    t.item = ns.RoundIcon(f, 40)
    t.item:SetPoint("CENTER", t.tile, "CENTER", 0, 0)
    t.item:Hide()
    t.unit = ns.Text(f, "bold", 11, C.muted, "RIGHT")
    t.unit:SetPoint("RIGHT", f, "RIGHT", -18, 5)
    t.unit:SetText(L["XP"])
    t.amt = ns.Text(f, "extra", 15, C.fg, "RIGHT")
    t.amt:SetPoint("RIGHT", t.unit, "LEFT", -3, 1)
    t.cap = ns.Text(f, "bold", 10.5, C.muted)
    t.cap:SetPoint("TOPLEFT", t.tile, "TOPRIGHT", 12, -4)
    t.title = ns.Text(f, "display", 16, C.fg)
    t.title:SetPoint("TOPLEFT", t.cap, "BOTTOMLEFT", 0, -2)
    -- Width and amount anchors are set together when the card receives its text.
    t.bar = CreateBar(f, 4, true)
    t.bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 11)
    t.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 11)
    self.bars[#self.bars + 1] = t.bar
    self.t = t
end

-- level up card
function I:BuildLevel()
    local f = Layer(self, "level", WIDE, STATES.levelup.h)
    local l = { frame = f, chips = {} }
    local clip = CreateFrame("Frame", nil, f)
    clip:SetSize(70, ROLL_H)
    clip:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -16)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    l.clip = clip
    l.old = ns.Text(clip, "display", 46, C.gold)
    l.new = ns.Text(clip, "display", 46, C.gold)
    l.cap = ns.Text(f, "display", 11, C.gold)
    l.cap:SetPoint("TOPLEFT", clip, "TOPRIGHT", 14, -9)
    l.cap:SetText(L["LEVEL UP"])
    l.title = ns.Text(f, "display", 17, C.fg)
    l.title:SetPoint("TOPLEFT", l.cap, "BOTTOMLEFT", 0, -3)
    for i = 1, 3 do
        local chip = CreateFrame("Frame", nil, f)
        chip:SetHeight(22)
        chip.bg = ns.CreatePill(chip, 22, "ARTWORK", 0)
        chip.bg:SetColor(1, 1, 1, 0.10)
        chip.text = ns.Text(chip, "bold", 11.5, C.fg, "CENTER")
        chip.text:SetPoint("CENTER", chip, "CENTER", 0, 0)
        l.chips[i] = chip
    end
    l.bar = CreateBar(f, 4, false)
    l.bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 16)
    l.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 16)
    self.bars[#self.bars + 1] = l.bar
    self.l = l
end

-- hover details
function I:BuildDetail()
    local f = Layer(self, "detail", WIDE, STATES.detail.h)
    local d = { frame = f, stats = {} }
    d.title = ns.Text(f, "display", 17, C.fg)
    d.title:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -17)
    -- Do Not Disturb switch, top right of the panel
    local bell = CreateFrame("Button", nil, f)
    bell:SetSize(26, 26)
    bell:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -13)
    bell.bg = Image(bell, "Circle", "ARTWORK", 0)
    bell.bg:SetAllPoints(bell)
    bell.icon = Image(bell, "Bell", "ARTWORK", 1)
    bell.icon:SetSize(13, 13)
    bell.icon:SetPoint("CENTER", bell, "CENTER", 0, 0)
    function bell:Paint()
        local on = ns.db and ns.db.dnd
        self.icon:SetTexture(MEDIA .. (on and "BellOff" or "Bell"))
        local c = on and DND_TONE or C.muted
        self.icon:SetVertexColor(c[1], c[2], c[3], 1)
        self.bg:SetVertexColor(1, 1, 1, self.over and 0.16 or 0.08)
    end
    bell:SetScript("OnClick", function() ns.SetDND(not ns.db.dnd) end)
    bell:SetScript("OnEnter", function(b)
        b.over = true b:Paint()
        I.hover = true
        if GameTooltip then
            ns.PlaceTip(GameTooltip, b, "BOTTOM")
            GameTooltip:SetText(ns.db.dnd and L["Do Not Disturb is on"] or L["Do Not Disturb"], 1, 1, 1)
            GameTooltip:AddLine(ns.db.dnd and L["Click to let cards show again."] or L["Click to hold back cards. Prompts and errors still show; the rest waits in the history."], 0.7, 0.72, 0.78, true)
            GameTooltip:Show()
        end
    end)
    bell:SetScript("OnLeave", function(b)
        b.over = false b:Paint()
        if GameTooltip then GameTooltip:Hide() end
        I.hover = I.island.IsMouseOver and I.island:IsMouseOver() or false
        I:Settle()
    end)
    d.bell = bell
    bell:Paint()          -- set its colors now; until painted the circle is plain white

    -- settings, just left of the bell
    local gear = CreateFrame("Button", nil, f)
    gear:SetSize(26, 26)
    gear:SetPoint("RIGHT", bell, "LEFT", -6, 0)
    gear.bg = Image(gear, "Circle", "ARTWORK", 0)
    gear.bg:SetAllPoints(gear)
    gear.bg:SetVertexColor(1, 1, 1, 0.08)
    gear.icon = Image(gear, "Gear", "ARTWORK", 1)
    gear.icon:SetSize(14, 14)
    gear.icon:SetPoint("CENTER", gear, "CENTER", 0, 0)
    gear.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
    gear:SetScript("OnClick", function() ns.ToggleSettings() end)
    gear:SetScript("OnEnter", function(b)
        b.bg:SetVertexColor(1, 1, 1, 0.16)
        b.icon:SetVertexColor(C.fg[1], C.fg[2], C.fg[3], 1)
        I.hover = true
        if GameTooltip then
            ns.PlaceTip(GameTooltip, b, "BOTTOM")
            GameTooltip:SetText(L["Settings"], 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    gear:SetScript("OnLeave", function(b)
        b.bg:SetVertexColor(1, 1, 1, 0.08)
        b.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
        if GameTooltip then GameTooltip:Hide() end
        I.hover = I.island.IsMouseOver and I.island:IsMouseOver() or false
        I:Settle()
    end)
    d.gear = gear
    d.pct = ns.Text(f, "extra", 16, C.fg, "RIGHT")
    d.pct:SetPoint("TOPRIGHT", f, "TOPRIGHT", -80, -17)
    -- The percentage is aligned after its text is refreshed.
    d.bar = CreateBar(f, 6, true)
    d.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -50)
    d.bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -50)
    self.bars[#self.bars + 1] = d.bar
    d.subL = ns.Text(f, "medium", 12, C.muted)
    d.subL:SetPoint("TOPLEFT", d.bar, "BOTTOMLEFT", 0, -8)
    d.subR = ns.Text(f, "medium", 12, C.muted, "RIGHT")
    d.subR:SetPoint("TOPRIGHT", d.bar, "BOTTOMRIGHT", 0, -8)
    local colW = (WIDE - 40) / 4
    for i = 1, 8 do      -- top row: progress, bottom row: this session
        local s = {}
        s.value = ns.Text(f, "bold", 14, C.fg)
        s.value:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20 + ((i - 1) % 4) * colW, i <= 4 and 60 or 18)
        s.value:SetWidth(colW - 4)
        s.label = ns.Text(f, "bold", 9.5, C.muted)
        s.label:SetPoint("BOTTOMLEFT", s.value, "TOPLEFT", 0, 3)
        d.stats[i] = s
    end
    self.d = d
end

-- bubbles that split off the island's right side for things running right now. Up to MAX_BUBBLES
-- show side by side; the setting "bubbleCount" picks how many.
local MAX_BUBBLES = 6
ns.MAX_BUBBLES = MAX_BUBBLES

local MAX_PINS = 8   -- room for Island's own pins, extension bubbles that stay and anything pinned from the shelf
function I:BuildBubble()
    self.bubbles, self.pins, self.allBubbles = {}, {}, {}
    for i = 1, MAX_BUBBLES + MAX_PINS do
        local b = CreateFrame("Frame", nil, self.anchor)
        b:SetFrameLevel(self.anchor:GetFrameLevel() + 2)
        b:SetSize(36, 36)
        b:SetPoint("LEFT", self.island, "RIGHT", 8, 0)
        b.body = ns.CreateBody(b, "BACKGROUND", 0)
        b.body:SetColor(0, 0, 0, 1)
        b.body:SetRadius(18)
        b.icon = Image(b, "Moon", "ARTWORK", 0)
        b.icon:SetSize(16, 16)
        b.icon:SetPoint("LEFT", b, "LEFT", 10, 0)
        b.text = ns.Text(b, "bold", 12.5, C.fg)
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        b.showS, b.widS = Spring(0), Spring(36)
        -- hover for what it is; some can be clicked (tracking turns off)
        b:EnableMouse(true)
        b:SetScript("OnEnter", function(f)
            local act = f.act
            if not (act and GameTooltip) then return end
            ns.PlaceTip(GameTooltip, f, "BOTTOM")
            GameTooltip:SetText(act.tip or L["Activity"], 1, 1, 1)
            local now = act.text and act.text()
            if act.tip2 or (now and now ~= "") then
                local ac = ns.Accent()
                local line = act.tip2 or ""
                if now and now ~= "" then
                    line = (line ~= "" and (line .. ":  ") or "") .. ns.Hex(ac[1], ac[2], ac[3]) .. now .. "|r"
                end
                GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true)
            end
            if act.hint then GameTooltip:AddLine(L["Right-click: %s"]:format(act.hint), 0.55, 0.58, 0.65) end
            GameTooltip:AddLine(act.clickHint or L["Click: all live activities"], 0.55, 0.58, 0.65)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        -- a click opens the shelf of every live activity; a right-click does what the bubble itself does
        b:SetScript("OnMouseUp", function(f, button)
            local act = f.act
            if button == "RightButton" then
                if act and act.onClick then
                    pcall(act.onClick)
                    if GameTooltip then GameTooltip:Hide() end
                end
            elseif act and act.click then
                pcall(act.click)                -- a bubble with a panel of its own (RestedXP's steps)
                if GameTooltip then GameTooltip:Hide() end
            elseif ns.Shelf then
                ns.Shelf.Toggle()
            end
        end)
        b:Hide()
        self.allBubbles[i] = b
        if i <= MAX_BUBBLES then self.bubbles[i] = b else self.pins[i - MAX_BUBBLES] = b end
    end
    self.bubble = self.bubbles[1]
    -- the "+3" chip after the last bubble: more is running than the bubbles have room for
    local c = CreateFrame("Frame", nil, self.anchor)
    c:SetFrameLevel(self.anchor:GetFrameLevel() + 2)
    c:SetSize(36, 36)
    c.body = ns.CreateBody(c, "BACKGROUND", 0)
    c.body:SetColor(0, 0, 0, 1)
    c.body:SetRadius(18)
    c.text = ns.Text(c, "bold", 12.5, C.fg, "CENTER")
    c.text:SetPoint("CENTER", c, "CENTER", 0, 0)
    c.showS, c.widS = Spring(0), Spring(36)
    c.isChip = true
    c:EnableMouse(true)
    c:SetScript("OnEnter", function(f)
        if not GameTooltip then return end
        ns.PlaceTip(GameTooltip, f, "BOTTOM")
        GameTooltip:SetText(L["More activities"], 1, 1, 1)
        GameTooltip:AddLine(L["Click to see everything that is running"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    c:SetScript("OnMouseUp", function() if ns.Shelf then ns.Shelf.Toggle() end end)
    c:Hide()
    self.chip = c
    self.allBubbles[#self.allBubbles + 1] = c
end

-- small round warning on the island's left, the mirror of the bubble: gear needs repair, etc.
function I:BuildWarnDot()
    local b = CreateFrame("Frame", nil, self.anchor)
    b:SetFrameLevel(self.anchor:GetFrameLevel() + 2)
    b:SetSize(36, 36)
    b:SetPoint("RIGHT", self.island, "LEFT", -8, 0)
    b.body = ns.CreateBody(b, "BACKGROUND", 0)
    b.body:SetColor(0, 0, 0, 1)
    b.body:SetRadius(18)
    b.icon = Image(b, "Armor", "ARTWORK", 0)
    b.icon:SetSize(17, 17)
    b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(f)
        local w = self.warnTop
        if not (w and w.tip and GameTooltip) then return end
        ns.PlaceTip(GameTooltip, f, "BOTTOM")
        GameTooltip:SetText(w.tip, 1, 1, 1)
        if w.tip2 then GameTooltip:AddLine(w.tip2, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnMouseUp", function()
        local w = self.warnTop
        if w and w.onClick then pcall(w.onClick) end
    end)
    b:Hide()
    self.warnDot = b
end

-- small red pill that drops out under the island for the game's red error text
-- ("Not enough rage", "Out of range"). Repeats of the same message count up instead of stacking.
local ERR_RED = { 1.00, 0.42, 0.42 }

-- Do Not Disturb: cards are kept in the history instead of shown. A bell with a line through it
-- sits beside the island while it is on; clicking it turns it off.
function ns.SetDND(on)
    ns.db.dnd = on and true or false
    if I.built then
        I:SetWarning("dnd", ns.db.dnd and {
            glyph = "BellOff", tone = DND_TONE, priority = 3, tip = L["Do Not Disturb"],
            tip2 = L["Cards wait in the history: scroll over the island to see them. Click to turn it off."],
            onClick = function() ns.SetDND(false) end,
        } or nil)
        if I.d and I.d.bell then I.d.bell:Paint() end
    end
    if ns.RefreshSettings then ns.RefreshSettings() end
end
function BanzaiSland_ToggleDND() if ns.db then ns.SetDND(not ns.db.dnd) end end
function I:BuildErrorPill()
    local e = CreateFrame("Frame", nil, self.anchor)
    e:SetFrameLevel(self.anchor:GetFrameLevel() + 1)
    e:SetSize(120, 26)
    e.body = ns.CreateBody(e, "BACKGROUND", 0)
    e.body:SetColor(0, 0, 0, 1)
    e.body:SetRadius(13)
    e.icon = Image(e, "Alert", "ARTWORK", 0)
    e.icon:SetSize(13, 13)
    e.icon:SetPoint("LEFT", e, "LEFT", 9, 0)
    e.icon:SetVertexColor(ERR_RED[1], ERR_RED[2], ERR_RED[3], 1)
    e.text = ns.Text(e, "bold", 12, ERR_RED)
    e.text:SetPoint("LEFT", e.icon, "RIGHT", 6, 0)
    e:Hide()
    self.errPill = e
end

function I:ShowError(text)
    if not self.built or type(text) ~= "string" or text == "" then return end
    local e = self.errPill
    local now = GetTime()
    if self.errText == text and self.errT and self.errT > 0 then
        self.errCount = (self.errCount or 1) + 1
    else
        self.errText, self.errCount = text, 1
    end
    local shown = text .. (self.errCount > 1 and ("  |cff8d93a5x" .. self.errCount .. "|r") or "")
    e.text:SetText(shown)
    e.w = 9 + 13 + 6 + (e.text:GetStringWidth() or 100) + 13
    self.errT = 1.6 + min(0.8, #text * 0.02)
    self.errS.t = 1
    if self.errS.x > 0.6 then self.errS.v = self.errS.v - 3 end     -- a little nudge on a repeat
    self.awake = true
end

-- `w` is { glyph, tone, priority, tip, tip2 } or nil to clear it
function I:SetWarning(key, w)
    self.warnings = self.warnings or {}
    self.warnings[key] = w
    if self.built then self:UpdateBubble() end
end

-- ---------------------------------------------------------------- state

function I:RestState()
    if self.rolls and #self.rolls > 0 then return "roll" end
    -- while it is being moved the island stays a plain resting pill: no details opening under the pointer
    if self.editing or self.dragging then return "idle" end
    if self.pinned or (self.hover and ns.db.hoverDetails) then return "detail" end
    return "idle"
end

function I:SetState(s)
    local g = STATES[s]
    self.state = s
    self.stateT = 0
    local gw = g.w
    if s == "gain" then
        -- just wide enough for the amount (the old fixed width was far too wide for "+4c")
        local aw = (self.c.amt:GetStringWidth() or 0) + 4
        gw = clamp(STATES.idle.w + max(0, aw - 34), STATES.idle.w, g.w)
    end
    self.gainW = gw
    self.sw.t, self.sh.t, self.sr.t = gw, g.h, g.r
    for name, l in pairs(self.layers) do
        local target = (name == g.layer) and 1 or 0
        if target == 1 and l.target == 0 then l.delay = 0.1 * FADE end
        l.target = target
    end
    self.amtT = (s == "gain") and 1 or 0
    if s == "detail" then self:FillDetail() end
    if s == "roll" then self:FillRoll() end
    self:UpdateBubble()
    self.awake = true
end

-- go back to whichever resting state applies, unless something is playing
function I:Settle()
    if not self.built or self.current then return end
    -- the pointer can leave without the island hearing about it (a card's button was under it and
    -- then the card closed): check for real
    if self.hover and self.island.IsMouseOver and not self.island:IsMouseOver() then self.hover = false end
    local s = self:RestState()
    if s ~= self.state then self:SetState(s) end
end

-- Live activities: things that are running right now (a flight, a breath timer, a queue).
-- The most important one sits in the bubble beside the island. `act` is
-- { glyph, tone, priority, text = function() return "2:14" end } or nil to clear it.
function I:SetActivity(key, act)
    self.acts[key] = act
    if self.built then self:UpdateBubble() end
end

function I:PaintBubbleIcon(b, act)
    local tone = act.tone or C.fg
    if act.texture then                 -- a game icon (active tracking), shown in its own colours
        b.icon:SetTexture(act.texture)
        b.icon:SetVertexColor(1, 1, 1, 1)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        if act.accentTone or (ns.db.accentBubbles and not act.fixedTone) then tone = ns.Accent() end
        b.icon:SetTexture(MEDIA .. act.glyph)
        b.icon:SetVertexColor(tone[1], tone[2], tone[3], 1)
        b.icon:SetTexCoord(0, 1, 0, 1)
    end
end

-- Is this activity pinned? A choice made on the shelf wins; otherwise the old pin settings and
-- extension bubbles that stay decide.
function I:IsPinned(key, act)
    local pins = ns.db.shelf and ns.db.shelf.pins
    local v = pins and pins[key]
    if v ~= nil then return v and true or false end
    return (act.pin and ns.db["pin" .. act.pin] and true) or (act.extPin and true) or false
end

-- Every live activity in the order the bubbles and the shelf use: returns the pinned ones and the
-- rest. A custom order (moved on the shelf) comes first, but a new urgent activity that has no place
-- in it yet (breath, a pull timer) still goes ahead, so it is never buried.
local PIN_ORDER = { Ammo = 1, Tracking = 2, Rested = 3 }
function I:Ranked()
    local order = ns.db.shelf and ns.db.shelf.order
    local rank = {}
    if order then for i, k in ipairs(order) do rank[k] = i end end
    local pinned, regular = {}, {}
    for key, act in pairs(self.acts) do
        local e = { key = key, act = act, rank = rank[key] }
        if self:IsPinned(key, act) then pinned[#pinned + 1] = e else regular[#regular + 1] = e end
    end
    table.sort(pinned, function(a, b)
        local ra, rb = a.rank or 1e9, b.rank or 1e9
        if ra ~= rb then return ra < rb end
        local oa, ob = PIN_ORDER[a.act.pin] or 9, PIN_ORDER[b.act.pin] or 9
        if oa ~= ob then return oa < ob end
        return tostring(a.key) < tostring(b.key)
    end)
    table.sort(regular, function(a, b)
        local ua = not a.rank and (a.act.priority or 0) >= 5
        local ub = not b.rank and (b.act.priority or 0) >= 5
        if ua ~= ub then return ua end
        local ra, rb = a.rank or 1e9, b.rank or 1e9
        if ra ~= rb then return ra < rb end
        local pa, pb = a.act.priority or 0, b.act.priority or 0
        if pa ~= pb then return pa > pb end
        return tostring(a.key) < tostring(b.key)
    end)
    return pinned, regular
end

function I:UpdateBubble()
    if not self.built then return end
    local s = self.state
    local resting = ns.db.showRested and self.data and self.data.mode == "xp" and IsResting and IsResting()
    if resting and not (self.acts.rested and self.acts.rested.tone == ns.db.restColor) then
        self.acts.rested = { glyph = "Moon", tone = ns.db.restColor, priority = 0, pin = "Rested", tip = L["Resting"],
                             tip2 = L["You're in an inn or a city, earning rested XP"] }
    elseif not resting then
        self.acts.rested = nil
    end
    -- Pinned bubbles (ammo, tracking, resting, anything pinned on the shelf) always show, on the
    -- other side of the island from the coming-and-going ones. The rest, most urgent first, fill the
    -- bubbles; whatever does not fit waits behind the "+N" chip and in the shelf.
    -- "Only urgent bubbles": breath and fatigue, pull and break timers, ready checks and server
    -- restarts (priority 5 and up); the rest stay out of the bubbles but are still in the shelf.
    local pinned, regular = self:Ranked()
    local urgentOnly = ns.db.bubblesUrgentOnly
    local list = {}
    for _, e in ipairs(regular) do
        if not urgentOnly or (e.act.priority or 0) >= 5 then list[#list + 1] = e end
    end
    for i, b in ipairs(self.pins) do
        local act = pinned[i] and pinned[i].act or nil
        if act ~= b.act then
            b.act = act
            if act then self:PaintBubbleIcon(b, act) end
        end
        b.showS.t = act and 1 or 0
    end
    local count = max(0, min(MAX_BUBBLES, tonumber(ns.db.bubbleCount) or 1))   -- 0 hides them
    for i, b in ipairs(self.bubbles) do
        local act = (i <= count) and list[i] and list[i].act or nil
        if act ~= b.act then
            b.act = act
            if act then self:PaintBubbleIcon(b, act) end
        end
        -- the bubbles stay out while a card is open too; they ride along its top edge
        b.showS.t = act and 1 or 0
    end
    -- more running than there is room for: a small "+N" chip points at the shelf
    local extra = max(0, #pinned - #self.pins) + (count > 0 and max(0, #list - count) or 0)
    if self.chip then
        if extra > 0 then self.chip.text:SetText("+" .. extra) end
        self.chip.showS.t = extra > 0 and 1 or 0
    end
    if ns.Shelf and ns.Shelf.Changed then ns.Shelf.Changed() end
    self.liveAct = self.bubbles[1].act
    self:UpdateBubbleText()
    local warn
    for _, w in pairs(self.warnings or {}) do
        if not warn or (w.priority or 0) > (warn.priority or 0) then warn = w end
    end
    if warn and warn ~= self.warnTop then
        local tone = warn.tone or C.fg
        self.warnDot.icon:SetTexture(MEDIA .. (warn.glyph or "Armor"))
        self.warnDot.icon:SetVertexColor(tone[1], tone[2], tone[3], 1)
    end
    self.warnTop = warn
    self.warn.t = warn and 1 or 0
    self.awake = true
end

function I:UpdateBubbleText()
    for _, b in ipairs(self.allBubbles) do
        local act = b.act
        if act then
            local text = act.text and act.text() or ""
            b.text:SetText(text)
            b.widS.t = (text ~= "") and (36 + (b.text:GetStringWidth() or 30) + 8) or 36
        end
    end
end

function I:BubblesResting()
    for _, b in ipairs(self.allBubbles) do
        if not (Resting(b.showS) and Resting(b.widS)) then return false end
    end
    return true
end

-- bubble bar begin
-- A small bar along the bottom of a bubble whose activity has a `progress` function (0 to 1): the same bar the
-- island's XP bar uses, so it is as smooth as the rest of the island. It sits inside the pill, held in from the
-- rounded ends. It is made the first time a bubble needs it.
local BUBBLE_BAR_H = 4
local BUBBLE_BAR_Y = 5                            -- gap under the bar
local function BubbleBarWidth(w, h)
    local r = h / 2
    local d = r - BUBBLE_BAR_Y
    local pad = r - math.sqrt(max(0, r * r - d * d)) + 4   -- keep clear of the curve at the bar's height
    return max(8, w - 2 * pad)
end

-- (ratio 0 to 1, tone) -> sets the bar on bubble `b`, creating it if needed; width `bw` in pixels
local function BubbleBarSet(b, v, tone, bw)
    local bar = b.pbar
    if not bar then
        bar = CreateBar(b, BUBBLE_BAR_H, false)
        bar:SetPoint("BOTTOM", b, "BOTTOM", 0, BUBBLE_BAR_Y)
        b.pbar = bar
    end
    if bar.bw ~= bw then
        bar.bw = bw
        bar:SetWidth(bw)
        bar.q = nil
    end
    if bar.tr ~= tone[1] or bar.tg ~= tone[2] or bar.tb ~= tone[3] then
        bar.tr, bar.tg, bar.tb = tone[1], tone[2], tone[3]
        bar.fill:SetColor(tone[1], tone[2], tone[3], 1)
        bar.track:SetColor(tone[1], tone[2], tone[3], 0.2)
        bar.q = nil
    end
    local q = floor(v * bw * 4 + 0.5)          -- repaint only when the fill has moved by a quarter pixel
    if bar.q ~= q then
        bar.q = q
        bar:Set(v, 0)
    end
    if not bar:IsShown() then bar:Show() end
end
-- bubble bar end

-- The bar on bubbles whose activity has a `progress` function (0 to 1). A fixed fill eases to its next value; a
-- countdown (noEase) just follows the clock. The shown value lives in act.barState so it survives the activity
-- being replaced by a newer one for the same thing. Returns true while it is still moving.
function I:UpdateBubbleBars(dt)
    local moving = false
    for _, b in ipairs(self.allBubbles) do
        local act = b.act
        local raw = act and act.progress and (not act.native or ns.db.bubbleBars ~= false) and b:IsShown() and act.progress()
        if raw ~= nil and raw ~= false then      -- nothing to count down from (a flight of unknown length): no bar
            local target = max(0, min(1, raw))
            local st = act.barState or b.barLocal or {}
            b.barLocal = st
            local v = st.shown
            if v == nil or act.noEase or not ns.BarEase then v = target else v = ns.BarEase(v, target, dt) end
            st.shown = v
            local tone = act.barTone or ((act.accentTone or (ns.db.accentBubbles and not act.fixedTone)) and ns.Accent()) or act.tone or C.fg
            local w, h = b:GetWidth() or 0, b:GetHeight() or 0
            if w > 8 and h > 8 then BubbleBarSet(b, v, tone, BubbleBarWidth(w, h)) end
            if v ~= target then moving = true end
        elseif b.pbar and b.pbar:IsShown() then
            b.pbar:Hide()
        end
    end
    return moving
end

-- true while any bubble shows a running timer, so the text keeps ticking
function I:BubblesTicking()
    for _, b in ipairs(self.allBubbles) do
        if b.act and b.act.text and not b.act.static then return true end
    end
    return false
end

function I:SetP(p)
    self.pT = clamp(p or 0, 0, 1)
    local d = self.data
    self.c.pct:SetText((d and d.mode == "max") and L["Max"] or (floor(self.pT * 100) .. "%"))
    self.awake = true
end

function I:SetLevel(n)
    self.c.lv:SetText(n)
    self.shownLevel = n
end

function I:Refresh()
    if not self.built then return end
    local s = ns.GetState()
    self.data = s
    self.fillColor = s.color or ns.BarColor()
    self.rT = s.r or 0
    self.qT = s.q or 0
    if not self.current then
        self:SetP(s.p)
        self:SetLevel(s.level)
    end
    if self.state == "detail" then self:FillDetail() end
    self:UpdateBubble()
    self.awake = true
end

function I:FillDetail()
    if self.d and self.d.bell then self.d.bell:Paint() end
    local d, s = self.d, ns.GetState()
    local ses = ns.session
    local elapsed = max(300, GetTime() - (ses.start or GetTime()))
    local rows
    if s.mode == "xp" then
        local left = max(0, s.max - s.cur)
        local rate = ses.xp > 0 and (ses.xp / elapsed * 3600) or 0
        d.title:SetText(L["Level %d"]:format(s.level))
        d.pct:SetText(string.format("%.1f%%", s.p * 100))
        d.subL:SetText(L["%s / %s XP"]:format(ns.Comma(s.cur), ns.Comma(s.max)))
        d.subR:SetText(L["%s to go"]:format(ns.Comma(left)))
        rows = {
            { L["RESTED"], s.rested > 0 and ("+" .. ns.Short(s.rested)) or L["None"] },
            { L["XP / HOUR"], rate > 0 and ns.Short(rate) or "--" },
            { L["TO LEVEL"], rate > 0 and ns.Duration(left / rate * 3600) or "--" },
            { L["KILLS LEFT"], (function() local k = ns.KillsLeft(left, s.rested) return k and ("~" .. ns.Comma(k)) or "--" end)() },
        }
    elseif s.mode == "rep" then
        local left = max(0, s.max - s.cur)
        local rate = ses.rep > 0 and (ses.rep / elapsed * 3600) or 0
        d.title:SetText(s.name)
        d.pct:SetText(string.format("%.1f%%", s.p * 100))
        d.subL:SetText(ns.Comma(s.cur) .. " / " .. ns.Comma(s.max))
        d.subR:SetText(s.standingText or "")
        rows = {
            { L["SESSION"], ses.rep > 0 and ("+" .. ns.Short(ses.rep)) or "--" },
            { L["REP / HOUR"], rate > 0 and ns.Short(rate) or "--" },
            { L["TO NEXT"], ns.Comma(left) },
            { L["LEVEL"], s.level },
        }
    else
        d.title:SetText(L["Level %d"]:format(s.level))
        d.pct:SetText(L["Max"])
        d.subL:SetText(L["Max level reached"])
        d.subR:SetText("")
        rows = { { L["RESTED"], "--" }, { L["XP / HOUR"], "--" }, { L["TO LEVEL"], "--" }, { L["KILLS LEFT"], "--" } }
    end
    ns.AlignCardRow(d.title, d.pct, 20, 62)
    local played = GetTime() - (ses.start or GetTime())
    local net = (GetMoney and ses.moneyStart) and (GetMoney() - ses.moneyStart) or 0
    local gold = "--"
    if ns.MoneyText and net ~= 0 then gold = (net < 0 and "-" or "+") .. ns.MoneyText(math.abs(net)):sub(2) end
    rows[5] = { L["GOLD"], gold }
    rows[6] = { L["KILLS"], (ses.kills or 0) > 0 and ns.Comma(ses.kills) or "--" }
    rows[7] = { L["XP GAINED"], ses.xp > 0 and ns.Short(ses.xp) or "--" }
    rows[8] = { L["SESSION"], ns.Duration(played) }
    local run = ns.Instance and ns.Instance.DetailRows()     -- inside a dungeon: this run instead
    if run then for i = 1, 4 do rows[4 + i] = run[i] end end
    for i = 1, 8 do
        d.stats[i].label:SetText(rows[i][1])
        d.stats[i].value:SetText(rows[i][2])
    end
end

-- ---------------------------------------------------------------- queue

local function GainText(item)
    if item.fmt then return item.fmt(item.amount) end
    return ("+%s %s"):format(ns.Comma(item.amount), L[item.unit or "XP"])
end

function I:ShowGain(item)
    local amt = self.c.amt
    amt:SetText(GainText(item))
    local col = item.color or (item.rested and ns.db.restColor) or (self.fillColor or ns.BarColor())
    amt:SetTextColor(col[1], col[2], col[3])
end

-- Keep a copy of a card so it can be scrolled back to with the mouse wheel.
function I:Record(item)
    if item.replay or item.transient or item.recorded then return end
    item.recorded = true
    local h = self.history
    h[#h + 1] = {
        cap = item.extensionName or item.cap, capColor = item.capColor, title = item.title, color = item.color, link = item.link,
        res = item.res, resColor = item.resColor, line = item.lineText or item.line,
        icon = item.icon, glyph = item.glyph, tone = item.tone, at = GetTime(),
        builderType = ns.Builder and ns.Builder.Type(item) or item.builderType,
    }
    if #h > 20 then table.remove(h, 1) end
end

local function Ago(sec)
    if sec < 60 then return L["JUST NOW"] end
    if sec < 3600 then return L["%dM AGO"]:format(floor(sec / 60)) end
    return L["%dH AGO"]:format(floor(sec / 3600))
end

-- direction 1 = older, -1 = newer
function I:ShowHistory(direction)
    local h = self.history
    if #h == 0 or (self.rolls and #self.rolls > 0) then return end
    local i = self.histIdx and (self.histIdx - direction) or #h
    i = max(1, min(#h, i))
    self.histIdx = i
    local e = h[i]
    self:PushReplace({
        kind = "won", key = "history", replay = true, urgent = true, hold = 4,
        cap = (e.cap or "") .. "   " .. Ago(GetTime() - e.at) .. "   " .. (#h - i + 1) .. " / " .. #h,
        capColor = e.capColor, title = e.title, color = e.color, link = e.link, res = e.res, resColor = e.resColor,
        line = e.line, icon = e.icon, glyph = e.glyph, tone = e.tone, builderType = e.builderType,
    })
end

local function InCombat()
    return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
end

-- typing in one of Pigeon's text boxes (a whisper window, the hub or its chat box)
local function TypingInPigeon()
    local api = _G.PigeonAPI
    if type(api) ~= "table" or type(api.IsTyping) ~= "function" then return false end
    local ok, typing = pcall(api.IsTyping)
    return ok and typing == true
end

-- should cards wait right now?
function I:ShouldHold()
    if ns.db.holdInCombat and InCombat() then return true end
    if ns.db.holdWhileTyping and TypingInPigeon() then return true end
    return false
end

-- cards that arrive in combat wait here and replay when it ends
function I:Hold(item)
    local held = self.held
    if item.key then
        for i, other in ipairs(held) do
            if other.key == item.key then
                if item.replace or not other.format then
                    held[i] = item
                else
                    other.count = (other.count or 0) + (item.count or 0)
                    other.res = other.format(other.count)
                    if item.line then other.line = item.line end
                end
                return
            end
        end
    end
    held[#held + 1] = item
    if #held > 12 then table.remove(held, 1) end
end

function I:ReleaseHeld()
    local held = self.held
    if #held == 0 or self:ShouldHold() then return end
    self.held = {}
    for _, item in ipairs(held) do
        item.released = true
        self:Push(item)
    end
end

function I:Push(item)
    if not self.built then return end
    if ns.Extensions and not ns.Extensions.Valid(item) then return end
    if ns.CatchUp and ns.CatchUp.ShouldQuiet(item) then self:Record(item) return end
    if item.kind ~= "gain" and ns.db.dnd and not item.replay then
        self:Record(item)           -- Do Not Disturb: kept in the history, not shown
        return
    end
    -- while a voiceover is on the island, small news goes to the strip along its bottom
    if not item.replay and ns.Voice and ns.Voice.Takes and ns.Voice:Takes(item) then return end
    if item.kind ~= "gain" and not item.urgent and not item.released then
        if ns.db.quietInRaid and IsInRaid and IsInRaid() then
            self:Record(item)       -- still reachable with the mouse wheel
            return
        end
        if self:ShouldHold() then
            self:Hold(item)
            return
        end
    end
    local dialogue=type(ns.Retail)=="table" and ns.Retail.Dialogue
    if dialogue and dialogue.Takes and dialogue.Takes(item) then return end
    local rolling = self.rolls and #self.rolls > 0
    if rolling and item.kind == "gain" then
        self:Refresh()      -- keep the roll card up; the bar still moves
        return
    end
    if item.kind == "gain" then
        local cur = self.current
        if cur and cur.kind == "gain" and cur.unit == item.unit then
            cur.amount = cur.amount + item.amount
            cur.rested = cur.rested or item.rested
            cur.p = (cur.p == 1) and 1 or item.p
            self:ShowGain(cur)
            if cur.applied and cur.p then self:SetP(cur.p) self.hit = 1 end
            cur.dur = max(cur.dur, cur.t + 1.5)
            return
        end
        local tail = self.queue[#self.queue]
        if tail and tail.kind == "gain" and tail.unit == item.unit then
            tail.amount = tail.amount + item.amount
            tail.rested = tail.rested or item.rested
            tail.p = (tail.p == 1) and 1 or item.p
            return
        end
    end
    local q = self.queue
    if #q >= (item.released and 14 or 8) then return end
    -- more important cards go ahead of less important ones that are still waiting
    local pr, pos = item.priority or 1, #q + 1
    for i = 1, #q do
        if (q[i].priority or 1) < pr then pos = i break end
    end
    table.insert(q, pos, item)
    if dialogue and dialogue.active and dialogue.IsUrgent(item)
        and self.current and self.current.retailDialogue then
        self.current=nil
        dialogue.HidePreviews()
    end
    self:Pump()
end

function I:Pump()
    if ns.Extensions then
        for index=#self.queue,1,-1 do
            if not ns.Extensions.Valid(self.queue[index]) then table.remove(self.queue,index) end
        end
    end
    if self.current then return end
    if self.rolls and #self.rolls > 0 then
        -- a loot roll is waiting for an answer: hold everything else until it is done. A
        -- voiceover is the exception: a card worth acting on steps in over it for its moment,
        -- and the voiceover comes back when it is done.
        local top = self.rolls[1]
        local stepIn = top.id == "spoken" and not top.answerT and #self.queue > 0
        if not stepIn then
            if self.state ~= "roll" then self:SetState("roll") end
            self:Refresh()
            return
        end
    end
    -- Retail dialogue yields to urgent cards even when ordinary news was queued first.
    local dialogue=type(ns.Retail)=="table" and ns.Retail.Dialogue
    if dialogue and dialogue.active then
        for index,item in ipairs(self.queue) do
            if dialogue.IsUrgent(item) then
                table.insert(self.queue,1,table.remove(self.queue,index))
                break
            end
        end
    end
    local item = table.remove(self.queue, 1)
    if not item then
        self.histIdx = nil
        self:SetState(self:RestState())
        self:Refresh()
        return
    end
    item.t, item.step = 0, 1
    -- A layout error must not leave an incomplete animation running every frame.
    item.steps, item.dur = {}, item.hold or 3
    self.current = item
    self:Begin(item)
    if item.kind ~= "gain" and item.dur and not item.exact then item.dur = item.dur * ns.CardTime(item) end
    if item.sound and ns.PlayCardSound then ns.PlayCardSound(item.sound, item) end
end

function I:Begin(item)
    local function apply()
        item.applied = true
        if item.p then          -- money and honor pills leave the xp bar alone
            I:SetP(item.p)
            I.hit = 1
        end
    end
    if item.kind == "gain" then
        self:ShowGain(item)
        item.steps, item.dur = { { 0.38, apply } }, 1.9
        self:SetState("gain")
    elseif item.kind == "toast" then
        local t = self.t
        local loot = item.toast == "loot"
        local quest = item.toast == "quest"
        local tone = loot and (item.color or C.fg) or (quest and C.quest or C.disc)
        t.tile:SetShown(not loot)
        t.icon:SetShown(not loot)
        t.item:SetShown(loot)
        t.cap:SetTextColor(tone[1], tone[2], tone[3])
        if loot then
            t.item:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            local muted = LookColor("muted")
            t.cap:SetTextColor(muted[1], muted[2], muted[3])
            t.cap:SetText(item.cap or L["LOOT"])
            t.title:SetTextColor(tone[1], tone[2], tone[3])
            t.amt:SetText("")
            t.unit:SetText("")
            item.steps, item.dur = {}, 3.0
        else
            t.tile:SetVertexColor(tone[1], tone[2], tone[3], 0.18)
            t.icon:SetTexture(MEDIA .. (quest and "Check" or "Compass"))
            t.icon:SetVertexColor(tone[1], tone[2], tone[3], 1)
            t.cap:SetText(quest and L["QUEST COMPLETE"] or L["DISCOVERED"])
            local fg = LookColor("fg")
            t.title:SetTextColor(fg[1], fg[2], fg[3])
            t.amt:SetText("+" .. ns.Comma(item.amount or 0))
            t.unit:SetText(L["XP"])
            item.steps, item.dur = { { 0.38, apply } }, 2.7
            self:Record({ cap = quest and L["QUEST COMPLETE"] or L["DISCOVERED"], capColor = tone, title = item.title,
                          color = C.fg, res = L["+%s XP"]:format(ns.Comma(item.amount or 0)), resColor = ns.BarColor(),
                          glyph = quest and "Check" or "Compass", tone = tone })
        end
        t.title:SetText(item.title or "")
        local unitWidth = t.unit:GetStringWidth() or 0
        ns.AlignCardRow(t.title, t.amt, 66, unitWidth + 3)
        t.unit:ClearAllPoints()
        t.unit:SetPoint("LEFT", t.amt, "RIGHT", 3, 0)
        self:SetState("toast")
    elseif item.kind == "won" then
        self:BeginWon(item)
    elseif item.kind == "levelup" then
        local l = self.l
        local new = item.level or ((self.shownLevel or 1) + 1)
        l.old:SetText(new - 1)
        l.new:SetText(new)
        -- Size the number's window to fit. The measured width can come back short the first time
        -- (before the font is ready, or while the layer is hidden), which cut the number off, so
        -- never go below a width worked out from the digits, and measure again a moment later.
        local function fit()
            local digits = math.max(#tostring(new), #tostring(new - 1))
            local measured = max(l.old:GetStringWidth() or 0, l.new:GetStringWidth() or 0)
            l.clip:SetWidth(max(measured, digits * 30) + 8)
        end
        fit()
        C_Timer.After(0.05, fit)
        C_Timer.After(0.3, fit)
        l.title:SetText(L["You reached level %d"]:format(new))
        local chips = item.chips or {}
        if #chips == 0 then chips = { L["Level %d"]:format(new) } end
        local prev
        for i = 1, 3 do
            local chip = l.chips[i]
            if chips[i] then
                chip.text:SetText(chips[i])
                local w = (chip.text:GetStringWidth() or 60) + 18
                chip:SetWidth(w)
                chip.bg:SetWidth(w)
                chip:ClearAllPoints()
                if prev then
                    chip:SetPoint("LEFT", prev, "RIGHT", 6, 0)
                else
                    chip:SetPoint("TOPLEFT", l.frame, "TOPLEFT", 20, -80)
                end
                chip:SetAlpha(0)
                chip:Show()
                prev = chip
            else
                chip:Hide()
            end
        end
        self.roll.x, self.roll.v, self.roll.t = 0, 0, 0
        self.ring.body:SetColor(C.gold[1], C.gold[2], C.gold[3], 1)
        self.flashT = 0
        item.steps = {
            { 0.42, function()
                I.roll.t = ROLL_H
                I.p, I.pT = 0, 0
                I:SetLevel(new)
                I:SetP(0)
            end },
            { 0.95, function()
                I:SetP(item.p or ns.GetState().p)
                I.hit = 1
            end },
        }
        item.dur = 3.6
        self:SetState("levelup")
    end
end

function I:Demo()
    if not self.built then return end
    local s = ns.GetState()
    local base = (s.p > 0.9) and 0.4 or s.p
    self:Push({ kind = "gain", amount = 1250, p = min(1, base + 0.02), unit = "XP" })
    self:Push({ kind = "toast", toast = "disc", title = L["Booty Bay"], amount = 430, p = min(1, base + 0.03) })
    self:Push({ kind = "toast", toast = "quest", title = L["The Defias Brotherhood"], amount = 9800, p = 1 })
    self:Push({ kind = "levelup", level = s.level + 1, p = 0.04,
                chips = { L["+%s health"]:format("38"), L["+%s mana"]:format("52"), L["+%d talent point"]:format(1) } })
end

-- ---------------------------------------------------------------- frame update

function I:OnUpdate(dt)
    if not dt or dt < 0 then dt = 0 end
    if dt > 0.1 then dt = 0.1 end

    local cur = self.current
    if cur then
        cur.t = cur.t + dt
        local steps = cur.steps
        while steps[cur.step] and cur.t >= steps[cur.step][1] do
            local fn = steps[cur.step][2]
            cur.step = cur.step + 1
            fn()
        end
        if cur.t >= cur.dur then
            self.current = nil
            self:Pump()
        end
        self.awake = true
    end

    if self.state == "detail" then
        self.detailT = self.detailT + dt
        if self.detailT > 1 then
            self.detailT = 0
            self:FillDetail()
        end
    end

    if self.state == "roll" then self:UpdateRoll(dt) end
    if #self.held > 0 then                            -- waiting cards: check twice a second whether they can go
        self.heldT = (self.heldT or 0) + dt
        if self.heldT > 0.5 then
            self.heldT = 0
            self:ReleaseHeld()
        end
    end
    if self:BubblesTicking() then                      -- running timers in the bubbles
        self.liveT = self.liveT + dt
        if self.liveT > 0.25 then
            self.liveT = 0
            self:UpdateBubbleText()
            for _, b in ipairs(self.allBubbles) do
                if not Resting(b.widS) then self.awake = true end
            end
        end
    end
    if self:UpdateBubbleBars(dt) then self.awake = true end
    if self.state == "won" then self:UpdateWon(dt) end

    -- details open from hovering: close them if the pointer has quietly gone (see Settle)
    if self.state == "detail" and self.hover and not self.pinned then
        self.hoverT = (self.hoverT or 0) + dt
        if self.hoverT > 0.2 then
            self.hoverT = 0
            if self.island.IsMouseOver and not self.island:IsMouseOver() then
                self.hover = false
                self:Settle()
            end
        end
    end
    if self.errT then                                  -- the red error pill counts down
        self.errT = self.errT - dt
        if self.errT <= 0 then self.errT = nil self.errS.t = 0 end
        self.awake = true
    end
    -- "Hidden" style: nothing shows while the island rests (hovering its spot still brings it up);
    -- fights can dim or hide the island
    local islT, ancT = 1, 1
    if ns.db.idleStyle == "hidden" and self.state == "idle" and not self.current and not self.hover then islT = 0 end
    local fade = ns.db.combatFade or "off"
    if fade ~= "off" and UnitAffectingCombat and UnitAffectingCombat("player")
        and (self.state == "idle" or self.state == "gain") and not (self.rolls and #self.rolls > 0) and not self.hover then
        ancT = (fade == "hide") and 0 or 0.3
    end
    if self.islA ~= islT then
        self.islA = (islT > self.islA) and min(islT, self.islA + dt * 5) or max(islT, self.islA - dt * 5)
        self.island:SetAlpha(self.islA)
        if self.border then self.border:SetAlpha(self.islA) end
        if self.borderRing then self.borderRing:SetAlpha(self.islA) end
        if self.dress and ns.Renderer then ns.Renderer.Fade(self, self.islA) end -- BanzaiSland: the dressing fades with the island
    end
    if self.ancA ~= ancT then
        self.ancA = (ancT > self.ancA) and min(ancT, self.ancA + dt * 4) or max(ancT, self.ancA - dt * 4)
        self.anchor:SetAlpha(self.ancA)
    end
    if not self.awake then return end
    self.stateT = self.stateT + dt

    -- springs
    local sw, sh, sr, roll = self.sw, self.sh, self.sr, self.roll
    local n = max(1, ceil(dt * 120))      -- a frame can report zero elapsed time
    local h = dt / n
    for _ = 1, n do
        -- The box itself is damped almost critically: with the normal bounce the edge swung ~4 px
        -- past its size and back (measured from a recording) while the text glued to the edge or
        -- sitting in a fixed layer moved against it, which read as a shake. Other springs keep the feel.
        Step(sw, h, STIFF, DAMP * 1.35)
        Step(sh, h, STIFF, DAMP * 1.35)
        Step(sr, h, STIFF, DAMP)
        Step(self.warn, h, STIFF, DAMP)
        Step(self.errS, h, STIFF, DAMP)
        for _, b in ipairs(self.allBubbles) do
            Step(b.showS, h, STIFF, DAMP)
            Step(b.widS, h, STIFF, DAMP)
        end
        Step(roll, h, 150, 15)
    end

    -- never smaller than the resting pill (the dot and bar styles are smaller than the usual floor)
    local w, ht = max(min(30, STATES.idle.w), sw.x), max(min(24, STATES.idle.h), sh.x)
    local r = clamp(sr.x, 2, min(w, ht) / 2)
    if InCombatLockdown() and self.island:IsProtected() then
        if not self.lockSaid then
            self.lockSaid = true
            local why = {}
            if GameTooltip and GameTooltip:IsProtected() then why[#why + 1] = "tooltip" end
            for i = 1, 4 do
                local o = _G["BanzaiSlandSecureButton" .. i]
                if o and o:GetNumPoints() > 0 then why[#why + 1] = "button " .. i end
            end
            print("|cff9eff1fBanzaiSland:|r " .. L["the island was locked by the game in this fight and can't resize until it ends (%s). Please report this."]
                :format(#why > 0 and table.concat(why, ", ") or L["unknown cause"]))
        end
    else
        -- Whole, even screen pixels: a fractional width puts the text (anchored to the edges or centre)
        -- on a different sub-pixel each frame, so it shimmers while the spring settles. Which anchor
        -- shakes depends on where the centre lands, so snap the size rather than the position.
        -- Real pixels per UI unit: effective scale times the screen's pixels per 768 UI units.
        local es = self.island:GetEffectiveScale()
        local physH = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize()) or 768
        local ppu = (es or 1) * (physH or 768) / 768
        local a = self.anchor
        local cx, edge
        if a and a.GetCenter then
            cx = a:GetCenter()
            edge = self.up and a:GetBottom() or a:GetTop()
        end
        if ppu > 0 and cx and edge then
            -- Steps of 2 px measured from the resting target, so the spring's last tiny wobble
            -- (under a pixel) always rounds to the target itself instead of flipping between two
            -- sizes. The parity is chosen so the centred text (centre = edge +/- size/2) lands on a
            -- whole pixel wherever the island is anchored; a half-pixel position rounds either way
            -- from frame to frame, which was the shake.
            local function par(coord) return (floor(coord * ppu * 2 + 0.5) % 2) end   -- 0 = on a pixel, 1 = half
            local function snap(x, target, parity)
                local tp = (target * ppu - parity) / 2
                local tq = floor(tp + 0.5) * 2 + parity
                return max(2, tq + 2 * floor((x - target) * ppu / 2 + 0.5)) / ppu
            end
            local tw, th = max(min(30, STATES.idle.w), sw.t), max(min(24, STATES.idle.h), sh.t)
            -- grown from a side edge, the text is anchored to that fixed edge: whole-pixel widths
            w, ht = snap(w, tw, self.gx and 0 or par(cx)), snap(ht, th, par(edge))
        end
        self.island:SetSize(w, ht)
    end
    self.body:SetRadius(r)
    if self.borderRing and self.borderRing:IsShown() then self.borderRingBody:SetRadius(self.body:GetPaintRadius() or r, self.borderSize or 2) end

    -- content layers cross-fade
    local fading = false
    for _, l in pairs(self.layers) do
        if l.a ~= l.target then
            fading = true
            if l.target == 1 then
                if l.delay > 0 then
                    l.delay = l.delay - dt
                else
                    l.a = min(1, l.a + dt / (0.22 * FADE))
                end
            else
                l.a = max(0, l.a - dt / (0.12 * FADE))
            end
            l:SetAlpha(l.a)
            l:SetShown(l.a > 0)
        end
    end

    -- resting pill: the right slot swaps percent for the amount gained
    local c = self.c
    if self.amtA ~= self.amtT then
        local d = dt / 0.22
        self.amtA = (self.amtT > self.amtA) and min(self.amtT, self.amtA + d) or max(self.amtT, self.amtA - d)
        fading = true
    end
    local a = self.amtA
    local e = a * a * (3 - 2 * a)
    c.amt:SetAlpha(e)
    c.pct:SetAlpha(1 - e)
    c.amt:SetPoint("RIGHT", c.frame, "RIGHT", -13, -10 * (1 - e))
    -- what the resting pill shows (Idle display); anything bigger than the resting pill shows it all
    local style = (self.state == "idle" and not self.current) and (ns.db.idleStyle or "full") or "full"
    c.lv:SetShown(style == "full")
    c.pct:SetShown(style == "full" or style == "percent")
    c.bar:SetShown(style == "full" or style == "bar" or style == "dot")
    c.pct:ClearAllPoints()
    c.bar:ClearAllPoints()
    if style == "percent" then
        c.pct:SetPoint("CENTER", c.frame, "CENTER", 0, 10 * e)
    else
        c.pct:SetPoint("RIGHT", c.frame, "RIGHT", -13, 10 * e)
    end
    if style == "bar" or style == "dot" then
        local inset = (style == "dot") and 8 or 12
        c.bar:SetPoint("LEFT", c.frame, "LEFT", inset, 0)
        c.bar:SetPoint("RIGHT", c.frame, "RIGHT", -inset, 0)
    else
        local slot = 34 + max(0, w - STATES.idle.w)
        c.bar:SetPoint("LEFT", c.lv, "RIGHT", 10, 0)
        c.bar:SetPoint("RIGHT", c.frame, "RIGHT", -(13 + slot + 10), 0)
    end

    -- bar fill eases toward its target and flashes white on a gain
    self.p = self.p + (self.pT - self.p) * min(1, dt * 7)
    self.r = self.r + (self.rT - self.r) * min(1, dt * 7)
    if abs(self.pT - self.p) < 0.0003 then self.p = self.pT end
    if abs(self.rT - self.r) < 0.0003 then self.r = self.rT end
    self.q = self.q + (self.qT - self.q) * min(1, dt * 7)
    if abs(self.qT - self.q) < 0.0003 then self.q = self.qT end
    if self.hit > 0 then self.hit = max(0, self.hit - dt * 2) end
    local fc = self.fillColor or ns.BarColor()
    local k = self.hit * 0.75
    local fr, fg, fb = fc[1] + (1 - fc[1]) * k, fc[2] + (1 - fc[2]) * k, fc[3] + (1 - fc[3]) * k
    for _, bar in ipairs(self.bars) do
        bar.fill:SetColor(fr, fg, fb, 1)
        bar:Set(self.p, self.r, self.q)
    end

    -- level up: number roll, chips, gold ring
    local l = self.l
    l.old:SetPoint("TOPLEFT", l.clip, "TOPLEFT", 0, roll.x)
    l.new:SetPoint("TOPLEFT", l.clip, "TOPLEFT", 0, roll.x - ROLL_H)
    if self.state == "levelup" then
        for i = 1, 3 do
            local ca = clamp((self.stateT - (0.45 + 0.1 * i)) / 0.3, 0, 1)
            l.chips[i]:SetAlpha(ca)
        end
    end
    if self.flashT then
        self.flashT = self.flashT + dt
        local f = self.flashT / 1.1
        if f >= 1 then
            self.flashT = nil
            self.ring:Hide()
        else
            local grow = 22 * (1 - (1 - f) * (1 - f))
            self.ring:SetSize(w + 2 * grow, ht + 2 * grow)
            self.ring.body:SetRadius(min(r + grow, (ht + 2 * grow) / 2))
            self.ring:SetAlpha(0.75 * (1 - f))
            self.ring:Show()
        end
    end

    -- activity bubbles, side by side to the right of the island (or left, or in a row under it)
    local side = ns.db.bubbleSide or "right"
    local x, last, rowW = 0, nil, 0
    local row = self.bubbleRow
    if not row then
        row = {}
        for i, b in ipairs(self.bubbles) do row[i] = b end
        row[#row + 1] = self.chip
        self.bubbleRow = row
    end
    if side == "below" then             -- the row is centred, so measure it first
        local n = 0
        for _, b in ipairs(row) do
            local bs = clamp(b.showS.x, 0, 1.15)
            if bs >= 0.02 then
                local k = 0.4 + 0.6 * bs
                rowW = rowW + max(36 * k, b.widS.x * k) + (n > 0 and 6 * bs or 0)
                n = n + 1
            end
        end
    end
    local rowH = 0
    for _, b in ipairs(row) do
        local bs = clamp(b.showS.x, 0, 1.15)
        if bs < 0.02 then
            b:Hide()
        else
            local k = 0.4 + 0.6 * bs
            local hgt = 36 * k
            local wid = max(hgt, b.widS.x * k)
            b:SetSize(wid, hgt)
            self:SetBubbleRadius(b, hgt / 2)
            if b.isChip then
                b.text:SetAlpha(min(1, bs))
            else
                b.icon:SetSize(hgt * 0.44, hgt * 0.44)
                b.icon:SetPoint("LEFT", b, "LEFT", hgt * 0.28, 0)
                b.text:SetAlpha(clamp((b.widS.x - 44) / 20, 0, 1) * min(1, bs))
            end
            if side == "below" then
                x = x + (last and 6 * bs or 0)
                b:ClearAllPoints()
                if self.gx == "left" then b:SetPoint("TOPLEFT", self.island, "BOTTOMLEFT", x, -6 * bs)
                elseif self.gx == "right" then b:SetPoint("TOPLEFT", self.island, "BOTTOMRIGHT", x - rowW, -6 * bs)
                else b:SetPoint("TOPLEFT", self.island, "BOTTOM", -rowW / 2 + x, -6 * bs) end
                rowH = max(rowH, hgt + 6 * bs)
            else
                -- level with the island's resting row, so they sit in the same place whether the
                -- island is a slim pill or a tall card
                x = x + (last and 6 or 8) * bs
                self:Beside(b, side, x, hgt)
            end
            x = x + wid
            b:SetAlpha(min(1, bs))
            b:Show()
            if bs > 0.5 then last = b end
        end
    end
    self.bubbleRowH = rowH
    self.lastBubble = last

    -- red error pill, dropping out underneath
    local es = clamp(self.errS.x, 0, 1.15)
    local ep = self.errPill
    if es < 0.02 then
        ep:Hide()
    else
        local k = 0.6 + 0.4 * es
        local pw = max(26, (ep.w or 120) * k)
        ep:SetSize(pw, 26 * k)
        self:SetBubbleRadius(ep, 13 * k)
        ep:ClearAllPoints()
        local hp = self.gx == "left" and "LEFT" or self.gx == "right" and "RIGHT" or ""
        ep:SetPoint("TOP" .. hp, self.island, "BOTTOM" .. hp, 0, -2 - 6 * es - (self.bubbleRowH or 0))
        ep:SetAlpha(min(1, es))
        ep.text:SetAlpha(clamp((es - 0.5) * 2, 0, 1))
        ep:Show()
    end

    -- warning dot, sliding out to the left. If the island's left edge is the fixed one the dot goes
    -- right, past the bubbles when they are on that side too.
    local pside0 = (ns.db.bubbleSide == "left") and "right" or "left"
    local wx = 0
    -- the navigation pill (placed by PlaceNav) sits after the bubbles on their side: count its width
    -- so the dot and pins that share that side start beyond it instead of on top of it
    local navW = 0
    local nf = ns.Nav and ns.Nav.frame
    if side ~= "below" and nf and nf:IsShown() then navW = (x > 0 and 6 or 8) + (nf:GetWidth() or 36) end
    if side ~= "below" and (x > 0 or navW > 0) and self:Flip(pside0) == self:Flip(side) then wx = x + navW end
    local ws = clamp(self.warn.x, 0, 1.15)
    local wd = self.warnDot
    if ws < 0.02 then
        wd:Hide()
    else
        local hgt = 36 * (0.4 + 0.6 * ws)
        wd:SetSize(hgt, hgt)
        self:SetBubbleRadius(wd, hgt / 2)
        wd.icon:SetSize(hgt * 0.48, hgt * 0.48)
        self:Beside(wd, pside0, wx + 8 * ws, hgt)
        wd:SetAlpha(min(1, ws))
        wd:Show()
    end

    -- pinned bubbles: the warning dot's side, beyond the dot when it is out
    local pside = pside0
    local px = wx + ((ws >= 0.02) and (8 * ws + 36 * (0.4 + 0.6 * ws)) or 0)
    local firstPin = true
    for _, b in ipairs(self.pins) do
        local bs = clamp(b.showS.x, 0, 1.15)
        if bs < 0.02 then
            b:Hide()
        else
            local k = 0.4 + 0.6 * bs
            local hgt = 36 * k
            local wid = max(hgt, b.widS.x * k)
            b:SetSize(wid, hgt)
            self:SetBubbleRadius(b, hgt / 2)
            b.icon:SetSize(hgt * 0.44, hgt * 0.44)
            b.icon:SetPoint("LEFT", b, "LEFT", hgt * 0.28, 0)
            b.text:SetAlpha(clamp((b.widS.x - 44) / 20, 0, 1) * min(1, bs))
            px = px + ((firstPin and px == 0) and 8 or 6) * bs
            firstPin = false
            self:Beside(b, pside, px, hgt)
            px = px + wid
            b:SetAlpha(min(1, bs))
            b:Show()
        end
    end

    if not self.current and not fading and not self.flashT and self.hit == 0
        and self.p == self.pT and self.r == self.rT and self.q == self.qT
        and Resting(sw) and Resting(sh) and Resting(sr) and Resting(self.warn) and Resting(self.errS) and not self.errT and Resting(roll) and self:BubblesResting() then
        self.awake = false
    end
end
