-- Island: collect an online AFK session and show one digest when the player returns.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L, I, C = ns.L, ns.Island, ns.C
local A = { entries = {}, byKey = {}, page = 1 }
ns.CatchUp = A
local ready, loading, generation = false, false, 0
local MAX_ENTRIES, PAGE_SIZE = 50, 4
local categories = { whispers = "catchUpWhispers", auctions = "catchUpAuctions", mail = "catchUpMail",
    cooldowns = "catchUpCooldowns", legacy = "catchUpLegacy", social = "catchUpSocial",
    retailProgress="catchUpRetailProgress",collections="catchUpCollections",housing="catchUpHousing" }

local function Color() return ns.db.restColor or ns.defaults.restColor end
local function Safe(v, kind) return ns.Readable(v) and type(v) == kind end
local function AFK()
    if not UnitIsAFK then return false end
    local ok, value = pcall(UnitIsAFK, "player")
    if not ok or not ns.Readable(value) then return nil end
    return value == true or value == 1
end
local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
local function Age(seconds)
    if seconds < 60 then return L["Just now"] end
    if seconds < 3600 then return L["%dm ago"]:format(math.floor(seconds / 60)) end
    return L["%dh ago"]:format(math.floor(seconds / 3600))
end
local function Count(snapshot)
    local total = 0
    for _, entry in ipairs(snapshot.entries) do total = total + entry.count end
    return total
end
local function Available(snapshot)
    return snapshot and not snapshot.cleared and GetTime() < snapshot.expires
end
local function Dismiss()
    for _, list in ipairs({ I.queue, I.held }) do
        for index = #list, 1, -1 do if list[index].catchUpDigest then table.remove(list, index) end end
    end
    if I.current and I.current.catchUpDigest then I.current.dur = I.current.t or 0 end
end

function A.UpdateBubble()
    if not I.built then return end
    if not ns.db.catchUp or not ns.db.catchUpBubble then I:SetActivity("catchUp", nil) return end
    if A.started then
        I:SetActivity("catchUp", { glyph = "Bell", tone = Color(), priority = 1,
            tip = L["Away"], tip2 = L["Collecting updates until you return"],
            text = function() return Clock(GetTime() - (A.started or GetTime())) end })
    elseif Available(A.latest) then
        local snapshot = A.latest
        I:SetActivity("catchUp", { glyph = "Bell", tone = Color(), priority = 1,
            tip = L["While you were away"], tip2 = L["Click to view your updates"],
            text = function() return tostring(Count(snapshot)) end, onClick = function() A.Show() end })
    else I:SetActivity("catchUp", nil) end
end

function A.Clear(snapshot)
    snapshot = snapshot or A.latest
    if snapshot then snapshot.cleared = true end
    if snapshot == A.latest then A.latest = nil end
    Dismiss()
    A.UpdateBubble()
end

function A.Show(snapshot, automatic)
    snapshot = snapshot or A.latest
    if not I.built or not Available(snapshot) then return false end
    A.page = 1
    I:PushReplace({ kind = "won", key = "catchUpDigest", builderType = "catchUp", group = "social",
        catchUpDigest = snapshot, transient = true, exact = true, replay = not automatic,
        glyph = "Bell", tone = Color(), cap = L["WHILE YOU WERE AWAY"], capColor = Color(),
        title = (Count(snapshot) == 1 and L["%d update waiting"] or L["%d updates waiting"]):format(Count(snapshot)),
        res = L["%dm away"]:format(math.max(1, math.floor(snapshot.duration / 60))), resColor = Color(),
        color = C.fg, hold = 20, onClick = false })
    return true
end

function A.Check()
    if not ready or loading or not ns.db then return end
    if not ns.db.catchUp then
        A.started, A.entries, A.byKey = nil, {}, {}
        A.UpdateBubble()
        return
    end
    local afk = AFK()
    if afk == nil then return end
    if afk then
        if not A.started then
            A.started, A.entries, A.byKey = GetTime(), {}, {}
            A.UpdateBubble()
        end
    elseif A.started then
        local duration = GetTime() - A.started
        local entries = A.entries
        A.started, A.entries, A.byKey = nil, {}, {}
        if #entries > 0 then
            -- Retain a previous unread digest when another AFK session starts.
            if Available(A.latest) then
                local merged = {}
                for _, entry in ipairs(A.latest.entries) do merged[#merged+1] = entry end
                for _, entry in ipairs(entries) do merged[#merged+1] = entry end
                entries = merged
            end
            while #entries > MAX_ENTRIES do table.remove(entries, 1) end
            A.latest = { entries = entries, duration = duration, expires = GetTime() + (ns.db.catchUpExpire or 60) * 60 }
            if duration >= (ns.db.catchUpMinimum or 60) then A.Show(A.latest, true) end
        end
        A.UpdateBubble()
    end
end

function A.Wants(category)
    if category == "legacy" and not ns.ClientFeature("legacy") then return false end
    if (category=="retailProgress" or category=="collections" or category=="housing") and not ns.ClientFeature("retail") then return false end
    if not ns.db or not ns.db.catchUp or not categories[category] or ns.db[categories[category]] == false then return false end
    A.Check()
    return ready and not loading and A.started ~= nil
end

function A.Record(category, key, title, detail, options)
    if not A.Wants(category) or not Safe(key, "string") or not Safe(title, "string") then return end
    options = options or {}
    local id = category .. ":" .. key
    local entry = A.byKey[id]
    if entry then
        entry.count, entry.at = entry.count + (options.once and 0 or 1), GetTime()
        if Safe(detail, "string") then entry.detail = detail end
        return
    end
    entry = { category = category, key = id, title = title, detail = Safe(detail, "string") and detail or "",
        glyph = options.glyph or "Bell", at = GetTime(), count = 1,
        sender = Safe(options.sender, "string") and options.sender or nil,
        guid = Safe(options.guid, "string") and options.guid or nil,
        bnID = Safe(options.bnID, "number") and options.bnID or nil }
    A.entries[#A.entries+1], A.byKey[id] = entry, entry
    if #A.entries > MAX_ENTRIES then local oldest = table.remove(A.entries, 1) A.byKey[oldest.key] = nil end
end

function A.ShouldQuiet(item)
    return not item.replay and item.kind == "won" and item.catchUpCategory and A.Wants(item.catchUpCategory)
end

function A.Apply()
    if not ns.db.catchUp then
        A.started, A.entries, A.byKey = nil, {}, {}
        if A.latest then A.latest.cleared = true A.latest = nil end
        Dismiss()
    end
    A.Check()
    A.UpdateBubble()
end

local function Button(parent, label, width, callback)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 30)
    b.bg = ns.CreatePill(b, 30, "ARTWORK", 0)
    b.bg:SetWidth(width)
    b.bg:SetColor(1, 1, 1, 0.10)
    b.text = ns.Text(b, "bold", 12, C.fg, "CENTER")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b:SetScript("OnClick", callback)
    b:SetScript("OnEnter", function() b.bg:SetColor(1, 1, 1, 0.18) end)
    b:SetScript("OnLeave", function() b.bg:SetColor(1, 1, 1, 0.10) end)
    return b
end

-- Rows are children of the existing won-card layer, so they follow Island's animation,
-- position and scale. No separate window or protected-frame anchors are needed.
function A.Layout(w, item)
    local cardWidth = w.cardWidth or ns.WIDE
    if w.catchUp then w.catchUp:Hide() end
    local snapshot = item.catchUpDigest
    if not snapshot then w.frame:SetHeight(140) return end
    if not Available(snapshot) then w.frame:SetHeight(68) return 68 end
    if not w.catchUp then
        local f = CreateFrame("Frame", nil, w.frame)
        f:SetFrameLevel(w.tip:GetFrameLevel() + 6)
        f:SetPoint("TOPLEFT", w.frame, "TOPLEFT", 14, -64)
        f:SetWidth(cardWidth - 32)
        f.rows = {}
        for index = 1, PAGE_SIZE do
            local row = CreateFrame("Button", nil, f)
            row:SetSize(cardWidth - 32, 57)
            row:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(index - 1) * 61)
            row.glyph = ns.Image(row, "Bell", "ARTWORK", 0)
            row.glyph:SetSize(16, 16)
            row.glyph:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -3)
            row.title = ns.Text(row, "bold", 12, C.fg)
            row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 25, 0)
            row.title:SetWidth(cardWidth - 120)
            row.title:SetJustifyH("LEFT")
            if row.title.SetMaxLines then row.title:SetMaxLines(1) end
            row.time = ns.Text(row, "medium", 10.5, C.muted, "RIGHT")
            row.time:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
            row.time:SetWidth(62)
            row.detail = ns.Text(row, "medium", 11.5, C.muted)
            row.detail:SetPoint("TOPLEFT", row, "TOPLEFT", 25, -18)
            row.detail:SetWidth(cardWidth - 62)
            row.detail:SetJustifyH("LEFT")
            if row.detail.SetWordWrap then row.detail:SetWordWrap(true) end
            if row.detail.SetMaxLines then row.detail:SetMaxLines(2) end
            row:SetScript("OnClick", function(self)
                local entry = self.entry
                local api = ns.db.usePigeon and _G.PigeonAPI
                if entry and entry.sender and type(api) == "table" and type(api.Open) == "function" then
                    pcall(api.Open, entry.sender, entry.guid, entry.bnID)
                end
            end)
            f.rows[index] = row
        end
        f.clear = Button(f, L["Clear updates"], (cardWidth-40)/2, function() A.Clear(f.snapshot) end)
        f.dismiss = Button(f, L["Dismiss"], (cardWidth-40)/2, Dismiss)
        f.previous = Button(f, L["Previous"], 85, function() A.page = A.page-1 A.RefreshCard() end)
        f.next = Button(f, L["Next"], 85, function() A.page = A.page+1 A.RefreshCard() end)
        f.pageLabel = ns.Text(f, "medium", 11, C.muted, "CENTER")
        f:SetScript("OnUpdate", function(self, dt)
            self.since = (self.since or 0) + dt
            if self.since < 1 then return end
            self.since = 0
            for _, row in ipairs(self.rows) do if row.entry then row.time:SetText(Age(GetTime()-row.entry.at)) end end
        end)
        w.catchUp = f
    end
    local f = w.catchUp
    f:SetWidth(cardWidth - 32)
    for _, row in ipairs(f.rows) do
        row:SetWidth(cardWidth - 32)
        row.title:SetWidth(cardWidth - 120)
        row.detail:SetWidth(cardWidth - 62)
    end
    for _, button in ipairs({f.clear, f.dismiss}) do
        button:SetWidth((cardWidth - 40)/2)
        button.bg:SetWidth((cardWidth - 40)/2)
    end
    f.snapshot = snapshot
    local sorted = {}
    for _, entry in ipairs(snapshot.entries) do sorted[#sorted+1] = entry end
    table.sort(sorted, function(a,b) return a.at > b.at end)
    local pages = math.max(1, math.ceil(#sorted / PAGE_SIZE))
    A.page = math.max(1, math.min(pages, A.page))
    local count = 0
    local look = ns.CardLook and ns.CardLook(item)
    local details = not look or look.line ~= false
    local rowHeight = details and 61 or 35
    for index, row in ipairs(f.rows) do
        local entry = sorted[(A.page-1)*PAGE_SIZE+index]
        row.entry = entry
        row:SetShown(entry ~= nil)
        if entry then
            count = count + 1
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(index-1)*rowHeight)
            row:SetHeight(rowHeight-4)
            row.detail:SetShown(details)
            local color = Color()
            row.glyph:SetVertexColor(color[1], color[2], color[3])
            row.glyph:SetTexture(ns.MEDIA .. entry.glyph)
            row.title:SetText(entry.count > 1 and L["%s (%d)"]:format(entry.title, entry.count) or entry.title)
            row.time:SetText(Age(GetTime()-entry.at))
            local api = ns.db.usePigeon and _G.PigeonAPI
            local reply = entry.sender and type(api) == "table" and type(api.Open) == "function"
            local detail = entry.detail
            if reply then detail = L["%s · Click to reply"]:format(detail) end
            row.detail:SetText(detail)
        end
    end
    local footer = count * rowHeight
    f.previous:SetShown(pages > 1) f.next:SetShown(pages > 1) f.pageLabel:SetShown(pages > 1)
    if pages > 1 then
        f.previous:ClearAllPoints() f.previous:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -footer)
        f.next:ClearAllPoints() f.next:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -footer)
        f.previous:SetEnabled(A.page > 1) f.next:SetEnabled(A.page < pages)
        f.pageLabel:ClearAllPoints() f.pageLabel:SetPoint("TOP", f, "TOP", 0, -footer-8)
        f.pageLabel:SetText(L["%d / %d"]:format(A.page, pages))
        footer = footer + 38
    end
    f.clear:ClearAllPoints() f.clear:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -footer)
    f.dismiss:ClearAllPoints() f.dismiss:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -footer)
    f:SetHeight(footer + 30)
    f:Show()
    w.names:Hide()
    local height = 64 + footer + 44
    w.frame:SetHeight(height)
    return height
end

function A.RefreshCard()
    local item = I.current
    if not item or not item.catchUpDigest then return end
    local h = A.Layout(I.wn, item)
    ns.STATES.won.h = h
    if I.state == "won" then I.sh.t = h end
    item.t = math.min(item.t or 0, 1)
end

function A.Demo()
    local now = GetTime()
    local snapshot = { duration = 12*60, expires = now + 3600, entries = {
        { title = L["Whisper from %s"]:format("Thrall"), detail = L["Ready for the dungeon?"], glyph = "Chat", at = now-180, count = 2 },
        { title = L["Auction sold"], detail = "Shadowfang", glyph = "Coin", at = now-420, count = 1 },
        { title = L["Hearthstone ready"], detail = L["Cooldown finished"], glyph = "Home", at = now-540, count = 1 },
        { title = L["Legacy challenge completed"], detail = "Journeyman Alchemist", glyph = "Check", at = now-660, count = 1 },
    } }
    if not ns.ClientFeature("legacy") then
        snapshot.entries[4] = { title = L["New mail"], detail = "", glyph = "Mail", at = now-660, count = 1 }
    end
    A.Show(snapshot)
end

local ev = CreateFrame("Frame")
local queueStates = {}
local function Arrived()
    ready, generation = false, generation + 1
    local ticket = generation
    C_Timer.After(2, function() if ticket == generation and not loading then ready = true A.Check() end end)
end
ev:SetScript("OnEvent", function(_, event, a)
    if event == "LOADING_SCREEN_ENABLED" then loading, ready, generation = true, false, generation+1
    elseif event == "LOADING_SCREEN_DISABLED" then loading = false Arrived()
    elseif event == "PLAYER_ENTERING_WORLD" then Arrived()
    elseif event == "PLAYER_FLAGS_CHANGED" and a == "player" then A.Check()
    elseif event == "PARTY_INVITE_REQUEST" then
        if Safe(a, "string") then A.Record("social", "invite:"..a, L["Group invite received"], L["From %s"]:format(ns.ShowName(a) or a), {glyph="Person"}) end
    elseif event == "READY_CHECK" then
        A.Record("social", "readyCheck", L["Ready check received"], L["Check its current status in the game."], {glyph="Check"})
    elseif event == "UPDATE_BATTLEFIELD_STATUS" and GetBattlefieldStatus then
        for index=1, (GetMaxBattlefieldID and GetMaxBattlefieldID() or 3) do
            local ok, status, name = pcall(GetBattlefieldStatus, index)
            if ok and Safe(status, "string") then
                if status == "confirm" and queueStates[index] ~= "confirm" then
                    A.Record("social", "queue:"..index, L["Battleground queue ready"], Safe(name,"string") and name or L["Check its current status in the game."], {glyph="Flag"})
                end
                queueStates[index] = status
            end
        end
    end
end)
for _, event in ipairs({"PLAYER_ENTERING_WORLD","LOADING_SCREEN_ENABLED","LOADING_SCREEN_DISABLED","PLAYER_FLAGS_CHANGED",
    "PARTY_INVITE_REQUEST","READY_CHECK","UPDATE_BATTLEFIELD_STATUS"}) do pcall(ev.RegisterEvent, ev, event) end
local since = 0
ev:SetScript("OnUpdate", function(_, dt)
    since = since + dt
    if since < 1 then return end
    since = 0
    A.Check()
    if A.latest and not Available(A.latest) then A.Clear() end
    if I.current and I.current.catchUpDigest and I.wn and I.wn.frame.IsMouseOver and I.wn.frame:IsMouseOver() then
        I.current.t = math.min(I.current.t or 0, 1)
    end
end)
