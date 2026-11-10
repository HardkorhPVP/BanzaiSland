# Cards

A **card** is the panel the island opens into when it has something to tell you. Every notification, prompt and summary arrives as a card, so once you know the shape you can read any of them at a glance.

## Anatomy

- **Caption** - small, upper-case: what kind of thing this is (*LOOT*, *UPGRADE*, *REPUTATION*, *READY CHECK*, *COMPLETE*, *LOW DURABILITY*).
- **Title** - the main line: the item, the person, the place, the message.
- **Result** - a value on the right: a count (*x1*), a gain (*+250*), a percentage (*+4.1%*), a time (*12:40*).
- **Line** - an optional second line of detail (the standing and its numbers, where something happened, who said it).
- **Icon or glyph** - the item's icon, a class identity disc, or one of BanzaiSland's glyphs (check, shield, alert, star, bell, hourglass, plane...).
- **Buttons** - only on prompts; see [INTERACTIVE-PROMPTS.md](INTERACTIVE-PROMPTS.md).

Cards keep the island's material and chassis, so a loot card on parchment is a loot card written in ink; the same card on Banzai Glass uses the bright BANZAI colours.

## How long a card stays

Each kind has its own hold time (**Settings › General › How long each kind stays**). A card you point at waits for you. Several cards queue and show one after another; scroll over the island to look back through recent ones (the **history**).

## Kinds of card

| Kind | When |
|---|---|
| Gain | experience or reputation earned (floats onto the bar) |
| Toast | loot, money, currency, honor, a quest turned in |
| Upgrade | an item that is better than what you wear (with Pawn, ItemTree or Lootified installed, or BanzaiSland's own check) |
| Level up | your new level with your class identity and the stat changes |
| Alert | durability, bags, mail, friends online, reagents, buffs |
| Zone | entering a zone or subzone (replaces the game's zone text) |
| Prompt | ready check, invite, duel, guild invite, release / resurrect, summon, battleground ready, Dungeon Finder proposal (Retail) |
| Loot roll | Need / Greed / Disenchant / Pass, who rolled, who won |
| Run summary | a dungeon or raid run: time, kills, XP, money |
| Vendor | repair and sell summary when you leave a merchant |
| Group | joined, left, role assigned |
| Catch up | what happened while you were away |
| Extension | cards sent by other addons through BanzaiSland |

## Card Builder

**Settings › Card Builder** lets you lay out each kind your way: which parts show, where the icon sits, how the caption and title are weighted, the colours - with a live sample in a preview well. Changes apply to the real cards immediately.

## Sounds

Each kind of card can have a sound (**Settings › Sounds**), with a preview button beside each choice.

## Do Not Disturb

**Settings › General › Do Not Disturb** (also a minimap button if you turn it on) keeps cards in the history instead of showing them. A small bell-with-a-line sits beside the island while it is on; click it to turn it off.

## Screenshots

| File | Shows |
|---|---|
| `images/07_loot_notification.png` | a loot card with an item icon and count |
| `images/06_reputation.png` | a reputation card with the standing line |
| `images/12_level_up.png` | the level-up card with the class identity |
