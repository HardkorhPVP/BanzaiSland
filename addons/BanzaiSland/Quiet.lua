-- Island: keeps the game's own pop-ups and on-screen text quiet for things the island already
-- shows, so the same news does not appear twice. Chat lines are left alone. Each one only goes
-- quiet while its island card is turned on, and the whole thing has one switch: hideBlizzardPopups.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)

local function On() return ns.db and ns.db.hideBlizzardPopups end

-- Hide a frame each time it opens while test() says so. Hooks are added once and stay harmless.
local hooked = {}
local function HideWhile(frame, test)
    if type(frame) ~= "table" or not frame.HookScript or hooked[frame] then return end
    hooked[frame] = true
    frame:HookScript("OnShow", function(self)
        if On() and test() then pcall(self.Hide, self) end
    end)
    if frame.IsShown and frame:IsShown() and On() and test() then pcall(frame.Hide, frame) end
end

-- ---------------------------------------------------------------- Battle.net friend toasts
-- the little box in the corner for "Name has come online" (and Battle.net whispers)
local function FriendToasts()
    HideWhile(_G.BNToastFrame, function() return ns.db.alertFriends or ns.db.showWhispers end)
end

-- ---------------------------------------------------------------- loot and money alerts
-- the game's sliding alert banners for looted items, upgrades, roll wins and money
local ALERT_EVENTS = {
    SHOW_LOOT_TOAST = "toastItems",
    SHOW_LOOT_TOAST_UPGRADE = "toastUpgrades",
    SHOW_LOOT_TOAST_LEGENDARY_LOOTED = "toastItems",
    LOOT_ITEM_ROLL_WON = "showRollWinners",
    BONUS_ROLL_RESULT = "toastItems",
}
local alertsOff = {}           -- only events the game had registered and we switched off
local function LootAlerts()
    local f = _G.AlertFrame
    if type(f) ~= "table" or not f.UnregisterEvent or not f.IsEventRegistered then return end
    for event, key in pairs(ALERT_EVENTS) do
        if On() and ns.db[key] then
            local ok, had = pcall(f.IsEventRegistered, f, event)
            if ok and had then
                pcall(f.UnregisterEvent, f, event)
                alertsOff[event] = true
            end
        elseif alertsOff[event] then
            pcall(f.RegisterEvent, f, event)
            alertsOff[event] = nil
        end
    end
end

-- ---------------------------------------------------------------- level up banner
local levelUntil = 0
local function LevelBanner()
    local test = function() return ns.db.showLevelUp and GetTime() < levelUntil end
    HideWhile(_G.LevelUpDisplay, test)
    HideWhile(_G.EventToastManagerFrame, test)
end

-- ---------------------------------------------------------------- durability figure
-- the little armor figure by the minimap. Made see-through rather than hidden, since some
-- interfaces move it around as part of their layout.
local function Durability()
    local f = _G.DurabilityFrame
    if type(f) ~= "table" or not f.SetAlpha then return end
    local quiet = On() and ns.db.alertDurability
    f:SetAlpha(quiet and 0 or 1)
    if not hooked[f] and f.HookScript then
        hooked[f] = true
        f:HookScript("OnShow", function(self) if On() and ns.db.alertDurability then self:SetAlpha(0) end end)
    end
end

-- ---------------------------------------------------------------- yellow quest progress text
-- "Kobold Vermin slain: 3/8" in the middle of the screen. The game's handler is switched off and
-- every other yellow message is passed straight back to it, so only the progress lines go quiet.
local infoOff = false
local function Readable(v) return ns.Readable(v) and type(v) == "string" end
local function IsProgress(msg)
    if not Readable(msg) then return false end
    if ns.ParseProgress then
        return ns.ParseProgress(msg) ~= nil or ns.IsObjectiveDone(msg)
    end
    return msg:match("^(.-):%s*%d+%s*/%s*%d+$") ~= nil
end

-- "Discovered Goldshire" and "Discovered Goldshire: 45 experience gained", built from the game's
-- own wording so other languages work too
local discover
local function IsDiscovery(msg)
    if not Readable(msg) then return false end
    if not discover then
        discover = {}
        for _, g in ipairs({ "ERR_ZONE_EXPLORED_XP", "ERR_ZONE_EXPLORED" }) do
            local fmt = _G[g]
            if type(fmt) == "string" then
                local pat = fmt:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.-)"):gsub("%%%%d", "%%d+")
                discover[#discover + 1] = "^" .. pat .. "$"
            end
        end
        if #discover == 0 then discover = { "^Discovered .+" } end
    end
    for _, p in ipairs(discover) do
        if msg:match(p) then return true end
    end
    return false
end

-- yellow lines the island already shows as its own cards
local function Covered(msg)
    if ns.db.showQuestProgress and IsProgress(msg) then return true end
    if ns.db.showDiscoveries and IsDiscovery(msg) then return true end
    return false
end

local function QuestText()
    local f = _G.UIErrorsFrame
    if type(f) ~= "table" or not f.UnregisterEvent then return end
    local want = On() and (ns.db.showQuestProgress or ns.db.showDiscoveries)
    if want and not infoOff then
        infoOff = pcall(f.UnregisterEvent, f, "UI_INFO_MESSAGE")
    elseif not want and infoOff then
        pcall(f.RegisterEvent, f, "UI_INFO_MESSAGE")
        infoOff = false
    end
end
-- Lines the island does not cover go to a stand-in frame in the same spot and style as the
-- game's own, since the game's frame may be see-through while the island shows red errors.
local stand
local function Stand()
    if stand then return stand end
    local src = _G.UIErrorsFrame
    stand = CreateFrame("MessageFrame", "BanzaiSlandMessageFrame", UIParent)
    stand:SetSize(512, 60)
    local ok = false
    if type(src) == "table" and src.GetPoint and src:GetNumPoints() > 0 then
        ok = pcall(function()
            for i = 1, src:GetNumPoints() do stand:SetPoint(src:GetPoint(i)) end
            stand:SetSize(src:GetSize())
        end)
    end
    if not ok then stand:ClearAllPoints(); stand:SetPoint("TOP", UIParent, "TOP", 0, -122) end
    stand:SetFrameStrata(type(src) == "table" and src.GetFrameStrata and src:GetFrameStrata() or "DIALOG")
    stand:SetFontObject(ErrorFont or GameFontNormalLarge)
    stand:SetInsertMode("TOP")
    stand:SetTimeVisible(2)
    stand:SetFadeDuration(1.5)
    stand:SetJustifyH("CENTER")
    pcall(stand.EnableMouse, stand, false)
    return stand
end
local function Say(msg, c)
    -- the text may be hidden from addons in combat; it can still be shown
    pcall(Stand().AddMessage, Stand(), msg, c.r, c.g, c.b, 1)
end

local function PassInfoOn(a, b)
    if not infoOff then return end
    local msg = b
    if msg == nil or (Readable(a) and not Readable(b)) then msg = a end
    if Covered(msg) then return end
    Say(msg, YELLOW_FONT_COLOR or { r = 1, g = 1, b = 0 })
end

-- ---------------------------------------------------------------- red error text
-- "Not enough rage", "Out of range", "Inventory is full". Shown in a small red pill under the
-- island instead. The game's frame keeps handling the event, so its voice line ("I need more
-- rage!") still plays exactly as before; the frame is only made see-through. Text the game hides
-- from addons in combat cannot go in the pill, so it shows in the stand-in frame instead.
local errorsOff = false
local function ErrorText()
    local f = _G.UIErrorsFrame
    if type(f) ~= "table" or not f.SetAlpha then return end
    -- older Island versions switched the game's handler off, which also silenced the voice
    pcall(f.RegisterEvent, f, "UI_ERROR_MESSAGE")
    errorsOff = ns.db.showErrors and true or false
    if not hooked[f] then
        hooked[f] = true
        if hooksecurefunc then
            hooksecurefunc(f, "SetAlpha", function(self, a)
                if errorsOff and a and a > 0 then self:SetAlpha(0) end
            end)
            -- anything else written to the game's frame (by other addons) is copied across, so
            -- it is not lost while the frame is see-through. The game's own red errors are
            -- recognised by their message id or colour and left to the island.
            hooksecurefunc(f, "AddMessage", function(_, msg, r, g, b, _, id)
                if not errorsOff then return end
                pcall(function()
                    if id ~= nil then return end
                    if r == 1 and type(g) == "number" and g < 0.15 and type(b) == "number" and b < 0.15 then return end
                    Say(msg, { r = r or 1, g = g or 1, b = b or 1 })
                end)
            end)
        end
    end
    f:SetAlpha(errorsOff and 0 or 1)
end

local function OnError(a, b)
    if not errorsOff then return end
    local msg = b
    if msg == nil then msg = a end                      -- older clients send only the text
    if Readable(msg) and ns.Island and ns.Island.built then
        ns.Island:ShowError(msg)
    else
        Say(msg, RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 })
    end
end

-- ---------------------------------------------------------------- apply

-- ---------------------------------------------------------------- breath, fatigue and feign death
-- the game's timer bars (MirrorTimer1-3, or the container that holds them on newer clients).
-- Made see-through rather than hidden, so the game keeps running them as normal.
local function MirrorBars()
    local quiet = On() and ns.db.liveTimers
    local list = {}
    for i = 1, (MIRRORTIMER_NUMTIMERS or 3) do list[#list + 1] = _G["MirrorTimer" .. i] end
    list[#list + 1] = _G.MirrorTimerContainer
    for _, f in ipairs(list) do
        if type(f) == "table" and f.SetAlpha then
            if not hooked[f] and f.HookScript then
                hooked[f] = true
                f:HookScript("OnShow", function(self) if On() and ns.db.liveTimers then self:SetAlpha(0) end end)
                if hooksecurefunc then
                    hooksecurefunc(f, "SetAlpha", function(self, a)
                        if a and a > 0 and On() and ns.db.liveTimers then self:SetAlpha(0) end
                    end)
                end
            end
            f:SetAlpha(quiet and 0 or 1)
        end
    end
end

function ns.ApplyQuiet()
    if not ns.db then return end
    MirrorBars()
    FriendToasts()
    LootAlerts()
    LevelBanner()
    Durability()
    QuestText()
    ErrorText()
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, a, b)
    if event == "PLAYER_LEVEL_UP" then
        levelUntil = GetTime() + 8
    elseif event == "UI_INFO_MESSAGE" then
        PassInfoOn(a, b)
    elseif event == "UI_ERROR_MESSAGE" then
        OnError(a, b)
    elseif event == "ADDON_LOADED" then
        if ns.db then ns.ApplyQuiet() end
    else
        ns.ApplyQuiet()
    end
end)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "PLAYER_LEVEL_UP", "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE",
                         "UPDATE_INVENTORY_DURABILITY" }) do
    pcall(ev.RegisterEvent, ev, event)
end
