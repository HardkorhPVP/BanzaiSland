-- Island: moving the island from other addons' edit modes. The game's Edit Mode and ElvUI's
-- movers show Island's own box to drag; EllesmereUI's unlock mode gets an Island mover of its own.
-- Wherever it is moved from, the spot is kept in Island's settings as X and Y from the middle of
-- the screen.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local I = ns.Island
local floor = math.floor
local M = {}
ns.Movers = M

-- ---------------------------------------------------------------- the coordinates panel
-- A small window beside the game's Edit Mode menu (or near the top of the screen for ElvUI) with
-- the island's X and Y. It is placed by screen position, never attached to the game's menu.

local C = ns.C
local panel

local function NumberBox(parent, get, set)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(64, 24)
    e:SetAutoFocus(false)
    e.bg = ns.CreatePill(e, 24, "BACKGROUND", 0)
    e.bg:SetWidth(64)
    e.bg:SetColor(1, 1, 1, 0.08)
    ns.UseFont(e, "bold", 12)
    e:SetTextColor(C.fg[1], C.fg[2], C.fg[3])
    e:SetJustifyH("CENTER")
    e:SetTextInsets(6, 6, 0, 0)
    e:SetMaxLetters(6)
    function e:Show_()
        if self.HasFocus and self:HasFocus() then return end
        local v = get()
        local text = v and tostring(floor(v + 0.5)) or ""
        if text ~= self.shownText then self.shownText = text self:SetText(text) end
    end
    local function commit(self)
        local v = tonumber(self:GetText())
        if v then set(floor(v + 0.5)) end
        self:Show_()
    end
    e:SetScript("OnEnterPressed", function(self) commit(self) self:ClearFocus() end)
    e:SetScript("OnTabPressed", function(self) commit(self) self:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() self:Show_() end)
    e:SetScript("OnEditFocusGained", function(self) self.bg:SetColor(1, 1, 1, 0.16) self:HighlightText() end)
    e:SetScript("OnEditFocusLost", function(self) self.bg:SetColor(1, 1, 1, 0.08) self:Show_() end)
    return e
end

local function SmallButton(parent, label, w, fn)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, 24)
    b.bg = ns.CreatePill(b, 24, "ARTWORK", 0)
    b.bg:SetWidth(w)
    b.bg:SetColor(1, 1, 1, 0.10)
    b.text = ns.Text(b, "bold", 11.5, C.fg, "CENTER")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b:SetScript("OnEnter", function() b.bg:SetColor(1, 1, 1, 0.18) end)
    b:SetScript("OnLeave", function() b.bg:SetColor(1, 1, 1, 0.10) end)
    b:SetScript("OnClick", fn)
    return b
end

local function Here() return I:ReadCenter() end

local function BuildPanel()
    local f = CreateFrame("Frame", "BanzaiSlandEditPanel", UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetSize(196, 132)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f.body = ns.CreateBody(f, "BACKGROUND", 0)
    f.body:SetColor(0.03, 0.03, 0.04, 0.95)
    f.body:SetRadius(14)
    local logo = ns.Image(f, "Icon", "ARTWORK", 0)
    logo:SetSize(20, 20)
    logo:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    local title = ns.Text(f, "extra", 14, C.fg)
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    title:SetText(L["BanzaiSland"])
    local hint = ns.Text(f, "medium", 10, C.muted)
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -38)
    hint:SetText(L["From the middle of the screen"])

    local xl = ns.Text(f, "bold", 12, C.muted)
    xl:SetText(L["X"])
    xl:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -64)
    f.x = NumberBox(f, function() return (select(1, Here())) end, function(v)
        local _, y = Here()
        I:MoveTo(v, y or 0)
    end)
    f.x:SetPoint("LEFT", xl, "RIGHT", 8, 0)
    local yl = ns.Text(f, "bold", 12, C.muted)
    yl:SetText(L["Y"])
    yl:SetPoint("LEFT", f.x, "RIGHT", 14, 0)
    f.y = NumberBox(f, function() return (select(2, Here())) end, function(v)
        local x = Here()
        I:MoveTo(x or 0, v)
    end)
    f.y:SetPoint("LEFT", yl, "RIGHT", 8, 0)

    local bw = (196 - 28 - 12) / 3
    local a = SmallButton(f, L["Center"], bw, function()
        local _, y = Here()
        I:MoveTo(0, y or 0)
    end)
    a:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
    local b = SmallButton(f, L["Top"], bw, function()
        ns.db.position = "top"
        I:ApplyPosition()
        if ns.RefreshSettings then ns.RefreshSettings() end
    end)
    b:SetPoint("LEFT", a, "RIGHT", 6, 0)
    local c = SmallButton(f, L["Bottom"], bw, function()
        ns.db.position = "bottom"
        I:ApplyPosition()
        if ns.RefreshSettings then ns.RefreshSettings() end
    end)
    c:SetPoint("LEFT", b, "RIGHT", 6, 0)

    -- follow the Edit Mode menu if it is moved, and keep the numbers current while dragging
    local t = 0
    f:SetScript("OnUpdate", function(self, dt)
        t = t + dt
        if t < 0.1 then return end
        t = 0
        M:PlacePanel()
        self.x:Show_()
        self.y:Show_()
    end)
    f:Hide()
    panel = f
end

function M:PlacePanel()
    if not panel then return end
    local menu = _G.EditModeManagerFrame
    local k = UIParent:GetEffectiveScale()
    local x, y
    if type(menu) == "table" and menu.IsShown and menu:IsShown() and menu:GetRight() then
        local mk = menu:GetEffectiveScale() / k
        x, y = floor(menu:GetRight() * mk + 10), floor(menu:GetTop() * mk)
    end
    if x == panel.px and y == panel.py and (panel:GetNumPoints() or 0) > 0 then return end   -- not moved
    panel.px, panel.py = x, y
    panel:ClearAllPoints()
    if x then
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    else
        panel:SetPoint("TOP", UIParent, "TOP", 0, -140)
    end
end

function M:ShowPanel(on)
    if on and not panel then BuildPanel() end
    if not panel then return end
    if on then
        M:PlacePanel()
        panel.x:Show_()
        panel.y:Show_()
        panel:Show()
    else
        panel:Hide()
        panel:ClearAllPoints()
        panel.px, panel.py = nil, nil
    end
end

local function Editing(on)
    I:SetEditing(on)
    M:ShowPanel(on)
end

-- ---------------------------------------------------------------- the game's Edit Mode

local function HookEditMode()
    if M.blizz then return end
    if EventRegistry and EventRegistry.RegisterCallback then
        M.blizz = true
        EventRegistry:RegisterCallback("EditMode.Enter", function() Editing(true) end, M)
        EventRegistry:RegisterCallback("EditMode.Exit", function() Editing(false) end, M)
    end
    local f = _G.EditModeManagerFrame
    if type(f) == "table" and f.HookScript and not M.blizzFrame then
        M.blizzFrame = true
        f:HookScript("OnShow", function() Editing(true) end)
        f:HookScript("OnHide", function() Editing(false) end)
    end
end

-- ---------------------------------------------------------------- ElvUI movers

local function HookElvUI()
    if M.elv then return end
    local E = type(_G.ElvUI) == "table" and _G.ElvUI[1]
    if type(E) ~= "table" or type(E.ToggleMoveMode) ~= "function" then return end
    M.elv = true
    hooksecurefunc(E, "ToggleMoveMode", function()
        Editing(E.ConfigurationMode and true or false)
    end)
end

-- ---------------------------------------------------------------- EllesmereUI unlock mode

local function HookEllesmere()
    if M.eui then return end
    local E = _G.EllesmereUI
    if type(E) ~= "table" or type(E.RegisterUnlockElements) ~= "function" then return end
    M.eui = true
    local elem = {
        key = "BanzaiSland_Island", label = "BanzaiSland", group = "BanzaiSland", order = 900,
        noResize = true, noAnchorTo = true, noAnchorTarget = true, noInitHook = true,
        getFrame = function() return I.anchor end,
        getSize = function() return ns.STATES.idle.w, ns.STATES.idle.h end,
        isHidden = function() return false end,
        -- EllesmereUI works in the same terms as Island: the middle of the frame, in pixels from the
        -- middle of the screen (CENTER to CENTER). Anything else is read back from the screen.
        savePos = function(_, point, relPoint, x, y)
            if point == "CENTER" and (relPoint or "CENTER") == "CENTER" and type(x) == "number" and type(y) == "number" then
                I:MoveTo(floor(x + 0.5), floor(y + 0.5))
                return
            end
            local cx, cy = I:ReadCenter()
            if cx then I:MoveTo(floor(cx + 0.5), floor(cy + 0.5)) end
        end,
        loadPos = function()
            local cx, cy = I:ReadCenter()
            if not cx then return nil end
            return { point = "CENTER", relPoint = "CENTER", x = cx, y = cy }
        end,
        clearPos = function()
            ns.db.position = "top"
            I:ApplyPosition()
        end,
        applyPos = function() I:ApplyPosition() end,
    }
    local MK = E.MakeUnlockElement
    pcall(E.RegisterUnlockElements, E, { MK and MK(elem) or elem }, "BanzaiSland")
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, name)
    if not I.built then return end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        HookEditMode() HookElvUI() HookEllesmere()
    elseif event == "ADDON_LOADED" then
        if name == "ElvUI" then HookElvUI()
        elseif name == "EllesmereUI" then HookEllesmere()
        elseif name == "Blizzard_EditMode" then HookEditMode() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if I.dragging then I:StopDrag() end
    end
end)
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "PLAYER_REGEN_DISABLED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
