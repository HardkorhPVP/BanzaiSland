-- BanzaiSland: the duplicate-addon guard.
-- BanzaiSland is a GPLv3 fork of Island (Devin / subtlegrind). The two addons watch the same game
-- events, replace the same pop-ups and arm the same hidden game buttons, so running both at once
-- would double every card and could leave either addon's saved settings half-written. When the
-- original Island is installed and enabled for this character, BanzaiSland says so once and does
-- nothing else this session: every module after this file starts with `if ns.Blocked then return end`.
--
-- The check runs while this file loads. Addon folders load in alphabetical order, so "BanzaiSland"
-- loads before "Island" and cannot see Island's globals yet; the addon list (C_AddOns) can be asked
-- about any addon at any time, loaded or not.
local ADDON, ns = ...
local L = ns.L

ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version"))
    or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "1.0.0"

local ORIGINAL = "Island"

-- true when the original Island addon exists and is enabled for this character (or for all characters)
local function OriginalEnabled()
    local C = C_AddOns
    if C and C.DoesAddOnExist then
        local ok, exists = pcall(C.DoesAddOnExist, ORIGINAL)
        if ok and not exists then return false end
    elseif GetAddOnInfo then
        local ok, name = pcall(GetAddOnInfo, ORIGINAL)
        if not ok or not name then return false end
    else
        return false
    end
    local state
    if C and C.GetAddOnEnableState then
        local ok, s = pcall(C.GetAddOnEnableState, ORIGINAL, UnitName and UnitName("player") or nil)
        if ok then state = s end
    elseif GetAddOnEnableState then
        local ok, s = pcall(GetAddOnEnableState, UnitName and UnitName("player") or nil, ORIGINAL)
        if ok then state = s end
    end
    -- Enum.AddOnEnableState: 0 none, 1 some characters, 2 all. "Some" counts: it may be this one.
    if type(state) == "number" then return state > 0 end
    -- no enable state API: fall back to "is it loaded already" (it would not be yet, but be safe)
    local loaded = (C and C.IsAddOnLoaded or IsAddOnLoaded)
    if loaded then
        local ok, is = pcall(loaded, ORIGINAL)
        if ok and is then return true end
    end
    return false
end

ns.Guard = {}
ns.Guard.OriginalEnabled = OriginalEnabled
ns.Guard.WARNING = "BanzaiSland is a fork of Island and cannot run beside it. BanzaiSland stayed off this session: enable only one of the two addons (Island or BanzaiSland) and /reload."

function ns.Guard.Evaluate()
    if OriginalEnabled() then
        ns.Blocked = "island"
    else
        ns.Blocked = nil
    end
    return ns.Blocked
end

ns.Guard.Evaluate()

if ns.Blocked then
    -- say it once the chat frame exists; nothing else of BanzaiSland runs
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        print("|cff9eff1fBanzaiSland|r: " .. L[ns.Guard.WARNING])
    end)
end
