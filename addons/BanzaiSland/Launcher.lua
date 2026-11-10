-- BanzaiSland: the integrated BANZAI / SLAND launcher's behaviour and the BANZAI UI integration boundary.
-- The renderer draws the mark on the chassis (Renderer.lua); this file owns what the two halves do.
--
-- BANZAI UI boundary (explicit, nothing else is touched):
--   present  : `_G.BanzaiOpenSettings` is a function - BANZAI UI's documented public entry ("the BANZAI
--              wordmark calls this", BANZAI UI Options.lua). Load order puts BANZAI UI after
--              BanzaiSland, so presence is asked at click / paint time, never at file load.
--   BANZAI   : call BanzaiOpenSettings("home"), out of combat only. BANZAI UI refuses in combat itself
--              as well; BanzaiSland checks first so nothing protected is ever asked for in a fight.
--   host     : BanzaiSland hosts the top-centre identity while its wordmark is shown. BanzaiSlandAPI
--              .HostsBanzaiLauncher() says so (pull), and BanzaiCompat.SetLauncherHost("BanzaiSland")
--              / SetLauncherHost(nil) is called when the mark comes or goes (push) - BANZAI UI 1.3.8's
--              launcher-host adapter (docs/BANZAI-UI-ADAPTER.md). Both sides are event-driven: no
--              timer, no OnUpdate, no polling. BANZAI UI 1.3.7 and older have neither, so there the
--              standalone BANZAI wordmark stays unless Darren turns BANZAI > Appearance > BANZAI logo
--              off himself. No frame of BANZAI UI is read, hidden, re-parented or hooked here, and no
--              BANZAI UI saved variable is written (its Show BANZAI Logo preference stays as it was).
--   absent   : the BANZAI half is branding. Clicking it says "BANZAI UI is not installed." once per
--              session (and in its tooltip), never errors, never spams.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local Launcher = {}
ns.Launcher = Launcher

Launcher.ABSENT_MESSAGE = "BANZAI UI is not installed."
Launcher.COMBAT_MESSAGE = "Settings cannot open in combat."

-- test / preview hook: Launcher.simulate = "absent" | "present" overrides detection
Launcher.simulate = nil

function Launcher.BanzaiUIPresent()
    if Launcher.simulate == "absent" then return false end
    if Launcher.simulate == "present" then return true end
    return type(_G.BanzaiOpenSettings) == "function"
end

local function InCombat() return InCombatLockdown and InCombatLockdown() or false end

-- the BANZAI half: BANZAI UI's settings on HOME, through its public entry; nothing in combat
function Launcher.ClickBanzai()
    if InCombat() then
        ns.Print(L[Launcher.COMBAT_MESSAGE])
        return false, "combat"
    end
    if not Launcher.BanzaiUIPresent() then
        if not Launcher.saidAbsent then
            Launcher.saidAbsent = true
            ns.Print(L[Launcher.ABSENT_MESSAGE])
        end
        return false, "absent"
    end
    if Launcher.simulate == "present" then return true, "simulated" end
    local ok, result = pcall(_G.BanzaiOpenSettings, "home")
    if not ok then
        ns.Print(L["BANZAI UI settings could not open."])
        return false, "error"
    end
    return result ~= false, "opened"
end

-- the SLAND half: BanzaiSland's own settings (what /banzaisland does; a plain frame, safe in combat)
function Launcher.ClickSland()
    ns.ToggleSettings()
    return true
end

-- tooltip lines for each half
function Launcher.BanzaiTip()
    if Launcher.BanzaiUIPresent() then return "BANZAI UI", L["Click: BANZAI settings"] end
    return "BANZAI UI", L[Launcher.ABSENT_MESSAGE]
end
function Launcher.SlandTip()
    return "BanzaiSland", L["Click: BanzaiSland settings"]
end

-- BanzaiSland hosts the top-centre identity while its wordmark is shown (the island built, the mark
-- present and shown; a blocked or failed start never hosts)
function Launcher.Hosting()
    local I = ns.Island
    return (I and I.built and I.brand and I.brand.shown and I.brand:IsShown()) and true or false
end

-- the public half of the launcher-host contract (pull side); BANZAI UI reads this to hide its own wordmark
local function PublishHost()
    local API = _G.BanzaiSlandAPI
    if type(API) == "table" and API.HostsBanzaiLauncher == nil then
        API.HostsBanzaiLauncher = function() return Launcher.Hosting() end
    end
end

-- the push side (BANZAI UI 1.3.8+): SetLauncherHost("BanzaiSland") claims the top centre,
-- SetLauncherHost(nil) releases it. Called by the renderer when the mark comes or goes; nothing else
-- of BANZAI UI is touched, and a BANZAI UI without the adapter is simply left alone.
function Launcher.Announce(on)
    PublishHost()
    local Compat = _G.BanzaiCompat
    if type(Compat) == "table" and type(Compat.SetLauncherHost) == "function" then
        pcall(Compat.SetLauncherHost, on and ADDON or nil)
        return true
    end
    return false
end

-- the pull side is published at once (Extensions.lua made the API table before this file) and again
-- after everything has loaded, BANZAI UI included
PublishHost()
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    PublishHost()
end)
