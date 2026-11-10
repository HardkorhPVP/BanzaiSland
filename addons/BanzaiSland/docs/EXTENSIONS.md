# Island extensions — API version 1

API version 1, first released with Island 3.3.0. It is written and tested for WoW Forever first. The same files load on Retail, but the new extension, package and bar features have not been tested there, so test Retail yourself before telling people your extension supports it. The Lua you write inside a package handler is described in [DEVELOPER.md](DEVELOPER.md). See "What the API cannot do yet" below for the current limits.

Declare `## RequiredDeps: Island` in your separate addon TOC. Register once after Island has loaded:

```lua
local extension, reason = IslandAPI.Register("YourAddonFolder", {
    apiVersion = 1, name = "Your readable extension name", audience = "forever",
})
if not extension then return end
-- On a live event, after establishing a silent login/loading baseline:
local accepted, status = extension:ShowCard("reminder", {
    title = "Time to restock", text = "Your supplies are running low.",
    group = "alerts", duration = 5, ttl = 20,
})
```

## Quick start

A separate addon that shows one card and one countdown bubble. Make a folder `MyIslandAddon` in `Interface/AddOns` with these two files.

`MyIslandAddon.toc`:

```
## Interface: 16001
## Title: My Island Addon
## Notes: Shows a card when combat ends.
## RequiredDeps: Island
## X-Island-Extension: 1
MyIslandAddon.lua
```

`MyIslandAddon.lua`:

```lua
local API = _G.IslandAPI
if type(API) ~= "table" or API.version ~= 1 then return end   -- Island missing or too old

-- 1. Register once. The id is your folder name.
local ext = API.Register("MyIslandAddon", { apiVersion = 1, name = "My addon", audience = "forever" })
if not ext then return end

-- 2. Send things when something real happens, never from a timer loop.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_ENABLED")        -- you left combat
f:SetScript("OnEvent", function()
    if not API.IsReady() then return end       -- Island is still loading
    ext:ShowCard("combat-over", { title = "Combat over", text = "Time to drink.", group = "alerts", duration = 5, ttl = 20 })
    if API.capabilities and API.capabilities.countdownBubbles then
        ext:SetBubble("drink", { text = "Drink", countdown = 30, bar = true })   -- 30 s countdown with a bar
    end
end)
```

Then `/reload`. Pull out of combat and the card and bubble appear. Open Island's Extensions page to see your addon, switch it off and on, and read the Problems list if it does not show up. `/island extensions` prints a short status line.

Rules that matter most: register once, send only on real events, pick one stable key per thing (sending the same key again updates it), treat every call's result as possibly `false` (the player may have switched you off), and check `IslandAPI.capabilities` before using an optional field.

## Cheat sheet

Every method returns `true, "accepted"` or `false, reason`, except Register (a handle, or `nil, reason`), `GetSetting`, `IsEnabled`, `IsFeatureEnabled` and `GetStatus`.

| Call | What it does | Main limits |
|---|---|---|
| `IslandAPI.Register(id, meta)` | Join Island; returns a handle. `meta`: `apiVersion=1`, `name`, `audience` (`forever`, `retail`, `both`), optional `features`, `settings`. | id 1-64 letters, digits, `_` or `-`; name up to 64 bytes; 32 registrations. |
| `IslandAPI.IsReady()` | True once Island has finished loading. Wait for it before sending. | |
| `ext:ShowCard(key, p)` | Create or update a card. Fields: `title`, `text`, `caption`, `icon`, `group`, `duration`, `ttl`, `feature`, `progress` or `countdown`, `barColor`. | `title` required, up to 160 bytes; 5 cards per extension. |
| `ext:DismissCard(key)` | Remove that card. Safe to repeat. | |
| `ext:SetBubble(key, p)` | Create or update a bubble. Fields: `text`, `tooltip`, `icon`, `ttl`, `persistent`, `feature`, `progress`, `bar`, `barColor`, `countdown`. | `text` up to 24 bytes (16 on a countdown bubble); 2 bubbles per extension. |
| `ext:RemoveBubble(key)` | Remove that bubble. | |
| `ext:PauseCountdown(key)` / `ext:ResumeCountdown(key)` | Stop or restart a countdown on a bubble or card. Gives `false, "not_found"` if nothing counts down under that key. | A paused bubble goes after 10 minutes. |
| `ext:Clear()` | Remove everything this extension is showing. | |
| `ext:GetSetting(key)` | The player's value for a setting you declared. | Never changes by callback: ask when you need it. |
| `ext:IsEnabled()` / `ext:IsFeatureEnabled(id)` | Whether the player has you, or that feature, switched on. | |
| `ext:GetStatus()` | A copy of your counters and last refusal reason, for debugging. | |

Sending is limited to a burst of 3 per extension, refilling one every two seconds. Sending the identical payload again does not restart a card or a countdown.

### Results

| Reason | Meaning | What to do |
|---|---|---|
| `accepted` | Island took it. It is not a promise the player saw it (Do Not Disturb, combat holds and full queues can delay or drop it). | Nothing. |
| `not_ready` | Island has not finished loading. | Wait for `IsReady()` and send on the next real event. |
| `disabled` | The player switched your extension off. | Stop sending. |
| `feature_disabled` | The player switched off the feature this output is tagged with. Not an error and costs no rate limit. | Nothing. |
| `rate_limited` | You sent too many at once. | Send fewer; do not retry in a loop. |
| `invalid_payload` | A field has the wrong type, is too long, is out of range or is not allowed. | Check the field tables below. |
| `capacity` | Too many registrations, cards or bubbles. | Dismiss or remove old ones. |
| `unavailable_client` | Your `audience` does not include this game client. | Check `audience`. |
| `unsupported_version` | Island is older than the API you asked for. | Tell the player to update Island. |
| `already_registered` | You registered again with a different name or audience. | Register once, the same way every time. |
| `adapter_error` | Island could not show it. | Not your bug; try on the next event. |
| `not_found` | Pause or Resume found nothing under that key. | Check the key. |

### Capabilities

`IslandAPI.capabilities` tells you which optional parts this Island has. Check one before using its fields, because older Islands refuse unknown fields with `invalid_payload`.

| Flag | Gives you |
|---|---|
| `features` | The `features` list in `Register`, and `feature` on cards and bubbles. |
| `settings` | The `settings` list and `GetSetting`. |
| `art` | A suggested `art` and `color` on a bubble feature. |
| `persistentBubbles` | `persistent = true` on bubbles. |
| `progress` | `progress`, `countdown` and `barColor` on cards. |
| `countdownBubbles` | `countdown`, `bar`, `progress` and `barColor` on bubbles. |
| `pauseCountdown` | `PauseCountdown` and `ResumeCountdown`. |

## What the API cannot do yet

Version 1 is deliberately small. It shows cards and bubbles, and nothing else, so that an extension can never get in the way of the game or act for the player. Here is what is missing today:

- **No clicks or buttons.** Cards and bubbles cannot be clicked and carry no actions. The player can only read them or let them expire.
- **No panels, menus or custom layouts.** An extension cannot draw its own frames or windows through Island. Anything that needs its own interface must be a real addon with its own frames.
- **No reading Island's state, and no callbacks.** An extension sends to Island but cannot ask for the player's XP state or Do Not Disturb status, and Island does not tell it when a card was shown, dismissed or clicked. Accepted is not a delivery receipt.
- **Sound only through a feature.** An extension cannot play its own sound. A feature can name one of Island's sounds, which the player can change or turn off.
- **Cards and bubbles only.** One bar per card or bubble, a short label, one icon, no extra text rows, no images other than a texture id, and no animation control.
- **Tight limits.** Sending is rate limited (burst of 3, then one every two seconds), a bubble label is at most 24 bytes, and each extension keeps at most five cards and two bubbles.
- **No automatic game actions.** Island never uses an item, casts a spell, buys, sells or answers a prompt for the player, and no extension can make it.
- **Packages are narrower still.** A package handler runs in a read-only sandbox, can only react to game events (not poll or watch the combat log), and a player can install up to 8 packages with up to 12 handlers each. A package cannot create frames or save data of its own. Packages are available in WoW Forever only.
- **Retail.** The Retail client is not yet covered or tested for the extension API, packages or bubble bars.

These limits are the first version, not the final one. Island plans to improve the API in later releases, guided by what extension authors ask for. Ideas under consideration include safe click actions that the player always triggers themselves, simple panels that Island draws, a way to read a small set of Island's state, callbacks for shown and dismissed, and a permission list the player can review. None of that is promised or scheduled. New abilities will arrive as optional, capability-flagged additions where possible, and anything that would break an existing extension would wait for a new API version.

## Registration and readiness

`IslandAPI.version` is 1. `IslandAPI.IsReady()` returns true after world initialization/loading has completed and Island's renderer/settings exist. Registration may happen earlier; notifications then return `false, "not_ready"`. Establish fresh baselines instead of replaying startup events. Compatible duplicate registration returns the same handle; changing name/audience for an existing ID is rejected. A folder ID is a convention, not a security boundary between trusted addons.

Metadata allows only apiVersion, name, audience (`forever`, `retail`, `both`) and the optional `features` and `settings` lists (see Features and Settings below). Folder IDs/local keys use ASCII letters, digits, underscore or hyphen, 1–64 bytes. Names are localized display text supplied by your addon, at most 64 bytes. Limit: 32 registrations per session. Unavailable audiences may register but cannot send notifications and are hidden from normal extension settings.

## Handle methods

| Method | Behavior |
|---|---|
| `extension:IsEnabled()` | Whether available for the client and enabled in Island. Can be false before settings exist. |
| `extension:ShowCard(key, payload)` | Create/update a normal informational card owned by this extension. |
| `extension:DismissCard(key)` | Remove the matching active/pending card and preview; repeat calls are harmless. |
| `extension:SetBubble(key, payload)` | Create/update a static expiring bubble. |
| `extension:RemoveBubble(key)` | Remove the matching owned bubble. |
| `extension:PauseCountdown(key)` | Stop a countdown (a bubble's or a card's with that key) where it is. It keeps the time left. A paused bubble is removed after ten minutes. Returns `true, "accepted"`, or `false, "not_found"` when nothing counts down under that key. Check `IslandAPI.capabilities.pauseCountdown`. |
| `extension:ResumeCountdown(key)` | Let a paused countdown run again from the time it had left. |
| `extension:Clear()` | Remove all this extension's active/pending cards, previews and bubbles; retain registration/preferences/history. |
| `extension:GetSetting(key)` | The player's current value for a declared setting (or its default), always valid for the declared type and range. `nil` for an unknown key. Works whether or not the extension is enabled. |
| `extension:IsFeatureEnabled(id)` | Whether this extension is enabled and the player has that declared feature switched on. False for an unknown id. |
| `extension:GetStatus()` | Copy of id, name, audience, available, enabled, ready, accepted, rejected, rateLimited, featureDisabled and lastReason. |

Submission/cleanup returns `true, "accepted"` or `false, reason`; Register returns a handle or `nil, reason`. Reasons: invalid_payload, unsupported_version, already_registered, capacity, not_ready, disabled, unavailable_client, rate_limited, adapter_error, and `feature_disabled` for output tagged with a feature the player switched off (not an error: nothing is queued, no rate-limit token is spent, and it is counted only in `featureDisabled`). Accepted is not a delivery receipt: DND may retain history only, native queues can be full, and holds/previews can delay presentation. Accepted counters count new/changed payloads; duplicate successes do not increment them. Diagnostic counters saturate at one million.

## Card payload

| Field | Type / default |
|---|---|
| title | Required nonempty string, at most 160 bytes. |
| text | Optional body string, at most 1,024 bytes; normal Island line limits still apply. |
| caption | Optional label, at most 160 bytes; defaults to registered extension name. History identifies the registered name. |
| icon | Optional positive integer texture file ID or texture path, at most 256 bytes. Otherwise a Bell glyph. |
| group | loot, social, alerts or world; defaults alerts. Selects existing group styles/timing. |
| duration | Finite number, defaults 5, clamps to 2–10 base seconds before Island timing multipliers. |
| ttl | Finite number, defaults 20, clamps to 2–60 seconds of pending lifetime. |
| feature | Optional identifier of a declared card feature (see Features). |
| progress | Optional finite number from 0 to 1 (clamped): a bar under the card text, filled that far. Send a new value and Island eases the bar to it instead of jumping. Not allowed together with countdown. |
| countdown | Optional finite number of seconds, 1 to 3600 (clamped): the bar starts full and drains by itself, drawn by Island, from the moment the card is accepted. Repeating the identical payload does not restart it. The bar is only seen while the card is up (duration), so keep duration and countdown in step. |
| barColor | Optional bar colour, one of the colour ids on the Look drawer (accent, white, red, orange, yellow, green, teal, blue, purple, pink, grey, default). Needs progress or countdown. |

Check `IslandAPI.capabilities.progress` before relying on bars; older Islands reject the fields. Bubbles take a bar too (see Bars on bubbles) and can count down (see Countdown bubbles).

Only those fields are accepted. Payloads must be plain tables without metatables. All values must be readable; secret combat values, NaN/infinity, callbacks, arbitrary fields and internal flags are rejected before rendering. Payloads are copied into scalar data; changing your table afterwards does not change a card.

Strings support ordinary text, escaped `||`, and balanced `|cAARRGGBB...|r` color spans. Texture/atlas/hyperlink markup and control bytes are rejected. Newlines/tabs are accepted within normal text limits. Localize your own strings; Island does not translate incoming text or inspect item links.

## Bubble payload

`{ text="3", tooltip="Three supplies left", icon=134831, ttl=30 }`

text is required (at most 24 bytes), tooltip optional (1,024 bytes), icon as above, ttl required and clamps to 1–120 seconds, and `feature` is an optional identifier of a declared bubble feature (see Features). Static labels only; no caller callbacks or custom polling. Bubbles are nonurgent and respect Island's bubble limits and urgent-only filter. Card DND/raid/combat holds apply to cards, not static bubbles; use the extension toggle/Clear to remove both.

### Bars on bubbles

`{ text="42%", tooltip="Healer mana", ttl=20, progress=0.42, barColor="blue" }`

A bubble may carry a small bar along its bottom edge, drawn by Island. `progress` is a fixed fill from 0 to 1 (clamped); send a new value and the bar eases to it. A countdown bubble can show its bar draining by itself with `bar=true`. `barColor` is a colour id from the Look drawer and needs a `progress` or `bar=true`. `text` stays the label; the bar never replaces it.

### Countdown bubbles

`{ text="Rez", tooltip="Combat rez cooldown", countdown=600 }`

Instead of ttl, a bubble may carry `countdown` (seconds, clamped to 1-3600). Island shows the time left as m:ss (h:mm:ss from an hour), counts it down by itself with no further calls from you, and removes the bubble at zero. text then becomes an optional label of at most 16 bytes shown before the time. A countdown bubble cannot also send ttl or persistent, and it is never kept up by the feature's Keep-visible choice. Sending the identical payload again does not restart it; send something different (for example a new countdown) to start over. Check `IslandAPI.capabilities.countdownBubbles`. Pause and resume it with `PauseCountdown` and `ResumeCountdown`.

On cards, `countdown` also writes the time left on the right of the card (`1:30`, then `30s`).

## Features (optional)

An extension may declare up to eight features when it registers. Island shows each as an on/off switch on the extension's details page (Settings > Extensions > the extension > Features) and saves the player's choices in the active profile. Check the capability first, because an Island without it refuses unknown registration fields:

```lua
local features
if type(IslandAPI.capabilities) == "table" and IslandAPI.capabilities.features then
    features = {
        { id = "restock", kind = "card", name = "Restock card", description = "A card when supplies run low." },
        { id = "count", kind = "bubble", name = "Count bubble", default = false },
    }
end
local extension = IslandAPI.Register("YourAddonFolder", { apiVersion = 1, name = "Your name", audience = "forever", features = features })
extension:ShowCard("restock", { title = "Time to restock", feature = features and "restock" or nil })
```

| Field | Rule |
|---|---|
| id | Identifier (letters, digits, underscore, hyphen; 1–64 bytes), unique within the extension. |
| kind | `"card"` or `"bubble"`. |
| name | Required display text, at most 64 bytes, localized by your addon. |
| description | Optional, at most 160 bytes. |
| default | Optional boolean; defaults to true. |
| sound | Optional suggested sound for new cards or bubbles of this feature: `whisper`, `chime`, `ping`, `bell`, `horn`, `alert` or `friend`. The default is no sound. The player can pick another sound or none in the feature's Look drawer. A sound plays only when a card or bubble first arrives (not for updates), at most once every three seconds per extension, never in Do Not Disturb, and only if Island's sound switches (the master switch and the card group's switch) are on. |

Only those fields are accepted; the list must be a plain sequence of plain tables. A bad schema refuses the whole registration with `nil, "invalid_payload"`. A repeated registration must carry the same schema or it returns `already_registered`; the schema is fixed for the session. Pass `feature = id` with a card or bubble: it must name a declared feature of the matching kind (otherwise `invalid_payload`). When the player has that feature off the call returns `false, "feature_disabled"`. Output without `feature` follows only the extension's master switch. Switching a feature off removes only that feature's current cards and bubbles at once. The extension's master switch still overrides every feature. Features are pulled, not pushed: read `extension:IsFeatureEnabled(id)` when you need it. Island does not tell an extension when the player switches a feature or setting, so an extension that shows a persistent bubble should notice the change itself (a once-a-second check of `IsFeatureEnabled` and `GetSetting` values is enough) and refresh its bubble; otherwise a bubble the player turned off stays gone until the next event. IslandExample does this.

## Card and bubble art and color (optional)

A card or bubble feature can suggest how its output looks, and the player can change it on the Features tab (Change art and color). Island ships 48 glyphs (its own bubble art plus potions, hearts, skulls, swords, keys, gems, flames and more) and 12 colors. The player can also choose "Extension's own icon", which keeps the `icon` you send, for example an item icon. Check `IslandAPI.capabilities.art` first, because an Island without it refuses the extra feature fields:

```lua
features = {
    { id = "restock", kind = "card", name = "Restock card" },   -- no suggestion: keeps the item icon you send
    { id = "count", kind = "bubble", name = "Potion count", art = "Potion", color = "red" },
}
```

| Field | Rule |
|---|---|
| place | Optional, bubble features only: `pinned` (default) or `bubble`; see Persistent bubbles. |
| art | Optional, on card or bubble features. One of the art ids below; the player's choice wins. Without it the output keeps the `icon` you send. |
| color | Optional. `default`, `accent` (Island's accent color), `white`, `red`, `orange`, `yellow`, `green`, `teal`, `blue`, `purple`, `pink` or `grey`. |

Art ids: Potion, Cup, Flask, Heart, Skull, Sword, Shield, Hammer, Flame, Bolt, Snowflake, Drop, Gem, Crown, Key, Scroll, Book, Eye, Hourglass, Clock, Bell, Alert, Star, Check, Plus, Coin, Bag, Pouch, Chest, Armor, Herb, Ore, Fish, Paw, Quiver, Shuriken, Person, Chat, Mail, Speaker, Home, Door, Flag, Compass, Plane, Moon, Gear, Power.

A bad `art` or `color` (unknown id) refuses the whole registration with `invalid_payload`, and the suggestion is part of the schema that must match on a repeated registration. Game icons keep their own colors; the color applies to Island's glyphs. A bubble's look changes at once when the player picks (the popup also sets where persistent bubbles show, see below); a card's look applies to the next card. Output without a `feature` keeps the plain look.

## Showing the current state at login

Island clears every extension's output at each loading screen and is ready a moment after the world loads, so anything sent before `IslandAPI.IsReady()` is true is refused with `not_ready`. To show something as soon as possible (a restock card or tracker bubble that should not wait for the next bag change), wait for readiness with the public API and then send what is true right now:

```lua
local function WhenReady(fn, tries)
    if IslandAPI.IsReady() then fn() return end
    tries = (tries or 0) + 1
    if tries <= 20 then C_Timer.After(0.5, function() WhenReady(fn, tries) end) end
end
-- on PLAYER_ENTERING_WORLD and LOADING_SCREEN_DISABLED:
WhenReady(function()
    if potions < low then extension:SetBubble("potions", { text = tostring(potions), persistent = true }) end
end)
```

This works for any extension with no special support. Send a card on login only if it should appear once per session (keep a flag); bubbles are fine to restore at every loading screen. Switched-off features and a disabled extension still apply, so a send that returns `feature_disabled` or `disabled` is normal.

## Persistent bubbles (optional)

For something the player watches all the time, such as your own tracker, a bubble can stay until you remove it. Check `IslandAPI.capabilities.persistentBubbles` first, because an Island without it refuses the `persistent` field.

```lua
local persistent = IslandAPI.capabilities and IslandAPI.capabilities.persistentBubbles
local bubble = { text = tostring(count), tooltip = "Potions in your bags", feature = "count" }
if persistent then bubble.persistent = true else bubble.ttl = 60 end
extension:SetBubble("potions", bubble)   -- send again whenever the value changes
```

`persistent = true` replaces `ttl` (sending both is `invalid_payload`; a bubble needs one or the other). It stays until you call `RemoveBubble`, the player switches the extension or its feature off, or the next loading screen, which clears every extension's output as always, so send it again when `IsReady()` turns true. Updating the text of an existing persistent bubble is allowed as usual. Limits: two persistent bubbles per extension and six in all (`capacity` beyond that), and the normal bubble token rate still applies.

The player can also keep any bubble up: the bubble feature's Change art and color popup has a **Keep it up until it is removed** button, which makes that feature's bubbles persistent even when you sent a `ttl` (they then count toward the persistent limits, and switching it off puts the lifetime back). So an extension does not have to be written for it.

Where it shows is the player's choice on the bubble feature's Change art and color popup: **Pinned** (default) puts it beside the island with Island's own pins (resting, ammo, tracking), where it always shows and is not hidden by "only urgent bubbles"; **With other bubbles** puts it in the regular bubble slots, which follow the bubble count and the urgent-only filter. A bubble feature can suggest one with `place = "pinned"` or `place = "bubble"` (bubble features only; other values refuse the registration). Persistent bubbles are meant for a few well-chosen trackers: pinned slots are limited, and anything past them is not shown.

## Settings (optional)

An extension may declare up to twelve settings when it registers. Island draws the controls on the extension's details page (Settings > Extensions > the extension > Settings), saves the values in the active profile, and shows which profile that is, with a Reset to defaults button (it resets the extension's features and settings, not its master switch). Declarative only: Island draws everything; there are no frames and no callbacks. Check the capability first, because an Island without it refuses unknown registration fields:

```lua
local settings
if type(IslandAPI.capabilities) == "table" and IslandAPI.capabilities.settings then
    settings = {
        { key = "low", type = "slider", name = "Low supply", min = 1, max = 10, step = 1, default = 3 },
        { key = "group", type = "choice", name = "Card group", default = "alerts",
          choices = { { id = "alerts", name = "Alerts" }, { id = "world", name = "World" } } },
        { key = "clear", type = "toggle", name = "Clear when restocked", default = true },
    }
end
local extension = IslandAPI.Register("YourAddonFolder", { apiVersion = 1, name = "Your name", audience = "forever", settings = settings })
local low = settings and extension:GetSetting("low") or 3
```

| Field | Rule |
|---|---|
| key | Identifier (letters, digits, underscore, hyphen; 1–64 bytes), unique within the extension. |
| type | `"toggle"`, `"slider"` or `"choice"`. |
| name | Required display text, at most 64 bytes, localized by your addon. |
| description | Optional, at most 160 bytes. |
| default | Toggle: boolean (default false). Slider: a number within min and max (default min). Choice: one of the choice ids (default the first). |
| min, max, step | Slider only, all required: min below max, step above zero, at most 1,000 steps. Values snap to the step. |
| choices | Choice only: 2 to 8 entries of `{ id = identifier, name = display text }`, ids unique. |

Only those fields are accepted; the list must be a plain sequence of plain tables. A bad schema refuses the whole registration with `nil, "invalid_payload"`, and a repeated registration must carry the same schema or returns `already_registered`. Settings are pulled, not pushed: read `extension:GetSetting(key)` when you need the value (there is deliberately no change callback). A stored value that no longer fits the declared type or range is ignored and the default is returned, so changing your schema never breaks a saved profile.

## Presentation and limits

Cards follow shared DND, raid, combat/typing and voice/dialogue presentation rules and cannot replace game prompts. group does not imply a built-in producer toggle: personal-loot, quest, rare and other producer switches are separate from custom notifications. Use General > Extensions to select and enable/disable each extension. Disable removes current/pending presentations immediately; history remains display-only. Extension cards are silent unless their feature declares a sound (see Features), and they expose no click/action buttons, urgency, secure controls, arbitrary layouts or frames.

One key per extension identifies a card; the same key in another extension cannot collide. Card keys and bubble keys use separate stores. Identical updates do not restart cards or extend TTL; changed payloads replace and renew pending TTL. Pending expiry includes voice/dialogue previews and holds; active full cards use their display duration. World/loading changes clear session presentations without unregistering addons or changing saved preferences. A reenabled extension must send new live observations.

Card and bubble submissions share a per-extension token bucket (burst 3, refill one per two seconds), and a global bucket (burst 10, refill five per second). Duplicate attempts also consume tokens; rejected/rate-limited submissions do not extend TTL. At most five retained cards per extension/20 globally, two bubbles per extension/10 globally; native queue limits may be lower. Cleanup is immediate or within the shared 250ms expiry sweep, which detaches when no extension presentations remain. Work is proportional to these bounded stores; this is not a claim of zero performance cost.

`/island extensions` prints names, enabled state and bounded counts. It never prints payload bodies/event arguments. Private registry/settings tables and ns.Extensions are not public APIs. Do not depend on them. Each registered extension saves its enabled preference, feature choices, bubble looks and setting values in the active settings profile under a versioned namespace; the settings picker in General also remembers its selection.

## Testing and compatibility

Use real live threshold transitions, not an OnUpdate notification loop. Test login, zoning, combat hold/expiry, DND, disable, simultaneous game prompts and repeated events. Guard APIs and restricted values before doing arithmetic. Unknown data is not zero. Never assume accepted means visible. Keep your addon optional and separate from Island's release. WoW addons share Lua; this API validates submissions, not arbitrary third-party code or infinite loops.

Breaking changes require a new API major version. Optional fields/methods need documented capability checks. Packages and their handlers use version 1 without changing the public payload contract; package code is a separate trusted-code feature.

Startup note: an unversioned extension preferences table is migrated to version 1 while preserving explicit enabled/disabled choices. Unknown future schema versions remain disabled and are not overwritten.

## Diagnostics (Problems on the Extensions page)

The Extensions page ends with a Problems list that says why an extension is missing. It shows the last 20 refused registrations, each with a reason: `unsupported_version` ("needs a newer Island API"), `invalid_payload`, `capacity` or `already_registered`. A repeated refusal is counted once with a number. Only the checked id and name are kept, never other data from the call.

It also lists addons that are installed but never registered. To be found, an extension adds this line to its TOC:

```
## X-Island-Extension: 1
```

Island then reads the game's addon list and gives the reason: switched off in the AddOns list, a required addon missing or switched off, out of date for this game version, could not be loaded, not loaded, or loaded but not registered. An extension registers under its folder name, so use the folder name as the id; otherwise a loaded addon with the tag but a different id is listed as not registered. The tag is optional and changes nothing else.

## Extension packages

A package is an extension you can install from text, the way WeakAuras installs auras. It is saved data that Island runs, not an addon: WoW can only load addons from the AddOns folder, so anything that needs deeper game access, files or its own frames still needs a real addon.

Open the package creator with `/island packages` or from the Extensions page (Package creator, or Import to start with a pasted string). Saving needs "Allow package code" on (the switch at the top right of the Extensions page, or the button at the top left of the creator). With it off, packages stay installed and listed but their handlers do not run, and Test, Enable and Import are refused.

### The package creator

The creator replaces the old Developer Lua editor. Pick a package on the left, or press New package. Four tabs build it without typing the data text:

- **Details**: id (fixed once saved), name, author, version, notes, and Lua access (sandbox or full).
- **Features**: up to 8. Each has an id, what it shows (card or bubble), whether it starts on, name, description, and optional art, colour and place.
- **Settings**: up to 12 switches, sliders and choices. Changing a setting's kind resets the fields that kind does not use.
- **Handlers**: up to 12. Each has a name, an on/off switch, the events, an optional unit filter, a minimum interval, the feature it feeds, and the Lua body.

On the Handlers tab the line at the bottom shows the handler being edited: how it ran last (event and how long ago) and exactly what it sent, and Test runs that handler once. Save checks the package and says which item is wrong when something is not valid. Enable switches the extension on (and restarts any handler that stopped after errors); Test sends ISLAND_TEST to every handler; Export shows the share string; Delete asks twice.

Rules from the old Developer editor were turned into one package, "Developer rules" (full Lua, each rule one handler, each keeping its on/off state). The old rules stay in your saved data; the package is the live copy.

### What a package holds

A package is one Lua-style table of plain data. Island reads it with a strict reader; it is never run as code.

```lua
{
  id = "Pkg_Bags", name = "Bag watcher", author = "you", version = "1",
  notes = "Shows a card when your bags change.",
  features = { { id = "note", kind = "card", name = "Show a card", default = true } },
  settings = { { key = "seconds", type = "slider", name = "Card time", default = 5, min = 2, max = 15, step = 1 } },
  handlers = {
    { name = "Bag change", events = "BAG_UPDATE_DELAYED", unit = "", interval = 2, feature = "note",
      code = [[
if event == "ISLAND_INIT" then return end
return { title = "Bags changed", text = event, duration = ctx.setting("seconds"), ttl = 20 }
]] },
  },
}
```

- `id` must start with `Pkg_` (letters, numbers, `_` and `-`, up to 64) so it can never collide with a real addon. `name` up to 64; `author`, `version`, `notes` are optional.
- `features` (up to 8) and `settings` (up to 12) are exactly the shapes registration takes (see above), including `art`, `color` and `place`.
- `handlers` (up to 12): `name`, `enabled` (optional; `false` keeps the handler off), `events` (up to 8 uppercase game events), optional `unit` filter, `interval` (0.1 to 60 seconds), `feature` (one of the package's features) and `code`. The feature's kind decides whether the handler shows a card or a bubble. The code is the body of `function(event, state, ctx, ...)` and returns the same payload a Developer rule returns; `ctx.setting(key)` reads one of the package's settings and `ctx.enabled(featureId)` tells whether a feature is on.
- Each handler gets `ctx.setting(key)` and `ctx.enabled(featureId)`, plus `ctx.pause()` and `ctx.resume()` for its own countdown and `ctx.cancel()` to remove its own card and bubble.
- A package is at most 64 KB and Island keeps up to 8.
- `full = true` asks for full Lua access (see Safety).

### Install, update, share

- **Import** (in the creator or on the Extensions page) takes an `ISLANDPKG1:` string or package text pasted into the box. **Review** reads it and shows it back as plain readable text with a summary: whether it is new or replaces an installed package, and what access it asks for. Read the code, then press **Install**. Editing the text cancels the review. A cut-off or changed string is refused.
- **Export** shows the string to copy (Ctrl+A, Ctrl+C).
- A new package arrives switched off. Switch it on in Extensions, or press Enable in the creator.
- Saving a change to a package's code, events or access switches it off again until you turn it on, so new code never runs by surprise. Changes to the name, features or settings register the extension again under its new shape at once; no `/reload` is needed.
- **Remove** (on the extension's page) or Delete in the creator removes the package and its Extensions entry. A real addon cannot be removed from Island: switch it off, or delete its folder.
- Packages are shared by all profiles. Each profile keeps its own on/off, feature and setting choices, as for any extension.

### Safety

Importing means running code someone else wrote. Read it first.

- A package's handlers run in a small sandbox: no `_G`, frames, `loadstring`, `getfenv`/`setfenv`, chat, secure actions or saved variables. Available are: assert, error, ipairs, next, pairs, pcall, select, tonumber, tostring, type, unpack, GetTime, GetServerTime, date, time, UnitName, UnitClass, UnitRace, UnitLevel, UnitExists, UnitIsDead, UnitIsPlayer, UnitIsUnit, UnitFactionGroup, UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax, UnitPowerType, UnitXP, UnitXPMax, GetXPExhaustion, IsResting, UnitAffectingCombat, InCombatLockdown, UnitIsGhost, UnitCreatureType, UnitReaction, UnitInRaid, UnitInParty, GetItemCount, GetItemInfo, GetMoney, GetSpellInfo, GetSpellCooldown, GetZoneText, GetSubZoneText, GetRealZoneText, GetMinimapZoneText, IsInInstance, IsInGroup, IsInRaid, GetNumGroupMembers, GetNumQuestLogEntries, UnitGroupRolesAssigned, UnitThreatSituation, GetPartyAssignment, GetRaidRosterInfo, GetNumSubgroupMembers, UnitGUID, UnitIsDeadOrGhost, UnitIsConnected, UnitIsGroupLeader, UnitInRange, UnitIsVisible, GetInventoryItemDurability, GetInventoryItemLink, GetInventoryItemID, GetItemCooldown, GetSpellTexture, IsSpellKnown, UnitAura, UnitBuff, UnitDebuff, GetContainerNumSlots, GetContainerNumFreeSlots, GetContainerItemInfo, GetContainerItemLink, GetInventoryItemCount, UnitCastingInfo, UnitChannelInfo, IsUsableSpell, IsSpellInRange, GetActionCooldown, UnitIsEnemy, UnitCanAttack, UnitIsFriend, UnitCanCooperate, UnitClassification, UnitIsTapDenied, UnitDetailedThreatSituation, GetRaidTargetIndex, GetNumFactions, GetFactionInfo, GetNumSkillLines, GetSkillLineInfo, GetInstanceInfo, GetLootMethod, UnitInBattleground, GetQuestLogTitle, GetQuestLogLeaderBoard, GetFramerate, GetNetStats, GetGameTime, strsplit, strtrim, strjoin, strmatch, strfind, tContains, tinsert, floor, ceil, max, min; plus the `math`, `string` and `table` functions that do not touch the game. Event arguments (for example the message text of a `CHAT_MSG_*` event) reach the handler after `ctx`. A handler is limited to one run per its interval, so busy events such as the combat log are not suitable; `UNIT_SPELLCAST_SUCCEEDED` is the better way to see a spell being cast.
- `full = true` runs the handlers with normal game globals, like a Developer rule. The editor asks for one more confirmation and warns that it can do anything an addon can.
- Handlers are throttled and have the usual limits: a card or bubble payload is checked like any extension's, a handler that fails three times in a row is switched off, and a package can only show cards and bubbles, never act in the game.
- WoW cannot stop an endless loop. The sandbox makes one less likely but cannot prevent it.
- Packages that cannot register, or that stop after errors, are listed under Problems on the Extensions page.
- Retail: the package creator is available in WoW Forever only for now.
