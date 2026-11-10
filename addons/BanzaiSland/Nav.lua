-- Island: a small navigation bubble. When a spot is pinned (a RareScanner find, a rare you spotted,
-- or /island way), a round bubble beside the island points to it and counts down the distance.
-- Click it to clear the pin. It works on its own; TomTom, if installed, gets the same pin too.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local I, C = ns.Island, ns.C
local floor, max, min, sqrt, atan2 = math.floor, math.max, math.min, math.sqrt, math.atan2 or math.atan
local abs = math.abs
local BLUE = { 0.40, 0.72, 1.00 }
local ARRIVE = 8                 -- yards
local H = 36

local N = { a = 0 }
ns.Nav = N

local function Readable(v) return v ~= nil and ns.Readable(v) end

-- ---------------------------------------------------------------- where things are

local function PlayerSpot()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not Readable(map) or not map then return nil end
    local ok2, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if not ok2 or not pos then return nil end
    local x, y = pos.x, pos.y
    if pos.GetXY then x, y = pos:GetXY() end
    if not (Readable(x) and Readable(y)) or (x == 0 and y == 0) then return nil end
    return map, x, y
end

-- the pin's position on the player's map (maps of different sizes nest inside each other)
local function OnMap(pin, map)
    if pin.map == map then return pin.x, pin.y end
    if C_Map and C_Map.GetMapRectOnMap then
        local ok, l, r, t, b = pcall(C_Map.GetMapRectOnMap, pin.map, map)
        if ok and l and r and r ~= l then return l + pin.x * (r - l), t + pin.y * (b - t) end
    end
end

local function WorldSize(map)
    if not (C_Map and C_Map.GetMapWorldSize) then return nil end
    local ok, w, h = pcall(C_Map.GetMapWorldSize, map)
    if ok and w and w > 0 and h and h > 0 then return w, h end
end

-- ---------------------------------------------------------------- TomTom
-- With TomTom installed the bubble follows TomTom's arrow, whatever set it: a quest addon, /way,
-- a rare, your corpse. TomTom works out the direction and distance; the bubble just shows them.

local function TT() local t = _G.TomTom return type(t) == "table" and t or nil end

local function TomTomVector(uid)
    local t = TT()
    if not (t and t.GetVectorToWaypoint) then return nil end
    local ok, angle, dist = pcall(t.GetVectorToWaypoint, t, uid)
    if ok and type(angle) == "number" and type(dist) == "number" then return dist, angle end
end

local function TomTomDistanceText(dist)
    local t = TT()
    if t and t.GetFormattedDistance then
        local ok, text = pcall(t.GetFormattedDistance, t, dist)
        if ok and type(text) == "string" then return (text:gsub("%s+away$", "")) end
    end
end

-- TomTom's own arrow, kept out of sight while the island shows the way (it still does its work)
local function TomTomFrame() return _G.TomTomCrazyArrow end
function N:ApplyTomTomArrow()
    local f = TomTomFrame()
    if type(f) ~= "table" or not f.SetAlpha then return end
    local hide = ns.db and ns.db.navTomTom and ns.db.navHideTomTom and self.pin and self.pin.uid ~= nil
    f:SetAlpha(hide and 0 or 1)
    if f.EnableMouse then pcall(f.EnableMouse, f, not hide) end
end

local function HookTomTom()
    local t = TT()
    if not t or N.hooked or not hooksecurefunc or not t.SetCrazyArrow then return end
    N.hooked = true
    hooksecurefunc(t, "SetCrazyArrow", function(_, uid, dist, title)
        if not (ns.db and ns.db.navTomTom) then return end
        local where
        if type(uid) == "table" and uid[1] and C_Map and C_Map.GetMapInfo then
            local ok, info = pcall(C_Map.GetMapInfo, uid[1])
            if ok and info and info.name then where = string.format("%s  %.1f, %.1f", info.name, (uid[2] or 0) * 100, (uid[3] or 0) * 100) end
        end
        N.pin = { uid = uid, title = title or (type(uid) == "table" and uid.title) or L["TomTom waypoint"], where = where, arrive = dist }
        N.lastText, N.host, N.near = nil, nil, nil
        -- this can happen before the island is built (TomTom restores its waypoints at login):
        -- the pin is kept and the bubble appears as soon as it can
        N:Build()
        if N.frame then N.frame:Show() end
        N:ApplyTomTomArrow()
    end)
    local f = TomTomFrame()
    if f and f.HookScript then
        f:HookScript("OnShow", function() N:ApplyTomTomArrow() end)
    end
end
N.HookTomTom = HookTomTom

-- ---------------------------------------------------------------- RestedXP Guides
-- RestedXP Guides keeps its own arrow (the frame RXPG_ARROW) pointing at the current step. When
-- nothing else is pinned, the bubble follows that arrow too. The guide decides where to point; the
-- bubble only shows the direction and distance, and clicking it hides it until the step changes.

-- RestedXP's text with its colour codes, icons and line breaks taken out
function ns.RXPPlain(t, limit)
    if type(t) ~= "string" then return "" end
    t = t:gsub("|cRXP_[A-Z]+_", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("RXP_[A-Z]+_", "")
    t = t:gsub("|T.-|t", ""):gsub("\\n", " "):gsub("\n", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if limit and #t > limit then t = t:sub(1, limit):gsub("[\192-\255][\128-\191]*$", "") .. "..." end
    return t
end

local function RXPFrame() local f = _G.RXPG_ARROW return type(f) == "table" and f or nil end

local function RXPElement()
    local f = RXPFrame()
    if not (f and f.IsShown and f:IsShown() and not f.wrongContinent) then return nil end
    local e = f.element
    if type(e) == "table" and type(e.wx) == "number" and type(e.wy) == "number" then return e end
end

local function RXPTitle(e)
    local step = type(e.step) == "table" and e.step or nil
    local t = e.title or (step and (step.arrowtext or step.title or (step.index and ("Step " .. step.index)))) or nil
    if type(t) ~= "string" then return L["Guide step"] end
    t = ns.RXPPlain(t, 60)
    return t ~= "" and t or L["Guide step"]
end

-- the arrow's own frame: out of sight while the bubble shows the way (RestedXP still does its work)
function N:ApplyRXPArrow()
    if ns.PS then ns.PS.ApplyArrow(self) end             -- Polestar's arrow, when that is the guide in use
    local f = RXPFrame()
    if not f or not f.SetAlpha then return end
    -- hidden while the bubble shows the way, and also after a right-click hid the bubble, until the next step
    local silenced = self.muted and RXPElement() == self.muted
    local hide = ns.db and ns.db.navRXP and ns.db.navHideRXP and ((self.pin and self.pin.rxp and self.pin.src ~= "polestar") or silenced)
    if hide then
        if f:GetAlpha() ~= 0 then f:SetAlpha(0) end
        self.rxpHidden = true
    elseif self.rxpHidden then
        self.rxpHidden = nil
        f:SetAlpha(f.alpha or 1)
    end
end

-- the world map, at the guide step's spot (a second click closes it again)
-- the map the step is on: the element's own map, RestedXP's lookup of its zone name, or the zone you stand in
local function StepMap(e, src)
    if type(e) ~= "table" then return nil end
    if src == "polestar" then
        local pm = tonumber(e.map)
        if pm then return pm end
    end
    local m = tonumber(e.zone) or tonumber(e.mapId) or tonumber(e.mapID) or tonumber(e.fixedMapID)
    if m then return m end
    local a = ns.RXPAddon and ns.RXPAddon()
    if a and a.GetMapId and type(e.zone) == "string" then
        local ok, r = pcall(a.GetMapId, e.zone)
        if ok and tonumber(r) then return tonumber(r) end
    end
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, r = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and tonumber(r) then return tonumber(r) end
    end
end
N.StepMap = StepMap

function N:OpenMap(pin)
    local map = StepMap(pin and pin.element, pin and pin.src)
    local wm = _G.WorldMapFrame
    if not (map and type(wm) == "table" and wm.Show) then return false end
    if wm.IsShown and wm:IsShown() then
        local ok, cur = pcall(function() return wm.GetMapID and wm:GetMapID() end)
        if ok and cur == map then
            if type(_G.HideUIPanel) == "function" then pcall(_G.HideUIPanel, wm) else pcall(wm.Hide, wm) end
            return true
        end
    end
    -- open it the way the game's own map key does: showing the frame bare can play the sound and show
    -- nothing the first time, before the map has been opened properly once
    if type(_G.OpenWorldMap) == "function" then pcall(_G.OpenWorldMap, map)
    elseif type(_G.ShowUIPanel) == "function" then pcall(_G.ShowUIPanel, wm)
    elseif type(_G.ToggleWorldMap) == "function" and not (wm.IsShown and wm:IsShown()) then pcall(_G.ToggleWorldMap)
    else pcall(wm.Show, wm) end
    if wm.SetMapID then pcall(wm.SetMapID, wm, map) end
    -- the first time, the map is still setting itself up: set the zone again a moment later
    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, function()
            if wm.IsShown and wm:IsShown() and wm.SetMapID then pcall(wm.SetMapID, wm, map) end
        end)
    end
    return true
end

-- the guide arrow that is up for one guide addon: RestedXP's, or Polestar's
local function ElementOf(src)
    if not ns.db then return nil end
    if src == "polestar" then
        if ns.db.navPolestar and ns.PS then return ns.PS.Element() end
    elseif ns.db.navRXP then
        return RXPElement()
    end
end

-- whichever guide holds the bubble keeps it while its arrow is up; otherwise RestedXP's comes first
local function GuideElement(prefer)
    local first, second = "rxp", "polestar"
    if prefer == "polestar" then first, second = second, first end
    local e = ElementOf(first)
    if e then return e, first end
    e = ElementOf(second)
    if e then return e, second end
end

-- start, update or end the guide pin; called a few times a second
function N:CheckRXP()
    local pin = self.pin
    if pin and not pin.rxp then return end              -- a pin you set yourself comes first
    local e, src = GuideElement(pin and pin.src)
    if not e or e == self.muted then
        if pin then self:Clear() end
        if not e then self.muted = nil end
        return
    end
    if not pin or pin.element ~= e then
        self.pin = { rxp = true, src = src, element = e, title = src == "polestar" and ns.PS.Title(e) or RXPTitle(e) }
        self.lastText, self.near, self.dir, self.rot = nil, nil, nil, nil
        self:Build()
        if self.frame then self.frame:Show() end
    end
    self:ApplyRXPArrow()
end

local function RXPVector(e)
    local HBD = _G.LibStub and _G.LibStub("HereBeDragons-2.0", true)
    if HBD and HBD.GetPlayerWorldPosition and HBD.GetWorldVector then
        local ok, x, y, inst = pcall(HBD.GetPlayerWorldPosition, HBD)
        if ok and x then
            local ok2, angle, dist = pcall(HBD.GetWorldVector, HBD, inst, x, y, e.wx, e.wy)
            if ok2 and type(angle) == "number" and type(dist) == "number" then return dist, angle end
        end
    end
    -- without the library, take what the arrow itself worked out
    local f = RXPFrame()
    local ok, facing = pcall(GetPlayerFacing)
    if f and ok and type(facing) == "number" and type(f.orientation) == "number" and type(f.distance) == "number" then
        return f.distance, f.orientation + facing
    end
end

-- yards to the pin and its direction (radians, 0 = north, turning left), or nil
local function Vector()
    local pin = N.pin
    if pin and pin.rxp then
        if pin.src == "polestar" then
            if not ns.PS then return nil end
            return ns.PS.Vector()          -- both values: the distance and the direction
        end
        return RXPVector(pin.element)
    end
    if pin and pin.uid ~= nil then return TomTomVector(pin.uid) end
    local map, px, py = PlayerSpot()
    if not (pin and map) then return nil end
    local tx, ty = OnMap(pin, map)
    if not tx then return nil end
    local w, h = WorldSize(map)
    w, h = w or 1000, h or 667
    local east, south = (tx - px) * w, (ty - py) * h
    -- facing works the same way: 0 is north and it grows turning left (west)
    return sqrt(east * east + south * south), atan2(-east, -south)
end

-- ---------------------------------------------------------------- the bubble

function N:Build()
    if self.frame or not I.built then return end
    local f = CreateFrame("Button", nil, I.anchor)
    f:SetFrameLevel(I.anchor:GetFrameLevel() + 2)
    f:SetSize(H, H)
    f.body = ns.CreateBody(f, "BACKGROUND", 0)
    f.body:SetStyle(ns.db.lookStyle, ns.db.opacity or 1)
    f.body:SetRadius(H / 2)
    f.arrow = ns.Image(f, "Nav", "ARTWORK", 1)
    f.arrow:SetSize(16, 16)
    f.arrow:SetPoint("CENTER", f, "LEFT", H / 2, 0)
    f.arrow:SetVertexColor(BLUE[1], BLUE[2], BLUE[3], 1)
    f.text = ns.Text(f, "bold", 12.5, C.fg)
    f.text:SetPoint("LEFT", f, "LEFT", H - 4, 0)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:SetScript("OnClick", function(_, button)
        local pin, t = N.pin, TT()
        if pin and pin.rxp then
            -- a click opens the map at the step's spot; a right-click hides the bubble until the guide points elsewhere
            if button ~= "RightButton" then
                if not N:OpenMap(pin) then ns.Print(L["Could not open the map for this step."]) end
                return
            end
            N.muted = pin.element
        end
        if pin and pin.uid ~= nil and t then
            if t.RemoveWaypoint then pcall(t.RemoveWaypoint, t, pin.uid) end
            if t.SetClosestWaypoint and t.profile and t.profile.arrow and t.profile.arrow.setclosest then pcall(t.SetClosestWaypoint, t) end
        end
        N:Clear()
    end)
    f:SetScript("OnEnter", function(self)
        if not (GameTooltip and N.pin) then return end
        ns.PlaceTip(GameTooltip, self, "BOTTOM")
        GameTooltip:SetText(N.pin.title or L["Map pin"], 1, 1, 1)
        if N.pin.where then GameTooltip:AddLine(N.pin.where, 0.7, 0.72, 0.78) end
        GameTooltip:AddLine(N.pin.rxp and L["Click: open the map  ·  Right-click: hide until the next step"] or L["Click to clear"], 0.6, 0.62, 0.7)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    f:SetScript("OnUpdate", function(_, dt) N:OnUpdate(dt) end)
    f:SetAlpha(0)
    f:Hide()
    self.frame = f
end

function N:OnUpdate(dt)
    local f = self.frame
    -- fade in, or out once cleared
    local want = self.pin and 1 or 0
    if self.a ~= want then
        self.a = want > self.a and min(1, self.a + dt / 0.2) or max(0, self.a - dt / 0.2)
        f:SetAlpha(self.a)
        if self.a == 0 then f:Hide() return end
    end
    -- sit beside the last activity bubble when any are out, otherwise beside the island
    I:PlaceNav(f)
    -- The arrow turns every frame. The direction to the pin barely changes from one frame to the
    -- next, but your facing can swing fast with the mouse, so facing is read every frame and the
    -- arrow eases toward it along the shortest way round, which keeps fast camera turns smooth.
    if self.pin and self.dir then
        local ok, facing = pcall(GetPlayerFacing)
        if ok and Readable(facing) and type(facing) == "number" then
            local want = self.dir - facing
            local cur = self.rot or want
            local diff = (want - cur + math.pi) % (2 * math.pi) - math.pi
            cur = cur + diff * min(1, dt * 22)
            self.rot = cur
            f.arrow:SetRotation(cur)
        end
    end
    self.t = (self.t or 0) + dt
    if self.t < 0.1 or not self.pin then return end
    self.t = 0
    if self.pin.rxp then
        self:CheckRXP()
        if not self.pin then return end
    end
    -- a TomTom pin ends when TomTom lets go of it (arrived, removed, or replaced)
    if self.pin.uid ~= nil then
        local t = TT()
        local ok, empty = pcall(function() return t and t:IsCrazyArrowEmpty() end)
        if not t or (ok and empty) then
            local title, near = self.pin.title, self.near
            self:Clear()
            if near then
                I:PushCard({ kind = "won", key = "nav", glyph = "Check", tone = BLUE, cap = L["ARRIVED"], capColor = BLUE,
                             title = title or L["Waypoint"], color = C.fg, hold = 2.4 })
            end
            return
        end
    end
    local dist, dir = Vector()
    local text
    if dist then
        self.dir = dir
        text = (self.pin.uid ~= nil and TomTomDistanceText(dist))
            or (dist >= 1000 and string.format(L["%.1fk yd"], dist / 1000) or L["%d yd"]:format(floor(dist + 0.5)))
        self.near = dist < (self.pin.arrive or 15) + 10
        if self.pin.uid == nil and not self.pin.rxp and dist < ARRIVE then
            local title = self.pin.title
            self:Clear()
            I:PushCard({ kind = "won", key = "nav", glyph = "Check", tone = BLUE, cap = L["ARRIVED"], capColor = BLUE,
                         title = title or L["Map pin"], color = C.fg, hold = 2.4 })
            return
        end
    else
        self.dir = nil
        text = L["far"]                      -- another continent, or a place the map cannot place you
    end
    if text ~= self.lastText then
        self.lastText = text
        f.text:SetText(text)
        local w = H - 4 + (f.text:GetStringWidth() or 30) + 13
        f:SetWidth(w)
        f.body:SetRadius(H / 2)
    end
end

-- ---------------------------------------------------------------- pins

-- map: the map ID; x, y: 0-1 (or 0-100)
function N:Set(map, x, y, title, where)
    if not (map and x and y) then return end
    if x > 1 or y > 1 then x, y = x / 100, y / 100 end
    self:Build()
    if not self.frame then return end
    self.pin = { map = map, x = x, y = y, title = title, where = where }
    self.lastText, self.host = nil, nil
    self.frame:Show()
end

function N:Clear()
    self.pin, self.dir, self.rot = nil, nil, nil
    self:ApplyTomTomArrow()
    self:ApplyRXPArrow()
end

-- where you are standing, as a pin, or nil
function N.Here()
    local map, x, y = PlayerSpot()
    if map then return { map = map, x = x, y = y } end
end

-- pin where you are standing right now
function N:SetHere(title)
    local map, x, y = PlayerSpot()
    if map then self:Set(map, x, y, title) return true end
end

function ns.DemoNav()
    local map, x, y = PlayerSpot()
    if not map then ns.Print(L["the map cannot place you here."]) return end
    N:Set(map, min(0.99, x + 0.03), max(0.01, y - 0.03), L["Sample pin"])
end

-- TomTom may have pointed its arrow before Island was listening (after a /reload it restores its
-- waypoints straight away). Pick that arrow up: TomTom does not say which waypoint it is, so take
-- the closest one, which is what TomTom itself points at by default.
local function Adopt()
    local t = TT()
    if not (t and ns.db and ns.db.navTomTom) or (N.pin and N.pin.uid ~= nil) then return end
    local ok, empty = pcall(function() return t:IsCrazyArrowEmpty() end)
    if not ok or empty then return end
    local ok2, uid = pcall(function() return t.GetClosestWaypoint and t:GetClosestWaypoint() end)
    if not ok2 or uid == nil then return end
    local f = TomTomFrame()
    local title = f and f.title and f.title.GetText and f.title:GetText() or nil
    N.pin = { uid = uid, title = title or (type(uid) == "table" and uid.title) or L["TomTom waypoint"] }
    N.lastText, N.host, N.near = nil, nil, nil
    N:Build()
    if N.frame then N.frame:Show() end
    N:ApplyTomTomArrow()
end

HookTomTom()        -- TomTom loads first when installed, so it can be hooked right away

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
local poll = 0
ev:SetScript("OnUpdate", function(_, dt)
    poll = poll + dt
    if poll < 0.3 then return end
    poll = 0
    if N.pin and N.pin.rxp or not N.pin then
        local ok = pcall(N.CheckRXP, N)
    end
end)
ev:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == "TomTom" then HookTomTom() end
        return
    end
    HookTomTom()
    -- show a pin that arrived before the island was built, then look for an arrow already up
    C_Timer.After(0.5, function()
        if N.pin then N:Build() if N.frame then N.frame:Show() end N:ApplyTomTomArrow() end
        Adopt()
    end)
    C_Timer.After(3, Adopt)
end)

-- ---------------------------------------------------------------- RestedXP Guides: step cards and bubbles
-- RestedXP announces each step it starts and finishes (messages on its own AceEvent bus). Island
-- listens: a card when a new step starts, a bubble that holds the current step with the guide's
-- progress along its bottom, and a short bubble when a step is done. Island only shows these;
-- it never completes, skips or clicks anything in the guide.

local PURPLE = { 0.70, 0.55, 1.00 }
-- GUIDE is the step accent. It is one shared table that Polestar.lua also uses: SyncTone() rewrites it in
-- place (purple in the Modern style, the Forever bronze gold otherwise), so the bubble and cards follow.
local GUIDE = { PURPLE[1], PURPLE[2], PURPLE[3] }
local function Forever() return ns.db and ns.db.lookStyle == "forever" and ns.ForeverPalette and true or false end
local function Pal(key) return Forever() and ns.ForeverPalette[key] or C[key] end
local function SyncTone()
    local src = Forever() and ns.ForeverPalette.gold or PURPLE
    GUIDE[1], GUIDE[2], GUIDE[3] = src[1], src[2], src[3]
end
local DONE = { 0.36, 0.85, 0.45 }
local R = { guide = nil, step = nil, quiet = 0 }
ns.RXP = R
R.GUIDE = GUIDE
R.SyncTone = function() SyncTone() end

local function RXPAddon()
    local AA = _G.LibStub and _G.LibStub("AceAddon-3.0", true)
    if not AA then return nil end
    local ok, a = pcall(AA.GetAddon, AA, "RXPGuides", true)
    if ok and type(a) == "table" then return a end
end

ns.RXPAddon = RXPAddon

local function GuideName(guide)
    if type(guide) == "table" and guide.ps then          -- a Polestar guide
        local pn = type(guide.title) == "string" and ns.RXPPlain(guide.title, 40) or ""
        return pn ~= "" and pn or L["Guide"]
    end
    local a = RXPAddon()
    if a and a.GetGuideName then
        local ok, n = pcall(a.GetGuideName, guide)
        if ok and type(n) == "string" and n ~= "" then return ns.RXPPlain(n, 40) end
    end
    local n = type(guide) == "table" and (guide.displayname or guide.name)
    return type(n) == "string" and ns.RXPPlain(n, 40) or L["Guide"]
end

-- the step's name: its title, else the first line of what to do
local function StepText(step)
    if type(step) ~= "table" then return L["Guide step"] end
    local t = type(step.title) == "string" and ns.RXPPlain(step.title, 60) or ""
    if t == "" then
        for _, e in ipairs(step.elements or step) do
            if type(e) == "table" and type(e.text) == "string" then
                t = ns.RXPPlain(e.text, 60)
                if t ~= "" then break end
            end
        end
    end
    if t == "" and type(step.arrowtext) == "string" then t = ns.RXPPlain(step.arrowtext, 60) end
    return t ~= "" and t or L["Guide step"]
end

-- how far along the guide is: steps before this one over all steps
local function GuideProgress()
    local g, st = R.guide, R.step
    if type(g) ~= "table" or type(g.steps) ~= "table" or type(st) ~= "table" or type(st.index) ~= "number" then return 0 end
    local n = #g.steps
    if n <= 0 then return 0 end
    return max(0, min(1, (st.index - 1) / n))
end

local function Index(step) return type(step) == "table" and type(step.index) == "number" and step.index or nil end

-- for the Polestar module (Polestar.lua), which shows its steps the same way
R.util = { StepText = StepText, GuideName = GuideName, Index = Index }

function R:SetBubble()
    SyncTone()
    if not (ns.db and ns.db.rxpStepBubble and self.step and Index(self.step)) then
        I:SetActivity("rxpstep", nil)
        self.shownBubble = nil
        return
    end
    self.shownBubble = true
    I:SetActivity("rxpstep", {
        glyph = "Compass", tone = GUIDE, priority = 2,
        tip = GuideName(self.guide), tip2 = StepText(self.step),
        text = function() return L["Step %d"]:format(Index(R.step) or 0) end,
        native = true, noEase = false,
        click = function() R:ToggleDrawer() end, clickHint = L["Click: guide steps"],
        extPin = true,                      -- beside the island by default (the shelf can unpin it)
        progress = ns.db.rxpStepBubbleBar ~= false and GuideProgress or nil,
    })
end

function R:StepActivated(_, step, guide)
    if not ns.db or not Index(step) or step.tip then return end
    -- RestedXP can run through several steps in a moment (a skipped step may pass over ones that are
    -- already done) and can start several at once: what counts is the step the guide rests on
    local g, cur = self:CurrentStep()
    if g and cur then guide, step = g, cur end
    self.guide, self.step = guide, step
    self:SetBubble()
    if self.D and self.D.frame and self.D.frame:IsShown() then self:RefreshDrawer() end
    if not ns.db.rxpStepCards then return end
    local now = GetTime()
    if now < (self.quiet or 0) then return end
    -- one card, once things have settled for a moment, for the step the guide is on by then
    self.seq = (self.seq or 0) + 1
    local mine = self.seq
    C_Timer.After(0.4, function()
        if R.seq ~= mine then return end
        local g2, cur2 = R:CurrentStep()
        if g2 and cur2 then R.guide, R.step = g2, cur2 end
        local st = R.step
        if not st or not ns.db or not ns.db.rxpStepCards or ns.db.dnd then return end
        local key = (R.guide and R.guide.key or "") .. ":" .. (Index(st) or 0)
        if R.lastCard == key then return end
        R.lastCard = key
        local item = {
            kind = "won", key = "rxpstep", builderType = "progress", glyph = "Compass", tone = GUIDE,
            cap = L["STEP %d"]:format(Index(st) or 0), capColor = GUIDE, title = StepText(st), line = GuideName(R.guide),
            color = C.fg, hold = 4,
            progress = GuideProgress, barBelow = true, barSmooth = true, barTone = GUIDE,
        }
        if I.PushReplace then pcall(I.PushReplace, I, item) else I:Push(item) end
    end)
end

function R:StepComplete(_, step)
    if not (ns.db and ns.db.rxpDoneBubble) or not Index(step) then return end
    I:SetActivity("rxpdone", { glyph = "Check", tone = DONE, priority = 1, static = true,
        tip = L["Step done"], tip2 = StepText(step), text = function() return L["Step %d done"]:format(Index(step)) end })
    local mark = GetTime()
    R.doneAt = mark
    C_Timer.After(4, function() if R.doneAt == mark then I:SetActivity("rxpdone", nil) end end)
end

function R:GuideLoaded(_, guide)
    self.guide, self.step = guide, nil
    self.lastCard = nil
    self.quiet = GetTime() + 1.5       -- the steps a guide starts with are not news
    I:SetActivity("rxpstep", nil)
end

function R:Apply()
    self:SetBubble()
    self:ApplyWindow()
end

-- ---------------------------------------------------------------- the guide panel
-- A click on the step bubble opens a panel under the island: the guide's steps (the current one
-- highlighted, finished ones dimmed), with buttons to go back or forward a step, skip the current
-- step, and pick another guide. Clicking a step jumps to it. These buttons call RestedXP's own
-- functions, only when you press them. Nothing here moves on its own.

local D = { W = 420, ROW = 44, BODY = 396, POOL = 9, HEAD = 46, BAR = 32, FOOT = 12, MAXROWS = 6, offset = 0, rows = {}, mode = "steps", query = "" }
D.TOP = D.HEAD + D.BAR
R.D = D

-- the guide and step the panel shows: RestedXP's, or (R.pv set) another guide addon's, see Polestar.lua
local function GS()
    local pv = R.pv
    if pv then return pv.Data() end
    return R.guide, R.step
end

local function Lines(step)
    local out = {}
    if type(step) ~= "table" then return out end
    if step.ps then return step.lines or out end
    local a = RXPAddon()
    -- the lines RestedXP shows for a step live in step.elements (their text, or a tooltip text)
    for _, e in ipairs(step.elements or step) do
        -- the tooltip text is the objective line (counts and all); some lines only have their own text
        local raw = type(e) == "table" and ((not e.hideTooltip and e.tooltipText) or e.rawtext or e.text)
        if type(raw) == "string" and raw ~= "" and raw ~= " " then
            local t = raw
            if a and a.ReplaceNpcIds then
                local ok, r = pcall(a.ReplaceNpcIds, t, e)
                if ok and type(r) == "string" then t = r end
            end
            -- a text with several lines gives several lines here
            for part in (t:gsub("|n", "\n") .. "\n"):gmatch("([^\n]*)\n") do
                part = ns.RXPPlain(part, 160)
                local dup = false
                for _, o in ipairs(out) do if o == part then dup = true end end
                if part ~= "" and not dup then out[#out + 1] = part end
                if #out >= 5 then break end
            end
            if #out >= 5 then break end
        end
    end
    if #out == 0 and type(step.text) == "string" then
        local t = ns.RXPPlain(step.text, 58)
        if t ~= "" then out[1] = t end
    end
    if #out == 0 and type(step.title) == "string" then
        local t = ns.RXPPlain(step.title, 58)
        if t ~= "" then out[1] = t end
    end
    if #out == 0 and step.tip then out[1] = L["Tip"] end
    return out
end
R.Lines = Lines

-- ---- what the buttons do in RestedXP (each guarded: a missing function just does nothing)

local function Call(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok = pcall(fn, ...)
    return ok
end

-- after a button moved the guide, look again soon so the bubble and panel follow at once
local function SoonAgain()
    if not C_Timer then return end
    for _, d in ipairs({ 0.05, 0.25, 0.6 }) do C_Timer.After(d, function() pcall(R.Poll, R) end) end
end

function R:GoToStep(n)
    if self.pv then return self.pv.GoToStep(n) end
    local a, g = RXPAddon(), self.guide
    if not (a and type(g) == "table" and type(g.steps) == "table") then return false end
    n = max(1, min(#g.steps, n))
    local ok = Call(a.SetStep, n)
    SoonAgain()
    return ok
end

function R:CurrentIndex()
    if self.pv then return self.pv.Current() end
    local a = RXPAddon()
    if a and a.GetGuideProgress then
        local ok, n = pcall(a.GetGuideProgress)
        if ok and tonumber(n) then return tonumber(n) end
    end
    return Index(self.step)
end

function R:PreviousStep() if self.pv then return self.pv.Prev() end local c = self:CurrentIndex() if c and c > 1 then return self:GoToStep(c - 1) end end
function R:NextStep() if self.pv then return self.pv.Next() end local c = self:CurrentIndex() local g = self.guide if c and g and c < #g.steps then return self:GoToStep(c + 1) end end

-- the same as ticking every line of the current step in RestedXP's window
function R:SkipStep()
    if self.pv then return self.pv.Skip() end
    local a, st = RXPAddon(), self.step
    if not (a and type(st) == "table" and type(st.elements) == "table") then return false end
    for _, e in ipairs(st.elements) do
        if type(e) == "table" and not e.optional then
            if e.OnComplete and not e.skip then pcall(e.OnComplete, e) end
            e.skip = true
        end
    end
    a.updateSteps = true
    if a.UpdateMap then pcall(a.UpdateMap) end
    SoonAgain()
    return true
end

function R:LoadGuide(entry)
    if self.pv then
        local pok = self.pv.LoadGuide(entry)
        if pok then
            D.mode, D.query, D.offset = "steps", "", 0
            if D.box then D.box:SetText("") end
        end
        return pok
    end
    local a = RXPAddon()
    if not (a and entry and entry.guide) then return false end
    local g = entry.guide
    local ok
    if g.OnClick and a.functions and a.functions[g.OnClick] then ok = pcall(a.functions[g.OnClick], g)
    else ok = pcall(a.LoadGuide, a, g) end
    if ok then
        D.mode, D.query, D.offset = "steps", "", 0
        if D.box then D.box:SetText("") end
        self.lastCard = nil
        SoonAgain()
    end
    return ok
end

-- ---- the guide list: groups, and the guides in them (built once when the list is opened)

local function GuideEntries()
    local a = RXPAddon()
    local out, groups = {}, {}
    if not (a and type(a.guideList) == "table") then return out, groups end
    local ga = type(_G.RXPCData) == "table" and _G.RXPCData.GA
    for group, t in pairs(a.guideList) do
        local c = group:sub(1, 1)
        local wanted = group ~= "RXPGuides" and ((ga and c == "+") or (not ga and c ~= "+" and c ~= "*"))
        if wanted and type(t) == "table" and type(t.names_) == "table" then
            local shown = group
            if a.GroupOverride then
                local ok, r = pcall(a.GroupOverride, group)
                if ok and type(r) == "string" then shown = r end
            end
            shown = ns.RXPPlain(shown, 50)
            local list = {}
            for _, n in ipairs(t.names_) do
                local ok, g = pcall(a.GetGuideTable, n.group, n.name)
                if ok and type(g) == "table" and not g.chapter and not g.disabled then
                    local active = true
                    if a.IsGuideActive then
                        local ok2, r = pcall(a.IsGuideActive, g)
                        active = ok2 and r and true or false
                    end
                    if active then
                        local name = n.name
                        if a.GetGuideName then
                            local ok3, r = pcall(a.GetGuideName, g)
                            if ok3 and type(r) == "string" and r ~= "" then name = r end
                        end
                        local e = { guide = g, name = ns.RXPPlain(name, 56), group = group, groupName = shown,
                                    sub = type(g.subgroup) == "string" and ns.RXPPlain(g.subgroup, 30) or nil }
                        list[#list + 1] = e
                        out[#out + 1] = e
                    end
                end
            end
            if #list > 0 then groups[#groups + 1] = { group = group, name = shown, list = list, weight = tonumber(t.weight_) or 0 } end
        end
    end
    table.sort(groups, function(x, y) if x.weight == y.weight then return x.name < y.name end return x.weight > y.weight end)
    return out, groups
end

-- what a step mostly asks of you, for the small icon on its tile
local KIND = { accept = "accept", turnin = "turnin", complete = "do", goto = "go", fp = "go", fly = "go", hs = "go", home = "go",
              train = "train", vendor = "vendor", buy = "vendor" }
local KIND_ICON = {
    accept = "Interface\\GossipFrame\\AvailableQuestIcon", turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
    ["do"] = "Interface\\Icons\\Ability_DualWield", train = "Interface\\GossipFrame\\TrainerGossipIcon",
    vendor = "Interface\\GossipFrame\\VendorGossipIcon",
}
local function StepKind(step)
    if type(step) ~= "table" then return nil end
    if step.ps then return step.kind end
    local found
    for _, e in ipairs(step.elements or step) do
        local k = type(e) == "table" and type(e.t) == "string" and KIND[e.t:lower()]
        if k then
            if k == "turnin" or k == "accept" or k == "do" then return k end
            found = found or k
        end
    end
    return found
end

local function Tiles() return not (ns.db and ns.db.navTiles == false) end

local function Rows()
    local items = {}
    local g, gstep = GS()
    if D.mode == "steps" then
        local steps = type(g) == "table" and type(g.steps) == "table" and g.steps or {}
        local cur = Index(gstep)
        for i, st in ipairs(steps) do
            if type(st) == "table" then
                local lines = Lines(st)
                items[#items + 1] = { num = tostring(Index(st) or i), name = lines[1] or "", sub = #lines > 1 and table.concat(lines, "\n", 2) or "",
                                      cur = cur and Index(st) == cur, dim = st.completed and not (cur and Index(st) == cur),
                                      kind = StepKind(st), click = function() R:GoToStep(Index(st) or i) end }
            end
        end
        return items
    end
    if not D.index then D.index, D.groups = (R.pv and R.pv.Entries or GuideEntries)() end
    local q = D.query:lower()
    local curKey = type(g) == "table" and g.key
    if q ~= "" then
        for _, e in ipairs(D.index) do
            if e.name:lower():find(q, 1, true) or e.groupName:lower():find(q, 1, true) then
                items[#items + 1] = { num = "", name = e.name, sub = e.groupName, cur = curKey and e.guide.key == curKey,
                                      click = function() R:LoadGuide(e) end }
            end
        end
    elseif D.mode == "groups" then
        for _, gr in ipairs(D.groups) do
            items[#items + 1] = { num = tostring(#gr.list), name = gr.name, sub = L["Guides in this group"],
                                  click = function() D.mode, D.group, D.offset = "guides", gr, 0 end }
        end
    else
        for _, e in ipairs(D.group and D.group.list or {}) do
            items[#items + 1] = { num = "", name = e.name, sub = e.sub or "", cur = curKey and e.guide.key == curKey,
                                  click = function() R:LoadGuide(e) end }
        end
    end
    return items
end

-- ---- the frame

-- Modern: a translucent white pill. Forever: the same dark bronze plaque as the card buttons.
local function PaintButton(b, hover)
    local fv = Forever()
    if (b.fv or false) ~= fv then
        b.fv = fv
        if fv then b.bg:SetStyle("forever", 1) b.bg:SetRadius(6)
        else b.bg:SetStyle("modern", 1, nil, false) b.bg:SetRadius(11) end
    end
    if fv then
        local P = ns.ForeverPalette
        local k = hover and P.buttonHover or P.buttonShade
        b.bg:SetColor(P.fill[1] * k, P.fill[2] * k, P.fill[3] * k, 1)
        b.text:SetTextColor(P.fg[1], P.fg[2], P.fg[3])
    else
        b.bg:SetColor(1, 1, 1, hover and 0.17 or 0.09)
        b.text:SetTextColor(C.fg[1], C.fg[2], C.fg[3])
    end
end

local function MakeButton(parent, label, w)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(w, 22)
    b:EnableMouse(true)
    b.bg = ns.CreateBody(b, "BACKGROUND", 0)
    b.bg:SetRadius(11)
    b.text = ns.Text(b, "bold", 11, C.fg, "CENTER")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b.Paint = PaintButton
    b:Paint(false)
    b:SetScript("OnEnter", function(f) f:Paint(true) end)
    b:SetScript("OnLeave", function(f) f:Paint(false) if GameTooltip then GameTooltip:Hide() end end)
    return b
end

local function Tip(f, title, line)
    if not GameTooltip then return end
    ns.PlaceTip(GameTooltip, f, "BOTTOM")
    GameTooltip:SetText(title, 1, 1, 1)
    if line then GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
end

local function CloseButton(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(20, 20)
    b:EnableMouse(true)
    b.icon = ns.Image(b, "Close", "OVERLAY", 0)
    b.icon:SetSize(13, 13)
    b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    return b
end

-- the tile behind a row: Modern keeps its blue-grey tiles and purple current step, Forever uses dark
-- bronze with a lit bronze current step
local function TileColor(cur, over)
    if Forever() then
        if cur then return 86 / 255, 53 / 255, 33 / 255 end
        if over then return 62 / 255, 54 / 255, 47 / 255 end
        return 24 / 255, 21 / 255, 18 / 255
    end
    if cur then return 0.17, 0.14, 0.28 end
    if over then return 0.17, 0.17, 0.22 end
    return 0.11, 0.11, 0.14
end

-- Forever: the current step is a lit plaque (the card's gradient and bronze edge); other rows stay flat dark
local function PaintTile(tile, cur, over)
    local fvCur = Forever() and cur and true or false
    if fvCur then
        if not tile.fvCur then tile.body:SetStyle("forever", 1) tile.fvCur = true tile.body:SetRadius(6) end
        return
    end
    if tile.fvCur then tile.body:SetStyle("modern", 1, nil, false) tile.fvCur = false end
    tile.body:SetColor(TileColor(cur, over))
end

local function SkinRow(r)
    local fg, muted = Pal("fg"), Pal("muted")
    r.name:SetTextColor(fg[1], fg[2], fg[3])
    r.sub:SetTextColor(muted[1], muted[2], muted[3])
    if Forever() then
        local l = ns.ForeverPalette.light
        r.hl:SetColorTexture(l[1], l[2], l[3], 0.35)
    else
        r.hl:SetColorTexture(PURPLE[1], PURPLE[2], PURPLE[3], 0.18)
    end
    r.tile.body:SetRadius(Forever() and 6 or 10)
end

local function ThumbPaint(f, state)
    if Forever() then
        local P = ns.ForeverPalette
        local c = state == "drag" and P.gold or (state == "over" and P.light) or P.edge
        f.sbThumbBody:SetColor(c[1], c[2], c[3], 1)
    else
        f.sbThumbBody:SetColor(1, 1, 1, state == "drag" and 0.5 or (state == "over" and 0.45) or 0.28)
    end
end

local function MakeRow(i)
    local f = D.frame
    local r = CreateFrame("Frame", nil, f.clip)
    r:SetSize(D.W - 20, D.ROW)
    r:SetPoint("TOPLEFT", f.clip, "TOPLEFT", 10, -((i - 1) * D.ROW))
    r.i = i
    r:EnableMouse(true)
    r.tile = CreateFrame("Frame", nil, r)
    r.tile:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.tile:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 4)
    -- a child frame draws over its parent's text, so the tile sits one level below the row
    if r.GetFrameLevel and r.tile.SetFrameLevel then r.tile:SetFrameLevel(math.max(0, (r:GetFrameLevel() or 1) - 1)) end
    r.tile.body = ns.CreateBody(r.tile, "BACKGROUND", 0)
    r.tile.body:SetRadius(10)
    r.tile:SetScript("OnSizeChanged", function(t) if t.fvCur then t.body:SetRadius(6) end end)
    r.tile.body:SetColor(0.11, 0.11, 0.14, 1)
    r.icon = ns.Image(r, "Arrow.tga", "ARTWORK", 1)
    r.icon:SetSize(18, 18)
    r.arrowTex = r.icon.GetTexture and r.icon:GetTexture()
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints(r)
    r.hover = r:CreateTexture(nil, "BACKGROUND")
    r.hover:SetColorTexture(1, 1, 1, 0.07)
    r.hover:SetAllPoints(r)
    r.hover:Hide()
    r.num = ns.Text(r, "bold", 12.5, C.muted, "RIGHT")
    r.num:SetPoint("LEFT", r, "LEFT", 4, 0)
    r.num:SetWidth(28)
    r.name = ns.Text(r, "bold", 12, C.fg)
    r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 42, -7)
    r.name:SetWidth(D.W - 80)
    if r.name.SetWordWrap then r.name:SetWordWrap(true) end
    if r.name.SetJustifyV then r.name:SetJustifyV("TOP") end
    r.sub = ns.Text(r, "medium", 10.5, C.muted)
    r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.sub:SetWidth(D.W - 80)
    -- long lines wrap, so nothing the step says is cut off; the row grows to fit
    if r.sub.SetWordWrap then r.sub:SetWordWrap(true) end
    if r.sub.SetSpacing then r.sub:SetSpacing(2) end
    if r.sub.SetJustifyV then r.sub:SetJustifyV("TOP") end
    r:SetScript("OnEnter", function(x)
        x.over = true
        if x.tiled then
            PaintTile(x.tile, x.item and x.item.cur, true)
        else x.hover:Show() end
    end)
    r:SetScript("OnLeave", function(x)
        x.over = nil
        if x.tiled then
            PaintTile(x.tile, x.item and x.item.cur, false)
        else x.hover:Hide() end
    end)
    r:SetScript("OnMouseUp", function(x, button)
        if button ~= "RightButton" and x.item and x.item.click then x.item.click() R:RefreshDrawer() end
    end)
    SkinRow(r)
    return r
end

local function Build()
    if D.frame then return D.frame end
    if not (I and I.island) then return nil end
    local f = CreateFrame("Frame", "BanzaiSlandRXPSteps", UIParent)
    D.frame = f
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f.body = ns.CreateBody(f, "BACKGROUND", 0)
    f.body:SetColor(0.03, 0.03, 0.04, 0.96)
    f.body:SetRadius(18)
    f:SetScript("OnSizeChanged", function(p) if p.bodyFv then p.body:SetRadius(18) end end)
    f.title = ns.Text(f, "bold", 13, C.fg)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -14)
    f.title:SetWidth(D.W - 150)
    f.count = ns.Text(f, "medium", 11, C.muted, "RIGHT")
    f.count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -44, -16)
    f.close = CloseButton(f)
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -12)
    f.close:SetScript("OnMouseUp", function() R:CloseDrawer() end)
    -- the button strip under the title
    local y = -(D.HEAD - 4)
    f.prev = MakeButton(f, L["Previous"], 70)
    f.prev:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    f.prev:SetScript("OnMouseUp", function() R:PreviousStep() R:RefreshDrawer() end)
    f.prev:SetScript("OnEnter", function(x) x:Paint(true) Tip(x, L["Previous step"], R.pv and L["Goes back one step in Polestar's guide"] or L["Goes back one step in RestedXP's guide"]) end)
    f.next = MakeButton(f, L["Next"], 56)
    f.next:SetPoint("LEFT", f.prev, "RIGHT", 6, 0)
    f.next:SetScript("OnMouseUp", function() R:NextStep() R:RefreshDrawer() end)
    f.next:SetScript("OnEnter", function(x) x:Paint(true) Tip(x, L["Next step"], R.pv and L["Moves on one step in Polestar's guide"] or L["Moves on one step in RestedXP's guide"]) end)
    f.skip = MakeButton(f, L["Skip step"], 78)
    f.skip:SetPoint("LEFT", f.next, "RIGHT", 6, 0)
    f.skip:SetScript("OnMouseUp", function() R:SkipStep() R:RefreshDrawer() end)
    f.skip:SetScript("OnEnter", function(x) x:Paint(true) Tip(x, L["Skip step"], R.pv and L["Skips the current step for good, like the skip button in Polestar's window"] or L["Ticks off every line of the current step, like clicking them in RestedXP's window"]) end)
    f.mode = MakeButton(f, L["Guides"], 70)
    f.mode:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, y)
    f.mode:SetScript("OnMouseUp", function()
        if D.mode == "steps" then D.mode, D.offset = "groups", 0
        elseif D.mode == "guides" then D.mode, D.offset = "groups", 0
        else D.mode, D.offset = "steps", 0 end
        D.query = ""
        if f.box then f.box:SetText("") end
        R:RefreshDrawer()
    end)
    f.box = CreateFrame("EditBox", nil, f)
    D.box = f.box
    f.box:SetSize(150, 22)
    f.box:SetPoint("RIGHT", f.mode, "LEFT", -8, 0)
    f.box:SetAutoFocus(false)
    f.box:SetFontObject(_G.ChatFontNormal or _G.GameFontNormal)
    f.box:SetMaxLetters(40)
    f.box:SetScript("OnTextChanged", function(x)
        D.query = x:GetText() or ""
        D.offset = 0
        R:RefreshDrawer()
    end)
    f.box:SetScript("OnEscapePressed", function(x) x:ClearFocus() end)
    f.opt = MakeButton(f, L["Options"], 64)
    f.opt:SetPoint("RIGHT", f.mode, "LEFT", -6, 0)
    f.opt:SetScript("OnMouseUp", function() R:OpenOptions() end)
    f.opt:SetScript("OnEnter", function(x) x:Paint(true) if R.pv then Tip(x, L["Polestar options"], L["Opens Polestar's own settings"]) else Tip(x, L["RestedXP options"], L["Opens RestedXP's own settings"]) end end)
    -- the rows live in a body that clips them, so a row half scrolled out is cut cleanly
    f.clip = CreateFrame("Frame", nil, f)
    f.clip:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -D.TOP)
    f.clip:SetSize(D.W, D.ROW)
    if f.clip.SetClipsChildren then f.clip:SetClipsChildren(true) end
    f.empty = ns.Text(f, "medium", 11.5, C.muted, "CENTER")
    f.empty:SetPoint("TOP", f, "TOP", 0, -(D.TOP + 14))
    f.empty:SetText(L["Nothing to show"])
    -- a scroll bar down the right edge: drag the thumb, or click the track to jump there
    f.sbTrack = CreateFrame("Frame", nil, f)
    f.sbTrack:SetWidth(10)
    f.sbTrack:EnableMouse(true)
    f.sbTrackBody = ns.CreateBody(f.sbTrack, "BACKGROUND", 0)
    f.sbTrackBody:SetColor(1, 1, 1, 0.06)
    f.sbTrackBody:SetRadius(2)
    f.sbThumb = CreateFrame("Frame", nil, f.sbTrack)
    f.sbThumb:SetWidth(6)
    f.sbThumb:EnableMouse(true)
    f.sbThumbBody = ns.CreateBody(f.sbThumb, "BACKGROUND", 0)
    f.sbThumbBody:SetColor(1, 1, 1, 0.28)
    f.sbThumbBody:SetRadius(3)
    local function CursorY() local _, y = GetCursorPosition() return y / (f:GetEffectiveScale() or 1) end
    f.sbThumb:SetScript("OnMouseDown", function()
        D.drag = { y = CursorY(), off = D.offset }
        ThumbPaint(f, "drag")
    end)
    f.sbThumb:SetScript("OnEnter", function() ThumbPaint(f, "over") end)
    f.sbThumb:SetScript("OnLeave", function() if not D.drag then ThumbPaint(f) end end)
    f.sbTrack:SetScript("OnMouseDown", function()
        local sb = D.sb
        if not (sb and sb.n > D.MAXROWS and sb.h > 0) then return end
        local frac = ((f:GetTop() or 0) - D.TOP - CursorY()) / sb.h
        D.offset = floor(max(0, min(1, frac)) * (sb.max or (sb.n - D.MAXROWS)) + 0.5)
        R:RefreshDrawer()
    end)
    f:SetScript("OnMouseWheel", function(_, delta)
        local step = (IsShiftKeyDown and IsShiftKeyDown() and D.MAXROWS) or ((D.sb and D.sb.n or 0) > 60 and 3) or 1
        D.offset = D.offset - (delta > 0 and step or -step)
        R:RefreshDrawer()
    end)
    local t = 0
    f:SetScript("OnUpdate", function(_, dt)
        R:SpringStep(dt)
        if D.drag then R:DragStep() else R:Glide(dt) end
        t = t + dt
        if t > 0.5 then t = 0 R:RefreshDrawer() end
    end)
    f.rule = f:CreateTexture(nil, "ARTWORK")
    f.rule:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -(D.TOP - 2))
    f.rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -(D.TOP - 2))
    f.rule:SetHeight(1)
    f.rule:Hide()
    f:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "BanzaiSlandRXPSteps") end
    R:Skin()
    return f
end

-- while the thumb is held, the list follows the cursor
function R:DragStep()
    local d, sb, f = D.drag, D.sb, D.frame
    if not (d and sb and f) then D.drag = nil return end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        D.drag = nil
        ThumbPaint(f)
        return
    end
    if sb.travel <= 0 then return end
    local _, cy = GetCursorPosition()
    cy = cy / (f:GetEffectiveScale() or 1)
    local top = sb.max or (sb.n - D.MAXROWS)
    local per = top / sb.travel
    local want = floor(d.off + (d.y - cy) * per + 0.5)
    want = max(0, min(top, want))
    if want ~= D.offset then D.offset, D.pos = want, want self:RefreshDrawer() end
end

-- opening: the panel grows from its edge with the island's own spring (a small overshoot), fading in
local FROM = 0.86
function R:SpringStep(dt)
    local f, sp = D.frame, D.spring
    local cl = D.closing
    if f and cl then
        -- closing: the panel shrinks back toward its edge and fades, a little faster than it opened
        cl.t = cl.t + dt / 0.16
        local p = min(1, cl.t)
        p = p * p
        if cl.t >= 1 then
            D.closing = nil
            f:Hide() f:SetScale(1) f:SetAlpha(1)
            return
        end
        f:SetScale(1 - (1 - FROM) * p)
        f:SetAlpha(1 - p)
        return
    end
    if not (f and sp) then return end
    local k, c = 256, 20
    if ns.SpringFeel then k, c = ns.SpringFeel() end
    local n = max(1, math.ceil(dt * 120))
    local h = dt / n
    for _ = 1, n do
        sp.v = sp.v + (-k * (sp.x - 1) - c * sp.v) * h
        sp.x = sp.x + sp.v * h
    end
    if abs(sp.x - 1) < 0.002 and abs(sp.v) < 0.02 then
        D.spring = nil
        f:SetScale(1)
        f:SetAlpha(1)
        return
    end
    f:SetScale(max(0.5, sp.x))
    f:SetAlpha(max(0, min(1, (sp.x - FROM) / (1 - FROM) * 1.4)))
end

-- Paint the panel for the Style setting. Cheap when nothing changed, so RefreshDrawer can call it often;
-- a style switch repaints everything (the drawer refreshes twice a second while it is open).
function R:Skin()
    local f = D.frame
    if not (f and ns.db) then return end
    local fv = Forever()
    local op = ns.db.opacity or 1
    if fv then
        if f.bodyFv ~= true or f.bodyOp ~= op then
            f.body:SetStyle("forever", op, true) f.bodyFv, f.bodyOp = true, op
            f.bodyH = f:GetHeight() f.body:SetRadius(18)
        end
    else
        if f.bodyFv then f.body:SetStyle("modern", 1, nil, false) f.bodyFv = false end
        local sr, sg, sb = ns.ShellRGB(0.03, 0.03, 0.04)
        f.body:SetColor(sr, sg, sb, op)
    end
    if D.skin == fv then return end
    D.skin = fv
    local fg, muted = Pal("fg"), Pal("muted")
    f.title:SetTextColor(fg[1], fg[2], fg[3])
    f.count:SetTextColor(muted[1], muted[2], muted[3])
    f.empty:SetTextColor(muted[1], muted[2], muted[3])
    f.close.icon:SetVertexColor(muted[1], muted[2], muted[3], 1)
    for _, b in ipairs({ f.prev, f.next, f.skip, f.mode, f.opt }) do b:Paint(false) end
    if fv then
        local P = ns.ForeverPalette
        f.sbTrackBody:SetColor(P.track[1], P.track[2], P.track[3], 0.7)
        f.rule:SetColorTexture(P.edge[1], P.edge[2], P.edge[3], 1)
    else
        f.sbTrackBody:SetColor(1, 1, 1, 0.06)
    end
    f.rule:SetShown(fv)
    ThumbPaint(f, D.drag and "drag" or nil)
    for _, r in pairs(D.rows) do SkinRow(r) end
    SyncTone()
    if f:IsShown() then self:LayoutRows() end
end

-- a Style change reaches the island through I:ApplyColors: retune the shared accent first (so the bubble
-- and cards pick it up), then repaint the panel
if I and I.ApplyColors and not R.colorsHooked then
    R.colorsHooked = true
    local orig = I.ApplyColors
    I.ApplyColors = function(self, ...)
        SyncTone()
        local a, b = orig(self, ...)
        pcall(R.Skin, R)
        return a, b
    end
end

function R:RefreshDrawer()
    local f = D.frame
    if not (f and f:IsShown()) then return end
    if self.pv and self.pv.Sync then self.pv.Sync() end
    local g, gstep = GS()
    local items = Rows()
    local n = #items
    D.items = items
    self:Skin()      -- the body (as see-through as the island and its bubbles) and the Style setting
    -- a different list (steps, groups, a search) starts where it is, not scrolled in from the old one
    local sig = D.mode .. "|" .. D.query .. "|" .. tostring(D.group and D.group.name)
    local std = max(0, n - D.MAXROWS)
    local lim = std
    if sig == D.sig and D.maxOff then lim = max(std, D.maxOff) end
    D.offset = max(0, min(D.offset, lim))
    if sig ~= D.sig or not D.pos then D.sig, D.pos, D.maxOff = sig, D.offset, nil end
    local inSteps = D.mode == "steps"
    local cur = Index(gstep)
    if inSteps then
        f.title:SetText(g and GuideName(g) or (self.pv and self.pv.label) or L["RestedXP Guides"])
        f.count:SetText(cur and L["Step %d of %d"]:format(cur, type(g) == "table" and (g.total or (type(g.steps) == "table" and #g.steps)) or 0) or "")
    elseif D.mode == "guides" and D.group and D.query == "" then
        f.title:SetText(D.group.name)
        f.count:SetText(L["%d guides"]:format(n))
    else
        f.title:SetText(L["Choose a guide"])
        f.count:SetText(D.query ~= "" and L["%d guides"]:format(n) or L["%d groups"]:format(n))
    end
    f.prev:SetShown(inSteps)
    f.next:SetShown(inSteps)
    f.skip:SetShown(inSteps)
    f.opt:SetShown(inSteps)
    f.box:SetShown(not inSteps)
    f.mode.text:SetText(inSteps and L["Guides"] or (D.mode == "guides" and L["Groups"] or L["Steps"]))
    f.empty:SetShown(n == 0)
    self:LayoutRows()
end

-- Place the rows for the current scroll position. The position eases toward the wanted row, so the
-- list glides; each row is as tall as its text, and the body clips the row that is half in view.
function R:LayoutRows()
    local f, items = D.frame, D.items
    if not (f and items) then return end
    local n = #items
    local pos = max(0, min(D.pos or 0, max(0, n - 1)))
    local base = floor(pos)
    local frac = pos - base
    local heights, y, shown = {}, 0, 0
    for i = 1, D.POOL do
        local item = items[base + i]
        if not item then break end
        local r = D.rows[i] or MakeRow(i)
        D.rows[i] = r
        local tiled = Tiles()
        if r.item ~= item or r.sized ~= item or r.tiled ~= tiled then
            r.tiled = tiled
            r.name:ClearAllPoints()
            r.name:SetPoint("TOPLEFT", r, "TOPLEFT", tiled and 64 or 42, -7)
            r.name:SetWidth(D.W - (tiled and 104 or 80))
            r.sub:SetWidth(D.W - (tiled and 104 or 80))
            r.name:SetText(item.name or "")
            r.sub:SetText(item.sub or "")
            local sh = (item.sub and item.sub ~= "") and r.sub:GetStringHeight() or 0
            if type(sh) ~= "number" then sh = 13 end
            local nh = r.name:GetStringHeight()
            if type(nh) ~= "number" or nh <= 0 then nh = 15 end
            r.h = max(D.ROW, 7 + nh + 3 + sh + 9) + (tiled and 4 or 0)
            r.sized = item
        end
        heights[i], shown = r.h, i
        y = y + r.h
        if y - frac * heights[1] >= D.BODY then break end
    end
    local overflow = (items[base + shown + 1] ~= nil) or pos > 0
    local more = n > D.MAXROWS or overflow
    local maxOff = n > D.MAXROWS and (n - D.MAXROWS) or (overflow and max(0, n - 1) or 0)
    D.maxOff = maxOff
    local trackH = more and D.BODY or y
    f:SetSize(D.W, D.TOP + max(D.ROW, trackH) + D.FOOT)
    -- the Forever gradient and bronze edge are laid out for the height they were painted at
    if f.body and f.bodyFv and f.bodyH ~= f:GetHeight() then f.bodyH = f:GetHeight() f.body:SetRadius(18) end
    f.clip:SetSize(D.W, max(D.ROW, trackH))
    f.sbTrack:SetShown(more)
    if more then
        f.sbTrack:ClearAllPoints()
        f.sbTrack:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -D.TOP)
        f.sbTrack:SetHeight(trackH)
        local th = max(26, trackH * D.MAXROWS / n)
        local travel = max(0, trackH - th)
        f.sbThumb:SetHeight(th)
        f.sbThumb:ClearAllPoints()
        f.sbThumb:SetPoint("TOP", f.sbTrack, "TOP", 0, -(travel * min(pos, max(1, maxOff)) / max(1, maxOff)))
        D.sb = { n = n, h = trackH, travel = travel, max = maxOff }
    else
        D.sb = { n = n, h = trackH, travel = 0, max = 0 }
    end
    local top = -frac * (heights[1] or 0)
    for i = 1, D.POOL do
        local r = D.rows[i] or MakeRow(i)
        D.rows[i] = r
        local item = items[base + i]
        if i <= shown and item then
            r.item = item
            r:SetHeight(heights[i])
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", f.clip, "TOPLEFT", 10, -top)
            top = top + heights[i]
            r.num:SetText(item.num or "")
            r.name:SetText(item.name or "")
            r.sub:SetText(item.sub or "")
            local tiled = r.tiled
            r.tile:SetShown(tiled and true or false)
            r.hl:SetShown(item.cur and not tiled and true or false)
            if tiled then
                PaintTile(r.tile, item.cur, r.over)
                r.num:ClearAllPoints()
                r.num:SetPoint("LEFT", r, "LEFT", 6, 2)
                local tex = item.kind and (KIND_ICON[item.kind] or (item.kind == "go" and r.arrowTex))
                if tex then
                    r.icon:SetTexture(tex)
                    r.icon:ClearAllPoints()
                    r.icon:SetPoint("LEFT", r, "LEFT", 38, 2)
                    r.icon:Show()
                else r.icon:Hide() end
            else
                r.icon:Hide()
                r.num:ClearAllPoints()
                r.num:SetPoint("LEFT", r, "LEFT", 4, 0)
            end
            r:SetAlpha(item.dim and 0.45 or 1)
            if item.cur then r.num:SetTextColor(GUIDE[1], GUIDE[2], GUIDE[3]) else local mu = Pal("muted") r.num:SetTextColor(mu[1], mu[2], mu[3]) end
            r:Show()
        else
            r.item = nil
            r:Hide()
        end
    end
end

-- the list glides toward the row it was sent to
function R:Glide(dt)
    if not (D.pos and D.offset) or D.pos == D.offset then return end
    local d = D.offset - D.pos
    if math.abs(d) < 0.01 then D.pos = D.offset
    else D.pos = D.pos + d * min(1, dt * 16) end
    self:LayoutRows()
end

-- RestedXP's own settings: whichever way this version of it opens them
function R:OpenOptions()
    if self.pv then return self.pv.Options() end
    local a = RXPAddon()
    local tried = {}
    if a then
        for k, v in pairs(a) do
            if type(k) == "string" and type(v) == "function" and k:lower():find("^open") and (k:lower():find("setting") or k:lower():find("option") or k:lower():find("config")) then
                tried[#tried + 1] = k
                if pcall(v, a) then return true end
            end
        end
    end
    local slash = _G.SlashCmdList
    if type(slash) == "table" then
        for k, fn in pairs(slash) do
            if type(k) == "string" and k:upper():find("RXP") and type(fn) == "function" then
                tried[#tried + 1] = "/" .. k
                if pcall(fn, "settings") then return true end
            end
        end
    end
    local ACD = _G.LibStub and _G.LibStub("AceConfigDialog-3.0", true)
    if ACD and ACD.Open then
        for _, name in ipairs({ "RXPGuides", "RXP Guides", "RXP" }) do
            if ACD.OpenFrames or true then
                local ok = pcall(ACD.Open, ACD, name)
                if ok and ACD.OpenFrames and ACD.OpenFrames[name] then return true end
            end
        end
    end
    ns.Print(L["Could not open RestedXP's options. Type /rxp to find them."])
    return false
end

function R:OpenDrawer(pv)
    local f = Build()
    if not f then return end
    self.pv = pv                    -- nil: RestedXP's guide; else another guide addon (Polestar.lua)
    if pv and pv.Sync then pv.Sync() end
    f:ClearAllPoints()
    local hp = I.gx == "left" and "LEFT" or I.gx == "right" and "RIGHT" or ""
    if I.up then f:SetPoint("BOTTOM" .. hp, I.island, "TOP" .. hp, 0, 12)
    else f:SetPoint("TOP" .. hp, I.island, "BOTTOM" .. hp, 0, -12 - ((ns.db.bubbleSide == "below") and 46 or 0)) end
    -- start on the steps, with the current one in view and a step or two before it
    D.mode, D.query, D.index, D.groups, D.group = "steps", "", nil, nil, nil
    f.box:SetText("")
    local dg, dstep = GS()
    local cur = Index(dstep)
    local at = type(dg) == "table" and dg.curPos or cur
    D.offset = at and max(0, at - 3) or 0
    D.sig, D.pos = nil, nil
    D.closing = nil
    D.spring = { x = FROM, v = 0 }
    f:SetScale(FROM)
    f:SetAlpha(0)
    f:Show()
    self:RefreshDrawer()
end

function R:CloseDrawer(instant)
    D.spring = nil
    local f = D.frame
    if not f then return end
    if instant or not f:IsShown() or D.closing then
        if instant or not f:IsShown() then D.closing = nil f:Hide() f:SetScale(1) f:SetAlpha(1) end
        return
    end
    D.closing = { t = 0 }
end
function R:ToggleDrawer(pv)
    if D.frame and D.frame:IsShown() and not D.closing and self.pv == pv then self:CloseDrawer() else self:OpenDrawer(pv) end
end

-- ---- RestedXP's own window, out of sight when you would rather use this panel. It stays shown (and so
-- keeps tracking your progress, which it stops doing when hidden); it is only made invisible and tiny.

function R:ApplyWindow()
    local a = RXPAddon()
    local f = a and a.RXPFrame
    if type(f) ~= "table" or not f.SetAlpha then return end
    if ns.db and ns.db.rxpHideWindow then
        if f:GetAlpha() ~= 0 then f:SetAlpha(0) end
        if f.SetScale and f:GetScale() ~= 0.001 then f:SetScale(0.001) end
        self.windowHidden = true
    elseif self.windowHidden then
        self.windowHidden = nil
        f:SetAlpha(1)
        local prof = a.settings and a.settings.profile
        if f.SetScale then f:SetScale(prof and prof.windowScale or 1) end
    end
end

-- The messages can be missed (a guide often loads before Island is listening), so the current step
-- is also read from the guide itself once a second.
function R:CurrentStep()
    local a = RXPAddon()
    local g = a and a.currentGuide
    if type(g) ~= "table" or type(g.steps) ~= "table" then return nil end
    for _, st in ipairs(g.steps) do
        if type(st) == "table" and st.active and not st.tip and Index(st) then return g, st end
    end
    local cd = _G.RXPCData
    local i = type(cd) == "table" and tonumber(cd.currentStep)
    local st = i and g.steps[i]
    if type(st) == "table" and Index(st) and not st.tip then return g, st end
    return g, nil
end

function R:Poll()
    if not (ns.db and I.built) then return end
    local g, st = self:CurrentStep()
    if not g then
        if self.step then self.guide, self.step = nil, nil self:SetBubble() end
        return
    end
    if g ~= self.guide and not self.step then self.guide = g end
    if st and (st ~= self.step) then self:StepActivated(nil, st, g) end
    if self.step and not (ns.db.rxpStepBubble and self.shownBubble) then self:SetBubble() end
    self:ApplyWindow()
end

function R:Debug()
    local a = RXPAddon()
    local e = RXPElement()
    if e then
        ns.Print(string.format("RestedXP arrow: zone %s, x %s, y %s, map used %s, map frame %s",
            tostring(e.zone), tostring(e.x), tostring(e.y), tostring(ns.Nav.StepMap(e)), tostring(_G.WorldMapFrame ~= nil)))
    else
        ns.Print("RestedXP arrow: none showing")
    end
    local g, st = self:CurrentStep()
    if st and type(st.elements) == "table" then
        for i, el in ipairs(st.elements) do
            ns.Print(string.format("  element %d: text=%s tooltip=%s raw=%s hideTooltip=%s", i,
                tostring(el.text), tostring(el.tooltipText), tostring(el.rawtext), tostring(el.hideTooltip)))
        end
    end
    ns.Print(string.format("RestedXP: addon %s, listening %s, island built %s, guide %s, step %s, bubble on %s, card on %s",
        tostring(a ~= nil), tostring(self.hooked == true), tostring(I.built == true), g and GuideName(g) or "none",
        st and tostring(Index(st)) or "none", tostring(ns.db and ns.db.rxpStepBubble), tostring(ns.db and ns.db.rxpStepCards)))
end

function R:Hook()
    if self.hooked then return true end
    local AE = _G.LibStub and _G.LibStub("AceEvent-3.0", true)
    if not (AE and RXPAddon() and I.built) then return false end
    self.hooked = true
    AE:Embed(self)
    self:RegisterMessage("RXP_STEP_ACTIVATED", "StepActivated")
    self:RegisterMessage("RXP_STEP_COMPLETE", "StepComplete")
    self:RegisterMessage("RXP_GUIDE_LOADED", "GuideLoaded")
    return true
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" and name ~= "RXPGuides" then return end
        if event == "PLAYER_ENTERING_WORLD" then R.quiet = GetTime() + 4 end
        for _, d in ipairs({ 0, 1, 4 }) do C_Timer.After(d, function() R:Hook() end) end
    end)
    local acc = 0
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.3 then return end
        acc = 0
        if not R.hooked then R:Hook() end
        pcall(R.Poll, R)
    end)
end
