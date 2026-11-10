# Third-party notices

BanzaiSland is a GPLv3 fork of Island by Devin/subtlegrind. BanzaiSland is independently maintained and is not supported by the upstream Island author. This file lists everything bundled with BanzaiSland that BanzaiSland did not write, with its licence and where the notice lives in the addon folder.

## Island 3.7.0 (upstream)

| | |
|---|---|
| Work | Island, "A Dynamic Island for WoW", version 3.7.0 |
| Author | Devin (CurseForge account `subtlegrind`) |
| Licence | GNU General Public License v3 (`addons/BanzaiSland/LICENSE`, `addons/BanzaiSland/LICENSING.md`) |
| Scope | the 48 Lua modules, the 10 locale files, `Bindings.xml`, the 64 glyph textures and corner atlases in `Media/`, `docs/EXTENSIONS.md`, `docs/DEVELOPER.md`, `CHANGELOG.md`, the translation `README.md` |
| Changes | listed in `CHANGES-FROM-ISLAND.md`; every derived Lua file keeps its upstream header comment |

## Open Sans (bundled by upstream Island; the BanzaiSland Information Font)

| | |
|---|---|
| Work | Open Sans, Copyright The Open Sans Project Authors (https://github.com/googlefonts/opensans) |
| Files | `Media/Fonts/OpenSans-Medium.ttf`, `OpenSans-Bold.ttf`, `OpenSans-ExtraBold.ttf` |
| Licence | `OpenSans-Medium.ttf`: SIL Open Font License 1.1 (`Media/Fonts/OFL.txt`); `OpenSans-Bold.ttf`, `OpenSans-ExtraBold.ttf`: Apache License 2.0 (`Media/Fonts/LICENSE-OpenSans-Apache-2.0.txt`); see `Media/Fonts/CREDITS.txt` |
| Use | all small information text: timers, percentages, values, captions, secondary text, compact details, and the display-font fallback |

## Shojumaru (BANZAI Default display face)

| | |
|---|---|
| Work | Shojumaru Regular, Copyright (c) 2012 Brian J. Bonislawsky DBA Astigmatic (AOETI), with Reserved Font Name "Shojumaru" |
| File | `Media/Banzai/Fonts/Shojumaru-Regular.ttf`; SHA-256 `8607110ef45da664861c72d95fb804c3609169ebfd2a380cb47b353a7b241c75` |
| Source | https://www.1001fonts.com/shojumaru-font.html |
| Licence | SIL Open Font License 1.1 (`Media/Banzai/Fonts/OFL.txt`). Preserve the copyright and reserved-name notice; do not sell the font by itself. |
| Selection | Darren approved Shojumaru as BANZAI Default for the Retail release. Redistribution is under the OFL terms, not a separate public-domain grant. |

## Alternate display faces (selectable in Appearance > Display font)

Each file is the unmodified font as downloaded; the licence or readme text supplied in its download is reproduced verbatim beside it in `Media/Banzai/Fonts/`, and `Media/Banzai/Fonts/FONT-NOTICES.txt` records author, source and SHA-256 for every face. None of these fonts is claimed to be public domain; each remains the property of its author. The BANZAI project owner approved shipping them inside BanzaiSland for the Retail release.

| Face | File (SHA-256) | Author / source | Supplied terms |
|---|---|---|---|
| Ryujin Attack | `RyujinAttack.otf` (`a6d8aa6b08da6bef1b7a94f574dd92983477b1f282c94b350956578f627c06ac`) | Jetsmax - https://www.1001fonts.com/ryujin-attack-font.html | `RyujinAttack-README.txt`: free to use; no further licence text in the download |
| Gang of Three | `go3v2.ttf` (`8bb0d23e78dc94851b86732c28b9e0da1724893ba9301483bfdfcea50c19fac4`) | Vic Fieger - https://www.1001fonts.com/gang-of-three-font.html | no licence text in the download; the author's terms are those published at the source page |
| Osaka Sans | `osaka-re.ttf` (`79f10ac3196dcdb5925504315c648cab9df286994da4f8d49156e016d01f5d4d`) | author not identified in the archive - https://www.1001fonts.com/osaka-sans-serif-font.html | `OsakaSans-1001fonts-FFC-EULA.txt`: 1001Fonts Free For Commercial Use licence (unmodified, not sold) |
| Sekaiwo | `Sekaiwo-Regular.otf` (`c3d71f31790becff50f42292d8edcb3123ac0a165c8ff196d6795e5eae17ccb6`) | Tkzgraphic - https://www.1001fonts.com/sekaiwo-font.html | `Sekaiwo-READ-ME.txt`: free for personal and commercial use |
| Xangda Shiny | `Xangda Shiny.ttf` (`13d7561e1a52658f7bbec8e12282f629c9ada5c00bc0b88b7d51ef1c9dadb87f`) | starinkbrush - https://www.dafont.com/xangda-shiny.font | no licence text in the download; the author's terms are those published at the source page. Letters only: strings with digits use the Information Font |
| Ninja Naruto | `njnaruto.ttf` (`d7dac597f70d9e53bc6617e364c5f4e705767ea8be2c678995249cfe179d9335`) | sk89q / The Risen Realm and Keiichi Anime Forever - https://resourceboy.com/fonts/ninja-naruto-font/ | `NinjaNaruto-readme.txt`: personal or commercial use; distribute unmodified and free of charge; not sold, not modified. The readme credits the original type to Kishimoto Masashi, Shueisha, TV Tokyo |

Only the display faces documented above are included in this release.

## BANZAI-owned materials (not third-party; listed for completeness)

Owner: Darren (BANZAI UI). Imported from the BANZAI UI source build by `tools/fork/import-banzai-assets.js`; each file's SHA-256 and origin are in `assets/banzai-assets.json` and `SOURCE-PROVENANCE.md`.

- `Media/Banzai/Identity/*.tga` (13): original BANZAI class identity artwork, generated for BANZAI with Gemini; not Blizzard art, no Blizzard icon used as a source. Provenance manifest: `Media/Banzai/Identity/class-provenance.json`.
- `Media/Banzai/Stalk.tga`, `StalkEnd.tga`, `RopeTie.tga`: bamboo construction textures.
- `Media/Banzai/ParchmentTile.tga`, `ParchmentEdge.tga`, `ParchmentCorners.tga`: the Hardkorh parchment material (the corrected, non-stretched tiled architecture of BANZAI UI 1.3.7).
- `Media/Banzai/BanzaiIcon.tga`: the BANZAI **B** logo (addon icon, settings header).
- `Media/Banzai/BanzaiWordmark.tga`: the BANZAI bamboo wordmark, BANZAI UI's own identity, used as the BANZAI half of the integrated BANZAI SLAND mark.

## World of Warcraft

World of Warcraft and Blizzard Entertainment are trademarks or registered trademarks of Blizzard Entertainment, Inc. BanzaiSland bundles no Blizzard assets; it references the game's own textures (`Interface\Icons\...`) by path only, as any addon does.
