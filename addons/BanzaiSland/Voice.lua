-- Island: Spoken voiceovers. While Spoken reads a quest, a zone or a book aloud, the island shows
-- who is speaking, what about, and the words as they are spoken, with Pause/Play, Skip and Stop.
-- Spoken's own window steps aside meanwhile. Nothing here runs without the Spoken addon.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local I, C = ns.Island, ns.C
local floor, max, min = math.floor, math.max, math.min
local PURPLE = { 0.72, 0.52, 1.00 }
local ID = "spoken"
local WINDOW = 230          -- characters of the line shown at once on a long transcript
local FG = ns.Hex(C.fg[1], C.fg[2], C.fg[3])
local MUTED = ns.Hex(C.muted[1], C.muted[2], C.muted[3])
local SPOKEN_FRAMES = { "SpokenPlayerFrame", "SpokenSubtitleFrame", "SpokenMinimalPlayerFrame", "SpokenDialogueUIPlayerFrame",
                        "SpokenTranscriptFrame" }

local V = {}
ns.Voice = V
local ClearStrip            -- defined with the ticker, further down

local function API()
    local s = _G.Spoken
    if type(s) == "table" and s.IsCompatible and s:IsCompatible(1) then return s end
end

local function On() return ns.db and ns.db.spokenCard end

-- ---------------------------------------------------------------- Spoken's own window

local hooked = {}
function V:ApplyHide()
    local hide = On() and ns.db.spokenHide and self.clip ~= nil
    self.hiding = hide
    for _, name in ipairs(SPOKEN_FRAMES) do
        local f = _G[name]
        if type(f) == "table" and f.SetAlpha then
            if not hooked[f] and hooksecurefunc then
                hooked[f] = true
                -- Spoken fades its window in and out: keep it at nothing while the island speaks
                hooksecurefunc(f, "SetAlpha", function(self, a) if V.hiding and a and a > 0 then self:SetAlpha(0) end end)
                if f.HookScript then f:HookScript("OnShow", function(self) if V.hiding then self:SetAlpha(0) end end) end
            end
            if hide then
                -- remember how it took the mouse, so it goes back exactly as it was
                if f.hiddenMouse == nil and f.IsMouseEnabled then f.hiddenMouse = f:IsMouseEnabled() and true or false end
                f:SetAlpha(0)
                if f.EnableMouse then pcall(f.EnableMouse, f, false) end
            elseif f.hiddenMouse ~= nil then
                f:SetAlpha(1)
                if f.EnableMouse then pcall(f.EnableMouse, f, f.hiddenMouse) end
                f.hiddenMouse = nil
            end
        end
    end
end

-- ---------------------------------------------------------------- the words

local function Transcript(clip)
    local p = clip and clip.present or {}
    local t = p.transcript or clip and clip.text or ""
    if type(t) ~= "string" then t = "" end
    return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+", " "))
end

-- How far into the text the voice is: the byte where the word being spoken ends.
local function SaidUpTo(clip, text)
    local sp = API()
    if not (sp and sp.GetCaption) then return 0 end
    local ok, cap = pcall(sp.GetCaption, sp)
    if not (ok and cap and cap.clip == clip) then return 0 end
    -- the word being spoken, found again in this cleaned-up copy of the line
    if V.wordsFor ~= clip then
        V.wordsFor = clip
        local ok2, words = pcall(sp.SplitCaption, sp, text)
        V.words = ok2 and words or nil
    end
    local w = cap.activeWord and V.words and V.words[cap.activeWord]
    if w and w.last then return w.last end
    if cap.progress and cap.progress >= 1 then return #text end
    return 0
end

-- ---------------------------------------------------------------- the scrolling text
-- The whole line is laid out once, three lines tall, and glides upward as the voice moves on, so
-- the line being read stays in view. Words already spoken turn white; the rest wait in grey.
-- Colouring never changes where a line wraps, so nothing jumps while you read.

local LINES = 3
local view

local function BuildView()
    if view or not (I.rl and I.rl.frame) then return view end
    local f = I.rl.frame
    view = CreateFrame("Frame", nil, f)
    view:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -79)
    view:SetWidth(ns.WIDE - 32)
    if view.SetClipsChildren then view:SetClipsChildren(true) end
    local function text()
        local fs = ns.Text(view, "medium", 12, C.fg)
        fs:SetWidth(ns.WIDE - 32)
        if fs.SetWordWrap then fs:SetWordWrap(true) end
        if fs.SetSpacing then fs:SetSpacing(3) end
        if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(true) end
        return fs
    end
    view.text = text()
    view.measure = text()            -- an invisible copy, to find which line a word is on
    view.measure:SetAlpha(0)
    -- the height of one line and the step from one line to the next
    view.measure:SetText("Ag")
    local one = view.measure:GetStringHeight() or 14
    view.measure:SetText("Ag\nAg")
    local two = view.measure:GetStringHeight() or 31
    view.lineH, view.step = one, max(1, two - one)
    view:SetHeight(one + view.step * (LINES - 1) + 2)
    view.y, view.target = 0, 0
    view:Hide()
    V.view = view
    return view
end

-- which line (0 = first) the given byte of the text falls on
local function LineOf(text, upto)
    if upto <= 0 then return 0 end
    view.measure:SetText(text:sub(1, upto))
    local h = view.measure:GetStringHeight() or view.lineH
    return max(0, floor((h - view.lineH) / view.step + 0.5))
end

local function Paint(text, said)
    said = min(said, #text)
    view.text:SetText(FG .. text:sub(1, said) .. "|r" .. MUTED .. text:sub(said + 1) .. "|r")
    -- keep the line being read second from the top (first, at the very start)
    local line = LineOf(text, said)
    local total = LineOf(text, #text)
    local top = min(max(0, line - 1), max(0, total - (LINES - 1)))
    view.target = top * view.step
end

-- what the card itself reserves for the text: three empty lines
local BLANK = " \n \n "

-- ---------------------------------------------------------------- the card

local function Roll()
    for _, r in ipairs(I.rolls or {}) do if r.id == ID then return r end end
end

function V:Buttons()
    local sp = API()
    local paused = sp and sp.IsPaused and sp:IsPaused()
    local waiting = sp and sp.GetWaitingCount and sp:GetWaitingCount() or 0
    local list = {
        { label = paused and L["Play"] or L["Pause"], keep = true, enabled = true, noKey = true, fn = function() if sp then sp:TogglePause() end end },
    }
    if waiting > 0 then
        list[#list + 1] = { label = L["Skip  (%d)"]:format(waiting), keep = true, muted = true, enabled = true, fn = function() if sp then sp:Skip() end end }
    end
    list[#list + 1] = { label = L["Stop"], keep = true, muted = true, enabled = true, fn = function() if sp then sp:StopAll() end end }
    return list, paused
end

function V:Show(clip)
    if not On() or not I.built then return end
    self.clip, self.lastWord = clip, nil
    local p = clip.present or {}
    local buttons, paused = self:Buttons()
    local length = tonumber(clip.length)
    local header = type(p.header) == "string" and p.header ~= "" and p.header or nil
    local label = type(p.label) == "string" and p.label ~= "" and p.label or nil
    I:AddPrompt({
        id = ID, glyph = "Speaker", tone = PURPLE, capColor = PURPLE,
        cap = label and label:upper() or L["VOICEOVER"], name = header or label or "Spoken",
        line = BLANK, seconds = (length and length > 0) and (length + 1) or 3600,
        buttons = buttons, keepOpen = true,
    })
    local r = Roll()
    if r and not (length and length > 0) then r.expires = nil end      -- no length: no countdown
    if BuildView() then
        self.text = Transcript(clip)
        Paint(self.text, 0)
        view.y = 0                                                       -- a new line starts at the top
        self.said = 0
    end
    self:ApplyHide()
end

function V:Refresh()
    local r = Roll()
    if not r or not self.clip then return end
    local buttons, paused = self:Buttons()
    r.buttons = buttons
    if paused then
        r.expires = nil                                  -- the clock stops; Play starts the line again
        if view then
            view.text:SetText(MUTED .. L["Paused. Play starts this line again from the beginning."] .. "|r")
            view.target, view.y = 0, 0
        end
    elseif view and self.text then
        Paint(self.text, self.said or 0)
    end
    r.line = BLANK
    I:UpdatePrompt(ID, r.line)
end

function V:Hide()
    self.clip = nil
    ClearStrip()
    I:RemoveRoll(ID, true)
    -- Spoken's window is usually still on screen, fading out, when the line ends: handing it back
    -- at once makes it flash. Keep it hidden until it has gone (or a short while), then restore.
    if self.hiding and C_Timer and C_Timer.After then
        self.release = (self.release or 0) + 1
        local mine = self.release
        local tries = 0
        local function Check()
            if self.clip or self.release ~= mine then return end      -- a new line started, or a newer release
            tries = tries + 1
            local shown = false
            for _, name in ipairs(SPOKEN_FRAMES) do
                local f = _G[name]
                if type(f) == "table" and f.IsShown and f:IsShown() then shown = true end
            end
            if shown and tries < 20 then C_Timer.After(0.1, Check) return end
            self:ApplyHide()
        end
        C_Timer.After(0.1, Check)
        return
    end
    self:ApplyHide()
end

-- Spoken builds its windows when it first needs them, and a line started by hand (the play button
-- on the map, a book) can bring one up after the island's card is already showing. While a line
-- plays, look again a few times a second and tuck away any that has appeared.
local function KeepHidden(dt)
    if not (V.clip and On() and ns.db.spokenHide) then return end
    V.ht = (V.ht or 0) + dt
    if V.ht < 0.25 then return end
    V.ht = 0
    for _, name in ipairs(SPOKEN_FRAMES) do
        local f = _G[name]
        if type(f) == "table" and f.IsShown and f:IsShown() and (not hooked[f] or (f.GetAlpha and f:GetAlpha() > 0)) then
            V:ApplyHide()
            return
        end
    end
end

-- ---------------------------------------------------------------- the ticker
-- While a voiceover plays, small news (loot, money, reputation, a quest step, a friend coming
-- online, a new zone) slides through a thin strip along the bottom of its card instead of taking
-- over the island; each item is still kept in the island's history. Anything worth acting on
-- (a whisper, a rare, broken gear, a group change) steps in as a full card for its moment.

local MINOR = { "^item:", "^currency:", "^rep:", "^skill$", "^zone$", "^questprogress$", "^mail$",
                "^friend:", "^guild:", "^vendor$", "^auction" }
local FOOTER = 34
local HOLD = 2.2            -- seconds each item stays when more are waiting
local LINGER = 3.2          -- seconds the last one stays before the strip folds away
local GOLD = C.gold or { 1, 0.82, 0 }

local strip
local queue, showing = {}, nil

local function Hex(c) return c and ns.Hex(c[1], c[2], c[3]) or FG end

local function BuildStrip()
    if strip or not (I.rl and I.rl.frame) then return strip end
    local f = I.rl.frame
    strip = CreateFrame("Frame", nil, f)
    strip:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 9)
    strip:SetSize(ns.WIDE - 32, 22)
    local line = strip:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.08)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", strip, "TOPLEFT", 0, 5)
    line:SetPoint("BOTTOMRIGHT", strip, "TOPRIGHT", 0, 5)
    if strip.SetClipsChildren then strip:SetClipsChildren(true) end
    local function slot()
        local s = CreateFrame("Frame", nil, strip)
        s:SetSize(ns.WIDE - 32, 22)
        s.tile = ns.Image(s, "Tile", "ARTWORK", 0)
        s.tile:SetSize(20, 20)
        s.tile:SetPoint("LEFT", s, "LEFT", 0, 0)
        s.glyph = ns.Image(s, "Star", "ARTWORK", 1)
        s.glyph:SetSize(12, 12)
        s.glyph:SetPoint("CENTER", s.tile, "CENTER", 0, 0)
        s.icon = ns.RoundIcon and ns.RoundIcon(s, 20) or s:CreateTexture(nil, "ARTWORK")
        s.icon:SetSize(20, 20)
        s.icon:SetPoint("LEFT", s, "LEFT", 0, 0)
        s.right = ns.Text(s, "bold", 12, C.muted, "RIGHT")
        s.right:SetPoint("RIGHT", s, "RIGHT", 0, 0)
        s.text = ns.Text(s, "bold", 12, C.fg)
        s.text:SetPoint("LEFT", s, "LEFT", 28, 0)
        s.text:SetPoint("RIGHT", s.right, "LEFT", -8, 0)
        s:SetAlpha(0)
        return s
    end
    strip.a, strip.b = slot(), slot()
    strip:Hide()
    return strip
end

local function EntryFor(item)
    local e = { key = item.key, t = 0, extensionOwner=item.extensionOwner, extensionKey=item.extensionKey }
    if item.kind == "gain" then
        e.key, e.amount, e.fmt = "money", item.amount or 0, item.fmt
        e.glyph, e.tone = "Coin", GOLD
    elseif item.kind == "toast" then
        local quest = item.toast == "quest"
        e.glyph, e.tone = quest and "Check" or "Compass", quest and C.quest or C.disc
        e.text = (item.title or "")
        e.right = (item.amount and item.amount > 0) and L["+%s XP"]:format(ns.Comma(item.amount)) or ""
    else
        e.icon = item.icon
        if not e.icon then e.glyph, e.tone = item.glyph or "Star", item.tone or C.muted end
        e.text = Hex(item.color) .. (item.title or "") .. "|r"
        e.count, e.format = item.count, item.format
        e.right = item.res or (item.format and item.count and item.format(item.count)) or ""
        e.cap = item.cap
    end
    return e
end

local function TextOf(e)
    if e.key == "money" then
        local m = e.fmt and e.fmt(e.amount) or tostring(e.amount)
        return L["Looted %s"]:format((m:gsub("^%+", ""))), ""
    end
    return e.text or "", e.right or ""
end

local function Fill(s, e)
    local text, right = TextOf(e)
    s.text:SetText(text)
    local more = #queue
    s.right:SetText(right .. (more > 0 and ((right ~= "" and "   " or "") .. MUTED .. L["+%d more"]:format(more) .. "|r") or ""))
    s.icon:SetShown(e.icon ~= nil)
    s.tile:SetShown(e.icon == nil)
    s.glyph:SetShown(e.icon == nil)
    if e.icon then
        s.icon:SetTexture(e.icon)
    else
        local t = e.tone or C.muted
        s.tile:SetVertexColor(t[1], t[2], t[3], 0.18)
        s.glyph:SetTexture(ns.MEDIA .. e.glyph)
        s.glyph:SetVertexColor(t[1], t[2], t[3], 1)
    end
end

-- the same thing again (more of the same cloth, more coin) adds to the one already listed
local function Merge(e)
    local function into(o)
        if o.key ~= e.key or not e.key then return false end
        if e.key == "money" then o.amount = o.amount + e.amount return true end
        if o.format and o.count and e.count then
            o.count = o.count + e.count
            o.right = o.format(o.count)
            return true
        end
        if e.right ~= "" then o.right = e.right end      -- quest progress, a zone: the newest wins
        if e.text then o.text = e.text end
        return true
    end
    if showing and into(showing) then
        showing.t = min(showing.t, 0.3)               -- keep it up a little longer
        local s = showing.slot
        if s then Fill(s, showing) end
        return true
    end
    for _, o in ipairs(queue) do if into(o) then return true end end
    return false
end

local function Footer(on)
    local top = I.rolls and I.rolls[1]
    if not (top and top.id == ID) then return end
    local want = on and FOOTER or nil
    if top.footer ~= want then
        top.footer = want
        if I.state == "roll" then I:FillRoll() end
    end
end

function V.HasExtension(id,key)
    local function match(e) return e and e.extensionOwner==id and (not key or e.extensionKey==key) end
    if match(showing) or (strip and match(strip.leaving)) then return true end
    for _,e in ipairs(queue) do if match(e) then return true end end
    return false
end
function V.RemoveExtension(id,key)
    local function match(e) return e and e.extensionOwner==id and (not key or e.extensionKey==key) end
    for n=#queue,1,-1 do if match(queue[n]) then table.remove(queue,n) end end
    if match(showing) then
        if showing.slot then showing.slot:SetAlpha(0) end
        showing=nil
    end
    if strip and match(strip.leaving) then
        if strip.leaving.slot then strip.leaving.slot:SetAlpha(0) end
        strip.leaving=nil
    end
    if not showing and #queue==0 then if strip then strip:Hide() end;Footer(false)
    elseif showing and showing.slot then Fill(showing.slot,showing) end
end
function V:Takes(item)
    if item.extensionOwner and (I:ShouldHold() or (ns.db.quietInRaid and IsInRaid and IsInRaid())) then return false end
    if not (self.clip and On() and ns.db.spokenTicker ~= false) then return false end
    local top = I.rolls and I.rolls[1]
    if not (top and top.id == ID) then return false end
    local minor = item.extensionOwner~=nil
    if item.kind == "gain" then
        minor = item.unit == "money"          -- XP still just moves the bar, as during any question
    elseif item.kind == "toast" then
        minor = true
    elseif item.kind == "won" and type(item.key) == "string" then
        for _, p in ipairs(MINOR) do if item.key:find(p) then minor = true break end end
    end
    if not minor then return false end
    if item.kind == "won" and item.count and item.format and not item.res then item.res = item.format(item.count) end
    if not BuildStrip() then
        if item.kind == "won" then I:Record(item) end
        return true
    end
    local e = EntryFor(item)
    if not Merge(e) then
        queue[#queue + 1] = e
        if item.kind == "won" then I:Record(item) end      -- kept in the history (once, not per repeat)
    end
    if showing and showing.slot then Fill(showing.slot, showing) end    -- the "+N more" count
    Footer(true)
    return true
end

-- one step of the strip, every frame while the voiceover card is on screen
local function StepStrip(dt, mine)
    if ns.Extensions then
        for n=#queue,1,-1 do if not ns.Extensions.Valid(queue[n]) then table.remove(queue,n) end end
        if showing and not ns.Extensions.Valid(showing) then V.RemoveExtension(showing.extensionOwner,showing.extensionKey) end
    end
    if not strip then return end
    local busy = showing ~= nil or #queue > 0
    strip:SetShown(mine and busy)
    if not mine then return end
    -- A new line (after Skip, or the next in Spoken's queue) arrives as a fresh card without the
    -- strip's room: give it back straight away so the strip never sits on top of the buttons.
    local top = I.rolls and I.rolls[1]
    if busy and top and top.footer ~= FOOTER then Footer(true) end
    if showing then
        showing.t = showing.t + dt
        local hold = #queue > 0 and HOLD or LINGER
        if showing.t >= hold then
            local old = showing
            showing = nil
            old.out = 0
            strip.leaving = old
            if #queue == 0 then
                C_Timer.After(0.3, function() if not showing and #queue == 0 then Footer(false) end end)
            end
        end
    end
    if not showing and #queue > 0 then
        showing = table.remove(queue, 1)
        showing.t, showing.inT = 0, 0
        local s = (strip.leaving and strip.leaving.slot == strip.a) and strip.b or strip.a
        showing.slot = s
        Fill(s, showing)
    end
    -- slide in from below, slide out upward
    if showing and showing.slot and showing.inT then
        showing.inT = min(1, showing.inT + dt / 0.25)
        local k = 1 - (1 - showing.inT) * (1 - showing.inT)
        local s = showing.slot
        s:ClearAllPoints()
        s:SetPoint("LEFT", strip, "LEFT", 0, -8 * (1 - k))
        s:SetAlpha(k)
        if showing.inT >= 1 then showing.inT = nil end
    end
    local old = strip.leaving
    if old and old.slot then
        old.out = min(1, old.out + dt / 0.2)
        local s = old.slot
        s:ClearAllPoints()
        s:SetPoint("LEFT", strip, "LEFT", 0, 8 * old.out)
        s:SetAlpha(1 - old.out)
        if old.out >= 1 then
            if not (showing and showing.slot == s) then s:SetAlpha(0) end
            strip.leaving = nil
        end
    end
end

ClearStrip = function()
    queue, showing = {}, nil
    if strip then
        strip.leaving = nil
        strip.a:SetAlpha(0) strip.b:SetAlpha(0)
        strip:Hide()
    end
end

-- the words move along while a line plays
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, dt)
    KeepHidden(dt)
    if not view then return end
    -- only over the voiceover card, and only while it is the one on screen
    local top = I.rolls and I.rolls[1]
    local mine = V.clip and top and top.id == ID and I.state == "roll"
    view:SetShown(mine and true or false)
    if I.rl and I.rl.names then I.rl.names:SetAlpha(mine and 0 or 1) end
    StepStrip(dt, mine)
    if not mine then return end
    -- glide toward the line being read
    local d = view.target - view.y
    if math.abs(d) > 0.2 then
        view.y = view.y + d * min(1, dt * 5)
    else
        view.y = view.target
    end
    view.text:ClearAllPoints()
    view.text:SetPoint("TOPLEFT", view, "TOPLEFT", 0, view.y)
    -- follow the voice a few times a second
    V.t = (V.t or 0) + dt
    if V.t < 0.1 then return end
    V.t = 0
    local sp = API()
    if not sp or (sp.IsPaused and sp:IsPaused()) or not V.text then return end
    local said = SaidUpTo(V.clip, V.text)
    if said ~= V.said then
        V.said = said
        Paint(V.text, said)
    end
end)

-- ---------------------------------------------------------------- Spoken's events

local function Hook()
    local sp = API()
    if not sp or V.hooked or not sp.RegisterCallback then return end
    V.hooked = true
    sp:RegisterCallback("CLIP_STARTED", function(clip) if clip then V:Show(clip) end end)
    sp:RegisterCallback("QUEUE_EMPTY", function() V:Hide() end)
    sp:RegisterCallback("AUDIO_CHANGED", function()
        if not V.clip then return end
        local cur = sp.GetCurrent and sp:GetCurrent()
        if not cur then V:Hide() return end
        V:Refresh()
    end)
end

function V:Demo()
    if not I.built then return end
    self.clip = { length = 9, present = { header = "Eagan Peltskinner", label = "Wolves Across the Border",
        transcript = "I'm sick and tired of those wolves! They come down from the mountains and take what isn't theirs. Kill them, and bring me their meat as proof." } }
    I:AddPrompt({ id = ID, glyph = "Speaker", tone = PURPLE, capColor = PURPLE, cap = "WOLVES ACROSS THE BORDER",
        name = "Eagan Peltskinner", line = BLANK,
        seconds = 9, buttons = { { label = L["Pause"], keep = true, fn = function() end }, { label = L["Stop"], keep = true, muted = true, fn = function() V:Hide() end } } })
    if BuildView() then
        local text = Transcript(self.clip)
        self.text, view.y = nil, 0
        -- read the sample out word by word, as the voice would
        local stop = 0
        for i = 1, 30 do
            C_Timer.After(i * 0.3, function()
                if not (V.clip and V.clip.present and V.clip.present.header == "Eagan Peltskinner") then return end
                stop = text:find(" ", stop + 2, true) or #text
                Paint(text, stop)
            end)
        end
        Paint(text, 0)
    end
    C_Timer.After(9, function() if V.clip and not V.clip.id then V.clip = nil end end)
end
ns.DemoVoice = function() V:Demo() end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or name == "Spoken" then Hook() end
end)
Hook()
