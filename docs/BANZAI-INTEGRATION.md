# BanzaiSland and BANZAI UI

**BANZAI UI is optional.** BanzaiSland is complete on its own. If you also run BANZAI UI, the two are designed to sit together at the top centre of the screen as one identity.

## The BANZAI SLAND launcher

The island's top edge carries the **BANZAI SLAND** mark - the BANZAI bamboo wordmark and *SLAND* in the display font you chose (BanzaiSland's own choice; BANZAI UI's font setting is separate). It is one mark with two halves you can click:

- **BANZAI** → opens **BANZAI UI's settings** (on its Home page). Not in combat; a short line in chat says so.
- **SLAND** → opens **BanzaiSland's settings**.

Point at either half for a tooltip. The BANZAI half glows faintly on hover; SLAND brightens.

### Without BANZAI UI

The mark is still there - it is BanzaiSland's identity. Clicking BANZAI says once, in chat, that BANZAI UI is not installed. Nothing else changes.

## One launcher, not two

BANZAI UI has its own small BANZAI wordmark at the top centre, which opens its settings. From **BANZAI UI 1.3.8** the two addons agree on who presents it:

- While BanzaiSland is showing the integrated BANZAI SLAND mark, **BANZAI UI's standalone wordmark steps aside**. You see one launcher.
- When BanzaiSland does not have room for the mark - a very small idle island style such as *Dot* or *Percent* - **BANZAI UI may resume its standalone wordmark** until the mark returns.
- When BanzaiSland is **disabled**, blocked by the original-Island conflict, or not installed, BANZAI UI behaves exactly as before: its own **BANZAI logo** setting (BANZAI › Appearance › Branding) decides.

Your **BANZAI logo** setting in BANZAI UI is never changed by BanzaiSland. Turn it off and it stays off; leave it on and the wordmark simply waits while BanzaiSland hosts the launcher.

The hand-over happens instantly, in either load order, with no polling - and nothing of BANZAI UI's frames or saved settings is touched by BanzaiSland.

## Requirements

| | |
|---|---|
| BanzaiSland | 1.0.0 (the hand-over has been part of BanzaiSland since 0.2.1) |
| BANZAI UI | **1.3.8** or newer - BANZAI UI 1.4.0 is the matching release (older BANZAI UI still works: both launchers show, and you can turn its wordmark off in BANZAI › Appearance › BANZAI logo yourself) |

## Looks

The BANZAI half keeps BANZAI UI's own bamboo wordmark colours; SLAND is violet on Glass and Solid and a deep plum ink on Hardkorh Parchment. The mark does not move or scale on hover and does not change with the accent.

## Screenshots

| File | Shows |
|---|---|
| `images/13_banzai_sland_launcher.png` | the mark on the island's top edge, close crop |
| `images/19_banzai_integration.png` | BanzaiSland and BANZAI UI together, one launcher |
| `images/20_full_ecosystem.png` | the full BANZAI screen |
