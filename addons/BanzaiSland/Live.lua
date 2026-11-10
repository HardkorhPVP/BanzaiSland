-- Island: live activities. Things that are running right now sit in the bubble beside the
-- island with a timer: flights, the hearthstone cooldown, breath and fatigue, battleground queues.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local floor, max = math.floor, math.max
local I, C = ns.Island, ns.C

local BLUE = { 0.40, 0.72, 1.00 }
local ORANGE = { 0.98, 0.66, 0.28 }
local GREEN = { 0.36, 0.85, 0.45 }
local RED = { 0.95, 0.38, 0.38 }
local GOLD = C.gold
local MUTED_HEX = ns.Hex(C.muted[1], C.muted[2], C.muted[3])
local HEARTHSTONE = 6948

local function Clock(sec)
    sec = max(0, floor(sec + 0.5))
    if sec >= 3600 then return string.format("%d:%02d:%02d", floor(sec / 3600), floor(sec / 60) % 60, sec % 60) end
    return string.format("%d:%02d", floor(sec / 60), sec % 60)
end
ns.Clock = Clock

-- ---------------------------------------------------------------- flights

local flight = { active = false }
local DRUID_FLIGHTS = {
    [97066] = "Rut'theran Village",
    [97069] = "Thunder Bluff",
}
local gossipOptions = {}

local function OnTaxi()
    if not UnitOnTaxi then return false end
    local ok, value = pcall(UnitOnTaxi, "player")
    return ok and ns.Readable(value) and (value == true or value == 1)
end

local function ClearRoute()
    flight.dest, flight.origin, flight.key, flight.yards = nil, nil, nil, nil
    flight.gossipID, flight.waitUntil = nil, nil
end

local function RememberGossipOptions()
    gossipOptions = {}
    if not (C_GossipInfo and C_GossipInfo.GetOptions) then return end
    local ok, options = pcall(C_GossipInfo.GetOptions)
    if ok and type(options) == "table" then
        for index, option in ipairs(options) do
            -- SelectOptionByIndex takes the game's orderIndex, which can start at zero.
            -- The list's Lua position is only a fallback for clients without that field.
            local selectionIndex = option.orderIndex
            if selectionIndex == nil then selectionIndex = index end
            gossipOptions[selectionIndex] = option.gossipOptionID
        end
    end
end

local function OnGossipFlight(id)
    if not ns.ClientFeature("druidGossipFlights") or flight.active or not DRUID_FLIGHTS[id] then return end
    ClearRoute()
    flight.gossipID, flight.dest = id, DRUID_FLIGHTS[id]
    -- These flights skip the taxi map, so there is no route length to estimate.
    -- Keep the option ID as a stable route key and learn its duration after landing.
    flight.waitUntil = GetTime() + 15
end

-- How long the route is, in yards, from the hops drawn on the flight map. Used to estimate the time
-- of a route you have not flown before. Coordinates there run 0-1 across the flight map.
local function RouteYards(index)
    if not (GetNumRoutes and TaxiGetSrcX and TaxiGetSrcY and TaxiGetDestX and TaxiGetDestY) then return nil end
    local w, h
    if GetTaxiMapID and C_Map and C_Map.GetMapWorldSize then
        local ok, map = pcall(GetTaxiMapID)
        if ok and map then
            local ok2, ww, hh = pcall(C_Map.GetMapWorldSize, map)
            if ok2 and ww and ww > 0 then w, h = ww, hh end
        end
    end
    if not w then return nil end
    local ok, hops = pcall(GetNumRoutes, index)
    if not ok or type(hops) ~= "number" or hops < 1 then return nil end
    local total = 0
    for hop = 1, hops do
        local sx, sy = TaxiGetSrcX(index, hop), TaxiGetSrcY(index, hop)
        local dx, dy = TaxiGetDestX(index, hop), TaxiGetDestY(index, hop)
        if not (sx and sy and dx and dy) then return nil end
        local ex, ey = (dx - sx) * w, (dy - sy) * h
        total = total + math.sqrt(ex * ex + ey * ey)
    end
    return total > 0 and total or nil
end

-- yards per second on a flight path: starts from a typical speed and learns from your own flights
local DEFAULT_SPEED = 30

-- remember where a flight is headed when the player picks a node on the flight map
local function OnTakeTaxi(index)
    if flight.active then return end
    ClearRoute()
    flight.waitUntil = GetTime() + 15
    local ok, dest = pcall(TaxiNodeName, index)
    flight.dest = ok and dest or nil
    local okLen, len = pcall(RouteYards, index)
    flight.yards = okLen and len or nil
    flight.origin = nil
    if NumTaxiNodes and TaxiNodeGetType then
        for i = 1, NumTaxiNodes() do
            if TaxiNodeGetType(i) == "CURRENT" then
                flight.origin = TaxiNodeName(i)
                break
            end
        end
    end
end

local function ShortNode(name)       -- "Booty Bay, Stranglethorn" reads better as "Booty Bay"
    return name and (name:match("^([^,]+)") or name) or nil
end

-- "Request stop": land at the next flight point on the way (the game's own early landing)
local function RequestStop()
    if not flight.active or flight.early then return end
    if not TaxiRequestEarlyLanding or not OnTaxi() then return end
    if pcall(TaxiRequestEarlyLanding) then flight.MarkEarly() end
end

local function MarkEarly()
    if not flight.active or flight.early then return end
    flight.early = true
    local act = flight.act
    if act then
        act.tip2 = L["Landing at the next flight point"]
        act.hint, act.onClick = nil, nil
    end
end
flight.MarkEarly = MarkEarly
if hooksecurefunc and TaxiRequestEarlyLanding then hooksecurefunc("TaxiRequestEarlyLanding", MarkEarly) end

-- the game's own Request Stop button: see-through while the island offers one
local stopHooked
local function GameStopButton()
    local b = _G.MainMenuBarVehicleLeaveButton
    if not (b and b.SetAlpha) then return end
    local hide = flight.active and ns.db.flightHideStop
    if not stopHooked and b.HookScript then
        stopHooked = true
        b:HookScript("OnShow", function(self)
            if flight.active and ns.db.flightHideStop then self:SetAlpha(0) end
        end)
    end
    if hide then b:SetAlpha(0) elseif flight.hidStop then b:SetAlpha(1) end
    flight.hidStop = hide or nil
end
ns.ApplyFlightStop = GameStopButton

local function FlightStart()
    if flight.active or not ns.db.liveFlight then return end
    flight.active, flight.started, flight.early = true, GetTime(), nil
    flight.waitUntil = nil
    local key = flight.gossipID and ("gossip:" .. flight.gossipID)
        or ((flight.origin and flight.dest) and (flight.origin .. " > " .. flight.dest) or nil)
    flight.key = key
    flight.known = key and ns.db.flights and ns.db.flights[key] or nil
    -- a route flown before uses its real time; a new one is estimated from its length
    flight.estimate = nil
    if not flight.known and flight.yards then
        flight.estimate = flight.yards / (ns.db.flightSpeed or DEFAULT_SPEED)
    end
    local total = flight.known or flight.estimate
    local act
    act = {
        glyph = "Plane", tone = BLUE, priority = 4,
        hint = L["Request a stop"], onClick = RequestStop,
        tip = flight.dest and L["Flying to %s"]:format(ShortNode(flight.dest)) or L["Flight"],
        tip2 = flight.known and L["Arrives in"] or (total and L["About this long; timing it for next time"] or L["Time in the air"]),
        native = true, noEase = true,
        progress = function()
            if not total or total <= 0 then return nil end     -- no length to count down from
            return max(0, math.min(1, (total - (GetTime() - flight.started)) / total))
        end,
        text = function()
            local elapsed = GetTime() - flight.started
            if flight.early then return L["Stopping"] end
            if total then
                local left = total - elapsed
                if left > 0 then return (flight.known and "" or "~") .. Clock(left) end
                return "0:00"           -- running a little over the estimate: hold at zero
            end
            return Clock(elapsed)       -- no way to know: count the time flown
        end,
    }
    flight.act = act
    I:SetActivity("flight", act)
    GameStopButton()
    I:Push({
        kind = "won", builderType = "flights", glyph = "Plane", tone = BLUE, cap = flight.dest and L["FLYING TO"] or L["FLIGHT"], capColor = BLUE,
        title = ShortNode(flight.dest) or L["On a flight path"], color = C.fg, transient = true,
        res = total and ((flight.known and "" or "~") .. Clock(total)) or "", hold = 2.6,
        line = (not flight.known and flight.dest) and (MUTED_HEX .. (total and L["About this long; timing it for next time"] or L["Timing this route for next time"]) .. "|r") or nil,
        button = { label = L["Request stop"], done = L["Stopping"], fn = RequestStop },
    })
end

local function FlightEnd()
    if not flight.active then return end
    flight.active = false
    flight.act = nil
    I:SetActivity("flight", nil)
    GameStopButton()
    local took = GetTime() - flight.started
    -- a flight cut short at an earlier stop says nothing about the route's real time
    if flight.early then took = 0 end
    if flight.key and took > 10 then
        ns.db.flights = ns.db.flights or {}
        ns.db.flights[flight.key] = floor(took + 0.5)
    end
    -- learn how fast flights really go, so estimates for new routes get better
    if flight.yards and took > 10 then
        local speed = flight.yards / took
        if speed > 5 and speed < 120 then
            ns.db.flightSpeed = ns.db.flightSpeed and (ns.db.flightSpeed * 0.7 + speed * 0.3) or speed
        end
    end
    ClearRoute()
end

-- A small snapshot for diagnosing routes that were not recognized or recorded.
function BanzaiSland_FlightDebug()
    local saved = ns.db and ns.db.flights or {}
    return {
        active = flight.active, taxi = OnTaxi(), enabled = ns.db and ns.db.liveFlight,
        destination = flight.dest, gossipOptionID = flight.gossipID, routeKey = flight.key,
        knownDuration = flight.known, earlyStop = flight.early,
        waiting = flight.waitUntil ~= nil,
        savedDruidRoutes = { [97066] = saved["gossip:97066"], [97069] = saved["gossip:97069"] },
    }
end

-- ---------------------------------------------------------------- hearthstone

local hearth = { was = nil }

local function HearthRemaining()
    local count = GetItemCount and GetItemCount(HEARTHSTONE) or 0
    if count == 0 then return nil end
    local getCD = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
    if not getCD then return nil end
    local ok, start, duration = pcall(getCD, HEARTHSTONE)
    if not ok or type(start) ~= "number" or type(duration) ~= "number" then return nil end
    if duration < 60 or start <= 0 then return 0 end
    return max(0, start + duration - GetTime()), duration
end

local function CheckHearth()
    if not ns.db.liveHearth then
        if hearth.shown then hearth.shown = false I:SetActivity("hearth", nil) end
        return
    end
    local left = HearthRemaining()
    if not left then return end
    local show = left > 0 and left <= 600
    if show and not hearth.shown then
        hearth.shown = true
        I:SetActivity("hearth", { glyph = "Home", tone = GOLD, priority = 2, tip = L["Hearthstone"], tip2 = L["Ready in"], text = function() return Clock(HearthRemaining() or 0) end,
            native = true, noEase = true,
            progress = function()
                local left, duration = HearthRemaining()
                if left and duration and duration > 0 then return math.min(1, left / duration) end
                return 0
            end })
    elseif not show and hearth.shown then
        hearth.shown = false
        I:SetActivity("hearth", nil)
    end
    if hearth.was and hearth.was > 0 and left == 0 then
        if ns.CatchUp then ns.CatchUp.Record("cooldowns", "hearthstone", L["Hearthstone ready"], L["Cooldown finished"], {glyph="Home", once=true}) end
        I:Push({ kind = "won", catchUpCategory = "cooldowns", glyph = "Home", tone = GOLD, cap = L["HEARTHSTONE"], capColor = GOLD,
                 title = L["Hearthstone is ready"], color = C.fg, res = "", hold = 3 })
    end
    hearth.was = left
end

-- ---------------------------------------------------------------- breath, fatigue, feign death

local MIRROR = {
    BREATH = { glyph = "Drop", tone = BLUE },
    EXHAUSTION = { glyph = "Clock", tone = ORANGE },
    FEIGNDEATH = { glyph = "Clock", tone = GREEN },
}

local mirrorOn = {}

-- the game's own numbers for a timer bar: its full value and whether it is running down (scale < 0)
-- or filling back up (scale > 0, after you surface)
local function MirrorInfo(name)
    if not GetMirrorTimerInfo then return nil end
    for i = 1, (MIRRORTIMER_NUMTIMERS or 3) do
        local ok, timer, _, maxValue, scale, paused = pcall(GetMirrorTimerInfo, i)
        if ok and timer == name then return maxValue, scale, paused end
    end
end

local function MirrorStart(name)
    if not ns.db.liveTimers or not name then return end
    local look = MIRROR[name] or { glyph = "Clock", tone = ORANGE }
    mirrorOn[name] = true
    I:SetActivity("mirror:" .. name, {
        glyph = look.glyph, tone = look.tone, priority = 5,
        tip = (name == "BREATH" and L["Breath"]) or (name == "EXHAUSTION" and L["Fatigue"]) or (name == "FEIGNDEATH" and L["Feign Death"]) or L["Timer"],
        text = function()
            local ms = GetMirrorTimerProgress and GetMirrorTimerProgress(name) or 0
            local maxValue = MirrorInfo(name)
            if type(maxValue) == "number" and maxValue > 0 then ms = math.min(ms, maxValue) end
            return L["%ds"]:format(floor(max(0, ms) / 1000 + 0.5))
        end,
        native = true, noEase = true,
        progress = function()
            local ms = GetMirrorTimerProgress and GetMirrorTimerProgress(name) or 0
            local maxValue = MirrorInfo(name)
            if type(maxValue) == "number" and maxValue > 0 then return max(0, math.min(1, ms / maxValue)) end
            return nil
        end,
    })
end

local function MirrorEnd(name)
    mirrorOn[name] = nil
    I:SetActivity("mirror:" .. name, nil)
end

-- After you surface the game fills the bar back up before it goes away; the bubble follows it up
-- to your full breath (never past it) and leaves when the game ends the timer.

-- ---------------------------------------------------------------- battleground queue

local queueState = {}

local function CheckQueues()
    if not GetBattlefieldStatus then return end
    local slots = (GetMaxBattlefieldID and GetMaxBattlefieldID()) or 3
    local waiting
    for i = 1, slots do
        local status, map = GetBattlefieldStatus(i)
        if status == "queued" and not waiting then waiting = i end
        if status == "confirm" and queueState[i] ~= "confirm" and ns.db.liveQueue then
            local left = GetBattlefieldPortExpiration and GetBattlefieldPortExpiration(i) or 0
            I:Push({
                kind = "won", urgent = true, priority = 3, glyph = "Flag", tone = GREEN, cap = L["QUEUE READY"],
                capColor = GREEN, title = map or L["Battleground"], color = C.fg, flash = GREEN, hold = 6, sound = 8960, soundKey = "queueReady",
                res = (type(left) == "number" and left > 0) and Clock(left) or "",
                line = MUTED_HEX .. L["Use the game's window to enter"] .. "|r",
            })
        end
        queueState[i] = status
    end
    if waiting and ns.db.liveQueue then
        local slot = waiting
        I:SetActivity("queue", {
            glyph = "Flag", tone = ORANGE, priority = 3, tip = L["Battleground queue"], tip2 = L["Time waiting"],
            text = function()
                local ms = GetBattlefieldTimeWaited and GetBattlefieldTimeWaited(slot) or 0
                return Clock(ms / 1000)
            end,
        })
    else
        I:SetActivity("queue", nil)
    end
end

-- ---------------------------------------------------------------- demo

function ns.DemoLive()
    if not I.built then return end
    local ends = GetTime() + 20
    I:SetActivity("demo", { glyph = "Plane", tone = BLUE, priority = 9, text = function() return Clock(ends - GetTime()) end })
    I:Push({ kind = "won", builderType = "flights", glyph = "Plane", tone = BLUE, cap = L["FLYING TO"], capColor = BLUE, title = "Booty Bay",
             color = C.fg, res = "0:20", hold = 2.6, transient = true })
    C_Timer.After(20, function() I:SetActivity("demo", nil) end)
end

-- ---------------------------------------------------------------- events

local ev = CreateFrame("Frame")
local since = 0
ev:SetScript("OnEvent", function(_, event, a)
    if event == "PLAYER_LOGIN" then
        if TakeTaxiNode and hooksecurefunc then pcall(hooksecurefunc, "TakeTaxiNode", OnTakeTaxi) end
        if ns.ClientFeature("druidGossipFlights") and C_GossipInfo and hooksecurefunc then
            if C_GossipInfo.SelectOption then pcall(hooksecurefunc, C_GossipInfo, "SelectOption", OnGossipFlight) end
            if C_GossipInfo.SelectOptionByIndex then
                pcall(hooksecurefunc, C_GossipInfo, "SelectOptionByIndex", function(index) OnGossipFlight(gossipOptions[index]) end)
            end
        end
        C_Timer.After(4, function() CheckHearth() CheckQueues() end)
    elseif event == "GOSSIP_SHOW" then
        if ns.ClientFeature("druidGossipFlights") then RememberGossipOptions() end
    elseif event == "PLAYER_CONTROL_LOST" then
        if not flight.active then
            if flight.waitUntil and GetTime() > flight.waitUntil then ClearRoute() end
            flight.waitUntil = GetTime() + 15
        end
    elseif event == "PLAYER_CONTROL_GAINED" then
        if not OnTaxi() then FlightEnd() end
    elseif event == "MIRROR_TIMER_START" then
        MirrorStart(a)
    elseif event == "MIRROR_TIMER_STOP" then
        if a then MirrorEnd(a) end
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        CheckQueues()
    end
end)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "GOSSIP_SHOW", "MIRROR_TIMER_START",
                         "MIRROR_TIMER_STOP", "UPDATE_BATTLEFIELD_STATUS" }) do
    pcall(ev.RegisterEvent, ev, event)
end
ev:SetScript("OnUpdate", function(_, dt)
    if I.built and flight.waitUntil and not flight.active then
        if GetTime() > flight.waitUntil then ClearRoute()
        elseif OnTaxi() then FlightStart() end
    end
    since = since + dt
    if since < 1 then return end
    since = 0
    if not I.built then return end
    if flight.active and not OnTaxi() then FlightEnd() end
    CheckHearth()
end)
