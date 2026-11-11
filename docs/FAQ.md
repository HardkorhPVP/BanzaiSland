# Frequently asked questions

**What is BanzaiSland?**
A BANZAI-themed contextual activity, notification, progression and interaction HUD for World of Warcraft Retail. One island at the top centre of the screen shows your progression, opens into cards for the things that happen, carries timers as bubbles beside it, and lets you answer ready checks, invites and loot rolls.

**Is it Island?**
It is built on it. BanzaiSland is a GPLv3 fork of **Island** by Devin (subtlegrind) with the presentation redesigned in the BANZAI visual language. BanzaiSland is independently maintained and is not supported by the Island author; do not report BanzaiSland problems to Island.

**Can I run Island and BanzaiSland together?**
No. They do the same job. If both are enabled, BanzaiSland prints one line and stays off for the session. Pick one.

**Do I need BANZAI UI?**
No. BANZAI UI is optional. With BANZAI UI 1.3.8+ the BANZAI SLAND mark on the island becomes the one launcher for both.

**Retail or Forever?**
1.0.1 supports Retail 12.1.5 and Forever 1.60.1 with the same source/package. The complete package passed final real-client Forever validation; affected simulations passed on both clients. The published 1.0.0 release remains Retail-only.

**Which fonts can I choose?**
Appearance › Display font: Automatic, BANZAI Default (Shojumaru at 105%, the default), Shojumaru, Ryujin Attack, Gang of Three, Osaka Sans, Sekaiwo, Xangda Shiny, Ninja Naruto and Information Font. Automatic uses BANZAI Default for fully supported strings and the Information Font otherwise; an alternate is drawn at its own size and falls back as a whole for strings it cannot show. The choice is independent of BANZAI UI's. [APPEARANCE.md](APPEARANCE.md#fonts)

**Does it change my Island settings?**
No. BanzaiSland saves under its own names (`BanzaiSlandDB`, `BanzaiSlandCharDB`) and never reads or writes Island's.

**Does it press buttons for me?**
Never on its own. A prompt's buttons press the game's own secure button when *you* click them, and never in combat.

**Why do the buttons do nothing in a fight?**
The game forbids addons from pressing protected buttons in combat. The game's own pop-up still works; the card's buttons are live again when combat ends.

**What are the three materials?**
Banzai Glass (dark, translucent), Solid (dark, opaque) and Hardkorh Parchment (cream paper written in dark ink).

**Why is text dark on Parchment?**
Because it is paper. Bright glass colours would be unreadable on cream; parchment uses a palette of dark inks that keep their meaning (green for gains, amber for warnings, wine for errors, plum for the arcane).

**Bamboo or Hairline?**
Bamboo has small bamboo end-caps and accent hairlines; Hairline is a thin one-pixel frame. Both grow with the island.

**Can I move it?**
Yes: Settings › Appearance › Placement, or drag it in edit mode. *Position: Top* puts it back.

**Can my characters have different setups?**
Yes: Settings › Profiles. Every character uses a profile; new ones share Default.

**Is it localised?**
The information text follows your client language where translations exist (ten locales). The display faces are Latin-script fonts, so on non-English clients titles use the Information Font unless you choose a display face explicitly.

**Does it work with ElvUI?**
Yes. The island registers as a mover in ElvUI's and EllesmereUI's edit modes.

**Will it spam my chat?**
No. It prints at login only when it has to (the Island conflict), and once when you first open the Preview.

**Where are the extension docs?**
[EXTENSIONS-GUIDE.md](EXTENSIONS-GUIDE.md) for the overview; `docs/EXTENSIONS.md` inside the addon folder for the full API reference.

**What licence?**
GNU General Public License v3. The source is the addon folder itself. [CREDITS.md](CREDITS.md).
