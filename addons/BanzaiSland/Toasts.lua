-- Island: everyday toasts. Items, upgrades and rewards, money, currency and reputation.
-- Cards reuse the winner card layout; money and honor use the small pill.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local floor, max, min = math.floor, math.max, math.min
local I, C = ns.Island, ns.C

local GREEN = { 0.36, 0.85, 0.45 }
local RED = { 0.95, 0.38, 0.38 }
local MUTED_HEX = ns.Hex(C.muted[1], C.muted[2], C.muted[3])

-- ---------------------------------------------------------------- items, upgrades, rewards

-- inventory slots an equip location can go in
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

-- Can the character wear this now? The game's own tooltip colours what you can't use red (an armor
-- type or weapon you haven't learned, a level you haven't reached, another class's item); without
-- the tooltip, the required level and the armor and weapon skills you know are checked instead.
local function Red(c)
    if type(c) ~= "table" then return false end
    local r, g, b = c.r, c.g, c.b
    if type(r) ~= "number" and c.GetRGB then r, g, b = c:GetRGB() end
    return type(r) == "number" and r > 0.9 and g < 0.3 and b < 0.3
end

local function TooltipSaysNo(link)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" or #data.lines == 0 then return nil end
    for _, line in ipairs(data.lines) do
        if Red(line.leftColor) or Red(line.rightColor) then return true end
        for _, arg in ipairs(line.args or {}) do
            if (arg.field == "leftColor" or arg.field == "rightColor") and Red(arg.colorVal) then return true end
        end
    end
    return false
end

-- armor and weapon types and the skill (a passive spell) that lets you use them
local ARMOR_SKILL = { [2] = 9077, [3] = 8737, [4] = 750, [6] = 9116 }          -- leather, mail, plate, shield
local WEAPON_SKILL = { [0] = 196, [1] = 197, [2] = 264, [3] = 266, [4] = 198, [5] = 199, [6] = 200,
                       [7] = 201, [8] = 202, [10] = 227, [13] = 15590, [15] = 1180, [16] = 2567,
                       [18] = 5011, [19] = 5009 }

local function CanWear(link)
    local no = TooltipSaysNo(link)
    if no ~= nil then return not no end
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local ok, _, _, _, _, minLevel, _, _, _, _, _, _, classID, subclassID = pcall(getInfo, link)
    if not ok then return true end
    if type(minLevel) == "number" and minLevel > (UnitLevel("player") or 1) then return false end
    local skill = (classID == 4 and ARMOR_SKILL[subclassID]) or (classID == 2 and WEAPON_SKILL[subclassID]) or nil
    if skill and IsPlayerSpell then
        local okS, known = pcall(IsPlayerSpell, skill)
        if okS and known == false then return false end
    end
    return true
end

-- ItemTree's public facts preserve random-suffix links and enabled-spec choices.
-- Do not treat its keep flag, unknown verdicts or level-only comparisons as upgrades.
local function ItemTreeReady()
    if ns.db and ns.db.itemTreeUpgrades==false then return end
    local api=_G.ItemTreeAPI
    if type(api)~="table" or type(api.IsReady)~="function" or type(api.GetItemFacts)~="function" then return end
    if api.version~=1 then return end
    if type(api.demo)=="table" and (not ns.Readable(api.demo.on) or api.demo.on~=false) then return end
    local ok,ready=pcall(api.IsReady)
    if ok and ns.Readable(ready) and ready==true then return api end
end
local function ItemTreeUpgrade(link)
    local api=ItemTreeReady()
    if not api or not ns.Readable(link) or type(link)~="string" then return false end
    local id=tonumber(link:match("item:(%d+)"))
    if not id or id<=0 then return false end
    local ok,facts=pcall(api.GetItemFacts,id,link)
    if not ok or not ns.Readable(facts) or type(facts)~="table" then return false end
    local keep=ns.Readable(facts.keep) and facts.keep
    local gear=type(keep)=="table" and ns.Readable(keep.gear) and keep.gear
    if type(gear)~="table" or not ns.Readable(gear.basis) or not ns.Readable(gear.upgrade)
        or type(gear.upgrade)~="boolean" then return false end
    if gear.basis~="stats" and gear.basis~="empty" then return false end
    if not gear.upgrade then return true,false end
    local labels={}
    if ns.Readable(gear.labels) and type(gear.labels)=="table" then
        for index=1,3 do
            local label=gear.labels[index]
            if ns.Readable(label) and type(label)=="string" and label~="" then labels[#labels+1]=label end
        end
    end
    local text=#labels>0 and L["ItemTree upgrade (%s)"]:format(table.concat(labels,", ")) or L["ItemTree upgrade"]
    return true,true,text,"ItemTree"
end

-- Lootified checks the complete item link (including random stats) against the active spec.
-- Read its existing verdict only; looting an item must not start a simulation.
-- First return: whether it supplied a verdict, including a definite no.
local function LootifiedUpgrade(link)
    if ns.db.lootifiedUpgrades == false then return false end
    local addon = _G.LootifiedAddon
    local check = type(addon) == "table" and addon.ItemCheck
    if type(check) ~= "table" or type(check.Get) ~= "function" then return false end
    if type(link) ~= "string" or not ns.Readable(link) then return false end
    if addon.Modules and type(addon.Modules.On) == "function" then
        local ok, enabled = pcall(addon.Modules.On, "bis")
        if not ok or not ns.Readable(enabled) or not enabled then return false end
    end
    local ok, verdict = pcall(check.Get, link)
    if not ok or type(verdict) ~= "table" or not ns.Readable(verdict.kind) then return false end
    local kind = verdict.kind
    if kind == "unknown" then return false end
    if kind == "cannot" or kind == "level" or kind == "worn" then
        return true, false
    end
    if kind == "estimate" then
        if not ns.Readable(verdict.better) or type(verdict.better) ~= "boolean" then return false end
        return true, verdict.better, L["Lootified estimate"], "Lootified", verdict.replaces
    end
    local direction = kind == "sim" and check.Direction or kind == "stats" and check.StatsDirection
    if type(direction) ~= "function" then return false end
    local good, value = pcall(direction, verdict)
    if not good or not ns.Readable(value) then return false end
    if value ~= "up" and value ~= "down" and value ~= "same" then return false end
    if value ~= "up" then return true, false end
    local amount = kind == "sim" and verdict.delta or verdict.pct
    local text = L["Lootified upgrade"]
    if ns.Readable(amount) and type(amount) == "number" and amount > 0 then
        text = (kind == "sim" and L["+%.1f DPS"] or L["+%.1f%%"]):format(amount)
    end
    return true, true, text, "Lootified", verdict.replaces
end

-- Pawn's first result contains stat-weight upgrades for enabled scales. Its separate
-- item-level result is deliberately ignored: item level is not a useful verdict on Forever.
local function PawnUpgrade(link)
    if ns.db.pawnUpgrades == false then return false end
    if type(PawnGetItemData) ~= "function" or type(PawnIsItemAnUpgrade) ~= "function" then return false end
    local ok, data = pcall(PawnGetItemData, link)
    if not ok or type(data) ~= "table" then return false end
    if (ns.Readable(data.CanEquip) and data.CanEquip == false) or (ns.Readable(data.Rarity) and data.Rarity == 6) then return true, false end
    local good, upgrades = pcall(PawnIsItemAnUpgrade, data)
    if not good then return false end
    if type(upgrades) ~= "table" then return true, false end
    local best, scale, replaces
    for _, entry in ipairs(upgrades) do
        if type(entry) == "table" then
            local pct = entry.PercentUpgrade
            if ns.Readable(pct) and type(pct) == "number" and pct > 0 and (not best or pct > best) then
                best = pct
                scale = entry.LocalizedScaleName or entry.ScaleName
                replaces = entry.ExistingItemLink
            end
        end
    end
    if not best then return true, false end
    local threshold = _G.PawnBigUpgradeThreshold
    if not ns.Readable(threshold) or type(threshold) ~= "number" or threshold <= 0 then threshold = 100 end
    local text = L["Pawn upgrade"]
    if ns.Readable(scale) and type(scale) == "string" and scale ~= "" then
        text = best < threshold and L["+%.1f%% (%s)"]:format(best * 100, scale) or L["Pawn upgrade (%s)"]:format(scale)
    elseif best < threshold then
        text = L["+%.1f%%"]:format(best * 100)
    end
    return true, true, text, "Pawn", replaces
end

-- Optional evaluators are cache-only consumers; their registration never starts work.
-- Existing definitive ItemTree/Lootified/Pawn verdicts retain precedence.
local providers = {}
local providerAPI = { version = 1 }
_G.BanzaiSland_UpgradeProviders = providerAPI
function providerAPI.Register(name, provider)
    if type(name) ~= "string" or #name > 64 or not name:match("^[%w_%-]+$") or type(provider) ~= "table"
        or type(provider.IsReady) ~= "function" or type(provider.GetInfo) ~= "function" then return false end
    for _, entry in ipairs(providers) do
        if entry.name == name then entry.IsReady, entry.GetInfo = provider.IsReady, provider.GetInfo; return true end
    end
    if #providers >= 8 then return false end
    providers[#providers + 1] = { name = name, IsReady = provider.IsReady, GetInfo = provider.GetInfo }
    return true
end
local function ProviderReady(entry)
    if not (ns.Client and ns.Client.isForever) then return false end
    local ok, ready = pcall(entry.IsReady)
    return ok and ns.Readable(ready) and ready == true
end
local function ExtraUpgrade(link, equipLoc)
    for _, entry in ipairs(providers) do
        if ProviderReady(entry) then
            local ok, info = pcall(entry.GetInfo, link, equipLoc)
            if ok and ns.Readable(info) and type(info) == "table" and ns.Readable(info.verdict) then
                if info.verdict == "downgrade" or info.verdict == "equivalent" then return true, false end
                if info.verdict == "upgrade" and ns.Readable(info.text) and type(info.text) == "string" and info.text ~= "" then
                    return true, true, info.text, entry.name, info.replaces
                end
            end
        end
    end
    return false
end

-- Check callable APIs rather than installed folders: a disabled addon cannot evaluate items.
function ns.CanCheckUpgrades()
    local db = ns.db or {}
    if ItemTreeReady() then return true end
    local addon = _G.LootifiedAddon
    local check = type(addon) == "table" and addon.ItemCheck
    if db.lootifiedUpgrades ~= false and type(check) == "table" and type(check.Get) == "function" then
        if not (addon.Modules and type(addon.Modules.On) == "function") then return true end
        local ok, enabled = pcall(addon.Modules.On, "bis")
        if ok and ns.Readable(enabled) and enabled == true then return true end
    end
    if db.pawnUpgrades ~= false and type(PawnGetItemData) == "function" and type(PawnIsItemAnUpgrade) == "function" then return true end
    for _, entry in ipairs(providers) do if ProviderReady(entry) then return true end end
    return false
end

-- Both loot notifications and roll cards use the same evaluator and replacement choice.
function ns.GetUpgradeInfo(link, equipLoc)
    if not ns.CanCheckUpgrades() then return nil end
    if not ns.Readable(link) or type(link) ~= "string" then return nil end
    if not equipLoc then
        local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        if instant then
            local ok, _, _, _, loc = pcall(instant, link)
            if ok and ns.Readable(loc) then equipLoc = loc end
        end
    end
    if not (equipLoc and SLOTS[equipLoc]) or not CanWear(link) then return nil end
    local handled, upgrade, text, source, replaces = ItemTreeUpgrade(link)
    if not handled then handled, upgrade, text, source, replaces = LootifiedUpgrade(link) end
    if not handled then handled, upgrade, text, source, replaces = PawnUpgrade(link) end
    if not handled then handled, upgrade, text, source, replaces = ExtraUpgrade(link, equipLoc) end
    if not (handled and upgrade) then return nil end
    local info = { text = text, source = source }
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if getInfo and ns.Readable(replaces) and (type(replaces) == "string" or type(replaces) == "number") then
        local ok, name = pcall(getInfo, replaces)
        if ok and ns.Readable(name) and type(name) == "string" and name ~= "" then info.replacementName = name end
    end
    return info
end

local function UpgradeText(link, equipLoc)
    local info = ns.GetUpgradeInfo(link, equipLoc)
    return info and info.text
end

function ns.OnItemLoot(kind, link, name, icon, quality, level, equipLoc, count)
    local db = ns.db
    -- an item you just won on a roll already had its card
    local wonAt = ns.recentWon[name]
    if wonAt and GetTime() - wonAt < 10 then
        ns.recentWon[name] = nil
        return
    end

    local item = {
        kind = "won", key = "item:" .. name, count = count, title = name, icon = icon, link = link,
        color = ns.QualityColor(quality), hold = 2.4,
        format = function(n) return n > 1 and ("x" .. n) or "" end,
    }
    local upgradeText
    if db.toastUpgrades then upgradeText = UpgradeText(link, equipLoc) end
    if upgradeText then
        item.cap, item.capColor, item.flash, item.resColor = L["UPGRADE"], GREEN, GREEN, GREEN
        local text = upgradeText
        item.format = function() return text end
        item.hold = 3.2
    elseif kind == "pushed" and db.toastRewards then
        item.cap, item.capColor = L["REWARD"], C.quest
    elseif db.toastItems and (quality or 1) >= (db.itemMinQuality or 0) then
        item.cap = (kind == "created") and L["CREATED"] or L["LOOT"]
    else
        return
    end
    item.res = item.format(count)
    if type(ns.Retail)=="table" then item.line=ns.Retail.GearDetails(link) end
    item.group = item.group or "loot"
    I:PushCard(item)
end

-- ---------------------------------------------------------------- money

local GOLD_HEX, SILVER_HEX, COPPER_HEX = "|cffffd700", "|cffc7c7cf", "|cffeda55f"

local function MoneyText(copper)
    local g, s, c = floor(copper / 10000), floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = ns.Comma(g) .. GOLD_HEX .. "g|r" end
    if s > 0 and g < 10000 then parts[#parts + 1] = s .. SILVER_HEX .. "s|r" end
    if (c > 0 and g < 100) or #parts == 0 then parts[#parts + 1] = c .. COPPER_HEX .. "c|r" end
    return "+" .. table.concat(parts, " ")
end
ns.MoneyText = MoneyText

-- Money in a coin bubble beside the island (if chosen) instead of where XP gains show: one running
-- total while you loot, gone a few seconds after the last coin.
local coin = { total = 0, last = 0 }
local COIN_LINGER = 5
local function CoinBubble(copper)
    coin.total = coin.total + copper
    coin.last = GetTime()
    I:SetActivity("money", {
        glyph = "Coin", tone = C.gold, priority = 2.5, tip = L["Money looted"], tip2 = L["Adds up while you loot"],
        text = function() return MoneyText(coin.total) end,
    })
    C_Timer.After(COIN_LINGER, function()
        if GetTime() - coin.last >= COIN_LINGER - 0.1 then
            coin.total = 0
            I:SetActivity("money", nil)
        end
    end)
end

local function PushMoney(copper)
    if not ns.db.toastMoney or not copper or copper <= 0 then return end
    if ns.db.moneyBubble then CoinBubble(copper) return end
    I:Push({ group = "loot", kind = "gain", unit = "money", amount = copper, fmt = MoneyText, color = C.fg })
end

local moneyPatterns, moneyPrefixes = {}, {}
local lastQuestMoney, lastQuestMoneyAt = 0, 0

local function ParseMoney(msg)
    msg = msg:gsub("(%d)[,%.](%d%d%d)", "%1%2")
    local total = 0
    for i, pat in ipairs(moneyPatterns) do
        local n = tonumber(msg:match(pat))
        if n then total = total + n * (i == 1 and 10000 or (i == 2 and 100 or 1)) end
    end
    return total
end

local function OnMoneyMessage(msg)
    if not ns.Readable(msg) then return end      -- the game hides some chat text from addons in combat
    if type(msg) ~= "string" then return end
    if #moneyPrefixes > 0 then
        local mine = false
        for _, prefix in ipairs(moneyPrefixes) do
            if msg:find(prefix, 1, true) == 1 then mine = true break end
        end
        if not mine then return end
    end
    local copper = ParseMoney(msg)
    -- quest money is announced by the quest event too; do not count it twice
    if copper == lastQuestMoney and GetTime() - lastQuestMoneyAt < 1.5 then
        lastQuestMoney = 0
        return
    end
    PushMoney(copper)
end

-- ---------------------------------------------------------------- currency and honor

local function OnCurrencyMessage(msg)
    if not ns.Readable(msg) then return end      -- the game hides some chat text from addons in combat
    if not ns.db.toastCurrency or type(msg) ~= "string" then return end
    local link = msg:match("(|c.-|Hcurrency:.-|h%[.-%]|h|r)") or msg:match("(|Hcurrency:.-|h%[.-%]|h)")
    if not link then return end
    local id = tonumber(link:match("|Hcurrency:(%d+)"))
    local name = link:match("%[(.-)%]") or L["Currency"]
    local count = tonumber(msg:match("|h|r%s*x(%d+)")) or tonumber(msg:match("|h%s*x(%d+)")) or 1
    local icon
    if id and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
        if ok and type(info) == "table" then icon = info.iconFileID end
    end
    I:PushCard({ group = "loot",
        kind = "won", key = "currency:" .. name, count = count, title = name, icon = icon, link = link,
        cap = L["CURRENCY"], color = C.fg, hold = 2.4,
        line = type(ns.Retail)=="table" and ns.Retail.CurrencyDetails(id) or nil,
        format = function(n) return "+" .. ns.Comma(n) end, res = "+" .. ns.Comma(count),
    })
end

local function OnHonorMessage(msg)
    if not ns.Readable(msg) then return end      -- the game hides some chat text from addons in combat
    if not ns.db.toastCurrency or type(msg) ~= "string" then return end
    local amount
    for n in msg:gmatch("(%d+)") do amount = tonumber(n) end      -- the honor amount is the last number
    if not amount or amount <= 0 then return end
    I:Push({ group = "loot", kind = "gain", unit = "honor", amount = amount, color = C.fg,
             fmt = function(n) return L["+%s honor"]:format(ns.Comma(n)) end })
end

-- ---------------------------------------------------------------- reputation

local repUp, repDown

-- standing name, progress into the standing, size of the standing
local function FactionProgress(name)
    if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
        for i = 1, C_Reputation.GetNumFactions() do
            local ok, d = pcall(C_Reputation.GetFactionDataByIndex, i)
            if ok and type(d) == "table" and d.name == name then
                return d.reaction, (d.currentStanding or 0) - (d.currentReactionThreshold or 0),
                    (d.nextReactionThreshold or 0) - (d.currentReactionThreshold or 0)
            end
        end
    elseif GetNumFactions and GetFactionInfo then
        for i = 1, GetNumFactions() do
            local n, _, standing, lo, hi, value = GetFactionInfo(i)
            if n == name then return standing, (value or 0) - (lo or 0), (hi or 0) - (lo or 0) end
        end
    end
end

local function PushRep(faction, amount)
    local standing, cur, span = FactionProgress(faction)
    local tone = C.disc
    local c = standing and FACTION_BAR_COLORS and FACTION_BAR_COLORS[standing]
    if c then tone = { c.r, c.g, c.b } end
    local line
    if standing then
        local label = _G["FACTION_STANDING_LABEL" .. standing] or ""
        line = MUTED_HEX .. label .. ((span and span > 0) and ("   " .. ns.Comma(cur) .. " / " .. ns.Comma(span)) or "") .. "|r"
    end
    if type(ns.Retail)=="table" then line=ns.Retail.ReputationDetails(faction) or line end
    local function fmt(n) return (n >= 0 and "+" or "-") .. ns.Comma(math.abs(n)) end
    I:PushCard({ group = "loot",
        kind = "won", key = "rep:" .. faction, count = amount, title = faction, glyph = "Star", tone = tone,
        cap = L["REPUTATION"], color = C.fg, resColor = amount >= 0 and GREEN or RED, hold = 2.8,
        format = fmt, res = fmt(amount), line = line,
    })
end

local function OnRepMessage(msg)
    if not ns.Readable(msg) then return end      -- the game hides some chat text from addons in combat
    if not ns.db.toastRep or type(msg) ~= "string" then return end
    local faction, amount
    if repUp then faction, amount = msg:match(repUp) end
    if faction and tonumber(amount) then
        PushRep(faction, tonumber(amount))
        return
    end
    if repDown then faction, amount = msg:match(repDown) end
    if faction and tonumber(amount) then PushRep(faction, -tonumber(amount)) end
end

-- ---------------------------------------------------------------- demo

function ns.DemoToasts()
    if not I.built then return end
    local q = ns.QualityColor
    I:PushCard({ group = "loot", kind = "won", cap = L["LOOT"], title = "Heavy Leather", icon = "Interface\\Icons\\INV_Misc_LeatherScrap_07",
                 color = q(1), res = "x3", hold = 2.4 })
    I:PushCard({ group = "loot", kind = "won", cap = L["UPGRADE"], capColor = GREEN, resColor = GREEN, flash = GREEN, title = "Blackened Defias Belt",
                 icon = "Interface\\Icons\\INV_Belt_03", color = q(2), res = L["+%.1f%%"]:format(4), hold = 3.2 })
    I:PushCard({ group = "loot", kind = "won", cap = L["REWARD"], capColor = C.quest, title = "Staff of Westfall",
                 icon = "Interface\\Icons\\INV_Staff_10", color = q(3), res = "", hold = 2.4 })
    I:Push({ group = "loot", kind = "gain", unit = "money", amount = 12345, fmt = MoneyText, color = C.fg })
    I:PushCard({ group = "loot", kind = "won", cap = L["CURRENCY"], title = "Honor Points", icon = "Interface\\Icons\\INV_BannerPVP_02",
                 color = C.fg, res = "+198", hold = 2.4 })
    I:PushCard({ group = "loot", kind = "won", cap = L["REPUTATION"], title = "Argent Dawn", glyph = "Star", tone = GREEN, color = C.fg,
                 res = "+25", resColor = GREEN, line = MUTED_HEX .. "Honored   3,025 / 12,000|r", hold = 2.8 })
end

-- ---------------------------------------------------------------- events

local function Prefix(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:match("^(.-)%%") or fmt
    if p ~= "" then return p end
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, a, b, c)
    if event == "CHAT_MSG_MONEY" then
        OnMoneyMessage(a)
    elseif event == "QUEST_TURNED_IN" then
        local copper = tonumber(c)
        if copper and copper > 0 then
            lastQuestMoney, lastQuestMoneyAt = copper, GetTime()
            PushMoney(copper)
        end
    elseif event == "CHAT_MSG_CURRENCY" then
        OnCurrencyMessage(a)
    elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        OnHonorMessage(a)
    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        OnRepMessage(a)
    elseif event == "PLAYER_LOGIN" then
        for _, name in ipairs({ "GOLD_AMOUNT", "SILVER_AMOUNT", "COPPER_AMOUNT" }) do
            local fmt = _G[name]
            local pat = type(fmt) == "string" and fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"):gsub("%%d", "(%%d+)")
            moneyPatterns[#moneyPatterns + 1] = pat or "$^"
        end
        for _, name in ipairs({ "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT", "YOU_LOOT_MONEY_GUILD", "LOOT_MONEY_SPLIT_GUILD" }) do
            local p = Prefix(_G[name])
            if p then moneyPrefixes[#moneyPrefixes + 1] = p end
        end
        repUp = ns.Compile(FACTION_STANDING_INCREASED, true)
        repDown = ns.Compile(FACTION_STANDING_DECREASED, true)
    end
end)
for _, event in ipairs({ "CHAT_MSG_MONEY", "QUEST_TURNED_IN", "CHAT_MSG_CURRENCY", "CHAT_MSG_COMBAT_HONOR_GAIN",
                         "CHAT_MSG_COMBAT_FACTION_CHANGE", "PLAYER_LOGIN" }) do
    pcall(ev.RegisterEvent, ev, event)
end
