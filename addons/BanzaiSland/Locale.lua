-- Island: translations.
-- Every piece of text the player sees goes through ns.L["English text"]. With no translation for
-- the player's language, the English comes back unchanged, so a half-done translation still works.
-- A translation lives in Locales/<code>.lua (koKR, zhCN, deDE, ...). Locales/Template.lua lists
-- every English text there is to translate.
local ADDON, ns = ...

local L = setmetatable({}, {
    __index = function(_, key) return key end,
})
ns.L = L
ns.LOCALE = (GetLocale and GetLocale()) or "enUS"

L["Style"] = "Style"
L["Modern"] = "Modern"
L["Forever"] = "Forever"

-- These are looked up through a variable elsewhere (L[item.unit] in the gain cards, L[category] in
-- the Polestar guide groups), so they are listed here for the template script to find them.
L["XP"] = "XP"
L["rep"] = "rep"
L["money"] = "money"
L["honor"] = "honor"
L["Leveling"] = "Leveling"

-- Locales/koKR.lua starts with:  local L = select(2, ...).NewLocale("koKR") if not L then return end
-- and then fills in lines like:   L["Size"] = "크기"
-- (lines left as "" are skipped, so a part-done file shows English for those)
local filler = setmetatable({}, {
    __index = L,
    __newindex = function(_, key, text)
        if type(text) == "string" and text ~= "" then rawset(L, key, text) end
    end,
})
function ns.NewLocale(code)
    if code ~= ns.LOCALE then return nil end
    return filler
end
