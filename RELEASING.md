# Releasing BanzaiSland

Stable releases publish only when a `vX.Y.Z` tag is pushed. Update both add-on TOC versions and the release notes to the same version, validate the addon on supported clients, commit the changes, and push the annotated tag.

The GitHub Action verifies the tag/version match, packages the `BanzaiSland` folder at the ZIP root using BigWigs Packager, creates a GitHub Release, and uploads the ZIP to CurseForge project `1793377` and Wago project `QN5JMd6B`. It ignores the existing `v1.0.0` release and earlier versions. Commits since the prior tag provide the generated release changelog. GPLv3, upstream attribution, font notices, and addon runtime assets remain in the packaged folder.

Required repository Actions secrets: `CF_API_KEY` and `WAGO_API_TOKEN`. GitHub Releases use the workflow's `GITHUB_TOKEN` with `contents: write`. See the repository Settings > Secrets and variables > Actions page; never put token values in source or logs.

## 1.0.1 Retail / Forever release

Both TOCs must declare version `1.0.1` and interfaces `120105, 16001` (order is immaterial). Forever is in the Mainline family and selects `BanzaiSland_Mainline.toc` ahead of the unsuffixed fallback. Do not narrow the Mainline interface to Retail again; the dual-interface line has passed a real Forever 1.60.1 test.

The addon source already contains the final 1.0.0 font registry, seven approved display faces and their notices. BANZAI Default is Shojumaru at 105%; retired saved font choices migrate to that default. No development-build font files should be overlaid onto this source.

Before tagging, validate Retail and Forever simulations using the selected Mainline TOC, font selection/fallback and profile migration, materials, launcher, fresh install and upgrade. Audit the package against the addon source, including both TOCs and all font hashes/notices. Validate the complete candidate in the actual Forever client; the earlier TOC-only PASS does not replace this check. Keep the existing 1.0.0 release and its asset unchanged.

For 1.0.1, final live validation and publication approval were received on 2026-11-10 as `FOREVER BANZAISLAND PASS`. The validated runtime commit is `2b971fb`; release-finalization documentation must not change its addon files. Both required repository secret names are configured; never read or expose their values.

Run `node --test tests/toc.test.js` for the source-controlled TOC/interface regression check. Tests are excluded from the automation package.
