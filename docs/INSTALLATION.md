# Installing BanzaiSland

BanzaiSland 1.0.1 supports **Retail 12.1.5** (Interface 120105) and **Forever 1.60.1** (Interface 16001). The complete package passed final real-client Forever validation; affected Retail and Forever simulations passed.

> **One rule before anything else:** BanzaiSland and the original **Island** addon must not run at the same time. BanzaiSland is built from Island and does the same job. If both are enabled, BanzaiSland prints one line in chat at login and stays off for that session - nothing breaks, but you will only see Island. Disable or remove one of them.

## With an addon manager

Where BanzaiSland is listed on CurseForge, Wago or WowUp you can install it like any other addon: search for **BanzaiSland**, click install. The manager keeps it updated. Otherwise use the manual steps below.

## Manual install

1. Close World of Warcraft completely.
2. Unzip the BanzaiSland package. You get one folder called `BanzaiSland`.
3. Replace the old addon folder in the selected client: `World of Warcraft\_retail_\Interface\AddOns\BanzaiSland` or `World of Warcraft\_forever_\Interface\AddOns\BanzaiSland`. Do not merge with a retired development build, which could leave old font files behind.
   You should see both TOCs directly inside the folder. Both clients select `BanzaiSland_Mainline.toc`; it declares interfaces `120105, 16001`.
4. Start the game. On the character screen, open **AddOns** and make sure **BanzaiSland** is ticked. If **Island** is also in the list, untick it.

## First start

- A thin, dark bar appears at the **top centre** of the screen: that is the island. It shows your experience (or reputation) and grows into cards when something happens.
- Nothing is configured yet, and nothing needs to be. BanzaiSland starts with the **Banzai Glass** material, the **Bamboo** chassis, the **Banzai** accent and the **BANZAI Default** display font (Shojumaru at 105%).
- Your settings are saved under BanzaiSland's own names (`BanzaiSlandDB` and `BanzaiSlandCharDB` in your `WTF` folder). BanzaiSland never reads or writes Island's saved settings, so you can try it without touching an existing Island setup.

## Opening the settings

Any of these:

- type `/banzaisland`
- type `/bsl`
- click **SLAND** in the BANZAI SLAND mark on the island's top edge

Useful commands:

| Command | Does |
|---|---|
| `/bsl` or `/banzaisland` | opens / closes the settings |
| `/bsl status` | prints the version, game version and look in chat |
| `/bsl preview` | opens the Preview page (made-up cards to look at the design) |

## BANZAI UI (optional)

BanzaiSland does not need BANZAI UI. If you also run **BANZAI UI 1.3.8 or newer**, the two fit together: the BANZAI SLAND mark on the island becomes the single launcher for both - **BANZAI** opens BANZAI UI's settings, **SLAND** opens BanzaiSland's - and BANZAI UI's own small top-centre wordmark steps aside while BanzaiSland is showing the mark. See [BANZAI-INTEGRATION.md](BANZAI-INTEGRATION.md).

## Updating

Replace the `BanzaiSland` folder with the new one (or let your addon manager do it). Your settings and profiles are kept; nothing is reset by an update. If a saved display-font choice names a face that is no longer shipped, it becomes **BANZAI Default**.

## Removing

Delete the `BanzaiSland` folder. If you want a completely clean slate, also delete `BanzaiSlandDB.lua` and `BanzaiSlandCharDB.lua` from your `WTF\Account\<account>\SavedVariables` (and per-character) folders - this is optional.

## If something is off

[TROUBLESHOOTING.md](TROUBLESHOOTING.md) has the short list: the island not showing, the Island conflict line, settings not opening, fonts, BANZAI UI.
