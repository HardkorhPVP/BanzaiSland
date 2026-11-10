-- Client identity is separate from combat policy: both clients share the same card rules.
local ADDON, ns = ...
local function Detect()
    local legacy = Constants and Constants.LegacyConsts
    if type(legacy) == "table" and type(legacy.LEGACY_POINTS_TRAIT_CURRENCY_ID) == "number" then return "forever" end
    if GetBuildInfo then
        local ok, _, _, _, interface = pcall(GetBuildInfo)
        if ok and interface == 16001 then return "forever" end
    end
    if WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then return "retail" end
    return "unknown"
end
ns.Client = { kind = Detect() }
ns.Client.isForever = ns.Client.kind == "forever"
ns.Client.isRetail = ns.Client.kind == "retail"
-- Future Retail-only modules/settings use the same gate with audience "retail".
ns.ClientFeatures = {
    forever = "forever", retail = "retail", legacy = "forever", druidGossipFlights = "forever",
    ammo = "forever", reagents = "forever", paladinSeals = "forever",
}
function ns.ClientFeature(feature, audience)
    audience = audience or ns.ClientFeatures[feature] or "shared"
    return audience == "shared" or audience == ns.Client.kind
end
