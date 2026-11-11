# Known issues

Current as of BanzaiSland 1.0.1. This list is kept honest: if it is not here, we do not know about it - tell us ([SUPPORT.md](SUPPORT.md)).

## Forever validation

- The 1.0.1 Mainline dual-interface correction and complete final-font package passed final real-client Forever 1.60.1 validation. The published 1.0.0 package remains Retail-only and unchanged.
- When upgrading the Forever development build, replace its addon folder rather than merging; otherwise retired font files can remain on disk.

## Behaviour to know about

- **Buttons wait in combat.** The game forbids addons from pressing protected buttons during combat; prompt cards show, their buttons are live again when combat ends. The game's own pop-up still works meanwhile. This is by design and cannot be changed by an addon.
- **Retail protected values.** On Retail 12.x some aura and loot details are protected from addons. BanzaiSland shows what it is allowed to and never guesses; a buff pill or loot card may carry less detail than you might expect.
- **Display face on unsupported strings.** *Automatic* uses BANZAI Default only when the complete display string is supported; otherwise it uses the Information Font. An explicitly chosen alternate does the same for any string it cannot show (*Xangda Shiny* has letters only). The font is not spliced character by character.
- **Talking Head mirroring (Retail)** hides the game's Talking Head visuals by transparency while showing the card; if a patch changes that frame, turn the mirror off under Notifications › Talking Head until an update.
- **Profile change needs a reload.** Picking another profile applies at the reload the game asks for.
- **Extension packages are off by default and do not run on Retail.** They run user-supplied code in a sandbox; leave *Allow package code* off unless you wrote the package.

## Compatibility

- **Original Island:** must not run at the same time (BanzaiSland stays off and says so).
- **BANZAI UI older than 1.3.8:** both launchers show at the top centre; turn BANZAI UI's wordmark off yourself or update BANZAI UI.
- **Other XP-bar / notification addons:** two addons answering the same ready check or hiding the same game frame may collide; disable one.

## Fixed in 0.3.0-dev

- Hardkorh Parchment text that read too bright or washed on the paper's darker grain: the whole ink palette was retuned, every class colour has its own dark ink (Priest a dark silver), and every ink is now checked against the paper's darkest grain, not just its average. Glass and Solid are unchanged.
