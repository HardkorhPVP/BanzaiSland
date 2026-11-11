# BanzaiSland

**Live information. Zero clutter.** A BANZAI-themed contextual activity HUD for World of Warcraft Retail and Forever.

One small island at the top centre of your screen shows your XP or reputation, opens into cards when something happens - loot, rolls, invites, ready checks, resurrection, summons, alerts, zone changes, dungeon runs, vendor visits, group changes - carries your timers as bubbles with draining rings, and lets you answer ready checks, invites, loot rolls, duels, summons and release / resurrect right there. The buttons press the game's own secure buttons, out of combat only, never on their own.

Two chassis (**Bamboo**, **Hairline**), three materials (**Banzai Glass**, **Solid**, **Hardkorh Parchment** with its own ink palette), three accents (**Banzai**, **Class**, **Hardkorh**), Darren's original class identity artwork, a display-font selector, profiles per character, a Preview page of synthetic scenarios and an extension API (`BanzaiSlandAPI` v1). With **BANZAI UI** installed, the **BANZAI SLAND** launcher on the island opens either addon's settings.

Settings: `/bsl`. Preview: `/bsl preview`. Status: `/bsl status`.

**1.0.1:** Retail 12.1.5 (Interface 120105) and Forever 1.60.1 (Interface 16001), using one shared source tree. Both clients select `BanzaiSland_Mainline.toc`, which declares both interfaces; `BanzaiSland.toc` remains a dual-interface fallback. The complete 1.0.1 package passed final real-client Forever validation; affected Retail and Forever simulations passed. No required dependencies. **Do not run the original Island addon at the same time** - BanzaiSland refuses to run beside it and says so in one chat line.

> BanzaiSland is a GPLv3 fork of Island by Devin/subtlegrind. BanzaiSland is independently maintained and is not supported by the upstream Island author.

Licence: GNU General Public License v3. Issues: https://github.com/HardkorhPVP/BanzaiSland/issues · Discord: https://discord.gg/sv2WNwk2WZ

### Install

1. Disable the original Island if you have it.
2. With WoW closed, unzip and copy the `BanzaiSland` folder into the selected client's AddOns folder: `World of Warcraft\_retail_\Interface\AddOns\` or `World of Warcraft\_forever_\Interface\AddOns\`.
3. Start the game, enable **BanzaiSland**, log in and type `/bsl`.

---

## Documentation

- [Installation](docs/INSTALLATION.md) · [Getting started](docs/GETTING-STARTED.md) · [Appearance](docs/APPEARANCE.md)
- [Cards](docs/CARDS.md) · [Bubbles](docs/BUBBLES.md) · [Interactive prompts](docs/INTERACTIVE-PROMPTS.md)
- [FAQ](docs/FAQ.md) · [Troubleshooting](docs/TROUBLESHOOTING.md) · [Support](docs/SUPPORT.md)
- [Credits](docs/CREDITS.md) · [Third-party notices](THIRD_PARTY_NOTICES.md) · [Source provenance](SOURCE-PROVENANCE.md)
- [Changes from Island](CHANGES-FROM-ISLAND.md) · [Upstream baseline](UPSTREAM.md)
- [1.0.1 release notes](release-notes/BANZAISLAND-1.0.1.md) · [1.0.0 release notes](release-notes/BANZAISLAND-1.0.0.md)

The addon folder is the complete source corresponding to the released package.
