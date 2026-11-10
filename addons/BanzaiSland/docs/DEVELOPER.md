# Package handler code

A package handler is a short piece of Lua that Island runs when a game event happens. You write it in the package creator (`/island packages`, or Package creator on the Extensions page); see the Extension packages section of [EXTENSIONS.md](EXTENSIONS.md) for the creator, sharing and the sandbox. This page covers the code itself.

If you used the old Developer Lua editor: it became the package creator in this release. Your existing rules were turned into one package, "Developer rules", with the same code and on/off state.

## Turning it on

Package code only runs while **Allow package code** is on (the switch at the top right of the Extensions page, or the button at the top left of the package creator). It is off by default. With it off, packages stay listed but their handlers do not run, and Test, Enable and Import are refused. This switch does not affect separate addons that use the API.

Only run code you trust. Code has normal access to game globals when a package asks for full access; in the default sandbox it is read-only (the allowed functions are listed in EXTENSIONS.md). Neither mode prevents an endless loop, and neither can bypass Blizzard's protected-action and secret-value restrictions.

## The function

Each handler is the body of `function(event, state, ctx, ...)`:

- `event` is the game event name, or `ISLAND_INIT` or `ISLAND_TEST` (see below).
- `state` is a private table for that handler. It starts empty when the package is switched on, after a loading screen, and when Allow package code is turned back on.
- `ctx` has `setting(key)`, `enabled(featureId)`, `pause()`, `resume()` and `cancel()` (the last three work on this handler's own countdown or card and bubble).
- `...` holds the live event arguments, for example the message text of a chat event.

Return a payload table to show something, or `nil` or `false` to show nothing.

- `ISLAND_INIT` runs once so you can record a starting value silently. Its return value is always ignored.
- `ISLAND_TEST` is sent by Test, without event arguments. Handle it explicitly if your code expects arguments, or return a sample so you can see the result.
- Your chosen events run your code and return the real output.

A unit filter is optional (`player`, `target`, `party1`, and so on). For events whose names start with `UNIT_`, only a readable first argument that matches the filter runs the code. Event names are exact uppercase game names. Loading lifecycle names and `ISLAND_*` cannot be subscribed to. An unknown event disables the handler.

## What to return

A handler's feature decides whether it shows a card or a bubble.

- A card takes `title` (required), `text`, `caption`, `icon`, `group`, `duration`, `ttl`, `progress` or `countdown`, and `barColor`.
- A bubble takes `text` (required), `tooltip`, `icon`, `ttl`, `persistent`, `progress`, `bar`, `barColor` and `countdown`.

Field rules and limits are in [EXTENSIONS.md](EXTENSIONS.md) (Card payload, Bubble payload, Bars on bubbles, Countdown bubbles). Never return internal fields, callbacks, buttons or frames. Output is checked like any extension's: accepted means submitted, not necessarily seen, and Do Not Disturb, combat and typing settings still apply. Identical output does not restart a card or renew its time; changed output updates the same key.

## Limits

- Up to 8 packages, 12 handlers each, 8 events per handler, 8,192 bytes of code per handler, 64 KB per package.
- A handler's minimum interval is 0.1 to 60 seconds (default 0.5). It is a leading-edge cooldown: events inside it are dropped, not delayed or replayed. All handlers also share a burst of ten runs, refilling ten per second. Test and initialization skip these cooldowns, but their output still uses the normal sending limits.
- Three failures in a row switch a handler off and clear what it showed. An error during initialization switches it off at once. The creator shows the last error and the last output.
- Saving a change to code, events or access switches the package off until you turn it on again.

Do not put sensitive event arguments in notification text. Logs never keep event argument lists.

## Example: low potions

Events: `BAG_UPDATE_DELAYED`, a card feature, minimum interval `0.5`.

```lua
local getter = C_Item and C_Item.GetItemCount or GetItemCount
if not getter then return end
local count = getter(118, false, false)
if issecretvalue and issecretvalue(count) then return end
if type(count) ~= "number" then return end

if event == "ISLAND_INIT" then
    state.count = count
    return
end
if event == "ISLAND_TEST" then
    return {title="Supply test", text="This handler can send a card."}
end
local before = state.count
state.count = count
if before and count < before and count < 3 then
    return {
        title="Time to restock",
        text=("Minor Healing Potions remaining: %d"):format(count),
        icon=134829, group="alerts", duration=5, ttl=20,
    }
end
```

This notices any decrease in bag count, including moving or selling items, so it does not tell you the item was used. Add your own checks, record a baseline instead of treating unknown data as zero, and keep long calculations and loops out of event handlers.
