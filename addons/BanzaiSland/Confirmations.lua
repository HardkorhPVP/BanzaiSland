-- Island: mirror known two-button questions, leaving the game's actions and warning text intact.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L, I, C, UI = ns.L, ns.Island, ns.C, ns.PopupCard
local known = {
    REPLACE_TRADESKILL_ENCHANT = { "Plus", L["Replace enchant?"] },
    REPLACE_ENCHANT = { "Plus", L["Replace enchant?"] },
    TRADE_REPLACE_ENCHANT = { "Plus", L["Replace trade enchant?"] },
    BIND_ENCHANT = { "Plus", L["Bind this item?"] },
    ACTION_WILL_BIND_ITEM = { "Bag", L["Bind this item?"] },
    TRADE_POTENTIAL_BIND_ENCHANT = { "Plus", L["Enchant this trade item?"] },
    END_BOUND_TRADEABLE = { "Bag", L["End item trading?"] },
    CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL = { "Coin", L["Sell this tradeable item?"] },
    CONFIRM_ACCEPT_SOCKETS = { "Ore", L["Apply these gems?"] },
    CONFIRM_RESET_INSTANCES = { "Door", L["Reset instances?"] },
    UNLEARN_SKILL = { "Alert", L["Unlearn this profession?"] },
    UNLEARN_SPECIALIZATION = { "Alert", L["Unlearn this specialization?"] },
}
local active = {}
local hooked = {}
local PURPLE = { 0.72, 0.52, 1.00 }

-- The forced layer change ("The world around you will refresh in 28 Minutes"). Its popup key is not
-- known, so it is recognised by its key or its wording, and the countdown is kept here.
local Text
local IsRefreshPopup
local refresh                      -- { ends, total, warned = { [15]=true ... } }
local function IsShardKey(which) return type(which) == "string" and which:find("^SHARD_TRANSFER") and true or false end
local function RefreshSecs(text, anyText)
    if type(text) ~= "string" then return end
    if not anyText and not text:lower():find("refresh") then return end
    local total, found = 0, false
    for n, unit in text:gmatch("(%d+)%s*(%a+)") do
        unit = unit:lower()
        if unit:find("^min") then total, found = total + n * 60, true
        elseif unit:find("^sec") then total, found = total + n, true
        elseif unit:find("^hour") then total, found = total + n * 3600, true end
    end
    return found and total or nil
end
local function Left(secs)
    secs = math.max(0, math.floor(secs + 0.5))
    if secs >= 3600 then return ("%d:%02d:%02d"):format(secs / 3600, secs % 3600 / 60, secs % 60) end
    return ("%d:%02d"):format(secs / 60, secs % 60)
end
local function Words(secs)
    local m = math.max(1, math.floor(secs / 60 + 0.5))
    return m == 1 and L["1 minute"] or L["%d minutes"]:format(m)
end
local function ClearRefresh()
    if not refresh then return end
    refresh = nil
    I:SetActivity("refresh", nil)
    local corner = _G.ShardTransferImminentFrame
    if corner and corner.SetAlpha then pcall(corner.SetAlpha, corner, 1) end
end
local function RefreshLine()
    return L["The world refreshes in %s. Be out of combat and somewhere safe."]:format(Words(refresh and (refresh.ends - GetTime()) or 0))
end
local function OpenOriginal()
    -- bring the game's own popup back, then the card is made from it again
    local dialogs = _G.StaticPopupDialogs
    if type(dialogs) == "table" and dialogs.SHARD_TRANSFER_IMMEDIATE and StaticPopup_Show then
        -- the game's own "Refresh the world now." question: what clicking its notice opens
        pcall(StaticPopup_Show, "SHARD_TRANSFER_IMMEDIATE")
        return
    end
    local corner = _G.ShardTransferImminentMinimizeButton
    if corner and corner.Click then pcall(corner.Click, corner) end
    -- if clicking did nothing, ask the game for its own world refresh dialog by name
    C_Timer.After(0.4, function()
        for i = 1, 4 do
            local f = _G["StaticPopup" .. i]
            if f and f:IsShown() and IsRefreshPopup(f) then return end
        end
        local dialogs = _G.StaticPopupDialogs
        if type(dialogs) ~= "table" or not StaticPopup_Show then return end
        local left = refresh and math.max(60, refresh.ends - GetTime()) or 1800
        local when = _G.SecondsToTime and _G.SecondsToTime(left) or Words(left)
        -- recognised by what it says, never by its name
        for key, def in pairs(dialogs) do
            local text = type(def) == "table" and type(def.text) == "string" and def.text:lower() or ""
            if text:find("world") and text:find("refresh") then
                pcall(StaticPopup_Show, key, when)
                return
            end
        end
    end)
end
local function SetRefresh(secs, recapture, announce)
    if not (ns.db and ns.db.promptRefresh ~= false) then return end
    local first = not refresh
    if first then refresh = { warned = {} } end
    refresh.ends, refresh.total = GetTime() + secs, math.max(secs, refresh.total or 0)
    I:SetActivity("refresh", { glyph = "Clock", tone = PURPLE, priority = 6, tip = L["Layer change"],
        tip2 = L["Forced layer change. The world refreshes when this reaches zero."],
        text = function() return Left(refresh and (refresh.ends - GetTime()) or 0) end,
        native = true, noEase = true, extPin = true,
        click = function() recapture() end, clickHint = L["Click: Refresh now / Okay"],
        progress = function()
            if not refresh or refresh.total <= 0 then return 0 end
            return math.max(0, math.min(1, (refresh.ends - GetTime()) / refresh.total))
        end })
    if first and announce then
        I:Push({ kind = "won", glyph = "Clock", tone = PURPLE, cap = L["LAYER CHANGE"], capColor = PURPLE,
                 title = L["World refresh in %s"]:format(Words(secs)), color = C.fg, res = "", hold = 4 })
    end
    if ns.db.hideBlizzardPopups then
        local corner = _G.ShardTransferImminentFrame
        if corner and corner.SetAlpha then pcall(corner.SetAlpha, corner, 0) end
    end
end
local serial = 0
local function Combat() return InCombatLockdown and InCombatLockdown() end
local function Enabled() return ns.db and ns.db.promptConfirmations ~= false end
IsRefreshPopup = function(f)
    return f and (IsShardKey(f.which) or RefreshSecs(Text(f.text or f.Text))) and true or false
end
Text = function(widget)
    if not (widget and widget.GetText) then return end
    local ok, value = pcall(widget.GetText, widget)
    if ok and ns.Readable(value) and type(value) == "string" and value ~= "" then return value end
end
local function Visible(entry)
    local f = entry.frame
    return f.which == entry.which and f:IsShown()
end
local function Restore(entry)
    UI.Restore(entry.frame)
    if entry.extras then
        for f in pairs(entry.extras) do UI.Restore(f) end
        entry.extras = nil
    end
end
local function Remove(entry)
    if active[entry.frame] ~= entry then return end
    active[entry.frame] = nil
    I:RemoveRoll(entry.id, true)
    Restore(entry)
end

local function Simple(frame, which)
    local def = StaticPopupDialogs and StaticPopupDialogs[which]
    if not def then return false end
    -- These controls carry information or consent that a pair of buttons cannot reproduce.
    for _, key in ipairs({ "hasEditBox", "hasMoneyFrame", "hasMoneyInputFrame", "hasItemFrame", "hasCheckBox" }) do
        if def[key] and def[key] ~= 0 then return false end
    end
    for i = 3, 4 do
        local b = UI.Button(frame, i)
        if b and b:IsShown() then return false end
    end
    for i = 1, 2 do
        local b = UI.Button(frame, i)
        -- the world refresh question has only one button (Refresh Now)
        if not (b and b:IsShown() and Text(b)) and not (i == 2 and IsShardKey(which)) then return false end
    end
    return Text(frame.text or frame.Text) ~= nil
end

local function Sync(entry)
    if entry.refresh and Visible(entry) then
        local s = RefreshSecs(Text(entry.frame.text or entry.frame.Text), IsShardKey(entry.which))
        if s then SetRefresh(s, entry.recapture) end
        entry.prompt.line = RefreshLine()
    end
    if not Visible(entry) then Remove(entry) return end
    if Combat() then return end
    if not Enabled() or not Simple(entry.frame, entry.which) then Remove(entry) return end
    local changed = false
    local line = entry.refresh and RefreshLine() or Text(entry.frame.text or entry.frame.Text)
    if line ~= entry.prompt.line then entry.prompt.line, changed = line, true end
    local two = entry.prompt.buttons[2]
    if two and two.virtual and entry.makeSpec then
        local b2 = UI.Button(entry.frame, 2)
        if b2 and b2:IsShown() and Text(b2) then
            entry.prompt.buttons[2] = entry.makeSpec(2)
            changed = true
        end
    end
    for i, spec in ipairs(entry.prompt.buttons) do
        local b = not spec.virtual and UI.Button(entry.frame, i)
        if b then
            local enabled = not b.IsEnabled or b:IsEnabled()
            local label = Text(b)
            if spec.enabled ~= enabled or spec.label ~= label then
                spec.enabled, spec.label, changed = enabled, label, true
            end
        end
    end
    if I.rolls[1] ~= entry.prompt or I.state ~= "roll" then Restore(entry) return end
    if changed then I:FillRoll() end
    -- Keep long warnings in the original dialog rather than clipping away their details.
    local names = I.rl and I.rl.names
    if names and names.GetStringHeight and names:GetStringHeight() > 74 then Remove(entry) return end
    local armed = true
    local layer = entry.refresh or entry.which == "SHARD_TRANSFER_IMMEDIATE"
    for i, spec in ipairs(entry.prompt.buttons) do
        -- on a layer change card only Refresh Now has to be armed; the second button is just "Not now"
        if spec.enabled and not spec.armed and not (layer and i > 1) then armed = false end
    end
    if armed and ns.db.hideBlizzardPopups then
        UI.Hide(entry.frame)
        -- the game can put a window back in view by itself (a refresh of its text, a fade): hide it again
        local a = entry.frame.GetAlpha and entry.frame:GetAlpha()
        if type(a) == "number" and a > 0.01 then
            UI.Restore(entry.frame) UI.Hide(entry.frame)
            local after = entry.frame:GetAlpha()
            if type(after) == "number" and after > 0.01 and not entry.warnedAlpha then
                entry.warnedAlpha = true
                ns.Print(string.format("BanzaiSland: the game keeps showing its %s window (alpha %s, effective %s). Send this line.",
                    tostring(entry.which), tostring(after), tostring(entry.frame.GetEffectiveAlpha and entry.frame:GetEffectiveAlpha())))
            end
        end
    else
        Restore(entry)
    end
end

local Capture
Capture = function(which)
    if not (Enabled() and I.built) or Combat() then return end
    local frame = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
    if not frame then return end
    local immediate = which == "SHARD_TRANSFER_IMMEDIATE"      -- "Refresh the world now."
    local rsecs = not known[which] and not immediate and RefreshSecs(Text(frame.text or frame.Text))
    if not rsecs and not immediate and IsShardKey(which) then
        -- the game's own shard transfer warning, whatever its wording: take the time from it, or from what is kept
        rsecs = RefreshSecs(Text(frame.text or frame.Text), true) or (refresh and math.max(1, refresh.ends - GetTime())) or 60
    end
    if not (known[which] or rsecs or immediate) then return end
    if (rsecs or immediate) and ns.db.promptRefresh == false then return end
    if not Simple(frame, which) then return end
    local previous = active[frame]
    if previous then
        if previous.which == which then Sync(previous) return end
        Remove(previous)
    end
    serial = serial + 1
    local entry = { frame = frame, which = which, id = "confirmation" .. serial }
    local info = known[which] or (immediate and { "Clock", L["Refresh the world now?"] }) or { "Clock", L["World refresh"] }
    if immediate then
        entry.recapture = function()
            if StaticPopup_FindVisible and StaticPopup_FindVisible(which) then Capture(which) else OpenOriginal() end
        end
    end
    if rsecs then
        entry.refresh = true
        entry.recapture = function()
            if StaticPopup_FindVisible and StaticPopup_FindVisible(which) then Capture(which) else OpenOriginal() end
        end
        SetRefresh(rsecs, entry.recapture)
    end
    local prompt = {
        id = entry.id, front = true, glyph = info[1], tone = (rsecs or immediate) and PURPLE or C.gold,
        cap = (rsecs or immediate) and L["LAYER CHANGE"] or L["CONFIRMATION"],
        name = info[2], line = rsecs and RefreshLine() or Text(frame.text or frame.Text), noTimer = true, fullWarning = true, buttons = {},
        onRemoved = function()
            if active[frame] == entry then active[frame] = nil end
            Restore(entry)
        end,
    }
    entry.prompt = prompt
    active[frame] = entry
    if not hooked[frame] and frame.HookScript then
        hooked[frame] = true
        frame:HookScript("OnHide", function()
            local old = active[frame]
            if not old then return end
            -- A popup frame can be reused for another question before the next update.
            if I.rolls[1] == old.prompt then I:DisarmSecure() end
            -- Let the secure button's PostClick finish before changing the current card.
            C_Timer.After(0, function() Remove(old) end)
        end)
    end
    local function MakeSpec(index)
        local button = UI.Button(frame, index)
        local spec = { label = Text(button), enabled = not button.IsEnabled or button:IsEnabled(), muted = index == 2, keep = true }
        spec.secure = function()
            if not Visible(entry) then return end
            local b = UI.Button(frame, index)
            if b and b:IsShown() and (not b.IsEnabled or b:IsEnabled()) then return b end
        end
        -- The secure overlay clicks the original button. Never call its OnAccept ourselves.
        -- Keep the card until the original dialog closes; some questions update in place.
        spec.fn = function()
            if not spec.armed then Restore(entry) return end
            if index == 1 and (entry.refresh or immediate) then
                -- the world refresh: check the game took the press; if its window is still up, press its button directly
                C_Timer.After(0.4, function()
                    -- the game took it: the countdown is over
                    if not Visible(entry) then ClearRefresh() return end
                    local b = UI.Button(frame, 1)
                    if b and b.Click then pcall(b.Click, b) end
                    C_Timer.After(0.4, function()
                        if not Visible(entry) then ClearRefresh() return end
                        if Visible(entry) then
                            ns.Print(L["The game's world refresh window is still open after pressing Refresh Now. If nothing happens, press its own button."])
                            Restore(entry)
                        end
                    end)
                end)
            end
        end
        return spec
    end
    entry.makeSpec = MakeSpec
    for i = 1, 2 do
        local button = UI.Button(frame, i)
        if i == 2 and not (button and button:IsShown() and Text(button)) then
            -- only one game button so far (Refresh Now): a second one on the card puts it away for now,
            -- and is swapped for the game's own second button if that shows up
            prompt.buttons[2] = { label = L["Not now"], muted = true, virtual = true,
                fn = function() if StaticPopup_Hide then pcall(StaticPopup_Hide, which) end end }
            break
        end
        prompt.buttons[i] = MakeSpec(i)
    end
    I:AddPrompt(prompt)
    Sync(entry)
end

local FindText
-- /island popups: what each open game pop-up looks like to Island (to learn how a warning is built)
function ns.DebugPopups()
    local any = false
    do
        local corner = _G.ShardTransferImminentFrame
        local t = corner and FindText(corner, 3)
        ns.Print("corner notice text: " .. tostring(t))
    end
    for i = 1, 4 do
        local f = _G["StaticPopup" .. i]
        if f and f:IsShown() then
            any = true
            local b1, b2 = UI.Button(f, 1), UI.Button(f, 2)
            local text = Text(f.text or f.Text)
            ns.Print(string.format("popup %d: which=%s  text=%s", i, tostring(f.which), tostring(text)))
            ns.Print(string.format("  buttons: %s | %s   refresh seconds: %s   island built: %s   in combat: %s",
                tostring(b1 and Text(b1)), tostring(b2 and Text(b2)), tostring(RefreshSecs(text)),
                tostring(I.built), tostring(Combat() and true or false)))
            local x, y = 0, 0
            local _, _, _, px, py = f:GetPoint(1)
            ns.Print(string.format("  window: alpha %s, effective alpha %s, anchored at %s, %s, strata %s, parent %s",
                tostring(f.GetAlpha and f:GetAlpha()), tostring(f.GetEffectiveAlpha and f:GetEffectiveAlpha()),
                tostring(px), tostring(py), tostring(select(2, pcall(f.GetFrameStrata, f))),
                tostring(f.GetParent and f:GetParent() and f:GetParent().GetName and f:GetParent():GetName())))
            local ok = Simple(f, f.which)
            ns.Print("  can be mirrored as a card: " .. tostring(ok) .. "   known to BanzaiSland: " .. tostring(known[f.which] ~= nil))
        end
    end
    local dialogs = _G.StaticPopupDialogs
    if type(dialogs) == "table" then
        for key, def in pairs(dialogs) do
            local text = type(def) == "table" and type(def.text) == "string" and def.text or ""
            local low, k = text:lower(), type(key) == "string" and key:upper() or ""
            if (low:find("world") and low:find("refresh")) or k:find("SHARD") or k:find("TRANSFER_IMM") then
                ns.Print("dialog: " .. tostring(key) .. "  text: " .. text)
            end
        end
    end
    for frame, entry in pairs(active) do
        local spec = entry.prompt and entry.prompt.buttons and entry.prompt.buttons[1]
        ns.Print(string.format("card for %s: first in line %s, island state %s, button armed %s, button enabled %s, hiding the game's pop-ups %s",
            tostring(entry.which), tostring(I.rolls[1] == entry.prompt), tostring(I.state), tostring(spec and spec.armed),
            tostring(spec and spec.enabled), tostring(ns.db.hideBlizzardPopups)))
        local two = entry.prompt and entry.prompt.buttons and entry.prompt.buttons[2]
        ns.Print(string.format("  second button: %s, virtual %s, enabled %s, armed %s;  card is for the window above: %s;  scale %s",
            tostring(two and two.label), tostring(two and two.virtual), tostring(two and two.enabled), tostring(two and two.armed),
            tostring(frame.IsShown and frame:IsShown()), tostring(frame.GetScale and frame:GetScale())))
    end
    local cf = _G.ShardTransferImminentFrame
    if cf and cf.GetChildren then
        for _, c in ipairs({ cf:GetChildren() }) do
            local scripts = {}
            for _, s in ipairs({ "OnClick", "OnMouseUp", "OnMouseDown" }) do
                if c.HasScript and c:HasScript(s) and c.GetScript and c:GetScript(s) then scripts[#scripts + 1] = s end
            end
            ns.Print("corner child: " .. tostring(c.GetName and c:GetName()) .. "  " .. tostring(c.GetObjectType and c:GetObjectType())
                .. "  scripts: " .. table.concat(scripts, ","))
        end
    end
    local corner = _G.ShardTransferImminentFrame
    ns.Print("ShardTransferImminentFrame: " .. tostring(corner ~= nil) .. (corner and ("  shown " .. tostring(corner:IsShown())) or "")
        .. "   refresh countdown kept: " .. tostring(refresh ~= nil))
    if not any then ns.Print("no game pop-up is open right now. Run this again while the world refresh pop-up is showing.") end
end

function ns.ApplyConfirmations()
    if Enabled() then return end
    local entries = {}
    for _, entry in pairs(active) do entries[#entries + 1] = entry end
    for _, entry in ipairs(entries) do Remove(entry) end
end

function ns.DemoConfirmation()
    I:AddPrompt({
        id = "demo-confirmation", front = true, glyph = "Plus", tone = C.gold, cap = L["CONFIRMATION"],
        name = L["Replace enchant?"], line = L["This is a preview. No item will be changed."], seconds = 20,
        buttons = { { label = L["Replace"], done = L["Confirmed"] },
                    { label = L["Cancel"], done = L["Cancelled"], muted = true } },
    })
end

-- the layer change's reminders: a card at 15, 5 and 1 minute, and the bubble goes at zero
local remind = 0
local function RefreshTick(dt)
    if not refresh then return end
    remind = remind + dt
    if remind < 1 then return end
    remind = 0
    local left = refresh.ends - GetTime()
    if left < -90 then ClearRefresh() return end
    for _, m in ipairs({ 15, 5, 1 }) do
        if left <= m * 60 and left > 0 and not refresh.warned[m] and refresh.total > m * 60 + 5 then
            for _, k in ipairs({ 15, 5, 1 }) do if k >= m then refresh.warned[k] = true end end
            I:Push({ kind = "won", urgent = m <= 5, glyph = "Clock", tone = PURPLE, cap = L["LAYER CHANGE"], capColor = PURPLE,
                     title = L["World refresh in %s"]:format(Words(left)), color = C.fg, res = "", hold = 4 })
        end
    end
end

-- The warning can open without going through StaticPopup_Show, so the open pop-ups are also looked at twice a second.
local scanT = 0
local told = setmetatable({}, { __mode = "k" })
-- the game's small corner notice ("World refresh in 30 Minutes") has its own text
FindText = function(frame, depth)
    if not frame then return nil end
    if frame.GetRegions then
        for _, r in ipairs({ frame:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "FontString" then
                local t = Text(r)
                if t and RefreshSecs(t) then return t end
            end
        end
    end
    if depth > 0 and frame.GetChildren then
        for _, c in ipairs({ frame:GetChildren() }) do
            local t = FindText(c, depth - 1)
            if t then return t end
        end
    end
end
local function Recapture()
    for i = 1, 4 do
        local f = _G["StaticPopup" .. i]
        if f and f.which and f:IsShown() and IsRefreshPopup(f) then Capture(f.which) return end
    end
    OpenOriginal()
    -- say so when the game's pop-up does not come up, so it can be fixed
    C_Timer.After(1.2, function()
        for i = 1, 4 do
            local f = _G["StaticPopup" .. i]
            if f and f:IsShown() and IsRefreshPopup(f) then return end
        end
        ns.Print(L["The game's world refresh pop-up did not open. Run /banzaisland popups and send what it prints."])
    end)
end
local function ScanCorner()
    local corner = _G.ShardTransferImminentFrame
    if not (corner and corner.IsShown and corner:IsShown()) then return end
    local text = FindText(corner, 3)
    local secs = text and RefreshSecs(text)
    if not secs then return end
    if not refresh or math.abs(secs - (refresh.ends - GetTime())) > 75 then SetRefresh(secs, Recapture, true) end
end
local function ScanPopups(dt)
    scanT = scanT + dt
    if scanT < 0.5 then return end
    scanT = 0
    if not (ns.db and ns.db.promptRefresh ~= false) then return end
    ScanCorner()
    if Combat() then return end
    for i = 1, 4 do
        local f = _G["StaticPopup" .. i]
        if f and f.which and f:IsShown() and not active[f] and not known[f.which] then
            local text = Text(f.text or f.Text)
            if IsRefreshPopup(f) then
                Capture(f.which)
                if not active[f] and not told[f] then
                    told[f] = true
                    local b1, b2 = UI.Button(f, 1), UI.Button(f, 2)
                    local b3, b4 = UI.Button(f, 3), UI.Button(f, 4)
                    ns.Print(string.format("BanzaiSland: found the world refresh pop-up (%s) but could not turn it into a card. buttons: %s | %s | %s | %s. Send this line.",
                        tostring(f.which), tostring(b1 and b1:IsShown() and Text(b1)), tostring(b2 and b2:IsShown() and Text(b2)),
                        tostring(b3 and b3:IsShown() and Text(b3)), tostring(b4 and b4:IsShown() and Text(b4))))
                end
            end
        end
    end
end

local watcher = CreateFrame("Frame")
local elapsed = 0
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnUpdate", function(_, dt)
    RefreshTick(dt)
    ScanPopups(dt)
    if not next(active) then return end
    elapsed = elapsed + dt
    if elapsed < 0.05 then return end
    elapsed = 0
    -- Snapshot because removing a prompt also removes its tracking entry.
    local entries = {}
    for _, entry in pairs(active) do entries[#entries + 1] = entry end
    for _, entry in ipairs(entries) do Sync(entry) end
end)
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then ClearRefresh() return end
    -- Match the existing secure prompts: restore the game window as combat begins.
    local entries = {}
    for _, entry in pairs(active) do entries[#entries + 1] = entry end
    for _, entry in ipairs(entries) do Remove(entry) end
end)

if hooksecurefunc and StaticPopup_Show then
    hooksecurefunc("StaticPopup_Show", function(which)
        -- Let the popup finish configuring its buttons and item-specific text first.
        C_Timer.After(0, function() Capture(which) end)
    end)
end
