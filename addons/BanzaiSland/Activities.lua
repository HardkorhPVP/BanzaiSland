-- Island: more live activities for the bubble beside the island. A fishing lure, pull and break
-- timers from DBM or BigWigs, server restarts, ready checks, raid lockouts and your active
-- tracking, plus a small flask by the island when a profession cooldown is ready.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local floor, max, min = math.floor, math.max, math.min
local I, C = ns.Island, ns.C
local Clock = ns.Clock

local BLUE = { 0.40, 0.72, 1.00 }
local TEAL = { 0.35, 0.85, 0.80 }
local GREEN = { 0.36, 0.85, 0.45 }
local RED = { 0.95, 0.38, 0.38 }
local PURPLE = { 0.70, 0.55, 1.00 }
local GOLD = C.gold
local MUTED_HEX = ns.Hex(C.muted[1], C.muted[2], C.muted[3])

local function Readable(v) return ns.Readable(v) end
local function Num(v) return Readable(v) and type(v) == "number" and v or nil end
local function Str(v) return Readable(v) and type(v) == "string" and v or nil end

-- "3d 4h", "4h 12m", or a plain clock under an hour
local function Long(sec)
    sec = max(0, floor(sec))
    if sec >= 86400 then return L["%dd %dh"]:format(floor(sec / 86400), floor(sec / 3600) % 24) end
    if sec >= 3600 then return L["%dh %dm"]:format(floor(sec / 3600), floor(sec / 60) % 60) end
    return Clock(sec)
end

local function Short(name)
    name = Str(name)
    if not name then return nil end
    return ns.ShowName(name)
end

-- ---------------------------------------------------------------- fishing lure

local lure = { on = false }

local function PoleEquipped()
    local id = GetInventoryItemID and GetInventoryItemID("player", 16)
    if not id then return false end
    local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not info then return false end
    local ok, _, _, _, _, _, classID, subclassID = pcall(info, id)
    return ok and classID == 2 and subclassID == 20
end

local function LureLeft()
    if not GetWeaponEnchantInfo then return nil end
    local ok, has, ms = pcall(GetWeaponEnchantInfo)
    if ok and Readable(has) and has and Num(ms) then return ms / 1000 end
end

local function CheckLure()
    local pole = ns.db.liveLure and PoleEquipped()
    local left = pole and LureLeft()
    if left and left > 0 then
        if not lure.on then
            lure.on = true
            local total = left       -- the game only says what is left, so the first reading is the full length
            I:SetActivity("lure", { glyph = "Fish", tone = TEAL, priority = 1.5, tip = L["Fishing lure"], tip2 = L["Time left on your lure"],
                                    text = function() return Clock(LureLeft() or 0) end,
                                    native = true, noEase = true,
                                    progress = function() return total > 0 and min(1, (LureLeft() or 0) / total) or 0 end })
        end
    elseif lure.on then
        lure.on = false
        I:SetActivity("lure", nil)
        if pole then
            I:Push({ kind = "won", glyph = "Fish", tone = TEAL, cap = L["FISHING"], capColor = TEAL,
                     title = L["Your lure ran out"], color = C.fg, res = "", hold = 3, transient = true })
        end
    end
end

-- ---------------------------------------------------------------- profession cooldowns

local PROF = {
    { name = L["Transmute"], spells = { 17187, 11479, 11480, 17559, 17560, 17561, 17562, 17563, 17564, 17565, 17566, 25146,
                                     28566, 28567, 28568, 28569, 28580, 28581, 28582, 28583, 28584, 28585, 29688, 32765, 32766 } },
    { name = L["Mooncloth"], spells = { 18560 } },
    { name = L["Primal Mooncloth"], spells = { 26751 } },
    { name = L["Spellcloth"], spells = { 31373 } },
    { name = L["Shadowcloth"], spells = { 36686 } },
    { name = L["Salt Shaker"], item = 15846 },
}

local function Known(id)
    if IsPlayerSpell then
        local ok, v = pcall(IsPlayerSpell, id)
        if ok and v then return true end
    end
    if IsSpellKnown then
        local ok, v = pcall(IsSpellKnown, id)
        if ok and v then return true end
    end
    return false
end

local function SpellLeft(id)
    local start, dur
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, id)
        if ok and type(info) == "table" then start, dur = info.startTime, info.duration end
    elseif GetSpellCooldown then
        local ok, s, d = pcall(GetSpellCooldown, id)
        if ok then start, dur = s, d end
    end
    start, dur = Num(start), Num(dur)
    if not (start and dur) then return nil end
    if dur <= 2 or start <= 0 then return 0 end         -- free, or only the global cooldown
    return max(0, start + dur - GetTime())
end

local function ItemLeft(id)
    if not GetItemCount or GetItemCount(id) == 0 then return nil end
    local getCD = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
    if not getCD then return nil end
    local ok, start, dur = pcall(getCD, id)
    start, dur = ok and Num(start), ok and Num(dur)
    if not (start and dur) then return nil end
    if dur <= 2 or start <= 0 then return 0 end
    return max(0, start + dur - GetTime())
end

local prof = { ready = {}, first = true }

local function CheckProf()
    if not ns.db.liveProfCD then
        I:SetWarning("profcd", nil)
        return
    end
    local ready, soonest = {}, nil
    for _, p in ipairs(PROF) do
        local left
        if p.item then
            left = ItemLeft(p.item)
        else
            for _, id in ipairs(p.spells) do
                if Known(id) then left = SpellLeft(id) break end
            end
        end
        if left then
            if left == 0 then
                ready[#ready + 1] = p.name
                if not prof.ready[p.name] and not prof.first then
                    if ns.CatchUp then ns.CatchUp.Record("cooldowns", p.name, L["%s is ready"]:format(p.name), L["Cooldown finished"], {glyph="Flask", once=true}) end
                    I:Push({ kind = "won", catchUpCategory = "cooldowns", glyph = "Flask", tone = GREEN, cap = L["COOLDOWN READY"], capColor = GREEN,
                             title = L["%s is ready"]:format(p.name), color = C.fg, res = "", hold = 3 })
                end
            elseif not soonest or left < soonest.left then
                soonest = { name = p.name, left = left }
            end
            prof.ready[p.name] = (left == 0) or nil
        end
    end
    prof.first = false
    if #ready > 0 then
        I:SetWarning("profcd", {
            glyph = "Flask", tone = GREEN, priority = 0.5, tip = L["Ready to craft"], tip2 = table.concat(ready, ", ")
                .. (soonest and ("\n" .. L["%s in %s"]:format(soonest.name, Long(soonest.left))) or ""),
        })
    else
        I:SetWarning("profcd", nil)
    end
end

-- ---------------------------------------------------------------- tracking

-- Island's own drawings for the common kinds, in the same style as the other bubbles. Anything
-- else (a hunter's demons or giants, say) shows the game's own icon.
local COPPER = { 0.88, 0.58, 0.38 }
local TRACK = {
    herbs     = { glyph = "Herb",   tone = GREEN },
    minerals  = { glyph = "Ore",    tone = COPPER },
    treasure  = { glyph = "Chest",  tone = GOLD },
    fish      = { glyph = "Fish",   tone = TEAL },
    beasts    = { glyph = "Paw",    tone = { 0.98, 0.66, 0.28 } },
    humanoids = { glyph = "Person", tone = BLUE },
}
local TRACK_SPELL = { [2383] = "herbs", [2580] = "minerals", [2481] = "treasure", [43308] = "fish",
                      [1494] = "beasts", [19883] = "humanoids", [5225] = "humanoids" }
local TRACK_ICON = { [133939] = "herbs", [136025] = "minerals", [135725] = "treasure", [133888] = "fish",
                     [132328] = "beasts", [135942] = "humanoids" }
local TRACK_WORD = { Herb = "herbs", Mineral = "minerals", Treasure = "treasure", Fish = "fish",
                     Beast = "beasts", Humanoid = "humanoids" }

local function TrackKind(tex, name, spell)
    if spell and TRACK_SPELL[spell] then return TRACK_SPELL[spell] end
    if type(tex) == "number" and TRACK_ICON[tex] then return TRACK_ICON[tex] end
    if type(tex) == "string" then
        local t = tex:lower()
        if t:find("flower_02") then return "herbs" end
        if t:find("earthquake") then return "minerals" end
        if t:find("findtreasure") then return "treasure" end
    end
    if type(name) == "string" then
        for word, kind in pairs(TRACK_WORD) do
            if name:find(word) then return kind end
        end
    end
end

local function ActiveTracking()
    local M = C_Minimap
    if M and M.GetNumTrackingTypes and M.GetTrackingInfo then
        local ok, n = pcall(M.GetNumTrackingTypes)
        if ok and type(n) == "number" then
            for i = 1, n do
                local ok2, a, b, c, d, e, f = pcall(M.GetTrackingInfo, i)
                if ok2 then
                    local name, tex, active, kind, spell
                    if type(a) == "table" then
                        name, tex, active, kind, spell = a.name, a.texture, a.active, a.type, a.spellID
                    else
                        name, tex, active, kind, spell = a, b, c, d, f
                    end
                    -- spells (herbs, minerals, beasts); not the town icons like mailboxes
                    if active and tex and (kind == nil or kind == "spell") then return tex, name, spell, i end
                end
            end
            return nil
        end
    end
    if GetTrackingTexture then
        local ok, tex = pcall(GetTrackingTexture)
        if ok then return tex end
    end
end

-- turn off what you are tracking (clicking the bubble)
local function StopTracking(index)
    local M = C_Minimap
    if index and M and M.SetTracking then
        pcall(M.SetTracking, index, false)
    elseif CancelTrackingBuff then
        pcall(CancelTrackingBuff)
    end
end

local tracking
local function CheckTracking()
    local tex, name, spell, index
    if ns.db.liveTracking then tex, name, spell, index = ActiveTracking() end
    local id = tex and tostring(tex) .. tostring(spell) or nil
    if id == tracking then return end
    tracking = id
    if not tex then I:SetActivity("tracking", nil) return end
    local look = TRACK[TrackKind(tex, Str(name), Num(spell)) or ""]
    local act = look and { glyph = look.glyph, tone = look.tone } or { texture = tex }
    act.priority = -1
    act.pin = "Tracking"
    act.tip = Str(name) or L["Tracking"]
    act.hint = L["Stop tracking"]
    act.onClick = function() StopTracking(index) end
    I:SetActivity("tracking", act)
end

-- ---------------------------------------------------------------- pull and break timers

local timers = {}

local function StopTimer(key)
    if timers[key] then timers[key] = nil I:SetActivity(key, nil) end
end

-- is this name you? (a pull you started can be cancelled from its card)
local function Mine(who)
    if not who or not UnitName then return false end
    local me = UnitName("player")
    return me ~= nil and ns.FirstName(who) == me
end

-- Call off a pull: the game's own countdown, and DBM's or BigWigs' pull timer if they are there
-- ("/pull 0" is how both cancel one).
local function CancelPull()
    if C_PartyInfo and C_PartyInfo.DoCountdown then pcall(C_PartyInfo.DoCountdown, 0) end
    for _, key in ipairs({ "DEADLYBOSSMODSPULL", "BIGWIGSPULL" }) do
        local fn = SlashCmdList and SlashCmdList[key]
        if type(fn) == "function" then pcall(fn, "0") end
    end
    timers.pull = nil
end

local function StartTimer(key, secs, who)
    if not ns.db.livePull then return end
    if secs <= 0 then StopTimer(key) return end
    local now = GetTime()
    local t = timers[key]
    -- DBM and BigWigs each send the same timer; only the first one makes a card
    local fresh = not (t and math.abs((t.ends - now) - secs) < 2)
    timers[key] = { ends = now + secs, total = secs }
    local pull = key == "pull"
    local tone = pull and RED or BLUE
    if pull then
        -- a pull counts down on its own card, which stays up until the pull (no bubble)
        timers[key].who = who
        local cur = I.current
        local showing = cur and cur.key == "pull"
        for _, q in ipairs(I.queue or {}) do if q.key == "pull" then showing = true end end
        if not showing then
            -- the countdown matters now: whatever card is up steps aside for it
            if cur and cur.kind ~= "gain" and cur.dur then cur.dur = math.min(cur.dur, cur.t + 0.15) end
            if ns.Rumble then ns.Rumble("pull") end
            I:Push({
                kind = "won", key = "pull", urgent = true, priority = 8, group = "alerts", exact = true,
                glyph = "Clock", tone = tone, cap = L["PULL TIMER"], capColor = tone, color = C.fg,
                title = who and L["Started by %s"]:format(who) or L["Get ready"], res = L["%ds"]:format(secs), resColor = C.muted,
                hold = secs + 3, sound = 8960,
                -- you started it: you can call it off
                button = Mine(who) and { label = L["Cancel"], fn = CancelPull } or nil,
                progress = function()
                    local t = timers.pull
                    if not t or not t.total or t.total <= 0 then return 0 end
                    return (t.ends - GetTime()) / t.total
                end,
                live = function(item)
                    local t = timers.pull
                    if not t then
                        item.dur = math.min(item.dur, item.t + 0.6)
                        return L["Cancelled"]
                    end
                    local left = t.ends - GetTime()
                    if left > 0 then return L["%ds"]:format(math.ceil(left)) end
                    if left < -1.5 then item.dur = math.min(item.dur, item.t) end
                    return L["Pull!"]
                end,
            })
        end
        return
    end
    I:SetActivity(key, {
        glyph = "Clock", tone = tone, priority = pull and 8 or 6,
        tip = pull and L["Pull timer"] or L["Break"], tip2 = who and L["Started by %s"]:format(who) or nil,
        text = function()
            local left = (timers[key] and timers[key].ends or 0) - GetTime()
            return pull and L["%ds"]:format(max(0, math.ceil(left))) or Clock(left)
        end,
        native = true, noEase = true,
        progress = function()
            local t = timers[key]
            if not t or not t.total or t.total <= 0 then return 0 end
            return max(0, min(1, (t.ends - GetTime()) / t.total))
        end,
    })
    if fresh then
        I:Push({ kind = "won", builderType = "timers", glyph = "Clock", tone = tone, cap = L["BREAK"], capColor = tone,
                 title = L["Break for %s"]:format((secs % 60 == 0 and secs < 3600) and L["%d min"]:format(secs / 60) or Long(secs)), color = C.fg,
                 res = "", hold = 2.4,
                 line = who and (MUTED_HEX .. L["Started by %s"]:format(who) .. "|r") or nil })
    end
end

local function OnAddonMessage(prefix, text, _, sender)
    prefix, text = Str(prefix), Str(text)
    if not (prefix and text) then return end
    local who = Short(sender)
    if prefix == "BigWigs" then
        local kind, n = text:match("^P%^(%a+)%^(%d+)")
        n = tonumber(n)
        if kind == "Pull" and n then StartTimer("pull", n, who)
        elseif kind == "Break" and n then StartTimer("break", n, who) end
    elseif prefix == "D4" or prefix == "D5" then
        local n = tonumber(text:match("%f[%w]PT\t(%d+)"))
        if n then StartTimer("pull", n, who) return end
        n = tonumber(text:match("%f[%w]BT\t(%d+)"))
        if n then StartTimer("break", n, who) end
    end
end

-- The game's big countdown numbers in the middle of the screen (TimerTracker). Only the player
-- countdown (/cd) is made see-through; battleground and Mythic+ start timers are left alone.
local PLAYER_COUNTDOWN = (Enum and Enum.StartTimerType and Enum.StartTimerType.PlayerCountdown) or 2
local function QuietCountdown()
    local tt = _G.TimerTracker
    if type(tt) ~= "table" or type(tt.timerList) ~= "table" then return end
    local quiet = ns.db.livePull and not ns.db.showGameCountdown
    for _, t in ipairs(tt.timerList) do
        if type(t) == "table" and t.SetAlpha then
            local isCountdown = (t.type == PLAYER_COUNTDOWN) or (t.type == nil and timers.pull ~= nil)
            t:SetAlpha((quiet and isCountdown) and 0 or 1)
        end
    end
end
ns.QuietCountdown = QuietCountdown

-- the game's own countdown (/cd 10, or the countdown button): the same pull timer card
local function OnCountdown(initiatedBy, timeRemaining, totalTime, _, initiatedByName)
    local secs = Num(timeRemaining) or Num(totalTime)
    if not secs then return end
    secs = math.floor(secs + 0.5)
    local who = Short(initiatedByName)
    if not who and Str(initiatedBy) and GetPlayerInfoByGUID then
        local ok, _, _, _, _, _, name = pcall(GetPlayerInfoByGUID, initiatedBy)
        if ok then who = Short(name) end
    end
    StartTimer("pull", secs, who)
    QuietCountdown()
    C_Timer.After(0.05, QuietCountdown)
end

local function TickTimers()
    for key, t in pairs(timers) do
        -- a pull card holds "Pull!" for a moment after zero, so its timer lives a little longer
        if GetTime() >= t.ends + (key == "pull" and 2 or 0) then
            StopTimer(key)
            if key == "break" then
                I:Push({ kind = "won", urgent = true, glyph = "Clock", tone = BLUE, cap = L["BREAK"], capColor = BLUE,
                         title = L["Break's over"], color = C.fg, res = "", hold = 3, sound = 8960, soundKey = "breakOver" })
            end
        end
    end
end

-- ---------------------------------------------------------------- server restart

local shutdown

local function ParseWait(msg)
    local h, m, s = msg:match("(%d+):(%d%d):(%d%d)")
    if h then return h * 3600 + m * 60 + s end
    m, s = msg:match("(%d+):(%d%d)")
    if m then return m * 60 + s end
    local total, found = 0, false
    for n, unit in msg:gmatch("(%d+)%s*(%a+)") do
        unit = unit:lower()
        if unit:find("^hour") or unit == "h" or unit == "hr" or unit == "hrs" then total, found = total + n * 3600, true
        elseif unit:find("^min") or unit == "m" then total, found = total + n * 60, true
        elseif unit:find("^sec") or unit == "s" then total, found = total + n, true end
    end
    return found and total or nil
end

local function OnSystemMessage(msg)
    msg = Str(msg)
    if not (msg and ns.db.liveShutdown) then return end
    local low = msg:lower()
    if not (low:find("shutdown") or low:find("shut down") or low:find("restart")) then return end
    if low:find("cancel") then
        if shutdown then
            shutdown = nil
            I:SetActivity("shutdown", nil)
            I:Push({ kind = "won", glyph = "Power", tone = GREEN, cap = L["SERVER"], capColor = GREEN,
                     title = L["Restart cancelled"], color = C.fg, res = "", hold = 3 })
        end
        return
    end
    local secs = ParseWait(msg)
    if not secs then return end
    local first = not shutdown
    local last = secs <= 60 and not (shutdown and shutdown.warned)
    shutdown = { ends = GetTime() + secs, total = secs, warned = (shutdown and shutdown.warned) or secs <= 60 }
    I:SetActivity("shutdown", { glyph = "Power", tone = RED, priority = 9, tip = L["Server restart"],
        tip2 = L["The server shuts down when this reaches zero"],
        text = function() return Clock(shutdown and (shutdown.ends - GetTime()) or 0) end,
        native = true, noEase = true,
        progress = function()
            if not shutdown or not shutdown.total or shutdown.total <= 0 then return 0 end
            return max(0, min(1, (shutdown.ends - GetTime()) / shutdown.total))
        end })
    if first or last then
        I:Push({ kind = "won", urgent = last, glyph = "Power", tone = RED, cap = L["SERVER RESTART"], capColor = RED,
                 title = L["Server restarts in %s"]:format(Long(secs)), color = C.fg, res = "", hold = 4, flash = last and RED or nil })
    end
end

-- ---------------------------------------------------------------- ready check

local ready

local function ReadyStart(_, secs)
    if not ns.db.liveReady then return end
    secs = Num(secs) or 30
    ready = GetTime() + secs
    I:SetActivity("ready", { glyph = "Check", tone = GOLD, priority = 7, tip = L["Ready check"], tip2 = L["Time left to answer"],
        text = function() return L["%ds"]:format(max(0, math.ceil((ready or 0) - GetTime()))) end,
        native = true, noEase = true,
        progress = function() return secs > 0 and max(0, min(1, ((ready or 0) - GetTime()) / secs)) or 0 end })
end

local function ReadyEnd()
    ready = nil
    I:SetActivity("ready", nil)
end

-- ---------------------------------------------------------------- raid lockout

local lockout

local function CheckLockout()
    local inside, kind = IsInInstance()
    if not (ns.db.liveLockout and inside and kind == "raid") then
        if lockout then lockout = nil I:SetActivity("lockout", nil) end
        return
    end
    local name, _, _, _, _, _, _, here = GetInstanceInfo()
    local found
    for i = 1, (GetNumSavedInstances and GetNumSavedInstances() or 0) do
        local ok, sname, _, reset, _, locked, _, _, _, _, _, _, _, _, sid = pcall(GetSavedInstanceInfo, i)
        if ok and locked and Num(reset) and ((sid and sid == here) or sname == name) then
            found = reset
            break
        end
    end
    if found then
        lockout = GetTime() + found
        I:SetActivity("lockout", { glyph = "Door", tone = PURPLE, priority = 0.8, tip = L["%s lockout"]:format(Str(name) or L["Raid"]),
            tip2 = L["Time until the raid resets"],
            text = function() return Long((lockout or 0) - GetTime()) end })
    elseif lockout then
        lockout = nil
        I:SetActivity("lockout", nil)
    end
end

local function AskLockout()
    local inside, kind = IsInInstance()
    if inside and kind == "raid" and RequestRaidInfo then RequestRaidInfo() end
    CheckLockout()
end

-- ---------------------------------------------------------------- demos

function ns.DemoPull()
    StartTimer("pull", 10, UnitName("player"))
end

function ns.DemoShutdown()
    local was = ns.db.liveShutdown
    ns.db.liveShutdown = true
    OnSystemMessage("[SERVER] Shutdown in 5:00 (demo)")
    ns.db.liveShutdown = was
    C_Timer.After(12, function()
        if shutdown then shutdown = nil I:SetActivity("shutdown", nil) end
    end)
end

-- ---------------------------------------------------------------- events

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, a, b, c, d, ...)
    if not ns.db then return end
    if event == "PLAYER_LOGIN" then
        local reg = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
        if reg then for _, p in ipairs({ "BigWigs", "D4", "D5" }) do pcall(reg, p) end end
        C_Timer.After(5, function() CheckLure() CheckProf() CheckTracking() AskLockout() end)
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(a, b, c, d)
    elseif event == "START_PLAYER_COUNTDOWN" then
        OnCountdown(a, b, c, d, select(1, ...))
    elseif event == "CANCEL_PLAYER_COUNTDOWN" then
        StopTimer("pull")
    elseif event == "START_TIMER" then
        -- the game reuses its timer frames: set each one right for the timer it now shows
        QuietCountdown()
        C_Timer.After(0.05, QuietCountdown)
    elseif event == "CHAT_MSG_SYSTEM" then
        OnSystemMessage(a)
    elseif event == "READY_CHECK" then
        ReadyStart(a, b)
    elseif event == "READY_CHECK_FINISHED" then
        ReadyEnd()
    elseif event == "MINIMAP_UPDATE_TRACKING" then
        CheckTracking()
    elseif event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        CheckLure()
    elseif event == "UPDATE_INSTANCE_INFO" then
        CheckLockout()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "BOSS_KILL" then
        C_Timer.After(1, AskLockout)
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" or event == "TRADE_SKILL_UPDATE" then
        if not ev.profSoon then
            ev.profSoon = true
            C_Timer.After(1, function() ev.profSoon = nil CheckProf() end)
        end
    end
end)
for _, event in ipairs({ "PLAYER_LOGIN", "CHAT_MSG_ADDON", "START_PLAYER_COUNTDOWN", "CANCEL_PLAYER_COUNTDOWN", "START_TIMER", "CHAT_MSG_SYSTEM", "READY_CHECK", "READY_CHECK_FINISHED",
                         "MINIMAP_UPDATE_TRACKING", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
                         "UPDATE_INSTANCE_INFO", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "BOSS_KILL",
                         "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "TRADE_SKILL_UPDATE" }) do
    pcall(ev.RegisterEvent, ev, event)
end

-- every second: lure and timers; every 30 seconds: profession cooldowns (they tick over silently)
local since, slow = 0, 0
ev:SetScript("OnUpdate", function(_, dt)
    since = since + dt
    if since < 1 then return end
    slow = slow + since
    since = 0
    if not (I.built and ns.db) then return end
    if lure.on or ns.db.liveLure then CheckLure() end
    TickTimers()
    if timers.pull then QuietCountdown() end
    if shutdown and GetTime() > shutdown.ends + 5 then shutdown = nil I:SetActivity("shutdown", nil) end
    if ready and GetTime() > ready + 2 then ReadyEnd() end
    if slow >= 30 then slow = 0 CheckProf() end
end)

-- settings switches call this so a change shows at once
function ns.ApplyActivities()
    CheckLure() CheckProf() CheckTracking() CheckLockout()
    if not ns.db.livePull then StopTimer("pull") StopTimer("break") end
    if not ns.db.liveReady then ReadyEnd() end
    if not ns.db.liveShutdown and shutdown then shutdown = nil I:SetActivity("shutdown", nil) end
end
