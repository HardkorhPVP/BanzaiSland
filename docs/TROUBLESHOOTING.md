# Troubleshooting

Short answers first. If none of them fits, see [SUPPORT.md](SUPPORT.md) for how to report it.

## "BanzaiSland cannot run beside it" in chat, and no island

The original **Island** addon is enabled for this character. BanzaiSland and Island do the same job and must not run at the same time, so BanzaiSland stays off for the session and says so once. Disable **Island** on the character screen's AddOns list (or remove its folder), then `/reload`.

## No island at all, no message

- Check **BanzaiSland** is ticked in the AddOns list for this character.
- Check the folder is `Interface\AddOns\BanzaiSland` with `BanzaiSland_Mainline.toc` directly inside it (not nested one level deeper).
- Idle style may be **Hidden**: move the mouse to the top centre of the screen; the island appears. Change it under Settings › Appearance › Idle style.
- `/bsl status` prints whether BanzaiSland is running and what it detected.

## The settings will not open

`/bsl` and `/banzaisland` both open them; so does clicking **SLAND** on the island's top edge. In combat the window still opens (it is a plain window), but the BANZAI half of the mark will not open BANZAI UI's settings until combat ends.

## Text looks wrong on Hardkorh Parchment

Parchment writes text in dark inks on purpose - titles in charcoal, captions in brown-grey, gains in deep green, warnings in amber, errors in wine. If a line is bright or pale on the paper, that is a defect: send a screenshot (see [SUPPORT.md](SUPPORT.md)). Switch to Banzai Glass or Solid meanwhile; those keep the bright BANZAI colours.

## Fonts

- **A title is in the small font although I chose a display face.** The chosen face cannot show every character of that string, so the whole string is drawn in the Information Font (Open Sans). *Xangda Shiny* has letters only, so anything with digits falls back; *Automatic* behaves the same for any string BANZAI Default cannot show. Pick another face under Appearance › Display font, or BANZAI Default.
- **On non-English clients** titles may use the Information Font because the display faces are Latin-script fonts; choose a face explicitly under Appearance › Display font if you want it anyway.
- **My display font changed to BANZAI Default after an update.** The face you had chosen is no longer shipped; the saved choice was normalised. Choose any of the shipped faces.
- If a shared-media font you picked under **Font** disappears (its addon was removed), BanzaiSland falls back to its own fonts.

## Buttons do nothing on a prompt

You are in combat. The game does not let addons press protected buttons during combat; the game's own pop-up still works, and the card's buttons wake up the moment combat ends.

## BANZAI UI's wordmark and the BANZAI SLAND mark both show

You have BANZAI UI older than **1.3.8**. Update BANZAI UI, or turn its wordmark off yourself in BANZAI › Appearance › Branding › BANZAI logo.

## BANZAI UI's wordmark is gone and I want it

It steps aside only while BanzaiSland shows the BANZAI SLAND mark. Disable BanzaiSland and it returns. Your **BANZAI logo** setting was not changed.

## I moved the island and want it back at the top

Settings › Appearance › Placement › **Position: Top**.

## A card I need is not showing

Settings › Notifications: the group may be off. Check **Do Not Disturb** is not on (a bell with a line beside the island). Cards you missed are in the **history**: scroll over the island.

## Something else is wrong

- `/reload` first.
- Check for a Lua error (the game's error window or an error addon such as BugSack). Copy the whole message.
- Make a note of the game version, the material, chassis and display font, and what you were doing.
- Then follow [SUPPORT.md](SUPPORT.md).
