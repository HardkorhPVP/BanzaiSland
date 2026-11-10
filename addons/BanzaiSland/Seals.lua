-- Island: buff pills. Small black pills that slide out from the player's unit frame, one for each
-- buff tracked in the game's Cooldown Manager (Tracked Buffs and Tracked Bars) while it is up, with
-- its icon, name and time left. Paladins also get their seal (tracked there or not) and, in combat
-- with no seal, a pill that says so.
-- The Cooldown Manager's frames keep working in combat, when this client hides buffs from addons,
-- so the pills read them instead of the buff list.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local C = ns.C

local S = { since = 0, pills = {}, order = {} }
ns.Seals = S
ns.Buffs = S

local ORANGE = { 0.98, 0.66, 0.28 }
local RED = { 0.95, 0.38, 0.38 }
local H, GAP, STEP, MAX_PILLS = 28, 6, 32, 8
local UNIT_FRAMES = { "EllesmereUIUnitFrames_Player", "ElvUF_Player", "SUFUnitplayer", "PlayerFrame" }
local SEAL_IDS = { 21084, 20375, 20164, 20165, 20166, 20162, 31801, 31892, 348704, 20154, 53736, 20424 }
local BUFF_VIEWERS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

-- seal names in the game's language, plus the English "Seal of ..." pattern as a catch-all
local sealNames
local function IsSeal(name)
    if type(name) ~= "string" then return false end
    if not sealNames then
        sealNames = {}
        local info = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
        for _, id in ipairs(SEAL_IDS) do
            local ok, n = pcall(info, id)
            if ok and type(n) == "string" then sealNames[n] = true end
        end
    end
    return sealNames[name] == true or name:find("^Seal of ") ~= nil
end

local function BuffAt(i)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local d = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if d then return d.name, d.icon, d.duration, d.expirationTime, d.spellId end
        return nil
    elseif UnitBuff then
        local name, icon, _, _, duration, expires, _, _, _, spellId = UnitBuff("player", i)
        return name, icon, duration, expires, spellId
    end
end

local function Number(v) return ns.Readable(v) and type(v) == "number" and v or nil end

-- The last seal seen while the game still let addons read buffs. In combat this client can hide
-- buff names and timers from addons, so the pill keeps showing what it knew and counts down.
local known
local durations = {}       -- seal name -> full duration, learned whenever the buff is readable

local function SpellName(id)
    if not id or not ns.Readable(id) then return nil end
    local fn = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    local ok, n = pcall(fn, id)
    if ok and type(n) == "string" and ns.Readable(n) then return n end
end

local function SpellIcon(id)
    if not id or not ns.Readable(id) then return nil end
    local fn = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
    if not fn then return nil end
    local ok, t = pcall(fn, id)
    if ok and ns.Readable(t) then return t end
end

-- ---------------------------------------------------------------------------------------------
-- The game's Cooldown Manager. Its buff trackers are Blizzard frames, so they keep working in
-- combat. If a seal is added to "Tracked Buffs", its icon there shows whether the seal is up, and
-- the pill reads that instead of the hidden buff list.
local VIEWERS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer", "EssentialCooldownViewer", "UtilityCooldownViewer" }

local function ItemFrames(viewer)
    local list = {}
    local ok = pcall(function()
        if viewer.GetItemFrames then
            for _, item in ipairs(viewer:GetItemFrames() or {}) do list[#list + 1] = item end
        end
    end)
    if #list == 0 and viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
        pcall(function() for item in viewer.itemFramePool:EnumerateActive() do list[#list + 1] = item end end)
    end
    if #list == 0 then
        for _, child in ipairs({ viewer:GetChildren() }) do
            if child.cooldownID or child.GetCooldownID then list[#list + 1] = child end
        end
    end
    return list
end

-- the spells an item tracks (config data, not combat data, so it stays readable)
local function ItemIDs(item)
    local ids = {}
    pcall(function()
        local info = item.GetCooldownInfo and item:GetCooldownInfo()
        if not info and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
            local cid = item.GetCooldownID and item:GetCooldownID() or item.cooldownID
            if cid then info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cid) end
        end
        if info then
            ids[#ids + 1] = info.overrideSpellID
            ids[#ids + 1] = info.spellID
            for _, id in ipairs(info.linkedSpellIDs or {}) do ids[#ids + 1] = id end
        end
    end)
    pcall(function() if item.GetSpellID then ids[#ids + 1] = item:GetSpellID() end end)
    pcall(function() if item.GetAuraSpellID then ids[#ids + 1] = item:GetAuraSpellID() end end)
    return ids
end

-- the seal an item tracks, if it tracks one: name, spell id
local function ItemSpell(item)
    for _, id in ipairs(ItemIDs(item)) do
        local n = SpellName(id)
        if n and IsSeal(n) then return n, id end
    end
end

-- the buff an item tracks: name, spell id (the first one with a readable name)
local function ItemBuff(item)
    for _, id in ipairs(ItemIDs(item)) do
        local n = SpellName(id)
        if n then return n, id end
    end
end

-- the icon the item shows (the aura's own), else the spell's
local function ItemIcon(item, id)
    local tex
    pcall(function()
        local icon = item.Icon
        if icon and not icon.GetTexture and icon.Icon then icon = icon.Icon end
        if icon and icon.GetTexture then
            local t = icon:GetTexture()
            if t and ns.Readable(t) then tex = t end
        end
    end)
    return tex or SpellIcon(id)
end

-- the stack count the item shows, as its own text (it may be hidden from addons, but can still be shown)
local function ItemCount(item)
    local fs
    pcall(function()
        fs = (item.Applications and item.Applications.Applications) or (item.Icon and item.Icon.Applications)
            or item.Applications
        if fs and not fs.GetText then fs = nil end
    end)
    if not fs then return nil end
    local ok, shown = pcall(fs.IsVisible, fs)
    if ok and ns.Readable(shown) and not shown then return nil end
    local ok2, text = pcall(fs.GetText, fs)
    if ok2 then return text end
end

-- does this item show its aura as up right now?
local function ItemActive(item)
    local active
    pcall(function()
        local aid = item.auraInstanceID
        if issecretvalue and issecretvalue(aid) then active = true return end
        if aid then active = true return end
        if item.IsActive then
            local a = item:IsActive()
            if ns.Readable(a) then active = a and true or false return end
        end
        if active == nil and item.auraInstanceID == nil and item.cooldownID then active = false end
    end)
    return active, item.auraInstanceID
end

-- returns: tracked (the Cooldown Manager has a seal entry), name, icon, auraInstanceID
function S.ManagerSeal()
    local tracked
    for _, vname in ipairs(VIEWERS) do
        local viewer = _G[vname]
        if type(viewer) == "table" and viewer.GetChildren then
            for _, item in ipairs(ItemFrames(viewer)) do
                local name, id = ItemSpell(item)
                if name then
                    tracked = true
                    local active, aid = ItemActive(item)
                    if active then return true, name, SpellIcon(id), aid end
                end
            end
        end
    end
    return tracked
end

-- seconds left on an aura, through the client's duration object. May come back hidden (secret);
-- then it can still be put on screen, just not used in math.
local function AuraLeft(aid)
    if not (aid and C_UnitAuras and C_UnitAuras.GetAuraDuration) then return nil end
    local ok, d = pcall(C_UnitAuras.GetAuraDuration, "player", aid)
    if not ok or not d then return nil end
    local ok2, left = pcall(function() return d:GetRemainingDuration() end)
    if ok2 and left ~= nil then return left end
end

-- name, icon, seconds left (nil when unknown), hidden, secret seconds left
local function ActiveSeal()
    if not S.paladin then return nil end

    local found, readable, total = nil, 0, 0
    pcall(function()
        for i = 1, 40 do
            local n, ic, duration, expires, spellId = BuffAt(i)
            if n == nil then break end
            total = total + 1
            if ns.Readable(n) then
                readable = readable + 1
                if IsSeal(n) then
                    duration, expires = Number(duration), Number(expires)
                    if duration and duration > 0 then durations[n] = duration end
                    found = { name = n, icon = ic, spellId = Number(spellId),
                              expires = (duration and duration > 0 and expires) or nil }
                    break
                end
            end
        end
    end)

    if not found then
        local name, icon = S.FormSeal()          -- some servers make seals a stance instead of a buff
        if name then found = { name = name, icon = icon } end
    end

    local combat = UnitAffectingCombat and UnitAffectingCombat("player")
    -- buffs only count as hidden when there are some and none can be read; with none at all the seal is gone
    -- in combat any unreadable buff (or an empty list) could be the seal, so don't conclude it is gone
    local hidden = combat and (readable < total or total == 0) and true or false
    local secretLeft

    if found then
        known = found
    else
        local tracked, mName, mIcon, aid = S.ManagerSeal()
        if tracked then
            -- the Cooldown Manager knows; trust it in and out of combat
            hidden = false
            if mName then
                if not (known and known.name == mName) then
                    known = { name = mName, icon = mIcon, expires = nil }
                end
                known.icon = known.icon or mIcon
                local left = AuraLeft(aid)
                if left ~= nil then
                    if ns.Readable(left) and type(left) == "number" then
                        if left > 0 then known.expires = GetTime() + left end
                    else
                        secretLeft = left
                    end
                end
            else
                known = nil
            end
        elseif known and known.cast and GetTime() - (known.castAt or 0) < 1.5 then
            -- just cast: the buff may not be in the list yet
        elseif known and combat and hidden then
            if known.expires and known.expires <= GetTime() then known = nil end
        else
            known = nil
        end
    end
    if not known then return nil, nil, nil, hidden end
    local left = known.expires and (known.expires - GetTime()) or nil
    if secretLeft ~= nil then left = nil end
    return known.name, known.icon, left, hidden, secretLeft
end

S.ActiveSeal = ActiveSeal

-- an active stance whose spell is a seal: name, icon
function S.FormSeal()
    if not (GetNumShapeshiftForms and GetShapeshiftFormInfo) then return nil end
    local found, icon
    pcall(function()
        for i = 1, GetNumShapeshiftForms() or 0 do
            local ic, active, _, spellID = GetShapeshiftFormInfo(i)
            if active then
                local n = SpellName(spellID)
                if IsSeal(n) then found, icon = n, ic break end
            end
        end
    end)
    return found, icon
end


-- ---------------------------------------------------------------------------------------------
-- every tracked buff that is up, in the Cooldown Manager's order (icons first, then bars)
local timers = {}     -- buff name -> when it runs out (GetTime), learned while the game lets us read it
local lengths = {}    -- buff name -> its full length, so casting it again restarts the countdown

local function SortedItems(viewer)
    local list = ItemFrames(viewer)
    pcall(table.sort, list, function(a, b)
        local x, y = a.layoutIndex or 0, b.layoutIndex or 0
        if x ~= y then return x < y end
        return (a.cooldownID or 0) < (b.cooldownID or 0)
    end)
    return list
end

local function TrackedBuffs()
    local list, seen = {}, {}
    for _, vname in ipairs(BUFF_VIEWERS) do
        local viewer = _G[vname]
        if type(viewer) == "table" and viewer.GetChildren then
            for _, item in ipairs(SortedItems(viewer)) do
                local name, id = ItemBuff(item)
                if name and not seen[name] then
                    local active, aid = ItemActive(item)
                    if active then
                        seen[name] = true
                        -- the Cooldown Manager can track every seal as one entry (named "Seals" or after one seal)
                        local isSeal = IsSeal(name) or ItemSpell(item) ~= nil or name == "Seals" or name == L["Seals"]
                        list[#list + 1] = { key = name, name = name, id = id, aid = aid, seal = isSeal or nil,
                                            icon = ItemIcon(item, id), count = ItemCount(item) }
                    end
                end
            end
        end
    end
    -- forget the countdowns of buffs that are gone
    for name in pairs(timers) do
        if not seen[name] then timers[name] = nil end
    end
    return list
end

-- fills in e.left (seconds, readable) or e.secret (a hidden number the game lets us print)
local function Timing(e)
    local now = GetTime()
    local left = AuraLeft(e.aid)
    if left ~= nil and ns.Readable(left) and type(left) == "number" then
        if left > 0 then
            timers[e.name] = now + left
            pcall(function()
                local d = C_UnitAuras.GetAuraDuration("player", e.aid)
                local total = d and d.GetTotalDuration and d:GetTotalDuration()
                if total and ns.Readable(total) and total > 0 then lengths[e.name] = total end
            end)
        else
            timers[e.name] = false        -- no time limit
        end
    elseif left ~= nil then
        e.secret = left
    end
    local t = timers[e.name]
    if t and t > now then
        e.left, e.secret = t - now, nil
    elseif t == false then
        e.secret = nil
    end
end

-- casting a tracked buff yourself restarts its countdown, even in combat
local function OnCast(spellID)
    local name = SpellName(spellID)
    if not name then return end
    if IsSeal(name) then
        local d = durations[name]
        known = { name = name, icon = SpellIcon(spellID), spellId = spellID,
                  expires = d and (GetTime() + d) or nil, cast = true, castAt = GetTime() }
    end
    if lengths[name] then timers[name] = GetTime() + lengths[name] end
end

-- everything the pills should show right now, top first
local function Entries()
    local list = {}
    if S.demoUntil then
        local left = S.demoUntil - GetTime()
        if left > 0 then
            list[1] = { key = "demo1", name = ns.ClientFeature("paladinSeals") and (SpellName(21084) or "Seal of Righteousness") or (SpellName(21562) or "Power Word: Fortitude"), icon = "Interface\\Icons\\Ability_ThunderBolt", left = left }
            list[2] = { key = "demo2", name = SpellName(19740) or "Blessing of Might", icon = "Interface\\Icons\\Spell_Holy_FistOfJustice", left = left + 262 }
            list[3] = { key = "demo3", name = SpellName(1243) or "Power Word: Fortitude", icon = "Interface\\Icons\\Spell_Holy_WordFortitude", left = left + 1505, count = nil }
            return list
        end
        S.demoUntil = nil
    end
    if not ns.db.sealPill then return list end

    local hasSeal = false
    for _, e in ipairs(TrackedBuffs()) do
        Timing(e)
        if e.seal then
            if hasSeal then e = nil else
                hasSeal = true
                -- one pill for the seal: the combined entry takes the name and icon of the seal that is up
                if S.paladin and not IsSeal(e.name) then
                    local name, icon = ActiveSeal()
                    if name then e.name, e.icon, e.key = name, icon or e.icon, name end
                end
            end
        end
        if e then list[#list + 1] = e end
    end

    -- paladins: their seal even when the Cooldown Manager doesn't track it, and a warning without one
    if ns.ClientFeature("paladinSeals") and S.paladin and not hasSeal then
        local name, icon, left, hidden, secretLeft = ActiveSeal()
        S.hidden = hidden
        local combat = UnitAffectingCombat and UnitAffectingCombat("player")
        if name then
            table.insert(list, 1, { key = name, name = name, icon = icon, left = left, secret = secretLeft })
        elseif combat and not hidden and ns.db.sealWarn ~= false then
            table.insert(list, 1, { key = "noseal", warn = true, name = L["No seal"] })
        end
    end
    while #list > MAX_PILLS do list[#list] = nil end
    return list
end

S.Entries = Entries

local function UnitFrame()
    for _, name in ipairs(UNIT_FRAMES) do
        local f = _G[name]
        if type(f) == "table" and f.IsShown and f:IsShown() then return f end
    end
end

-- ---------------------------------------------------------------------------------------------
-- the pills

-- repaint every live buff pill (the pill colour setting changed)
function S.Recolor()
    local sr, sg, sb = ns.ShellRGB()
    for _, f in pairs(S.pills) do f.body:SetColor(sr, sg, sb, 1) end
end

local function NewPill()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("BACKGROUND")       -- behind the unit frame, so it slides out from under it
    f:SetSize(120, H)
    f.body = ns.CreateBody(f, "BACKGROUND", 0)
    local sr, sg, sb = ns.ShellRGB()
    f.body:SetColor(sr, sg, sb, 1)
    f.body:SetRadius(H / 2)
    f.icon = ns.RoundIcon(f, 18)
    f.icon:SetPoint("LEFT", f, "LEFT", 6, 0)
    f.count = ns.Text(f, "extra", 9, C.fg, "RIGHT")
    f.count:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", 3, -2)
    f.name = ns.Text(f, "bold", 12, C.fg)
    f.name:SetPoint("LEFT", f, "LEFT", 30, 0)
    f.time = ns.Text(f, "bold", 12, C.muted, "RIGHT")
    f.time:SetPoint("RIGHT", f, "RIGHT", -11, 0)
    f.v, f.vel, f.target, f.slot, f.at = 0, 0, 0, 0, 0
    f:Hide()
    return f
end

local function Clock(left)
    if left >= 3600 then return string.format("%d:%02d:%02d", floor(left / 3600), floor(left % 3600 / 60), floor(left % 60)) end
    if left >= 60 then return string.format("%d:%02d", floor(left / 60), floor(left % 60)) end
    return L["%ds"]:format(max(0, floor(left + 0.5)))
end

local function Paint(f, e)
    if e.warn then
        f.icon:Hide()
        f.count:SetText("")
        f.name:SetPoint("LEFT", f, "LEFT", 12, 0)
        f.name:SetText(e.name)
        f.name:SetTextColor(RED[1], RED[2], RED[3])
        f.time:SetText("")
        f.timeW = 0
    else
        f.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        f.icon:Show()
        if e.count ~= nil then pcall(f.count.SetText, f.count, e.count) else f.count:SetText("") end
        f.name:SetPoint("LEFT", f, "LEFT", 30, 0)
        local shown = e.name
        if IsSeal(shown) then shown = shown:gsub("^Seal of the ", ""):gsub("^Seal of ", "") end
        f.name:SetText(shown)
        f.name:SetTextColor(C.fg[1], C.fg[2], C.fg[3])
        if e.secret ~= nil then
            -- a hidden timer: the game lets us print it, not do math with it
            local ok = pcall(f.time.SetFormattedText, f.time, L["%.0fs"], e.secret)
            if not ok then f.time:SetText("") end
            f.time:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
            f.timeW = ok and 30 or 0
        elseif e.left then
            local tc = e.left <= 5 and ORANGE or C.muted
            f.time:SetText(Clock(e.left))
            f.time:SetTextColor(tc[1], tc[2], tc[3])
            f.timeW = nil
        else
            f.time:SetText("")
            f.timeW = 0
        end
    end
    local timeW = f.timeW
    if timeW == nil then
        local ok, w = pcall(f.time.GetStringWidth, f.time)
        timeW = (ok and ns.Readable(w) and w) or 0
    end
    local left0 = f.icon:IsShown() and 30 or 12
    f:SetWidth(left0 + (f.name:GetStringWidth() or 60) + (timeW > 0 and (8 + timeW) or 0) + 12)
end

-- where pill f sits: v = 0 tucked behind the unit frame, 1 fully out; at = its place in the stack
local function Place(f)
    local e = min(1.1, max(0, f.v))
    local w = f:GetWidth() or 120
    local side = ns.db.sealSide or "below"
    local host = UnitFrame()
    local y = f.at * STEP
    f:ClearAllPoints()
    if not host then
        f:SetPoint("CENTER", UIParent, "CENTER", -220, -160 + 10 * (1 - e) - y)
    elseif side == "above" then
        f:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 0, -H + (H + GAP) * e + y)
    elseif side == "right" then
        f:SetPoint("TOPLEFT", host, "TOPRIGHT", -w + (w + GAP) * e, -y)
    elseif side == "left" then
        f:SetPoint("TOPRIGHT", host, "TOPLEFT", w - (w + GAP) * e, -y)
    else
        f:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, H - (H + GAP) * e - y)
    end
    f:SetAlpha(min(1, max(0, f.v * 1.4)))
end

function S:Build()
    if self.driver then return end
    self.driver = CreateFrame("Frame", nil, UIParent)
    self.driver:Hide()
    self.driver:SetScript("OnUpdate", function(_, dt) S:OnUpdate(dt) end)
end

function S:Refresh()
    if not self.driver then return end
    local list = Entries()
    local want = {}
    for i, e in ipairs(list) do
        local f = self.pills[e.key]
        if not f then
            -- reuse a pill that has gone away
            for key, old in pairs(self.pills) do
                if old.target == 0 and not old:IsShown() then
                    self.pills[key] = nil
                    f = old
                    break
                end
            end
            f = f or NewPill()
            f.v, f.vel, f.at = 0, 0, i - 1
            self.pills[e.key] = f
        end
        want[e.key] = true
        f.target, f.slot = 1, i - 1
        Paint(f, e)
        f:Show()
    end
    local any = #list > 0
    for key, f in pairs(self.pills) do
        if not want[key] then f.target = 0 end
        if f:IsShown() then any = true end
    end
    if any then self.driver:Show() end
end

function S:OnUpdate(dt)
    if not dt or dt <= 0 then return end
    if dt > 0.1 then dt = 0.1 end
    self.since = self.since + dt
    if self.since > 0.2 then          -- the countdowns
        self.since = 0
        self:Refresh()
    end
    -- a small spring so each pill pops out and settles, and slides to its place in the stack
    local n = max(1, math.ceil(dt * 120))
    local h = dt / n
    local busy = false
    for _, f in pairs(self.pills) do
        if f:IsShown() then
            for _ = 1, n do
                f.vel = f.vel + (-220 * (f.v - f.target) - 20 * f.vel) * h
                f.v = f.v + f.vel * h
            end
            f.at = f.at + (f.slot - f.at) * min(1, dt * 12)
            if f.target == 0 and f.v < 0.02 and abs(f.vel) < 0.2 then
                f.v, f.vel = 0, 0
                f:Hide()
            else
                busy = true
                Place(f)
            end
        end
    end
    if not busy then self.driver:Hide() end
end

-- the game's own buff icons and bars, see-through when the pills replace them (they keep working)
function S:ApplyHideBlizzard()
    local hide = ns.db and ns.db.sealPill and ns.db.buffHideBlizzard
    if not hide and not self.hidBlizzard then return end
    for _, vname in ipairs(BUFF_VIEWERS) do
        local viewer = _G[vname]
        if type(viewer) == "table" and viewer.SetAlpha then pcall(viewer.SetAlpha, viewer, hide and 0 or 1) end
    end
    self.hidBlizzard = hide or nil
end

-- called on aura and combat changes; the driver's own update only runs while a pill is out
function S:Check()
    if not ns.db then return end
    self:Build()
    self:ApplyHideBlizzard()
    self:Refresh()
end

function ns.DemoSeal()
    S.demoUntil = GetTime() + 15
    S:Build()
    S:Refresh()
end
ns.DemoBuffs = ns.DemoSeal

-- /island buffs debug: what the game reports, to see why a buff is or is not picked up
function S.Debug()
    local function say(text) ns.Print(text) end
    local _, class = UnitClass("player")
    say("class " .. tostring(class) .. ", buff pills " .. (ns.db.sealPill and "on" or "off") .. ", unit frame " .. tostring(UnitFrame() and UnitFrame():GetName() or "not found"))
    local foundViewer = false
    for _, vname in ipairs(VIEWERS) do
        local viewer = _G[vname]
        if type(viewer) == "table" and viewer.GetChildren then
            foundViewer = true
            local items = ItemFrames(viewer)
            say("cooldown manager " .. vname .. ": " .. #items .. " entries")
            for _, item in ipairs(items) do
                local n = ItemBuff(item)
                if n then say("  " .. n .. (ItemActive(item) and "  (up)" or "  (not up)") .. (IsSeal(n) and "  <- seal" or "")) end
            end
        end
    end
    if not foundViewer then say("cooldown manager: not found. Turn it on in the game's options.") end
    if S.paladin then
        for i = 1, 40 do
            local ok, name, _, duration = pcall(BuffAt, i)
            if not ok then say("buff " .. i .. ": could not be read (" .. tostring(name) .. ")") break end
            if not name then break end
            local okSeal, isSeal = pcall(IsSeal, name)
            if okSeal and isSeal then say("buff " .. i .. ": " .. tostring(name) .. "  (" .. tostring(duration) .. "s)  <- seal") end
        end
        if GetNumShapeshiftForms and GetShapeshiftFormInfo then
            for i = 1, GetNumShapeshiftForms() or 0 do
                local ok, _, active, _, spellID = pcall(GetShapeshiftFormInfo, i)
                if ok then
                    local n = SpellName(spellID)
                    if n and IsSeal(n) then say("stance " .. i .. ": " .. tostring(n) .. (active and "  (active)" or "")) end
                end
            end
        end
    end
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, unit, ...)
    if event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        S.paladin = class == "PALADIN"
        C_Timer.After(2, function() S:Check() end)
    elseif event == "UNIT_AURA" then
        if unit == "player" then S:Check() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" then
            local spellID = select(2, ...)
            pcall(OnCast, spellID)
            S:Check()
        end
    else
        S:Check()
    end
end)
for _, event in ipairs({ "PLAYER_LOGIN", "UNIT_AURA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                         "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "COOLDOWN_VIEWER_DATA_LOADED" }) do
    pcall(ev.RegisterEvent, ev, event)
end
pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player")
