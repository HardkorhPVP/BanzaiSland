-- Island: controller support. With a controller in hand (and out of combat) a card's buttons can
-- be picked with the D-pad and pressed with A; B declines or closes the card. The buttons then
-- show A and B instead of keyboard keys. Important cards give a short rumble, and the guide button
-- shows the island's details. In combat the bound keys from Key Bindings still work.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)

local I = ns.Island
local P = { focus = 1 }
ns.Pad = P

-- ---------------------------------------------------------------- is a controller in use?

local function Enabled()
    return C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled() or false
end

local function Connected()
    if not Enabled() or not C_GamePad.GetAllDeviceIDs then return false end
    local ok, ids = pcall(C_GamePad.GetAllDeviceIDs)
    if not ok or type(ids) ~= "table" then return false end
    for _, id in ipairs(ids) do
        local ok2, state = pcall(C_GamePad.GetDeviceRawState, id)
        if ok2 and state then return true end
    end
    return false
end

-- the controller was the last thing touched (not just plugged in)
local function Using()
    if not Enabled() then return false end
    if IsUsingGamepad then
        local ok, v = pcall(IsUsingGamepad)
        if ok then return v and true or false end
    end
    return Connected()
end
P.Using = Using

-- ---------------------------------------------------------------- rumble

local RUMBLE = { readycheck = true, summon = true, resurrect = true, invite = true, pull = true }

function ns.Rumble(id)
    if not (ns.db and ns.db.padRumble) or not Connected() or not C_GamePad.SetVibration then return end
    id = tostring(id or "")
    if not (RUMBLE[id] or id:find("^bg")) then return end
    -- two short pulses, like a phone notification
    pcall(C_GamePad.SetVibration, "High", 0.55)
    C_Timer.After(0.12, function() if C_GamePad.StopVibration then pcall(C_GamePad.StopVibration) end end)
    C_Timer.After(0.22, function() pcall(C_GamePad.SetVibration, "High", 0.55) end)
    C_Timer.After(0.34, function() if C_GamePad.StopVibration then pcall(C_GamePad.StopVibration) end end)
end

-- ---------------------------------------------------------------- answering cards

-- Controller buttons are taken over with override bindings while a card is up: D-pad left and
-- right move the focus, A presses, B declines or closes. Bindings can only change out of combat,
-- so this switches off when a fight starts; the Key Bindings keys keep working in combat.
local owner = CreateFrame("Frame")

local function Hidden(name, fn)
    local b = CreateFrame("Button", name, UIParent)
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
    b:EnableMouse(false)
    b:SetScript("OnClick", fn)
    return b
end

-- the shown buttons of the card at the top, with their place among the card's buttons
local function Buttons()
    local list = {}
    if not (I.rl and I.rl.buttons) then return list end
    for i, b in ipairs(I.rl.buttons) do
        if b:IsShown() and b.spec then list[#list + 1] = { b = b, i = i } end
    end
    return list
end

local function Mode()
    if not (ns.db and ns.db.padCards) or not Using() then return nil end
    if InCombatLockdown and InCombatLockdown() then return nil end
    if not I.built then return nil end
    local roll = I.rolls and I.rolls[1]
    if roll and I.state == "roll" and not roll.answerT and #Buttons() > 0 then return "roll" end
    local cur = I.current
    if cur and cur.kind == "won" and cur.button then return "won" end
    return nil
end

local GREEN, RED = { 0.45, 0.82, 0.38 }, { 0.92, 0.38, 0.34 }
local function Glyph(letter, col) return "  " .. ns.Hex(col[1], col[2], col[3]) .. letter .. "|r" end

-- the focus: brighter in the accent colour, with A on it; B on the button B presses
function P:Paint()
    if self.mode ~= "roll" then return end
    local list = Buttons()
    if #list == 0 then return end
    self.focus = math.max(1, math.min(self.focus, #list))
    local ac = ns.Accent()
    local last = list[#list]
    for n, e in ipairs(list) do
        local b, spec = e.b, e.b.spec
        local label = spec.label
        if n == self.focus then
            b.bg:SetColor(ac[1], ac[2], ac[3], 0.38)
            label = label .. Glyph("A", GREEN)
        else
            b.bg:SetColor(1, 1, 1, 0.10)
        end
        if e == last and #list > 1 and n ~= self.focus then label = label .. Glyph("B", RED) end
        b.text:SetText(label)
    end
end

-- A: the focused button. A button only the game may press gets A bound straight to its overlay.
local function BindA()
    if not SetOverrideBindingClick then return end
    local target = "BanzaiSlandPadPress"
    if P.mode == "roll" then
        local e = Buttons()[P.focus]
        local spec = e and e.b.spec
        local overlay = spec and spec.secure and spec.armed and _G["BanzaiSlandSecureButton" .. e.i]
        if overlay then target = overlay:GetName() end
    end
    if target == P.aTarget then return end        -- only rebind when it changes
    P.aTarget = target
    SetOverrideBindingClick(owner, true, "PAD1", target)
end

local function Bind(mode)
    ClearOverrideBindings(owner)
    P.mode, P.aTarget = mode, nil
    if not mode then return end
    BindA()
    SetOverrideBindingClick(owner, true, "PAD2", "BanzaiSlandPadBack")
    if mode == "roll" then
        SetOverrideBindingClick(owner, true, "PADDLEFT", "BanzaiSlandPadPrev")
        SetOverrideBindingClick(owner, true, "PADDRIGHT", "BanzaiSlandPadNext")
    end
end

local function Move(d)
    if P.mode ~= "roll" then return end
    local n = #Buttons()
    if n == 0 then return end
    P.focus = (P.focus - 1 + d) % n + 1
    P:Paint()
    BindA()
end

Hidden("BanzaiSlandPadPrev", function() Move(-1) end)
Hidden("BanzaiSlandPadNext", function() Move(1) end)
Hidden("BanzaiSlandPadPress", function()
    if P.mode == "won" then
        if I.current and I.current.button then I.wn.btn:Click() end
        return
    end
    local e = Buttons()[P.focus]
    local spec = e and e.b.spec
    if spec and spec.enabled and not spec.secure then I:AnswerRoll(spec) end
end)
Hidden("BanzaiSlandPadBack", function()
    if P.mode == "roll" then
        local list = Buttons()
        local last = list[#list]
        -- two or more buttons: the last is the "no" (Decline, Not ready, Pass); otherwise close it
        if #list > 1 and last and last.b.spec.enabled and not last.b.spec.secure then
            I:AnswerRoll(last.b.spec)
            return
        end
    end
    BanzaiSland_DismissCard()
end)

-- keep the takeover in step with what is on the island
local lastRoll
function P:Update()
    local mode = Mode()
    local roll = I.rolls and I.rolls[1]
    if roll ~= lastRoll then self.focus = 1 lastRoll = roll end
    if mode ~= self.mode then
        if InCombatLockdown and InCombatLockdown() then return end
        Bind(mode)
        if mode == "roll" then self:Paint()
        elseif ns.RefreshKeyHints then ns.RefreshKeyHints() end      -- back to keyboard hints
    elseif mode == "roll" then
        BindA()
    end
    if mode == "won" and I.current and I.current.button and I.wn.btn:IsShown() then
        I.wn.btn.text:SetText(I.current.button.label .. Glyph("A", GREEN))
    end
end

-- ---------------------------------------------------------------- the guide button

-- Shows or hides the island's details (the card you get by hovering it). Bound to the guide button
-- without taking priority, so a binding of your own on it wins. Some systems keep the guide button
-- for themselves (the Xbox Game Bar, Steam); Key Bindings > Island has the same thing to put on any
-- other button.
function BanzaiSland_ToggleDetails()
    if not I.built then return end
    if I.current or (I.rolls and #I.rolls > 0) then return end
    I.pinned = not I.pinned
    I:Settle()
end

local guideOwner = CreateFrame("Frame")
function P:ApplyGuide()
    if not SetOverrideBinding or (InCombatLockdown and InCombatLockdown()) then return end
    ClearOverrideBindings(guideOwner)
    if ns.db and ns.db.padGuide then
        SetOverrideBinding(guideOwner, false, "PADSYSTEM", "BANZAISLAND_DETAILS")
    end
end

-- ---------------------------------------------------------------- events

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    if event == "PLAYER_LOGIN" then
        P:ApplyGuide()
        if I.FillRoll and hooksecurefunc then hooksecurefunc(I, "FillRoll", function() P:Update() if P.mode == "roll" then P:Paint() end end) end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- this runs just before combat locks bindings: give the controller back
        ClearOverrideBindings(owner)
        P.mode, P.aTarget = nil, nil
        if ns.RefreshKeyHints then ns.RefreshKeyHints() end
    else
        P:Update()
    end
end)
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GAME_PAD_ACTIVE_CHANGED",
                     "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
-- cards come and go all the time: check a few times a second
local t = 0
ev:SetScript("OnUpdate", function(_, dt)
    t = t + dt
    if t < 0.2 then return end
    t = 0
    if ns.db and I.built then P:Update() end
end)
