-- Island: party and raid changes. Cards when people join or leave, go offline or come back,
-- when the leader changes, and when you join, leave or the party becomes a raid. Changes that
-- land close together (a raid filling up) are gathered into one card.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local I, C = ns.Island, ns.C
local GREEN = { 0.36, 0.85, 0.45 }
local RED = { 0.95, 0.38, 0.38 }
local GOLD = C.gold
local BLUE = { 0.40, 0.72, 1.00 }
local MUTED_HEX = ns.Hex(C.muted[1], C.muted[2], C.muted[3])
local NBSP = "\194\160"
local GATHER = 1.5          -- seconds to wait for more changes before showing a card
local SOUND = 3332

local G = { roster = {}, leader = nil, inGroup = false, raid = false, ready = false }
ns.Group = G

local function Allowed()
    if not ns.db then return false end
    if IsInRaid and IsInRaid() then return ns.db.groupRaid end
    return ns.db.groupParty
end

local function Name(unit)
    local ok, name, realm = pcall(UnitName, unit)
    if not ok or not ns.Readable(name) or type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return nil end
    if ns.Readable(realm) and type(realm) == "string" and realm ~= "" then name = name .. "-" .. realm end
    return name
end

local function Colored(name, class)
    local short = (ns.ShowName(name or "?") or "?"):gsub(" ", NBSP)
    local hex = class and ns.ClassHex and ns.ClassHex(class) -- BanzaiSland 0.3.0: one class-colour authority
    if hex then return hex .. short .. "|r" end
    return short
end

local function Units()
    local list = {}
    if IsInRaid and IsInRaid() then
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do list[#list + 1] = "raid" .. i end
    else
        list[1] = "player"
        for i = 1, 4 do list[#list + 1] = "party" .. i end
    end
    return list
end

-- who is in the group right now: name -> { class, online, leader }; nil if names are hidden
local function Snapshot()
    local roster, leader = {}, nil
    for _, unit in ipairs(Units()) do
        if UnitExists(unit) then
            local name = Name(unit)
            if not name then return nil end
            local _, class = UnitClass(unit)
            local online = not UnitIsConnected or UnitIsConnected(unit)
            if not ns.Readable(online) then online = true end
            roster[name] = { class = class, online = online and true or false }
            if UnitIsGroupLeader and UnitIsGroupLeader(unit) then leader = name end
        end
    end
    return roster, leader
end

-- ---------------------------------------------------------------- gathering cards

local pending = { joined = {}, left = {}, offline = {}, online = {} }
local timerOn = false

local function NameList(list)
    local names = {}
    for i = 1, math.min(#list, 6) do names[i] = Colored(list[i].name, list[i].class) end
    local text = table.concat(names, ", ")
    if #list > 6 then text = text .. MUTED_HEX .. " " .. L["and %d more"]:format(#list - 6) .. "|r" end
    return text
end

local KINDS = {
    { key = "joined",  glyph = "Person", tone = GREEN,    one = { party = L["JOINED PARTY"], raid = L["JOINED RAID"] },             many = { party = L["%d JOINED PARTY"], raid = L["%d JOINED RAID"] } },
    { key = "left",    glyph = "Person", tone = C.muted,  one = { party = L["LEFT PARTY"], raid = L["LEFT RAID"] },                 many = { party = L["%d LEFT PARTY"], raid = L["%d LEFT RAID"] } },
    { key = "offline", glyph = "Person", tone = RED,      one = { party = L["DISCONNECTED PARTY"], raid = L["DISCONNECTED RAID"] }, many = { party = L["%d DISCONNECTED PARTY"], raid = L["%d DISCONNECTED RAID"] } },
    { key = "online",  glyph = "Person", tone = BLUE,     one = { party = L["RECONNECTED PARTY"], raid = L["RECONNECTED RAID"] },   many = { party = L["%d RECONNECTED PARTY"], raid = L["%d RECONNECTED RAID"] } },
}

local function Flush()
    timerOn = false
    if not Allowed() then
        for k in pairs(pending) do pending[k] = {} end
        return
    end
    local where = (IsInRaid and IsInRaid()) and "raid" or "party"
    for _, k in ipairs(KINDS) do
        local list = pending[k.key]
        if #list > 0 then
            I:PushCard({ group = "social",
                kind = "won", key = "group" .. k.key, glyph = k.glyph, tone = k.tone,
                cap = (#list == 1 and k.one[where] or string.format(k.many[where], #list)), capColor = k.tone,
                title = NameList(list), color = C.fg, hold = 2.6, priority = 1, sound = k.key == "offline" and SOUND or nil,
            })
            pending[k.key] = {}
        end
    end
end

local function Queue(kind, name, class)
    -- someone who left and came straight back, or dropped and returned, cancels out
    local opposite = ({ joined = "left", left = "joined", offline = "online", online = "offline" })[kind]
    for i, e in ipairs(pending[opposite]) do
        if e.name == name then table.remove(pending[opposite], i) return end
    end
    table.insert(pending[kind], { name = name, class = class })
    if not timerOn then
        timerOn = true
        C_Timer.After(GATHER, Flush)
    end
end

local function Card(glyph, tone, cap, title, line)
    if not Allowed() and not (cap == L["LEFT GROUP"]) then return end
    I:PushCard({ group = "social", kind = "won", key = "group", glyph = glyph, tone = tone, cap = cap, capColor = tone, title = title,
                 color = C.fg, line = line and (MUTED_HEX .. line .. "|r") or nil, hold = 2.8, priority = 1 })
end

-- ---------------------------------------------------------------- roster changes

local function Update()
    local inGroup = IsInGroup and IsInGroup() or false
    local raid = IsInRaid and IsInRaid() or false
    local roster, leader = Snapshot()
    if not roster then return end          -- names hidden right now: compare again later

    if not G.ready then
        G.roster, G.leader, G.inGroup, G.raid, G.ready = roster, leader, inGroup, raid, true
        return
    end
    local me = Name("player")

    if inGroup and not G.inGroup then
        -- you joined a group: one card for that, not one per member
        local who = leader and leader ~= me and Colored(leader, roster[leader] and roster[leader].class) or nil
        local count = 0
        for _ in pairs(roster) do count = count + 1 end
        Card("Person", GREEN, raid and L["JOINED RAID"] or L["JOINED PARTY"], who and (raid and L["%s's raid"]:format(who) or L["%s's party"]:format(who)) or (raid and L["New raid"] or L["New party"]),
             (count == 1 and L["%d member"] or L["%d members"]):format(count))
    elseif not inGroup and G.inGroup then
        if ns.db and (ns.db.groupParty or ns.db.groupRaid) then
            Card("Person", C.muted, L["LEFT GROUP"], G.raid and L["You left the raid"] or L["You left the party"])
        end
    elseif inGroup then
        if raid and not G.raid then Card("Flag", BLUE, L["NOW A RAID"], L["The party became a raid"]) end
        for name, info in pairs(roster) do
            local before = G.roster[name]
            if name ~= me then
                if not before then
                    Queue("joined", name, info.class)
                elseif before.online and not info.online then
                    Queue("offline", name, info.class)
                elseif not before.online and info.online then
                    Queue("online", name, info.class)
                end
            end
        end
        for name, info in pairs(G.roster) do
            if not roster[name] and name ~= me then Queue("left", name, info.class) end
        end
        if leader and G.leader and leader ~= G.leader then
            local mine = leader == me
            Card("Star", GOLD, L["NEW LEADER"], mine and L["You are now the leader"] or Colored(leader, roster[leader] and roster[leader].class))
        end
    end
    G.roster, G.leader, G.inGroup, G.raid = roster, leader, inGroup, raid
end

function ns.DemoGroup()
    Card("Person", GREEN, L["JOINED PARTY"], L["%s's party"]:format(Colored("Thrall", "SHAMAN")), L["%d members"]:format(4))
    I:PushCard({ group = "social", kind = "won", key = "groupjoined", glyph = "Person", tone = GREEN, cap = L["%d JOINED RAID"]:format(3), capColor = GREEN,
                 title = Colored("Jaina", "MAGE") .. ", " .. Colored("Uther", "PALADIN") .. ", " .. Colored("Rexxar", "HUNTER"), color = C.fg, hold = 2.6 })
    I:PushCard({ group = "social", kind = "won", key = "groupoffline", glyph = "Person", tone = RED, cap = L["DISCONNECTED RAID"], capColor = RED,
                 title = Colored("Valeera", "ROGUE"), color = C.fg, hold = 2.6 })
    Card("Star", GOLD, L["NEW LEADER"], Colored("Jaina", "MAGE"))
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(3, Update)        -- after the group has loaded, as the starting point
    elseif G.ready or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.2, Update)
    end
end)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "UNIT_CONNECTION" }) do
    pcall(ev.RegisterEvent, ev, event)
end
