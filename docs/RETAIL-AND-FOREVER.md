# Retail and WoW Forever

BanzaiSland is one addon for both clients. It reads which game it is running in at start-up and shows only what that game has. There is no Retail-only or Forever-only download, and no feature pretends to exist where the client has nothing behind it.

## What both clients get

The island, progression (experience, reputation), cards, bubbles, prompts (ready checks, invites, duels, loot rolls, release / resurrect, summons, battleground ready), zone cards, alerts (durability, bags, mail, friends, reagents), vendor and run summaries, catch-up, profiles, the settings window, Preview, the BANZAI SLAND launcher, extensions, keys and controller, supported addons.

## Retail only

| Feature | Where it shows |
|---|---|
| Renown and Warband reputations | the bar at max level, cards |
| Great Vault, weekly rewards | bubbles and cards |
| Mythic+ keystones, Delves | bubbles and cards |
| Gear and upgrade tracking | cards |
| Work orders, knowledge, collections, housing, loadouts | cards |
| Dungeon Finder proposals | a prompt card with Accept / Decline |
| Other members' boss drops | a summary card after the encounter |
| Talking Head mirrored as a card | Settings › Notifications › Talking Head |

Retail 12.x protects some values (certain aura and loot details) from addons. Where the game hands BanzaiSland a protected value it shows what it is allowed to and never guesses.

## WoW Forever only

| Feature | Where it shows |
|---|---|
| Legacy points reminder | a card after loading screens |
| Legacy challenges and criteria progress | cards |
| Ammo alerts | Settings › Notifications › Gear and bags |
| Paladin seals | buff pills by your unit frame |
| Druid gossip flights | flight bubbles |
| The *Forever* look (bronze-edged) | Appearance › Look |
| Extension **packages** and the package creator | General › Allow package code (off by default) |

## Settings

The settings window shows a **Retail** section or a **Legacy** section depending on the client, and hides the options the other client has no use for. A profile can be shared between a Retail and a Forever character; each client simply uses the parts it understands.

## Versions

`/bsl status` prints the client BanzaiSland detected and its version. The two TOC files inside the addon folder (`BanzaiSland.toc`, `BanzaiSland_Mainline.toc`) are both meant to be there: each client reads its own.

## Screenshots

| File | Shows |
|---|---|
| `images/17_retail_feature.png` | a Retail-only card |
| `images/18_forever_feature.png` | a Forever-only card |
