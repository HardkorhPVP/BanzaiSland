# Getting started with BanzaiSland

BanzaiSland is a small HUD that lives at the top centre of your screen and tells you what is happening - experience and reputation as you earn them, loot as it drops, who is ready and who is not, what is counting down - and lets you answer the things that need an answer (ready checks, invites, loot rolls) without hunting for the game's pop-ups.

It is quiet when nothing is going on and grows only when it has something to say.

## The island

The thin dark bar at the top centre is the **island**. At rest it shows your experience bar (or the reputation you are watching) with your level and percentage. When something happens it opens into a **card** - a short, readable panel - and settles back when the moment is over.

Everything stays in the same place, so your eyes always know where to look.

## What you will see

- **Progression** - XP gains float onto the bar, quest turn-ins and level-ups get their own card (with your class's BANZAI artwork). Reputation gains show the standing you are in. [PROGRESSION.md](PROGRESSION.md)
- **Notifications** - loot, money, currency, upgrades, zone changes, durability, bags, mail, friends coming online, vendor summaries, dungeon and raid run summaries. [NOTIFICATIONS.md](NOTIFICATIONS.md)
- **Cards** - the panel every notification arrives in: a caption, a title, a result, sometimes a line of detail and an icon. [CARDS.md](CARDS.md)
- **Bubbles** - small round timers beside the island: pull timers, countdowns, flights, lockouts, buffs you are tracking. [BUBBLES.md](BUBBLES.md)
- **Prompts** - cards with buttons: Ready / Not ready, Accept / Decline, Need / Greed / Pass, Release, Accept summon. [INTERACTIVE-PROMPTS.md](INTERACTIVE-PROMPTS.md)

## Settings

Type `/bsl` (or `/banzaisland`), or click **SLAND** on the island's top edge.

The window has three groups in its sidebar:

- **APPEARANCE** - *Appearance* (material, chassis, accent, fonts, placement, size), *Card Builder* (lay out each kind of card), *Preview* (made-up cards to look at the design).
- **FEATURES** - *Sounds*, *Notifications* (what appears), *Bubbles*, *Activities* (timers and buffs), *Supported Addons*, *Extensions*.
- **MORE** - *Controls* (keys and controller), *General*, *Profiles*, *About & Credits*.

## Preview

Open **Preview** and press any scenario - XP progression, Reputation, Loot, Ready check, Group invite, Loot roll, Timer bubble, Level up, Success, Warning and error. Every card and bubble it shows is made up and clearly tagged *SYNTHETIC PREVIEW*; none of it answers the game. **Tour** runs them all a few seconds apart. **Look variants** switch the material, accent and chassis on the fly so you can compare.

## Making it yours

- **Material** - *Banzai Glass* (dark, translucent), *Solid* (dark, opaque), *Hardkorh Parchment* (cream paper with dark ink). [APPEARANCE.md](APPEARANCE.md)
- **Chassis** - *Bamboo* (small bamboo end-caps and accent hairlines) or *Hairline* (a thin one-pixel frame).
- **Accent** - *Banzai* (lime → emerald → violet), *Class* (your class colour), *Hardkorh* (bright green → emerald → violet).
- **Display font** - *BANZAI Default* is Shojumaru at 105%; *Automatic*, six alternates and the *Information Font* are also there. Independent of BANZAI UI. [APPEARANCE.md](APPEARANCE.md#fonts)
- **Placement** - drag the island in edit mode, or pick a preset; size and text scale are sliders.

## Profiles

Each character uses a **profile**. New characters share the **Default** profile; you can create more (for a healer and a tank, for example) and assign them per character. [PROFILES.md](PROFILES.md)

## Retail

This release runs on World of Warcraft Retail (Interface 120105) and shows the Retail things: Renown, Warband, Great Vault, Mythic+, Delves, Dungeon Finder proposals, Talking Head cards. WoW Forever compatibility is the next milestone and is not part of this release.

## BANZAI UI

Optional. With BANZAI UI 1.3.8+ installed, the **BANZAI SLAND** mark on the island opens both: BANZAI → BANZAI UI's settings, SLAND → BanzaiSland's. [BANZAI-INTEGRATION.md](BANZAI-INTEGRATION.md)

## A word on where it comes from

BanzaiSland is a GPLv3 fork of **Island** by Devin (subtlegrind) - the cards, bubbles, prompts and progression are Island's work, re-dressed in the BANZAI visual language. BanzaiSland is independently maintained and is not supported by the Island author. [CREDITS.md](CREDITS.md)
