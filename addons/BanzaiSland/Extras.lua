-- Island: smaller cards. Quest objective progress, skill ups, whispers, rare mobs, auctions, calendar.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local I, C = ns.Island, ns.C

local GREEN = { 0.36, 0.85, 0.45 }
local RED = { 0.95, 0.38, 0.38 }
local PINK = { 1.00, 0.55, 0.95 }
local SILVER = { 0.78, 0.84, 0.96 }
local GOLD = C.gold
local MUTED_HEX = ns.Hex(C.muted[1], C.muted[2], C.muted[3])

-- ---------------------------------------------------------------- quest objectives

-- "Kobold Vermin slain: 3/8", and the finished form "Kobold Vermin slain: 8/8 (Complete)",
-- whose wording comes from the game so other languages work too. Also used by Quiet.lua.
local doneSuffix
function ns.ParseProgress(msg)
    if not ns.Readable(msg) or type(msg) ~= "string" then return end
    if not doneSuffix then
        doneSuffix = {}
        local fmt = _G.ERR_QUEST_OBJECTIVE_COMPLETE_S
        if type(fmt) == "string" and fmt:find("%s", 1, true) then
            local a, b = fmt:match("^(.-)%%s(.*)$")
            doneSuffix[#doneSuffix + 1] = { a or "", b or "" }
        end
        doneSuffix[#doneSuffix + 1] = { "", " (Complete)" }
    end
    local core = msg
    for _, d in ipairs(doneSuffix) do
        local a, b = d[1], d[2]
        if #core > #a + #b and core:sub(1, #a) == a and (b == "" or core:sub(-#b) == b) then
            core = core:sub(#a + 1, #core - #b)
            break
        end
    end
    local name, have, need = core:match("^(.-):%s*(%d+)%s*/%s*(%d+)$")
    if not name or name == "" then return end
    return name, tonumber(have), tonumber(need)
end

-- the bare "Objective Complete." line some objectives give instead
function ns.IsObjectiveDone(msg)
    if not ns.Readable(msg) or type(msg) ~= "string" then return false end
    local s = _G.ERR_QUEST_UNKNOWN_COMPLETE
    return (type(s) == "string" and msg == s) or msg == "Objective Complete."
end

local function OnInfoMessage(msg)
    if not ns.Readable(msg) then return end      -- the game hides some chat text from addons in combat
    if not ns.db.showQuestProgress or type(msg) ~= "string" then return end
    local name, have, need = ns.ParseProgress(msg)
    if not name then return end
    local done = have >= need
    I:PushReplace({
        kind = "won", key = "questprogress", transient = true, priority = 0, glyph = "Check",
        tone = done and GREEN or C.quest, cap = done and L["OBJECTIVE COMPLETE"] or L["QUEST"], capColor = done and GREEN or C.quest,
        title = name, color = C.fg, res = have .. " / " .. need, resColor = done and GREEN or C.fg, hold = done and 2.4 or 1.8,
    })
end

-- ---------------------------------------------------------------- skill ups

local skillUp

local function OnSkillMessage(msg)
    if not ns.Readable(msg) then return end      -- the game hides some chat text from addons in combat
    if not ns.db.showSkillUps or not skillUp or type(msg) ~= "string" then return end
    local name, value = msg:match(skillUp)
    if not name or not tonumber(value) then return end
    I:PushReplace({
        kind = "won", key = "skill", transient = true, priority = 0, glyph = "Plus", tone = GREEN, cap = L["SKILL UP"],
        capColor = GREEN, title = name, color = C.fg, res = value, hold = 2,
    })
end

-- ---------------------------------------------------------------- whispers

-- Pigeon (the chat addon) is used when it is installed: the card takes its name and class color,
-- shows the unread count, opens the conversation when clicked, and stands in for Pigeon's own
-- preview bubble so a whisper is announced once.
local function Pigeon()
    local api = ns.db.usePigeon and _G.PigeonAPI
    if type(api) == "table" and type(api.Info) == "function" and type(api.Open) == "function" then return api end
end

function ns.ApplyPigeon()
    local api = _G.PigeonAPI
    if type(api) ~= "table" then return end
    api.externalPreview = (ns.db.usePigeon and ns.db.showWhispers) and true or false
end

local function ShowWhisper(text, sender, guid, bnID)
    local api = Pigeon()
    local info = api and api.Info(sender, guid, bnID)
    if info and info.viewing then return end          -- already reading that conversation in Pigeon
    local name = bnID and sender or (ns.ShowName(sender) or sender)
    local color = C.fg
    if info then
        name = info.name or name
        if info.r then color = { info.r, info.g, info.b } end
    elseif guid and GetPlayerInfoByGUID then
        local _, class = GetPlayerInfoByGUID(guid)
        local c = class and ns.Theme and ns.Theme.ClassScreen and ns.Theme.ClassScreen(class) -- BanzaiSland 0.3.0
        if c then color = c end
    end
    local body = text
    if #body > 110 then body = body:sub(1, 107) .. "..." end
    local unread = info and info.unread or 0
    I:PushReplace({
        kind = "won", catchUpCategory = "whispers", key = "whisper:" .. tostring(bnID or sender), priority = 2, glyph = "Chat", tone = PINK,
        cap = api and L["WHISPER   CLICK TO REPLY"] or L["WHISPER"], capColor = PINK, title = name, color = color,
        res = unread > 1 and L["%d new"]:format(unread) or "", resColor = PINK, line = body, hold = 4.5,
        sound = (not api) and 3081 or nil,      -- Pigeon plays its own sound
        urgent = api and true or nil,           -- it replaces Pigeon's preview, which also shows in combat
        onClick = api and function() api.Open(sender, guid, bnID) end or nil,
    })
end

local function OnWhisper(text, sender, guid, bnID)
    if not ns.Readable(text) or not ns.Readable(sender) then return end      -- the game hides some chat text from addons in combat
    if ns.CatchUp and type(sender) == "string" and type(text) == "string" then
        ns.CatchUp.Record("whispers", tostring(type(bnID) == "number" and bnID > 0 and bnID or sender), L["Whisper from %s"]:format(ns.ShowName(sender) or sender), text,
            {glyph="Chat", sender=sender, guid=guid, bnID=bnID})
    end
    if not ns.db.showWhispers then return end
    -- a short wait lets Pigeon file the message first, so its unread count is right
    C_Timer.After(0.05, function() pcall(ShowWhisper, text, sender, guid, bnID) end)
end

-- ---------------------------------------------------------------- rare mobs

local seenRare = {}

-- opts: key (what to throttle on), cap, glyph, tone, sound
local function RareCard(name, line, opts)
    opts = opts or {}
    if not name or name == "" or (not opts.force and not ns.db.showRares) then return end
    local key, now = opts.key or name, GetTime()
    if (seenRare[key] and now - seenRare[key] < 300) or (seenRare[name] and now - seenRare[name] < 300) then return end
    seenRare[key], seenRare[name] = now, now
    local tone = opts.tone or SILVER
    local sound = 8959
    if opts.sound == false then sound = nil end
    I:Push({ group = "world",
        kind = "won", urgent = true, priority = 3, glyph = opts.glyph or "Star", tone = tone,
        builderType = "rare",
        cap = opts.cap or L["RARE SPOTTED"], capColor = tone, title = name, color = C.fg, res = opts.res or "",
        line = line and (MUTED_HEX .. line .. "|r") or nil, flash = tone, hold = 4, sound = sound,
        -- where it is: RareScanner's spot, or where you are standing when you see it yourself
        waypoint = opts.waypoint or (ns.Nav and ns.Nav.Here and ns.Nav.Here()),
    })
end

local function CheckUnit(unit)
    if not ns.db.showRares or not unit or not UnitExists or not UnitExists(unit) then return end
    local ok = pcall(function()
        local class = UnitClassification(unit)
        if not ns.Readable(class) then return end
        if class ~= "rare" and class ~= "rareelite" then return end
        if UnitIsDead(unit) then return end
        local level = UnitLevel(unit)
        local line = (class == "rareelite" and L["Level %s Rare Elite"] or L["Level %s Rare"]):format((level and level > 0) and level or "??")
        local uname = UnitName(unit)
        if not ns.Readable(uname) then return end
        RareCard(uname, line)
    end)
    return ok
end

local function OnVignette(id)
    if not ns.db.showRares or not id or not (C_VignetteInfo and C_VignetteInfo.GetVignetteInfo) then return end
    local ok, info = pcall(C_VignetteInfo.GetVignetteInfo, id)
    if not ok or type(info) ~= "table" or not info.name then return end
    local atlas = type(info.atlasName) == "string" and info.atlasName:lower() or ""
    if atlas:find("rare", 1, true) or atlas:find("vignettekill", 1, true) then
        RareCard(info.name, L["On your minimap"])
    end
end

-- ---------------------------------------------------------------- RareScanner

-- When the RareScanner addon is installed, its alerts (rares, treasures and events it finds on
-- the minimap) show as island cards too. Nothing of RareScanner's is changed: its own button,
-- sound and chat message keep working, and it still decides what is worth alerting on.
local rsHooked = false

local function RareScannerKind(atlas)
    atlas = type(atlas) == "string" and atlas:lower() or ""
    if atlas:find("loot", 1, true) then return L["TREASURE SPOTTED"], "Bag", GOLD end
    if atlas:find("event", 1, true) then return L["EVENT SPOTTED"], "Flag", GREEN end
    return L["RARE SPOTTED"], "Star", SILVER
end

local function RareScannerWhere(mapID, x, y)
    local parts = {}
    if mapID and C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and type(info) == "table" and info.name then parts[#parts + 1] = info.name end
    end
    if type(x) == "number" and type(y) == "number" and x > 0 and y > 0 then
        if x <= 1 and y <= 1 then x, y = x * 100, y * 100 elseif x > 100 or y > 100 then x, y = x / 100, y / 100 end
        parts[#parts + 1] = string.format("%.1f, %.1f", x, y)
    end
    return #parts > 0 and table.concat(parts, "   ") or nil
end

local function RareScannerCard(button, entityID, name)
    if not ns.db.useRareScanner or not name or name == "" then return end
    local cap, glyph, tone, where, wp
    -- the button carries the details once RareScanner has filled it in for this find
    if button and button.entityID == entityID then
        cap, glyph, tone = RareScannerKind(button.atlasName)
        where = RareScannerWhere(button.mapID, button.x, button.y)
        if button.mapID and type(button.x) == "number" and type(button.y) == "number" and button.x > 0 then
            wp = { map = button.mapID, x = button.x, y = button.y }
        end
    else
        cap, glyph, tone = RareScannerKind(nil)
    end
    RareCard(name, where, { key = "rs:" .. tostring(entityID), cap = cap, glyph = glyph, tone = tone, sound = false, force = true, waypoint = wp })
end

local function HookRareScanner()
    if rsHooked then return end
    local button = _G.RARESCANNER_BUTTON
    if type(button) ~= "table" or not hooksecurefunc then return end
    rsHooked = true
    if type(button.ShowButton) == "function" then
        hooksecurefunc(button, "ShowButton", function(self)
            pcall(RareScannerCard, self, self.entityID, self.name)
        end)
    end
    if type(button.DisplayMessages) == "function" then
        -- also called when RareScanner's button is turned off or held back by combat;
        -- wait a moment so the button path, which knows more, gets to go first
        hooksecurefunc(button, "DisplayMessages", function(self, entityID, name)
            C_Timer.After(0.3, function() pcall(RareScannerCard, self, entityID, name) end)
        end)
    end
end
ns.HookRareScanner = HookRareScanner

-- ---------------------------------------------------------------- auctions and calendar

local auction = {}
local lastInvites = 0

local function OnSystemMessage(msg)
    if not ns.Readable(msg) then return end      -- the game hides some chat text from addons in combat
    if type(msg) ~= "string" then return end
    for _, a in ipairs(auction) do
        local item = msg:match(a.pattern)
        if item then
            if ns.CatchUp then ns.CatchUp.Record("auctions", a.event, a.title, item:match("%[(.-)%]") or item, {glyph="Coin"}) end
            if not ns.db.toastAuction then return end
            I:Push({ group = "loot", catchUpCategory = "auctions",
                kind = "won", glyph = "Coin", tone = a.tone, cap = a.cap, capColor = a.tone,
                title = (item:match("%[(.-)%]") or item), color = C.fg, res = "", hold = 3.2, priority = 2,
            })
            return
        end
    end
end

local function CheckCalendar()
    if not (C_Calendar and C_Calendar.GetNumPendingInvites) then return end
    local ok, n = pcall(C_Calendar.GetNumPendingInvites)
    if not ok or type(n) ~= "number" then return end
    if n > lastInvites and ns.db.alertCalendar then
        I:Push({
            kind = "won", glyph = "Clock", tone = GOLD, cap = L["CALENDAR"], capColor = GOLD, color = C.fg,
            title = (n == 1 and L["%d pending invite"] or L["%d pending invites"]):format(n), res = "", hold = 3.2,
        })
    end
    lastInvites = n
end

-- ---------------------------------------------------------------- demo

function ns.DemoExtras()
    if not I.built then return end
    I:Push({ kind = "won", glyph = "Check", tone = C.quest, cap = L["QUEST"], capColor = C.quest, title = "Bloodscalp Tusk",
             color = C.fg, res = "7 / 10", hold = 1.8, transient = true })
    I:Push({ kind = "won", glyph = "Plus", tone = GREEN, cap = L["SKILL UP"], capColor = GREEN, title = "Mining",
             color = C.fg, res = "142", hold = 2, transient = true })
    I:Push({ kind = "won", glyph = "Chat", tone = PINK, cap = L["WHISPER"], capColor = PINK, title = "Thrall", color = { 0, 0.44, 0.87 },
             res = "", line = "You around for Zul'Farrak later? We need one more.", hold = 4 })
    I:Push({ kind = "won", builderType = "rare", glyph = "Star", tone = SILVER, cap = L["RARE SPOTTED"], capColor = SILVER, title = "Mosh'Ogg Butcher",
             color = C.fg, res = "", line = MUTED_HEX .. L["Level %s Rare Elite"]:format(44) .. "|r", flash = SILVER, hold = 3.4 })
    I:Push({ kind = "won", glyph = "Coin", tone = GOLD, cap = L["AUCTION SOLD"], capColor = GOLD, title = "Heavy Leather",
             color = C.fg, res = "", hold = 3 })
end

-- ---------------------------------------------------------------- events

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, a, b, ...)
    if event == "PLAYER_LOGIN" then
        skillUp = ns.Compile(ERR_SKILL_UP_SI, true)
        local defs = {
            { "ERR_AUCTION_SOLD_S", L["AUCTION SOLD"], GOLD, L["Auction sold"] }, { "ERR_AUCTION_OUTBID_S", L["OUTBID"], RED, L["Auction outbid"] },
            { "ERR_AUCTION_WON_S", L["AUCTION WON"], GREEN, L["Auction won"] }, { "ERR_AUCTION_EXPIRED_S", L["AUCTION EXPIRED"], C.muted, L["Auction expired"] },
        }
        for _, def in ipairs(defs) do
            local pattern = ns.Compile(_G[def[1]], true)
            if pattern then auction[#auction + 1] = { pattern = pattern, cap = def[2], tone = def[3], event = def[1], title = def[4] } end
        end
        C_Timer.After(8, CheckCalendar)
        HookRareScanner()
        ns.ApplyPigeon()
    elseif event == "ADDON_LOADED" then
        if a == "RareScanner" then HookRareScanner() end
        if a == "Pigeon" and ns.db then ns.ApplyPigeon() end
    elseif event == "UI_INFO_MESSAGE" then
        OnInfoMessage(type(b) == "string" and b or a)
    elseif event == "CHAT_MSG_SKILL" then
        OnSkillMessage(a)
    elseif event == "CHAT_MSG_WHISPER" then
        OnWhisper(a, b, (select(10, ...)), nil)
    elseif event == "CHAT_MSG_BN_WHISPER" then
        OnWhisper(a, b, nil, (select(11, ...)) or 0)
    elseif event == "PLAYER_TARGET_CHANGED" then
        CheckUnit("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        CheckUnit("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        CheckUnit(a)
    elseif event == "VIGNETTE_MINIMAP_UPDATED" then
        OnVignette(a)
    elseif event == "CHAT_MSG_SYSTEM" then
        OnSystemMessage(a)
    elseif event == "CALENDAR_UPDATE_PENDING_INVITES" then
        CheckCalendar()
    end
end)
for _, event in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "UI_INFO_MESSAGE", "CHAT_MSG_SKILL", "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER",
                         "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED",
                         "VIGNETTE_MINIMAP_UPDATED", "CHAT_MSG_SYSTEM", "CALENDAR_UPDATE_PENDING_INVITES" }) do
    pcall(ev.RegisterEvent, ev, event)
end

-- On this client the game's proc-glow overlay (SpellActivationOverlayFrame, the big frame in the
-- middle of the screen that shows spell alerts) can end up catching mouse clicks, leaving a dead
-- spot in the middle of the screen. It is only ever a picture, so keep it click-through.
do
    local busy
    local function ClickThrough()
        local f = _G.SpellActivationOverlayFrame
        if type(f) ~= "table" or not f.EnableMouse or busy then return end
        busy = true
        pcall(f.EnableMouse, f, false)
        if f.SetMouseClickEnabled then pcall(f.SetMouseClickEnabled, f, false) end
        if f.SetMouseMotionEnabled then pcall(f.SetMouseMotionEnabled, f, false) end
        busy = false
    end
    local fix = CreateFrame("Frame")
    fix:RegisterEvent("PLAYER_LOGIN")
    fix:RegisterEvent("PLAYER_ENTERING_WORLD")
    fix:SetScript("OnEvent", function(self, event)
        ClickThrough()
        local f = _G.SpellActivationOverlayFrame
        if event == "PLAYER_LOGIN" and type(f) == "table" and hooksecurefunc then
            -- if the game turns it back on later, turn it straight back off
            for _, m in ipairs({ "EnableMouse", "SetMouseClickEnabled", "SetMouseMotionEnabled" }) do
                if f[m] then hooksecurefunc(f, m, function(_, on) if on then ClickThrough() end end) end
            end
        end
    end)
end

-- ---------------------------------------------------------------- minimap button
-- A small round button on the minimap's edge: click for settings, right-click for the shelf, drag to move.
do
    local btn
    local function Place()
        if not (btn and Minimap and ns.db) then return end
        local angle = math.rad(ns.db.minimapAngle or 215)
        local x, y = math.cos(angle), math.sin(angle)
        local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
        local r = Minimap:GetWidth() / 2 + 5
        if shape == "SQUARE" then
            local q = math.max(math.abs(x), math.abs(y))
            if q > 0 then x, y = x / q, y / q end
        end
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
    end
    local function Build()
        if btn or not Minimap then return end
        btn = CreateFrame("Button", "BanzaiSlandMinimapButton", Minimap)
        btn:SetSize(31, 31)
        btn:SetFrameStrata("MEDIUM")
        btn:SetFrameLevel(8)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:RegisterForDrag("LeftButton")
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetSize(20, 20)
        bg:SetPoint("CENTER", btn, "CENTER", 0, 0)
        bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        icon:SetTexture("Interface\\AddOns\\BanzaiSland\\Media\\Icon")
        local border = btn:CreateTexture(nil, "OVERLAY")
        border:SetSize(53, 53)
        border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        btn:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                if ns.Shelf and ns.Shelf.Toggle then ns.Shelf.Toggle() end
            elseif ns.ToggleSettings then
                ns.ToggleSettings()
            end
        end)
        btn:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("BanzaiSland", 1, 1, 1)
            GameTooltip:AddLine(L["Click: settings"], 0.8, 0.8, 0.8)
            GameTooltip:AddLine(L["Right-click: shelf"], 0.8, 0.8, 0.8)
            GameTooltip:AddLine(L["Drag: move this button"], 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        btn:SetScript("OnDragStart", function(self)
            self:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local scale = Minimap:GetEffectiveScale()
                local cx, cy = GetCursorPosition()
                if not (mx and cx) then return end
                ns.db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
                Place()
            end)
        end)
        btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
        ns.MinimapButton = btn
    end
    function ns.ApplyMinimapButton()
        if not ns.db then return end
        if ns.db.minimapButton == false then
            if btn then btn:Hide() end
            return
        end
        Build()
        if btn then Place() btn:Show() end
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function() ns.ApplyMinimapButton() end)
end
