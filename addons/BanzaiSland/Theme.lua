-- BanzaiSland: the BANZAI visual language in one place. Palette, materials (Banzai Glass, Solid,
-- Hardkorh Parchment), accent themes (Banzai, Class, Hardkorh), typography (the display face for display
-- text, the bundled information font for everything small), the original Banzai class artwork and
-- the colours of card buttons. Feature modules never paint from here directly: Island.lua and
-- Renderer.lua read ns.Theme at their presentation boundaries, so business/event logic stays as
-- upstream Island wrote it.
--
-- Settings this file adds to the profile (ns.defaults): material, accentTheme, bambooCaps,
-- bubbleRing, hairline, displayFont, classArt. It also turns the upstream defaults opacity /
-- accentMode / barMode to the Banzai look; a player's own choice is kept as always.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)

local Theme = {}
ns.Theme = Theme

Theme.MEDIA = "Interface\\AddOns\\BanzaiSland\\Media\\Banzai\\"

-- ---------------------------------------------------------------- palette
-- the BANZAI colours (as BANZAI UI Theme.COLORS), plus the structural darks and the semantic tones
local COLORS = {
    lime     = { 0.62, 1.00, 0.12 },
    emerald  = { 0.00, 0.90, 0.42 },
    teal     = { 0.00, 0.76, 0.72 },
    violet   = { 0.56, 0.22, 1.00 },
    purple   = { 0.62, 0.10, 0.86 },
    bright   = { 0.30, 1.00, 0.30 },   -- HARDKORH's bright green
    glass    = { 0.015, 0.075, 0.045 }, -- deep green-black glass
    solid    = { 0.030, 0.070, 0.050 }, -- the solid material's green-black
    charcoal = { 0.08, 0.09, 0.09 },   -- structural depth (caps' shadow, tracks)
    crimson  = { 0.82, 0.06, 0.22 },   -- decline / destructive
    amber    = { 1.00, 0.70, 0.00 },   -- attention
    fg       = { 0.95, 0.97, 0.93 },   -- readable off-white with a touch of green
    muted    = { 0.58, 0.68, 0.60 },   -- secondary text on green glass
    parchFg  = { 0.169, 0.157, 0.133 }, -- PARCHMENT INK: primary, dark warm charcoal (#2B2822)
    parchMuted = { 0.290, 0.263, 0.216 }, -- PARCHMENT INK: secondary, warm dark brown-grey (#4A4337)
}
Theme.COLORS = COLORS

-- ---------------------------------------------------------------- parchment ink palette (0.2.0, retuned 0.3.0)
-- Text on the cream paper: the screen colours of the glass are far too bright there, so on the
-- parchment material every text colour is mapped to an ink. Named inks for the semantic families;
-- any other saturated colour (item qualities, custom picks) is darkened on its own hue until it clears
-- the contrast target, so its meaning stays recognisable; the thirteen class colours have their own
-- hand-set inks (Theme.CLASS_INK). The paper is measured from the tile as it is drawn (x 0.91):
-- PAPER is its mean, PAPER_DARK the mean of its darkest 2 % of grain - every ink must clear the
-- contrast target against the DARK grain, not only the average (0.3.0: the 0.2.0 inks cleared the
-- average and still read washed on the grain in play).
Theme.PAPER = { 0.894, 0.812, 0.631 }
Theme.PAPER_DARK = { 0.847, 0.754, 0.575 }
Theme.INK_CONTRAST = 4.5  -- the gate (WCAG AA for normal text), against Theme.PAPER_DARK
Theme.INK_TARGET = 5.0    -- what a derived ink is darkened to, so the gate is cleared with a margin
local INK = {
    primary   = COLORS.parchFg,
    secondary = COLORS.parchMuted,
    success   = { 0.106, 0.337, 0.204 },  -- deep forest / emerald ink (#1B5634)
    arcane    = { 0.376, 0.216, 0.435 },  -- deep plum / violet ink (#60376F)
    info      = { 0.082, 0.314, 0.345 },  -- dark teal (#155058)
    blue      = { 0.149, 0.267, 0.502 },  -- deep desaturated blue (#264480)
    warning   = { 0.420, 0.267, 0.063 },  -- burnt amber / dark ochre (#6B4410)
    error     = { 0.494, 0.173, 0.208 },  -- deep wine / crimson (#7E2C35)
}
Theme.INK = INK
-- the class colours as inks: each keeps its hue, darkened to the target against the dark grain; Priest's
-- white cannot be an ink, so Priest is a dark silver-grey - cooler than the charcoal primary, still Priest
local CLASS_INK = {
    DEATHKNIGHT = { 0.568, 0.092, 0.173 },
    DEMONHUNTER = { 0.445, 0.131, 0.549 },
    DRUID       = { 0.430, 0.238, 0.070 },
    EVOKER      = { 0.108, 0.312, 0.269 },
    HUNTER      = { 0.216, 0.305, 0.095 },
    MAGE        = { 0.062, 0.312, 0.378 },
    MONK        = { 0.053, 0.327, 0.216 },
    PALADIN     = { 0.550, 0.090, 0.293 },
    PRIEST      = { 0.271, 0.271, 0.302 },
    ROGUE       = { 0.310, 0.291, 0.050 },
    SHAMAN      = { 0.081, 0.293, 0.499 },
    WARLOCK     = { 0.235, 0.240, 0.620 },
    WARRIOR     = { 0.374, 0.264, 0.146 },
}
Theme.CLASS_INK = CLASS_INK
-- the screen colours the game gives the classes (RAID_CLASS_COLORS), so a class-coloured text can be
-- recognised by value and take its class ink; a class-colour addon's custom colours register too
local CLASS_SCREEN = {
    DEATHKNIGHT = { 196 / 255, 30 / 255, 58 / 255 }, DEMONHUNTER = { 163 / 255, 48 / 255, 201 / 255 }, DRUID = { 255 / 255, 124 / 255, 10 / 255 },
    EVOKER = { 51 / 255, 147 / 255, 127 / 255 }, HUNTER = { 170 / 255, 211 / 255, 114 / 255 }, MAGE = { 63 / 255, 199 / 255, 235 / 255 },
    MONK = { 0 / 255, 255 / 255, 152 / 255 }, PALADIN = { 244 / 255, 140 / 255, 186 / 255 }, PRIEST = { 1, 1, 254 / 255 }, ROGUE = { 255 / 255, 244 / 255, 104 / 255 },
    SHAMAN = { 0 / 255, 112 / 255, 221 / 255 }, WARLOCK = { 135 / 255, 136 / 255, 238 / 255 }, WARRIOR = { 198 / 255, 155 / 255, 109 / 255 },
}
-- Priest's screen colour here is one step off pure white (#FFFFFE, invisible on glass): so a Priest name
-- written by BanzaiSland can be told from a white item link or plain white text, which take the primary
-- ink. The game's own pure white (RAID_CLASS_COLORS.PRIEST) is deliberately NOT registered as Priest.
Theme.CLASS_SCREEN = CLASS_SCREEN
-- the screen colour BanzaiSland writes for a class (names in cards): the game's colour, Priest marked
function Theme.ClassScreen(token)
    local c = CLASS_SCREEN[token]
    if c then return c end
    local game = _G.RAID_CLASS_COLORS and token and _G.RAID_CLASS_COLORS[token]
    if game and game.r then return { game.r, game.g, game.b } end
    return nil
end
-- the |cffRRGGBB prefix for a class name, or nil for an unknown token
function Theme.ClassHex(token)
    local c = Theme.ClassScreen(token)
    if not c then return nil end
    return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end
ns.ClassHex = Theme.ClassHex

-- the accent ramps, start -> end (0 .. 1)
local STOPS = {
    banzai   = { { 0.00, COLORS.lime }, { 0.42, COLORS.emerald }, { 0.75, COLORS.violet }, { 1.00, COLORS.purple } },
    hardkorh = { { 0.00, COLORS.bright }, { 0.40, COLORS.emerald }, { 0.72, COLORS.violet }, { 1.00, COLORS.purple } },
}
Theme.STOPS = STOPS

Theme.MATERIALS = { "glass", "solid", "parchment" }
Theme.ACCENTS = { "banzai", "class", "hardkorh" }
Theme.DISPLAY_FONTS = { "auto", "on", "off" }
Theme.CHASSIS = { "bamboo", "hairline" } -- 0.2.0: CHASSIS EDGE STYLE

-- ---------------------------------------------------------------- defaults
-- added to the profile defaults before ADDON_LOADED fills the saved settings
ns.defaults.material = "glass"
ns.defaults.accentTheme = "banzai"
ns.defaults.chassisEdge = "bamboo"    -- 0.2.0: bamboo (0.1.0's caps) or hairline (a four-sided thin frame)
ns.defaults.bambooCaps = true
ns.defaults.bubbleRing = true
ns.defaults.hairline = true
ns.defaults.displayFont = "BANZAI_DEFAULT"
ns.defaults.classArt = true
-- upstream defaults turned to the Banzai look (profile values a player set are kept by P.Fill)
ns.defaults.opacity = 0.82
ns.defaults.accentMode = "theme"
ns.defaults.barMode = "theme"
ns.defaults.panelBgColor = { COLORS.glass[1], COLORS.glass[2], COLORS.glass[3] } -- 0.2.0: the settings window is Banzai Glass

local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
local function db() return ns.db or ns.defaults end

function Theme.Material()
    local m = db().material
    if m ~= "glass" and m ~= "solid" and m ~= "parchment" then m = "glass" end
    return m
end
-- 0.2.0: the chassis edge style; anything unknown (and every 0.1.0 profile) is bamboo
function Theme.ChassisEdge()
    local e = db().chassisEdge
    if e ~= "bamboo" and e ~= "hairline" then e = "bamboo" end
    return e
end
function Theme.IsHairline() return Theme.ChassisEdge() == "hairline" end
function Theme.AccentTheme()
    local a = db().accentTheme
    if a ~= "banzai" and a ~= "class" and a ~= "hardkorh" then a = "banzai" end
    return a
end
function Theme.IsParchment() return Theme.Material() == "parchment" end

-- ---------------------------------------------------------------- colour maths
local function mix(a, b, t)
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end
Theme.Mix = mix

-- the colour at position t (0..1) along a ramp of { pos, color } stops
function Theme.ColorAt(stops, t)
    t = clamp(t or 0, 0, 1)
    local prev = stops[1]
    for i = 2, #stops do
        local cur = stops[i]
        if t <= cur[1] then
            local span = cur[1] - prev[1]
            return mix(prev[2], cur[2], span > 0 and (t - prev[1]) / span or 0)
        end
        prev = cur
    end
    return { prev[2][1], prev[2][2], prev[2][3] }
end

-- sRGB relative luminance and WCAG contrast (for the parchment inks)
local function lin(c) return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
function Theme.Luminance(c) return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3]) end
function Theme.Contrast(a, b)
    local la, lb = Theme.Luminance(a), Theme.Luminance(b)
    if la < lb then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end
local function rgb2hsl(r, g, b)
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local l = (mx + mn) / 2
    if mx == mn then return 0, 0, l end
    local d = mx - mn
    local s = l > 0.5 and d / (2 - mx - mn) or d / (mx + mn)
    local h
    if mx == r then h = (g - b) / d + (g < b and 6 or 0)
    elseif mx == g then h = (b - r) / d + 2
    else h = (r - g) / d + 4 end
    return h * 60, s, l
end
local function hue2rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1 / 6 then return p + (q - p) * 6 * t end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
    return p
end
local function hsl2rgb(h, s, l)
    if s == 0 then return { l, l, l } end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    h = h / 360
    return { hue2rgb(p, q, h + 1 / 3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1 / 3) }
end
Theme.RGBToHSL, Theme.HSLToRGB = rgb2hsl, hsl2rgb

-- ---------------------------------------------------------------- parchment ink mapping
-- The ink for a screen colour. Neutral light colours become the primary / secondary inks; a colour that
-- is already dark is left alone; a saturated colour keeps its hue and is darkened until it meets
-- Theme.INK_CONTRAST against the paper, with the named inks used for the semantic families so that
-- success stays green, warnings amber, errors wine, information teal, arcane plum.
local inkCache = {}
local function key255(r, g, b) return math.floor(r * 255 + 0.5) * 65536 + math.floor(g * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5) end
-- class colours by value -> class ink; the game's table first, then whatever a class-colour addon set
local classInkByKey
local function ClassInkFor(r, g, b)
    if not classInkByKey then
        classInkByKey = {}
        for token, c in pairs(CLASS_SCREEN) do classInkByKey[key255(c[1], c[2], c[3])] = CLASS_INK[token] end
        for _, source in ipairs({ _G.RAID_CLASS_COLORS, _G.CUSTOM_CLASS_COLORS }) do
            if type(source) == "table" then
                for token, c in pairs(source) do
                    -- a class-colour addon's custom colours register; the game's pure white stays plain white
                    if CLASS_INK[token] and type(c) == "table" and c.r and not (c.r >= 0.999 and c.g >= 0.999 and c.b >= 0.999) then
                        classInkByKey[key255(c.r, c.g, c.b)] = CLASS_INK[token]
                    end
                end
            end
        end
    end
    return classInkByKey[key255(r, g, b)]
end
-- the ink for a class token (badges, names): nil for an unknown token
function Theme.ClassInk(token) return CLASS_INK[token] end
-- hue buckets with the named ink of the family and how far (degrees) a colour may sit from the ink's own
-- hue and still take the family ink; further away (an item quality, a custom pick) it keeps its hue
local FAMILIES = {
    { 160, 215, "info", 30 },    -- cyans / teals (before the greens: 160-170 is teal, not green)
    { 60, 160, "success", 60 },  -- greens, lime through emerald
    { 215, 262, "blue", 30 },    -- blues
    { 262, 345, "arcane", 45 },  -- violets, purples, magentas
    { 15, 60, "warning", 30 },   -- oranges, golds, yellows
}
local function Reads(c) return Theme.Contrast(c, Theme.PAPER_DARK) >= Theme.INK_CONTRAST end
-- darken a colour on its own hue until it reaches the target against the dark grain
local function Darken(h, s, l)
    local c = hsl2rgb(h, s, l)
    local guard = 0
    while Theme.Contrast(c, Theme.PAPER_DARK) < Theme.INK_TARGET and l > 0.06 and guard < 60 do
        l = l - 0.01
        c = hsl2rgb(h, s, l)
        guard = guard + 1
    end
    return c
end
local function InkFor(r, g, b)
    local class = ClassInkFor(r, g, b)
    if class then return class end
    local h, s, l = rgb2hsl(r, g, b)
    local chroma = math.max(r, g, b) - math.min(r, g, b)
    if chroma < 0.12 then
        if l > 0.75 then return INK.primary end
        if l > 0.45 then return INK.secondary end
        if Reads({ r, g, b }) then return { r, g, b } end
        return Darken(h, s, l) -- a mid grey that does not read on the grain
    end
    -- a dark saturated colour that already reads on the grain stays as it is
    if Reads({ r, g, b }) and l < 0.4 then return { r, g, b } end
    local named, tolerance
    for _, fam in ipairs(FAMILIES) do
        if h >= fam[1] and h < fam[2] then named, tolerance = INK[fam[3]], fam[4] break end
    end
    if not named and (h >= 345 or h < 15) then named, tolerance = INK.error, 20 end
    local function angle(a, b2) local d = math.abs(a - b2) % 360 return d > 180 and 360 - d or d end
    if named then
        local nh = rgb2hsl(named[1], named[2], named[3])
        if angle(h, nh) <= tolerance then return named end
    end
    -- its own hue, darkened to the target
    return Darken(h, math.min(s, 0.85), math.min(l, 0.34))
end
function Theme.Ink(r, g, b)
    if type(r) == "table" then r, g, b = r[1], r[2], r[3] end
    if not (r and g and b) then return INK.primary end
    -- cached per 1/255 step: the same few colours come through thousands of times
    local key = key255(clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1))
    local c = inkCache[key]
    if not c then
        c = InkFor(clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1))
        inkCache[key] = c
    end
    return c
end
-- the colour a text should draw for a surface: paper takes the ink, glass / solid / a dark disc keeps the
-- screen colour. Feature modules name the intent (a screen colour); the surface decides what is drawn.
function Theme.SurfaceColor(surface, r, g, b)
    if type(r) == "table" then r, g, b = r[1], r[2], r[3] end
    if surface == "paper" then return Theme.Ink(r, g, b) end
    return { r, g, b }
end
-- the ink for an `RRGGBB` hex colour code, as a hex string (for |cAARRGGBB spans in card text)
local hexCache = {}
function Theme.InkHex(hex)
    local out = hexCache[hex]
    if out then return out end
    local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
    if not (r and g and b) then hexCache[hex] = hex return hex end
    local c = Theme.Ink(r / 255, g / 255, b / 255)
    out = string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
    hexCache[hex] = out
    return out
end
local function InkText(text)
    if type(text) ~= "string" or not text:find("|c", 1, true) then return text end
    return (text:gsub("|c(%x%x)(%x%x%x%x%x%x)", function(a, hex) return "|c" .. a .. Theme.InkHex(hex) end))
end
Theme.InkText = InkText

-- Font strings on the parchment sheet remember the colour and text they were given and show the ink
-- version while the material is parchment; switching materials re-applies every one (ReinkAll), so
-- the glass and solid palettes come back exactly. Island.lua wraps each text it creates on the island.
local inked = setmetatable({}, { __mode = "k" })
function Theme.InkWrap(fs)
    if inked[fs] then return fs end
    local rawColor, rawText, rawGet, rawFormatted = fs.SetTextColor, fs.SetText, fs.GetTextColor, fs.SetFormattedText
    fs.__inkR, fs.__inkG, fs.__inkB, fs.__inkA = 1, 1, 1, 1
    fs.SetTextColor = function(self, r, g, b, a)
        self.__inkR, self.__inkG, self.__inkB, self.__inkA = r, g, b, a
        if Theme.IsParchment() and r and g and b then
            local c = Theme.Ink(r, g, b)
            rawColor(self, c[1], c[2], c[3], a)
        else
            rawColor(self, r, g, b, a)
        end
    end
    -- upstream logic compares the colour it asked for (NeutralText), so the request is what it reads back
    fs.GetTextColor = function(self)
        if self.__inkR then return self.__inkR, self.__inkG, self.__inkB, self.__inkA end
        return rawGet(self)
    end
    fs.SetText = function(self, text)
        self.__inkText = text
        if Theme.IsParchment() then rawText(self, InkText(text)) else rawText(self, text) end
    end
    -- 0.3.0: the formatted form takes the same road (colour spans inside the format or its arguments)
    if rawFormatted then
        fs.SetFormattedText = function(self, fmt, ...) self:SetText(string.format(fmt, ...)) end
    end
    inked[fs] = { rawColor, rawText }
    return fs
end
function Theme.ReinkAll()
    for fs, raw in pairs(inked) do
        if fs.__inkR then fs:SetTextColor(fs.__inkR, fs.__inkG, fs.__inkB, fs.__inkA) end
        if fs.__inkText ~= nil then fs:SetText(fs.__inkText) end
    end
end
function Theme.IsInked(fs) return inked[fs] ~= nil end

-- the player's class colour (or the class-colour addon's); nil when unknown (tests, early load)
function Theme.ClassColor()
    if ns.ClassColor then
        local c = ns.ClassColor()
        if c then return c end
    end
    return nil
end

-- CLASS: the class colour's family (dark -> colour -> light) with the Banzai structural accent kept
-- restrained (violet / purple only at the far end)
local function ClassStops()
    local c = Theme.ClassColor() or COLORS.emerald
    local dark = mix(c, COLORS.charcoal, 0.35)
    local light = mix(c, { 1, 1, 1 }, 0.35)
    return { { 0.00, dark }, { 0.45, c }, { 0.80, light }, { 1.00, mix(light, COLORS.violet, 0.35) } }
end

-- the active accent ramp
function Theme.Stops()
    local a = Theme.AccentTheme()
    if a == "class" then return ClassStops() end
    return STOPS[a] or STOPS.banzai
end

-- the accent colour at t along the active ramp
function Theme.Accent(t) return Theme.ColorAt(Theme.Stops(), t or 0) end

-- the one colour that stands for the accent (bars, percentages): the ramp's start, or the class colour
function Theme.Primary()
    if Theme.AccentTheme() == "class" then return Theme.ClassColor() or COLORS.emerald end
    return Theme.Stops()[1][2]
end
-- the counter-colour at the far end (alternate buttons, the right-hand cap)
function Theme.Secondary() return Theme.Accent(1) end

-- ---------------------------------------------------------------- materials
-- the shell: fill colour and alpha for the island body, cards, bubbles, warning dot, error pill
function Theme.ShellFill(opacity)
    local m = Theme.Material()
    local o = clamp(opacity or db().opacity or 1, 0.1, 1)
    if m == "solid" then
        local c = COLORS.solid
        return c[1], c[2], c[3], 1
    end
    -- parchment keeps a thin glass under its paper for the moments the paper is not built yet
    local c = COLORS.glass
    return c[1], c[2], c[3], o
end

-- text colours for the active material
function Theme.Text()
    if Theme.IsParchment() then return COLORS.parchFg, COLORS.parchMuted end
    return COLORS.fg, COLORS.muted
end

-- the progress track under a bar
function Theme.Track()
    if Theme.IsParchment() then return 0, 0, 0, 0.22 end
    return 0.55, 0.75, 0.55, 0.14
end

-- ---------------------------------------------------------------- parchment geometry
-- HARDKORH PARCHMENT: one material that never stretches (the corrected tiled architecture of BANZAI UI
-- 1.3.7). The body tile repeats at `density` texels per UI unit on both axes, so a wider card shows
-- more paper, never larger paper; the worn edge strips repeat along each side from both corners and
-- mirror where they meet; the corners are fixed squares of the corner atlas.
Theme.PARCHMENT = { tileW = 1024, tileH = 512, density = 2, edgeW = 512, edgeH = 256, corners = 128, period = 8,
    corner = 14, -- the corner size in UI units on the island (fixed; the paper grain stays the same size)
    textures = {
        tile = { Theme.MEDIA .. "ParchmentTile", "REPEAT", "REPEAT" },
        corners = { Theme.MEDIA .. "ParchmentCorners", "CLAMP", "CLAMP" },
        edge = { Theme.MEDIA .. "ParchmentEdge", "REPEAT", "CLAMP" },
    } }

-- the 13 pieces for a pw x ph sheet (x right, y down from its top-left), as BANZAI UI Compat.ParchmentLayout
function Theme.ParchmentLayout(pw, ph, phaseU, phaseV)
    local M = Theme.PARCHMENT
    local c = math.min(M.corner, pw / 2, ph / 2)
    local period = M.period * c
    local pieces = {}
    local function add(name, texture, x0, y0, x1, y1, ...)
        pieces[#pieces + 1] = { name = name, texture = texture, x0 = x0, y0 = y0, x1 = x1, y1 = y1, coords = { ... } }
    end
    local u0, v0 = phaseU or 0, phaseV or 0
    local u1, v1 = u0 + pw * M.density / M.tileW, v0 + ph * M.density / M.tileH
    add("body", "tile", 0, 0, pw, ph, u0, v0, u0, v1, u1, v0, u1, v1)
    add("TOPLEFT", "corners", 0, 0, c, c, 0, 0, 0, 0.5, 0.5, 0, 0.5, 0.5)
    add("TOPRIGHT", "corners", pw - c, 0, pw, c, 0.5, 0, 0.5, 0.5, 1, 0, 1, 0.5)
    add("BOTTOMLEFT", "corners", 0, ph - c, c, ph, 0, 0.5, 0, 1, 0.5, 0.5, 0.5, 1)
    add("BOTTOMRIGHT", "corners", pw - c, ph - c, pw, ph, 0.5, 0.5, 0.5, 1, 1, 0.5, 1, 1)
    local mx, my = pw / 2, ph / 2
    local uw, uh = (mx - c) / period, (my - c) / period
    add("top1", "edge", c, 0, mx, c, 0, 0, 0, 0.25, uw, 0, uw, 0.25)
    add("top2", "edge", mx, 0, pw - c, c, uw, 0, uw, 0.25, 0, 0, 0, 0.25)
    add("bottom1", "edge", c, ph - c, mx, ph, 0, 0.75, 0, 0.5, uw, 0.75, uw, 0.5)
    add("bottom2", "edge", mx, ph - c, pw - c, ph, uw, 0.75, uw, 0.5, 0, 0.75, 0, 0.5)
    add("left1", "edge", 0, c, c, my, 0, 1, uh, 1, 0, 0.75, uh, 0.75)
    add("left2", "edge", 0, my, c, ph - c, uh, 1, 0, 1, uh, 0.75, 0, 0.75)
    add("right1", "edge", pw - c, c, pw, my, 0, 0.25, uh, 0.25, 0, 0.5, uh, 0.5)
    add("right2", "edge", pw - c, my, pw, ph - c, uh, 0.25, 0, 0.25, uh, 0.5, 0, 0.5)
    return pieces, c, period
end

-- ---------------------------------------------------------------- bamboo geometry
-- texture facts (BANZAI UI Compat.PANEL): the stalk strip is texH px tall with a texD px stalk in it,
-- one node period is periodPx px (periods of them across the strip), a tip piece is tipPx px with a
-- tipGap px seam between the two tips in StalkEnd
Theme.BAMBOO = { texD = 88, texH = 128, tipPx = 256, periodPx = 256, periods = 4, tipGap = 6,
    diameter = 10,  -- the cap's stalk diameter in UI units at scale 1
    overhang = 3,   -- how far a cap reaches past the island's top and bottom
    inset = 0.45 }  -- the cap's axis sits this many diameters inside the island's end

-- ---------------------------------------------------------------- typography
-- ---------------------------------------------------------------- brand (0.2.0)
-- The integrated BANZAI SLAND wordmark: the BANZAI half is BANZAI UI's own bamboo wordmark texture
-- (512 x 128, letters inside the crop below), the SLAND half is the display face. One mark, two hit
-- zones. Tunables for baseline, gap, size and colour live here, not in the renderer.
Theme.BRAND = {
    texture = Theme.MEDIA .. "BanzaiWordmark",
    crop = { 0.1113, 0.8887, 0, 1 },   -- the opaque part of the texture (alpha > 40/255): U 57..454 of 512
    aspect = (0.8887 - 0.1113) * 512 / 128, -- width / height of the cropped letters
    height = 22,                        -- the BANZAI letters' drawn height on the chassis
    slandSize = 17,                     -- SLAND font size (the display face sits a little small for its em)
    slandDy = -2.5,                     -- SLAND baseline nudge, up is positive (0.2.1: 1.5 lower than 0.2.0 =
                                        -- about 2 rendered px at 2560 x 1440, UI scale 0.71; the sizes and gap unchanged)
    gap = -3,                           -- BANZAI -> SLAND spacing (negative tucks SLAND under the blossom)
    pad = 4,                            -- hit zone padding around each half
    hoverGlow = 0.35,                   -- additive copy of the BANZAI letters on hover
    sland = COLORS.violet,              -- SLAND colour on glass / solid
    slandHover = { 0.78, 0.56, 1.00 },  -- lighter violet on hover
    slandInk = nil,                     -- on parchment: Theme.Ink(violet) = plum (resolved at paint time)
    lineGap = 6,                        -- the top hairline stops this far from the wordmark on each side
    settingsHeight = 26,                -- the mark in the settings header
}

-- ---------------------------------------------------------------- settings window surfaces (0.2.0)
Theme.UI = {
    radius = 6,         -- controls (soft chamfer)
    groupRadius = 8,    -- row groups, menus
    windowRadius = 10,  -- the window itself
    navRadius = 6,      -- sidebar items
    control = { 1, 1, 1, 0.08 }, controlHover = { 1, 1, 1, 0.15 },
    navSelected = { 0, 0, 0, 0.30 }, navHover = { 1, 1, 1, 0.05 },
    well = { 0.01, 0.045, 0.03, 0.62 },   -- preview wells: dark translucent glass
    wellEdge = 0.55,                       -- alpha of the 1 px accent edge around a well
    heading = mix(COLORS.muted, COLORS.fg, 0.35),
}
Theme.LOGO = Theme.MEDIA .. "BanzaiIcon" -- the BANZAI B logo

-- ---------------------------------------------------------------- class artwork
local CLASS_ART = { DEATHKNIGHT = "deathknight", DEMONHUNTER = "demonhunter", DRUID = "druid", EVOKER = "evoker",
    HUNTER = "hunter", MAGE = "mage", MONK = "monk", PALADIN = "paladin", PRIEST = "priest", ROGUE = "rogue",
    SHAMAN = "shaman", WARLOCK = "warlock", WARRIOR = "warrior" }
Theme.CLASS_ART = CLASS_ART
-- the texture path of a class token's Banzai identity, or nil (unknown class, or class art switched off)
function Theme.ClassArt(classToken)
    if db().classArt == false then return nil end
    local file = classToken and CLASS_ART[classToken]
    return file and (Theme.MEDIA .. "Identity\\" .. file) or nil
end
function Theme.PlayerClassArt()
    if not UnitClass then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    if not ok or type(token) ~= "string" then return nil end
    return Theme.ClassArt(token), token
end

-- ---------------------------------------------------------------- buttons
-- Card buttons by role: the first button of a card is the primary answer (Accept, Ready, Need, Join,
-- Release spirit), the last of several is the decline (Decline, Not ready, Pass, Cancel), the ones in
-- between are alternates (Greed, Disenchant). A lone button is the primary.
function Theme.ButtonRole(index, count)
    if count <= 1 or index == 1 then return "primary" end
    if index == count then return "decline" end
    return "alt"
end
-- fill r,g,b,a and text colour for a role; `hover` brightens, `muted` greys a disabled answer.
-- On parchment the fill is a tone laid over the paper and the label is the primary ink: the hover
-- strengthens the tone only as far as the label still clears the contrast gate against the blended
-- button surface (0.3.0; a crimson or class-red button at the full hover strength did not).
local function Blend(tone, a, under) return { tone[1] * a + under[1] * (1 - a), tone[2] * a + under[2] * (1 - a), tone[3] * a + under[3] * (1 - a) } end
function Theme.ButtonSurface(role, hover, muted)
    local r, g, b, a = Theme.ButtonColors(role, hover, muted)
    if Theme.IsParchment() then return Blend({ r, g, b }, a, Theme.PAPER) end
    local sr, sg, sb = Theme.ShellFill(1)
    return Blend({ r, g, b }, a, { sr, sg, sb })
end
function Theme.ButtonColors(role, hover, muted)
    local fg, mutedText = Theme.Text()
    if muted then return 1, 1, 1, hover and 0.14 or 0.07, mutedText end
    local tone
    if role == "primary" then tone = Theme.AccentTheme() == "class" and (Theme.ClassColor() or COLORS.emerald) or COLORS.emerald
    elseif role == "decline" then tone = COLORS.crimson
    else tone = COLORS.violet end
    local a = hover and 0.46 or 0.26
    if Theme.IsParchment() then
        local rest = 0.42
        a = hover and 0.62 or rest
        local ink = Theme.Ink(fg)
        while a > rest and Theme.Contrast(ink, Blend(tone, a, Theme.PAPER)) < Theme.INK_CONTRAST do a = a - 0.02 end
    end
    return tone[1], tone[2], tone[3], a, fg
end

-- ---------------------------------------------------------------- status
function Theme.Describe()
    return string.format("material %s, chassis %s, accent %s, caps %s, ring %s, display font %s, class art %s",
        Theme.Material(), Theme.ChassisEdge(), Theme.AccentTheme(), tostring(db().bambooCaps ~= false), tostring(db().bubbleRing ~= false),
        Theme.DisplayFontLabel and Theme.DisplayFontLabel(db().displayFont or "BANZAI_DEFAULT") or "Information Font",
        tostring(db().classArt ~= false))
end
