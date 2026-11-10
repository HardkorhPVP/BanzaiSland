-- Island: announce objectives and challenges earned during play, never a login snapshot.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
if not ns.ClientFeature("legacy") then
    ns.ApplyLegacyChallengeProgress = function() end
    ns.DemoLegacyChallenge = function() end
    BanzaiSland_LegacyDebug = function() return { enabled = false, client = ns.Client.kind } end
    return
end
local L, I, C = ns.L, ns.Island, ns.C
local ready, loading, generation = false, false, 0
local completed, objectives = {}, {}
local partialReady, scanning, rescan = false, false, false
local partialIDs, counts = {}, {}
local eventCounts, shownCards = {}, 0
local lastScanError, lastSeedError

local function Readable(v, kind)
    return ns.Readable(v) and type(v) == kind
end

local function Enabled()
    return ns.db and ns.db.showLegacyChallenges ~= false
end

local function ChallengeInfo(id)
    local constants = Constants and Constants.LegacyConsts
    local api = C_Traits
    if not (constants and api and api.GetTraitCurrencyForAchievement and GetAchievementInfo) then return end
    local currencyID = constants.LEGACY_POINTS_TRAIT_CURRENCY_ID
    if not Readable(currencyID, "number") then return end
    local ok, info = pcall(function()
        local points = api.GetTraitCurrencyForAchievement(currencyID, id)
        -- The Legacy UI uses this currency reward in place of achievement points.
        if not Readable(points, "number") or points < 0 then return end
        local _, name, _, _, _, _, _, _, _, icon = GetAchievementInfo(id)
        if not Readable(name, "string") or name == "" then return end
        if not Readable(icon, "number") and not Readable(icon, "string") then icon = nil end
        return { name = name, icon = icon, points = points }
    end)
    if ok then return info end
end

local function OpenChallenge(id)
    if InCombatLockdown and InCombatLockdown() then return false end
    if id == 0 then
        if not LegacySystemFrame then
            local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
            if not load then return false end
            local ok, loaded = pcall(load, "Blizzard_LegacySystem")
            if not ok or not loaded then return false end
        end
        local frame = LegacySystemFrame
        if not (frame and frame.ShowChallenges and frame.IsShown) then return false end
        local ok = pcall(frame.ShowChallenges, frame)
        return ok and frame:IsShown() or false
    end
    if not ShowLegacyChallenge then return false end
    local ok = pcall(ShowLegacyChallenge, id)
    if not ok then return false end
    local frame = LegacySystemFrame
    return frame and frame.IsShown and frame:IsShown() or false
end

local function Card(id, info, objective, preview, progress)
    local done = objective == nil
    local points = info.points
    return {
        kind = "won", key = preview and (done and "legacyChallengePreview" or "legacyObjectivePreview") or "legacyChallenge:" .. id,
        group = "world", catchUpCategory = done and "legacy" or nil, priority = done and 2 or 1, hold = done and 5 or 3.5,
        replay = preview, urgent = preview, builderType = progress and "legacyProgress" or "legacyChallenges", onClick = false,
        icon = info.icon, glyph = "Check", tone = C.gold, capColor = C.gold,
        cap = progress and L["LEGACY PROGRESS"] or (done and L["LEGACY CHALLENGE COMPLETE"] or L["LEGACY OBJECTIVE COMPLETE"]),
        title = info.name, color = C.fg,
        res = progress or (done and (points == 1 and L["%d legacy point"] or L["%d legacy points"]):format(points) or ""),
        resColor = C.gold,
        line = ns.Hex(C.muted[1], C.muted[2], C.muted[3]) .. (objective or L["Challenge completed."]) .. "|r",
        button = { label = L["View challenge"], done = L["Legacy opened"], fn = function() return OpenChallenge(id) end },
    }
end

local function ShowCard(id, info, objective, progress)
    shownCards = shownCards + 1
    local card = Card(id, info, objective, nil, progress)
    -- PushReplace covers the visible card and queue; also replace a card held during combat.
    for index = #I.held, 1, -1 do
        if I.held[index].key == card.key then table.remove(I.held, index) end
    end
    I:PushReplace(card)
end

local function PartialEnabled()
    return Enabled() and ns.db.legacyPartialProgress == true
end

local function EarlierTierUnfinished(id)
    if not GetPreviousAchievement then return false end
    local seen = { [id] = true }
    local cursor = id
    while true do
        local ok, previous = pcall(GetPreviousAchievement, cursor)
        if not ok or not Readable(previous, "number") or previous <= 0 or seen[previous] then return false end
        seen[previous], cursor = true, previous
        if not completed[previous] then
            local success, _, _, _, _, _, _, _, _, _, _, _, _, earned = pcall(GetAchievementInfo, previous)
            if not success or not ns.Readable(earned) or earned ~= true then return true end
        end
    end
end

local function CriterionKey(kind, asset)
    if Readable(kind, "number") and Readable(asset, "number") and asset > 0 then
        return kind .. ":" .. asset
    end
end

local function FirstPartialTiers()
    local first = {}
    -- Some Forever tiers are separate challenges rather than linked achievements.
    -- A single counted objective with the same type and asset is the same goal.
    for _, id in ipairs(partialIDs) do
        if not completed[id] then
            pcall(function()
                local _, _, _, _, _, _, _, _, _, _, _, _, earned = GetAchievementInfo(id)
                if earned ~= nil and (not ns.Readable(earned) or earned == true) then return end
                local n = GetAchievementNumCriteria(id)
                if not Readable(n, "number") or n ~= 1 then return end
                local _, kind, done, have, need, _, _, asset = GetAchievementCriteriaInfo(id, 1)
                local key = CriterionKey(kind, asset)
                if key and (done == nil or Readable(done, "boolean")) and not done
                    and Readable(have, "number") and Readable(need, "number") and need > 0 and have < need then
                    local old = first[key]
                    if not old or need < old.need or (need == old.need and id < old.id) then
                        first[key] = { id = id, need = need }
                    end
                end
            end)
        end
    end
    return first
end

local ScanPartial
ScanPartial = function(announce)
    if scanning then rescan = true return end
    if not ready or loading or not PartialEnabled() then return end
    if not (GetAchievementNumCriteria and GetAchievementCriteriaInfo) then return end
    scanning = true
    local firstTiers = FirstPartialTiers()
    local ticket, index = generation, 1
    local function Batch()
        if ticket ~= generation then return end
        if not ready or loading or not PartialEnabled() then scanning = false return end
        -- Criteria updates have no ID; read a cached challenge list in small batches.
        local last = math.min(index + 19, #partialIDs)
        for at = index, last do
            local id = partialIDs[at]
            if not completed[id] then
                local ok, err = pcall(function()
                    local _, _, _, _, _, _, _, _, _, _, _, _, earnedByMe = GetAchievementInfo(id)
                    -- Unearned challenges can return nil for this optional flag.
                    if earnedByMe ~= nil and (not ns.Readable(earnedByMe) or earnedByMe == true) then return end
                    local info = ChallengeInfo(id)
                    if not info then return end
                    local n = GetAchievementNumCriteria(id)
                    if not Readable(n, "number") then return end
                    local previous = counts[id]
                    if not previous then previous = {} counts[id] = previous end
                    for criterion = 1, n do
                        local description, kind, done, have, need, _, _, asset = GetAchievementCriteriaInfo(id, criterion)
                        if Readable(description, "string") and (done == nil or Readable(done, "boolean"))
                            and Readable(have, "number") and Readable(need, "number") then
                            local old = previous[criterion]
                            previous[criterion] = have
                            -- Completed objectives have their own earned event/card.
                            local key = n == 1 and CriterionKey(kind, asset)
                            local first = key and firstTiers[key]
                            local nextTier = (not first or first.id == id) and not EarlierTierUnfinished(id)
                            if announce and old and have > old and not done and need > 0 and have < need and nextTier then
                                ShowCard(id, info, description, L["%d / %d"]:format(have, need))
                            end
                        end
                    end
                end)
                if not ok then lastScanError = err end
            end
        end
        index = last + 1
        if index <= #partialIDs then
            C_Timer.After(0, Batch)
        else
            scanning, partialReady = false, true
            if rescan then rescan = false ScanPartial(true) end
        end
    end
    Batch()
end

local function SeedPartial()
    partialReady, scanning, rescan = false, false, false
    partialIDs, counts = {}, {}
    if not PartialEnabled() or not (GetCategoryList and GetCategoryNumAchievements and GetAchievementInfo) then return end
    local ok, err = pcall(function()
        local seen = {}
        for _, category in ipairs(GetCategoryList() or {}) do
            local n = GetCategoryNumAchievements(category)
            if Readable(n, "number") then
                for index = 1, n do
                    local id = GetAchievementInfo(category, index)
                    if Readable(id, "number") and not seen[id] then
                        seen[id] = true
                        if ChallengeInfo(id) then partialIDs[#partialIDs + 1] = id end
                    end
                end
            end
        end
    end)
    lastSeedError = not ok and err or nil
    if ok then ScanPartial(false) end
end

-- Read-only diagnostic for a specific challenge; it never seeds or shows a card.
function BanzaiSland_LegacyDebug(id)
    if not Readable(id, "number") then return end
    local cached = false
    for _, candidate in ipairs(partialIDs) do
        if candidate == id then cached = true break end
    end
    local data = {
        version = "2.6.13", id = id, enabled = Enabled(), partialEnabled = PartialEnabled(),
        ready = ready, loading = loading, partialReady = partialReady, scanning = scanning,
        candidateCount = #partialIDs, cached = cached, previous = counts[id],
        events = eventCounts, shownCards = shownCards, queueCount = #I.queue, heldCount = #I.held,
        lastScanError = ns.Readable(lastScanError) and lastScanError or nil,
        lastSeedError = ns.Readable(lastSeedError) and lastSeedError or nil,
        criteria = {},
    }
    local info = ChallengeInfo(id)
    if info then data.name, data.reward = info.name, info.points end
    local ok, err = pcall(function()
        local _, _, _, accountDone, _, _, _, _, _, _, _, _, earnedByMe = GetAchievementInfo(id)
        if ns.Readable(accountDone) then data.accountDone = accountDone end
        if ns.Readable(earnedByMe) then data.earnedByMe = earnedByMe end
        data.earnedFlagReadable = ns.Readable(earnedByMe)
        local category = GetAchievementCategory and GetAchievementCategory(id)
        if Readable(category, "number") then
            data.category = category
            local n = GetCategoryNumAchievements(category)
            if ns.Readable(n) then data.categoryCount = n end
        end
        local n = GetAchievementNumCriteria(id)
        if not Readable(n, "number") then return end
        data.criteriaCount = n
        for index = 1, n do
            local description, _, done, have, need = GetAchievementCriteriaInfo(id, index)
            local criterion = {}
            if ns.Readable(description) then criterion.description = description end
            if ns.Readable(done) then criterion.done = done end
            if ns.Readable(have) then criterion.have = have end
            if ns.Readable(need) then criterion.need = need end
            criterion.readable = Readable(description, "string") and (done == nil or Readable(done, "boolean"))
                and Readable(have, "number") and Readable(need, "number")
            data.criteria[index] = criterion
        end
    end)
    if not ok and ns.Readable(err) then data.readError = err end
    return data
end

function ns.ApplyLegacyChallengeProgress()
    -- Enabling partial cards mid-session also starts with a silent baseline.
    if ready then generation = generation + 1 end
    SeedPartial()
end

function ns.DemoLegacyChallenge(objective)
    if not I.built then return end
    local info = { name = L["A legacy challenge"], points = 2 }
    I:Push(Card(0, info, objective and L["An objective completed."] or nil, true,
        objective == "partial" and L["%d / %d"]:format(3, 10) or nil))
end

local function Arrived()
    generation, ready = generation + 1, false
    local ticket = generation
    -- Ignore the earned-event burst while the client restores character data.
    C_Timer.After(1.5, function()
        if ticket == generation and not loading then ready = true SeedPartial() end
    end)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, id, description)
    eventCounts[event] = (eventCounts[event] or 0) + 1
    if event == "LOADING_SCREEN_ENABLED" then
        loading, ready, generation = true, false, generation + 1
        partialReady, scanning, rescan = false, false, false
        return
    elseif event == "LOADING_SCREEN_DISABLED" then
        loading = false
        Arrived()
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        Arrived()
        return
    elseif event == "RECEIVED_ACHIEVEMENT_LIST" and not partialReady then
        -- Recover an unavailable initial list without discarding an established baseline.
        if ready and not loading and not scanning then SeedPartial() end
        return
    elseif event == "CRITERIA_UPDATE" or event == "SKILL_LINES_CHANGED" or event == "RECEIVED_ACHIEVEMENT_LIST" then
        -- Forever also sends full achievement lists during live profession progress.
        -- Compare them to the existing baseline just like any other update event.
        if ready and partialReady and not loading and PartialEnabled() then
            if not scanning then
                -- Coalesce the many criteria notifications sent by one action.
                scanning = true
                local ticket = generation
                C_Timer.After(0.3, function()
                    if ticket ~= generation then return end
                    scanning = false
                    ScanPartial(true)
                end)
            else
                rescan = true
            end
        end
        return
    end
    if not ready or loading or not I.built or (not Enabled() and not (ns.CatchUp and ns.CatchUp.Wants("legacy"))) or not Readable(id, "number") then return end
    if completed[id] then return end
    local info = ChallengeInfo(id)
    if not info then return end
    if event == "ACHIEVEMENT_EARNED" then
        completed[id] = true
        if ns.CatchUp then ns.CatchUp.Record("legacy", tostring(id), L["Legacy challenge completed"], info.name, {glyph="Check", once=true}) end
        if Enabled() then ShowCard(id, info) end
    elseif event == "CRITERIA_EARNED" then
        if not Readable(description, "string") or description == "" then return end
        local seen = objectives[id]
        if not seen then seen = {} objectives[id] = seen end
        if seen[description] then return end
        seen[description] = true
        local ticket = generation
        -- A final objective often earns the whole challenge in the same event burst.
        C_Timer.After(0.3, function()
            if ticket == generation and ready and not loading and Enabled() and not completed[id] then
                ShowCard(id, info, description)
            end
        end)
    end
end)
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_ENABLED", "LOADING_SCREEN_DISABLED",
                         "ACHIEVEMENT_EARNED", "CRITERIA_EARNED", "CRITERIA_UPDATE", "SKILL_LINES_CHANGED", "RECEIVED_ACHIEVEMENT_LIST" }) do
    pcall(ev.RegisterEvent, ev, event)
end
