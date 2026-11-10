-- Island: Polestar (the leveling guide addon for Forever). It mirrors the RestedXP Guides support in Nav.lua:
--   * the navigation bubble follows Polestar's arrow (Nav.lua asks ns.PS for the arrow's target, the distance
--     and the direction, and can keep that arrow out of sight)
--   * a card and a bubble for the step Polestar is on, with the guide's progress along the bubble
--   * the step panel under the island (previous / next / skip / guide list / options) with Polestar's steps
--   * Polestar's own guide window can be kept out of sight
-- Island only reads Polestar and calls its public functions when you press a button. Polestar exposes its
-- namespace as the global `Polestar` (Engine, Nav, Guides and a message bus); everything here is guarded, so
-- nothing happens when Polestar is missing or a function is not there.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local I, C = ns.Island, ns.C
local max, min = math.max, math.min

-- shared with Nav.lua, which retunes it for the Style setting (purple, or bronze gold in Forever)
local GUIDE = (ns.RXP and ns.RXP.GUIDE) or { 0.70, 0.55, 1.00 }
local PS = { label = "Polestar", quiet = 0, seq = 0 }
ns.PS = PS

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end

-- Polestar's namespace, only when it is loaded and has what is used here
local function Core()
    local P = _G.Polestar
    if type(P) == "table" and type(P.Engine) == "table" and type(P.Nav) == "table" then return P end
    return nil
end
PS.Core = Core

local function Plain(t, limit) return ns.RXPPlain(t, limit) end

local function Index(step) return type(step) == "table" and type(step.index) == "number" and step.index or nil end

-- ---------------------------------------------------------------- the arrow

local function ArrowFrame()
    local P = Core()
    local a = P and P.Nav.arrow
    local f = type(a) == "table" and a.frame or _G.PolestarNavArrow
    if type(f) == "table" and f.SetAlpha and f.IsShown then return f end
    return nil
end

-- the target Polestar's arrow points at, while that arrow is up and has somewhere to point (not on
-- another continent, in an instance, on a taxi); nil otherwise
function PS.Element()
    local P = Core()
    if not P then return nil end
    local f = ArrowFrame()
    if not (f and f:IsShown()) then return nil end
    local Nv = P.Nav
    local t = Try(Nv.GetTarget)
    if type(t) ~= "table" then return nil end
    local ok, state, dist = pcall(Nv.Sample)
    if not ok then return nil end
    if state == "travel" or state == "arrived" or state == "search" or (state == "instruction" and type(dist) == "number") then
        return t
    end
    return nil
end

-- yards to the target and its direction (radians, 0 = north, turning left), as the arrow works them out
-- (along the walking route when Polestar has one); Polestar gives the angle relative to your facing
function PS.Vector()
    local P = Core()
    if not P then return nil end
    local ok, _, dist, angle, dn, dw = pcall(P.Nav.Sample)
    if not ok or type(dist) ~= "number" then return nil end
    -- the offset north/west is a map bearing already (0 = north, turning left): no facing needed
    if type(dn) == "number" and type(dw) == "number" and ns.Readable(dn) and ns.Readable(dw) and (dn ~= 0 or dw ~= 0) then
        return dist, (math.atan2 or math.atan)(dw, dn)
    end
    if type(angle) == "number" then
        local okf, facing = pcall(GetPlayerFacing)
        if okf and type(facing) == "number" and ns.Readable(facing) then return dist, angle + facing end
    end
    return dist, nil
end

function PS.Title(e)
    local t = type(e) == "table" and e.label
    if type(t) ~= "string" then return L["Guide step"] end
    t = Plain(t, 60)
    return t ~= "" and t or L["Guide step"]
end

-- Polestar's arrow: out of sight while the bubble shows the way (Polestar still does its work), and after a
-- right-click hid the bubble, until the target changes. Called from Nav:ApplyRXPArrow.
function PS.ApplyArrow(N)
    local f = ArrowFrame()
    if not f then return end
    local P = Core()
    local pin = N.pin
    local silenced = false
    if N.muted and P then silenced = Try(P.Nav.GetTarget) == N.muted end
    local hide = ns.db and ns.db.navPolestar and ns.db.navHidePolestar and ((pin and pin.src == "polestar") or silenced)
    if hide then
        if f:GetAlpha() ~= 0 then f:SetAlpha(0) end
        if not PS.arrowHidden then
            PS.arrowHidden = true
            if f.EnableMouse then f:EnableMouse(false) end
        end
    elseif PS.arrowHidden then
        PS.arrowHidden = nil
        local a = P and tonumber(Try(P.Get, "nav.arrowAlpha")) or 1
        f:SetAlpha(min(1, max(0.1, a)))
        if f.EnableMouse then f:EnableMouse(true) end
    end
end

-- ---------------------------------------------------------------- the current step (cards, bubble)

-- the step's name: its title, else the first line of what to do
local function StepTitle(view)
    if type(view) ~= "table" then return nil end
    if type(view.title) == "string" and view.title ~= "" then return view.title end
    for _, g in ipairs(view.goals or {}) do
        if g.status ~= "na" and not g.folded and type(g.text) == "string" and g.text ~= "" then return g.text end
    end
    return nil
end

local function Progress()
    local P = Core()
    if not P then return 0 end
    local done, total = Try(P.Engine.GetProgress)
    if type(done) ~= "number" or type(total) ~= "number" or total <= 0 then return 0 end
    return max(0, min(1, done / total))
end

-- read the guide and step Polestar is on into PS.guide / PS.step (shaped like what the RestedXP code shows)
function PS:Refresh()
    local P = Core()
    local g = P and Try(P.Engine.GetGuide)
    if type(g) ~= "table" then self.guide, self.step = nil, nil return false end
    local idx = Try(P.Engine.GetStepIndex)
    local view = type(idx) == "number" and Try(P.Engine.GetStepView, idx) or nil
    self.guide = { ps = true, key = g.id, title = g.title }
    self.step = type(idx) == "number" and { index = idx, ps = true, title = StepTitle(view) } or nil
    return true
end

function PS:SetBubble()
    if ns.RXP and ns.RXP.SyncTone then ns.RXP.SyncTone() end
    local U = ns.RXP and ns.RXP.util
    if not (U and ns.db and ns.db.polestarStepBubble and self.step and Index(self.step)) then
        I:SetActivity("polestep", nil)
        self.shownBubble = nil
        return
    end
    self.shownBubble = true
    I:SetActivity("polestep", {
        glyph = "Compass", tone = GUIDE, priority = 2,
        tip = U.GuideName(self.guide), tip2 = U.StepText(self.step),
        text = function() return L["Step %d"]:format(Index(PS.step) or 0) end,
        native = true, noEase = false,
        click = function() ns.RXP:ToggleDrawer(PS) end, clickHint = L["Click: guide steps"],
        extPin = true,                      -- beside the island by default (the shelf can unpin it)
        progress = ns.db.polestarStepBubbleBar ~= false and Progress or nil,
    })
end

-- the guide moved to another step (or a first one): a bubble, and a card once things have settled
function PS:StepActivated()
    local R = ns.RXP
    local U = R and R.util
    if not (ns.db and U and self:Refresh() and self.step) then return end
    self:SetBubble()
    if R.pv == PS and R.D and R.D.frame and R.D.frame:IsShown() then R:RefreshDrawer() end
    if not ns.db.polestarStepCards then return end
    if GetTime() < (self.quiet or 0) then return end
    self.seq = (self.seq or 0) + 1
    local mine = self.seq
    C_Timer.After(0.4, function()
        if PS.seq ~= mine or not PS:Refresh() then return end
        local st = PS.step
        if not st or not ns.db or not ns.db.polestarStepCards or ns.db.dnd then return end
        local key = tostring(PS.guide.key) .. ":" .. (Index(st) or 0)
        if PS.lastCard == key then return end
        PS.lastCard = key
        local item = {
            kind = "won", key = "polestep", builderType = "progress", glyph = "Compass", tone = GUIDE,
            cap = L["STEP %d"]:format(Index(st) or 0), capColor = GUIDE, title = U.StepText(st), line = U.GuideName(PS.guide),
            color = C.fg, hold = 4,
            progress = Progress, barBelow = true, barSmooth = true, barTone = GUIDE,
        }
        if I.PushReplace then pcall(I.PushReplace, I, item) else I:Push(item) end
    end)
end

-- the window Polestar shows, out of sight when you would rather use Island's panel. It stays shown (the
-- guide keeps working either way); it is only made invisible and tiny, as with RestedXP's.
function PS:ApplyWindow()
    local f = _G.PolestarGuideFrame
    if type(f) ~= "table" or not f.SetAlpha then return end
    local P = Core()
    if P and ns.db and ns.db.polestarHideWindow then
        if f:GetAlpha() ~= 0 then f:SetAlpha(0) end
        if f.SetScale and f:GetScale() ~= 0.001 then f:SetScale(0.001) end
        self.windowHidden = true
    elseif self.windowHidden then
        self.windowHidden = nil
        local sc = P and tonumber(Try(P.Get, "ui.scale")) or 1
        local op = P and tonumber(Try(P.Get, "ui.opacity")) or 1
        if f.SetScale then f:SetScale(sc > 0 and sc or 1) end
        f:SetAlpha(min(1, max(0.1, op)))
    end
end

function PS:Apply()
    self:Refresh()
    self:SetBubble()
    self:ApplyWindow()
end

-- messages can be missed, so the guide is also read once a few times a second
function PS:Poll()
    if not (ns.db and I.built) then return end
    local P = Core()
    local g = P and Try(P.Engine.GetGuide)
    if type(g) ~= "table" then
        if self.g or self.step then
            self.g, self.guide, self.step, self.idx = nil, nil, nil, nil
            self:SetBubble()
        end
        return
    end
    if g ~= self.g then
        self.g, self.idx, self.lastCard = g, nil, nil
        self.quiet = GetTime() + 1.5          -- the step a guide starts on is not news
        self.step = nil
        I:SetActivity("polestep", nil)
    end
    local idx = Try(P.Engine.GetStepIndex)
    if type(idx) == "number" and idx ~= self.idx then
        self.idx = idx
        self:StepActivated()
    end
    if self.step and not (ns.db.polestarStepBubble and self.shownBubble) then self:SetBubble() end
    self:ApplyWindow()
end

-- ---------------------------------------------------------------- the panel (see R.pv in Nav.lua)

-- what a step mostly asks of you, for the small icon on its tile
local KIND = {
    accept = "accept", turnin = "turnin",
    complete = "do", kill = "do", collect = "do", use = "do", interact = "do", talk = "do", cast = "do",
    craft = "do", learn = "do", destroy = "do", abandon = "do",
    ["goto"] = "go", fly = "go", hearth = "go", getfp = "go", enter = "go", explore = "go", sethome = "go",
    train = "train", vendor = "vendor", buy = "vendor",
}

local cache = {}

-- every step Polestar shows for this character, as the panel lists them
local function BuildSteps(P, g, n)
    local E = P.Engine
    local steps = {}
    local ad = { ps = true, key = g.id, title = g.title, steps = steps, total = n }
    local cur = Try(E.GetStepIndex)
    for i = 1, n do
        local view = Try(E.GetStepView, i)
        if type(view) == "table" and view.status ~= "na" then
            local lines, seen, kind = {}, {}, nil
            local title = type(view.title) == "string" and Plain(view.title, 160) or ""
            if title ~= "" then lines[1] = title seen[title] = true end
            for _, gl in ipairs(view.goals or {}) do
                if gl.status ~= "na" and not gl.folded then
                    local k = KIND[gl.t]
                    if k and kind ~= "turnin" and kind ~= "accept" and kind ~= "do" then
                        if k == "turnin" or k == "accept" or k == "do" or not kind then kind = k end
                    end
                    if #lines < 5 and type(gl.text) == "string" then
                        local t = Plain(gl.text, 160)
                        if t ~= "" and not seen[t] then seen[t] = true lines[#lines + 1] = t end
                    end
                end
            end
            if #lines == 0 then lines[1] = L["Guide step"] end
            steps[#steps + 1] = {
                ps = true, index = i, title = lines[1], lines = lines, kind = kind,
                completed = view.status == "done" or view.status == "skipped" or view.skipped or nil,
            }
            if i == cur then ad.curPos = #steps end
        end
    end
    return ad
end

-- the guide and the current step for the panel; rebuilt only when Polestar's position in the guide changes
function PS.Data()
    local P = Core()
    local g = P and Try(P.Engine.GetGuide)
    if type(g) ~= "table" or type(g.steps) ~= "table" then return nil, nil end
    local E = P.Engine
    local cur = Try(E.GetStepIndex)
    local live = Try(E.GetLiveStep)
    local done = Try(E.GetProgress)
    local n = Try(E.GetStepCount) or #g.steps
    if cache.g ~= g or cache.cur ~= cur or cache.live ~= live or cache.done ~= done or cache.n ~= n or not cache.ad then
        cache.g, cache.cur, cache.live, cache.done, cache.n = g, cur, live, done, n
        cache.ad = BuildSteps(P, g, n)
        cache.step = nil
        for _, st in ipairs(cache.ad.steps) do
            if st.index == cur then cache.step = st break end
        end
    end
    return cache.ad, cache.step
end

function PS.Sync() PS.Data() end

PS.GoToStep = function(n)
    local P = Core()
    if not (P and type(n) == "number") then return false end
    Try(P.Engine.Goto, n)
    return true
end
PS.Current = function() local P = Core() return P and Try(P.Engine.GetStepIndex) or nil end
PS.Prev = function() local P = Core() if P then Try(P.Engine.Prev) end return true end
PS.Next = function() local P = Core() if P then Try(P.Engine.Next) end return true end
PS.Skip = function() local P = Core() if P then Try(P.Engine.Skip) end return true end

PS.LoadGuide = function(entry)
    local P = Core()
    if not (P and entry and entry.id) then return false end
    local E = P.Engine
    local opened = Try(E.OpenTab, entry.id, true)
    if not opened then return Try(E.SetGuide, entry.id) and true or false end
    return true
end

-- the guides Polestar has, in groups by category
function PS.Entries()
    local out, groups, by = {}, {}, {}
    local P = Core()
    local list = P and P.Guides and Try(P.Guides.List)
    if type(list) ~= "table" then return out, groups end
    for _, h in ipairs(list) do
        if type(h) == "table" and h.id and type(h.title) == "string" then
            local cat = (type(h.category) == "string" and h.category ~= "") and h.category or "Leveling"
            local grp = by[cat]
            if not grp then
                grp = { group = cat, name = Plain(L[cat], 50), list = {}, weight = 0 }
                by[cat] = grp
                groups[#groups + 1] = grp
            end
            local sub = ""
            if tonumber(h.minLevel) and tonumber(h.maxLevel) then sub = ("%d-%d"):format(h.minLevel, h.maxLevel) end
            if type(h.zoneName) == "string" and h.zoneName ~= "" then
                sub = sub ~= "" and (h.zoneName .. "  " .. sub) or h.zoneName
            end
            local e = { guide = { key = h.id }, id = h.id, name = Plain(h.title, 56), group = cat, groupName = grp.name, sub = Plain(sub, 40) }
            grp.list[#grp.list + 1] = e
            out[#out + 1] = e
        end
    end
    table.sort(groups, function(x, y) if x.name == "Leveling" or y.name == "Leveling" then return x.name == "Leveling" and y.name ~= "Leveling" end return x.name < y.name end)
    return out, groups
end

PS.Options = function()
    local P = Core()
    if P and type(P.Fire) == "function" then
        local ok = pcall(P.Fire, "SHOW_OPTIONS")
        if ok then return true end
    end
    ns.Print(L["Could not open Polestar's options. Type /polestar options to find them."])
    return false
end

-- ---------------------------------------------------------------- listening, debug

function PS:Debug()
    local P = Core()
    if not P then ns.Print("Polestar: not loaded") return end
    local f = ArrowFrame()
    local t = Try(P.Nav.GetTarget)
    local ok, state, dist = pcall(P.Nav.Sample)
    ns.Print(string.format("Polestar arrow: frame %s, shown %s, hidden by BanzaiSland %s",
        tostring(f ~= nil), tostring(f and f:IsShown() or false), tostring(PS.arrowHidden == true)))
    if type(t) == "table" then
        ns.Print(string.format("Polestar target: %s, map %s, x %s, y %s, state %s, distance %s, map used %s",
            tostring(t.label), tostring(t.map), tostring(t.x), tostring(t.y), ok and tostring(state) or "error",
            tostring(dist), tostring(t.map and ns.Nav.StepMap({ map = t.map }, "polestar"))))
    else
        ns.Print("Polestar target: none")
    end
    local okv, vd, vdir = pcall(PS.Vector)
    ns.Print(string.format("Polestar bubble direction: %s (distance %s), island arrow rotating %s",
        okv and tostring(vdir) or "error", okv and tostring(vd) or "-", tostring(ns.Nav and ns.Nav.dir ~= nil)))
    local N = ns.Nav
    local pin = N and N.pin
    local okg, facing = pcall(GetPlayerFacing)
    ns.Print(string.format("BanzaiSland bubble: pin %s, src %s, rxp %s, dir %s, rot %s, frame shown %s, arrow %s, facing %s, muted %s",
        tostring(pin ~= nil), tostring(pin and pin.src), tostring(pin and pin.rxp), tostring(N and N.dir), tostring(N and N.rot),
        tostring(N and N.frame and N.frame:IsShown()), tostring(N and N.frame and N.frame.arrow ~= nil),
        okg and tostring(facing) or "error", tostring(N and N.muted ~= nil)))
    self:Refresh()
    local g, st = self.guide, self.step
    local done, total = Try(P.Engine.GetProgress)
    ns.Print(string.format("Polestar: listening %s, island built %s, guide %s, step %s, progress %s/%s, bubble on %s, card on %s, nav on %s, window hidden %s",
        tostring(self.hooked == true), tostring(I.built == true), g and tostring(g.title) or "none",
        st and tostring(Index(st)) or "none", tostring(done), tostring(total), tostring(ns.db and ns.db.polestarStepBubble),
        tostring(ns.db and ns.db.polestarStepCards), tostring(ns.db and ns.db.navPolestar), tostring(self.windowHidden == true)))
end

-- Polestar's own messages say a step or guide changed; look soon after (it settles its state just after)
function PS:Hook()
    if self.hooked then return true end
    local P = Core()
    if not (P and type(P.On) == "function") then return false end
    local function soon()
        if C_Timer and C_Timer.After then C_Timer.After(0.05, function() pcall(PS.Poll, PS) end) end
    end
    local ok = true
    for _, msg in ipairs({ "STEP_CHANGED", "GUIDE_CHANGED", "STEP_SKIPPED", "PLAYER_SKIPPED_STEP" }) do
        if not pcall(P.On, msg, soon) then ok = false end
    end
    self.hooked = ok
    return ok
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" and name ~= "Polestar" then return end
        if event == "PLAYER_ENTERING_WORLD" then PS.quiet = GetTime() + 4 end
        for _, d in ipairs({ 0, 1, 4 }) do C_Timer.After(d, function() PS:Hook() end) end
    end)
    local acc = 0
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.3 then return end
        acc = 0
        if not _G.Polestar then return end
        if not PS.hooked then PS:Hook() end
        pcall(PS.Poll, PS)
    end)
end
