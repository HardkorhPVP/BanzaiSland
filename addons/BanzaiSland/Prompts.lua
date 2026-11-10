-- Island: cards that wait for an answer. Ready checks, party invites, duels, resurrections, summons.
-- The game's own dialogs stay up as well; answering in either place closes both.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local I, C = ns.Island, ns.C

local GREEN = { 0.36, 0.85, 0.45 }
local RED = { 0.95, 0.38, 0.38 }
local BLUE = { 0.40, 0.72, 1.00 }
local PURPLE = { 0.72, 0.52, 1.00 }
local GOLD = C.gold
local ORANGE_BIND = { 0.98, 0.66, 0.28 }
local MUTED_HEX = ns.Hex(C.muted[1], C.muted[2], C.muted[3])
local GREEN_HEX, RED_HEX = ns.Hex(GREEN[1], GREEN[2], GREEN[3]), ns.Hex(RED[1], RED[2], RED[3])
local SOUND_PROMPT = 8960      -- ready check

local function HidePopup(...)
    if not StaticPopup_Hide then return end
    for i = 1, select("#", ...) do StaticPopup_Hide((select(i, ...))) end
end

-- ---------------------------------------------------------------- ready check

local rc = { active = false, ready = {}, notReady = {}, total = 0 }

local function GroupSize()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    return n > 0 and n or 1
end

local function TallyLine()
    local ready, notReady = 0, 0
    for _ in pairs(rc.ready) do ready = ready + 1 end
    for _ in pairs(rc.notReady) do notReady = notReady + 1 end
    local waiting = math.max(0, rc.total - ready - notReady)
    local parts = { GREEN_HEX .. L["%d ready"]:format(ready) .. "|r" }
    if notReady > 0 then parts[#parts + 1] = RED_HEX .. L["%d not ready"]:format(notReady) .. "|r" end
    if waiting > 0 then parts[#parts + 1] = MUTED_HEX .. L["%d waiting"]:format(waiting) .. "|r" end
    return table.concat(parts, "   "), ready, notReady, waiting
end

local function ReadyCheckStart(initiator, seconds)
    if not ns.db.promptReady then return end
    rc.active, rc.ready, rc.notReady, rc.total = true, {}, {}, GroupSize()
    local me = UnitName("player")
    local mine = ns.FirstName(initiator) == me
    if initiator then rc.ready[ns.UnitShowName("player") and mine and ns.UnitShowName("player") or ns.ShowName(initiator)] = true end
    local buttons
    if mine then
        buttons = { { label = L["Dismiss"], muted = true } }
    else
        buttons = {
            { label = L["Ready"], done = L["Ready"], fn = function()
                if ConfirmReadyCheck then ConfirmReadyCheck(true) end
                if ReadyCheckFrame then ReadyCheckFrame:Hide() end
                if me then rc.ready[me] = true end
            end },
            { label = L["Not ready"], done = L["Not ready"], muted = true, fn = function()
                if ConfirmReadyCheck then ConfirmReadyCheck(false) end
                if ReadyCheckFrame then ReadyCheckFrame:Hide() end
                if me then rc.notReady[me] = true end
            end },
        }
    end
    I:AddPrompt({
        id = "readycheck", glyph = "Check", tone = GOLD, cap = L["READY CHECK"],
        name = mine and L["You started a ready check"] or L["%s asks if you are ready"]:format(initiator or L["Someone"]),
        line = TallyLine(), seconds = (type(seconds) == "number" and seconds > 0) and seconds or 30,
        buttons = buttons, sound = SOUND_PROMPT,
    })
end

local function ReadyCheckConfirm(unit, isReady)
    if not rc.active then return end
    local name = unit and ns.UnitShowName(unit)
    if not name then return end
    rc.ready[name], rc.notReady[name] = nil, nil
    if isReady then rc.ready[name] = true else rc.notReady[name] = true end
    I:UpdatePrompt("readycheck", (TallyLine()))
end

local function ReadyCheckFinished()
    if not rc.active then return end
    rc.active = false
    I:RemoveRoll("readycheck", true)
    if not ns.db.promptReady then return end
    local _, ready, notReady, waiting = TallyLine()
    local missing = notReady + waiting
    local names = {}
    for name in pairs(rc.notReady) do names[#names + 1] = name end
    table.sort(names)
    local line
    if #names > 0 then line = MUTED_HEX .. L["Not ready:"] .. " |r" .. RED_HEX .. table.concat(names, ", ") .. "|r" end
    I:Push({
        kind = "won", urgent = true, glyph = "Check", tone = missing == 0 and GREEN or RED, cap = L["READY CHECK"],
        capColor = missing == 0 and GREEN or RED, color = C.fg,
        title = missing == 0 and L["Everyone is ready"] or (missing == 1 and L["%d player is not ready"] or L["%d players are not ready"]):format(missing),
        res = ready .. " / " .. rc.total, line = line, hold = 3.4, priority = 3,
    })
end

-- ---------------------------------------------------------------- requests

local function Request(id, glyph, tone, cap, name, line, seconds, accept, decline, acceptLabel, onRemoved)
    if not ns.db.promptRequests then return end
    I:AddPrompt({
        id = id, glyph = glyph, tone = tone, cap = cap, name = name, line = line, seconds = seconds,
        sound = SOUND_PROMPT, onRemoved = onRemoved,
        buttons = {
            { label = acceptLabel or L["Accept"], done = L["Accepted"], fn = accept },
            { label = L["Decline"], done = L["Declined"], muted = true, fn = decline },
        },
    })
end

-- The game's own dialog for a request is kept alive (it still does the accepting) but made
-- invisible and moved off screen, so only the island card shows. If the card goes away without
-- an answer, the dialog comes back.
local suppressed, hookedHide = {}, {}

-- where a frame sat before it was moved off screen, so it can go back exactly there
local savedPoints = {}
local function SavePoints(frame)
    if savedPoints[frame] or not frame.GetNumPoints then return end
    local pts = {}
    for i = 1, (frame:GetNumPoints() or 0) do pts[i] = { frame:GetPoint(i) } end
    savedPoints[frame] = pts
end
local savedScale = {}
local function PutBack(frame)
    local pts = savedPoints[frame]
    savedPoints[frame] = nil
    frame:SetAlpha(1)
    -- also shrunk while hidden, so a skin that keeps its own pieces in view (or moves the window back) shows nothing
    if savedScale[frame] and frame.SetScale then frame:SetScale(savedScale[frame]) end
    savedScale[frame] = nil
    if not pts or #pts == 0 then return end
    frame:ClearAllPoints()
    for _, p in ipairs(pts) do pcall(frame.SetPoint, frame, unpack(p)) end
end

local function Suppress(frame)
    if type(frame) ~= "table" or not frame.SetAlpha or suppressed[frame] then return end
    suppressed[frame] = true
    if not hookedHide[frame] and frame.HookScript then
        hookedHide[frame] = true
        frame:HookScript("OnHide", function(self)
            if suppressed[self] then
                suppressed[self] = nil
                PutBack(self)
            end
        end)
    end
    SavePoints(frame)
    frame:SetAlpha(0)
    if frame.SetScale and frame.GetScale and not savedScale[frame] then
        savedScale[frame] = frame:GetScale() or 1
        frame:SetScale(0.001)
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "BOTTOM", 0, -400)
end

local function Restore()
    for frame in pairs(suppressed) do
        suppressed[frame] = nil
        PutBack(frame)
    end
end

local function SuppressPopups(...)
    local names = { ... }
    local function go()
        for _, which in ipairs(names) do
            if which == "LFGInvitePopup" then
                local f = _G.LFGInvitePopup
                if f and f.IsShown and f:IsShown() then Suppress(f) end
            elseif StaticPopup_FindVisible then
                Suppress(StaticPopup_FindVisible(which))
            end
        end
    end
    -- the game may open its dialog just before or just after this event reaches the addon
    go()
    C_Timer.After(0.05, go)
    C_Timer.After(0.4, go)
end

local ROLE_BUTTONS = { tank = "LFGInvitePopupRoleButtonTank", healer = "LFGInvitePopupRoleButtonHealer", damage = "LFGInvitePopupRoleButtonDPS" }

local function RoleCheck(key)
    local b = _G[ROLE_BUTTONS[key]]
    return type(b) == "table" and b.checkButton or nil
end

-- Accept through the game's own role dialog when it is up, so the roles are applied its way.
local function AcceptInvite(roles)
    local popup = _G.LFGInvitePopup
    if roles and popup and popup.IsShown and popup:IsShown() then
        for _, role in ipairs(roles) do
            local cb = RoleCheck(role.key)
            if cb and cb.GetChecked and cb.Click and (cb:GetChecked() and true or false) ~= (role.on and true or false) then
                cb:Click()
            end
        end
        local accept = _G.LFGInvitePopupAcceptButton
        if accept and accept.Click and (not accept.IsEnabled or accept:IsEnabled()) then
            accept:Click()
            return
        end
    end
    if AcceptGroup then AcceptGroup() end
    HidePopup("PARTY_INVITE")
    if popup and StaticPopupSpecial_Hide then StaticPopupSpecial_Hide(popup) end
end

local function DeclineInvite()
    local popup = _G.LFGInvitePopup
    local decline = _G.LFGInvitePopupDeclineButton
    if popup and popup.IsShown and popup:IsShown() and decline and decline.Click then
        decline:Click()
        return
    end
    if DeclineGroup then DeclineGroup() end
    HidePopup("PARTY_INVITE")
    if popup and StaticPopupSpecial_Hide then StaticPopupSpecial_Hide(popup) end
end

local BLUE_ROLE, GREEN_ROLE, RED_ROLE = { 0.35, 0.62, 1.00 }, { 0.36, 0.85, 0.45 }, { 0.95, 0.38, 0.38 }

local function OnInvite(name, isTank, isHealer, isDamage, _, allowMultiple)
    if not ns.db.promptRequests then return end
    local roles
    if isTank or isHealer or isDamage then
        roles = {}
        if isTank then roles[#roles + 1] = { key = "tank", label = L["Tank"], tone = BLUE_ROLE } end
        if isHealer then roles[#roles + 1] = { key = "healer", label = L["Healer"], tone = GREEN_ROLE } end
        if isDamage then roles[#roles + 1] = { key = "damage", label = L["Damage"], tone = RED_ROLE } end
        if #roles == 1 then roles[1].on = true end
    end
    local accept = { label = L["Accept"], done = L["Accepted"], fn = function() AcceptInvite(roles) end }
    local function sync()
        local any = not roles
        for _, role in ipairs(roles or {}) do if role.on then any = true end end
        accept.enabled = any
        accept.label = any and L["Accept"] or L["Pick a role"]
    end
    sync()
    I:AddPrompt({
        id = "invite", glyph = "Person", tone = GREEN, cap = L["PARTY INVITE"], name = ns.ShowName(name) or L["Someone"], seconds = 60,
        sound = SOUND_PROMPT, roles = roles, multiRole = allowMultiple and true or false,
        onRoles = sync, onRemoved = Restore,
        buttons = { accept, { label = L["Decline"], done = L["Declined"], muted = true, fn = DeclineInvite } },
    })
    SuppressPopups("PARTY_INVITE", "LFGInvitePopup")
    -- start from whatever the game ticked by default (usually the role of your spec)
    if roles then
        C_Timer.After(0.1, function()
            local changed = false
            for _, role in ipairs(roles) do
                local cb = RoleCheck(role.key)
                if cb and cb.GetChecked and cb:GetChecked() and not role.on then role.on, changed = true, true end
            end
            if changed then
                if not allowMultiple then
                    local first
                    for _, role in ipairs(roles) do
                        if role.on and not first then first = role elseif role.on then role.on = false end
                    end
                end
                sync()
                I:UpdatePrompt("invite", nil)
            end
        end)
    end
end

local function OnDuel(name)
    if not ns.db.promptRequests then return end
    I:AddPrompt({
        id = "duel", glyph = "Flag", tone = RED, cap = L["DUEL REQUEST"], name = ns.ShowName(name) or L["Someone"], seconds = 60,
        sound = SOUND_PROMPT, onRemoved = Restore,
        buttons = {
            { label = L["Accept"], done = L["Accepted"], fn = function() if AcceptDuel then AcceptDuel() end HidePopup("DUEL_REQUESTED") end },
            { label = L["Decline"], done = L["Declined"], muted = true, fn = function() if CancelDuel then CancelDuel() end HidePopup("DUEL_REQUESTED") end },
        },
    })
    SuppressPopups("DUEL_REQUESTED")
end

-- guild invites: the game's own window (a dialog on older clients, GuildInviteFrame on newer ones)
-- stays out of sight while the card is up
-- (closing the window declines unless it is marked accepted, as the game's own Join button does)
local function HideGuildInvite(accepted)
    HidePopup("GUILD_INVITE")
    local f = _G.GuildInviteFrame
    if f and f.IsShown and f:IsShown() then
        if accepted then f.accepted = true end
        f:Hide()
    end
end

-- In gamepad mode the game gives GuildInviteFrame the controller (A joins, everything else is
-- blocked), so a hidden window would hold the controller; leave it in view there.
local function GamepadUI()
    local util = _G.InputUtil
    if not (util and util.IsGamepadUIEnabled) then return false end
    local ok, on = pcall(util.IsGamepadUIEnabled)
    return ok and on == true
end

local function OnGuildInvite(inviter, guild)
    if not ns.db.promptRequests then return end
    local who = (type(inviter) == "string" and ns.Readable(inviter) and inviter ~= "") and ns.ShowName(inviter) or L["Someone"]
    local name = (type(guild) == "string" and ns.Readable(guild) and guild ~= "") and guild or nil
    I:AddPrompt({
        id = "guild", glyph = "Shield", tone = GOLD, cap = L["GUILD INVITE"],
        name = name and ("<" .. name .. ">") or L["%s invites you to a guild"]:format(who),
        line = name and (MUTED_HEX .. L["Invited by %s"]:format(who) .. "|r") or nil,
        seconds = 60, sound = SOUND_PROMPT, onRemoved = Restore,
        buttons = {
            { label = L["Join"], done = L["Joined"], fn = function() if AcceptGuild then AcceptGuild() end HideGuildInvite(true) end },
            { label = L["Decline"], done = L["Declined"], muted = true, fn = function() if DeclineGuild then DeclineGuild() end HideGuildInvite() end },
        },
    })
    SuppressPopups("GUILD_INVITE")
    local function frame()
        local f = _G.GuildInviteFrame
        if f and f.IsShown and f:IsShown() and not GamepadUI() then Suppress(f) end
    end
    frame() C_Timer.After(0.05, frame) C_Timer.After(0.4, frame)
end

-- ---------------------------------------------------------------- death
-- Dead: a card with Release Spirit (and a soulstone or Reincarnation when you have one).
-- As a ghost: Return to Graveyard. Back at your body: Resurrect, once the game allows it.
local GREY = { 0.70, 0.73, 0.80 }

local function GhostFrame() return _G.GhostFrame end

-- Soulstone and Reincarnation share the client's self-resurrection option list.
local function SelfResOptions()
    local api = C_DeathInfo
    if api and api.GetSelfResurrectOptions and api.UseSelfResurrectOption then
        local ok, options = pcall(api.GetSelfResurrectOptions)
        if ok and type(options) == "nil" then return {} end
        if ok and ns.Readable(options) and type(options) == "table" then
            local result = {}
            for _, option in ipairs(options) do
                if ns.Readable(option) and type(option) == "table"
                    and ns.Readable(option.canUse) and (option.canUse == true or option.canUse == 1)
                    and ns.Readable(option.name) and type(option.name) == "string" and option.name ~= ""
                    and ns.Readable(option.optionType) and type(option.optionType) == "number"
                    and ns.Readable(option.id) and type(option.id) == "number" then
                    result[#result+1] = { name = option.name, optionType = option.optionType, id = option.id }
                end
            end
            return result
        end
    end
    local ok, name = pcall(function() return HasSoulstone and HasSoulstone() end)
    if ok and ns.Readable(name) and type(name) == "string" and name ~= "" and UseSoulstone then
        return { { name = name, legacy = true } }
    end
    return {}
end

local function StillDead()
    if not UnitIsDead then return false end
    local ok, value = pcall(UnitIsDead, "player")
    return ok and ns.Readable(value) and (value == true or value == 1)
end

local function OnDead()
    if not ns.db.promptDeath or not StillDead() then return end
    local options = SelfResOptions()
    local hasSelfRes = #options > 0
    local id = hasSelfRes and "selfres" or "death"
    local signature = id
    for _, option in ipairs(options) do signature = signature .. ":" .. option.name .. ":" .. tostring(option.optionType) .. ":" .. tostring(option.id) end
    for _, roll in ipairs(I.rolls or {}) do
        if roll.id == id and roll.selfResSignature == signature then return end
    end
    I:RemoveRoll(hasSelfRes and "death" or "selfres", true)
    local buttons = {}
    -- Leave the final slot for Release; the normal card renderer has three buttons.
    for index = 1, math.min(2, #options) do
        local choice = options[index]
        buttons[#buttons+1] = { label = choice.name, done = choice.name, keep = true, fn = function()
            if not StillDead() then return end
            -- Recheck at click time: a cooldown or aura may have changed since the card opened.
            for _, current in ipairs(SelfResOptions()) do
                if current.name == choice.name and current.id == choice.id and current.optionType == choice.optionType then
                    local ok
                    if current.legacy then ok = pcall(UseSoulstone)
                    else ok = pcall(C_DeathInfo.UseSelfResurrectOption, current.optionType, current.id) end
                    if not ok then Restore() end
                    return
                end
            end
            Restore()
        end }
    end
    buttons[#buttons+1] = { label = L["Release spirit"], done = L["Released"], muted = hasSelfRes, keep = true,
        fn = function()
            if not StillDead() then return end
            local ok = RepopMe and pcall(RepopMe)
            if ok then HidePopup("DEATH") else Restore() end
        end }
    local ok, left = pcall(function() return GetReleaseTimeRemaining and GetReleaseTimeRemaining() end)
    I:AddPrompt({
        id = id, front = hasSelfRes, selfResSignature = signature, glyph = "Plus", tone = hasSelfRes and GREEN or RED,
        cap = hasSelfRes and L["RESURRECTION"] or L["YOU DIED"],
        name = hasSelfRes and L["You can resurrect yourself"] or L["Release your spirit to the graveyard"],
        seconds = (ok and ns.Readable(left) and type(left) == "number" and left > 0 and left < 3600) and left or 360,
        onRemoved = Restore, buttons = buttons,
    })
    SuppressPopups("DEATH")
end

-- Availability can arrive after PLAYER_DEAD or change without another death event.
local deathWatch = CreateFrame("Frame")
local deathElapsed = 0
deathWatch:SetScript("OnUpdate", function(_, dt)
    deathElapsed = deathElapsed + dt
    if deathElapsed < 0.5 then return end
    deathElapsed = 0
    if ns.db and ns.db.promptDeath and StillDead() then
        for _, roll in ipairs(I.rolls or {}) do
            if (roll.id == "death" or roll.id == "selfres") and not roll.answerT then OnDead() break end
        end
    end
end)

local function OnGhost()
    if not ns.db.promptDeath then return end
    if not (UnitIsGhost and UnitIsGhost("player")) then return end
    I:AddPrompt({
        id = "ghost", glyph = "Home", tone = GREY, cap = L["GHOST"], name = L["Run back to your body"],
        seconds = 20, onRemoved = Restore,
        buttons = {
            { label = L["Return to graveyard"], done = L["Returning"], fn = function() if PortGraveyard then PortGraveyard() end end },
            { label = L["Dismiss"], done = L["Dismissed"], muted = true, fn = function() end },
        },
    })
    local function frame()
        local f = GhostFrame()
        if f and f.IsShown and f:IsShown() then Suppress(f) end
    end
    frame() C_Timer.After(0.1, frame) C_Timer.After(0.5, frame)
end

local function OnCorpseInRange()
    if not ns.db.promptDeath then return end
    if not (UnitIsGhost and UnitIsGhost("player")) then return end
    I:RemoveRoll("ghost", true)
    local delay = GetCorpseRecoveryDelay and GetCorpseRecoveryDelay() or 0
    local res = { label = L["Resurrect"], done = L["Resurrected"], fn = function()
        if RetrieveCorpse then RetrieveCorpse() end
        HidePopup("RECOVER_CORPSE")
    end }
    if delay > 0 then
        res.enabled, res.label = false, L["Resurrect in %ds"]:format(math.ceil(delay))
        local function tick()
            local d = GetCorpseRecoveryDelay and GetCorpseRecoveryDelay() or 0
            if d > 0 then
                res.label = L["Resurrect in %ds"]:format(math.ceil(d))
                I:UpdatePrompt("corpse", nil)
                C_Timer.After(1, tick)
            else
                res.enabled, res.label = true, L["Resurrect"]
                I:UpdatePrompt("corpse", nil)
            end
        end
        C_Timer.After(1, tick)
    end
    I:AddPrompt({
        id = "corpse", glyph = "Plus", tone = GREEN, cap = L["YOUR BODY"], name = L["You are next to your body"],
        seconds = 120, noTimer = true, onRemoved = Restore, sound = SOUND_PROMPT,
        buttons = { res },
    })
    SuppressPopups("RECOVER_CORPSE")
end

local function BackToLife()
    for _, id in ipairs({ "death", "selfres", "ghost", "corpse" }) do I:RemoveRoll(id, true) end
end

-- ---------------------------------------------------------------- buttons only the game may press
-- Some answers (entering a battleground) can only be given by the game's own button. For those, an
-- invisible secure button sits over the card's button and presses the game's (hidden) one. Secure
-- buttons cannot be changed during combat, so going into combat takes them away and brings the
-- game's window back; they return once combat ends.
local overlays = {}

-- A secure button anchored to the card makes the whole island "protected" in combat, so even
-- resizing it is blocked. Unused overlays are therefore unhooked from the card, not just hidden.
local function Park(o)
    o:Hide()
    o:ClearAllPoints()
    o.over = nil
    if ClearOverrideBindings and not (InCombatLockdown and InCombatLockdown()) then ClearOverrideBindings(o) end
end

-- While a button only the game may press is on the card, the card keys (Key Bindings > Island)
-- press its secure overlay, so they work for it too. Bound out of combat only, like the overlays.
local function BindKeys(o, commands)
    if not (SetOverrideBindingClick and GetBindingKey) then return end
    ClearOverrideBindings(o)
    for _, cmd in ipairs(commands) do
        for _, key in ipairs({ GetBindingKey(cmd) }) do
            if key then SetOverrideBindingClick(o, true, key, o:GetName(), "LeftButton") end
        end
    end
end

-- placed by screen position over the card's button, never attached to it
local function Place(o)
    local b = o.over
    if not b then return end
    local l, bt, w, h = b:GetLeft(), b:GetBottom(), b:GetWidth(), b:GetHeight()
    if not (l and bt) then return end
    local k = b:GetEffectiveScale() / o:GetEffectiveScale()
    o:ClearAllPoints()
    o:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * k, bt * k)
    o:SetSize(w * k, h * k)
end

-- the card springs open and moves, so armed overlays follow their buttons until combat
local follow = CreateFrame("Frame")
follow:SetScript("OnUpdate", function()
    if InCombatLockdown and InCombatLockdown() then return end
    for _, o in pairs(overlays) do
        if o.over and o:IsShown() then Place(o) end
    end
end)

local function Overlay(i)
    if overlays[i] then return overlays[i] end
    local o = CreateFrame("Button", "BanzaiSlandSecureButton" .. i, UIParent, "SecureActionButtonTemplate")
    o:RegisterForClicks("AnyUp", "AnyDown")
    o:SetAttribute("type", "click")
    o.i = i
    o:SetScript("PostClick", function(self)
        local b = I.rl and I.rl.buttons[self.i]
        if b and b.spec then I:AnswerRoll(b.spec) end
    end)
    o:SetScript("OnEnter", function(self)
        local b = I.rl and I.rl.buttons[self.i]
        if b then b.bg:SetRole(b.role, true, b.spec and b.spec.muted) end
    end)
    o:SetScript("OnLeave", function(self)
        local b = I.rl and I.rl.buttons[self.i]
        if b then b.bg:SetRole(b.role, false, b.spec and b.spec.muted) end
    end)
    o:Hide()
    overlays[i] = o
    return o
end

function I:DisarmSecure()
    if InCombatLockdown and InCombatLockdown() then return end
    for _, o in pairs(overlays) do Park(o) end
end

function I:ArmSecure()
    if InCombatLockdown and InCombatLockdown() then return end
    local roll = self.rolls[1]
    local last = 0
    for i, b in ipairs(self.rl.buttons) do
        if roll and b:IsShown() and b.spec then last = i end
    end
    for i, b in ipairs(self.rl.buttons) do
        local spec = roll and b:IsShown() and b.spec
        local target = spec and spec.secure and spec.secure()
        if target then
            local o = Overlay(i)
            o:SetAttribute("clickbutton", target)
            o.over = b
            Place(o)
            local okS, strata = pcall(b.GetFrameStrata, b)
            if not okS or type(strata) ~= "string" or not ns.Readable(strata) then strata = "DIALOG" end
            o:SetFrameStrata(strata)
            o:SetFrameLevel(b:GetFrameLevel() + 5)
            o:Show()
            spec.armed = true
            BindKeys(o, (i == last) and { "BANZAISLAND_CARD" .. i, "BANZAISLAND_CARDLAST" } or { "BANZAISLAND_CARD" .. i })
        else
            if spec then spec.armed = nil end
            if overlays[i] then Park(overlays[i]) end
        end
    end
end

local function TopHasSecure()
    local roll = I.rolls and I.rolls[1]
    if not (roll and roll.buttons) then return false end
    for _, spec in ipairs(roll.buttons) do if spec.secure then return true end end
    return false
end

-- ---------------------------------------------------------------- battleground ready

local function ButtonOf(dialog, n)
    if not dialog then return nil end
    local b = dialog["button" .. n]
    if not b and dialog.ButtonContainer then b = dialog.ButtonContainer["Button" .. n] end
    if not b and dialog.GetName and dialog:GetName() then b = _G[dialog:GetName() .. "Button" .. n] end
    return b
end

-- Shared with confirmation cards; restore only the dialog that belongs to that card.
ns.PopupCard = {
    Button = ButtonOf, Hide = Suppress,
    Restore = function(frame)
        if suppressed[frame] then
            suppressed[frame] = nil
            PutBack(frame)
        end
    end,
}

-- the game's "enter battleground" window and its Enter and Leave Queue buttons
local function BGWindow()
    local d = StaticPopup_FindVisible and StaticPopup_FindVisible("CONFIRM_BATTLEFIELD_ENTRY")
    if d then return d, ButtonOf(d, 1), ButtonOf(d, 2) end
    local p = _G.PVPReadyDialog
    if p and p.IsShown and p:IsShown() then return p, p.enterButton, p.leaveButton end
end

local bgUp = {}

local function HideBGWindow()
    if InCombatLockdown and InCombatLockdown() then return end
    local d = BGWindow()
    if d and I.rolls[1] and tostring(I.rolls[1].id):find("^bg") then Suppress(d) end
end

local function BGPrompt(i, map)
    local left = GetBattlefieldPortExpiration and GetBattlefieldPortExpiration(i) or 0
    if type(left) ~= "number" or left <= 0 then left = 90 elseif left > 1000 then left = left / 1000 end
    local enter, leave
    enter = { label = L["Enter"], done = L["Entering"], secure = function() local _, b = BGWindow() return b end,
              fn = function() if not enter.armed then Restore() end end }
    leave = { label = L["Leave queue"], done = L["Left queue"], muted = true, secure = function() local _, _, b = BGWindow() return b end,
              fn = function() if not leave.armed then Restore() end end }
    I:AddPrompt({
        id = "bg" .. i, glyph = "Flag", tone = GOLD, cap = L["BATTLEGROUND READY"], name = map or L["Battleground"],
        line = MUTED_HEX .. L["Your queue popped"] .. "|r", seconds = left, sound = SOUND_PROMPT, onRemoved = Restore,
        buttons = { enter, leave },
    })
    -- the game opens its window around now: take over its buttons once it is there
    for _, t in ipairs({ 0.05, 0.3, 1 }) do
        C_Timer.After(t, function()
            if I.rolls[1] and I.rolls[1].id == "bg" .. i and I.state == "roll" then I:FillRoll() HideBGWindow() end
        end)
    end
end

local function OnBattlefieldStatus()
    if not (ns.db.promptBattleground and GetBattlefieldStatus) then return end
    local slots = (GetMaxBattlefieldID and GetMaxBattlefieldID()) or 3
    for i = 1, slots do
        local ok, status, map = pcall(GetBattlefieldStatus, i)
        if ok and status == "confirm" then
            if not bgUp[i] then
                bgUp[i] = true
                BGPrompt(i, map)
            end
        elseif bgUp[i] then
            bgUp[i] = nil
            I:RemoveRoll("bg" .. i, true)
        end
    end
end

-- ---------------------------------------------------------------- loot confirmations
-- "This item will bind to you": rolling Need or Greed (or disenchant) on a bind-on-pickup item,
-- looting one, or equipping a bind-on-equip item.

local function ItemFromRoll(rollID)
    if not GetLootRollItemInfo then return end
    local ok, texture, name, _, quality = pcall(GetLootRollItemInfo, rollID)
    if ok then return name, texture, quality end
end

local function ConfirmCard(id, cap, name, texture, quality, line, confirm, cancel, popups)
    I:AddPrompt({
        id = id, front = true, cap = cap, capColor = ORANGE_BIND, name = name or L["This item"], texture = texture, quality = quality,
        line = MUTED_HEX .. line .. "|r", seconds = 30, sound = SOUND_PROMPT, onRemoved = Restore,
        buttons = {
            { label = L["Confirm"], done = L["Confirmed"], fn = function() pcall(confirm) HidePopup(unpack(popups)) end },
            { label = L["Cancel"], done = L["Cancelled"], muted = true, fn = function() if cancel then pcall(cancel) end HidePopup(unpack(popups)) end },
        },
    })
    SuppressPopups(unpack(popups))
end

local ROLL_WORD = { [1] = L["Need"], [2] = L["Greed"], [3] = L["Disenchant"] }

local function OnConfirmRoll(rollID, rollType)
    if not ns.db.promptLootConfirm then return end
    local name, texture, quality = ItemFromRoll(rollID)
    local word = ROLL_WORD[rollType] or L["Rolling"]
    ConfirmCard("bindroll" .. tostring(rollID), L["BIND ON PICKUP"], name, texture, quality,
        L["%s binds it to you if you win"]:format(word),
        function() ConfirmLootRoll(rollID, rollType) end, nil, { "CONFIRM_LOOT_ROLL", "CONFIRM_DISENCHANT_ROLL" })
end

local function OnLootBind(slot)
    if not ns.db.promptLootConfirm then return end
    local name, texture, quality
    if GetLootSlotInfo then
        local ok, t, n, _, _, q = pcall(GetLootSlotInfo, slot)
        if ok then texture, name, quality = t, n, q end
    end
    ConfirmCard("bindloot" .. tostring(slot), L["BIND ON PICKUP"], name, texture, quality, L["Looting it binds it to you"],
        function() ConfirmLootSlot(slot) end, nil, { "LOOT_BIND" })
end

-- Equipping is something only the game's own button may do, so the card's buttons press the
-- (hidden) game window's buttons, the same way as entering a battleground.
local function EquipWindow()
    for _, which in ipairs({ "EQUIP_BIND", "AUTOEQUIP_BIND" }) do
        local d = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
        if d then return d end
    end
end

-- Weapons, shields and off-hands (slots 16-18) can be swapped in combat, but only with the game's
-- own window, since the island's buttons are locked during a fight. Armor can't be changed in
-- combat at all: for that the island says so and closes the game's window (the item stays in your bags).
local WEAPON_SLOTS = { [16] = true, [17] = true, [18] = true }

local function EquipBlocked(id)
    HidePopup("EQUIP_BIND", "AUTOEQUIP_BIND")
    I:AddPrompt({
        id = id or "bindequip", front = true, cap = L["BIND ON EQUIP"], capColor = ORANGE_BIND, name = L["Can't change armor in combat"],
        line = MUTED_HEX .. L["Try again once the fight is over"] .. "|r", seconds = 6,
        buttons = { { label = L["OK"], done = L["OK"], muted = true, fn = function() end } },
    })
end

local function OnEquipBind(slot)
    if not ns.db.promptLootConfirm then return end
    local id = "bindequip" .. tostring(slot)
    if InCombatLockdown and InCombatLockdown() then
        if not WEAPON_SLOTS[slot] then EquipBlocked(id) end      -- a weapon: the game's window handles it
        return
    end
    local equip, cancel
    equip = { label = L["Equip"], done = L["Equipped"], secure = function() return ButtonOf(EquipWindow(), 1) end,
              fn = function() if not equip.armed then Restore() end end }
    cancel = { label = L["Cancel"], done = L["Cancelled"], muted = true, secure = function() return ButtonOf(EquipWindow(), 2) end,
               fn = function() if not cancel.armed then Restore() end end }
    I:AddPrompt({
        id = id, front = true, cap = L["BIND ON EQUIP"], capColor = ORANGE_BIND, name = L["Equip this item?"], slot = slot,
        line = MUTED_HEX .. L["Equipping it binds it to you"] .. "|r", seconds = 30, sound = SOUND_PROMPT, onRemoved = Restore,
        buttons = { equip, cancel },
    })
    -- the game opens its window around now: take over its buttons, then tuck it away
    for _, t in ipairs({ 0.05, 0.3 }) do
        C_Timer.After(t, function()
            if not (I.rolls[1] and I.rolls[1].id == id and I.state == "roll") then return end
            I:FillRoll()
            local d = EquipWindow()
            if d and equip.armed and not (InCombatLockdown and InCombatLockdown()) then Suppress(d) end
        end)
    end
end

local function OnResurrect(name)
    Request("resurrect", "Plus", GREEN, L["RESURRECTION"], L["%s wants to resurrect you"]:format(ns.ShowName(name) or L["Someone"]), nil, 60,
        function() if AcceptResurrect then AcceptResurrect() end HidePopup("RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER") end,
        function() if DeclineResurrect then DeclineResurrect() end HidePopup("RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER") end,
        nil, Restore)
    if ns.db.promptRequests and ns.db.hideBlizzardPopups then
        SuppressPopups("RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER")
    end
end

local function OnSummon()
    local S = C_SummonInfo
    local who = (S and S.GetSummonConfirmSummoner and S.GetSummonConfirmSummoner()) or (GetSummonConfirmSummoner and GetSummonConfirmSummoner())
    local area = (S and S.GetSummonConfirmAreaName and S.GetSummonConfirmAreaName()) or (GetSummonConfirmAreaName and GetSummonConfirmAreaName())
    local left = (S and S.GetSummonConfirmTimeLeft and S.GetSummonConfirmTimeLeft()) or (GetSummonConfirmTimeLeft and GetSummonConfirmTimeLeft())
    Request("summon", "Home", PURPLE, L["SUMMON"], L["%s is summoning you"]:format(ns.ShowName(who) or L["Someone"]),
        (area and area ~= "") and (MUTED_HEX .. L["To %s"]:format(area) .. "|r") or nil,
        (type(left) == "number" and left > 0) and left or 120,
        function()
            if S and S.ConfirmSummon then S.ConfirmSummon() elseif ConfirmSummon then ConfirmSummon() end
            HidePopup("CONFIRM_SUMMON")
        end,
        function()
            if S and S.CancelSummon then S.CancelSummon() elseif CancelSummon then CancelSummon() end
            HidePopup("CONFIRM_SUMMON")
        end, nil, Restore)
    if ns.db.promptRequests and ns.db.hideBlizzardPopups then SuppressPopups("CONFIRM_SUMMON") end
end

-- ---------------------------------------------------------------- demo

function ns.DemoPrompts()
    if not I.built then return end
    rc.active, rc.ready, rc.notReady, rc.total = true, { Thrall = true }, {}, 5
    I:AddPrompt({
        id = "readycheck", glyph = "Check", tone = GOLD, cap = L["READY CHECK"], name = L["%s asks if you are ready"]:format("Thrall"),
        line = TallyLine(), seconds = 20, sound = SOUND_PROMPT,
        buttons = {
            { label = L["Ready"], done = L["Ready"], fn = function() rc.ready.You = true end },
            { label = L["Not ready"], done = L["Not ready"], muted = true, fn = function() rc.notReady.You = true end },
        },
        onAnswered = function()
            rc.ready.Jaina, rc.ready.Sylvanas, rc.notReady.Garrosh = true, true, true
            ReadyCheckFinished()
        end,
    })
    C_Timer.After(1.5, function() rc.ready.Jaina = true I:UpdatePrompt("readycheck", (TallyLine())) end)
    C_Timer.After(3.0, function() rc.notReady.Garrosh = true I:UpdatePrompt("readycheck", (TallyLine())) end)
    I:AddPrompt({
        id = "demo-summon", glyph = "Home", tone = PURPLE, cap = L["SUMMON"], name = L["%s is summoning you"]:format("Jaina"),
        line = MUTED_HEX .. L["To %s"]:format("Blackrock Mountain") .. "|r", seconds = 20,
        buttons = { { label = L["Accept"], done = L["Accepted"] }, { label = L["Decline"], done = L["Declined"], muted = true } },
    })
end

-- ---------------------------------------------------------------- events

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, a, b, ...)
    if event == "READY_CHECK" then
        ReadyCheckStart(a, b)
        -- the game's ready check window: kept working but out of sight while the card is up
        if ns.db.promptReady and ns.db.hideBlizzardPopups then
            local function go()
                local f = _G.ReadyCheckFrame
                if f and f.IsShown and f:IsShown() and rc.active then Suppress(f) end
            end
            go() C_Timer.After(0.05, go) C_Timer.After(0.4, go)
        end
    elseif event == "READY_CHECK_CONFIRM" then
        ReadyCheckConfirm(a, b)
    elseif event == "READY_CHECK_FINISHED" then
        ReadyCheckFinished()
    elseif event == "PARTY_INVITE_REQUEST" then
        OnInvite(a, b, ...)
    elseif event == "PARTY_INVITE_CANCEL" or event == "GROUP_JOINED" then
        I:RemoveRoll("invite", true)
    elseif event == "DUEL_REQUESTED" then
        OnDuel(a)
    elseif event == "GUILD_INVITE_REQUEST" then
        OnGuildInvite(a, b)
    elseif event == "GUILD_INVITE_CANCEL" then
        I:RemoveRoll("guild", true)
    elseif event == "DUEL_FINISHED" or event == "DUEL_INBOUNDS" then
        I:RemoveRoll("duel", true)
    elseif event == "RESURRECT_REQUEST" then
        OnResurrect(a)
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        I:RemoveRoll("resurrect", true)
        if event == "PLAYER_ALIVE" and UnitIsGhost and UnitIsGhost("player") then
            -- PLAYER_ALIVE also fires on releasing: now a ghost
            I:RemoveRoll("death", true)
            I:RemoveRoll("selfres", true)
            C_Timer.After(0.3, OnGhost)
        else
            BackToLife()
        end
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        OnBattlefieldStatus()
    elseif event == "CONFIRM_LOOT_ROLL" or event == "CONFIRM_DISENCHANT_ROLL" then
        OnConfirmRoll(a, b)
    elseif event == "LOOT_BIND_CONFIRM" then
        OnLootBind(a)
    elseif event == "EQUIP_BIND_CONFIRM" or event == "AUTOEQUIP_BIND_CONFIRM" then
        OnEquipBind(a)
    elseif event == "LOOT_CLOSED" then
        for _, roll in ipairs(I.rolls) do
            if tostring(roll.id):find("^bindloot") then I:RemoveRoll(roll.id, true) break end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- this runs just before combat locks secure buttons: unhook every overlay from the card
        -- (or the island can't move in combat) and hand the battleground window back
        for _, o in pairs(overlays) do Park(o) end
        if TopHasSecure() then
            local roll = I.rolls[1]
            for _, spec in ipairs(roll.buttons) do spec.armed = nil end
            if tostring(roll.id):find("^bindequip") and not WEAPON_SLOTS[roll.slot] then
                -- an equip question when a fight starts: it can't be answered now
                I:RemoveRoll(roll.id, true)
                EquipBlocked(roll.id)
            elseif tostring(roll.id):find("^bindequip") then
                I:RemoveRoll(roll.id, true)      -- a weapon: hand it to the game's window, which works in combat
            else
                Restore()
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if TopHasSecure() and I.state == "roll" then I:FillRoll() HideBGWindow() end
    elseif event == "SELF_RES_SPELL_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.2, OnDead)
    elseif event == "PLAYER_DEAD" then
        C_Timer.After(0.2, OnDead)
    elseif event == "CORPSE_IN_RANGE" then
        OnCorpseInRange()
    elseif event == "CORPSE_OUT_OF_RANGE" then
        I:RemoveRoll("corpse", true)
    elseif event == "CONFIRM_SUMMON" then
        OnSummon()
    elseif event == "CANCEL_SUMMON" then
        I:RemoveRoll("summon", true)
    end
end)
for _, event in ipairs({ "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "PARTY_INVITE_REQUEST",
                         "PARTY_INVITE_CANCEL", "GROUP_JOINED", "DUEL_REQUESTED", "DUEL_FINISHED", "RESURRECT_REQUEST",
                         "PLAYER_ALIVE", "PLAYER_UNGHOST", "SELF_RES_SPELL_CHANGED", "PLAYER_ENTERING_WORLD", "CONFIRM_SUMMON", "CANCEL_SUMMON",
                         "GUILD_INVITE_REQUEST", "GUILD_INVITE_CANCEL", "PLAYER_DEAD", "CORPSE_IN_RANGE", "CORPSE_OUT_OF_RANGE",
                         "UPDATE_BATTLEFIELD_STATUS", "CONFIRM_LOOT_ROLL", "CONFIRM_DISENCHANT_ROLL", "LOOT_BIND_CONFIRM",
                         "EQUIP_BIND_CONFIRM", "AUTOEQUIP_BIND_CONFIRM", "LOOT_CLOSED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    pcall(ev.RegisterEvent, ev, event)
end
