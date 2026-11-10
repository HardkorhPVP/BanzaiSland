-- Island: group loot rolls. The island opens into a roll card with a countdown and
-- Need / Greed / Pass buttons, lists what the rest of the group picked, and shows who won.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local ceil, max, min, floor = math.ceil, math.max, math.min, math.floor
local I, C = ns.Island, ns.C
local Theme = ns.Theme -- BanzaiSland
local MEDIA = ns.MEDIA
ns.recentWon = {}

ns.STATES.roll = { w = ns.WIDE, h = 124, r = 30, layer = "roll" }
ns.STATES.won = { w = ns.WIDE, h = 68, r = 27, layer = "won" }

I.rolls = {}

local NEED, GREED, DISENCHANT, PASS = 1, 2, 3, 0
local TYPE_LABEL = { [NEED] = L["Need"], [GREED] = L["Greed"], [DISENCHANT] = L["Disenchant"], [PASS] = L["Pass"] }
local TYPE_ORDER = { [NEED] = 1, [GREED] = 2, [DISENCHANT] = 3, [PASS] = 4 }
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local ROLL_H, NAMES_H = 124, 22
local NUM_H = 20
local SPIN_TICKS = 12
local NBSP = "\194\160"     -- keeps a name and its roll together when the line wraps

local function QualityColor(quality)
    local c = ITEM_QUALITY_COLORS and quality and ITEM_QUALITY_COLORS[quality]
    if c then return { c.r, c.g, c.b } end
    return C.fg
end

ns.QualityColor = QualityColor

local function Hex(r, g, b)
    return string.format("|cff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end
ns.Hex = Hex
local MUTED_HEX = Hex(C.muted[1], C.muted[2], C.muted[3])
local FG_HEX = Hex(C.fg[1], C.fg[2], C.fg[3])

local function Short(name)
    return ns.ShowName(name) or name
end

-- class color of a group member, by name
local function NameHex(name)
    local short = Short(name)
    local function try(unit)
        local unitName = UnitExists and UnitExists(unit) and UnitName(unit)
        -- names here can carry a second name ("Uglawhar Bearbrother") the unit name leaves off
        if unitName and (unitName == short or short:sub(1, #unitName + 1) == unitName .. " ") then
            local _, class = UnitClass(unit)
            local hex = class and ns.ClassHex and ns.ClassHex(class) -- BanzaiSland 0.3.0: one class-colour authority
            if hex then return hex end
        end
    end
    local hex = try("player")
    if hex then return hex end
    for i = 1, 4 do
        hex = try("party" .. i)
        if hex then return hex end
    end
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do
            hex = try("raid" .. i)
            if hex then return hex end
        end
    end
    return FG_HEX
end

-- "Thrall Need 94   Jaina Greed   Sylvanas Pass", names in class color
local function ChoiceLine(choices, withNumbers)
    if not choices or #choices == 0 then return "" end
    local sorted = {}
    for i, c in ipairs(choices) do sorted[i] = c end
    table.sort(sorted, function(a, b)
        local oa, ob = TYPE_ORDER[a.type] or 5, TYPE_ORDER[b.type] or 5
        if oa ~= ob then return oa < ob end
        if (a.num or 0) ~= (b.num or 0) then return (a.num or 0) > (b.num or 0) end
        return a.who < b.who
    end)
    local parts = {}
    for i, c in ipairs(sorted) do
        local tag = TYPE_LABEL[c.type] or ""
        if withNumbers and c.num then tag = tag .. NBSP .. c.num end
        -- non-breaking spaces keep a two-word name, and its roll, together on one line
        local shown = Short(c.who):gsub(" ", NBSP)
        parts[i] = (c.hex or NameHex(c.who)) .. shown .. "|r" .. NBSP .. MUTED_HEX .. tag:gsub(" ", NBSP) .. "|r"
    end
    return table.concat(parts, "   ")
end

-- ---------------------------------------------------------------- roll log

-- One entry per item being rolled on: who picked what, and what they rolled.
local log = {}

local function NewEntry(name)
    local now = GetTime()
    for i = #log, 1, -1 do
        if now - log[i].t > 300 then table.remove(log, i) end
    end
    local e = { name = name, choices = {}, byWho = {}, t = now }
    log[#log + 1] = e
    return e
end

local function FindEntry(name, accept)
    local first
    for _, e in ipairs(log) do
        if e.name == name then
            first = first or e
            if not accept or accept(e) then return e end
        end
    end
    return first or NewEntry(name)
end

local function Record(e, who, rollType, num, hex)
    local c = e.byWho[who]
    if not c then
        c = { who = who }
        e.byWho[who] = c
        e.choices[#e.choices + 1] = c
    end
    if rollType then c.type = rollType end
    if num then c.num = num end
    if hex then c.hex = hex end
    local roll = I.rolls[1]
    if I.state == "roll" and roll and roll.log == e then I:FillRoll() end
end

-- ---------------------------------------------------------------- cards

-- item tooltip, placed beside the island so it never covers the card
local function ShowTip(owner, fill)
    if not GameTooltip then return end
    ns.PlaceTip(GameTooltip, I.island, "RIGHT")
    pcall(fill)
    GameTooltip:Show()
end
local function HideTip() if GameTooltip then GameTooltip:Hide() end end

-- A private native tooltip leaves other hovers and the player's comparison CVar alone.
local rollTip, rollTipOwner, rollHover
local function OwnsRollComparison()
    return GameTooltip and rollTipOwner and GameTooltip:GetOwner() == rollTipOwner
end
local function HideRollTip(owner)
    if owner and rollHover and owner ~= rollHover.owner then return end
    local old = rollHover
    rollHover = nil
    if old then old.owner:SetScript("OnUpdate", nil) end
    if rollTip then rollTip:Hide() end
    if OwnsRollComparison() then GameTooltip:Hide() end
end
local function RenderRollTip(state, expanded)
    local target = expanded and GameTooltip or rollTip
    if not target then HideRollTip() return end
    if expanded then rollTip:Hide()
    elseif OwnsRollComparison() then GameTooltip:Hide() end
    local ok = pcall(function()
        ns.PlaceTip(target, I.island, "RIGHT")
        if expanded then
            -- A separate screen-rooted owner lets cleanup distinguish our full tip from a bag hover.
            local point, relative, relativePoint, x, y = target:GetPoint(1)
            target:SetOwner(rollTipOwner, "ANCHOR_NONE")
            target:ClearAllPoints()
            target:SetPoint(point, relative, relativePoint, x, y)
        end
        local roll = state.roll
        if roll.fake then target:SetHyperlink(roll.link)
        else target:SetLootRollItem(roll.id) end
        if not expanded then target:AddLine(L["Hold Shift to compare equipped items."], 0.6, 0.62, 0.7) end
        target:Show()
        if expanded and GameTooltip_ShowCompareItem then GameTooltip_ShowCompareItem(target) end
    end)
    if not ok then HideRollTip() return end
    state.expanded = expanded
end
local function ShowRollTip(owner, roll)
    HideRollTip()
    if not rollTip then
        rollTip = CreateFrame("GameTooltip", "BanzaiSlandRollItemTooltip", UIParent, "GameTooltipTemplate")
        rollTip.supportsItemComparison = false
        rollTip:SetClampedToScreen(true)
        rollTipOwner = CreateFrame("Frame", nil, UIParent)
    end
    local state = { owner = owner, roll = roll }
    rollHover = state
    RenderRollTip(state, IsShiftKeyDown and IsShiftKeyDown() or false)
    if rollHover ~= state then return end
    owner:SetScript("OnUpdate", function(self)
        if rollHover ~= state then return end
        if I.state ~= "roll" or I.rolls[1] ~= state.roll or not self:IsShown()
            or (state.expanded and not OwnsRollComparison()) then
            HideRollTip(self)
            return
        end
        local expanded = IsShiftKeyDown and IsShiftKeyDown() or false
        if expanded ~= state.expanded then RenderRollTip(state, expanded) end
    end)
end

function I:BuildRoll()
    local f = ns.Layer(self, "roll", ns.WIDE, ROLL_H + NAMES_H)
    local r = { frame = f, buttons = {}, isRoll = true }

    r.icon = ns.RoundIcon(f, 40)
    r.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -14)
    r.tile = ns.Image(f, "Tile", "ARTWORK", 0)        -- prompts (ready check, invites) use a glyph
    r.tile:SetSize(40, 40)
    r.tile:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -14)
    r.glyph = ns.Image(f, "Check", "ARTWORK", 1)
    r.glyph:SetSize(20, 20)
    r.glyph:SetPoint("CENTER", r.tile, "CENTER", 0, 0)

    -- hover the icon or the name for the item tooltip, shift-click to link it
    local tip = CreateFrame("Button", nil, f)
    tip:SetPoint("TOPLEFT", r.icon, "TOPLEFT", 0, 0)
    tip:SetSize(270, 40)
    tip:SetScript("OnEnter", function(self)
        local roll = I.rolls[1]
        if not roll or roll.prompt then return end
        ShowRollTip(self, roll)
    end)
    tip:SetScript("OnLeave", HideRollTip)
    tip:SetScript("OnHide", HideRollTip)
    tip:SetScript("OnClick", function()
        local roll = I.rolls[1]
        -- only real loot rolls have an item to link; prompts (death, invites, ...) do not
        if roll and not roll.fake and not roll.prompt and type(roll.id) == "number"
            and GetLootRollItemLink and HandleModifiedItemClick then
            local ok, link = pcall(GetLootRollItemLink, roll.id)
            if ok and link then HandleModifiedItemClick(link) end
        end
    end)

    r.time = ns.Text(f, "extra", 15, C.muted, "RIGHT")
    r.res = r.time
    r.time:SetPoint("RIGHT", f, "TOPRIGHT", -18, -34)
    r.cap = ns.Text(f, "bold", 10.5, C.muted)
    r.cap:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 12, -4)
    r.title = ns.Text(f, "display", 16, C.fg)
    r.title:SetPoint("TOPLEFT", r.cap, "BOTTOMLEFT", 0, -2)
    -- The timer and title share a row after their text has been set.

    local upgradeColor = { 0.36, 0.85, 0.45 }
    r.upgradeLabel = ns.Text(f, "bold", 10.5, upgradeColor)
    r.upgradeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -65)
    r.upgradeLabel:SetText(L["UPGRADE"])
    r.upgradeGain = ns.Text(f, "bold", 12, upgradeColor, "RIGHT")
    r.upgradeGain:SetPoint("TOPLEFT", r.upgradeLabel, "TOPRIGHT", 10, 0)
    r.upgradeGain:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -65)
    r.upgradeFrom = ns.Text(f, "medium", 12, C.muted)
    r.upgradeFrom:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -83)
    r.upgradeFrom:SetWidth(ns.WIDE - 32)
    if r.upgradeFrom.SetWordWrap then r.upgradeFrom:SetWordWrap(true) end
    if r.upgradeFrom.SetMaxLines then r.upgradeFrom:SetMaxLines(2) end

    r.bar = ns.CreateBar(f, 4, false)
    r.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -65)
    r.bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -65)

    -- what the rest of the group has picked so far
    r.names = ns.Text(f, "medium", 12, C.fg)
    r.names:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -79)
    r.names:SetWidth(ns.WIDE - 32)
    if r.names.SetWordWrap then r.names:SetWordWrap(true) end     -- everyone's pick, on as many lines as it takes
    if r.names.SetMaxLines then r.names:SetMaxLines(4) end
    if r.names.SetSpacing then r.names:SetSpacing(3) end

    -- role picker for group invites: up to three toggles between the timer and the buttons
    r.roles = {}
    for i = 1, 3 do
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(26)
        b.bg = ns.CreateCardButton(b, 26)
        b.text = ns.Text(b, "bold", 12, C.muted, "CENTER")
        b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
        b:SetScript("OnClick", function(self)
            local roll = I.rolls[1]
            local role = roll and roll.roles and roll.roles[self.index]
            if not role or roll.answerT then return end
            if roll.multiRole then
                role.on = not role.on
            else
                for _, other in ipairs(roll.roles) do other.on = (other == role) end
            end
            if roll.onRoles then pcall(roll.onRoles, roll) end
            I:FillRoll()
        end)
        b:Hide()
        r.roles[i] = b
    end

    for i = 1, 4 do
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(30)
        b.bg = ns.CreateCardButton(b, 30)
        b.text = ns.Text(b, "bold", 12.5, C.fg, "CENTER")
        b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.bg:SetColor(1, 1, 1, 0.10)
        b:SetScript("OnEnter", function(self) if self.spec and self.spec.enabled then self.bg:SetRole(self.role, true, self.spec.muted) end end)
        b:SetScript("OnLeave", function(self) if not (I.rolls[1] and I.rolls[1].answerT) then self.bg:SetRole(self.role, false, self.spec and self.spec.muted) end end)
        b:SetScript("OnClick", function(self) if self.spec and self.spec.enabled then I:AnswerRoll(self.spec) end end)
        r.buttons[i] = b
    end
    self.rl = r

    -- winner card
    local wf = ns.Layer(self, "won", ns.WIDE, 140)
    local w = { frame = wf }
    w.icon = ns.RoundIcon(wf, 40)
    w.icon:SetPoint("TOPLEFT", wf, "TOPLEFT", 14, -14)
    w.tile = ns.Image(wf, "Tile", "ARTWORK", 0)      -- used instead of an icon by cards with a glyph
    w.tile:SetSize(40, 40)
    w.tile:SetPoint("TOPLEFT", wf, "TOPLEFT", 14, -14)
    w.glyph = ns.Image(wf, "Star", "ARTWORK", 1)
    w.glyph:SetSize(20, 20)
    w.glyph:SetPoint("CENTER", w.tile, "CENTER", 0, 0)
    -- the winning roll: a label ("Need") and a number that spins like a slot reel
    local clip = CreateFrame("Frame", nil, wf)
    clip:SetSize(30, NUM_H)
    clip:SetPoint("RIGHT", wf, "TOPRIGHT", -18, -34)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    w.clip = clip
    w.numA = ns.Text(clip, "extra", 14, C.fg, "RIGHT")
    w.numB = ns.Text(clip, "extra", 14, C.fg, "RIGHT")
    w.numA:SetWidth(30)
    w.numB:SetWidth(30)
    w.res = ns.Text(wf, "extra", 14, C.fg, "RIGHT")
    w.res:SetPoint("RIGHT", wf, "TOPRIGHT", -18, -34)
    local wtip = CreateFrame("Button", nil, wf)
    wtip:SetPoint("TOPLEFT", w.icon, "TOPLEFT", 0, 0)
    wtip:SetSize(250, 40)
    wtip:SetScript("OnEnter", function(self)
        local item = I.current
        if not item or item.kind ~= "won" then return end
        if item.link and item.link:find("item:", 1, true) then
            ShowTip(self, function()
                GameTooltip:SetHyperlink(item.link)
                if item.hint then GameTooltip:AddLine(item.hint, 0.6, 0.62, 0.7) end
            end)
        elseif item.hint then
            ShowTip(self, function() GameTooltip:SetText(item.hint, 0.85, 0.86, 0.9) end)
        end
    end)
    wtip:SetScript("OnLeave", HideTip)
    w.tip = wtip
    wtip:SetScript("OnClick", function()
        local item = I.current
        if item and item.kind == "won" and item.onClick then
            pcall(item.onClick)
            item.dur = math.min(item.dur, item.t + 0.4)       -- it has been dealt with: close soon
            return
        end
        if item and item.kind == "won" and item.link and item.link:find("|H", 1, true) and HandleModifiedItemClick then
            HandleModifiedItemClick(item.link)
        end
    end)
    w.cap = ns.Text(wf, "bold", 10.5, C.muted)
    w.cap:SetPoint("TOPLEFT", w.icon, "TOPRIGHT", 12, -4)
    w.title = ns.Text(wf, "display", 16, C.fg)
    w.title:SetPoint("TOPLEFT", w.cap, "BOTTOMLEFT", 0, -2)
    w.title:SetPoint("RIGHT", w.res, "LEFT", -10, 0)
    w.names = ns.Text(wf, "medium", 12, C.fg)
    w.names:SetPoint("TOPLEFT", wf, "TOPLEFT", 14, -64)
    w.names:SetWidth(ns.WIDE - 32)
    if w.names.SetWordWrap then w.names:SetWordWrap(true) end
    if w.names.SetMaxLines then w.names:SetMaxLines(5) end
    if w.names.SetSpacing then w.names:SetSpacing(3) end
    -- a timer bar along the bottom, for cards that count down (a pull timer)
    w.bar = ns.CreateBar(wf, 4, false)
    w.bar:Hide()
    -- one button along the bottom, in the prompt cards' style (Cancel on your own pull timer)
    local btn = CreateFrame("Button", nil, wf)
    btn:SetHeight(30)
    btn:SetFrameLevel(wtip:GetFrameLevel() + 5)
    btn.bg = ns.CreateCardButton(btn, 30)
    btn.bg:SetColor(1, 1, 1, 0.10)
    btn.text = ns.Text(btn, "bold", 12.5, C.fg, "CENTER")
    btn.text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn:SetScript("OnEnter", function(self) self.bg:SetRole("primary", true) end)
    btn:SetScript("OnLeave", function(self) self.bg:SetRole("primary", false) end)
    btn:SetScript("OnClick", function()
        local item = I.current
        if not (item and item.kind == "won" and item.button) then return end
        local spec = item.button
        local ok, result = pcall(spec.fn, item)
        if not ok or result == false then return end -- keep the action available if it could not run
        item.button = nil
        btn.text:SetText(spec.done or L["Cancelled"])
        btn.bg:SetTextColor(C.muted)
        item.dur = math.min(item.dur, item.t + 0.6)
    end)
    btn:Hide()
    w.btn = btn
    self.wn = w
end

-- the buttons a card offers: Need / Greed / Pass for loot, or whatever a prompt supplies
local function Specs(roll)
    if roll.buttons then return roll.buttons end
    if not roll.specs then
        local specs = {
            { type = NEED, label = L["Need"], enabled = roll.canNeed },
            { type = GREED, label = L["Greed"], enabled = roll.canGreed },
        }
        if roll.canDisenchant then specs[#specs + 1] = { type = DISENCHANT, label = L["Disenchant"], enabled = true } end
        specs[#specs + 1] = { type = PASS, label = L["Pass"], enabled = true, muted = true }
        roll.specs = specs
    end
    return roll.specs
end

-- Poll only the visible roll, at most once a second: item data and saved sim results
-- may arrive after the roll starts. Never evaluate prompts or start a simulation here.
local function RefreshRollUpgrade(roll)
    local before = roll.upgradeInfo
    local info
    if not roll.prompt and ns.db.rollUpgrades ~= false and ns.GetUpgradeInfo then
        local link = roll.link
        if not roll.fake and GetLootRollItemLink then
            local ok, value = pcall(GetLootRollItemLink, roll.id)
            if ok and ns.Readable(value) then link = value end
        end
        if ns.Readable(link) and type(link) == "string" then
            local ok, value = pcall(ns.GetUpgradeInfo, link)
            if ok then info = value end
        end
    end
    roll.upgradeInfo = info
    roll.upgradeCheckAt = GetTime() + 1
    return (before and before.text) ~= (info and info.text)
        or (before and before.source) ~= (info and info.source)
        or (before and before.replacementName) ~= (info and info.replacementName)
end

local TEXT_LEFT = 14 + 40 + 12            -- where the text starts beside the icon
-- Measure the full header after applying its font, before allocating title space.
local function TextWidth(text)
    local value = text:GetText()
    if not ns.Readable(value) or type(value) ~= "string" or value == "" then return 0 end
    local width
    if text.GetUnboundedStringWidth then width = text:GetUnboundedStringWidth() end
    if not ns.Readable(width) or type(width) ~= "number" then
        local previous = text:GetWidth()
        text:SetWidth(0)
        width = text:GetStringWidth()
        text:SetWidth(previous or 0)
    end
    return ns.Readable(width) and type(width) == "number" and width or 0
end

local function HeaderWidth(w, layout, label)
    -- Keep timed prompts and their secure response overlays at their existing width.
    if w.isRoll then return ns.WIDE end
    local title, value = TextWidth(w.title), TextWidth(w.res)
    local cap = label and TextWidth(w.cap) or 0
    local tail = (w.clip and w.clip:IsShown()) and 33 or 0
    local wanted
    if layout == "classic" then
        wanted = math.max(TEXT_LEFT + title + value + tail + 28, TEXT_LEFT + cap + 18)
    else
        local padding = layout == "icon" and 2 * TEXT_LEFT or 40
        wanted = math.max(title + padding, cap + padding)
        if value + tail > 0 then wanted = math.max(wanted, title + 2 * (value + tail + 30)) end
    end
    local limit = 640
    if w == I.wn or w == I.rl then
        local scale = w.frame.GetEffectiveScale and w.frame:GetEffectiveScale()
        local screen = UIParent and UIParent.GetWidth and UIParent:GetWidth()
        local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
        if type(scale) == "number" and scale > 0 and type(screen) == "number" and type(uiScale) == "number" then
            local pixels = screen * uiScale
            local center = I.anchor and I.anchor.GetCenter and I.anchor:GetCenter()
            local anchorScale = I.anchor and I.anchor.GetEffectiveScale and I.anchor:GetEffectiveScale()
            if type(center) == "number" and type(anchorScale) == "number" then
                pixels = 2 * math.max(0, math.min(center * anchorScale, pixels - center * anchorScale))
            end
            limit = math.min(limit, math.max(ns.WIDE, pixels / scale - 32))
        end
    else
        -- The settings preview must stay inside its lighter background mat.
        local parent = w.frame.GetParent and w.frame:GetParent()
        local width = parent and parent.GetWidth and parent:GetWidth()
        if type(width) == "number" and width > 0 then limit = math.min(limit, math.max(ns.WIDE, width - 24)) end
    end
    return math.ceil(math.max(ns.WIDE, math.min(limit, wanted + 2)))
end

local function LayoutWon(w, layout, look)
    w.layout, w.look = layout, look
    -- Remove both sides before switching between a plain value and the roll reel.
    w.res:ClearAllPoints()
    if w.clip then w.clip:ClearAllPoints() end
    local wf = w.frame
    local label = not look or look.label ~= false
    w.cap:ClearAllPoints()
    w.title:ClearAllPoints()
    if not w.isRoll then w.names:ClearAllPoints() end
    w.cap:SetShown(label)
    if ns.ResizeText then ns.ResizeText(w.title, (look and look.title == "large") and 18 or 15) end
    local cardWidth = HeaderWidth(w, layout, label)
    w.cardWidth = cardWidth
    wf:SetWidth(cardWidth)
    if not w.isRoll then
        if w.bar then w.bar:SetWidth(cardWidth - 32) end
        if w.btn then
            w.btn:SetWidth(cardWidth - 32)
            w.btn.bg:SetWidth(cardWidth - 32)
        end
    end
    local state = w == I.wn and "won" or (w == I.rl and "roll")
    if state then
        ns.STATES[state].w = cardWidth
        if I.state == state and I.sw then I.sw.t = cardWidth end
    end
    if layout ~= "classic" then
        -- centred across the card, or (with the icon on the left) across the space beside the icon;
        -- narrower when there is a number on the right, so the two never meet
        -- always centred on the card itself; with the icon, kept as wide on the right as the icon
        -- takes on the left, so the text stays in the middle and clear of both
        local x = 0
        local width = (layout == "icon") and (cardWidth - 2 * TEXT_LEFT) or (cardWidth - 40)
        local rw = (w.res:GetText() or "") ~= "" and (w.res:GetStringWidth() or 0) or 0
        local tail = (w.clip and w.clip:IsShown()) and 33 or 0
        if rw + tail > 0 then width = math.min(width, cardWidth - 2 * (rw + tail + 30)) end
        width = math.max(1, width)
        if label then
            w.cap:SetPoint("TOP", wf, "TOP", x, -17)
            w.cap:SetJustifyH("CENTER")
            w.title:SetPoint("TOP", w.cap, "BOTTOM", 0, -3)
        else
            w.title:SetPoint("TOP", wf, "TOP", x, -24)
        end
        w.title:SetWidth(width)
        w.title:SetJustifyH("CENTER")
        local edge = (cardWidth - width) / 2 - 18
        if w.clip then w.clip:ClearAllPoints() end
        if w.clip then w.clip:SetPoint("RIGHT", w.title, "RIGHT", edge, 0) end
        if tail == 0 then
            w.res:SetPoint("RIGHT", w.title, "RIGHT", edge, 0)
        else
            w.res:SetPoint("RIGHT", w.clip, "LEFT", -3, 0)
        end
        if not w.isRoll then
            w.names:SetPoint("TOP", w.title, "BOTTOM", 0, -9)
            w.names:SetWidth(width)
            w.names:SetJustifyH("CENTER")
        end
    else
        w.cap:SetPoint("TOPLEFT", w.icon, "TOPRIGHT", 12, -4)
        w.cap:SetJustifyH("LEFT")
        w.title:SetWidth(0)              -- the anchors set its width again
        if label then
            w.title:SetPoint("TOPLEFT", w.cap, "BOTTOMLEFT", 0, -2)
        else
            w.title:SetPoint("LEFT", w.icon, "RIGHT", 12, 0)
        end
        local tail = (w.clip and w.clip:IsShown()) and 33 or 0
        ns.AlignCardRow(w.title, w.res, TEXT_LEFT, tail, cardWidth)
        if w.clip then w.clip:ClearAllPoints() end
        if w.clip then w.clip:SetPoint("LEFT", w.res, "RIGHT", 3, 0) end
        w.title:SetJustifyH("LEFT")
        if not w.isRoll then
            w.names:SetPoint("TOPLEFT", wf, "TOPLEFT", 14, -64)
            w.names:SetWidth(cardWidth - 32)
            w.names:SetJustifyH("LEFT")
        end
    end
end

ns.LayoutCardHeader = LayoutWon

function I:FillRoll()
    local r, roll = self.rl, self.rolls[1]
    if not r or not roll then return end
    if not roll.answerT and GetTime() >= (roll.upgradeCheckAt or 0) then RefreshRollUpgrade(roll) end
    local look = ns.CardLook and ns.CardLook(roll)
    local layout = look and look.layout or "classic"
    local info = not roll.prompt and ns.db.rollUpgrades ~= false and roll.upgradeInfo
    local extra = 0
    r.upgradeLabel:SetShown(info ~= nil and info ~= false)
    r.upgradeGain:SetShown(info ~= nil and info ~= false)
    r.upgradeFrom:SetShown(info ~= nil and info ~= false)
    if info then
        r.upgradeGain:SetText(info.text)
        r.upgradeGain:ClearAllPoints()
        r.upgradeGain:SetPoint("RIGHT", r.upgradeLabel, "RIGHT", (r.cardWidth or ns.WIDE) - 32 - (r.upgradeLabel:GetStringWidth() or 0), 0)
        r.upgradeFrom:SetText(info.replacementName and L["Replaces %s · %s"]:format(info.replacementName, info.source)
            or L["Checked by %s"]:format(info.source))
        local height = (r.upgradeFrom.GetStringHeight and r.upgradeFrom:GetStringHeight()) or 14
        extra = 26 + max(14, min(30, height))
    end
    r.bar:ClearAllPoints()
    r.bar:SetPoint("TOPLEFT", r.frame, "TOPLEFT", 14, -65 - extra)
    r.bar:SetPoint("TOPRIGHT", r.frame, "TOPRIGHT", -18, -65 - extra)
    r.names:ClearAllPoints()
    r.names:SetPoint("TOPLEFT", r.frame, "TOPLEFT", 14, -79 - extra)
    local col = roll.color or QualityColor(roll.quality)
    local tone = roll.tone or col
    local glyph = roll.glyph and true or false
    r.icon:SetShown(not glyph and layout ~= "centered")
    r.tile:SetShown(glyph and layout ~= "centered")
    r.glyph:SetShown(glyph and layout ~= "centered")
    if glyph then
        r.tile:SetVertexColor(tone[1], tone[2], tone[3], 0.18)
        r.glyph:SetTexture(MEDIA .. roll.glyph)
        r.glyph:SetVertexColor(tone[1], tone[2], tone[3], 1)
    else
        r.icon:SetTexture(roll.texture or QUESTION)
    end
    local name = roll.name or L["Item"]
    if roll.count and roll.count > 1 then name = L["%s x%d"]:format(name, roll.count) end
    r.title:SetText(name)

    r.title:SetTextColor(col[1], col[2], col[3])
    local more = #self.rolls - 1
    local cap = roll.cap or L["LOOT ROLL"]
    r.cap:SetText(more > 0 and L["%s  +%d MORE"]:format(cap, more) or cap)
    local cc = roll.capColor or C.muted
    if look and look.labelColor == "muted" then cc = C.muted
    elseif look and look.labelColor == "tone" then cc = tone
    elseif look and look.labelColor == "accent" then cc = ns.Accent() end
    LayoutWon(r, layout, look)
    r.upgradeGain:ClearAllPoints()
    r.upgradeGain:SetPoint("RIGHT", r.upgradeLabel, "RIGHT", (r.cardWidth or ns.WIDE) - 32 - (r.upgradeLabel:GetStringWidth() or 0), 0)
    r.names:SetWidth((r.cardWidth or ns.WIDE) - 32)
    r.cap:SetTextColor(cc[1], cc[2], cc[3])
    r.bar.fill:SetColor(tone[1], tone[2], tone[3], 1)

    -- the card grows by one line once there is something to list
    local line = roll.line or ChoiceLine(roll.log and roll.log.choices, false)
    if type(ns.Retail)=="table" and not roll.prompt then
        local gear=ns.Retail.GearDetails(roll.link)
        if gear then line=(line~="" and line.."\n" or "")..gear end
    end
    if look and look.line == false and not roll.fullWarning then line = "" end
    local roles = roll.roles
    if roles and #roles > 0 then line = "" end
    if r.names.SetMaxLines then r.names:SetMaxLines(roll.fullWarning and 0 or 4) end
    r.names:SetText(line)
    local h = ROLL_H + extra
    if line ~= "" then
        -- the card grows by the height of the list (one line is about 14 tall)
        local th = (r.names.GetStringHeight and r.names:GetStringHeight()) or 14
        h = ROLL_H + extra + max(14, min(74, th)) + (NAMES_H - 14)
    end
    for i, b in ipairs(r.roles) do
        local role = roles and roles[i]
        b:SetShown(role ~= nil)
        if role then
            local n = #roles
            local w = ((r.cardWidth or ns.WIDE) - 32 - 8 * (n - 1)) / n
            local rt = role.tone or tone
            b.index = i
            b:SetWidth(w)
            b.bg:SetWidth(w)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", r.frame, "TOPLEFT", 14 + (i - 1) * (w + 8), -78)
            b.text:SetText(role.label)
            if role.on then
                b.bg:SetColor(rt[1], rt[2], rt[3], 0.34)
                b.bg:SetTextColor(C.fg)
            else
                b.bg:SetColor(1, 1, 1, 0.07)
                b.bg:SetTextColor(C.muted)
            end
        end
    end
    if roles and #roles > 0 then h = ROLL_H + 36 end
    h = h + (roll.footer or 0)          -- room for a strip under the buttons (the voiceover's ticker)
    r.frame:SetHeight(h)
    ns.STATES.roll.h = h
    if self.state == "roll" then self.sh.t = h end

    if roll.answerT then return end       -- mid "selected" animation: leave the buttons alone
    local specs = Specs(roll)
    local gap, left, right = 8, 14, 18
    local w = ((r.cardWidth or ns.WIDE) - left - right - gap * (#specs - 1)) / max(1, #specs)
    for i, b in ipairs(r.buttons) do
        local spec = specs[i]
        b.spec = spec
        b:SetShown(spec ~= nil)
        if spec then
            b.role = Theme and Theme.ButtonRole(i, #specs) or "primary" -- BanzaiSland
            b:SetAlpha(spec.enabled and 1 or 0.35)
            b.text:SetText(ns.WithKey and ns.WithKey(spec.label, i, i == #specs) or spec.label)
            b.bg:SetRole(b.role, false, spec.muted)
            b.x0, b.w0 = left + (i - 1) * (w + gap), w
            b:SetWidth(w)
            b.bg:SetWidth(w)
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", r.frame, "BOTTOMLEFT", b.x0, 14 + (roll.footer or 0))
        end
    end
    if self.ArmSecure then self:ArmSecure() end
    self.awake = true
end

-- Layouts for this card (see Builder.lua): "classic" (icon on the left, text beside it), "icon"
-- (text centred beside the icon) and "centered" (text centred across the card, no icon). The label
-- on top can be left out, and the title can be large.
-- called by the island's queue for { kind = "won" } items
-- a bar that eases toward a new value instead of jumping; close enough counts as arrived
local function Ease(shown, target, dt)
    local d = target - shown
    if d > -0.002 and d < 0.002 then return target end
    return shown + d * min(1, dt * 9)
end
ns.BarEase = Ease

function I:BeginWon(item)
    local w = self.wn
    local look = ns.CardLook and ns.CardLook(item)
    local layout = look and look.layout
        or ((item.centered == "icon") and "icon") or (item.centered and "centered") or "classic"
    local col = item.color or C.fg
    local glyph = item.glyph and true or false
    local iconless = layout == "centered"
    w.icon:SetShown(not glyph and not iconless)
    w.tile:SetShown(glyph and not iconless)
    w.glyph:SetShown(glyph and not iconless)
    if glyph then
        local tone = item.tone or col
        w.tile:SetVertexColor(tone[1], tone[2], tone[3], 0.18)
        w.glyph:SetTexture(MEDIA .. item.glyph)
        w.glyph:SetVertexColor(tone[1], tone[2], tone[3], 1)
    else
        w.icon:SetTexture(item.icon or QUESTION)
    end
    if item.onClick == nil and ns.CardAction then
        local fn, hint = ns.CardAction(item)
        item.onClick, item.hint = fn or false, item.hint or hint
    end
    local cc = item.capColor or C.muted
    local lc = look and look.labelColor
    if lc == "muted" then cc = C.muted
    elseif lc == "tone" then cc = item.tone or item.capColor or C.muted
    elseif lc == "accent" then cc = ns.Accent() end
    w.cap:SetTextColor(cc[1], cc[2], cc[3])
    w.cap:SetText(item.cap or L["LOOT"])
    w.title:SetText(item.title or "")
    w.title:SetTextColor(col[1], col[2], col[3])
    local rc = item.resColor or C.fg
    w.res:SetTextColor(rc[1], rc[2], rc[3])
    local line = item.line or ChoiceLine(item.choices, true)
    if look and look.line == false then line = "" end
    item.lineText = line
    if not item.res or item.res == "" then
        item.res = (item.label and item.num) and (item.label .. " " .. item.num) or (item.res or "")
    end
    self:Record(item)
    w.names:Show()
    if w.names.SetMaxLines then w.names:SetMaxLines(item.retailDialogue and 0 or 5) end
    w.names:SetText(line)
    w.res:ClearAllPoints()
    if item.num then
        -- spin the number before it lands; the list of rolls fades in afterwards
        w.clip:Show()
        w.res:SetText(item.label or "")
        item.spin = { i = 0, p = 0, b = math.random(1, 100) }
        w.numA:SetText(math.random(1, 100))
        w.numB:SetText(item.spin.b)
        w.numA:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        w.numB:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        w.names:SetAlpha(0)
    else
        w.clip:Hide()
        w.res:SetText(item.res or "")
        w.names:SetAlpha(1)
    end
    LayoutWon(w, layout, look)
    local h = 68
    if line ~= "" then
        local th = (w.names.GetStringHeight and w.names:GetStringHeight()) or 14
        h = 64 + max(14, min(92, th)) + 14       -- up to five lines; the card grows to fit
    end
    if item.progress then
        -- the same timer bar as a prompt card: under the icon row, with the time on the right
        local barY = 65
        if item.barBelow and line ~= "" then
            -- an extension card with text: the bar sits under the text and the card grows by its height
            barY = h - 14 + 8
            h = h + 12
        else
            h = max(h, 83)
        end
        w.bar:ClearAllPoints()
        w.bar:SetPoint("TOPLEFT", w.frame, "TOPLEFT", 14, -barY)
        w.bar:SetWidth((w.cardWidth or ns.WIDE) - 32)        -- a fixed width, so the bar can measure itself at once
        local tone = item.barTone or item.tone or col
        w.bar.fill:SetColor(tone[1], tone[2], tone[3], 1)
        local shown = item.progress(item) or 0
        if item.barSmooth then
            -- a card that was updated keeps showing where its bar was, then eases from there
            shown = item.barShown or shown
            item.barShown = shown
        end
        w.bar:Set(shown, 0)
        w.bar:Show()
    else
        w.bar:Hide()
    end
    if item.button then
        h = h + 40
        local btn = w.btn
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT", w.frame, "TOPLEFT", 14, -(h - 14))
        btn:SetWidth((w.cardWidth or ns.WIDE) - 32)
        btn.bg:SetWidth((w.cardWidth or ns.WIDE) - 32)
        btn.text:SetText(ns.WithKey and ns.WithKey(item.button.label, 1, true) or item.button.label)
        btn.bg:SetRole("primary", false)
        btn:Show()
    else
        w.btn:Hide()
    end
    if ns.CatchUp then h = ns.CatchUp.Layout(w, item) or h end
    if type(ns.Retail)=="table" and ns.Retail.LayoutDialogue then h=ns.Retail.LayoutDialogue(w,item) or h end
    if type(ns.Retail)=="table" and ns.Retail.BossLoot then h=ns.Retail.BossLoot.Layout(w,item,look) or h end
    ns.STATES.won.h = h
    -- a clickable card takes clicks anywhere on it, not just on the icon and title
    if item.onClick then w.tip:SetSize((w.cardWidth or ns.WIDE) - 28, h - 20) else w.tip:SetSize(250, 40) end
    if item.flash then
        self.ring.body:SetColor(item.flash[1], item.flash[2], item.flash[3], 1)
        self.flashT = 0
    end
    item.steps = {}
    item.dur = item.hold or (((line ~= "") and 4.5 or 3.0) + (item.num and 1.5 or 0))
    self:SetState("won")
end

-- Push a card that can absorb repeats: looting the same thing again adds to the one on screen.
function I:PushCard(item)
    if ns.CatchUp and ns.CatchUp.ShouldQuiet(item) then self:Record(item) return end
    local function merge(into)
        into.count = (into.count or 0) + (item.count or 0)
        if into.format then into.res = into.format(into.count) end
        if item.line then into.line = item.line end
    end
    if item.key then
        local cur = self.current
        if cur and cur.kind == "won" and cur.key == item.key then
            merge(cur)
            self.wn.res:SetText(cur.res or "")
            LayoutWon(self.wn, self.wn.layout, self.wn.look)
            if cur.line then self.wn.names:SetText(cur.line) end
            cur.dur = max(cur.dur, cur.t + 1.6)
            return
        end
        for _, queued in ipairs(self.queue) do
            if queued.kind == "won" and queued.key == item.key then
                merge(queued)
                return
            end
        end
    end
    self:Push(item)
end

-- Push a card that rewrites the one already showing (or waiting) with the same key, so a
-- stream of updates such as quest progress or zone changes never piles up.
function I:PushReplace(item)
    if ns.Extensions and not ns.Extensions.Valid(item) then return end
    if ns.CatchUp and ns.CatchUp.ShouldQuiet(item) then self:Record(item) return end
    item.replace = true
    local cur = self.current
    if cur and cur.kind == "won" and cur.key == item.key then
        for _, field in ipairs({ "cap", "capColor", "title", "color", "res", "resColor", "line", "icon", "glyph",
                                 "extensionOwner", "extensionKey", "extensionName", "tone", "link", "hold", "flash", "onClick", "builderType", "online", "bossLootRows", "catchUpDigest", "retailDialogue", "progress", "barTone", "barBelow", "barSmooth", "live", "button" }) do
            cur[field] = item[field]
        end
        local t = cur.t
        self:BeginWon(cur)
        if not cur.exact then cur.dur = cur.dur * ns.CardTime(cur) end
        cur.t = cur.retailDialogue and 0 or min(t, 0.6)           -- restart the hold without replaying the open animation
        return
    end
    for i, queued in ipairs(self.queue) do
        if queued.kind == "won" and queued.key == item.key then
            self.queue[i] = item
            return
        end
    end
    self:Push(item)
end

-- runs every frame while the winner card is up
function I:UpdateWon(dt)
    local item = self.current
    if not item or item.kind ~= "won" then return end
    local w, sp = self.wn, item.spin
    -- a card whose number keeps changing while it is up (a pull countdown)
    if item.live then
        local text = item.live(item)
        if text and text ~= item.liveText then
            item.liveText = text
            w.res:SetText(text)
            LayoutWon(w, w.layout, w.look)
            if item.retailDialogue and type(ns.Retail)=="table" and ns.Retail.LayoutDialogue then
                local height=ns.Retail.LayoutDialogue(w,item)
                if height then ns.STATES.won.h=height;if self.sh then self.sh.t=height end end
            end
        end
    end
    if item.progress then
        local value = max(0, min(1, item.progress(item) or 0))
        if item.barSmooth then
            value = Ease(item.barShown or value, value, dt)
            item.barShown = value
        end
        w.bar:Set(value, 0)
    end
    if sp then
        sp.p = sp.p + dt / (0.05 + 0.012 * sp.i)      -- each tick is a little slower than the last
        if sp.p >= 1 then
            sp.i, sp.p = sp.i + 1, 0
            w.numA:SetText(sp.b)
            if sp.i >= SPIN_TICKS then
                -- landed
                item.spin, item.landT = nil, 0
                local col = item.color or C.fg
                self.ring.body:SetColor(col[1], col[2], col[3], 1)
                self.flashT = 0
            else
                sp.b = (sp.i == SPIN_TICKS - 1) and item.num or math.random(1, 100)
                w.numB:SetText(sp.b)
            end
        end
        local y = (item.spin and sp.p or 0) * NUM_H
        w.numA:SetPoint("RIGHT", w.clip, "RIGHT", 0, y)
        w.numB:SetPoint("RIGHT", w.clip, "RIGHT", 0, y - NUM_H)
    elseif item.landT then
        item.landT = item.landT + dt
        local k = max(0, 1 - item.landT / 0.5)
        local col = item.color or C.fg
        w.numA:SetTextColor(C.fg[1] + (col[1] - C.fg[1]) * k, C.fg[2] + (col[2] - C.fg[2]) * k, C.fg[3] + (col[3] - C.fg[3]) * k)
        w.names:SetAlpha(min(1, item.landT / 0.3))
        if item.landT > 0.6 then
            item.landT = nil
            w.names:SetAlpha(1)
        end
    end
end

-- milliseconds left, or nil for a prompt with no time limit
local function TimeLeft(roll)
    if roll.fake or roll.prompt then
        return roll.expires and (roll.expires - GetTime()) * 1000 or nil
    end
    return (GetLootRollTimeLeft and GetLootRollTimeLeft(roll.id)) or 0
end

function I:UpdateRoll(dt)
    local now = GetTime()
    for i = #self.rolls, 1, -1 do
        local roll = self.rolls[i]
        local left = TimeLeft(roll)
        if left and now - roll.started > 1 and left <= 0 then
            self:RemoveRoll(roll.id)
        end
    end
    local roll, r = self.rolls[1], self.rl
    if not roll or self.state ~= "roll" then return end
    if not roll.prompt and not roll.answerT and now >= (roll.upgradeCheckAt or 0) then
        if RefreshRollUpgrade(roll) then self:FillRoll() end
    end

    -- after you pick: the chosen button stretches across the card and the others fade
    if roll.answerT then
        roll.answerT = roll.answerT + (dt or 0)
        local f = min(1, roll.answerT / 0.4)
        f = 1 - (1 - f) * (1 - f) * (1 - f)
        local full = (r.cardWidth or ns.WIDE) - 32
        local col = roll.tone or roll.color or QualityColor(roll.quality)
        for _, b in ipairs(r.buttons) do
            local spec = b.spec
            if spec and spec == roll.answerSpec then
                local w = b.w0 + (full - b.w0) * f
                b:SetWidth(w)
                b.bg:SetWidth(w)
                b:SetPoint("BOTTOMLEFT", r.frame, "BOTTOMLEFT", b.x0 + (14 - b.x0) * f, 14 + (roll.footer or 0))
                if spec.muted then
                    b.bg:SetColor(1, 1, 1, 0.10 + 0.06 * f)
                else
                    b.bg:SetColor(1 + (col[1] - 1) * f, 1 + (col[2] - 1) * f, 1 + (col[3] - 1) * f, 0.10 + 0.25 * f)
                end
            elseif spec then
                b:SetAlpha(max(0, (spec.enabled and 1 or 0.35) * (1 - f * 2)))
            end
        end
        if roll.answerT >= 0.95 then
            self:FinishAnswer(roll)
            return
        end
    end
    local left = TimeLeft(roll)
    if left then
        left = max(0, left)
        local text = L["%ds"]:format(ceil(left / 1000))
        if r.time:GetText() ~= text then
            r.time:SetText(text)
            LayoutWon(r, r.layout or "classic", r.look)
        end
        r.bar:Show()
        r.bar:Set(roll.total > 0 and min(1, left / roll.total) or 0, 0)
    else
        r.time:SetText("")
        LayoutWon(r, r.layout or "classic", r.look)
        r.bar:Hide()                      -- a card with no time limit has no timer bar
    end
end

-- A card that waits for an answer, like a loot roll: a ready check, an invite, a summon.
-- p = { id, glyph, tone, cap, name, line, seconds, buttons = { { label, fn, muted, done } } }
function I:AddPrompt(p)
    if not self.built then return end
    p.prompt = true
    p.seconds = p.seconds or 60
    p.total = p.seconds * 1000
    p.expires = (not p.noTimer) and (GetTime() + p.seconds) or nil   -- noTimer: no countdown, stays until dealt with
    p.color = p.color or C.fg
    p.capColor = p.capColor or p.tone
    p.log = { choices = {}, byWho = {} }
    for _, b in ipairs(p.buttons or {}) do
        if b.enabled == nil then b.enabled = true end
    end
    for i, roll in ipairs(self.rolls) do          -- a newer prompt with the same id replaces the old one
        if roll.id == p.id then
            p.started = GetTime()
            self.rolls[i] = p
            if i == 1 and self.state == "roll" then self:FillRoll() end
            return
        end
    end
    self:AddRoll(p)
    if p.sound and ns.PlayCardSound then ns.PlayCardSound(p.sound, p, "prompts") end
    if ns.Rumble then ns.Rumble(p.id) end
end

function I:UpdatePrompt(id, line)
    for i, roll in ipairs(self.rolls) do
        if roll.id == id then
            roll.line = line
            if i == 1 and self.state == "roll" then self:FillRoll() end
            return true
        end
    end
end

function I:AddRoll(roll)
    if not self.built then return end
    for _, existing in ipairs(self.rolls) do
        if existing.id == roll.id then return end
    end
    roll.started = GetTime()
    roll.log = roll.log or NewEntry(roll.name)
    -- While you are dead the death card (release, graveyard, corpse) can wait: anything else that
    -- needs an answer, like a resurrection or an invite, goes in front of it. A voiceover waits for
    -- everything, the death cards included (getting back to your body matters more than a story).
    local LINGER = { death = true, ghost = true, corpse = true, spoken = true }
    local top = self.rolls[1]
    if top and LINGER[top.id] and (not LINGER[roll.id] or (top.id == "spoken" and roll.id ~= "spoken")) then
        roll.front = true
    end
    if roll.front then
        table.insert(self.rolls, 1, roll)       -- a question about the card on screen goes first
    else
        self.rolls[#self.rolls + 1] = roll
    end
    self.current = nil            -- a roll needs an answer: it takes over from any pop up
    if self.state ~= "roll" then
        self:FillRoll()
        self:SetState("roll")
    else
        self:FillRoll()
    end
end

function I:RemoveRoll(id, force)
    for i, roll in ipairs(self.rolls) do
        if roll.id == id then
            if roll.answerT and not force then return end     -- let the "selected" animation finish
            table.remove(self.rolls, i)
            if self.DisarmSecure then self:DisarmSecure() end
            if roll.onRemoved then pcall(roll.onRemoved, roll) end
            break
        end
    end
    if #self.rolls > 0 then
        if self.state == "roll" then self:FillRoll() end
    elseif self.state == "roll" then
        self:Pump()
    end
end

local function PushWon(e, winner, isSelf, rollType, num, name, icon, quality, link)
    if e then Record(e, winner, rollType, num) end
    local c = e and e.byWho[winner]
    rollType = rollType or (c and c.type)
    num = num or (c and c.num)
    ns.recentWon[name or ""] = GetTime()
    local res, label = "", nil
    if rollType and rollType ~= PASS then
        label = TYPE_LABEL[rollType]
        res = label .. (num and (" " .. num) or "")
    end
    I:Push({ group = "loot",
        kind = "won", builderType = "rollResults", urgent = true,        -- a roll result shows even in combat, like the roll itself
        cap = isSelf and L["YOU WON"] or L["WON BY %s"]:format(Short(winner):upper()),
        title = name, icon = icon, color = QualityColor(quality), res = res, label = label,
        num = label and num or nil, link = link, choices = e and e.choices,
    })
end

function I:AnswerRoll(spec)
    local roll = self.rolls[1]
    if not roll or roll.answerT or not spec then return end
    if roll.prompt then
        if spec.fn then pcall(spec.fn) end
        if spec.keep then return end       -- a control (Pause, Stop): the card stays and updates itself
    elseif not roll.fake then
        RollOnLoot(roll.id, spec.type)
        -- Bind on pickup items ask for confirmation first; the card stays until the game closes the roll.
        if roll.bop and spec.type ~= PASS then return end
    end
    roll.answer, roll.answerSpec, roll.answerT = spec.type, spec, 0
    for _, b in ipairs(self.rl.buttons) do
        if b.spec == spec then
            b.text:SetText(spec.done or (spec.type == PASS and L["Passed"]) or (spec.type and L["%s selected"]:format(spec.label)) or spec.label)
        end
    end
    self.awake = true
end

function I:FinishAnswer(roll)
    self:RemoveRoll(roll.id, true)
    if roll.onAnswered then pcall(roll.onAnswered, roll.answerSpec) end
    if roll.fake and not roll.prompt then
        local me = UnitName("player") or L["You"]
        local e, rollType = roll.log, roll.answer
        Record(e, me, rollType, rollType ~= PASS and 94 or nil)
        Record(e, "Thrall", NEED, 71, Hex(0.0, 0.44, 0.87))
        Record(e, "Jaina", GREED, 55, Hex(0.25, 0.78, 0.92))
        Record(e, "Sylvanas", PASS, nil, Hex(0.67, 0.83, 0.45))
        local selfWon = rollType == NEED
        PushWon(e, selfWon and me or "Thrall", selfWon, nil, nil, roll.name, roll.texture, roll.quality, roll.link)
    end
end

function I:DemoRoll()
    if not self.built then return end
    self.demoRollId = (self.demoRollId or 0) - 1
    local e = NewEntry("Shadowfang")
    local roll = {
        id = self.demoRollId, fake = true, total = 20000, expires = GetTime() + 20, log = e,
        link = "item:1482", name = "Shadowfang", texture = "Interface\\Icons\\INV_Sword_36", quality = 4, count = 1,
        canNeed = true, canGreed = true, canDisenchant = false,
    }
    self:AddRoll(roll)
    local function later(delay, who, rollType, hex)
        C_Timer.After(delay, function()
            if I.rolls[1] == roll then Record(e, who, rollType, nil, hex) end
        end)
    end
    later(1.5, "Thrall", NEED, Hex(0.0, 0.44, 0.87))
    later(3.0, "Jaina", GREED, Hex(0.25, 0.78, 0.92))
    later(4.5, "Sylvanas", PASS, Hex(0.67, 0.83, 0.45))
end

-- ---------------------------------------------------------------- events

-- Stop the default roll windows while the island is handling rolls.
-- The game's own roll windows (GroupLootFrame1, 2, ...) are hidden as they open while the island
-- handles rolls. Hiding one does not pass on the item; the roll stays open for the island card.
local hookedRollFrames = {}

local function HookRollFrame(f)
    if type(f) ~= "table" or hookedRollFrames[f] or not f.HookScript then return end
    hookedRollFrames[f] = true
    f:HookScript("OnShow", function(self)
        if ns.db and ns.db.lootRolls then
            C_Timer.After(0, function() if ns.db.lootRolls and self:IsShown() then self:Hide() end end)
        end
    end)
    if f:IsShown() and ns.db.lootRolls then f:Hide() end
end

local function HookRollFrames()
    for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) + 4 do HookRollFrame(_G["GroupLootFrame" .. i]) end
end

-- The holder the roll windows sit in. With the windows hidden it can stay on screen, empty and
-- stretched, catching clicks in the middle of the screen. It is only a holder: the roll windows
-- take their own clicks, so the holder itself never needs to.
local function ContainerClickThrough()
    local c = _G.GroupLootContainer
    if type(c) ~= "table" or not c.EnableMouse then return end
    pcall(c.EnableMouse, c, false)
    if c.SetMouseClickEnabled then pcall(c.SetMouseClickEnabled, c, false) end
    if c.SetMouseMotionEnabled then pcall(c.SetMouseMotionEnabled, c, false) end
    if not hookedRollFrames.container and hooksecurefunc then
        hookedRollFrames.container = true
        hooksecurefunc(c, "EnableMouse", function(self, on) if on then pcall(self.EnableMouse, self, false) end end)
        if c.HookScript then c:HookScript("OnShow", ContainerClickThrough) end
    end
end

function ns.ApplyLootRolls()
    if not UIParent or not UIParent.UnregisterEvent then return end
    ContainerClickThrough()
    if ns.db.lootRolls then
        UIParent:UnregisterEvent("START_LOOT_ROLL")
    else
        UIParent:RegisterEvent("START_LOOT_ROLL")
    end
    HookRollFrames()
    -- newer clients make extra roll windows on demand: catch those as they are made
    if not hookedRollFrames.opener and hooksecurefunc then
        hookedRollFrames.opener = true
        if type(_G.GroupLootFrame_OpenNewFrame) == "function" then hooksecurefunc("GroupLootFrame_OpenNewFrame", HookRollFrames) end
        if type(_G.GroupLootContainer_AddFrame) == "function" then
            hooksecurefunc("GroupLootContainer_AddFrame", function(_, frame) HookRollFrame(frame) HookRollFrames() end)
        end
    end
end

local function ItemFromLink(link)
    local name = link:match("%[(.-)%]")
    local icon, quality, level, equipLoc
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if getInfo then
        local ok, n, _, q, lvl, _, _, _, _, loc, tex = pcall(getInfo, link)
        if ok and n then quality, level, equipLoc, icon = q, lvl, loc, tex end
    end
    if not icon then
        local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        if instant then
            local ok, _, _, _, _, tex = pcall(instant, link)
            if ok then icon = tex end
        end
    end
    return name or L["Item"], icon, quality, level, equipLoc
end

-- Turn a chat format such as "%s has selected Need for: %s" into a Lua pattern. Returns the
-- pattern plus, for each capture, which argument it is and whether it is text or a number
-- (some formats number their arguments, and some clients put a loot-history id in front).
local function Compile(fmt, open)
    if type(fmt) ~= "string" then return nil end
    local order, kinds = {}, {}
    local p = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%(%d)%%%$([sd])", function(n, t)
        order[#order + 1] = tonumber(n)
        kinds[#kinds + 1] = t
        return t == "d" and "(%d+)" or "(.-)"
    end)
    if #order == 0 then
        p = p:gsub("%%([sd])", function(t)
            order[#order + 1] = #order + 1
            kinds[#kinds + 1] = t
            return t == "d" and "(%d+)" or "(.-)"
        end)
    end
    return "^" .. p .. (open and "" or "$"), order, kinds
end
ns.Compile = Compile

-- Chat formats in the order they must be tried. `texts` names the text arguments in the order
-- the game passes them; `num` says the last number in the message is the roll (or the stack size).
-- Numbers are otherwise ignored, which skips the loot-history id newer clients put first.
local FORMATS = {
    { "LOOT_ROLL_YOU_WON_NO_SPAM_NEED", "won", NEED, { "item" }, true, true },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_GREED", "won", GREED, { "item" }, true, true },
    { "LOOT_ROLL_YOU_WON_NO_SPAM_DE", "won", DISENCHANT, { "item" }, true, true },
    { "LOOT_ROLL_WON_NO_SPAM_NEED", "won", NEED, { "who", "item" }, false, true },
    { "LOOT_ROLL_WON_NO_SPAM_GREED", "won", GREED, { "who", "item" }, false, true },
    { "LOOT_ROLL_WON_NO_SPAM_DE", "won", DISENCHANT, { "who", "item" }, false, true },
    { "LOOT_ROLL_YOU_WON", "won", nil, { "item" }, true },
    { "LOOT_ROLL_PASSED_AUTO", "choice", PASS, { "who", "item" } },
    { "LOOT_ROLL_PASSED_AUTO_FEMALE", "choice", PASS, { "who", "item" } },
    { "LOOT_ROLL_NEED_SELF", "choice", NEED, { "item" }, true },
    { "LOOT_ROLL_GREED_SELF", "choice", GREED, { "item" }, true },
    { "LOOT_ROLL_DISENCHANT_SELF", "choice", DISENCHANT, { "item" }, true },
    { "LOOT_ROLL_PASSED_SELF", "choice", PASS, { "item" }, true },
    { "LOOT_ROLL_NEED", "choice", NEED, { "who", "item" } },
    { "LOOT_ROLL_GREED", "choice", GREED, { "who", "item" } },
    { "LOOT_ROLL_DISENCHANT", "choice", DISENCHANT, { "who", "item" } },
    { "LOOT_ROLL_PASSED", "choice", PASS, { "who", "item" } },
    { "LOOT_ROLL_ROLLED_NEED_ROLE_BONUS", "rolled", NEED, { "item", "who" }, false, true },
    { "LOOT_ROLL_ROLLED_NEED", "rolled", NEED, { "item", "who" }, false, true },
    { "LOOT_ROLL_ROLLED_GREED", "rolled", GREED, { "item", "who" }, false, true },
    { "LOOT_ROLL_ROLLED_DE", "rolled", DISENCHANT, { "item", "who" }, false, true },
    { "LOOT_ROLL_WON", "won", nil, { "who", "item" } },
    -- things you received yourself (handled in Toasts.lua)
    { "LOOT_ITEM_SELF_MULTIPLE", "loot", nil, { "item" }, true, true },
    { "LOOT_ITEM_SELF", "loot", nil, { "item" }, true },
    { "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "pushed", nil, { "item" }, true, true },
    { "LOOT_ITEM_PUSHED_SELF", "pushed", nil, { "item" }, true },
    { "LOOT_ITEM_CREATED_SELF_MULTIPLE", "created", nil, { "item" }, true, true },
    { "LOOT_ITEM_CREATED_SELF", "created", nil, { "item" }, true },
}
local compiled = {}

local function CompileFormats()
    for _, def in ipairs(FORMATS) do
        -- drop the loot-history link some clients put in front; the message loses it too (below),
        -- so matching does not depend on that prefix being exactly what is expected
        local fmt = _G[def[1]]
        if type(fmt) == "string" then fmt = fmt:gsub("^|HlootHistory:%%[%d%$]*d|h.-|h:?%s*", "") end
        local pattern, order, kinds = Compile(fmt)
        if pattern then
            pattern = pattern:gsub("%$$", "%%s*$")       -- allow trailing spaces
            compiled[#compiled + 1] = { pattern = pattern, order = order, kinds = kinds, kind = def[2], type = def[3],
                                        texts = def[4], isSelf = def[5], wantNum = def[6] }
        end
    end
end

local function Parse(msg)
    for _, f in ipairs(compiled) do
        local caps = { msg:match(f.pattern) }
        if caps[1] then
            -- put the captures back in argument order, then split them into texts and numbers
            local args = {}
            for i, value in ipairs(caps) do
                args[#args + 1] = { at = f.order[i] or i, value = value, kind = f.kinds[i] }
            end
            table.sort(args, function(a, b) return a.at < b.at end)
            local out = { kind = f.kind, type = f.type, isSelf = f.isSelf }
            local t = 0
            for _, a in ipairs(args) do
                if a.kind == "d" then
                    if f.wantNum then out.num = a.value end      -- the last number wins
                else
                    t = t + 1
                    local role = f.texts[t]
                    if role then out[role] = a.value end
                end
            end
            return out
        end
    end
end

local function OnLootMessage(msg)
    if not ns.Readable(msg) then return end      -- the game hides some chat text from addons in combat
    if type(msg) ~= "string" then return end
    local link = msg:match("(|c.-|Hitem:.-|h%[.-%]|h|r)") or msg:match("(|Hitem:.-|h%[.-%]|h)")
    if not link then return end
    local m = Parse((msg:gsub("^|HlootHistory:%d+|h.-|h:?%s*", "")))
    if not m then return end
    local name, icon, quality, level, equipLoc = ItemFromLink(link)
    if m.kind == "loot" or m.kind == "pushed" or m.kind == "created" then
        if ns.OnItemLoot then ns.OnItemLoot(m.kind, link, name, icon, quality, level, equipLoc, tonumber(m.num) or 1) end
        return
    end
    local who = m.isSelf and (UnitName("player") or L["You"]) or m.who
    if who then
        -- a name may arrive colored or as a clickable player link: keep just the name
        who = who:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn.-:", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("^%[(.-)%]$", "%1")
    end
    if not who or who == "" or who:find("|", 1, true) then return end
    local num = tonumber(m.num)

    if m.kind == "choice" then
        Record(FindEntry(name, function(e) return not e.byWho[who] end), who, m.type)
    elseif m.kind == "rolled" then
        local e = FindEntry(name, function(e) return not (e.byWho[who] and e.byWho[who].num) end)
        Record(e, who, m.type, num)
    elseif m.kind == "won" then
        local e
        for i, entry in ipairs(log) do
            if entry.name == name then
                e = table.remove(log, i)
                break
            end
        end
        if ns.db.showRollWinners then
            PushWon(e, who, m.isSelf, m.type, num, name, icon, quality, link)
        end
    end
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, a, b)
    if event == "START_LOOT_ROLL" then
        if not ns.db.lootRolls or not GetLootRollItemInfo then return end
        C_Timer.After(0.05, HookRollFrames)
        local texture, name, count, quality, bop, canNeed, canGreed, canDisenchant = GetLootRollItemInfo(a)
        if not name then return end
        I:AddRoll({
            id = a, total = (type(b) == "number" and b > 0) and b or 60000,
            texture = texture, name = name, count = count, quality = quality, bop = bop,
            canNeed = canNeed ~= false, canGreed = canGreed ~= false, canDisenchant = canDisenchant == true,
        })
        -- Optional notification sound; new rolls stay silent unless configured.
        ns.PlayCardSound(nil, { soundKey = "lootRoll" }, "prompts")
    elseif event == "CANCEL_LOOT_ROLL" then
        I:RemoveRoll(a)
    elseif event == "CHAT_MSG_LOOT" then
        OnLootMessage(a)
    elseif event == "PLAYER_LOGIN" then
        CompileFormats()
    end
end)
for _, event in ipairs({ "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CHAT_MSG_LOOT", "PLAYER_LOGIN" }) do
    pcall(ev.RegisterEvent, ev, event)
end
