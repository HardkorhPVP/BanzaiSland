-- Retail progression and rewards. No frames, hooks or API calls are created on Forever.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
if not ns.ClientFeature("retail") then return end
local L, I, C = ns.L, ns.Island, ns.C
local R = { ready = false, loading = false, epoch = 0, seen = {}, vault = {}, knowledge = {} }
ns.Retail = R
local BLUE, GREEN, PURPLE = { .40,.72,1 }, { .36,.85,.45 }, { .70,.55,1 }
local function Read(v, kind) return ns.Readable(v) and type(v) == kind end
local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local function Pack(...) return {n=select("#",...),...} end
    local values = Pack(pcall(fn, ...))
    if not values[1] then return end
    for index=2,values.n do if not ns.Readable(values[index]) then values[index]=nil end end
    return unpack(values, 2, values.n)
end
R.Call, R.Read = Call, Read
local function Muted(text) return ns.Hex(C.muted[1],C.muted[2],C.muted[3]) .. text .. "|r" end
local function Enabled(key) return ns.db and ns.db[key] ~= false end
local function Store()
    local db = ns.account or ns.db
    if not db then return end
    if type(db.retailProgress) ~= "table" then db.retailProgress = {} end
    local s = db.retailProgress
    if type(s.seen) ~= "table" then s.seen = {} end
    if type(s.renown) ~= "table" then s.renown = {} end
    return s
end
local function Seen(key, account)
    local s = account and Enabled("retailWarband") and Store()
    local seen = s and s.seen or R.seen
    if seen[key] then return true end
    seen[key] = Call(time) or GetTime()
    -- Collection histories are only a duplicate guard, not a growing collection database.
    local n, oldest, age = 0
    for id, at in pairs(seen) do
        n = n+1
        if not age or at < age then oldest, age = id, at end
    end
    if n > 512 then seen[oldest] = nil end
    return false
end
local function Card(kind, key, caption, title, result, line, glyph, tone)
    return { kind="won", key=key, builderType=kind, group="world", cap=caption, capColor=tone or BLUE,
        title=title, res=result or "", resColor=tone or BLUE, line=line and Muted(line), glyph=glyph or "Star",
        tone=tone or BLUE, color=C.fg, hold=4, onClick=false }
end
function R.Notify(item, option)
    if not R.ready or R.loading or not I.built or not Enabled(option) then return false end
    local category = item.builderType=="retailCollection" and "collections" or item.builderType=="retailHousing" and "housing" or "retailProgress"
    item.catchUpCategory=category
    if ns.CatchUp then
        ns.CatchUp.Record(category,item.key or item.builderType,item.title,
            item.res~="" and L["%s · %s"]:format(item.cap,item.res) or item.cap,{glyph=item.glyph or "Star"})
    end
    I:PushReplace(item)
    return true
end

-- Normalize special reputations into the same state consumed by the existing XP/rep island.
function R.GetWatchedState(state, faction)
    local f = faction or Call(C_Reputation and C_Reputation.GetWatchedFactionData)
    if not Read(f,"table") or not Read(f.factionID,"number") or not Read(f.name,"string") then return end
    local id, current, maximum, label = f.factionID
    local pending
    local major = Call(C_MajorFactions and C_MajorFactions.GetMajorFactionData, id)
    local isRenown = Read(major,"table") and Read(major.renownLevel,"number")
    local capped = isRenown and (Call(C_MajorFactions and C_MajorFactions.HasMaximumRenown,id)==true
        or (Read(major.maxLevel,"number") and major.renownLevel>=major.maxLevel))
    -- Paragon capability can be reported before a major faction's Renown track is finished.
    if (not isRenown or capped) and Call(C_Reputation and C_Reputation.IsFactionParagon, id) == true then
        local value, threshold, _, ready = Call(C_Reputation.GetFactionParagonInfo, id)
        if Read(value,"number") and Read(threshold,"number") and threshold > 0 then
            current, maximum, pending = value % threshold, threshold, ready == true
            if pending then current = threshold end
            label = pending and L["Paragon reward ready"] or L["Paragon"]
        end
    end
    if not label then
        if isRenown then
            local value, threshold = major.renownReputationEarned, major.renownLevelThreshold
            if Read(value,"number") and Read(threshold,"number") and threshold > 0 then
                current, maximum = value, threshold
                if capped then current = threshold end
                label = L["Renown %d"]:format(major.renownLevel)
            end
        end
    end
    if not label then
        local friend = Call(C_GossipInfo and C_GossipInfo.GetFriendshipReputation,id)
        if Read(friend,"table") and Read(friend.friendshipFactionID,"number") and friend.friendshipFactionID > 0
            and Read(friend.standing,"number") and Read(friend.reactionThreshold,"number") then
            local nextLevel = Read(friend.nextThreshold,"number") and friend.nextThreshold or friend.maxRep
            if Read(nextLevel,"number") then
                maximum = math.max(1,nextLevel-friend.reactionThreshold)
                current = Read(friend.nextThreshold,"number") and friend.standing-friend.reactionThreshold or maximum
                label = Read(friend.reaction,"string") and friend.reaction or L["Friendship"]
            end
        end
    end
    if not label then return end
    state.mode, state.name, state.standing = "rep", f.name, f.reaction
    state.cur, state.max = math.max(0,math.min(maximum,current)), maximum
    state.p, state.r = state.cur / maximum, 0
    state.pctText, state.standingText = math.floor(state.p*100).."%", label
    state.value, state.color = current, BLUE
    if Enabled("retailWarband") and (f.isAccountWide == true or Call(C_Reputation.IsAccountWideReputation,id) == true) then
        state.standingText = L["%s · Warband"]:format(label)
    end
    return state
end

function R.ReputationDetails(name)
    if not Read(name,"string") then return end
    local count=Call(C_Reputation and C_Reputation.GetNumFactions)
    if not Read(count,"number") then return end
    for index=1,count do
        local data=Call(C_Reputation.GetFactionDataByIndex,index)
        if Read(data,"table") and Read(data.name,"string") and data.name==name then
            local state=R.GetWatchedState({},data)
            if state then return Muted(L["%s · %s / %s"]:format(state.standingText,ns.Comma(state.cur),ns.Comma(state.max))) end
            if Enabled("retailWarband") and data.isAccountWide==true then return Muted(L["Warband reputation"]) end
            return
        end
    end
end
function R.CurrencyDetails(id)
    if not Enabled("retailWarband") or not Read(id,"number") then return end
    local info=Call(C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo,id)
    if not Read(info,"table") then return end
    if info.isAccountWide==true then return Muted(L["Warband currency"]) end
    if info.isAccountTransferable==true then return Muted(L["Transferable between characters"]) end
end

function R.SeedRenown()
    local ids = Call(C_MajorFactions and C_MajorFactions.GetMajorFactionIDs)
    local store = Store()
    if not Read(ids,"table") or not store then return end
    for _, id in ipairs(ids) do
        if Read(id,"number") then
            local data = Call(C_MajorFactions.GetMajorFactionData,id)
            if Read(data,"table") and Read(data.renownLevel,"number") then
                store.renown[id] = math.max(store.renown[id] or 0,data.renownLevel)
            end
        end
    end
end
function R.Renown(id, level, old)
    if not Read(id,"number") or not Read(level,"number") or not Read(old,"number") then return end
    local store = Store()
    if not store then return end
    local previous = store.renown[id] or old
    store.renown[id] = math.max(previous,level)
    if level <= old or (Enabled("retailWarband") and level <= previous) then return end
    local info = Call(C_MajorFactions and C_MajorFactions.GetMajorFactionData,id)
    if not Read(info,"table") or not Read(info.name,"string") then return end
    R.Notify(Card("retailRenown","renown:"..id,L["RENOWN INCREASED"],info.name,L["Renown %d"]:format(level),
        Enabled("retailWarband") and L["Warband progression"] or nil,"Star",BLUE),"retailRenown")
end

-- This is descriptive gear information, never an item-level-based upgrade verdict.
function R.GearDetails(link)
    if not Enabled("retailGear") or not Read(link,"string") then return end
    local _, _, _, _, _, _, _, _, equip = Call(C_Item and C_Item.GetItemInfo,link)
    if not Read(equip,"string") or equip == "" then return end
    local level = Call(C_Item and C_Item.GetDetailedItemLevelInfo,link)
    local parts = {}
    if Read(level,"number") then parts[#parts+1] = L["Item level %d"]:format(level) end
    local upgrade = Call(C_Item and C_Item.GetItemUpgradeInfo,link)
    if Read(upgrade,"table") and Read(upgrade.trackString,"string") then
        local track = upgrade.trackString
        if Read(upgrade.currentLevel,"number") and Read(upgrade.maxLevel,"number") and upgrade.maxLevel > 0 then
            track = L["%s %d/%d"]:format(track,upgrade.currentLevel,upgrade.maxLevel)
        end
        parts[#parts+1] = track
    end
    if Enabled("retailWarband") and Call(C_Item and C_Item.IsItemBindToAccountUntilEquip,link) == true then
        parts[#parts+1] = L["Warbound until equipped"]
    end
    return #parts > 0 and Muted(table.concat(parts," · ")) or nil
end

local function OpenAddon(addon, fn, frameName)
    if InCombatLockdown and InCombatLockdown() then return false end
    Call(C_AddOns and C_AddOns.LoadAddOn,addon)
    local existing=_G[frameName]
    if existing and Call(existing.IsShown,existing)==true then return true end
    if type(_G[fn]) == "function" then return pcall(_G[fn]) end
    local frame = _G[frameName]
    if frame and frame.Show then return pcall(frame.Show,frame) end
    return false
end
local function VaultButton()
    return {label=L["View Great Vault"],fn=function() return OpenAddon("Blizzard_WeeklyRewards","WeeklyRewards_ShowUI","WeeklyRewardsFrame") end}
end
function R.ClearBubbles()
    for _,key in ipairs({"retailVault","retailKnowledge","retailQueue"}) do I:SetActivity(key,nil) end
end
function R.Queue()
    if not R.ready or R.loading or not Enabled("bubbleRetailQueue") then I:SetActivity("retailQueue",nil) return end
    local category=LE_LFG_CATEGORY_LFD
    if not Read(category,"number") then I:SetActivity("retailQueue",nil) return end
    local mode=Call(GetLFGMode,category)
    if mode~="queued" and mode~="suspended" then I:SetActivity("retailQueue",nil) return end
    -- Blizzard's timestamp survives reloads; never invent a start time if it is unavailable.
    local stats={Call(GetLFGQueueStats,category)}
    local started=Read(stats[17],"number") and stats[17] or nil
    local activeID=Read(stats[18],"number") and stats[18] or nil
    local info={Call(GetLFGInfoServer,category,activeID)}
    local roles={}
    if info[10]==true then roles[#roles+1]=L["Tank"] end
    if info[11]==true then roles[#roles+1]=L["Healer"] end
    if info[12]==true then roles[#roles+1]=L["Damage"] end
    local detail=#roles>0 and table.concat(roles," / ") or L["Time waiting"]
    if mode=="suspended" then detail=L["Queue suspended"] end
    I:SetActivity("retailQueue",{glyph="Person",tone=BLUE,priority=3,tip=L["Dungeon Finder queue"],tip2=detail,
        onClick=function()
            if InCombatLockdown and InCombatLockdown() then return false end
            Call(C_AddOns and C_AddOns.LoadAddOn,"Blizzard_GroupFinder")
            if type(PVEFrame_ShowFrame)=="function" then return pcall(PVEFrame_ShowFrame,"GroupFinderFrame","LFDParentFrame") end
            return false
        end,
        text=function() return started and ns.Clock(math.max(0,GetTime()-started)) or "" end})
end
function R.KnowledgeBubble(totals)
    local total,lines=0,{}
    for _,entry in ipairs(totals) do
        if entry.total>0 then
            total=total+entry.total
            lines[#lines+1]=L["%s: %d"]:format(entry.name,entry.total)
        end
    end
    table.sort(lines)
    I:SetActivity("retailKnowledge",Enabled("bubbleRetailKnowledge") and total>0 and {
        glyph="Flask",tone=C.gold,priority=1,tip=L["Unspent profession Knowledge"],tip2=table.concat(lines,"\n"),
        text=function() return tostring(total) end,
        onClick=function() return OpenAddon("Blizzard_ProfessionsBook","ToggleProfessionsBook","ProfessionsBookFrame") end,
    } or nil)
end
function R.Vault(baseline)
    if not R.ready or R.loading then return end
    local available = Call(C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards)
    I:SetActivity("retailVault",Enabled("bubbleRetailVault") and available==true and {
        glyph="Chest",tone=C.gold,priority=2,tip=L["Great Vault reward ready"],tip2=L["Click to view your weekly rewards"],
        onClick=VaultButton().fn,
    } or nil)
    if Read(available,"boolean") then
        if available and not R.vaultReminded then
            local item = Card("retailVault","vaultReward",L["GREAT VAULT"],L["Your weekly reward is ready"],"",nil,"Chest",C.gold)
            item.button = VaultButton()
            if R.Notify(item,"retailVault") then R.vaultReminded = true end
        elseif not available then R.vaultReminded = false end
    end
    local activities = Call(C_WeeklyRewards and C_WeeklyRewards.GetActivities)
    if not Read(activities,"table") then return end
    local groups = {}
    for _, a in ipairs(activities) do
        if Read(a,"table") and Read(a.id,"number") and Read(a.type,"number")
            and Read(a.progress,"number") and Read(a.threshold,"number") and a.threshold > 0 then
            local g = groups[a.type] or {activities={}, increased=false, unlocked=0}
            groups[a.type] = g
            local previous = R.vault[a.id]
            if previous and a.progress > previous then g.increased = true end
            R.vault[a.id] = a.progress
            g.activities[#g.activities+1] = a
            if a.progress >= a.threshold then g.unlocked = g.unlocked+1 end
        end
    end
    for kind, g in pairs(groups) do
        table.sort(g.activities,function(a,b) return a.threshold < b.threshold end)
        local a = g.activities[#g.activities]
        for _, candidate in ipairs(g.activities) do if candidate.progress < candidate.threshold then a=candidate break end end
        if not baseline and g.increased then
            local names = Enum and Enum.WeeklyRewardChestThresholdType or {}
            local name = kind == names.Raid and L["Raids"] or kind == names.Activities and L["Dungeons"]
                or kind == names.RankedPvP and L["PvP"] or kind == names.World and L["World activities"] or L["Weekly activities"]
            local item = Card("retailVault","vaultProgress:"..kind,L["GREAT VAULT"],name,L["%d / %d"]:format(a.progress,a.threshold),
                L["%d reward slots unlocked"]:format(g.unlocked),"Chest",C.gold)
            item.button = VaultButton()
            R.Notify(item,"retailVault")
        end
    end
end

local function MarkInstance()
    local db = ns.char or ns.db
    if db and db.runs and db.runs.current then db.runs.current.retailSummaryShown = true end
end
function R.MythicCompleted()
    if not R.ready or R.loading or not Enabled("retailMythic") then return end
    local map, level, elapsed, onTime, upgrades, _, oldScore, newScore = Call(C_ChallengeMode and C_ChallengeMode.GetCompletionInfo)
    if Read(map,"table") then
        local data = map
        map, level, elapsed = data.mapChallengeModeID or data.mapID,data.level,data.time
        onTime = data.onTime
        if not Read(onTime,"boolean") then onTime = data.isCompletedWithinTime end
        oldScore,newScore = data.oldDungeonScore,data.newDungeonScore
    end
    if not Read(map,"number") or not Read(level,"number") or not Read(elapsed,"number") then return end
    local key = "mythic:"..map..":"..level..":"..elapsed
    if Seen(key,false) then return end
    local name = Call(C_ChallengeMode.GetMapUIInfo,map)
    local line = Read(onTime,"boolean") and (onTime and L["Completed in time"] or L["Completed over time"]) or L["Completed"]
    if Read(oldScore,"number") and Read(newScore,"number") and newScore > oldScore then
        line = L["%s · +%d rating"]:format(line,math.floor(newScore-oldScore))
    end
    local item = Card("retailMythic",key,L["MYTHIC+ COMPLETE"],Read(name,"string") and name or L["Mythic+ dungeon"],
        L["+%d · %s"]:format(level,ns.Clock(elapsed/1000)),line,"Door",onTime == true and GREEN or BLUE)
    if R.Notify(item,"retailMythic") then MarkInstance() end
end
function R.Delve(baseline)
    if not R.ready or R.loading then return end
    local tier = Call(C_DelvesUI and C_DelvesUI.GetActiveDelveTier)
    local inside = Call(IsInInstance)
    if not inside or not Read(tier,"table") or not Read(tier.tier,"number") or tier.tier <= 0 then R.delve=nil return end
    local info = Call(C_Scenario and C_Scenario.GetScenarioInfo)
    local name = Read(info,"table") and info.name or Call(C_Scenario and C_Scenario.GetInfo)
    if not Read(name,"string") then return end
    if not R.delve or R.delve.name ~= name then R.delve={name=name,tier=tier.tier,started=GetTime(),done=false} end
    local done = Call(C_PartyInfo and C_PartyInfo.IsDelveComplete)
    if done == true and not R.delve.done then
        R.delve.done = true
        if baseline then return end
        local run = R.delve
        local item = Card("retailDelve","delveComplete",L["DELVE COMPLETE"],run.name,L["Tier %d"]:format(run.tier),
            L["Time inside: %s"]:format(ns.Clock(GetTime()-run.started)),"Door",PURPLE)
        if R.Notify(item,"retailDelves") then MarkInstance() end
    end
end

function R.Knowledge(baseline)
    if not R.ready or R.loading then return end
    local skills = Call(C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines)
    if not Read(skills,"table") then I:SetActivity("retailKnowledge",nil) return end
    local totals={}
    for _, skill in ipairs(skills) do
        if Read(skill,"number") then
            local config = Call(C_ProfSpecs and C_ProfSpecs.GetConfigIDForSkillLine,skill)
            local trees = Call(C_ProfSpecs and C_ProfSpecs.GetSpecTabIDsForSkillLine,skill)
            local info = Call(C_TradeSkillUI.GetProfessionInfoBySkillLineID,skill)
            if Read(config,"number") and config > 0 and Read(trees,"table") and Read(info,"table") and Read(info.professionName,"string") then
                local total, currencies, readable = 0, {}, false
                for _, tree in ipairs(trees) do
                    local tab = Call(C_ProfSpecs.GetTabInfo,tree)
                    local currency = Read(tab,"table") and Call(C_ProfSpecs.GetSpendCurrencyForPath,tab.rootNodeID)
                    if Read(currency,"number") and not currencies[currency] then
                        currencies[currency] = true
                        local values = Call(C_Traits and C_Traits.GetTreeCurrencyInfo,config,tree,false)
                        if Read(values,"table") then
                            for _, value in ipairs(values) do
                                if Read(value,"table") and Read(value.traitCurrencyID,"number") and value.traitCurrencyID == currency and Read(value.quantity,"number") then
                                    total,readable = total+value.quantity,true
                                end
                            end
                        end
                    end
                end
                if readable then
                    totals[#totals+1]={name=info.professionName,total=total}
                    local previous = R.knowledge[skill]
                    R.knowledge[skill] = total
                    if (total > 0 and (previous == nil or (not baseline and total > previous))) or (not baseline and previous and total < previous) then
                        local item = Card("retailProfession","knowledge:"..skill,L["PROFESSIONS"],info.professionName,L["%d unspent Knowledge"]:format(total),
                            previous and total < previous and L["Specialization updated"] or L["Choose your next profession specialization"],"Flask",C.gold)
                        item.button={label=L["Open professions"],fn=function() return OpenAddon("Blizzard_ProfessionsBook","ToggleProfessionsBook","ProfessionsBookFrame") end}
                        R.Notify(item,"retailKnowledge")
                    end
                end
            end
        end
    end
    R.KnowledgeBubble(totals)
end

function R.Collection(category,id)
    if not R.ready or R.loading or not Enabled("retailCollections") then return end
    if not Read(id,"number") and not Read(id,"string") then return end
    local name, icon, key
    if category == "mount" then
        name, _, icon = Call(C_MountJournal and C_MountJournal.GetMountInfoByID,id)
        key="mount:"..id
    elseif category == "toy" then
        local _, title, texture = Call(C_ToyBox and C_ToyBox.GetToyInfo,id)
        name,icon,key=title,texture,"toy:"..id
    elseif category == "pet" then
        local species, _, _, _, _, _, _, title, texture = Call(C_PetJournal and C_PetJournal.GetPetInfoByPetID,id)
        if not Read(species,"number") then return end
        local owned = Call(C_PetJournal.GetNumCollectedInfo,species)
        if Read(owned,"number") and owned > 1 then return end
        name,icon,key=title,texture,"pet:"..species
    elseif category == "appearance" then
        local source = Call(C_TransmogCollection and C_TransmogCollection.GetSourceInfo,id)
        if not Read(source,"table") then return end
        local item = Read(source.itemID,"number") and source.itemID or nil
        name, _, _, _, _, _, _, _, _, icon = Call(C_Item and C_Item.GetItemInfo,item)
        if not Read(name,"string") then name=source.name end
        key="appearance:"..(Read(source.visualID,"number") and source.visualID or id)
    end
    if not Read(name,"string") then
        -- Item data can arrive after the unlock event; retry once without marking it seen early.
        if category == "toy" or category == "appearance" then
            local retryKey=category..":"..id
            R.collectionRetry=R.collectionRetry or {}
            if not R.collectionRetry[retryKey] then
                R.collectionRetry[retryKey]=true
                local epoch=R.epoch
                C_Timer.After(.7,function() if R.epoch==epoch then R.Collection(category,id) end end)
            end
        end
        return
    end
    if Seen(key,true) then return end
    local caps={mount=L["MOUNT LEARNED"],pet=L["PET COLLECTED"],toy=L["TOY COLLECTED"],appearance=L["APPEARANCE COLLECTED"]}
    local item = Card("retailCollection",key,caps[category],name,"",L["Added to your collection"],"Star",PURPLE)
    if Read(icon,"number") or Read(icon,"string") then item.icon,item.glyph=icon,nil end
    R.Notify(item,"retailCollections")
end
function R.Decor(guid,id)
    if not R.ready or R.loading or not Enabled("retailHousing") or not Read(id,"number") then return end
    local kind = Enum and Enum.HousingCatalogEntryType and Enum.HousingCatalogEntryType.Decor
    if not Read(kind,"number") then return end
    local info = Call(C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByRecordID,kind,id)
    if not Read(info,"table") or not Read(info.name,"string") then return end
    if Seen("decor:"..id,true) then return end
    local item=Card("retailHousing","decor:"..id,L["DECOR COLLECTED"],info.name,"",L["Added to your housing collection"],"Home",PURPLE)
    local icon=info.iconTexture or info.icon
    if Read(icon,"number") or Read(icon,"string") then item.icon,item.glyph=icon,nil end
    R.Notify(item,"retailHousing")
end

local scheduled = {}
local function Later(key,fn,delay)
    if scheduled[key] then return end
    scheduled[key]=true
    local epoch=R.epoch
    C_Timer.After(delay or .35,function()
        scheduled[key]=nil
        if epoch == R.epoch and R.ready and not R.loading then fn() end
    end)
end
function R.Apply()
    if not ns.db then return end
    if R.QueuePrompt then R.QueuePrompt.Apply() end
    if R.BossLoot then R.BossLoot.Apply() end
    if not Enabled("retailVault") then
        for _,list in ipairs({I.queue or {},I.held or {}}) do
            for i=#list,1,-1 do if list[i].builderType=="retailVault" then table.remove(list,i) end end
        end
    end
    if R.ready then R.Vault(true);R.Knowledge(false);R.Queue() else R.ClearBubbles() end
end

function R.Sample(kind)
    local item
    if kind=="retailRenown" then item=Card(kind,"sample",L["RENOWN INCREASED"],L["A major faction"],L["Renown %d"]:format(12),L["Warband progression"],"Star",BLUE)
    elseif kind=="retailVault" then item=Card(kind,"sample",L["GREAT VAULT"],L["Dungeons"],"3 / 4",L["%d reward slots unlocked"]:format(1),"Chest",C.gold);item.button={label=L["View Great Vault"],fn=function() return true end}
    elseif kind=="retailMythic" then item=Card(kind,"sample",L["MYTHIC+ COMPLETE"],L["Mythic+ dungeon"],"+10 · 24:30",L["Completed in time"],"Door",GREEN)
    elseif kind=="retailDelve" then item=Card(kind,"sample",L["DELVE COMPLETE"],L["A completed Delve"],L["Tier %d"]:format(8),L["Time inside: %s"]:format("12:30"),"Door",PURPLE)
    elseif kind=="retailProfession" then item=Card(kind,"sample",L["PROFESSIONS"],L["Alchemy"],L["%d unspent Knowledge"]:format(6),L["Choose your next profession specialization"],"Flask",C.gold);item.button={label=L["Open professions"],fn=function() return true end}
    elseif kind=="retailCollection" then item=Card(kind,"sample",L["MOUNT LEARNED"],L["A new mount"],"",L["Added to your collection"],"Star",PURPLE)
    elseif kind=="retailHousing" then item=Card(kind,"sample",L["DECOR COLLECTED"],L["A new decoration"],"",L["Added to your housing collection"],"Home",PURPLE)
    elseif kind=="retailBossLoot" then item=R.BossLoot and R.BossLoot.Sample()
    elseif kind=="retailDialogue" then
        item=Card(kind,"sample",L["DIALOGUE"],"Khadgar","12s",L["There is much to do, champion. Our next adventure awaits."],"Speaker",BLUE)
        item.resColor=C.muted;item.progress=function() return .6 end;item.button={label=L["Dismiss"],fn=function() return true end}
    end
    return item
end

local ev=CreateFrame("Frame")
ev:SetScript("OnEvent",function(_,event,a,b,c)
    if event=="PLAYER_ENTERING_WORLD" or event=="LOADING_SCREEN_DISABLED" then
        R.epoch=R.epoch+1;R.ready=false;R.loading=false;R.delve=nil;R.vault={};scheduled={};R.ClearBubbles()
        local epoch=R.epoch
        C_Timer.After(3,function()
            if epoch~=R.epoch or R.loading then return end
            R.ready=true;R.SeedRenown();R.Vault(true);R.Knowledge(true);R.Delve(true);R.Queue()
        end)
    elseif event=="LOADING_SCREEN_ENABLED" then
        R.epoch=R.epoch+1;R.loading=true;R.ready=false;R.ClearBubbles()
    elseif event=="LFG_UPDATE" or event=="LFG_QUEUE_STATUS_UPDATE" or event=="LFG_ROLE_CHECK_UPDATE"
        or event=="LFG_PROPOSAL_UPDATE" or event=="LFG_PROPOSAL_FAILED" or event=="LFG_PROPOSAL_SUCCEEDED" then
        Later("queue",R.Queue)
    elseif event=="MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then R.Renown(a,b,c)
    elseif event=="UPDATE_FACTION" then
        Later("paragon",function()
            local state=R.GetWatchedState({})
            if state and state.standingText:find(L["Paragon reward ready"],1,true) and R.paragonName~=state.name then
                local item=Card("retailRenown","paragonReady",L["REPUTATION"],state.name,L["Reward ready"],nil,"Star",BLUE)
                if R.Notify(item,"retailRenown") then R.paragonName=state.name end
            elseif not state or not state.standingText:find(L["Paragon reward ready"],1,true) then R.paragonName=nil end
        end)
    elseif event=="WEEKLY_REWARDS_UPDATE" or event=="WEEKLY_REWARDS_ITEM_CHANGED" then Later("vault",function() R.Vault(false) end)
    elseif event=="CHALLENGE_MODE_COMPLETED" then
        Later("mythic",R.MythicCompleted,.2);Later("vault",function() R.Vault(false) end,1)
    elseif event=="SCENARIO_UPDATE" or event=="SCENARIO_CRITERIA_UPDATE" or event=="SCENARIO_COMPLETED" or event=="ACTIVE_DELVE_DATA_UPDATE" then
        Later("delve",function() R.Delve(false) end);Later("vault",function() R.Vault(false) end,1)
    elseif event=="TRADE_SKILL_LIST_UPDATE" or event=="TRADE_SKILL_DATA_SOURCE_CHANGED" or event=="TRAIT_CONFIG_UPDATED" or event=="SKILL_LINES_CHANGED" then
        Later("knowledge",function() R.Knowledge(false) end,1)
    elseif event=="CRAFTINGORDERS_DISPLAY_CRAFTER_FULFILLED_MSG" then
        if Read(b,"string") and R.ready then
            local item=Card("retailProfession","craftingOrder",L["CRAFTING ORDER COMPLETE"],b,"",Read(c,"string") and L["For %s"]:format(c) or nil,"Flask",C.gold)
            R.Notify(item,"retailOrders")
        end
    elseif event=="NEW_MOUNT_ADDED" then R.Collection("mount",a)
    elseif event=="NEW_TOY_ADDED" then R.Collection("toy",a)
    elseif event=="NEW_PET_ADDED" then R.Collection("pet",a)
    elseif event=="TRANSMOG_COLLECTION_SOURCE_ADDED" then R.Collection("appearance",a)
    elseif event=="HOUSE_DECOR_ADDED_TO_CHEST" then R.Decor(a,b)
    elseif event=="LFG_PROPOSAL_SHOW" or event=="LFG_ROLE_CHECK_SHOW" then
        Later("queue",R.Queue)
        local role=event=="LFG_ROLE_CHECK_SHOW"
        if not role then return end -- RetailQueue mirrors the proposal as an actionable prompt.
        local item=Card("prompts",role and "retailRoleCheck" or "retailDungeonQueue",role and L["ROLE CHECK"] or L["QUEUE READY"],
            role and L["Choose your dungeon role"] or L["Dungeon Finder is ready"],"",L["Respond in the game's Dungeon Finder window"],"Person",GREEN)
        item.urgent,item.group=true,"social"
        R.Notify(item,"retailQueues")
    elseif event=="ACTIVE_TALENT_GROUP_CHANGED" then
        Later("loadout",function()
            local id=Call(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
            local info=Read(id,"number") and Call(C_Traits and C_Traits.GetConfigInfo,id)
            if Read(info,"table") and Read(info.name,"string") then
                R.Notify(Card("talents","retailLoadout",L["TALENT LOADOUT"],info.name,"",nil,"Plus",BLUE),"retailLoadouts")
            end
        end)
    end
end)
for _,event in ipairs({"PLAYER_ENTERING_WORLD","LOADING_SCREEN_ENABLED","LOADING_SCREEN_DISABLED","MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
    "UPDATE_FACTION","WEEKLY_REWARDS_UPDATE","WEEKLY_REWARDS_ITEM_CHANGED","CHALLENGE_MODE_COMPLETED","SCENARIO_UPDATE","SCENARIO_CRITERIA_UPDATE",
    "SCENARIO_COMPLETED","ACTIVE_DELVE_DATA_UPDATE","TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_DATA_SOURCE_CHANGED","TRAIT_CONFIG_UPDATED","SKILL_LINES_CHANGED",
    "CRAFTINGORDERS_DISPLAY_CRAFTER_FULFILLED_MSG","NEW_MOUNT_ADDED","NEW_TOY_ADDED","NEW_PET_ADDED","TRANSMOG_COLLECTION_SOURCE_ADDED",
    "HOUSE_DECOR_ADDED_TO_CHEST","ACTIVE_TALENT_GROUP_CHANGED","LFG_PROPOSAL_SHOW","LFG_ROLE_CHECK_SHOW",
    "LFG_UPDATE","LFG_QUEUE_STATUS_UPDATE","LFG_ROLE_CHECK_UPDATE","LFG_PROPOSAL_UPDATE","LFG_PROPOSAL_FAILED","LFG_PROPOSAL_SUCCEEDED"}) do pcall(ev.RegisterEvent,ev,event) end
