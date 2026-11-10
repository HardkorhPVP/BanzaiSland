-- Island: a quiet reminder after arriving in the world, never on every talent update.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L, I, C = ns.L, ns.Island, ns.C
local KEY = "unspentTalents"
local loading, pending, serial = false, false, 0
local shownPoints

local function Points()
    -- Forever uses the modern talent API; the old globals may be absent or report zero.
    local api = C_ClassTalents
    if api and api.HasUnspentTalentPoints then
        local ok, hasPoints, classPoints, specPoints = pcall(api.HasUnspentTalentPoints)
        if ok and ns.Readable(hasPoints) and type(hasPoints) == "boolean"
            and ns.Readable(classPoints) and type(classPoints) == "number"
            and ns.Readable(specPoints) and type(specPoints) == "number"
            and classPoints >= 0 and specPoints >= 0 then
            return classPoints + specPoints
        end
    end
    if GetUnspentTalentPoints then
        local ok, n = pcall(GetUnspentTalentPoints)
        if ok and ns.Readable(n) and type(n) == "number" then return n end
    end
    -- Classic clients expose the player's available points here instead.
    if UnitCharacterPoints then
        local ok, n = pcall(UnitCharacterPoints, "player")
        if ok and ns.Readable(n) and type(n) == "number" then return n end
    end
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function OpenTalents()
    if InCombat() then return false end
    -- Forever uses the combined spells/talents window on newer builds.
    local function OpenModern()
        local api = PlayerSpellsUtil
        if not (api and api.ToggleClassTalentFrame) then return false end
        local f = PlayerSpellsFrame
        if f and f.IsShown and f:IsShown() and f.TalentsFrame
            and f.TalentsFrame.IsShown and f.TalentsFrame:IsShown() then return true end
        local ok, result = pcall(api.ToggleClassTalentFrame)
        return ok and result ~= false
    end
    if OpenModern() then return true end
    local frame = PlayerTalentFrame or TalentFrame
    if frame and frame.IsShown and frame:IsShown() then return true end
    if ToggleTalentFrame then
        local ok, result = pcall(ToggleTalentFrame)
        if ok and result ~= false then return true end
    end
    -- The modern utility may not exist until its load-on-demand addon is loaded.
    local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if load then
        local ok, loaded = pcall(load, "Blizzard_PlayerSpells")
        if ok and loaded and OpenModern() then return true end
    end
    return false
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
function ns.ApplyTalentReminder()
    if ns.db and ns.db.talentReminder == false then
        pending, serial = false, serial + 1
        ClearReminder()
    end
end

local function TalentCard(n, preview)
    return {
        kind = "won", key = preview and "talentPreview" or KEY, replay = preview, urgent = preview, group = "world", priority = 1, hold = 6,
        glyph = "Plus", tone = C.gold, cap = L["TALENTS"], capColor = C.gold,
        title = (n == 1 and L["%d unspent talent point"] or L["%d unspent talent points"]):format(n),
        color = C.fg, res = "", line = ns.Hex(C.muted[1], C.muted[2], C.muted[3]) .. L["Choose your next talent."] .. "|r",
        builderType = "talents", onClick = false,
        button = { label = n == 1 and L["Spend point"] or L["Spend points"], done = L["Talents opened"], fn = OpenTalents },
    }
end

-- A sample uses its own key and never changes the real arrival reminder.
function ns.DemoTalentReminder()
    if not I.built then return end
    I:Push(TalentCard(1, true))
end

local function Check(attempt, ticket)
    if ticket ~= serial or not pending or loading then return end
    if ns.db and ns.db.talentReminder == false then ns.ApplyTalentReminder() return end
    if InCombat() then return end -- PLAYER_REGEN_ENABLED resumes the same arrival check.
    local n = Points()
    if not I.built or not n or n <= 0 then
        -- Talent data can arrive after the loading screen has already gone away.
        if attempt < 4 then
            C_Timer.After(1, function() Check(attempt + 1, ticket) end)
        else
            pending = false
        end
        return
    end
    pending = false
    shownPoints = n
    I:Push(TalentCard(n))
end

local function Schedule()
    if ns.db and ns.db.talentReminder == false then ns.ApplyTalentReminder() return end
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
                         "PLAYER_REGEN_ENABLED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED" }) do
    pcall(ev.RegisterEvent, ev, event)
end
