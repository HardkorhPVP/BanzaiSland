## BanzaiSland 1.0.0

First public release of BanzaiSland for World of Warcraft Retail.

### What is in it
- The island: XP / reputation progression, level-up card with class identity, cards, bubbles with timer rings, pins, +n chip, warning dot, error pill.
- Prompts for ready check, invite, loot roll, duel, summon and release / resurrect that press the game's own secure buttons out of combat.
- Bamboo or Hairline chassis; Banzai Glass, Solid or Hardkorh Parchment (dedicated INK palette, ≥ 4.5:1 contrast on the darkest grain, thirteen class inks); Banzai, Class or Hardkorh accent.
- The integrated BANZAI SLAND launcher: BANZAI opens BANZAI UI's settings when BANZAI UI is installed, SLAND opens BanzaiSland's.
- Settings window with Appearance, Card Builder, Preview, Sounds, Notifications, Bubbles, Activities, Supported Addons, Extensions, Controls, General, Profiles, About & Credits.
- Display-font selection: **BANZAI Default = Shojumaru at 105 %**, with Automatic, Ryujin Attack, Gang of Three, Osaka Sans, Sekaiwo, Xangda Shiny, Ninja Naruto and the Information Font (Open Sans ExtraBold). Fonts the game cannot show fall back, whole-string, to the Information Font.
- Font notices and SHA-256 per file in `Media/Banzai/Fonts/FONT-NOTICES.txt`.

### Changed since 0.3.0-dev
- The display-font set is final; any earlier saved selection of a font that no longer ships becomes BANZAI Default.
- Public documentation, credits and licence notices.

### Compatibility
- World of Warcraft Retail, Interface 120105. Retail only in this release.
- No required dependencies. BANZAI UI optional (integrated launcher).
- Conflict: the original Island addon must be disabled.
- Saved variables: `BanzaiSlandDB`, `BanzaiSlandCharDB`.

### Known limitations
- WoW Forever is not supported by this release; it is the next milestone. On a Forever client the AddOns screen currently shows BanzaiSland as Incompatible.
- Prompt buttons wait while you are in combat; the game's own pop-up still works.

### Install
Unzip; put the `BanzaiSland` folder into `Interface\AddOns\` of your Retail client. `/bsl` opens the settings.

### Integrity
`BanzaiSland-1.0.0.zip` SHA-256 `025060d0201e11dabb58ae971170a8c3cf25c6a0cd329bcc5a910eee78914e34`

BanzaiSland is a GPLv3 fork of Island by Devin/subtlegrind. BanzaiSland is independently maintained and is not supported by the upstream Island author. Licence: GPLv3.
