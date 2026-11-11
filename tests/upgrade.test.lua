local ns, WOW, T = ...
local key = ns.Profiles.CharacterKey()
local retired = { "WANTBANZAI", "WANTCOFFEE", "CHANG_CHANG_WOODCUT", "ROOTS_OF_CHINA", "ODISHI" }
local profiles = {
    Retail = { displayFont = "RYUJIN_ATTACK", material = "solid", chassisEdge = "hairline", opacity = 0.7 },
}
for _, font in ipairs(retired) do
    profiles[font] = { displayFont = font, material = "parchment", chassisEdge = "bamboo", opacity = 0.9 }
end
_G.BanzaiSlandDB = {
    displayFont = "BANZAI_DEFAULT", material = "glass", x = 120, y = -40,
    profiles = profiles, profileUsers = { [key] = "Retail" },
}
_G.BanzaiSlandCharDB = { profile = "Retail" }
local account = BanzaiSlandDB
local character = BanzaiSlandCharDB
T.noerror(function() WOW.Login() end, "1.0.1 loads existing final/retired font profiles")
T.eq(ns.VERSION, "1.0.1", "candidate version")
T.eq(BanzaiSlandDB, account, "account table retained")
T.eq(BanzaiSlandCharDB, character, "character table retained")
T.eq(BanzaiSlandDB.profiles, profiles, "profile table retained")
T.eq(ns.db, profiles.Retail, "active profile retained")
T.eq(ns.db.displayFont, "RYUJIN_ATTACK", "final Retail alternate retained")
T.eq(ns.db.material, "solid", "active material retained")
T.eq(ns.db.chassisEdge, "hairline", "active chassis retained")
T.eq(ns.db.opacity, 0.7, "active opacity retained")
T.eq(account.x, 120, "saved position retained")
T.eq(account.y, -40, "saved position retained")
for _, font in ipairs(retired) do
    T.eq(profiles[font].displayFont, "BANZAI_DEFAULT", font .. " migrates in inactive profile")
    T.eq(profiles[font].material, "parchment", font .. " material retained")
    T.eq(profiles[font].opacity, 0.9, font .. " opacity retained")
end
T.eq(ns.Theme.BANZAI_DEFAULT_SCALE, 1.05, "default scale stays 105%")
T.ok(BanzaiSlandAPI.HostsBanzaiLauncher(), "integrated launcher host retained")
T.eq(#WOW.secureAttributeWrites, 0, "upgrade writes no secure attributes")
