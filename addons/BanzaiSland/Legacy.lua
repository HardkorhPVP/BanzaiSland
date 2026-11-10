-- Island: a quiet reminder after arriving in the world, never on every legacy update.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
if not ns.ClientFeature("legacy") then
    ns.ApplyLegacyReminder = function() end
    ns.DemoLegacyReminder = function() end
    return
end
local L, I, C = ns.L, ns.Island, ns.C
local KEY = "unspentLegacy"
local loading, pending, serial = false, false, 0
local shownPoints

local function Points()
    -- Read the trait currency directly: LegacySystem.GetCurrencyInfo caches old counts.
    -- Constants are available before the Legacy window's load-on-demand addon is loaded.
    local constants = Constants and Constants.LegacyConsts
    local treeID = constants and constants.LEGACY_TREE_PROFESSIONS_ID
    local api = C_Traits
    if not (treeID and api and api.GetConfigIDByTreeID and api.GetTreeCurrencyInfo) then return end
    local ok, n = pcall(function()
        local configID = api.GetConfigIDByTreeID(treeID)
        if not ns.Readable(configID) or type(configID) ~= "number" then return end
        local currencies = api.GetTreeCurrencyInfo(configID, treeID, false)
        local info = currencies and currencies[1]
        local quantity = info and info.quantity
        if ns.Readable(quantity) and type(quantity) == "number" and quantity >= 0 then
            return quantity
        end
    end)
    if ok then return n end
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function OpenLegacy()
    if InCombat() then return false end
    if not LegacySystemFrame then
        local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
        if not load then return false end
        local ok, loaded = pcall(load, "Blizzard_LegacySystem")
        if not ok or not loaded then return false end
    end
    local frame = LegacySystemFrame
    if not (frame and frame.SelectPage and frame.IsShown and ShowUIPanel) then return false end
    local ok, opened = pcall(function()
        -- Show rather than toggle so an already-open window stays open.
        if not frame:IsShown() then ShowUIPanel(frame) end
        frame:SelectPage(3) -- Blizzard's Legacy tree page.
        return frame:IsShown()
    end)
    return ok and opened == true
end

local function ClearReminder()
    shownPoints = nil
    -- Loading or spending points must not leave an old count waiting in either queue.
    for _, list in ipairs({ I.queue, I.held }) do
        for i = #list, 1, -1 do
            if list[i].key == KEY then table.remove(list, i) end
        end
    end
    local cur = I.current
    if cur and cur.key == KEY then
        cur.button = nil
        if I.wn and I.wn.btn then I.wn.btn:Hide() end
        cur.dur = math.min(cur.dur or 0, cur.t or 0)
        I.awake = true
    end
end

-- Turning this off also removes a reminder already showing or waiting.
function ns.ApplyLegacyReminder()
    if ns.db and ns.db.legacyReminder == false then
        pending, serial = false, serial + 1
        ClearReminder()
    end
end

local function LegacyCard(n, preview)
    return {
        kind = "won", key = preview and "legacyPreview" or KEY, replay = preview, urgent = preview, group = "world", priority = 1, hold = 6,
        glyph = "Plus", tone = C.gold, cap = L["LEGACY"], capColor = C.gold,
        title = (n == 1 and L["%d unspent legacy point"] or L["%d unspent legacy points"]):format(n),
        color = C.fg, res = "", line = ns.Hex(C.muted[1], C.muted[2], C.muted[3]) .. L["Choose your next legacy upgrade."] .. "|r",
        builderType = "legacy", onClick = false,
        button = { label = n == 1 and L["Spend point"] or L["Spend points"], done = L["Legacy opened"], fn = OpenLegacy },
    }
end

-- A sample uses its own key and never changes the real arrival reminder.
function ns.DemoLegacyReminder()
    if not I.built then return end
    I:Push(LegacyCard(6, true))
end

local function Check(attempt, ticket)
    if ticket ~= serial or not pending or loading then return end
    if ns.db and ns.db.legacyReminder == false then ns.ApplyLegacyReminder() return end
    if InCombat() then return end -- PLAYER_REGEN_ENABLED resumes the same arrival check.
    local n = Points()
    if not I.built or not n or n <= 0 then
        -- Legacy data can arrive after the loading screen has already gone away.
        if attempt < 4 then
            C_Timer.After(1, function() Check(attempt + 1, ticket) end)
        else
            pending = false
        end
        return
    end
    pending = false
    shownPoints = n
    I:Push(LegacyCard(n))
end

local function Schedule()
    if ns.db and ns.db.legacyReminder == false then ns.ApplyLegacyReminder() return end
    serial = serial + 1
    pending = true
    local ticket = serial
    C_Timer.After(1.5, function() Check(1, ticket) end)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "LOADING_SCREEN_ENABLED" then
        loading, pending, serial = true, false, serial + 1
        ClearReminder()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Covers login and /reload too. If a loading screen is still up, wait for it.
        if not loading then ClearReminder() Schedule() end
    elseif event == "LOADING_SCREEN_DISABLED" then
        loading = false
        ClearReminder()
        Schedule()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending and not loading then Schedule() end
    else
        -- These events only retire a stale reminder; they never create a new one.
        local n = Points()
        if n and shownPoints and n ~= shownPoints then ClearReminder() end
    end
end)
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_ENABLED", "LOADING_SCREEN_DISABLED",
                         "PLAYER_REGEN_ENABLED", "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED", "CURRENCY_DISPLAY_UPDATE" }) do
    pcall(ev.RegisterEvent, ev, event)
end
