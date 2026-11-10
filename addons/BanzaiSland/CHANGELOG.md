# Island changelog

## 3.7.0

- **Island border:** New border around the island in Settings > Look. Pick the thickness, color and opacity, or tick Use class color. If you have LibSharedMedia, you can use its border textures too. It follows the island's rounded shape as it grows. Off by default.
- **Bubble borders:** A separate option that gives the bubbles the same border.
- **Font outline:** Choose None, Thin or Thick for all Island text.
- **Settings window look:** Pick a border (thickness, color, opacity, class color) and a background color and opacity for this window. Reset window look puts it back.

## 3.6.0

- **Pill and card color:** New color swatch in Settings > Look tints the island, cards, bubbles, buff pills, navigation pill and shelf (Modern style). Right-click the swatch to go back to black.
- **Cards open:** New setting in Placement to open cards down or up (Auto keeps the old behavior). If the chosen direction would push a card off the screen, it opens the other way.
- **Fix:** With the island growing from an edge, the navigation pill no longer stacks on top of the warning dot and pinned bubbles.

## 3.5.2

- **Translations:** Island now follows your game language. Draft translations are included for German, Spanish (Spain and Mexico), French, Korean, Brazilian Portuguese, Russian and Simplified and Traditional Chinese. They are machine-translated, so some wording will be off. Anything not translated stays in English.
- **Help translate:** Every text to translate is listed in `Locales/Template.lua`, and `README.md` explains how to correct a language or add a new one.

## 3.5.1

- **Forever style for the guide steps:** The step panel (RestedXP and Polestar) and its Step bubble now follow the Forever style: bronze plaque, buttons, scroll bar and current-step highlight.

## 3.5.0 — Polestar

- **Polestar support:** Island now works with the Polestar leveling guide, the same way it does with RestedXP Guides. The navigation bubble follows Polestar's arrow, including its walking path, and shows the distance. Turn off Polestar's own arrow or guide window in Settings > Addons if you prefer Island's.
- **Polestar steps:** A card and a bubble with a progress bar appear when Polestar starts a new step, and the step panel (previous, next, skip, guide list, options) works with Polestar's steps.
- **Both guides installed:** RestedXP's arrow comes first unless Polestar already holds the bubble.

## 3.4.1

- **Grows from:** A new **Grows from** setting (Settings > Look, next to Position) lets the island sit at the left or right edge of the screen and open inward instead of being cut off. Choose **Left edge**, **Right edge**, **Center**, or **Auto** (the default), which picks an edge when the island is in the left or right third of the screen. Bubbles, the warning dot, the error pill and panels follow the edge. Islands placed in the middle of the screen behave exactly as before.

## 3.4.0 — Forever look

- **Forever style:** A new **Style** setting (Settings > Look) gives the island, its cards and bubbles a dark-bronze plaque look that matches the Forever UI. **Modern** stays the default and looks the same as before.
- **No more shaking text:** Text no longer jitters when the island expands or settles, wherever it is anchored (top, bottom or free). The island's size now lines up with real screen pixels, and the box no longer bounces out and back when it opens.
- **Gain pill fits its text:** The pill that shows XP and money gains is only as wide as the amount, instead of stretching very wide for something short like "+4c".
- **See-through island:** The faint lines that showed through the island when its opacity was below 100% are gone.

## 3.3.0 — Universal

**License:** GNU General Public License v3 (GPLv3). Full license included; bundled third-party notices are preserved.

- **Extensions page:** A new page in Island's settings lists every addon that sends cards and bubbles through Island, with search, filters, sorting, an on/off switch and details. A Problems list explains why an extension is missing or was refused.
- **Per-extension control:** Extensions can offer features you switch on or off (for example "card" or "bubble"), their own settings, and a card or bubble look (icon and color) that you can change in the Look drawer, including an optional sound.
- **Profiles:** Island's settings now live in profiles, so one profile is your whole setup. Existing settings carry over automatically.
- **Package creator:** Build a small extension from tabs, or install one from pasted text, without writing an addon. Packages run only if you turn on **Allow package code** (top right of the Extensions page). It is off by default; only install packages you have read and trust. Forever only.
- **Bars and countdowns:** Cards can show a progress bar or a countdown that drains by itself, and bubbles can show a small bar along the bottom. Island's own timers (break, server restart, ready check, fishing lure, flights, hearthstone cooldown, breath and fatigue) show the bar too; turn it off in Settings > Bubbles.
- **Quest XP on the XP bar:** An option (off by default, in Settings > Look next to the bar color) shows the XP waiting in quests you can turn in as an extra bar segment after the rested part, in its own color that you can change beside the switch. It is new and untested in game. The quest log is read the same way the game's own log does, and collapsed zones are opened and closed again briefly while counting.
- **RestedXP Guides:** If RestedXP Guides is installed, Island can show a card when a guide step starts, keep a bubble with the current step and the guide's progress along its bottom, and show a short bubble when a step is done (that one is off by default). Click the step bubble to open a panel with the guide's steps: go to the previous or next step, skip the current step, jump to any step, or pick a different guide from a searchable list. These buttons use RestedXP's own functions and only act when you press them. An optional switch hides RestedXP's own guide window (it keeps tracking your progress). The step bubble sits on the pinned side by default and its panel opens with the island's spring. The navigation bubble also points at the guide's arrow when nothing else is pinned; click it to open the map at the step's spot, or right-click to hide it until the next step. Switches are in Settings > Navigation. New and untested in game.
- **Activity shelf and persistent bubbles:** More of what is running at the moment can stay on the island.
- **Documentation:** Developers will find a quick start, a cheat sheet and the package handler guide in `Interface/AddOns/Island/docs`.
- **Voiceovers:** Pause is now mouse-only, so a card key meant for something else (Accept, Need) can no longer pause the voice by accident. Spoken's own window no longer flashes for a moment when a line ends.

**What the extension API cannot do yet:** For now it only shows cards and bubbles. They cannot be clicked, there are no panels, menus or custom layouts, extensions cannot read Island's state or hear back when a card is dismissed, only a feature's chosen sound can play, and sending is rate limited. Island never acts in the game for you. This is a first version: we plan to improve it in later releases, guided by what extension authors ask for.

**Forever first:** The extension API, packages and bars were built and tested for WoW Forever. The same files load on Retail, but these features have not been tested there, and the package creator is Forever only.

**Before you update:** Settings now live in profiles. Going back to an older Island afterwards may not see your profile choices, though nothing is deleted.
