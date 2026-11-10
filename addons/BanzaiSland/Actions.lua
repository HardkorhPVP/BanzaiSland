-- Island: what clicking a card does. Cards that do not set their own click get one here,
-- worked out from what the card is about: whisper a friend who came online, put a looted item
-- in chat, open the map for a new zone, the character sheet for broken gear, and so on.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local function Safe(fn) return function() pcall(fn) end end

local function Whisper(name)
    return Safe(function()
        local api = _G.PigeonAPI
        if ns.db.usePigeon and type(api) == "table" and type(api.Open) == "function" then
            api.Open(name)
        elseif ChatFrame_SendTell then
            ChatFrame_SendTell(name)
        end
    end)
end

-- put a link in the chat box, opening it if needed
local function LinkInChat(link)
    return Safe(function()
        if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return end
        if ChatFrame_OpenChat then ChatFrame_OpenChat(link) end
    end)
end

local function OpenQuestLog()
    if SlashCmdList and SlashCmdList.ISLANDQUESTLOG then
        SlashCmdList.ISLANDQUESTLOG("")
    elseif ToggleQuestLog then
        ToggleQuestLog()
    end
end

local function OpenBags()
    if ToggleAllBags then ToggleAllBags() elseif OpenAllBags then OpenAllBags() end
end

-- a map pin for a find, through TomTom if it is installed, otherwise the game's own waypoint
local function Waypoint(wp, title)
    return Safe(function()
        local map, x, y = wp.map, wp.x, wp.y
        if x > 100 or y > 100 then x, y = x / 10000, y / 10000 elseif x > 1 or y > 1 then x, y = x / 100, y / 100 end
        -- the island's own arrow, beside the island
        if ns.Nav then ns.Nav:Set(map, x, y, title, wp.where) end
        -- and a marker on the map: TomTom's if installed, otherwise the game's own
        local tomtom = _G.TomTom
        if type(tomtom) == "table" and tomtom.AddWaypoint then
            tomtom:AddWaypoint(map, x, y, { title = title })
        elseif C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
            pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(map, x, y))
        end
    end)
end

-- returns the click function and the hover hint for a card, or nil
function ns.CardAction(item)
    local key = type(item.key) == "string" and item.key or ""
    local cap = item.cap or ""

    if item.whisperTo then return Whisper(item.whisperTo), L["Click to whisper %s"]:format(item.whisperTo) end
    local who = key:match("^friend:(.+)") or key:match("^guild:(.+)")
    -- friend and guild cards say whether they came online; the caption is only a fallback (it's translated)
    local online = item.online
    if online == nil then online = cap:find(L["ONLINE"], 1, true) and not cap:find(L["OFFLINE"], 1, true) end
    if who and online then return Whisper(who), L["Click to whisper %s"]:format(who) end
    local sender = key:match("^whisper:(.+)")
    if sender and not tonumber(sender) then return Whisper(sender), L["Click to reply"] end

    if item.waypoint then return Waypoint(item.waypoint, item.title), L["Click to point the way there"] end

    if item.link and item.link:find("|H", 1, true) then
        return LinkInChat(item.link), L["Click to link it in chat"]
    end

    if key == "durability" then return Safe(function() ToggleCharacter("PaperDollFrame") end), L["Click to open your character"] end
    if key == "bags" then return Safe(OpenBags), L["Click to open your bags"] end
    if key:find("^rep:") then return Safe(function() ToggleCharacter("ReputationFrame") end), L["Click to open reputation"] end
    if key == "zone" then return Safe(function() ToggleWorldMap() end), L["Click to open the map"] end
    if key == "questprogress" then return Safe(OpenQuestLog), L["Click to open the quest log"] end
    if key == "skill" then return Safe(function() ToggleSpellBook(BOOKTYPE_PROFESSION or "professions") end), nil end
    if key == "instance" and ns.Instance then return Safe(ns.Instance.Report), L["Click to list your recent runs in chat"] end
    if cap == L["CALENDAR"] then return Safe(function() if ToggleCalendar then ToggleCalendar() elseif Calendar_Toggle then Calendar_Toggle() end end), L["Click to open the calendar"] end
    return nil
end
