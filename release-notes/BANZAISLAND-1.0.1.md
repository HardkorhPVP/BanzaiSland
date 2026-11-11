# BanzaiSland 1.0.1 - release candidate

- First Forever-capable update: Retail 12.1.5 and Forever 1.60.1 use the same addon source and package.
- Fix the selected Mainline TOC to declare `120105, 16001`. This correction passed a real Forever development-build test; changing only the fallback TOC was insufficient.
- Carry the final Retail 1.0.0 font system into the Forever package unchanged. BANZAI Default is Shojumaru at 105%. Automatic, BANZAI Default, Shojumaru, Ryujin Attack, Gang of Three, Osaka Sans, Sekaiwo, Xangda Shiny, Ninja Naruto and Information Font remain selectable, with whole-string fallback.
- Retired Want Coffee, Want Banzai, Chang Chang Woodcut, Roots of China and Odishi choices migrate to BANZAI Default. Their font files are not shipped. Replace the old development addon folder rather than merging files.
- Glass, Solid, Hardkorh Parchment and its ink palette, chassis, cards, bubbles, timer rings, prompts, settings, profiles, class artwork and launcher geometry are unchanged from final Retail 1.0.0.
- No required dependencies. The original Island addon must remain disabled.

The complete 1.0.1 candidate is not published and requires final live Forever validation. No current release is replaced or rebuilt. The existing stable-tag GitHub workflow and CurseForge/Wago project IDs are retained.

## Offline validation

- 26 affected Retail/Forever simulation runs: 2,124 assertions passed after updating two old version expectations to 1.0.1; no runtime failures.
- Additional final-alternate/retired-profile upgrade regression: 30 assertions passed on each client.
- Source-controlled TOC regression passed. Both clients were simulated with the selected Mainline TOC, not the fallback.
- Local package audit: 168 files, one `BanzaiSland` root, every packaged file matches its build manifest, seven display faces plus three Information Font weights, all font hashes/notices preserved, no retired font binaries.
- All runtime Lua and visual/font assets match the final Retail source. Relative to the accepted 1.0.0 ZIP, 66 text files differ only in Git checkout line endings; two notices/provenance files retain the already-approved public sanitization. No visuals or runtime logic were redesigned.

BanzaiSland is a GPLv3 fork of Island by Devin/subtlegrind. It is independently maintained and is not supported by the upstream Island author.
