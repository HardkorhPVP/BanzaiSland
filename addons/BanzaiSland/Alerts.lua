-- Island: alerts. Low durability, bags nearly full, new mail, friends coming online or going offline.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local floor, max, min = math.floor, math.max, math.min
local I, C = ns.Island, ns.C

local ORANGE = { 0.98, 0.66, 0.28 }
local RED = { 0.95, 0.38, 0.38 }
local GREEN = { 0.36, 0.85, 0.45 }
local BLUE = { 0.40, 0.72, 1.00 }
local MUTED_HEX = ns.Hex(C.muted[1], C.muted[2], C.muted[3])
local REMIND_EVERY = 300          -- seconds between reminders

local SOUND_ALERT, SOUND_FRIEND = 12867, 3332

local function Card(key, glyph, tone, cap, title, res, line, hold, extra)
    local item = {
        kind = "won", catchUpCategory = key == "mail" and "mail" or nil, key = key, glyph = glyph, tone = tone, cap = cap, capColor = tone, title = title,
        color = C.fg, res = res or "", resColor = tone, line = line and (MUTED_HEX .. line .. "|r") or nil,
        hold = hold or 3.2, priority = 2, sound = SOUND_ALERT,
    }
    if extra then
        for k, v in pairs(extra) do item[k] = v end
    end
    I:PushCard(item)
end

-- ---------------------------------------------------------------- durability

local dur = { low = false, broken = false, last = 0 }

-- lowest durability percent, the item it belongs to, and how many items are under the threshold
local function ScanDurability(threshold)
    local lowest, lowestSlot, count = nil, nil, 0
    for slot = 1, 18 do
        local cur, top = GetInventoryItemDurability(slot)
        if cur and top and top > 0 then
            local pct = cur / top * 100
            if pct < threshold then count = count + 1 end
            if not lowest or pct < lowest then lowest, lowestSlot = pct, slot end
        end
    end
    local name
    if lowestSlot and GetInventoryItemLink then
        local link = GetInventoryItemLink("player", lowestSlot)
        name = link and link:match("%[(.-)%]")
    end
    return lowest, name, count
end

local function CheckDurability(remind)
    local db = ns.db
    if not db.alertDurability or not GetInventoryItemDurability then return end
    local threshold = db.durabilityThreshold or 25
    local lowest, name, count = ScanDurability(threshold)
    if not lowest or lowest >= threshold then
        dur.low, dur.broken = false, false
        return
    end
    local broken = lowest <= 0
    local fresh = not dur.low or (broken and not dur.broken)
    dur.low, dur.broken = true, broken
    if not fresh and not remind then return end
    dur.last = GetTime()
    local tone = broken and RED or ORANGE
    local line = count > 1 and L["%d items under %s%%"]:format(count, threshold) or nil
    Card("durability", "Shield", tone, broken and L["BROKEN GEAR"] or L["LOW DURABILITY"], name or L["Your gear"],
         floor(lowest + 0.5) .. "%", line)
end

-- The small red armor beside the island, for as long as gear is under the threshold.
local function UpdateRepairDot()
    local db = ns.db
    if not db.repairDot or not GetInventoryItemDurability then I:SetWarning("repair", nil) return end
    local threshold = db.durabilityThreshold or 25
    local lowest, name, count = ScanDurability(threshold)
    if not lowest or lowest >= threshold then I:SetWarning("repair", nil) return end
    local broken = lowest <= 0
    local more = count > 1 and (", " .. L["%d items under %s%%"]:format(count, threshold)) or ""
    I:SetWarning("repair", {
        glyph = "Armor", tone = RED, priority = broken and 2 or 1,
        tip = broken and L["Broken gear"] or L["Repairs needed"],
        tip2 = L["%s at %d%%"]:format(name or L["Your gear"], floor(lowest + 0.5)) .. more,
    })
end
ns.UpdateRepairDot = UpdateRepairDot

-- ---------------------------------------------------------------- bags

local bags = { low = false, full = false, last = 0 }

local function ScanBags()
    local freeFn = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
    local sizeFn = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    if not freeFn or not sizeFn then return nil end
    local free, total = 0, 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local f, family = freeFn(bag)
        local size = sizeFn(bag) or 0
        if size > 0 and (family == nil or family == 0) then      -- ordinary bags only, not quivers or herb bags
            free, total = free + (f or 0), total + size
        end
    end
    return free, total
end

local function CheckBags(remind)
    local db = ns.db
    if not db.alertBags then return end
    local free, total = ScanBags()
    if not free or total == 0 then return end
    local threshold = db.bagThreshold or 3
    if free > threshold then
        bags.low, bags.full = false, false
        return
    end
    local full = free == 0
    local fresh = not bags.low or (full and not bags.full)
    bags.low, bags.full = true, full
    if not fresh and not remind then return end
    bags.last = GetTime()
    local title = full and L["No space left"] or (free == 1 and L["%d slot left"] or L["%d slots left"]):format(free)
    Card("bags", "Bag", full and RED or ORANGE, full and L["BAGS FULL"] or L["BAGS NEARLY FULL"], title,
         (total - free) .. " / " .. total)
end

-- ---------------------------------------------------------------- mail

local hadMail = false

local function CheckMail()
    local has = HasNewMail and HasNewMail() and true or false
    local was = hadMail
    hadMail = has
    if not has or was then return end
    if MailFrame and MailFrame.IsShown and MailFrame:IsShown() then return end
    local title = L["You have mail"]
    if GetLatestThreeSenders then
        local a, b, c = GetLatestThreeSenders()
        local names = {}
        for _, n in ipairs({ a, b, c }) do
            if type(n) == "string" and n ~= "" then names[#names + 1] = n end
        end
        if #names > 0 then title = L["From %s"]:format(table.concat(names, ", ")) end
    end
    if ns.CatchUp then ns.CatchUp.Record("mail", "new", L["New mail"], title, {glyph="Mail", once=true}) end
    if ns.db.alertMail then Card("mail", "Mail", BLUE, L["NEW MAIL"], title) end
end

-- ---------------------------------------------------------------- friends

local friendOnline, friendOffline

-- friend details, or nil when the name is not on the friends list
local function FriendInfo(name)
    if C_FriendList and C_FriendList.GetFriendInfo then
        local ok, info = pcall(C_FriendList.GetFriendInfo, name)
        if ok and type(info) == "table" then return info end
        if ok then return nil end
    end
    return {}
end

-- rank, level, class and zone of a guild member, or nil when the name is not in your guild
local function GuildInfo(name)
    if not (IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then return nil end
    for i = 1, GetNumGuildMembers() do
        local full, rank, _, level, class, zone = GetGuildRosterInfo(i)
        if full and (full == name or full:match("^[^%-]+") == name) then
            return { rank = rank, level = level, className = class, area = zone }
        end
    end
end

local function PersonCard(name, online, line, guild)
    local what = guild and L["GUILD MEMBER %s"] or L["FRIEND %s"]
    Card((guild and "guild:" or "friend:") .. name, "Person", online and GREEN or C.muted,
         what:format(online and L["ONLINE"] or L["OFFLINE"]), name, nil, line, 2.6, { sound = online and SOUND_FRIEND or false, priority = 1, group = "social", online = online and true or false })
end
local function FriendCard(name, online, line) PersonCard(name, online, line, false) end

local function OnFriendMessage(msg)
    if not ns.Readable(msg) then return end      -- the game hides some chat text from addons in combat
    if type(msg) ~= "string" then return end
    local name, online
    if friendOnline and msg:match(friendOnline) then
        name, online = msg:match("|Hplayer:([^|:]+)") or msg:match(friendOnline), true
    elseif friendOffline then
        name = msg:match(friendOffline)
        online = false
    end
    if not name or name == "" or name:find("|", 1, true) then return end
    local info, guild = FriendInfo(name), false
    if info and not ns.db.alertFriends then return end
    if not info then
        if not ns.db.alertGuild then return end
        info, guild = GuildInfo(name), true
        if not info then return end
    end
    local line
    if online and info.className and info.level and info.level > 0 then
        line = L["Level %d %s"]:format(info.level, info.className) .. ((info.area and info.area ~= "") and ("   " .. info.area) or "")
    end
    PersonCard(name, online, line, guild)
end

local function OnBattleNetFriend(accountID, online)
    if not ns.db.alertFriends or not (C_BattleNet and C_BattleNet.GetAccountInfoByID) then return end
    local ok, info = pcall(C_BattleNet.GetAccountInfoByID, accountID)
    if not ok or type(info) ~= "table" or not info.accountName then return end
    local line
    local game = info.gameAccountInfo
    if online and type(game) == "table" and game.characterName and game.characterName ~= "" then
        line = game.characterName .. ((game.areaName and game.areaName ~= "") and ("   " .. game.areaName) or "")
    end
    FriendCard(info.accountName, online, line)
end

-- ---------------------------------------------------------------- ammo and reagents

-- reagents worth warning about, with the count at which to warn
local REAGENTS = {
    [17020] = 5,  -- Arcane Powder
    [17031] = 2,  -- Rune of Teleportation
    [17032] = 2,  -- Rune of Portals
    [17029] = 5,  -- Sacred Candle
    [17028] = 5,  -- Holy Candle
    [21177] = 20, -- Symbol of Kings
    [17033] = 1,  -- Symbol of Divinity
    [17030] = 2,  -- Ankh
    [6265] = 2,   -- Soul Shard
    [5140] = 5,   -- Flash Powder
    [17026] = 5,  -- Wild Thornroot
    [17021] = 5,  -- Wild Berries
    [17034] = 2, [17035] = 2, [17036] = 2, [17037] = 2, [17038] = 2,   -- druid rebirth seeds
}
local AMMO_SLOT, RANGED_SLOT, AMMO_WARN = 0, 18, 200
local supply = {}        -- per item: was it above the warning level, and has the warning been shown

local function ItemName(id)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if getInfo then
        local ok, name = pcall(getInfo, id)
        if ok and type(name) == "string" then return name end
    end
end

-- dropOnly: warn only after the count has been seen above the warning level and then fell to it.
-- Used for ammo, because some clients put a permanent stand-in item in the ammo slot (always
-- "1 left") for characters whose ranged weapons no longer use ammo at all.
local function CheckSupply(id, count, warnAt, glyph, cap, dropOnly)
    local st = supply[id]
    if not st then
        st = { above = count > warnAt, everAbove = count > warnAt, warned = false, had = count > 0 }
        supply[id] = st
        if st.above or not st.had or dropOnly then return end       -- fine, or never carried: nothing to say
    end
    if count > 0 then st.had = true end
    if count > warnAt then
        st.above, st.everAbove, st.warned = true, true, false
        return
    end
    if st.warned or not st.had then return end
    if dropOnly and not st.everAbove then return end
    local name = ItemName(id)
    if not name then return end                         -- never alert on something without a name
    st.warned = true
    Card("supply:" .. id, glyph, count == 0 and RED or ORANGE, count == 0 and L["OUT OF %s"]:format(cap) or L["LOW %s"]:format(cap),
         name, L["%d left"]:format(count))
end

-- item class and subclass numbers, e.g. weapon / bow
local function ItemClass(id)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not instant or not id then return nil end
    local ok, _, _, _, _, _, class, sub = pcall(instant, id)
    if ok then return class, sub end
end

local WEAPON, PROJECTILE = 2, 6
local USES_AMMO = { [2] = true, [3] = true, [18] = true }      -- bows, guns, crossbows

-- Ammo only matters with a bow, gun or crossbow in the ranged slot (not a wand, thrown weapon,
-- libram, idol, totem or other relic), and only when the ammo slot really holds arrows or bullets.
local function AmmoInUse()
    if not (GetInventoryItemID and GetInventoryItemCount) then return nil end
    local ok, ranged = pcall(GetInventoryItemID, "player", RANGED_SLOT)
    if not ok or not ranged then return nil end
    local class, sub = ItemClass(ranged)
    if class ~= WEAPON or not USES_AMMO[sub] then return nil end
    local ok2, ammo = pcall(GetInventoryItemID, "player", AMMO_SLOT)
    if not ok2 or not ammo then return nil end
    if ItemClass(ammo) ~= PROJECTILE then return nil end
    if not ItemName(ammo) then return nil end       -- an item the game cannot even name is not real ammo
    -- count what is in the bags; the slot's own count reads 1 for an empty slot on some clients
    local count = GetItemCount and GetItemCount(ammo) or GetInventoryItemCount("player", AMMO_SLOT) or 0
    return ammo, count
end

-- the ammo bubble: arrows (a quiver), bullets (a pouch) or a thrown weapon (a shuriken) left,
-- orange when low and red when out
local THROWN = 16                         -- weapon subclass for thrown weapons
local function RangedSupply()
    local ammo, count = AmmoInUse()
    if ammo then
        local _, sub = ItemClass(ammo)
        return ammo, count, (sub == 3) and "Pouch" or "Quiver"
    end
    if not (GetInventoryItemID and GetInventoryItemCount) then return nil end
    local ok, ranged = pcall(GetInventoryItemID, "player", RANGED_SLOT)
    if not ok or not ranged then return nil end
    local class, sub = ItemClass(ranged)
    if class ~= WEAPON or sub ~= THROWN then return nil end
    -- Some thrown weapons never run out: they wear down (durability) instead of being used up, and
    -- come one to a slot. Only a stack that gets used up is worth counting.
    if GetInventoryItemDurability then
        local okD, cur, max = pcall(GetInventoryItemDurability, RANGED_SLOT)
        if okD and cur and max and max > 0 then return nil end
    end
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local okI, _, _, _, _, _, _, _, stack = pcall(getInfo, ranged)
    if not okI or not stack or stack <= 1 then return nil end
    local ok2, n = pcall(GetInventoryItemCount, "player", RANGED_SLOT)
    return ranged, (ok2 and n) or 0, "Shuriken"
end

local ammoShown, ammoBand
local function AmmoBubble()
    local item, count, glyph
    if ns.ClientFeature("ammo") and ns.db.liveAmmo then item, count, glyph = RangedSupply() end
    if not item then
        if ammoShown then ammoShown, ammoBand = nil, nil I:SetActivity("ammo", nil) end
        return
    end
    local warnAt = (glyph == "Shuriken") and 20 or AMMO_WARN
    local band = (count == 0) and "out" or (count <= warnAt and "low" or "ok")
    local id = tostring(item) .. glyph
    if ammoShown == id and ammoBand == band then return end
    ammoShown, ammoBand = id, band
    I:SetActivity("ammo", {
        glyph = glyph, tone = (band == "out" and RED) or (band == "low" and ORANGE) or C.fg,
        priority = 0.4, pin = "Ammo", tip = ItemName(item) or L["Ammo"],
        tip2 = (glyph == "Shuriken") and L["Thrown weapons left"] or L["Left in your bags"],
        text = function()
            local _, n = RangedSupply()
            return tostring(n or 0)
        end,
    })
end
ns.UpdateAmmoBubble = AmmoBubble

local function CheckSupplies()
    AmmoBubble()
    if not ns.ClientFeature("reagents") or not ns.db.alertReagents then return end
    local ammo, ammoCount = AmmoInUse()
    if ammo then
        CheckSupply(ammo, ammoCount, AMMO_WARN, "Arrow", L["AMMO"], true)
    end
    if GetItemCount then
        for id, warnAt in pairs(REAGENTS) do
            local count = GetItemCount(id) or 0
            if count > 0 or supply[id] then CheckSupply(id, count, warnAt, "Bag", L["REAGENTS"]) end
        end
    end
end

-- ---------------------------------------------------------------- buffs about to run out

local warnedBuff, warnedCount, weaponWarned = {}, 0, {}

local function BuffAt(i)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local d = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if d then return d.name, d.icon, d.duration, d.expirationTime end
        return nil
    elseif UnitBuff then
        local name, icon, _, _, duration, expires = UnitBuff("player", i)
        return name, icon, duration, expires
    end
end

local function BuffCard(key, name, icon, left)
    I:PushCard({
        kind = "won", key = key, icon = icon, cap = L["BUFF EXPIRING"], capColor = ORANGE, title = name, color = C.fg,
        res = ns.Clock and ns.Clock(left) or L["%ds"]:format(math.floor(left)), resColor = ORANGE, hold = 3.2, priority = 2,
    })
end

local function CheckBuffs()
    if not ns.db.alertBuffs then return end
    pcall(function()
        local now = GetTime()
        for i = 1, 40 do
            local name, icon, duration, expires = BuffAt(i)
            if not name then break end
            -- only long buffs (five minutes or more) with under a minute left
            if ns.Readable(name) and ns.Readable(duration) and ns.Readable(expires)
                and type(duration) == "number" and type(expires) == "number" and duration >= 300 then
                local left = expires - now
                local key = name .. ":" .. math.floor(expires)
                if left > 0 and left <= 60 and not warnedBuff[key] then
                    if warnedCount > 60 then warnedBuff, warnedCount = {}, 0 end
                    warnedBuff[key], warnedCount = true, warnedCount + 1
                    BuffCard("buff:" .. name, name, icon, left)
                end
            end
        end
        if GetWeaponEnchantInfo then
            local hasMain, mainLeft, _, _, hasOff, offLeft = GetWeaponEnchantInfo()
            for hand, has in pairs({ main = hasMain, off = hasOff }) do
                local left = (hand == "main") and mainLeft or offLeft
                if has and type(left) == "number" and left > 0 and left <= 60000 then
                    if not weaponWarned[hand] then
                        weaponWarned[hand] = true
                        local slot = hand == "main" and 16 or 17
                        BuffCard("weapon:" .. hand, hand == "main" and L["Main hand enchant"] or L["Off hand enchant"],
                                 GetInventoryItemTexture and GetInventoryItemTexture("player", slot), left / 1000)
                    end
                else
                    weaponWarned[hand] = false
                end
            end
        end
    end)
end

-- ---------------------------------------------------------------- demo

function ns.DemoAlerts()
    if not I.built then return end
    Card(nil, "Shield", ORANGE, L["LOW DURABILITY"], "Ironfoe", "18%", L["%d items under %s%%"]:format(3, 25))
    I:SetWarning("repairDemo", { glyph = "Armor", tone = RED, tip = L["Repairs needed"], tip2 = L["%s (demo)"]:format(L["%s at %d%%"]:format("Ironfoe", 18)) })
    C_Timer.After(12, function() I:SetWarning("repairDemo", nil) end)
    Card(nil, "Bag", ORANGE, L["BAGS NEARLY FULL"], L["%d slots left"]:format(2), "62 / 64")
    Card(nil, "Mail", BLUE, L["NEW MAIL"], L["From %s"]:format("Thrall, Jaina"))
    Card(nil, "Person", GREEN, L["FRIEND %s"]:format(L["ONLINE"]), "Thrall", nil, L["Level %d %s"]:format(42, LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE.SHAMAN or "Shaman") .. "   Stranglethorn Vale", 2.6)
    Card(nil, "Person", C.muted, L["GUILD MEMBER %s"]:format(L["OFFLINE"]), "Jaina", nil, nil, 2.6)
    Card(nil, "Arrow", ORANGE, L["LOW %s"]:format(L["AMMO"]), "Jagged Arrow", L["%d left"]:format(180))
    I:PushCard({ kind = "won", icon = "Interface\\Icons\\Spell_Holy_WordFortitude", cap = L["BUFF EXPIRING"], capColor = ORANGE,
                 title = "Power Word: Fortitude", color = C.fg, res = "0:45", resColor = ORANGE, hold = 3.2 })
end

-- ---------------------------------------------------------------- events

local ev = CreateFrame("Frame")
local ready, bagDirty, sinceRemind = false, false, 0

ev:SetScript("OnEvent", function(_, event, a)
    if event == "PLAYER_LOGIN" then
        friendOnline = ns.Compile(ERR_FRIEND_ONLINE_SS, true)
        friendOffline = ns.Compile(ERR_FRIEND_OFFLINE_S, true)
        hadMail = false
        -- give the game a few seconds to load gear, bags and mail before the first check
        C_Timer.After(6, function()
            ready = true
            CheckDurability()
            UpdateRepairDot()
            CheckBags()
            CheckMail()
            CheckSupplies()
        end)
    elseif not ready then
        return
    elseif event == "UPDATE_INVENTORY_DURABILITY" then
        CheckDurability()
        UpdateRepairDot()
    elseif event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" then
        bagDirty = true
    elseif event == "UPDATE_PENDING_MAIL" then
        CheckMail()
    elseif event == "CHAT_MSG_SYSTEM" then
        OnFriendMessage(a)
    elseif event == "BN_FRIEND_ACCOUNT_ONLINE" then
        OnBattleNetFriend(a, true)
    elseif event == "BN_FRIEND_ACCOUNT_OFFLINE" then
        OnBattleNetFriend(a, false)
    end
end)
for _, event in ipairs({ "PLAYER_LOGIN", "UPDATE_INVENTORY_DURABILITY", "BAG_UPDATE_DELAYED", "UPDATE_PENDING_MAIL", "PLAYER_EQUIPMENT_CHANGED",
                         "CHAT_MSG_SYSTEM", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE" }) do
    pcall(ev.RegisterEvent, ev, event)
end

-- bag changes arrive in bursts, so they are checked at most twice a second; reminders once a minute
local sinceBag, sinceBuff = 0, 0
ev:SetScript("OnUpdate", function(_, dt)
    if not ready then return end
    sinceBag = sinceBag + dt
    if bagDirty and sinceBag > 0.5 then
        bagDirty, sinceBag = false, 0
        CheckBags()
        CheckSupplies()
    end
    sinceBuff = sinceBuff + dt
    if sinceBuff > 5 then
        sinceBuff = 0
        CheckBuffs()
        CheckSupplies()
    end
    sinceRemind = sinceRemind + dt
    if sinceRemind < 60 then return end
    sinceRemind = 0
    local now, db = GetTime(), ns.db
    if db.durabilityReminder and dur.low and now - dur.last >= REMIND_EVERY then CheckDurability(true) end
    if db.bagReminder and bags.low and now - bags.last >= REMIND_EVERY then CheckBags(true) end
end)
