local _, ns = ...
local Theme = ns.Theme
if ns.Blocked then return end
if not Theme then return end

local ROOT = Theme.MEDIA .. "Fonts\\"
local REGISTRY = {
	SHOJUMARU = { label = "Shojumaru", author = "Brian J. Bonislawsky DBA Astigmatic", sourceUrl = "https://www.1001fonts.com/shojumaru-font.html", file = "Shojumaru-Regular.ttf", cmapCount = 370, ranges = "20-7e,a0-17e,1fc-1ff,237,2c6-2c7,2d8-2dd,312,315,326,3c0,1e80-1e85,1ef2-1ef3,2013-2014,2018-201a,201c-201e,2020-2022,2026,2030,2039-203a,2044,20ac,2122,2202,220f,2212,2248,2260,2264-2265,fb01-fb02", license = "SIL Open Font License 1.1", licenseFile = "Media/Banzai/Fonts/OFL.txt", presentationScale = 1, attribution = "Copyright (c) 2012 Brian J. Bonislawsky DBA Astigmatic (AOETI); reserved font name Shojumaru.", distributionAuthorization = "OFL 1.1 redistribution terms and notice retained; Darren approved Shojumaru for the private Retail selection lock; public distribution approved by Darren for the Retail release (2026-11-08)." },
	RYUJIN_ATTACK = { label = "Ryujin Attack", author = "Jetsmax", sourceUrl = "https://www.1001fonts.com/ryujin-attack-font.html", file = "RyujinAttack.otf", cmapCount = 196, ranges = "20-7e,a0-a5,a7,a9-ab,ad-ae,b2-b3,b9-bb,bf-cf,d1-dd,df-ef,f1-fd,ff,152-153,160-161,178,17e,2013-2014,2018-201a,201c-201e,2020-2021,2026,2039-203a,20ac", license = "Free to use (author README; no further licence text supplied)", licenseFile = "Media/Banzai/Fonts/RyujinAttack-README.txt", attribution = "Ryujin Attack by Jetsmax.", distributionAuthorization = "Shipped unmodified under the supplied README; Darren approved distribution inside BanzaiSland for the Retail release." },
	GANG_OF_THREE = { label = "Gang of Three", author = "Vic Fieger", sourceUrl = "https://www.1001fonts.com/gang-of-three-font.html", file = "go3v2.ttf", cmapCount = 655, ranges = "20-7e,a0-a3,a5-17f,192,1fa-1ff,2c6-2c7,2c9,2d8-2dd,37e,384-38a,38c,38e-3a1,3a3-3ce,401-40c,40e-44f,451-45c,45e-45f,490-491,1e80-1e85,1ef2-1ef3,2013-2015,2017-201e,2020-2022,2026,2030,2032-2033,2039-203a,203c,203e,2044,207f,20a3-20a4,20a7,20ac,2105,2113,2116,2122,2126,212e,215b-215e,2190-2195,21a8,2202,2206,220f,2211-2212,2215,2219-221a,221e-221f,2229,222b,2248,2260-2261,2264-2265,2302,2310,2320-2321,2500,2502,250c,2510,2514,2518,251c,2524,252c,2534,253c,2550-256c,2580,2584,2588,258c,2590-2593,25a0-25a1,25aa-25ac,25b2,25ba,25bc,25c4,25ca-25cb,25cf,25d8-25d9,25e6,263a-263c,2640,2642,2660,2663,2665-2666,266a-266b,f001-f002,f004-f005,fb01-fb02", license = "Author's published terms at the source page (no licence text in the download)", licenseFile = "Media/Banzai/Fonts/FONT-NOTICES.txt", attribution = "Gang of Three by Vic Fieger.", distributionAuthorization = "Shipped unmodified; Darren approved distribution inside BanzaiSland for the Retail release." },
	OSAKA_SANS = { label = "Osaka Sans", author = "Not identified in the download archive", sourceUrl = "https://www.1001fonts.com/osaka-sans-serif-font.html", file = "osaka-re.ttf", cmapCount = 248, ranges = "20-7e,a0-a3,a5-ae,b0-ff,131,141-142,152-153,160-161,178,17d-17e,192,2c6-2c7,2c9,2d8-2dd,37e,2013-2014,2018-201a,201c-201e,2020-2022,2026,2030,2039-203a,2044,20ac,2122,2126,2202,2206,220f,2211-2212,2215,2219-221a,221e,222b,2248,2260,2264-2265,25ca,f001-f002,fb01-fb02", license = "1001Fonts Free For Commercial Use licence (supplied EULA)", licenseFile = "Media/Banzai/Fonts/OsakaSans-1001fonts-FFC-EULA.txt", attribution = "Osaka-Sans Serif; see the supplied 1001Fonts FFC EULA.", distributionAuthorization = "Shipped unmodified with the supplied EULA; Darren approved distribution inside BanzaiSland for the Retail release." },
	SEKAIWO = { label = "Sekaiwo", author = "Tkzgraphic", sourceUrl = "https://www.1001fonts.com/sekaiwo-font.html", file = "Sekaiwo-Regular.otf", cmapCount = 238, ranges = "20-7e,a0-ff,131,300-304,307-308,30a,30c,327,2013-2014,2018-201a,201c-201e,2020-2022,2026,2039-203a,2044,20a3-20a4,20a7,20ac,2116,2122,2202,2206,220f,2211-2212,2215,2219-221a,221e,222b,2248,2264-2265,fb01-fb02", license = "Free for personal and commercial use (author READ ME)", licenseFile = "Media/Banzai/Fonts/Sekaiwo-READ-ME.txt", attribution = "Sekaiwo by Tkzgraphic.", distributionAuthorization = "Shipped unmodified with the supplied READ ME; Darren approved distribution inside BanzaiSland for the Retail release." },
	XANGDA_SHINY = { label = "Xangda Shiny", author = "starinkbrush", sourceUrl = "https://www.dafont.com/xangda-shiny.font", file = "Xangda Shiny.ttf", cmapCount = 55, ranges = "20,41-5a,61-7a", license = "Author's published terms at the source page (no licence text in the download)", licenseFile = "Media/Banzai/Fonts/FONT-NOTICES.txt", attribution = "Xangda Shiny by starinkbrush.", distributionAuthorization = "Shipped unmodified; Darren approved distribution inside BanzaiSland for the Retail release." },
	NINJA_NARUTO = { label = "Ninja Naruto", author = "sk89q / The Risen Realm", sourceUrl = "https://resourceboy.com/fonts/ninja-naruto-font/", file = "njnaruto.ttf", cmapCount = 96, ranges = "20-7e,2010", license = "Free distribution unmodified (supplied readme)", licenseFile = "Media/Banzai/Fonts/NinjaNaruto-readme.txt", attribution = "Ninja Naruto by sk89q; The Risen Realm / Keiichi Anime Forever. Original type credited to Kishimoto Masashi, Shueisha, TV Tokyo.", distributionAuthorization = "Shipped unmodified and free of charge under the supplied readme; Darren approved distribution inside BanzaiSland for the Retail release." },
	INFORMATION = { label = "Information Font", author = "The Open Sans Project Authors", sourceUrl = "https://github.com/googlefonts/opensans", license = "Apache License 2.0 and SIL Open Font License 1.1", licenseFile = "Media/Fonts/LICENSE-OpenSans-Apache-2.0.txt", licenseFiles = { "Media/Fonts/LICENSE-OpenSans-Apache-2.0.txt", "Media/Fonts/OFL.txt" }, informationFile = "Media/Fonts/OpenSans-ExtraBold.ttf", sourceSha256 = "0fcbdb5cbeea00ae532352c7c94a7d288ebc911ba85f4d595012032dcab64ba8", information = true, attribution = "Copyright The Open Sans Project Authors; see the Apache-2.0 and OFL notices.", distributionAuthorization = "Existing Information Font retained under its preserved notices; Darren approved it as the explicit/fallback face." },
}
local SOURCE_SHA256 = {
	SHOJUMARU = "8607110ef45da664861c72d95fb804c3609169ebfd2a380cb47b353a7b241c75",
	RYUJIN_ATTACK = "a6d8aa6b08da6bef1b7a94f574dd92983477b1f282c94b350956578f627c06ac",
	GANG_OF_THREE = "8bb0d23e78dc94851b86732c28b9e0da1724893ba9301483bfdfcea50c19fac4",
	OSAKA_SANS = "79f10ac3196dcdb5925504315c648cab9df286994da4f8d49156e016d01f5d4d",
	SEKAIWO = "c3d71f31790becff50f42292d8edcb3123ac0a165c8ff196d6795e5eae17ccb6",
	XANGDA_SHINY = "13d7561e1a52658f7bbec8e12282f629c9ada5c00bc0b88b7d51ef1c9dadb87f",
	NINJA_NARUTO = "d7dac597f70d9e53bc6617e364c5f4e705767ea8be2c678995249cfe179d9335",
}
local REQUIRED_COVERAGE = {
	SHOJUMARU = 333, RYUJIN_ATTACK = 187, GANG_OF_THREE = 333, OSAKA_SANS = 214, SEKAIWO = 206, XANGDA_SHINY = 53, NINJA_NARUTO = 95,
}
local ORDER = { "auto", "BANZAI_DEFAULT", "SHOJUMARU", "RYUJIN_ATTACK", "GANG_OF_THREE", "OSAKA_SANS", "SEKAIWO", "XANGDA_SHINY", "NINJA_NARUTO", "INFORMATION" }

local function parseRanges(source)
	local ranges = {}
	for item in source:gmatch("[^,]+") do
		local first, last = item:match("^([%da-f]+)%-([%da-f]+)$")
		if first then ranges[#ranges + 1] = { tonumber(first, 16), tonumber(last, 16) }
		else local point = tonumber(item, 16) ranges[#ranges + 1] = { point, point } end
	end
	return ranges
end
for id, face in pairs(REGISTRY) do
	if face.ranges then face.cmap = parseRanges(face.ranges) end
	face.sizeAdjust, face.baselineAdjust, face.launcherSizeAdjust = face.sizeAdjust or 0, face.baselineAdjust or 0, face.launcherSizeAdjust or 0
	face.sourceSha256 = SOURCE_SHA256[id] or face.sourceSha256
	face.requiredCoverage = REQUIRED_COVERAGE[id]
	face.minimumPracticalSize = face.minimumPracticalSize or 10
	face.outline = face.outline or "profile"
end

local DEFAULT_FACE = "SHOJUMARU"
local DEFAULT_SCALE = 1.05
local DEFAULT_KEY = "SHOJUMARU"
-- saved choices from the private bake-off that no longer ship (and the legacy "on" switch): the semantic default
local RETIRED = {
	ON = "BANZAI_DEFAULT", WANTBANZAI = "BANZAI_DEFAULT", WANTCOFFEE = "BANZAI_DEFAULT",
	CHANG_CHANG_WOODCUT = "BANZAI_DEFAULT", ROOTS_OF_CHINA = "BANZAI_DEFAULT", ODISHI = "BANZAI_DEFAULT",
}
Theme.BANZAI_DEFAULT = DEFAULT_KEY
Theme.BANZAI_DEFAULT_SCALE = DEFAULT_SCALE
local LATIN_LOCALES = { enUS = true, enGB = true, deDE = true, esES = true, esMX = true, frFR = true, itIT = true, ptBR = true }
local function defaultFace()
	return REGISTRY[DEFAULT_KEY] and DEFAULT_KEY or DEFAULT_FACE
end
local function resolved(value)
	if value == "auto" then
		return LATIN_LOCALES[ns.LOCALE or (GetLocale and GetLocale()) or "enUS"] and defaultFace() or "INFORMATION"
	end
	if value == "BANZAI_DEFAULT" or value == "default" then return defaultFace() end
	if value == "off" or value == "information" then return "INFORMATION" end
	if type(value) == "string" and RETIRED[value:upper()] then return defaultFace() end
	if REGISTRY[value] then return value end
	return DEFAULT_FACE
end

local function nextCodepoint(text, index)
	local a, b, c, d = string.byte(text, index, index + 3)
	if not a then return nil end
	if a < 0x80 then return a, 1 end
	if a >= 0xC2 and a <= 0xDF and b and b >= 0x80 and b <= 0xBF then return (a - 0xC0) * 0x40 + b - 0x80, 2 end
	if a >= 0xE0 and a <= 0xEF and b and c and b >= 0x80 and b <= 0xBF and c >= 0x80 and c <= 0xBF
		and not (a == 0xE0 and b < 0xA0) and not (a == 0xED and b >= 0xA0) then
		return (a - 0xE0) * 0x1000 + (b - 0x80) * 0x40 + c - 0x80, 3
	end
	if a >= 0xF0 and a <= 0xF4 and b and c and d and b >= 0x80 and b <= 0xBF and c >= 0x80 and c <= 0xBF and d >= 0x80 and d <= 0xBF
		and not (a == 0xF0 and b < 0x90) and not (a == 0xF4 and b > 0x8F) then
		return (a - 0xF0) * 0x40000 + (b - 0x80) * 0x1000 + (c - 0x80) * 0x40 + d - 0x80, 4
	end
	return nil
end
local function supports(face, text)
	if text == nil then return true end
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return false end
	local index = 1
	while index <= #text do
		local cp, width = nextCodepoint(text, index)
		local found = false
		if cp == 10 or cp == 13 then
			found = true
		elseif cp and face.cmap then
			for _, range in ipairs(face.cmap) do
				if cp < range[1] then break end
				if cp <= range[2] then found = true break end
			end
		end
		if not found then return false end
		index = index + (width or 1)
	end
	return true
end
local function coverage(face, text)
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return nil end
	if face.information then return nil end
	local covered, total, index = 0, 0, 1
	while index <= #text do
		local cp, width = nextCodepoint(text, index)
		if not cp then
			total = total + 1
			index = index + 1
		else
			if cp ~= 10 and cp ~= 13 then
				total = total + 1
				if face.cmap then
					for _, range in ipairs(face.cmap) do
						if cp < range[1] then break end
						if cp <= range[2] then covered = covered + 1 break end
					end
				end
			end
			index = index + width
		end
	end
	return covered, total
end

Theme.FONT_REGISTRY = REGISTRY
Theme.DISPLAY_FONTS = ORDER
Theme.DISPLAY_FONT_LABELS = {
	auto = "Automatic", BANZAI_DEFAULT = "BANZAI Default",
}
for id, face in pairs(REGISTRY) do Theme.DISPLAY_FONT_LABELS[id] = face.label end

function Theme.SelectedDisplayFont()
	local db = ns.db
	local value = db and db.displayFont or "BANZAI_DEFAULT"
	local normalized = resolved(value)
	if db then Theme.NormalizeDisplayFont(db) end
	return normalized
end
function Theme.DisplayFontOn()
	return Theme.SelectedDisplayFont() ~= "INFORMATION"
end
function Theme.DisplayFontPath(text)
	local id = Theme.SelectedDisplayFont()
	local face = REGISTRY[id]
	if face.information or not supports(face, text) then return nil end
	return ROOT .. face.file
end
function Theme.DisplayFontScale(text)
	local choice = ns.db and ns.db.displayFont
	local selected = Theme.SelectedDisplayFont()
	if (choice == "BANZAI_DEFAULT" or (choice == "auto" and selected == DEFAULT_KEY)) and Theme.DisplayFontPath(text) then return DEFAULT_SCALE end
	return 1
end
function Theme.NormalizeDisplayFont(db)
	if type(db) ~= "table" then return end
	local value = db.displayFont
	if value == nil then db.displayFont = "BANZAI_DEFAULT"
	elseif type(value) == "string" and (RETIRED[value:upper()] or value:lower() == "default") then db.displayFont = "BANZAI_DEFAULT"
	elseif value ~= "auto" and value ~= "off" and value ~= "information" and value ~= "BANZAI_DEFAULT" and not REGISTRY[value] then db.displayFont = "BANZAI_DEFAULT"
	elseif value == "off" or value == "information" then db.displayFont = "INFORMATION" end
end
function Theme.DisplayFontInfo(text)
	local id = Theme.SelectedDisplayFont()
	local face = REGISTRY[id]
	local ok = face.information or supports(face, text)
	local covered, total = coverage(face, text)
	return {
		id = id, name = face.label, group = face.group,
		author = face.author,
		source = face.sourceUrl or "BANZAI information font",
		file = face.file and (ROOT .. face.file) or face.informationFile or "Profile information font",
		license = face.license,
		licenseFile = face.licenseFile,
		licenseFiles = face.licenseFiles,
		attribution = face.attribution,
		distributionAuthorization = face.distributionAuthorization,
		sourceSha256 = face.sourceSha256,
		cmapCount = face.cmapCount,
		coverage = covered and (covered .. "/" .. total .. " sample codepoints") or "Information Font",
		requiredCoverage = face.requiredCoverage and (face.requiredCoverage .. "/335 required codepoints") or "product Information Font",
		fallback = not ok, status = ok and face.label or "Information Font (fallback)", metadata = face,
	}
end
function Theme.DisplayFontLabel(value)
	if value == "auto" then
		local default = REGISTRY[defaultFace()]
		if Theme.DisplayFontOn() then return "Automatic (" .. default.label .. ")" end
		return "Automatic (Information Font)"
	end
	if value == "BANZAI_DEFAULT" or value == "default" or value == "on" then return "BANZAI Default (" .. REGISTRY[defaultFace()].label .. ")" end
	if value == "off" or value == "information" then return REGISTRY.INFORMATION.label end
	return Theme.DISPLAY_FONT_LABELS[value] or REGISTRY.INFORMATION.label
end

local media = LibStub and LibStub("LibSharedMedia-3.0", true)
if media and media.Register then
	for _, face in pairs(REGISTRY) do
		if face.file then media:Register("font", "BANZAI " .. face.label, ROOT .. face.file, media.LOCALE_BIT_western) end
	end
end
