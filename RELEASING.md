# Releasing BanzaiSland

Stable releases publish only when a `vX.Y.Z` tag is pushed. Update both add-on TOC versions and the release notes to the same version, validate the addon on supported clients, commit the changes, and push the annotated tag.

The GitHub Action verifies the tag/version match, packages the `BanzaiSland` folder at the ZIP root using BigWigs Packager, creates a GitHub Release, and uploads the ZIP to CurseForge project `1793377` and Wago project `QN5JMd6B`. It ignores the existing `v1.0.0` release and earlier versions. Commits since the prior tag provide the generated release changelog. GPLv3, upstream attribution, font notices, and addon runtime assets remain in the packaged folder.

Required repository Actions secrets: `CF_API_KEY` and `WAGO_API_TOKEN`. GitHub Releases use the workflow's `GITHUB_TOKEN` with `contents: write`. See the repository Settings > Secrets and variables > Actions page; never put token values in source or logs.
