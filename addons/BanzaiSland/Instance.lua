-- Island: instance runs. While you are in a dungeon or raid, the bubble beside the island shows
-- how long you have been inside, and the hover panel's bottom row shows the run's gold, kills and
-- XP. Leaving shows a summary card.
--
-- A run is tied to the instance copy itself, not just the dungeon: every creature's ID carries the
-- number of the copy it lives in. Going out and back in to the same copy (a corpse run, a trip to
-- a vendor, a disconnect, a /reload) carries on the same run. A reset copy has a new number, and
-- the run starts fresh as soon as the first creature in it is seen.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local floor, max = math.floor, math.max
local I, C = ns.Island, ns.C

local BLUE = { 0.40, 0.72, 1.00 }
local MUTED_HEX = ns.Hex(C.muted[1], C.muted[2], C.muted[3])
local KEEP = 20                 -- finished runs kept in history
local STALE = 12 * 3600         -- a run untouched this long is finished, whatever the copy
local EMPTY = 30 * 60           -- a dungeon left empty this long has reset itself (raids keep their lockout)

local R = { inside = false }
ns.Instance = R

local function Store()
    local db = ns.char or ns.db          -- runs belong to the character who ran them
    db.runs = db.runs or { history = {} }
    db.runs.history = db.runs.history or {}
    return db.runs
end

-- ---------------------------------------------------------------- text

local GOLD_HEX, SILVER_HEX, COPPER_HEX = "|cffffd700", "|cffc7c7cf", "|cffeda55f"

-- gold, silver and copper, always all three once there is gold
function R.Money(copper)
    copper = floor(copper or 0)
    local g, s, c = floor(copper / 10000), floor(copper / 100) % 100, copper % 100
    if g > 0 then
        return ns.Comma(g) .. GOLD_HEX .. "g|r " .. s .. SILVER_HEX .. "s|r " .. c .. COPPER_HEX .. "c|r"
    elseif s > 0 then
        return s .. SILVER_HEX .. "s|r " .. c .. COPPER_HEX .. "c|r"
    end
    return c .. COPPER_HEX .. "c|r"
end

-- ---------------------------------------------------------------- the current copy

-- the number of the instance copy, from a creature's ID: Creature-0-server-map-copy-npc-spawn
local function CopyFromUnit(unit, mapID)
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or not ns.Readable(guid) or type(guid) ~= "string" then return nil end
    local kind, _, _, map, copy = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    -- (the map number in the ID isn't always the one GetInstanceInfo gives, so it isn't checked)
    if not copy or copy == "0" or copy == "" then return nil end
    return copy
end

local function InstanceNow()
    if not (IsInInstance and GetInstanceInfo) then return nil end
    local inside, kind = IsInInstance()
    if not inside or (kind ~= "party" and kind ~= "raid" and kind ~= "scenario") then return nil end
    local name, _, difficulty, difficultyName, _, _, _, mapID = GetInstanceInfo()
    if not mapID then return nil end
    return { map = mapID, name = name or "Instance", kind = kind, difficulty = difficultyName }
end

local function Elapsed(run)
    if not run then return 0 end
    local t = run.time or 0
    if R.inside and R.enteredAt then t = t + (GetTime() - R.enteredAt) end
    return t
end
R.Elapsed = Elapsed

local function NewRun(info)
    return { map = info.map, name = info.name, kind = info.kind, difficulty = info.difficulty,
             started = time(), lastSeen = time(), time = 0, money = 0, xp = 0, kills = 0 }
end

local function Archive(run)
    if not run then return end
    local store = Store()
    if (run.time or 0) >= 30 or (run.money or 0) > 0 or (run.xp or 0) > 0 then
        table.insert(store.history, 1, run)
        while #store.history > KEEP do table.remove(store.history) end
    end
end

local function Bubble()
    local run = Store().current
    if R.inside and run and ns.db.instanceTracker then
        I:SetActivity("instance", { glyph = "Door", tone = BLUE, priority = 1, tip = L["This run"],
            tip2 = L["Time inside this instance. /banzaisland runs for more"], hint = L["Print this run in chat"],
            onClick = function() if ns.Instance and ns.Instance.Report then ns.Instance.Report() end end, text = function() return ns.Clock(Elapsed(Store().current)) end })
    else
        I:SetActivity("instance", nil)
    end
end

-- bank the time spent inside so far
local function Bank()
    local run = Store().current
    if run and R.inside and R.enteredAt then
        run.time = (run.time or 0) + (GetTime() - R.enteredAt)
        R.enteredAt = GetTime()
        run.lastSeen = time()
    end
end

local function SummaryCard(run, cap)
    if ns.ClientFeature("retail") and run and run.retailSummaryShown then return end
    if not (run and ns.db.instanceTracker and ns.db.instanceSummary and I.built) then return end
    local bits = {}
    if (run.money or 0) > 0 then bits[#bits + 1] = "+" .. R.Money(run.money) .. MUTED_HEX end
    if (run.xp or 0) > 0 then bits[#bits + 1] = L["%s XP"]:format(ns.Comma(run.xp)) end
    if (run.kills or 0) > 0 then bits[#bits + 1] = (run.kills == 1 and L["%s kill"] or L["%s kills"]):format(ns.Comma(run.kills)) end
    I:PushCard({ group = "alerts",
        kind = "won", key = "instance", glyph = "Door", tone = BLUE, cap = cap or L["LEFT INSTANCE"], capColor = BLUE,
        title = run.name or L["Instance"], color = C.fg, res = ns.Clock(run.time or 0), resColor = C.fg,
        line = #bits > 0 and (MUTED_HEX .. table.concat(bits, "   ") .. "|r") or nil, hold = 4,
    })
end

-- the copy number is known: same copy carries on, a different one means the dungeon was reset
local function SeenCopy(copy)
    local store = Store()
    local run = store.current
    if not (copy and run and R.inside) then return end
    if not run.copy then
        run.copy = copy
    elseif run.copy ~= copy then
        -- a fresh copy: what was earned since walking in belongs to the new run
        Bank()
        local entry = R.entry or { money = run.money, xp = run.xp, kills = run.kills, time = run.time }
        local fresh = NewRun(run)
        fresh.copy = copy
        fresh.money = max(0, run.money - entry.money)
        fresh.xp = max(0, run.xp - entry.xp)
        fresh.kills = max(0, run.kills - entry.kills)
        fresh.time = max(0, run.time - entry.time)
        run.money, run.xp, run.kills, run.time = entry.money, entry.xp, entry.kills, entry.time
        Archive(run)
        store.current = fresh
        R.entry = { money = 0, xp = 0, kills = 0, time = 0 }
        Bubble()
    end
end

local function LookForCopy(unit)
    local run = Store().current
    if not (R.inside and run) then return end
    local copy = CopyFromUnit(unit, run.map)
    if copy and copy ~= run.copy then SeenCopy(copy) end
end

-- ---------------------------------------------------------------- entering and leaving

-- dungeons reset by name ("The Deadmines has been reset."): the next visit is a new run
local resetNames = {}
local resetPattern
local function ResetPattern()
    if resetPattern ~= nil then return resetPattern end
    resetPattern = false
    local fmt = INSTANCE_RESET_SUCCESS
    if type(fmt) == "string" then
        local p = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"):gsub("%%s", "(.+)")
        resetPattern = "^" .. p .. "$"
    end
    return resetPattern
end

local function Enter(info)
    local store = Store()
    local run = store.current
    local now = time()
    local away = now - (run and run.lastSeen or now)
    local reset = run and resetNames[run.name or ""]
    local emptied = run and info.kind == "party" and away > EMPTY
    if run and (run.map ~= info.map or away > STALE or reset or emptied) then
        Archive(run)
        run = nil
    end
    if not run then
        run = NewRun(info)
        store.current = run
    end
    resetNames[run.name or ""] = nil
    run.name, run.difficulty = info.name or run.name, info.difficulty or run.difficulty
    R.inside, R.enteredAt = true, GetTime()
    R.entry = { money = run.money, xp = run.xp, kills = run.kills, time = run.time }
    R.money = GetMoney and GetMoney() or 0
    Bubble()
    for _, unit in ipairs({ "target", "mouseover", "boss1" }) do LookForCopy(unit) end
end

local function Leave()
    if not R.inside then return end
    Bank()
    R.inside, R.enteredAt = false, nil
    local run = Store().current
    if run then run.lastSeen = time() end
    Bubble()
    -- no summary for a corpse run: you are only stepping out to come straight back
    local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    if not dead then SummaryCard(run) end
end

local function CheckWhere()
    if not ns.db then return end
    local info = InstanceNow()
    if info then
        local run = Store().current
        if R.inside and run and run.map == info.map then return end   -- moving between parts of it
        if R.inside then Leave() end
        Enter(info)
    elseif R.inside then
        Leave()
    end
end

-- ---------------------------------------------------------------- gains, called from Core

function R.AddXP(n)
    local run = Store and ns.db and Store().current
    if R.inside and run and type(n) == "number" and n > 0 then run.xp = run.xp + n end
end

function R.AddKill()
    local run = ns.db and Store().current
    if R.inside and run then run.kills = run.kills + 1 end
end

-- "X has been reset.": that dungeon's run is over; going back in starts a new one
local function OnSystem(msg)
    if not (ns.Readable(msg) and type(msg) == "string") then return end
    local pat = ResetPattern()
    if not pat then return end
    local name = msg:match(pat)
    if not name then return end
    resetNames[name] = true
    local store = Store()
    local run = store.current
    if run and run.name == name and not R.inside then
        Archive(run)
        store.current = nil
    end
end

local function OnMoney()
    if not GetMoney then return end
    local now = GetMoney()
    local gained = now - (R.money or now)
    R.money = now
    local run = ns.db and Store().current
    -- only money coming in counts: repairs and vendor buys do not take away from the haul
    local selling = ns.Vendor and ns.Vendor.open        -- vendor sales are not dungeon loot
    if R.inside and run and gained > 0 and not selling then run.money = run.money + gained end
end

-- ---------------------------------------------------------------- hover panel

-- the bottom row of the hover panel while inside: this run instead of the whole session
function R.DetailRows()
    local run = ns.db and ns.db.instanceTracker and R.inside and Store().current
    if not run then return nil end
    return {
        { L["RUN GOLD"], (run.money or 0) > 0 and ("+" .. R.Money(run.money)) or "--" },
        { L["RUN KILLS"], (run.kills or 0) > 0 and ns.Comma(run.kills) or "--" },
        { L["RUN XP"], (run.xp or 0) > 0 and ns.Short(run.xp) or "--" },
        { L["IN INSTANCE"], ns.Clock(Elapsed(run)) },
    }
end

R.Refresh = Bubble

-- ---------------------------------------------------------------- slash: /island runs

function R.Report()
    local store = Store()
    local run = store.current
    if run then
        ns.Print((R.inside and L["current run: %s  %s  +%s  %s XP  %s kills"] or L["last run (you can still go back in): %s  %s  +%s  %s XP  %s kills"])
            :format(run.name or "?", ns.Clock(Elapsed(run)), R.Money(run.money), ns.Comma(run.xp or 0), ns.Comma(run.kills or 0)))
    else
        ns.Print(L["no instance run yet."])
    end
    for i = 1, math.min(5, #store.history) do
        local h = store.history[i]
        ns.Print(L["%d. %s  %s  +%s  %s XP  %s"]:format(i, h.name or "?", ns.Clock(h.time or 0), R.Money(h.money),
            ns.Comma(h.xp or 0), (date and date("%b %d %H:%M", h.started or 0) or "")))
    end
end

-- start over in the same instance (for example after resetting it by hand)
-- /island runs debug: why a new copy is or isn't noticed
function R.Debug()
    local run = Store().current
    local info = InstanceNow()
    ns.Print("inside " .. tostring(R.inside) .. ", run " .. tostring(run and run.name) .. " map " .. tostring(run and run.map)
        .. " copy " .. tostring(run and run.copy) .. ", here map " .. tostring(info and info.map))
    for _, unit in ipairs({ "target", "mouseover" }) do
        local ok, guid = pcall(UnitGUID, unit)
        local readable = ok and ns.Readable(guid)
        ns.Print(unit .. ": " .. (not ok and "error" or guid == nil and "none" or not readable and "hidden by the game"
            or tostring(guid)) .. (readable and ("  -> copy " .. tostring(CopyFromUnit(unit))) or ""))
    end
end

function R.Reset()
    local store = Store()
    Bank()
    if store.current then Archive(store.current) store.current = nil end
    R.inside = false
    CheckWhere()
    ns.Print(L["instance run reset."])
end

function ns.DemoInstance()
    I:SetActivity("instanceDemo", { glyph = "Door", tone = BLUE, priority = 1, text = function() return "23:41" end })
    C_Timer.After(6, function() I:SetActivity("instanceDemo", nil) end)
    SummaryCard({ name = "The Deadmines", time = 1421, money = 23456, xp = 18420, kills = 61 })
end

-- ---------------------------------------------------------------- events

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        R.money = GetMoney and GetMoney() or 0
        C_Timer.After(1, CheckWhere)
    elseif event == "PLAYER_LOGOUT" then
        Bank()
    elseif event == "PLAYER_MONEY" then
        OnMoney()
    elseif event == "CHAT_MSG_SYSTEM" then
        OnSystem(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then
        LookForCopy("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        LookForCopy("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        LookForCopy(unit)
    elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        LookForCopy("boss1")
    else
        C_Timer.After(0.5, CheckWhere)
    end
end)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_MONEY",
                         "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
                         "CHAT_MSG_SYSTEM" }) do
    pcall(ev.RegisterEvent, ev, event)
end

-- keep the banked time fresh in case the game closes without a clean logout
if C_Timer.NewTicker then C_Timer.NewTicker(30, function() if R.inside then Bank() end end) end
