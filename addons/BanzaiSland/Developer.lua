-- Trusted Lua switch. The old per-rule editor became the package creator (Packages.lua); the rules a
-- player already made are turned into one package there (K.MigrateRules) and stay in the saved data.
local ADDON,ns=...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
if ns.Client.kind~="forever" then return end
local L=ns.L
local D={};ns.Developer=D
local function Prefs()
    if not ns.db then return end
    if type(ns.db.developer)~="table" then ns.db.developer={} end
    local p=ns.db.developer
    if p.version==nil then p.version=1 end -- Core's RGB table-default filler yields {}.
    if p.version~=1 then return end
    if type(p.rules)~="table" then p.rules={} end
    return p
end
function D.Trusted() local p=Prefs();return p and p.trusted==true or false end
function D.SetTrusted(value)
    local p=Prefs();if not p or type(value)~="boolean" then return false,"invalid_rule" end
    p.trusted=value
    if ns.Packages then ns.Packages.Refresh() end
    if ns.RefreshSettings then ns.RefreshSettings() end
    return true,"accepted"
end
function D.Reason(reason)
    local names={accepted=L["Accepted"],disabled=L["Disabled"],no_output=L["No output"],
        trust_required=L["Turn on Allow package code first."],not_ready=L["BanzaiSland is not ready"],
        capacity=L["Rule or notification limit reached"],invalid_payload=L["Returned payload is invalid. A card needs title and text; a bubble needs text and tooltip. Check the mode."],
        rate_limited=L["Notification rate limited"],lua_error=L["Lua error; disabled after three consecutive failures"],
        adapter_error=L["Notification could not be submitted"]}
    return names[reason] or reason or L["Disabled"]
end
