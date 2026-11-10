-- Island: keys and controller buttons for the cards. Bind them in the game's Key Bindings, under
-- AddOns > Island; a controller button can be bound there too. "Card: first button" presses the
-- first button on whatever card is up (Accept, Need, Release Spirit, Cancel), "Card: last button"
-- the last one (Decline, Pass), and "Close the current card" puts a card away.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local I = ns.Island

-- the buttons on the card at the top, in order, as the player sees them
local function VisibleButtons()
    local list = {}
    if not (I.rl and I.rl.buttons) then return list end
    for _, b in ipairs(I.rl.buttons) do
        if b:IsShown() and b.spec then list[#list + 1] = b end
    end
    return list
end

function BanzaiSland_CardButton(n)
    if not I.built then return end
    local roll = I.rolls and I.rolls[1]
    if roll and I.state == "roll" and not roll.answerT then
        local list = VisibleButtons()
        local b = (n == "last") and list[#list] or list[n]
        local spec = b and b.spec
        if not spec or not spec.enabled then return end
        -- Pause on a voiceover is mouse-only: a key meant for another card (Accept, Need) must not pause the voice
        if spec.noKey then return end
        -- a button only the game may press: its key is bound straight to it while it is armed
        if spec.secure then
            if not spec.armed then ns.Print(L["that one can't be answered with a key during combat."]) end
            return
        end
        I:AnswerRoll(spec)
        return
    end
    local cur = I.current
    if not (cur and cur.kind == "won") then return end
    if cur.button and (n == 1 or n == "last") then
        I.wn.btn:Click()                  -- Cancel on your own pull timer
    elseif n == 1 and cur.onClick then
        I.wn.tip:Click()                  -- what clicking the card does (whisper back, open the map...)
    end
end

function BanzaiSland_DismissCard()
    if not I.built then return end
    local cur = I.current
    if cur and cur.kind ~= "gain" and cur.dur then
        cur.dur = math.min(cur.dur, cur.t + 0.05)
        return
    end
    -- a question you would rather answer in the game's own window (it comes back)
    local roll = I.rolls and I.rolls[1]
    if roll and roll.prompt and not roll.answerT then I:RemoveRoll(roll.id) end
end

-- the key (or controller button) bound to a card button, short, for the hint on the button
local function KeyName(cmd)
    if not GetBindingKey then return nil end
    local key = GetBindingKey(cmd)
    if not key then return nil end
    local ok, text = pcall(GetBindingText, key, true)
    if not ok or not text or text == "" then
        ok, text = pcall(GetBindingText, key, "KEY_", true)
    end
    return (ok and text and text ~= "") and text or key
end

function ns.KeyHint(index, isLast)
    if not (ns.db and ns.db.keyHints) then return nil end
    local k = KeyName("BANZAISLAND_CARD" .. index)
    if not k and isLast then k = KeyName("BANZAISLAND_CARDLAST") end
    return k
end

-- the label with its key after it, quietly
function ns.WithKey(label, index, isLast)
    local k = ns.KeyHint(index, isLast)
    if not k then return label end
    return label .. "  " .. ns.Hex(0.55, 0.58, 0.65) .. k .. "|r"
end

-- keys can change while a card is up: refresh the hints on its buttons (only the labels)
local function RefreshHints()
    if not I.built then return end
    if ns.Pad and ns.Pad.mode == "roll" then ns.Pad:Paint() return end     -- showing A and B instead
    local roll = I.rolls and I.rolls[1]
    if roll and I.state == "roll" and not roll.answerT then
        local list = VisibleButtons()
        for i, b in ipairs(list) do b.text:SetText(ns.WithKey(b.spec.label, i, i == #list)) end
    end
    local cur = I.current
    if cur and cur.kind == "won" and cur.button and I.wn.btn:IsShown() and not (ns.Pad and ns.Pad.mode == "won") then
        I.wn.btn.text:SetText(ns.WithKey(cur.button.label, 1, true))
    end
end
ns.RefreshKeyHints = RefreshHints
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", RefreshHints)
pcall(ev.RegisterEvent, ev, "UPDATE_BINDINGS")
