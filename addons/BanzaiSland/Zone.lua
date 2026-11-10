-- Island: zone card. Shows the zone or subzone you just entered and who controls it.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local I, C = ns.Island, ns.C

local GREEN = { 0.36, 0.85, 0.45 }
local RED = { 0.95, 0.38, 0.38 }
local ORANGE = { 0.98, 0.66, 0.28 }
local BLUE = { 0.45, 0.80, 1.00 }
local MUTED_HEX = ns.Hex(C.muted[1], C.muted[2], C.muted[3])

local function Plain(text)          -- the game's strings come wrapped in brackets: "(Contested Territory)"
    if type(text) ~= "string" then return nil end
    return (text:gsub("^%s*%(", ""):gsub("%)%s*$", ""))
end

-- Who a zone belongs to, for when the game does not say. WoW Forever (like retail with War Mode
-- off) reports no status for open-world zones unless world PvP is on for you, so the card would
-- show nothing for Hillsbrad. Known by map number, and by English name as a fallback.
local OWNER = {
    -- Alliance
    [1429] = "Alliance", [1436] = "Alliance", [1433] = "Alliance", [1431] = "Alliance", [1432] = "Alliance",
    [1426] = "Alliance", [1437] = "Alliance", [1438] = "Alliance", [1439] = "Alliance",
    [1453] = "Alliance", [1455] = "Alliance", [1457] = "Alliance",
    -- Horde
    [1411] = "Horde", [1412] = "Horde", [1413] = "Horde", [1420] = "Horde", [1421] = "Horde",
    [1454] = "Horde", [1456] = "Horde", [1458] = "Horde",
    -- contested
    [1416] = "contested", [1417] = "contested", [1418] = "contested", [1419] = "contested", [1422] = "contested",
    [1423] = "contested", [1424] = "contested", [1425] = "contested", [1427] = "contested", [1428] = "contested",
    [1430] = "contested", [1434] = "contested", [1435] = "contested", [1440] = "contested", [1441] = "contested",
    [1442] = "contested", [1443] = "contested", [1444] = "contested", [1445] = "contested", [1446] = "contested",
    [1447] = "contested", [1448] = "contested", [1449] = "contested", [1451] = "contested", [1452] = "contested",
}
local OWNER_NAME = {
    ["Elwynn Forest"] = "Alliance", ["Westfall"] = "Alliance", ["Redridge Mountains"] = "Alliance",
    ["Duskwood"] = "Alliance", ["Loch Modan"] = "Alliance", ["Dun Morogh"] = "Alliance", ["Wetlands"] = "Alliance",
    ["Teldrassil"] = "Alliance", ["Darkshore"] = "Alliance", ["Stormwind City"] = "Alliance",
    ["Ironforge"] = "Alliance", ["Darnassus"] = "Alliance",
    ["Durotar"] = "Horde", ["Mulgore"] = "Horde", ["The Barrens"] = "Horde", ["Tirisfal Glades"] = "Horde",
    ["Silverpine Forest"] = "Horde", ["Orgrimmar"] = "Horde", ["Thunder Bluff"] = "Horde", ["Undercity"] = "Horde",
    ["Alterac Mountains"] = "contested", ["Arathi Highlands"] = "contested", ["Badlands"] = "contested",
    ["Blasted Lands"] = "contested", ["Western Plaguelands"] = "contested", ["Eastern Plaguelands"] = "contested",
    ["Hillsbrad Foothills"] = "contested", ["The Hinterlands"] = "contested", ["Searing Gorge"] = "contested",
    ["Burning Steppes"] = "contested", ["Deadwind Pass"] = "contested", ["Stranglethorn Vale"] = "contested",
    ["Swamp of Sorrows"] = "contested", ["Ashenvale"] = "contested", ["Thousand Needles"] = "contested",
    ["Stonetalon Mountains"] = "contested", ["Desolace"] = "contested", ["Feralas"] = "contested",
    ["Dustwallow Marsh"] = "contested", ["Tanaris"] = "contested", ["Azshara"] = "contested",
    ["Felwood"] = "contested", ["Un'Goro Crater"] = "contested", ["Silithus"] = "contested",
    ["Winterspring"] = "contested",
}

-- the zone you are in, as a map number (the zone itself, not a city district or a cave inside it)
local function ZoneMap()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok then return nil end
    for _ = 1, 5 do
        if not id or OWNER[id] then return id end
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
        if not info or (Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Zone) then return id end
        id = info.parentMapID
    end
    return id
end

local function KnownOwner(zone)
    local id = ZoneMap()
    return (id and OWNER[id]) or (zone and OWNER_NAME[zone]) or nil
end

-- label and color for the zone's pvp status
local function Territory()
    local getInfo = (C_PvP and C_PvP.GetZonePVPInfo) or GetZonePVPInfo
    local pvpType, faction
    if getInfo then
        local ok, t, _, f = pcall(getInfo)
        if ok then pvpType, faction = t, f end
    end
    if pvpType == nil or pvpType == "" then
        -- the game says nothing: use what is known about the zone
        local owner = KnownOwner(GetRealZoneText and GetRealZoneText())
        if owner == "contested" then
            pvpType = "contested"
        elseif owner then
            local mine = UnitFactionGroup and UnitFactionGroup("player")
            local shown = (owner == "Alliance" and FACTION_ALLIANCE) or (owner == "Horde" and FACTION_HORDE) or owner
            pvpType, faction = (owner == mine) and "friendly" or "hostile", shown
        end
    end
    if pvpType == "sanctuary" then
        return Plain(SANCTUARY_TERRITORY) or L["Sanctuary"], BLUE, pvpType
    elseif pvpType == "contested" then
        return Plain(CONTESTED_TERRITORY) or L["Contested Territory"], ORANGE, pvpType
    elseif pvpType == "friendly" or pvpType == "hostile" then
        local label
        if faction and faction ~= "" then
            label = Plain(FACTION_CONTROLLED_TERRITORY and FACTION_CONTROLLED_TERRITORY:format(faction)) or L["%s Territory"]:format(faction)
        else
            label = pvpType == "friendly" and L["Friendly Territory"] or L["Hostile Territory"]
        end
        return label, pvpType == "friendly" and GREEN or RED, pvpType
    elseif pvpType == "arena" then
        return Plain(FREE_FOR_ALL_TERRITORY) or L["Free for All"], RED, pvpType
    elseif pvpType == "combat" then
        return Plain(COMBAT_ZONE) or L["Combat Zone"], RED, pvpType
    end
    return nil, nil, pvpType
end

-- `other` is the second place name shown in grey: the area inside a zone, or the zone an area is in
local function Fields(title, other, label, tone, hold)
    tone = tone or C.muted
    local line
    if label then line = ns.Hex(tone[1], tone[2], tone[3]) .. label .. "|r" end
    if other then line = MUTED_HEX .. other .. "|r" .. (line and ("   " .. line) or "") end
    return {
        kind = "won", key = "zone", transient = true, priority = 0, glyph = "Compass", tone = label and tone or C.disc, cap = L["ENTERING"],
        -- Zone card style: centred, centred with the compass above, or the usual layout
        capColor = (ns.db.zoneStyle ~= "classic") and (label and tone or C.disc) or nil,
        centered = (ns.db.zoneStyle == "icon") and "icon" or (ns.db.zoneStyle ~= "classic"),
        title = title, color = C.fg, res = "", line = line, hold = hold or 3.4,
    }
end

local function Show(item) item.group = "world" I:PushReplace(item) end

local last = {}
local pendingCheck = false

local function Check()
    pendingCheck = false
    if not I.built then return end
    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
    local sub = (GetSubZoneText and GetSubZoneText()) or ""
    if zone == "" then return end
    if sub == zone then sub = "" end
    local label, tone, pvpType = Territory()
    local zoneChanged = zone ~= last.zone
    local subChanged = sub ~= last.sub
    local statusChanged = pvpType ~= last.pvp
    last.zone, last.sub, last.pvp = zone, sub, pvpType

    if zoneChanged then
        if ns.db.zoneCards then Show(Fields(zone, sub ~= "" and sub or nil, label, tone)) end
    elseif (subChanged or statusChanged) and ns.db.subzoneCards then
        if sub ~= "" then
            Show(Fields(sub, zone, label, tone, 2.6))
        elseif statusChanged or subChanged then
            Show(Fields(zone, nil, label, tone))
        end
    end
end

-- Zone events arrive in clumps and the pvp status settles a moment later, so wait briefly.
local function Queue()
    if pendingCheck then return end
    pendingCheck = true
    C_Timer.After(0.4, Check)
end

-- ---------------------------------------------------------------- Blizzard zone text

local hooked = {}
function ns.ApplyZoneText()
    if not ns.db.hideZoneText then return end
    for _, name in ipairs({ "ZoneTextFrame", "SubZoneTextFrame" }) do
        local f = _G[name]
        if f and type(f) == "table" and f.Hide then
            if not hooked[name] and f.Show then
                hooked[name] = true
                hooksecurefunc(f, "Show", function(self)
                    if ns.db.hideZoneText then self:Hide() end
                end)
            end
            f:Hide()
        end
    end
end

function ns.DemoZone()
    if not I.built then return end
    I:Push(Fields("Stranglethorn Vale", "Rebel Camp", L["Contested Territory"], ORANGE))
    I:Push(Fields("Grom'gol Base Camp", "Stranglethorn Vale", L["%s Territory"]:format(FACTION_HORDE or "Horde"), GREEN, 2.6))
    I:Push(Fields("Booty Bay", "Stranglethorn Vale", L["Sanctuary"], BLUE, 2.6))
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        ns.ApplyZoneText()
        C_Timer.After(3, Queue)
    else
        Queue()
    end
end)
for _, event in ipairs({ "PLAYER_LOGIN", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }) do
    pcall(ev.RegisterEvent, ev, event)
end
