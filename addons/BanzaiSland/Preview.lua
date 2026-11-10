-- BanzaiSland: Preview / Demo mode. The representative proof scenarios of Foundation Milestone 1,
-- each built from upstream Island's own synthetic paths (Builder samples, demo cards, demo bubbles)
-- so what is shown is exactly what the live code shows, only with made-up data.
--
-- Safety: every scenario is marked synthetic; the card buttons here call plain functions (or Builder's
-- `fake` previews) and never a secure game button, a loot roll, an invite or a ready check. The
-- preview never calls a protected function, never runs in combat (it waits), and the look variants
-- only change this profile's material / accent so they can be put back with RestoreLook.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local PV = {}
ns.Preview = PV
PV.TAG = "SYNTHETIC PREVIEW"

local function I() return ns.Island end
local function C() return ns.C end
local function Ready()
    local isl = I()
    if not (isl and isl.built) then return false end
    if InCombatLockdown and InCombatLockdown() then
        ns.Print(L["Preview waits until you leave combat."])
        return false
    end
    return true
end
local function Muted(s) return (ns.Hex and ns.Hex(0.58, 0.68, 0.60) or "|cff94ad99") .. s .. "|r" end

-- a synthetic activity bubble that ticks down and removes itself
local function Bubble(key, glyph, tone, seconds, tip, bar)
    local isl = I()
    local ends = GetTime() + seconds
    local act = { glyph = glyph, tone = tone, priority = 9, tip = tip or L["Preview bubble"], tip2 = L["Synthetic"],
        text = function()
            local left = math.max(0, ends - GetTime())
            return string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
        end }
    if bar then act.bar = function() return math.max(0, (ends - GetTime()) / seconds) end end
    isl:SetActivity(key, act)
    C_Timer.After(seconds, function() if I() then I():SetActivity(key, nil) end end)
end

local GREEN, BLUE, PURPLE, GOLD, ORANGE, RED = { 0.36, 0.85, 0.45 }, { 0.35, 0.62, 1.00 }, { 0.72, 0.45, 1.00 }, { 0.961, 0.788, 0.416 }, { 0.98, 0.66, 0.28 }, { 0.95, 0.38, 0.38 }

-- ---------------------------------------------------------------- scenarios
local RUN = {}

-- 1. the idle compact chassis: nothing queued, bubbles cleared
function RUN.idle()
    PV.Stop()
end

-- 2. XP / progression: a kill gain and a quest turn-in toast
function RUN.xp()
    local isl, s = I(), ns.GetState()
    local base = s and s.p or 0.4
    isl:Push({ kind = "gain", amount = 1250, p = math.min(1, base + 0.02), unit = "XP", preview = true })
    isl:Push({ kind = "toast", toast = "quest", title = L["The Defias Brotherhood"], amount = 9800, p = math.min(1, base + 0.08), preview = true })
end

-- 3. reputation progression: the gain on the bar and the standing card
function RUN.rep()
    local isl = I()
    isl:Push({ kind = "gain", amount = 250, p = 0.62, unit = "rep", preview = true })
    isl:PushCard({ group = "loot", kind = "won", cap = L["REPUTATION"], title = "Argent Dawn", glyph = "Star", tone = GREEN, color = C().fg,
        res = "+250", resColor = GREEN, line = Muted("Honored   7,450 / 12,000"), hold = 2.8, preview = true })
end

-- 4. a loot notification card (item, quality colour, count)
function RUN.loot()
    local isl, q = I(), ns.QualityColor
    isl:PushCard({ group = "loot", kind = "won", cap = L["LOOT"], title = "Blackened Defias Belt", icon = "Interface\\Icons\\INV_Belt_03",
        color = q(2), res = "x1", hold = 2.6, preview = true })
    isl:PushCard({ group = "loot", kind = "won", cap = L["UPGRADE"], capColor = GREEN, resColor = GREEN, flash = GREEN, title = "Staff of Westfall",
        icon = "Interface\\Icons\\INV_Staff_10", color = q(3), res = L["+%.1f%%"]:format(4), hold = 3.0, preview = true })
end

-- 5. a ready-check interactive prompt (plain demo buttons, never the game's)
function RUN.readycheck()
    if ns.DemoPrompts then ns.DemoPrompts() end
end

-- 6. a group-invite prompt: Builder's `fake` prompt sample
function RUN.invite()
    if ns.Builder and ns.Builder.Preview then ns.Builder.Preview("prompts") end
end

-- 7. a timer bubble (pull timer: countdown with a bar)
function RUN.timer()
    Bubble("preview-timer", "Hourglass", ORANGE, 30, L["Pull timer"], true)
end

-- 8. a flight / activity bubble with its card
function RUN.flight()
    if ns.DemoLive then ns.DemoLive() else Bubble("preview-flight", "Plane", BLUE, 20, L["Flight"]) end
end

-- 9. a success notification
function RUN.success()
    I():PushCard({ group = "alerts", kind = "won", cap = L["COMPLETE"], capColor = GREEN, glyph = "Check", tone = GREEN, title = L["Dungeon cleared"],
        color = C().fg, res = "12:40", line = Muted(L["The Deadmines"]), hold = 3, preview = true })
end

-- 10. a warning / error notification, and the island's own error pill
function RUN.warning()
    I():PushCard({ group = "alerts", kind = "won", cap = L["LOW DURABILITY"], capColor = ORANGE, glyph = "Shield", tone = ORANGE, title = "Ironfoe",
        color = C().fg, res = "18%", resColor = ORANGE, hold = 3, preview = true })
    C_Timer.After(3.4, function()
        local isl = I()
        if isl and isl.ShowError then isl:ShowError(L["Not enough rage"]) end
    end)
    C_Timer.After(4.2, function()
        I():PushCard({ group = "alerts", kind = "won", cap = L["ERROR"], capColor = RED, glyph = "Alert", tone = RED, title = L["Inventory is full"],
            color = C().fg, res = "", hold = 3, preview = true })
    end)
end

-- 11-13. look variants are PV.Look; 14-15 are the running client (Client.lua): see PV.Status

-- a loot roll with Need / Greed / Pass (Builder's fake roll: nothing is rolled on)
function RUN.roll()
    if ns.Builder and ns.Builder.Preview then ns.Builder.Preview("rolls") end
end

-- a level-up card (the display font and the class badge)
function RUN.levelup()
    local isl, s = I(), ns.GetState()
    isl:Push({ kind = "levelup", level = (s and s.level or 41) + 1, p = 0.04, preview = true,
        chips = { L["+%s health"]:format("38"), L["+%s mana"]:format("52"), L["+%d talent point"]:format(1) } })
end

-- 0.2.0: the chassis edge styles, with a card so the lines are seen growing
function RUN.bamboo()
    PV.Edge("bamboo")
    RUN.xp()
end
function RUN.hairline()
    PV.Edge("hairline")
    RUN.xp()
end

-- 0.2.0: the integrated BANZAI SLAND mark: hover each half for two seconds, then rest
local function Hover(half, on)
    local isl = I()
    local b = isl and isl.brand
    if not b then return end
    local zone = half == "banzai" and b.banzaiZone or b.slandZone
    local script = zone and zone:GetScript(on and "OnEnter" or "OnLeave")
    if script then script(zone) end
end
function RUN.wordmark()
    Hover("banzai", true)
    C_Timer.After(2, function() Hover("banzai", false) Hover("sland", true) end)
    C_Timer.After(4, function() Hover("sland", false) end)
end
function RUN.hoverbanzai() Hover("banzai", true) C_Timer.After(2.5, function() Hover("banzai", false) end) end
function RUN.hoversland() Hover("sland", true) C_Timer.After(2.5, function() Hover("sland", false) end) end

-- 0.2.0: BANZAI UI absent - the BANZAI half is branding; clicking says so once and never errors
function RUN.banzaiabsent()
    local Launcher = ns.Launcher
    local was, said = Launcher.simulate, Launcher.saidAbsent
    Launcher.simulate, Launcher.saidAbsent = "absent", nil
    local ok, why = Launcher.ClickBanzai()
    ns.Print(L["Preview: BANZAI click with BANZAI UI absent -> %s (%s)"]:format(tostring(ok), tostring(why)))
    Launcher.ClickBanzai() -- a second click says nothing more
    Launcher.simulate, Launcher.saidAbsent = was, said
end

PV.SCENARIOS = {
    { id = "idle", label = L["Idle chassis"] },
    { id = "xp", label = L["XP progression"] },
    { id = "rep", label = L["Reputation"] },
    { id = "loot", label = L["Loot notification"] },
    { id = "readycheck", label = L["Ready check"] },
    { id = "invite", label = L["Group invite"] },
    { id = "roll", label = L["Loot roll"] },
    { id = "timer", label = L["Timer bubble"] },
    { id = "flight", label = L["Flight bubble"] },
    { id = "success", label = L["Success notification"] },
    { id = "warning", label = L["Warning and error"] },
    { id = "levelup", label = L["Level up"] },
    { id = "bamboo", label = L["Bamboo chassis"] },
    { id = "hairline", label = L["Hairline chassis"] },
    { id = "wordmark", label = L["BANZAI SLAND mark"] },
    { id = "hoverbanzai", label = L["BANZAI hover"] },
    { id = "hoversland", label = L["SLAND hover"] },
    { id = "banzaiabsent", label = L["BANZAI UI absent"] },
}
PV.RUN = RUN

function PV.Has(id) return RUN[id] ~= nil end

function PV.Run(id)
    local fn = RUN[id]
    if not fn then ns.Print(L["Unknown preview: %s"]:format(tostring(id))) return false end
    if not Ready() then return false end
    if not PV.announced then
        PV.announced = true
        ns.Print(L["%s: made-up cards, bubbles and prompts. Nothing here answers the game."]:format(PV.TAG))
    end
    local ok, err = pcall(fn)
    if not ok then ns.Print(L["Preview %s failed: %s"]:format(tostring(id), tostring(err))) end
    return ok
end

-- clear everything the previews put up
function PV.Stop()
    local isl = I()
    if not (isl and isl.built) then return end
    PV.touring = nil
    for _, key in ipairs({ "preview-timer", "preview-flight", "demo" }) do isl:SetActivity(key, nil) end
    if isl.RemoveRoll then
        isl:RemoveRoll("builderPreviewRoll", true)
        for _, id in ipairs({ "readycheck", "demo-summon" }) do pcall(isl.RemoveRoll, isl, id, true) end
    end
    if isl.queue then for i = #isl.queue, 1, -1 do if isl.queue[i].preview then table.remove(isl.queue, i) end end end
    if isl.current and isl.current.preview and isl.current.dur then isl.current.dur = math.min(isl.current.dur, isl.current.t or 0) end
    isl:Settle()
end

-- every scenario in order, a few seconds apart
function PV.Tour()
    if not Ready() then return end
    PV.Stop()
    PV.touring = true
    local t = 0.2
    for _, s in ipairs(PV.SCENARIOS) do
        if s.id ~= "idle" then
            local id = s.id
            C_Timer.After(t, function() if PV.touring then PV.Run(id) end end)
            t = t + 6
        end
    end
    C_Timer.After(t, function() if PV.touring then PV.Stop() end end)
end

-- ---------------------------------------------------------------- look variants
-- remember the player's own look the first time a variant is tried, so it can be put back
local function Remember()
    if not PV.saved then PV.saved = { material = ns.db.material, accentTheme = ns.db.accentTheme, chassisEdge = ns.db.chassisEdge } end
end
function PV.Look(material, accent)
    if not ns.db then return end
    Remember()
    if material then ns.db.material = material end
    if accent then ns.db.accentTheme = accent end
    local isl = I()
    if isl and isl.built then isl:ApplyLook() end
    ns.Print(L["Preview look: %s"]:format(ns.Theme.Describe()))
end

-- 0.2.0: the chassis edge style as a look variant
function PV.Edge(edge)
    if not ns.db then return end
    Remember()
    ns.db.chassisEdge = edge
    local isl = I()
    if isl and isl.built then isl:ApplyLook() end
    ns.Print(L["Preview look: %s"]:format(ns.Theme.Describe()))
end

function PV.RestoreLook()
    if not (ns.db and PV.saved) then return end
    ns.db.material, ns.db.accentTheme, ns.db.chassisEdge = PV.saved.material, PV.saved.accentTheme, PV.saved.chassisEdge
    PV.saved = nil
    local isl = I()
    if isl and isl.built then isl:ApplyLook() end
end

-- the running client and theme, for /bsl status and the About page
function PV.Status()
    return string.format("BanzaiSland %s | client %s | %s | BANZAI UI %s | guard %s", tostring(ns.VERSION), ns.Client and ns.Client.kind or "?",
        ns.Theme.Describe(), (ns.Launcher and ns.Launcher.BanzaiUIPresent()) and "present" or "absent", ns.Blocked and "blocked" or "clear")
end
