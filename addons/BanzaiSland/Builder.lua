-- Island: the card builder. Each kind of card can have its own layout: the icon on the left with the
-- text beside it, the text centred beside the icon, or centred with no icon; with or without its
-- small label on top, in a choice of colours, a normal or large title, and with or without its
-- second line. Buttons, timer bars and rolling numbers stay available in every layout.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local C = ns.C
local B = {}
ns.Builder = B

B.TYPES = {
    { key = "zone",     name = L["Zone changes"] },
    { key = "loot",     name = L["Loot, money, reputation"] },
    { key = "progress", name = L["Quests and skills"] },
    { key = "whisper",  name = L["Whispers"] },
    { key = "social",   name = L["Friends and group"] },
    { key = "rare",     name = L["Rares"] },
    { key = "alerts",   name = L["Alerts and timers"] },
    { key = "legacy", name = L["Legacy point reminders"] },
    { key = "legacyChallenges", name = L["Legacy challenges"] },
    { key = "legacyProgress", name = L["Legacy progress"] },
    { key = "talents", name = L["Talent reminders"] },
    { key = "flights", name = L["Flight paths"] },
    { key = "timers", name = L["Pull and break timers"] },
    { key = "rollResults", name = L["Loot roll results"] },
    { key = "rolls", name = L["Loot rolls"] },
    { key = "prompts", name = L["Invites and prompts"] },
    { key = "instances", name = L["Dungeon summaries"] },
    { key = "vendor", name = L["Vendor summaries"] },
    { key = "catchUp", name = L["AFK catch-up digest"] },
}

local retailKinds = {
    {key="retailRenown",name=L["Renown and reputation"]},
    {key="retailVault",name=L["Great Vault"]},
    {key="retailMythic",name=L["Mythic+ summaries"]},
    {key="retailDelve",name=L["Delve summaries"]},
    {key="retailProfession",name=L["Retail professions"]},
    {key="retailCollection",name=L["Collection unlocks"]},
    {key="retailHousing",name=L["Housing decor"]},
    {key="retailDialogue",name=L["Talking Head dialogue"]},
    {key="retailBossLoot",name=L["Boss loot summaries"]},
}
for _,entry in ipairs(retailKinds) do B.TYPES[#B.TYPES+1]=entry end
local clientKinds = { legacy = "legacy", legacyChallenges = "legacy", legacyProgress = "legacy" }
for _,entry in ipairs(retailKinds) do clientKinds[entry.key]="retail" end
function B.Available(kind)
    return not clientKinds[kind] or ns.ClientFeature(clientKinds[kind])
end
for index = #B.TYPES, 1, -1 do
    if not B.Available(B.TYPES[index].key) then table.remove(B.TYPES, index) end
end

local DEFAULT = { layout = "classic", label = true, labelColor = "auto", title = "normal", line = true }

-- which kind of card this is
function B.Type(item)
    if item.builderType then return item.builderType end
    if item.prompt then return "prompts" end
    if item.id and item.total then return "rolls" end
    if item.num then return "rollResults" end
    local key = type(item.key) == "string" and item.key or ""
    if key == "zone" then return "zone" end
    if key == "instance" then return "instances" end
    if key == "vendor" then return "vendor" end
    if key == "pull" or key == "break" or item.progress then return "timers" end
    if key:find("^whisper") then return "whisper" end
    if key == "questprogress" or key == "skill" then return "progress" end
    if key:find("^rs:") or (type(item.cap) == "string" and (item.cap:find("RARE") or item.cap:find(L["RARE SPOTTED"], 1, true))) then return "rare" end
    local g = ns.CardGroup and ns.CardGroup(item) or "alerts"
    if g == "loot" then return "loot" end
    if g == "social" then return "social" end
    if g == "world" then return "progress" end
    if g == "alerts" then return "alerts" end
    return nil
end

local function Store()
    local db = ns.db
    if type(db.cardBuilder) ~= "table" then db.cardBuilder = {} end
    return db.cardBuilder
end

-- the look of a kind of card: its own choices over the defaults. The zone card's layout is the
-- same setting as "Zone card style".
function B.Get(t)
    local s = Store()[t] or {}
    local look = {}
    for k, v in pairs(DEFAULT) do
        if s[k] == nil then look[k] = v else look[k] = s[k] end
    end
    if t == "zone" then look.layout = ns.db.zoneStyle or "classic" end
    return look
end

function B.Set(t, k, v)
    if t == "zone" and k == "layout" then ns.db.zoneStyle = v return end
    local all = Store()
    all[t] = all[t] or {}
    all[t][k] = v
end

function B.Reset(t)
    Store()[t] = nil
    if t == "zone" then ns.db.zoneStyle = "classic" end
end

-- the look to use for a card, or nil to keep the usual layout
function ns.CardLook(item)
    if item.noBuilder or item.id == "spoken" then return nil end
    local t = B.Type(item)
    if not t then return nil end
    return B.Get(t), t
end

-- ---------------------------------------------------------------- preview

local GREEN, PINK, SILVER, RED = { 0.36, 0.85, 0.45 }, { 1.00, 0.55, 0.95 }, { 0.78, 0.84, 0.96 }, { 0.95, 0.38, 0.38 }
local BLUE, ORANGE = { 0.40, 0.72, 1.00 }, { 0.98, 0.66, 0.28 }
local function ClassColor(class)
    -- BanzaiSland 0.3.0: the theme's class screen colour (Priest marked, so the parchment ink knows it)
    local c = ns.Theme and ns.Theme.ClassScreen and ns.Theme.ClassScreen(class)
    return c or C.fg
end
local function Muted(s) return ns.Hex(C.muted[1], C.muted[2], C.muted[3]) .. s .. "|r" end
local function Tint(c, s) return ns.Hex(c[1], c[2], c[3]) .. s .. "|r" end

local SAMPLES = {
    catchUp = function() local color = ns.db.restColor or ns.defaults.restColor return {glyph="Bell", tone=color, cap=L["WHILE YOU WERE AWAY"], capColor=color,
        title=L["%d updates waiting"]:format(5), res=L["%dm away"]:format(12), resColor=color,
        line=Muted(ns.ClientFeature("legacy") and L["Whispers, auctions, cooldowns and legacy challenges."] or L["Whispers, auctions and cooldowns."])} end,

    legacy = function() return { glyph="Plus", tone=C.gold, cap=L["LEGACY"], capColor=C.gold,
        title=L["%d unspent legacy points"]:format(6), line=Muted(L["Choose your next legacy upgrade."]),
        button={label=L["Spend points"], fn=function() return true end} } end,
    legacyChallenges = function() return { glyph="Check", tone=C.gold, cap=L["LEGACY CHALLENGE COMPLETE"], capColor=C.gold,
        title=L["A legacy challenge"], res=L["%d legacy points"]:format(2), resColor=C.gold,
        line=Muted(L["Challenge completed."]), button={label=L["View challenge"],fn=function() return true end} } end,
    legacyProgress = function() return { glyph="Check", tone=C.gold, cap=L["LEGACY PROGRESS"], capColor=C.gold,
        title=L["A legacy challenge"], res="3 / 10", resColor=C.gold,
        line=Muted(L["An objective completed."]), button={label=L["View challenge"],fn=function() return true end} } end,
    talents = function() return { glyph="Plus", tone=C.gold, cap=L["TALENTS"], capColor=C.gold,
        title=L["%d unspent talent point"]:format(1), line=Muted(L["Choose your next talent."]),
        button={label=L["Spend point"],fn=function() return true end} } end,
    flights = function() return { glyph="Plane", tone=BLUE, cap=L["FLYING TO"], capColor=BLUE,
        title="Booty Bay", res="~2:30", line=Muted(L["About this long; timing it for next time"]),
        button={label=L["Request stop"],fn=function() return true end} } end,
    timers = function() return { glyph="Clock", tone=RED, cap=L["PULL TIMER"], capColor=RED,
        title=L["Get ready"], res=L["%ds"]:format(10), resColor=C.muted, progress=function() return .6 end,
        button={label=L["Cancel"],fn=function() return true end} } end,
    rollResults = function() return { icon="Interface\\Icons\\INV_Sword_36", cap=L["YOU WON"], title="Shadowfang", color=ns.QualityColor(3),
        num=71, label=L["Need"], res=L["Need"].." 71", line=Muted("Thrall") } end,
    rolls = function() return { cap=L["LOOT ROLL"], name="Shadowfang", quality=3, color=ns.QualityColor(3), texture="Interface\\Icons\\INV_Sword_36",
        seconds=15, buttons={{label=L["Need"],fn=function() return true end},{label=L["Greed"],fn=function() return true end},{label=L["Pass"],fn=function() return true end}} } end,
    prompts = function() return { glyph="Person", tone=GREEN, cap=L["PARTY INVITE"], capColor=GREEN, name="Thrall", seconds=15,
        buttons={{label=L["Accept"],fn=function() return true end},{label=L["Decline"],fn=function() return true end}} } end,
    instances = function() return { glyph="Door", tone=BLUE, cap=L["LEFT INSTANCE"], capColor=BLUE, title="The Deadmines", res="24:30",
        line=Muted(L["%s XP"]:format("12,500")) } end,
    vendor = function() return { glyph="Coin", tone=C.gold, cap=L["VENDOR"], capColor=C.gold, title=L["Repaired -%s"]:format("12s 50c"), res="" } end,
    zone = function() return { glyph = "Compass", tone = GREEN, cap = L["ENTERING"], title = "Elwynn Forest",
        line = Muted("Goldshire") .. "   " .. Tint(GREEN, L["%s Territory"]:format(FACTION_ALLIANCE or "Alliance")), capColor = ns.db.zoneStyle ~= "classic" and GREEN or nil } end,
    loot = function() return { icon = "Interface\\Icons\\INV_Misc_LeatherScrap_07", cap = L["LOOT"], title = "Heavy Leather",
        color = ns.QualityColor(1), res = L["x%d"]:format(3) } end,
    progress = function() return { glyph = "Check", tone = C.quest, cap = L["QUEST"], capColor = C.quest,
        title = L["Kobold Vermin slain"], res = "3 / 8" } end,
    whisper = function() return { glyph = "Chat", tone = PINK, cap = L["WHISPER"], capColor = PINK, title = "Thrall", color=ClassColor("SHAMAN"),
        line = Muted(L["Want to run Deadmines?"]) } end,
    social = function() return { glyph = "Person", tone = GREEN, cap = L["FRIEND %s"]:format(L["ONLINE"]), capColor = GREEN, title = "Jaina",
        line = Muted(L["Level %d %s"]:format(60, LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE.MAGE or "Mage") .. ", Stormwind") } end,
    rare = function() return { glyph = "Star", tone = SILVER, cap = L["RARE SPOTTED"], capColor = SILVER,
        title = "Mosh'Ogg Butcher", line = Muted("Stranglethorn Vale") } end,
    alerts = function() return { glyph = "Shield", tone = ORANGE, cap = L["LOW DURABILITY"], capColor = ORANGE, title = "Ironfoe",
        res = "18%", resColor = ORANGE } end,
}

-- Retail samples use the same factories as their event cards.
for _,entry in ipairs(retailKinds) do
    local kind=entry.key
    SAMPLES[kind]=function() return type(ns.Retail)=="table" and ns.Retail.Sample(kind) or nil end
end

-- The settings preview uses the same header layout as real cards, without game actions.
function B.Sample(t)
    if not B.Available(t) then return end
    local make = SAMPLES[t]
    return make and make() or nil
end

function B.CreatePreview(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetWidth(ns.WIDE)
    local w = { frame = f }
    f.body = ns.CreateBody(f, "BACKGROUND", 0)
    f.body:SetStyle(ns.db.lookStyle, 1, true)
    f.body:SetRadius(27)
    w.icon = ns.RoundIcon(f, 40)
    w.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -14)
    w.tile = ns.Image(f, "Tile", "ARTWORK", 0)
    w.tile:SetSize(40, 40)
    w.tile:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -14)
    w.glyph = ns.Image(f, "Check", "ARTWORK", 1)
    w.glyph:SetSize(20, 20)
    w.glyph:SetPoint("CENTER", w.tile, "CENTER", 0, 0)
    w.cap = ns.Text(f, "bold", 10.5, C.muted)
    w.title = ns.Text(f, "display", 16, C.fg)
    w.res = ns.Text(f, "extra", 14, C.fg, "RIGHT")
    w.names = ns.Text(f, "medium", 12, C.fg)
    w.names:SetWordWrap(true)
    w.names:SetMaxLines(3)
    w.bar = ns.CreateBar(f, 4, false)
    w.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -65)
    w.bar:SetWidth(ns.WIDE - 32)
    w.buttons = {}
    for i = 1, 3 do
        local button = CreateFrame("Frame", nil, f)
        button:SetHeight(30)
        button.body = ns.CreateCardButton(button, 30)
        button.body:SetColor(1, 1, 1, 0.10)
        button.text = ns.Text(button, "bold", 12.5, C.fg, "CENTER")
        button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
        w.buttons[i] = button
    end
    return w
end

-- Fit only the embedded settings preview; live cards retain their actual size.
function B.FitPreview(w, width, height)
    local cardWidth=w.cardWidth or ns.WIDE
    local cardHeight=w.frame:GetHeight()
    local scale=math.min(1,width/math.max(1,cardWidth),height/math.max(1,cardHeight))
    w.frame:SetScale(scale)
    return scale
end

function B.UpdatePreview(w, t)
    w.frame.body:SetStyle(ns.db.lookStyle, 1, true)
    local item = B.Sample(t)
    if not item then return end
    local look = B.Get(t)
    local layout = look.layout
    local color = item.color or C.fg
    local tone = item.tone or color
    local interactive = t == "rolls" or t == "prompts"
    local glyph = item.glyph ~= nil
    w.icon:SetShown(not glyph and layout ~= "centered")
    w.tile:SetShown(glyph and layout ~= "centered")
    w.glyph:SetShown(glyph and layout ~= "centered")
    w.icon:SetTexture(item.icon or item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    w.tile:SetVertexColor(tone[1], tone[2], tone[3], .18)
    w.glyph:SetTexture(ns.MEDIA .. (item.glyph or "Check"))
    w.glyph:SetVertexColor(tone[1], tone[2], tone[3], 1)
    local cc = item.capColor or C.muted
    if look.labelColor == "muted" then cc = C.muted
    elseif look.labelColor == "tone" then cc = interactive and tone or item.tone or item.capColor or C.muted
    elseif look.labelColor == "accent" then cc = ns.Accent() end
    w.cap:SetText(item.cap or "")
    w.cap:SetTextColor(cc[1], cc[2], cc[3])
    w.title:SetText(item.title or item.name or "")
    w.title:SetTextColor(color[1], color[2], color[3])
    local result = item.res or (item.seconds and L["%ds"]:format(item.seconds)) or ""
    w.res:SetText(result)
    local rc = item.resColor or (interactive and C.muted or C.fg)
    ns.UseFont(w.res, "extra", interactive and 15 or 14)
    w.res:SetTextColor(rc[1], rc[2], rc[3])
    local line = look.line ~= false and item.line or ""
    w.names:Show()
    w.names:SetText(line or "")
    w.isRoll = interactive
    ns.LayoutCardHeader(w, layout, look)
    local height = 68
    if line and line ~= "" then height = 64 + math.max(14, math.min(44, w.names:GetStringHeight() or 14)) + 14 end
    local timed = item.progress ~= nil or interactive
    w.bar:SetWidth((w.cardWidth or ns.WIDE) - 32)
    w.bar:SetShown(timed)
    w.bar.fill:SetColor(tone[1], tone[2], tone[3], 1)
    w.bar:Set(.6, 0)
    if timed then height = math.max(height, 83) end
    if interactive then
        w.names:ClearAllPoints()
        w.names:SetPoint("TOPLEFT", w.frame, "TOPLEFT", 14, -79)
        w.names:SetWidth((w.cardWidth or ns.WIDE) - 32)
        w.names:SetJustifyH("LEFT")
        height = 84
    end
    if type(ns.Retail)=="table" and ns.Retail.BossLoot then
        local rowsHeight=ns.Retail.BossLoot.Layout(w,item,look)
        if rowsHeight then height=rowsHeight-(item.button and 40 or 0) end
    end
    local buttons = item.buttons or (item.button and {item.button}) or {}
    if #buttons > 0 then height = height + 40 end
    w.frame:SetHeight(height)
    for i, b in ipairs(w.buttons) do
        local spec = buttons[i]
        b:SetShown(spec ~= nil)
        if spec then
            local width = ((w.cardWidth or ns.WIDE) - 32 - 8 * (#buttons - 1)) / #buttons
            b:SetWidth(width)
            b.body:SetWidth(width)
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", w.frame, "BOTTOMLEFT", 14 + (i - 1) * (width + 8), 14)
            b.text:SetText(spec.label)
            -- BanzaiSland: buttons by role (primary / alt / decline); a non-interactive sample keeps neutral text
            if interactive and ns.Theme then
                b.body:SetRole(ns.Theme.ButtonRole(i, #buttons), false, spec.muted)
            else
                b.body:SetColor(1, 1, 1, 0.10)
                b.body:SetTextColor(C.fg)
            end
        end
    end
end

-- shows a sample of a kind of card on the island right away
function B.Preview(t)
    if not B.Available(t) then return end
    local I = ns.Island
    if not (I and I.built) then return end
    if t == "catchUp" and ns.CatchUp then ns.CatchUp.Demo() return end
    if t == "retailDialogue" and ns.Retail and ns.Retail.Dialogue then ns.Retail.Dialogue.Demo() return end
    local make = SAMPLES[t]
    if not make then return end
    local item = make()
    if t == "rolls" or t == "prompts" then
        -- Preview buttons never answer a real game prompt or loot roll.
        for _, roll in ipairs(I.rolls or {}) do
            if roll.id ~= "builderPreviewRoll" then return end
        end
        item.id, item.builderType, item.fake = "builderPreviewRoll", t, true
        I:AddPrompt(item)
        return
    end
    if I.RemoveRoll then I:RemoveRoll("builderPreviewRoll", true) end
    item.kind, item.key, item.builderType = "won", "builderPreview", t
    item.color = item.color or C.fg
    item.res = item.res or ""
    item.urgent, item.hold, item.priority, item.exact = true, 4, 9, true
    item.onClick, item.replay = false, true
    local cur = I.current
    -- Samples can change card families, including their buttons and reel.
    if cur and cur.key == "builderPreview" then I.current = nil end
    if cur and cur.key ~= "builderPreview" and cur.kind ~= "gain" and cur.dur then
        cur.dur = math.min(cur.dur, cur.t + 0.1)
    end
    I:PushReplace(item)
end
