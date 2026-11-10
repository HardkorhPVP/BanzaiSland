# Extensions guide

Other addons can send their own cards and bubbles through BanzaiSland, so everything you are told arrives in one place, in one style. These are **extensions**.

## For players

- **Settings › Extensions** lists every extension that has registered with BanzaiSland. Each can be turned on or off, and each may offer its own options (which of its cards to show, how often).
- An extension's cards look like any other BanzaiSland card and follow your material, chassis and accent.
- Extensions are **rate-limited**: a misbehaving one cannot flood the island.
- An extension can never read protected game data through BanzaiSland and never presses anything for you.

### Supported addons

**Settings › Supported Addons** is different: these are addons BanzaiSland already knows how to work with, with their options in one place. Only the ones you have installed appear.

| Addon | What BanzaiSland does with it |
|---|---|
| RestedXP Guides | shows the current step and a navigation pill |
| Polestar | guide arrow and bubble |
| TomTom | waypoint arrow / distance pill |
| Spoken | voiceover cards with a Stop button |
| Pigeon | whispers as cards |
| RareScanner | rare sightings as cards |
| Pawn, ItemTree, Lootified | upgrade detection for looted items |
| ElvUI, EllesmereUI | the island registers as a mover in their edit modes |

### Packages (off by default; not available in this Retail release)

BanzaiSland can run small **packages** - saved text that registers as an extension. This is developer territory: packages run user-supplied code in a sandbox and only after you switch **Allow package code** on under General. The switch is off unless you turn it on, and packages do not run on Retail; they belong to the WoW Forever milestone that follows this release.

## For addon authors

BanzaiSland exposes `BanzaiSlandAPI` (version 1). In outline:

- **Register** your extension with an id, a name and the kinds of card and bubble you send.
- **Send a card**: a caption, a title, an optional result, line, icon or glyph, tone and hold time. BanzaiSland lays it out and colours it for the active material (on Hardkorh Parchment your colours become readable inks automatically).
- **Send a bubble**: a glyph, a tone, a text function and optionally a bar function (0..1).
- **Features**: declare switches and options; BanzaiSland shows them on the Extensions page and tells you when they change.
- **Readiness**: ask whether the island is built before sending.
- **Limits**: a few cards per minute per extension; payloads that carry protected values are refused.

Mark your TOC with `## X-BanzaiSland-Extension: <id>` so BanzaiSland lists you even before you send anything.

The full reference with every field and example code is `docs/EXTENSIONS.md` inside the addon folder (upstream Island's extension documentation, which BanzaiSland keeps compatible with the namespaced API).

## BANZAI UI

BANZAI UI is not an extension; it is a companion. The integrated launcher between the two is described in [BANZAI-INTEGRATION.md](BANZAI-INTEGRATION.md).
