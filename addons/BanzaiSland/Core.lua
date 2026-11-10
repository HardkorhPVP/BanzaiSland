-- Island: saved settings, player data and the game events that feed the island.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

BINDING_HEADER_BANZAISLAND = L["BanzaiSland"]
BINDING_NAME_BANZAISLAND_DND = L["Toggle Do Not Disturb"]
BINDING_NAME_BANZAISLAND_CARD1 = L["Card: 1st button (Accept, Ready, Need, Join, Release spirit, Enter, Pause)"]
BINDING_NAME_BANZAISLAND_CARD2 = L["Card: 2nd button (Decline, Not ready, Greed, Leave queue, Skip or Stop)"]
BINDING_NAME_BANZAISLAND_CARD3 = L["Card: 3rd button (Disenchant or Pass on loot rolls, Stop on voiceovers)"]
BINDING_NAME_BANZAISLAND_CARD4 = L["Card: 4th button (Pass, on loot rolls that can be disenchanted)"]
BINDING_NAME_BANZAISLAND_CARDLAST = L["Card: last button (Decline, Not ready, Pass, Cancel: whichever is last)"]
BINDING_NAME_BANZAISLAND_DISMISS = L["Close the current card"]
BINDING_NAME_BANZAISLAND_DETAILS = L["Show or hide the island's details (guide button by default)"]

local floor, min, max = math.floor, math.min, math.max

ns.defaults = {
    retailRenown = true,
    retailWarband = true,
    retailGear = true,
    retailVault = true,
    bubbleRetailVault = true,
    bubbleRetailKnowledge = true,
    bubbleRetailQueue = true,
    bubbleRetailDialogue = true,
    retailMythic = true,
    retailDelves = true,
    retailKnowledge = true,
    retailOrders = true,
    retailCollections = true,
    retailHousing = true,
    retailLoadouts = true,
    retailQueues = true,
    retailBossLoot = true,
    retailTalkingHead = true,
    retailTalkingHeadHide = true,
    catchUpRetailProgress = true,
    catchUpCollections = true,
    catchUpHousing = true,
    scale = 1,
    x = 0,
    y = -14,
    locked = true,
    hideBlizzard = true,
    showKills = true,
    showQuests = true,
    showDiscoveries = true,
    showLevelUp = true,
    talentReminder = true,
    legacyReminder = true,
    showLegacyChallenges = true,
    legacyPartialProgress = false,
    catchUp = true,
    catchUpBubble = true,
    catchUpMinimum = 60,
    catchUpExpire = 60,
    catchUpWhispers = true,
    catchUpAuctions = true,
    catchUpMail = true,
    catchUpCooldowns = true,
    catchUpLegacy = true,
    catchUpSocial = true,
    showRested = true,
    questXPBar = false,
    repAtMax = true,
    hoverDetails = true,
    minimapButton = true,   -- a button on the minimap that opens Island's settings
    minimapAngle = 215,     -- where it sits around the minimap, in degrees
    lootRolls = true,
    showRollWinners = true,
    toastItems = true,
    toastUpgrades = true,
    rollUpgrades = true,
    toastRewards = true,
    itemTreeUpgrades = true,
    lootifiedUpgrades = true,
    pawnUpgrades = true,
    toastMoney = true,
    moneyBubble = false,      -- money in a coin bubble instead of where XP gains show
    toastCurrency = true,
    toastRep = true,
    itemMinQuality = 2,
    alertDurability = true,
    durabilityThreshold = 25,
    durabilityReminder = true,
    repairDot = true,
    instanceTracker = true,
    instanceSummary = true,
    groupParty = true,
    groupRaid = true,
    vendorSell = true,
    vendorRepair = true,
    alertBags = true,
    bagThreshold = 3,
    bagReminder = false,
    alertMail = true,
    alertFriends = true,
    zoneCards = true,
    subzoneCards = true,
    hideZoneText = true,
    hideBlizzardPopups = true,
    showErrors = true,
    dnd = false,
    extensions = {version=1,enabled={}},
    developer = {version=1,trusted=false,nextId=1,rules={}},
    packages = {version=1,list={}},
    spokenCard = true,      -- Spoken voiceovers play on the island
    spokenHide = true,
    spokenTicker = true,    -- small news slides along the voiceover card instead of interrupting it      -- and Spoken's own window steps aside meanwhile
    navTomTom = true,       -- the nav bubble follows TomTom's arrow
    navHideTomTom = true,   -- and TomTom's own arrow stays out of sight meanwhile
    navRXP = true,          -- the nav bubble follows RestedXP Guides' arrow when nothing else is pinned
    navTiles = true,        -- the guide's step list as rounded tiles with a small icon per step
    navHideRXP = true,      -- and that arrow stays out of sight meanwhile
    rxpStepCards = true,    -- a card when RestedXP Guides starts a new step
    rxpStepBubble = true,   -- a bubble holding the current step
    rxpStepBubbleBar = true,-- with the guide's progress along its bottom
    rxpDoneBubble = false,  -- a short bubble when a step is done
    rxpHideWindow = false,  -- RestedXP's own guide window out of sight (Island's panel replaces it)
    navPolestar = true,     -- the nav bubble follows Polestar's arrow when nothing else is pinned
    navHidePolestar = true, -- and that arrow stays out of sight meanwhile
    polestarStepCards = true,     -- a card when Polestar starts a new step
    polestarStepBubble = true,    -- a bubble holding the current step
    polestarStepBubbleBar = true, -- with the guide's progress along its bottom
    polestarHideWindow = false,   -- Polestar's own guide window out of sight (Island's panel replaces it)
    promptDeath = true,
    promptBattleground = true,
    promptLootConfirm = true,
    promptConfirmations = true,
    promptRefresh = true,   -- the forced layer change: a card, a countdown bubble and Refresh now / Okay on the island
    promptReady = true,
    promptRequests = true,
    showWhispers = true,
    usePigeon = true,
    showRares = true,
    useRareScanner = true,
    showQuestProgress = true,
    showSkillUps = true,
    liveFlight = true,
    flightHideStop = true,
    liveHearth = true,
    liveTimers = true,
    liveQueue = true,
    bubbleCount = 2,
    shelf = { pins = {}, order = {} },   -- the activity shelf: pinned and ordered activities (by key)
    bubblesUrgentOnly = false,
    bubbleBars = true,           -- Island's own running timers show a bar on their bubble
    liveAmmo = true,          -- the ammo bubble (with a bow, gun or crossbow)
    pinAmmo = false, pinTracking = false, pinRested = false,   -- pinned to the other side, always shown
    showGameCountdown = false,
    zoneStyle = "classic",
    builderPick = "zone",     -- the kind of card shown in the card builder   -- zone cards: centered, icon (centred with the compass above), classic
    keyHints = true,          -- show the bound key on card buttons
    padCards = true,          -- answer cards with the controller (D-pad, A, B)
    padGuide = true,          -- the guide button shows the island's details
    padRumble = true,         -- a short rumble for important cards    -- the game's big countdown numbers in the middle of the screen        -- how many activity bubbles can show at once (1-4)
    liveLure = true,
    liveProfCD = true,
    liveTracking = true,
    livePull = true,
    liveShutdown = true,
    liveReady = true,
    liveLockout = true,
    sealPill = true,
    sealSide = "below",
    sealWarn = true,
    buffHideBlizzard = false,
    toastAuction = true,
    alertCalendar = true,
    alertGuild = false,
    alertReagents = true,
    alertBuffs = true,
    sounds = true,
    holdInCombat = true,
    holdWhileTyping = true,
    quietInRaid = false,
    cardTime = 1,
    xpColor = { 0.655, 0.545, 0.980 },
    restColor = { 0.365, 0.706, 1.000 },
    questXPColor = { 0.949, 0.780, 0.251 },
    -- look
    lookStyle = "modern",     -- modern or forever; paint only
    opacity = 1,              -- 1 solid black; lower lets the world show through
    accent = { 0.655, 0.545, 0.980 },
    accentMode = "bar",
    barMode = "custom",       -- custom (the bar colour you pick) or class       -- bar (follows the bar colour), class, or custom
    accentBubbles = false,    -- tint the bubble icons with the accent too
    textScale = 1,
    font = "auto",
    fontOutline = "none",     -- none, thin, thick
    borderOn = false,         -- optional border around the island
    borderSize = 2,
    borderColor = { 1, 1, 1 },
    borderAlpha = 1,
    bubbleBorderOn = false,   -- same border on the bubbles and pins, in the island border's style
    borderClass = false,    -- use the player's class colour instead of borderColor
    panelBorderClass = false,
    borderTexture = "solid",  -- solid, or a LibSharedMedia border name
    panelBorderOn = false,    -- settings window border and background
    panelBorderSize = 2,
    panelBorderColor = { 1, 1, 1 },
    panelBorderAlpha = 0.25,
    panelBgColor = { 0.03, 0.03, 0.04 },
    panelBgAlpha = 0.97,
    idleStyle = "full",       -- full, percent, bar, dot
    -- placement
    bubbleSide = "right",     -- right, left, below
    shellColor = { 0, 0, 0 }, -- pill and card fill (Modern style)
    growY = "auto",           -- auto (by screen half), down, up
    growX = "auto",          -- auto, center, left (left edge fixed), right (right edge fixed)
    combatFade = "off",       -- off, dim, hide
    -- behaviour
    feel = "smooth",          -- snappy, smooth, calm
    timeLoot = "normal", timeSocial = "normal", timeAlerts = "normal", timeWorld = "normal",
    soundLoot = true, soundSocial = true, soundAlerts = true, soundWorld = true, soundPrompts = true,
    whisperSound = "default", promptSound = "default", rollSound = "none",
    cardSounds = {}, -- per-card overrides; empty keeps legacy choices
}

-- Newer clients hand addons some values as "secret": they can be shown but not read or compared.
-- Anything that parses text checks this first and leaves such values alone.
function ns.Readable(v)
    if v == nil then return false end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, v)
        if ok and secret then return false end
    end
    return true
end

ns.session = { start = 0, xp = 0, rep = 0, kills = 0, lastGain = nil }

-- ---------------------------------------------------------------- names
-- In WoW Forever a character has a first name and a surname, and the second part of a name is the
-- surname (elsewhere it is the realm). Names are shown with the surname kept and realms dropped.
function ns.RegionalNames()
    if ns.regionalNames == nil then
        local ok, v = false, false
        if type(RegionalUniqueNamesEnabled) == "function" then ok, v = pcall(RegionalUniqueNamesEnabled) end
        ns.regionalNames = (ok and v) and true or false
    end
    return ns.regionalNames
end

-- a name to show: "Jeste-Ironfoot" is "Jeste Ironfoot" in Forever, "Thrall-Realm" is "Thrall" elsewhere
function ns.ShowName(name)
    if type(name) ~= "string" or not ns.Readable(name) or name == "" then return name end
    if ns.RegionalNames() then return (name:gsub("%-", " ")) end
    return name:match("^([^%-]+)") or name
end

-- the name of a unit to show, with its surname in Forever
function ns.UnitShowName(unit)
    if not UnitName then return nil end
    local ok, name, second = pcall(UnitName, unit)
    if not ok or not ns.Readable(name) or type(name) ~= "string" or name == "" then return nil end
    if ns.RegionalNames() and ns.Readable(second) and type(second) == "string" and second ~= "" then
        return name .. " " .. second
    end
    return name
end

-- the first part of a name, to tell whether two ways of writing a name are the same person
function ns.FirstName(name)
    if type(name) ~= "string" or not ns.Readable(name) then return nil end
    return name:match("^([^%-%s]+)") or name
end

-- ---------------------------------------------------------------- card groups

-- Cards fall into groups that share a display time and a sound switch: loot, social, alerts,
-- world (zones, quests, skills, rares) and prompts (cards waiting for an answer).
function ns.CardGroup(item)
    if type(item) ~= "table" then return "alerts" end
    if item.group then return item.group end
    if item.kind == "gain" then return "xp" end
    if item.kind == "toast" then return "world" end
    if item.buttons or item.prompt then return "prompts" end
    local key = type(item.key) == "string" and item.key or ""
    if key:find("^whisper") then return "social" end
    if key == "questprogress" or key == "skill" or key:find("^zone") or key:find("^rs:") or key:find("^rare") then
        return "world"
    end
    return "alerts"
end

local TIME_KEY = { loot = "timeLoot", social = "timeSocial", alerts = "timeAlerts", world = "timeWorld" }
local TIMES = { short = 0.6, normal = 1, long = 1.6 }

-- how long a card stays, as a share of normal: the Card time slider and its group's timing
function ns.CardTime(item)
    local db = ns.db
    local k = TIME_KEY[ns.CardGroup(item)]
    return (db.cardTime or 1) * (k and TIMES[db[k] or "normal"] or 1)
end

local SOUND_KEY = { loot = "soundLoot", social = "soundSocial", alerts = "soundAlerts", world = "soundWorld",
                    prompts = "soundPrompts" }

-- Notification sound choices. "default" keeps each card's own original sound.
ns.SOUNDS = {
    { key = "default", name = L["Default"] },
    { key = "whisper", name = L["Whisper"], kit = "TELL_MESSAGE", id = 3081 },
    { key = "chime",   name = L["Chime"],   kit = "UI_BNET_TOAST", id = 18019 },
    { key = "ping",    name = L["Ping"],    kit = "MAP_PING", id = 3175 },
    { key = "bell",    name = L["Bell"],    kit = "READY_CHECK", id = 8960 },
    { key = "horn",    name = L["Horn"],    kit = "RAID_WARNING", id = 8959 },
    { key = "alert",   name = L["Alert tone"], id = 12867 },
    { key = "friend",  name = L["Friend online"], id = 3332 },
    { key = "none",    name = L["None"] },
}
local function SoundId(choice)
    for _, s in ipairs(ns.SOUNDS) do
        if s.key == choice then
            if s.kit and SOUNDKIT and SOUNDKIT[s.kit] then return SOUNDKIT[s.kit] end
            return s.id
        end
    end
end
ns.SoundId = SoundId

-- Each Island-produced notification sound has a stable, untranslated setting key.
-- Pigeon/RareScanner-owned sounds still stay with those addons.
ns.CARD_SOUNDS = {
    {key="whisper", label=L["Whispers"], group="social", defaultId=3081, legacy="whisperSound"},
    {key="friendOnline", label=L["Friends online"], group="social", defaultId=3332},
    {key="guildOnline", label=L["Guild members online"], group="social", defaultId=3332},
    {key="groupDisconnect", label=L["Group disconnects"], group="social", defaultId=3332},
    {key="durability", label=L["Low durability"], group="alerts", defaultId=12867},
    {key="bags", label=L["Bags nearly full"], group="alerts", defaultId=12867},
    {key="mail", label=L["New mail"], group="alerts", defaultId=12867},
    {key="ammo", label=L["Low ammo"], group="alerts", defaultId=12867, feature="ammo"},
    {key="reagents", label=L["Low reagents"], group="alerts", defaultId=12867, feature="reagents"},
    {key="pull", label=L["Pull countdown"], group="alerts", defaultId=8960},
    {key="breakOver", label=L["Break finished"], group="alerts", defaultId=8960},
    {key="queueReady", label=L["Queue ready notice"], group="alerts", defaultId=8960},
    {key="rare", label=L["Rare alerts"], group="world", defaultId=8959},
    {key="lootRoll", label=L["Loot rolls"], group="prompts", legacy="rollSound"},
    {key="readycheck", label=L["Ready checks"], group="prompts", defaultId=8960, legacy="promptSound"},
    {key="invite", label=L["Party invites"], group="prompts", defaultId=8960, legacy="promptSound"},
    {key="guildInvite", label=L["Guild invites"], group="prompts", defaultId=8960, legacy="promptSound"},
    {key="duel", label=L["Duel requests"], group="prompts", defaultId=8960, legacy="promptSound"},
    {key="resurrect", label=L["Resurrection requests"], group="prompts", defaultId=8960, legacy="promptSound"},
    {key="summon", label=L["Summon requests"], group="prompts", defaultId=8960, legacy="promptSound"},
    {key="corpse", label=L["Corpse recovery"], group="prompts", defaultId=8960, legacy="promptSound"},
    {key="battleground", label=L["Battleground ready"], group="prompts", defaultId=8960, legacy="promptSound"},
    {key="bindPickup", label=L["Bind on pickup confirmations"], group="prompts", defaultId=8960, legacy="promptSound"},
    {key="bindEquip", label=L["Bind on equip confirmations"], group="prompts", defaultId=8960, legacy="promptSound"},
    {key="prompts", label=L["Other questions and confirmations"], group="prompts", defaultId=8960, legacy="promptSound"},
}
local cardSoundIndex = {}
for _, event in ipairs(ns.CARD_SOUNDS) do cardSoundIndex[event.key] = event end
local function SoundChoice(value)
    if type(value) ~= "string" or not ns.Readable(value) then return false end
    for _, sound in ipairs(ns.SOUNDS) do if sound.key == value then return true end end
    return false
end
function ns.GetCardSoundChoice(key)
    local event, db = cardSoundIndex[key], ns.db
    if not event then return "default" end
    local overrides = db and db.cardSounds
    local choice = type(overrides) == "table" and overrides[key]
    if SoundChoice(choice) then return choice end
    choice = event.legacy and db and db[event.legacy]
    if SoundChoice(choice) then return choice end
    return event.key == "lootRoll" and "none" or "default"
end
function ns.SetCardSoundChoice(key, choice)
    if not ns.db or not cardSoundIndex[key] or not SoundChoice(choice) then return false end
    if type(ns.db.cardSounds) ~= "table" then ns.db.cardSounds = {} end
    ns.db.cardSounds[key] = choice
    return true
end
function ns.CardSoundKey(item, group)
    if type(item) ~= "table" then return group == "prompts" and "prompts" or nil end
    local explicit = item.soundKey
    if type(explicit) == "string" and ns.Readable(explicit) and cardSoundIndex[explicit] then return explicit end
    if item.builderType == "rare" then return "rare" end
    local key = item.key or item.id
    if type(key) ~= "string" or not ns.Readable(key) then return group == "prompts" and "prompts" or nil end
    if key:find("^whisper") then return "whisper" end
    if key:find("^friend:") then return "friendOnline" end
    if key:find("^guild:") then return "guildOnline" end
    if key == "groupoffline" then return "groupDisconnect" end
    if key:find("^supply:") then return item.glyph == "Arrow" and "ammo" or "reagents" end
    if key:find("^rare") or key:find("^rs:") then return "rare" end
    if group == "prompts" then
        if key == "guild" then return "guildInvite" end
        if key:find("^bg%d") then return "battleground" end
        if key:find("^bindroll") or key:find("^bindloot") then return "bindPickup" end
        if key:find("^bindequip") then return "bindEquip" end
        return cardSoundIndex[key] and key or "prompts"
    end
    return cardSoundIndex[key] and key or nil
end

function ns.PreviewCardSound(key)
    local event = cardSoundIndex[key]
    if not event then return end
    local choice = ns.GetCardSoundChoice(key)
    if choice == "none" then return end
    local defaultId = (event.defaultKit and SOUNDKIT and SOUNDKIT[event.defaultKit]) or event.defaultId
    local id = choice == "default" and defaultId or SoundId(choice)
    -- An explicit audition is allowed even when automatic notifications are muted.
    if id and PlaySound then pcall(PlaySound, id, "SFX") end
end

function ns.PreviewSound(choice)
    local id = SoundId(choice)
    if id and PlaySound then pcall(PlaySound, id, "SFX") end
end

-- optional soft sound when a card opens; `id` is a sound kit number. `item` (the card) picks its
-- group's switch, and each registered notification can use its own chosen sound.
function ns.PlayCardSound(id, item, group)
    if id == false then return end -- explicitly suppressed/foreign-owned sound
    if id == nil and type(item) == "table" and item.builderType == "rare" then return end -- RareScanner owns its audio
    local db = ns.db
    if not db or not db.sounds or not PlaySound then return end
    group = group or ns.CardGroup(item)
    local k = SOUND_KEY[group]
    if k and db[k] == false then return end
    local eventKey = ns.CardSoundKey(item, group)
    local choice = eventKey and ns.GetCardSoundChoice(eventKey)
    if not choice then
        if group == "prompts" then choice = db.promptSound
        elseif type(item) == "table" and type(item.key) == "string" and ns.Readable(item.key) and item.key:find("^whisper") then choice = db.whisperSound end
    end
    if choice and choice ~= "default" then
        if choice == "none" then return end
        id = SoundId(choice) or id
    end
    if not id then return end
    pcall(PlaySound, id, "SFX")
end

-- ---------------------------------------------------------------- helpers

function ns.Comma(n)
    local s = tostring(floor((n or 0) + 0.5))
    local out, k = s, 0
    repeat
        out, k = out:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until k == 0
    return out
end

function ns.Short(n)
    n = n or 0
    if n >= 1000000 then return string.format("%.1fm", n / 1000000) end
    if n >= 10000 then return string.format("%.1fk", n / 1000) end
    return ns.Comma(n)
end

function ns.Duration(sec)
    if not sec or sec <= 0 or sec ~= sec or sec == math.huge then return "--" end
    local m = floor(sec / 60 + 0.5)
    if m >= 60 then return string.format("%dh %02dm", floor(m / 60), m % 60) end
    return string.format("%dm", max(1, m))
end

function ns.Print(msg)
    print("|cff9eff1fBanzaiSland|r: " .. tostring(msg))
end

-- ---------------------------------------------------------------- player data

local function MaxLevel()
    if GetMaxPlayerLevel then
        local ok, v = pcall(GetMaxPlayerLevel)
        if ok and type(v) == "number" and v > 0 then return v end
    end
    if GetMaxLevelForPlayerExpansion then
        local ok, v = pcall(GetMaxLevelForPlayerExpansion)
        if ok and type(v) == "number" and v > 0 then return v end
    end
    return MAX_PLAYER_LEVEL or 60
end

function ns.IsMax()
    if IsXPUserDisabled and IsXPUserDisabled() then return true end
    local xpMax = UnitXPMax("player") or 0
    return (UnitLevel("player") or 1) >= MaxLevel() or xpMax <= 0
end

-- name, standing, floor of standing, ceiling of standing, current value
function ns.GetWatched()
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local ok, d = pcall(C_Reputation.GetWatchedFactionData)
        if ok and type(d) == "table" and d.name and d.name ~= "" then
            return d.name, d.reaction, d.currentReactionThreshold or 0, d.nextReactionThreshold or 0, d.currentStanding or 0
        end
    end
    if GetWatchedFactionInfo then
        local name, standing, lo, hi, value = GetWatchedFactionInfo()
        if name and name ~= "" then return name, standing, lo or 0, hi or 0, value or 0 end
    end
end

-- XP waiting in quests that are ready to turn in (shown on the bar when the option is on).
-- WoW Forever answers through C_QuestLog (ids, completion) plus GetQuestLogRewardXP(questID); older
-- clients use the quest log selection instead. Every game call is guarded: where the client cannot
-- say, this is 0 and the option is hidden.
local questXP, questXPDirty, questXPReading = 0, true, false
local questXPIgnore, questXPRetries, questXPMissing = 0, 0, false

local function ModernQuestLog()
    local Q = C_QuestLog
    return Q and Q.GetNumQuestLogEntries and Q.GetQuestIDForLogIndex and Q.IsComplete and GetQuestLogRewardXP and true or false
end

local function ReadModernQuestXP()
    local Q = C_QuestLog
    local total = 0
    local collapsed, expanded = {}, false
    local i = 1
    while i <= (Q.GetNumQuestLogEntries() or 0) do
        local id = Q.GetQuestIDForLogIndex(i)
        if not id or id == 0 then
            -- a header with nothing under it is a collapsed zone: open it for now, close it again after
            local n = Q.GetNumQuestLogEntries()
            local nextId = i < n and Q.GetQuestIDForLogIndex(i + 1)
            if ExpandQuestHeader and Q.GetTitleForLogIndex and (i == n or not nextId or nextId == 0) then
                local title = Q.GetTitleForLogIndex(i)
                if title then
                    collapsed[title] = true
                    expanded = true
                    questXPIgnore = GetTime() + 1
                    ExpandQuestHeader(i)
                end
            end
        elseif Q.IsComplete(id) then
            local info = Q.GetInfo and Q.GetInfo(i)
            if not (info and info.isHidden) then
                local xp = GetQuestLogRewardXP(id)
                if type(xp) == "number" then total = total + xp else questXPMissing = true end
            end
        end
        i = i + 1
    end
    if expanded and CollapseQuestHeader and Q.GetTitleForLogIndex then
        questXPIgnore = GetTime() + 1
        i = 1
        while i <= (Q.GetNumQuestLogEntries() or 0) do
            local id = Q.GetQuestIDForLogIndex(i)
            if (not id or id == 0) then
                local title = Q.GetTitleForLogIndex(i)
                if title and collapsed[title] then CollapseQuestHeader(i) end
            end
            i = i + 1
        end
    end
    return total
end

local function QuestRewardXP(i, questID)
    if GetQuestLogRewardXP and questID and questID ~= 0 then
        local ok, v = pcall(GetQuestLogRewardXP, questID)
        if ok and tonumber(v) then return v end
    end
    if SelectQuestLogEntry and GetRewardXP and GetQuestLogSelection then
        local keep = GetQuestLogSelection()
        pcall(SelectQuestLogEntry, i)
        local ok, v = pcall(GetRewardXP)
        if keep then pcall(SelectQuestLogEntry, keep) end
        if ok and tonumber(v) then return v end
    end
    return 0
end

local function ReadLegacyQuestXP()
    local total = 0
    if not GetNumQuestLogEntries then return 0 end
    local okN, n = pcall(GetNumQuestLogEntries)
    if not okN then return 0 end
    for i = 1, tonumber(n) or 0 do
        local ok, _, _, _, header, _, done, _, questID
        if GetQuestLogTitle then
            ok, _, _, _, header, _, done, _, questID = pcall(GetQuestLogTitle, i)
        end
        if ok and not header and (done == 1 or done == true) then
            total = total + (tonumber(QuestRewardXP(i, questID)) or 0)
        end
    end
    return total
end

local function ReadQuestXP()
    if ModernQuestLog() then return ReadModernQuestXP() end
    return ReadLegacyQuestXP()
end

function ns.QuestXPAvailable()
    if ModernQuestLog() then return true end
    return ((GetQuestLogRewardXP or (GetRewardXP and SelectQuestLogEntry)) and GetNumQuestLogEntries and GetQuestLogTitle) and true or false
end

function ns.QuestXPDirty() questXPDirty = true end

function ns.CompletedQuestXP()
    if not ns.db.questXPBar or not ns.QuestXPAvailable() then return 0 end
    if questXPDirty and not questXPReading then
        questXPReading, questXPMissing = true, false
        local ok, v = pcall(ReadQuestXP)
        questXPReading = false
        questXP = ok and v or 0
        questXPDirty = false
        -- the game sometimes has not loaded a quest's reward yet: look again shortly
        if questXPMissing and questXPRetries < 4 and C_Timer and C_Timer.After then
            questXPRetries = questXPRetries + 1
            C_Timer.After(1.5, function()
                questXPDirty = true
                if ns.Island and ns.Island.built then ns.Island:Refresh() end
            end)
        elseif not questXPMissing then
            questXPRetries = 0
        end
    end
    return questXP
end

function ns.GetState()
    local s = { level = UnitLevel("player") or 1 }
    if not ns.IsMax() then
        s.mode = "xp"
        s.cur = UnitXP("player") or 0
        s.max = max(1, UnitXPMax("player") or 1)
        s.rested = GetXPExhaustion() or 0
        s.p = min(1, s.cur / s.max)
        s.r = s.rested > 0 and min(1, (s.cur + s.rested) / s.max) or 0
        local qx = ns.CompletedQuestXP()
        s.questXP = qx
        s.q = qx > 0 and min(1, (s.cur + s.rested + qx) / s.max) or 0
        s.pctText = floor(s.p * 100) .. "%"
        return s
    end
    if ns.db.repAtMax and type(ns.Retail)=="table" then
        local special = ns.Retail.GetWatchedState(s)
        if special then return special end
    end
    local name, standing, lo, hi, value = ns.GetWatched()
    if ns.db.repAtMax and name then
        s.mode = "rep"
        s.name, s.standing = name, standing
        local span = hi - lo
        if span <= 0 then
            s.cur, s.max, s.p = 1, 1, 1
        else
            s.cur, s.max = value - lo, span
            s.p = max(0, min(1, s.cur / s.max))
        end
        s.r = 0
        s.value = value
        s.pctText = floor(s.p * 100) .. "%"
        s.standingText = (standing and _G["FACTION_STANDING_LABEL" .. standing]) or ""
        local c = FACTION_BAR_COLORS and standing and FACTION_BAR_COLORS[standing]
        if c then s.color = { c.r, c.g, c.b } end
        return s
    end
    s.mode = "max"
    s.cur, s.max, s.p, s.r = 1, 1, 1, 0
    s.pctText = L["Max"]
    return s
end

-- ---------------------------------------------------------------- Blizzard bar

local BLIZZARD_BARS = {
    "MainMenuExpBar", "MainMenuBarMaxLevelBar", "ReputationWatchBar",
    "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "StatusTrackingBarManager",
}
local hooked = {}

function ns.ApplyBlizzardBar()
    if not ns.db.hideBlizzard then return end
    for _, name in ipairs(BLIZZARD_BARS) do
        local f = _G[name]
        if f and type(f) == "table" and f.SetAlpha then
            -- made see-through, not hidden: hiding the game's status bars from an addon taints the action
            -- bars' layout, and the game then blocks them ("tried to call the protected function")
            if not hooked[name] and f.Show then
                hooked[name] = true
                hooksecurefunc(f, "Show", function(self)
                    if ns.db.hideBlizzard then self:SetAlpha(0) end
                end)
            end
            f:SetAlpha(0)
        end
    end
end

-- ---------------------------------------------------------------- xp events

local last = {}          -- last seen xp / max / rested
local pending            -- a gain waiting to see whether a quest or discovery claims it
local special            -- a quest or discovery waiting for its xp update
local lastQuestTitle
local lastRep = {}

-- Match nearby XP updates and kill messages as a batch: several enemies can share one
-- XP update, and either event can arrive first. Ambiguous quest/discovery batches are skipped.
local killAverage, killSamples = nil, 0
local killBatch
local killBlockedUntil = 0
local KILL_WINDOW = 1

local function ResetKills()
    killAverage, killSamples, killBatch = nil, 0, nil
    -- The kill that caused a level-up may still have events in flight.
    killBlockedUntil = GetTime() + KILL_WINDOW
end

local function RecordKillPart(base, count)
    local now = GetTime()
    if now < killBlockedUntil then return end
    local batch = killBatch
    if not batch then
        batch = { xp = 0, kills = 0, t = now }
        killBatch = batch
        local function finish()
            if killBatch ~= batch then return end
            local remaining = KILL_WINDOW - (GetTime() - batch.t)
            if remaining > 0.001 then
                C_Timer.After(remaining + 0.001, finish)
                return
            end
            killBatch = nil
            if batch.xp <= 0 or batch.kills <= 0 then return end
            local average = batch.xp / batch.kills
            -- Each additional kill carries 25% weight; batches use their per-kill mean.
            local weight = 1 - 0.75 ^ batch.kills
            killAverage = killAverage and (killAverage * (1 - weight) + average * weight) or average
            killSamples = killSamples + batch.kills
            ns.Island:Refresh()
        end
        C_Timer.After(KILL_WINDOW, finish)
    end
    batch.xp = batch.xp + (base or 0)
    batch.kills = batch.kills + (count or 0)
    batch.t = now
end

function ns.KillsLeft(left, rested)
    if killSamples < 3 or not killAverage or not left or left <= 0 then return nil end
    -- Exhaustion covers the total doubled XP span; half of it is bonus XP.
    rested = math.max(0, rested or 0)
    return math.ceil(math.max(left / 2, left - rested / 2) / killAverage)
end

local function Snapshot()
    last.xp = UnitXP("player") or 0
    last.max = UnitXPMax("player") or 0
    last.rested = GetXPExhaustion() or 0
end

local function ToastEnabled(kind)
    if kind == "quest" then return ns.db.showQuests end
    return ns.db.showDiscoveries
end

local function PushToast(kind, title, amount, p)
    if ToastEnabled(kind) then
        ns.Island:Push({ kind = "toast", toast = kind, title = title, amount = amount, p = p })
    else
        ns.Island:Refresh()
    end
end

local function FlushPending()
    local g = pending
    if not g or GetTime() - g.t < 0.2 then return end
    pending = nil
    if ns.db.showKills then
        ns.Island:Push({ kind = "gain", amount = g.amount, rested = g.rested, p = g.p, unit = "XP" })
    else
        ns.Island:Refresh()
    end
end

local function OnXP()
    local xp, xpMax = UnitXP("player") or 0, UnitXPMax("player") or 0
    local rested = GetXPExhaustion() or 0
    if not last.xp then Snapshot() return end
    if ns.IsMax() and xpMax <= 0 then Snapshot() ns.Island:Refresh() return end

    local delta, wrapped
    if xpMax ~= last.max or xp < last.xp then
        delta, wrapped = (last.max - last.xp) + xp, true
    else
        delta = xp - last.xp
    end
    local usedRested = rested < (last.rested or 0)
    local bonus = usedRested and (((last.rested or 0) - rested) / 2) or 0
    Snapshot()
    if delta <= 0 then ns.Island:Refresh() return end

    ns.session.xp = ns.session.xp + delta
    ns.session.lastGain = delta
    if ns.Instance then ns.Instance.AddXP(delta) end
    local p = wrapped and 1 or (xpMax > 0 and xp / xpMax or 1)

    if wrapped then ResetKills() end
    if not (special and GetTime() - special.t < 1.5) then
        RecordKillPart(math.max(0, delta - bonus), 0)
    end

    if special and GetTime() - special.t < 1.5 then
        local sp = special
        special = nil
        PushToast(sp.kind, sp.title, sp.amount or delta, p)
        return
    end
    special = nil

    if pending then
        pending.amount = pending.amount + delta
        pending.rested = pending.rested or usedRested
        pending.p = (pending.p == 1 or wrapped) and 1 or p
        pending.t = GetTime()
    else
        pending = { amount = delta, rested = usedRested, p = p, t = GetTime() }
    end
    C_Timer.After(0.25, FlushPending)
end

local function OnSpecial(kind, title, amount)
    -- Discard the entire overlapping batch rather than turn mixed XP into a kill sample.
    killBatch = nil
    killBlockedUntil = GetTime() + 1.5
    if pending and GetTime() - pending.t < 1 then
        local g = pending
        pending = nil
        PushToast(kind, title, (amount and amount > 0) and amount or g.amount, g.p)
    else
        special = { kind = kind, title = title, amount = (amount and amount > 0) and amount or nil, t = GetTime() }
    end
end

local function QuestTitle(id)
    if id and C_QuestLog then
        if C_QuestLog.GetTitleForQuestID then
            local ok, t = pcall(C_QuestLog.GetTitleForQuestID, id)
            if ok and type(t) == "string" and t ~= "" then return t end
        end
        if C_QuestLog.GetQuestInfo then
            local ok, t = pcall(C_QuestLog.GetQuestInfo, id)
            if ok and type(t) == "string" and t ~= "" then return t end
        end
    end
    return lastQuestTitle or L["Quest"]
end

-- "Discovered %s: %d experience gained" turned into a Lua pattern.
local discoverPattern
local function BuildDiscoverPattern()
    local fmt = ERR_ZONE_EXPLORED_XP
    if type(fmt) ~= "string" then return end
    local p = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%%d%%%$s", "(.+)"):gsub("%%%d%%%$d", "(%%d+)")
    p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    discoverPattern = "^" .. p
end

local function OnSystemMessage(msg)
    if not ns.Readable(msg) then return end      -- the game hides some chat text from addons in combat
    if not discoverPattern or type(msg) ~= "string" then return end
    local a, b = msg:match(discoverPattern)
    if not a then return end
    local name, amount = a, tonumber(b)
    if not amount and tonumber(a) then name, amount = b, tonumber(a) end
    OnSpecial("disc", name or L["New area"], amount)
end

local function OnFaction()
    if not ns.IsMax() then return end
    local name, _, _, _, value = ns.GetWatched()
    if not name then ns.Island:Refresh() return end
    local prev = lastRep[name]
    lastRep[name] = value
    if prev and value > prev and ns.db.repAtMax then
        local delta = value - prev
        ns.session.rep = ns.session.rep + delta
        local s = ns.GetState()
        if ns.db.showKills and not ns.db.toastRep then      -- reputation toasts already cover this
            ns.Island:Push({ kind = "gain", amount = delta, p = s.p, unit = "rep" })
            return
        end
    end
    ns.Island:Refresh()
end

-- ---------------------------------------------------------------- boot

-- Settings profiles. "Default" is BanzaiSlandDB itself (so an older Island still finds its settings);
-- every other profile is a table in BanzaiSlandDB.profiles. Which profile a character uses is kept on the
-- account (BanzaiSlandDB.profileUsers), so renaming or deleting a profile never needs another
-- character's saved variables. ns.db is the active profile's table, so modules keep reading ns.db.
local P = {}
ns.Profiles = P
P.DEFAULT = "Default"
-- learned or account-wide data: stays in the account table whichever profile is active
local SHARED = { flights = true, flightSpeed = true, barNow = true, developer = true, packages = true, runs = true, retailProgress = true }
P.SHARED = SHARED
-- profile keys that have no entry in ns.defaults
local EXTRA = { cardBuilder = true, position = true, x = true, y = true, cx = true, cy = true, extensions = true,
    extensionPick = true, zoneStyleV2 = true }
local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end
P.Copy = copy
local function isProfileKey(k)
    return not SHARED[k] and (ns.defaults[k] ~= nil or EXTRA[k] == true)
end
P.IsProfileKey = isProfileKey
-- a profile table (not the default) reads and writes the shared keys through the account table
local sharedMeta = {
    __index = function(_, k) if SHARED[k] then return P.account[k] end end,
    __newindex = function(t, k, v) if SHARED[k] then P.account[k] = v else rawset(t, k, v) end end,
}
local function fill(t, skipShared)
    -- Rewards used to share the upgrade switch; retain that choice for existing settings.
    if t.toastRewards == nil then t.toastRewards = t.toastUpgrades ~= false end
    for k, v in pairs(ns.defaults) do
        if t[k] == nil and not (skipShared and SHARED[k]) then t[k] = copy(v) end
    end
    return t
end
P.Fill = fill
local function characterKey()
    local name = UnitName and UnitName("player") or "?"
    local realm = GetRealmName and GetRealmName() or "?"
    return tostring(name) .. "-" .. tostring(realm), tostring(name)
end
function P.CharacterKey() return (characterKey()) end
local function store()
    local a = P.account
    if type(a.profiles) ~= "table" then a.profiles = {} end
    if type(a.profileUsers) ~= "table" then a.profileUsers = {} end
    return a.profiles, a.profileUsers
end
function P.Get(name)
    if name == nil or name == P.DEFAULT then return P.account end
    local profiles = store()
    return profiles[name]
end
function P.Active() return P.active or P.DEFAULT end
function P.List()
    local profiles = store()
    local names = {}
    for name in pairs(profiles) do names[#names + 1] = name end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    table.insert(names, 1, P.DEFAULT)
    return names
end
-- characters (name-realm) that use a profile; the current one is always counted
function P.Users(name)
    local _, users = store()
    local list = {}
    for key, n in pairs(users) do if n == name then list[#list + 1] = key end end
    table.sort(list)
    return list
end
function P.Valid(name)
    if type(name) ~= "string" then return nil, "invalid" end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or #name > 24 then return nil, "invalid" end
    if name:find("[%c|]") then return nil, "invalid" end
    local profiles = store()
    local lower = name:lower()
    if lower == P.DEFAULT:lower() then return nil, "exists" end
    for existing in pairs(profiles) do if existing:lower() == lower then return nil, "exists" end end
    return name
end
local function unique(base)
    local name, n = base, 1
    while not P.Valid(name) do
        n = n + 1
        name = base .. " " .. n
    end
    return name
end
P.Unique = unique
-- copy the profile keys of one table into a new one
local function profileCopy(from)
    local t = {}
    for k, v in pairs(from) do
        if isProfileKey(k) then t[k] = copy(v) end
    end
    return fill(t, true)
end
function P.Create(name, source)
    local valid, why = P.Valid(name)
    if not valid then return nil, why end
    local from = P.Get(source or P.Active()) or P.account
    local profiles = store()
    profiles[valid] = profileCopy(from)
    return valid
end
function P.CreateDefaults(name)
    local valid, why = P.Valid(name)
    if not valid then return nil, why end
    local profiles = store()
    profiles[valid] = fill({}, true)
    return valid
end
function P.Rename(old, name)
    if old == P.DEFAULT or not P.Get(old) then return nil, "invalid" end
    local valid, why = P.Valid(name)
    if not valid then return nil, why end
    local profiles, users = store()
    profiles[valid], profiles[old] = profiles[old], nil
    for key, n in pairs(users) do if n == old then users[key] = valid end end
    if P.active == old then P.active = valid end
    return valid
end
function P.Delete(name)
    if name == P.DEFAULT or not P.Get(name) then return nil, "invalid" end
    if name == P.Active() then return nil, "active" end
    local profiles, users = store()
    profiles[name] = nil
    for key, n in pairs(users) do if n == name then users[key] = nil end end
    return true
end
-- the profile in use takes on another one's settings, or goes back to defaults
function P.CopyInto(source)
    local from = P.Get(source)
    if not from or from == ns.db then return nil, "invalid" end
    for k in pairs(ns.db) do if isProfileKey(k) then ns.db[k] = nil end end
    for k, v in pairs(from) do if isProfileKey(k) then ns.db[k] = copy(v) end end
    fill(ns.db, ns.db ~= P.account)
    if ns.Theme and ns.Theme.NormalizeDisplayFont then ns.Theme.NormalizeDisplayFont(ns.db) end
    return true
end
function P.Reset()
    for k in pairs(ns.db) do if isProfileKey(k) then ns.db[k] = nil end end
    fill(ns.db, ns.db ~= P.account)
    if ns.Theme and ns.Theme.NormalizeDisplayFont then ns.Theme.NormalizeDisplayFont(ns.db) end
    return true
end
-- change this character's profile; the interface reloads to pick it up
function P.Use(name)
    if not P.Get(name) then return nil, "invalid" end
    local _, users = store()
    users[(characterKey())] = name
    if P.charDB then P.charDB.profile = name end
    P.Reload()
    return true
end
-- the profile this character will use after the next reload (it differs from Active until then)
function P.Chosen()
    local _, users = store()
    return users[(characterKey())] or P.Active()
end
-- reload to apply a change; if the game does not reload, say how to do it by hand
function P.Reload()
    if C_UI and C_UI.Reload then pcall(C_UI.Reload) elseif ReloadUI then pcall(ReloadUI) end
    if C_Timer and C_Timer.After then
        C_Timer.After(1.5, function() ns.Print(ns.L["Profile changed. Type /reload to apply it."]) end)
    end
end
-- a profile of its own for this character, copied from the one in use
function P.Separate()
    local _, short = characterKey()
    local name = P.Create(unique(short))
    if name then P.Use(name) end
    return name
end
-- "Character Profile": a profile named after this character. On makes it (copied from the one in
-- use) or picks it again; off goes back to Default and keeps it for later.
function P.OwnName() local _, short = characterKey() return short end
function P.IsOwn() return P.Chosen() == P.OwnName() end
function P.SetOwn(on)
    local short = P.OwnName()
    if on then
        if P.Get(short) then return P.Use(short) end
        return P.Separate()
    end
    if P.IsOwn() then return P.Use(P.DEFAULT) end
end
-- run once at ADDON_LOADED, after the saved variables exist
function P.Boot()
    local a, c = P.account, P.charDB
    fill(a)
    ns.account, ns.char = a, c
    local profiles, users = store()
    if ns.Theme and ns.Theme.NormalizeDisplayFont then
        ns.Theme.NormalizeDisplayFont(a)
        for _, profile in pairs(profiles) do ns.Theme.NormalizeDisplayFont(profile) end
    end
    local key, short = characterKey()
    local name = users[key]
    if name == nil then
        -- first time here: the old "settings for this character only" copy becomes a profile of its own
        -- (the old flag and table stay as they were, so an older Island still finds them)
        if c.own and type(c.settings) == "table" then
            local t = profileCopy(c.settings)
            name = unique(short)
            profiles[name] = t
        else
            name = P.DEFAULT
        end
        users[key] = name
    end
    local t = P.Get(name)
    if not t then name, t = P.DEFAULT, a end
    users[key] = name
    c.profile = name
    P.active = name
    if t ~= a then
        fill(t, true)
        setmetatable(t, sharedMeta)
    end
    ns.db = t
    if ns.Theme and ns.Theme.NormalizeDisplayFont then ns.Theme.NormalizeDisplayFont(ns.db) end
end
-- other addons read Island's settings through this (the profile in use), not the saved variables
function ns.GetSettings() return ns.db end
BanzaiSlandSettings = ns.GetSettings

local ev = CreateFrame("Frame")
local handlers = {}

function handlers.ADDON_LOADED(name)
    if name ~= ADDON then return end
    BanzaiSlandDB = BanzaiSlandDB or {}
    BanzaiSlandCharDB = BanzaiSlandCharDB or {}
    local P = ns.Profiles
    P.account = BanzaiSlandDB
    P.charDB = BanzaiSlandCharDB
    P.Boot()
    -- the "open whispers in the chat addon" setting had the addon's old name
    if ns.db.useParley ~= nil then
        if ns.db.useParley == false then ns.db.usePigeon = false end
        ns.db.useParley = nil
    end
    -- zone cards went back to the icon-and-text layout by default (2.4.2): a setup still on the
    -- old centred default moves with it, once
    if not ns.db.zoneStyleV2 then
        if ns.db.zoneStyle == "centered" then ns.db.zoneStyle = "classic" end
        ns.db.zoneStyleV2 = true
    end
    -- the zone card style was a plain on/off before
    if ns.db.zoneCentered ~= nil then
        if ns.db.zoneCentered == false then ns.db.zoneStyle = "classic" end
        ns.db.zoneCentered = nil
    end
    -- older setups picked a custom accent with a separate switch
    if ns.db.accentCustom ~= nil then
        if ns.db.accentCustom then ns.db.accentMode = "custom" end
        ns.db.accentCustom = nil
    end
    -- older setups have no position preset: a dragged island stays where it was put
    if ns.db.position == nil then
        local moved = (ns.db.x and ns.db.x ~= 0) or (ns.db.y and ns.db.y ~= -14)
        ns.db.position = moved and "free" or "top"
    end
end

-- kept for older callers: per-character settings are now a profile of the character's own
function ns.SetOwnSettings(on)
    if on then P.Separate() else P.Use(P.DEFAULT) end
end

function handlers.PLAYER_LOGIN()
    ns.session.start = GetTime()
    ns.session.moneyStart = GetMoney and GetMoney() or 0
    BuildDiscoverPattern()
    Snapshot()
    local name, _, _, _, value = ns.GetWatched()
    if name then lastRep[name] = value end
    ns.Island:Build()
    ns.Island:Refresh()
    ns.ApplyBlizzardBar()
    ns.ApplyLootRolls()
end

function handlers.PLAYER_ENTERING_WORLD()
    if not ns.Island.built then return end
    killBatch = nil
    killBlockedUntil = GetTime() + KILL_WINDOW
    Snapshot()
    ns.Island:Refresh()
    ns.ApplyBlizzardBar()
end

handlers.PLAYER_XP_UPDATE = function(unit)
    if unit and unit ~= "player" then return end
    OnXP()
end

function handlers.PLAYER_LEVEL_UP(level, hp, mp, talents)
    ResetKills()
    if not ns.db.showLevelUp then
        C_Timer.After(0.7, function() ns.Island:Refresh() end)
        return
    end
    local chips = {}
    if type(hp) == "number" and hp > 0 then chips[#chips + 1] = L["+%s health"]:format(ns.Comma(hp)) end
    if type(mp) == "number" and mp > 0 then chips[#chips + 1] = L["+%s mana"]:format(ns.Comma(mp)) end
    if type(talents) == "number" and talents > 0 then
        chips[#chips + 1] = (talents == 1 and L["+%d talent point"] or L["+%d talent points"]):format(talents)
    end
    -- Wait a moment so the xp gain that caused the level lands in the queue first.
    C_Timer.After(0.7, function()
        ns.Island:Push({ kind = "levelup", level = level or UnitLevel("player"), chips = chips })
    end)
end

function handlers.QUEST_COMPLETE()
    if GetTitleText then
        local t = GetTitleText()
        if type(t) == "string" and t ~= "" then lastQuestTitle = t end
    end
end

-- the quest log changed: re-read the waiting quest XP, and redraw the bar only if it moved
function handlers.QUEST_LOG_UPDATE()
    if questXPReading or not ns.db.questXPBar or GetTime() < questXPIgnore then return end
    local before = questXP
    questXPDirty = true
    if ns.CompletedQuestXP() ~= before and ns.Island.built then ns.Island:Refresh() end
end
handlers.UNIT_QUEST_LOG_CHANGED = function(unit)
    if unit == "player" then handlers.QUEST_LOG_UPDATE() end
end

function handlers.QUEST_TURNED_IN(questID, xpReward)
    questXPDirty = true
    if ns.IsMax() then return end
    OnSpecial("quest", QuestTitle(questID), tonumber(xpReward))
end

-- one xp line in the combat log per kill
function handlers.CHAT_MSG_COMBAT_XP_GAIN()
    ns.session.kills = ns.session.kills + 1
    RecordKillPart(0, 1)
    if ns.Instance then ns.Instance.AddKill() end
end

-- /island watch: prints the game events and pop-up windows that look like the world refresh warning,
-- to learn how the game announces it (a debugging aid; /island watch again stops it)
local watcher
function ns.WatchWorld()
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", function(_, event, ...)
            local e = event:upper()
            if e:find("REFRESH") or e:find("PHASE") or e:find("LAYER") or e:find("SHARD") or e:find("SHUTDOWN")
                or e:find("RESTART") or e:find("TRANSFER") or e:find("REALM") or e:find("WORLD_MAP") == nil and e:find("WORLD") then
                local args = {}
                for i = 1, select("#", ...) do args[#args + 1] = tostring((select(i, ...))) end
                ns.Print("event " .. event .. "  " .. table.concat(args, ", "))
            end
        end)
        if hooksecurefunc and StaticPopup_Show then
            hooksecurefunc("StaticPopup_Show", function(which, a1, a2)
                if watcher.on then ns.Print("popup " .. tostring(which) .. "  " .. tostring(a1) .. ", " .. tostring(a2)) end
            end)
        end
    end
    watcher.on = not watcher.on
    if watcher.on then
        watcher:RegisterAllEvents()
        ns.Print("watching for the world refresh warning. Leave this on until it shows, then send what it printed. /banzaisland watch stops it.")
    else
        watcher:UnregisterAllEvents()
        ns.Print("stopped watching.")
    end
end

-- cards that arrived during the fight replay once it is over
function handlers.PLAYER_REGEN_ENABLED()
    if ns.Island.built then
        C_Timer.After(0.6, function() ns.Island:ReleaseHeld() end)
    end
end

handlers.CHAT_MSG_SYSTEM = OnSystemMessage
handlers.UPDATE_FACTION = OnFaction

local function RefreshSoon()
    if ns.Island.built then
        Snapshot()
        ns.Island:Refresh()
    end
end
handlers.UPDATE_EXHAUSTION = function()
    -- rested XP built up (resting, logging in): remember it, so the next kill's bonus is known.
    -- Only upward: a kill uses some up, and that is worked out with its xp update.
    local r = GetXPExhaustion() or 0
    if last.xp and r > (last.rested or 0) then last.rested = r end
    -- Do not snapshot XP here: this event can precede PLAYER_XP_UPDATE for the same kill.
    if ns.Island.built then ns.Island:Refresh() end
end
handlers.PLAYER_UPDATE_RESTING = handlers.UPDATE_EXHAUSTION
handlers.DISABLE_XP_GAIN = RefreshSoon
handlers.ENABLE_XP_GAIN = RefreshSoon

ev:SetScript("OnEvent", function(_, event, ...)
    local h = handlers[event]
    if h then h(...) end
end)
for event in pairs(handlers) do
    pcall(ev.RegisterEvent, ev, event)
end

-- ---------------------------------------------------------------- slash

SLASH_BANZAISLAND1 = "/banzaisland"
SLASH_BANZAISLAND2 = "/bsl"
SLASH_BANZAISLAND3 = "/banzaisland"
SlashCmdList.BANZAISLAND = function(msg)
    local raw = (msg or ""):match("^%s*(.-)%s*$")
    msg = raw:lower()
    if msg == "status" or msg == "version" or msg == "ver" then
        -- BanzaiSland: version, client, theme and the duplicate guard in one line
        ns.Print(ns.Preview and ns.Preview.Status() or ("BanzaiSland " .. tostring(ns.VERSION)))
    elseif msg == "preview" or msg == "previews" then
        ns.ToggleSettings(40)
    elseif msg:match("^preview%s+%S") then
        local id = raw:match("^%S+%s+(%S+)")
        if ns.Preview then ns.Preview.Run(id:lower()) end
    elseif msg == "tour" then
        if ns.Preview then ns.Preview.Tour() end
    elseif msg == "stop" or msg == "clear" then
        if ns.Preview then ns.Preview.Stop() end
    elseif msg == "test" or msg == "demo" then
        ns.Island:Demo()
    elseif msg == "roll" then
        ns.Island:DemoRoll()
    elseif msg == "toasts" or msg == "toast" then
        ns.DemoToasts()
    elseif msg == "alerts" or msg == "alert" then
        ns.DemoAlerts()
    elseif msg == "zone" then
        ns.DemoZone()
    elseif msg == "extensions" then
        if ns.Extensions then ns.Extensions.Report() end
    elseif msg == "popups" then
        if ns.DebugPopups then ns.DebugPopups() end
    elseif msg == "rxp" then
        if ns.RXP then ns.RXP:Debug() end
    elseif msg == "polestar" then
        if ns.PS then ns.PS:Debug() end
    elseif msg == "shelf" then
        if ns.Shelf then ns.Shelf.Toggle() end
    elseif msg == "packages" or msg == "package" then
        if ns.Packages and ns.Packages.Open then ns.Packages.Open() end
    elseif msg == "ready" or msg == "prompt" then
        ns.DemoPrompts()
    elseif msg == "live" or msg == "flight" then
        ns.DemoLive()
    elseif msg == "runs" or msg == "instance" or msg == "run" then
        ns.Instance.Report()
    elseif msg == "runs debug" or msg == "instance debug" then
        if ns.Instance and ns.Instance.Debug then ns.Instance.Debug() end
    elseif msg == "runs reset" or msg == "instance reset" then
        ns.Instance.Reset()
    elseif msg == "runs test" or msg == "instance test" then
        ns.DemoInstance()
    elseif msg == "way clear" or msg == "nav clear" then
        ns.Nav:Clear()
    elseif msg == "nav" or msg == "nav test" or msg == "way test" then
        ns.DemoNav()
    elseif msg:match("^way ") then
        -- /island way 45.2 33.1 Name
        local x, y, title = raw:match("^%a+%s+([%d%.]+)[,%s]+([%d%.]+)%s*(.*)$")
        local here = ns.Nav.Here()
        if x and here then
            ns.Nav:Set(here.map, tonumber(x), tonumber(y), title ~= "" and title or (L["Pin at %s, %s"]:format(x, y)))
        else
            ns.Print(L["use /banzaisland way 45.2 33.1 to point the way to a spot on this map."])
        end
    elseif msg == "voice" or msg == "spoken" then
        ns.DemoVoice()
    elseif msg == "dnd" or msg == "quiet" then
        ns.SetDND(not ns.db.dnd)
        ns.Print(ns.db.dnd and L["Do Not Disturb on. Cards wait in the history."] or L["Do Not Disturb off."])
    elseif msg == "errors" or msg == "error" then
        local I = ns.Island
        I:ShowError(L["Not enough rage"])
        C_Timer.After(0.4, function() I:ShowError(L["Not enough rage"]) end)
        C_Timer.After(0.8, function() I:ShowError(L["Not enough rage"]) end)
        C_Timer.After(3, function() I:ShowError(L["Out of range."]) end)
        C_Timer.After(5.5, function() I:ShowError(L["You are facing the wrong way!"]) end)
    elseif msg == "group" or msg == "party" then
        ns.DemoGroup()
    elseif msg == "vendor" then
        ns.DemoVendor()
    elseif msg == "watch" then
        ns.WatchWorld()
    elseif msg == "seal" or msg == "buffs" then
        ns.DemoSeal()
    elseif msg == "seal debug" or msg == "seals" or msg == "buffs debug" then
        ns.Seals.Debug()
    elseif msg == "catchup" then
        if ns.CatchUp and not ns.CatchUp.Show() then ns.Print(L["No catch-up updates waiting."]) end
    elseif msg == "catchup test" then
        if ns.CatchUp then ns.CatchUp.Demo() end
    elseif msg == "catchup clear" then
        if ns.CatchUp then ns.CatchUp.Clear() end
    elseif msg == "more" then
        ns.DemoExtras()
    elseif msg == "unlock" or msg == "move" then
        ns.db.locked = false
        ns.Print(L["unlocked. Drag the island, then type /banzaisland lock."])
    elseif msg == "lock" then
        ns.db.locked = true
        ns.Print(L["locked."])
    elseif msg == "reset" then
        ns.db.x, ns.db.y, ns.db.scale = ns.defaults.x, ns.defaults.y, ns.defaults.scale
        ns.db.cx, ns.db.cy = nil, nil
        ns.db.position = "top"
        ns.Island:ApplyPosition()
        ns.Print(L["position and size reset."])
    elseif msg == "help" then
        ns.Print(L["/banzaisland opens settings (/bsl works too). BanzaiSland: /bsl status, /bsl preview, /bsl preview <scenario>, /bsl tour, /bsl stop. Also: /banzaisland test, /banzaisland roll, /banzaisland toasts, /banzaisland alerts, /banzaisland zone, /banzaisland ready, /banzaisland live, /banzaisland runs, /banzaisland runs reset, /banzaisland runs test, /banzaisland way, /banzaisland dnd, /banzaisland group, /banzaisland vendor, /banzaisland errors, /banzaisland buffs, /banzaisland more, /banzaisland catchup, /banzaisland catchup test, /banzaisland catchup clear, /banzaisland unlock, /banzaisland lock, /banzaisland reset."])
    else
        ns.ToggleSettings()
    end
end


-- Tooltips are placed by screen position rather than attached to the island. Attaching the game's
-- tooltip to the island joins the two together, and the game can then treat the island as locked
-- during combat, so it can no longer grow or shrink.
function ns.PlaceTip(tip, frame, where)
    tip = tip or GameTooltip
    if not tip then return end
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearAllPoints()
    local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not (l and r and t and b) then tip:SetPoint("TOP", UIParent, "TOP", 0, -120) return end
    local k = frame:GetEffectiveScale() / tip:GetEffectiveScale()
    if where == "RIGHT" then
        tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", r * k + 10, t * k)
    else
        tip:SetPoint("TOP", UIParent, "BOTTOMLEFT", (l + r) / 2 * k, b * k - 4)
    end
end
