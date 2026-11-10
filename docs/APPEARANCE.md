# Appearance

Everything here is in **Settings › Appearance** (`/bsl`). Changes apply at once; the **Preview** page lets you see each choice on real-looking cards.

## Materials

The material is what the island and its cards are made of. Bubbles (the round timers beside the island) are always dark glass, whatever material you pick, so their text stays light and readable.

### Banzai Glass (default)

A deep green-black, slightly translucent surface. Text is a soft off-white; values and captions use the bright BANZAI colours - lime and emerald for gains and success, violet for the arcane, amber for warnings, crimson for errors.

### Solid

The same green-black, fully opaque. Same colours as Glass. Pick it if translucency over a busy world bothers you.

### Hardkorh Parchment

Cream paper with worn edges and corners, laid at a fixed grain so it never stretches - a wide card has more paper, not bigger paper. Text is written in **ink**: dark warm charcoal for titles and values, a quieter brown-grey for captions, and dark semantic inks that keep their meaning - deep forest green for gains and success, dark teal for information, deep plum for the arcane, burnt amber for warnings, deep wine for errors, dark blue for blue. Class-coloured names use a dark ink of their class hue (a Priest's is a dark silver).

Every ink is checked for comfortable contrast against the darkest grain of the paper, not just the average.

## Chassis

The chassis is the island's edge construction.

### Bamboo

A small bamboo end-cap at each end, softly chamfered corners, and one-pixel accent hairlines along the top and bottom. As the island grows into a card the caps stay at the ends and the lines widen.

### Hairline

A four-sided, one-pixel accent frame and sharp corners. It simply grows with the island - the sides lengthen, the top and bottom widen - with no caps.

## Accents

The accent is the colour family the bar, percentages, hairlines, rings and the primary button draw from.

| Accent | Colours | Notes |
|---|---|---|
| **Banzai** | lime → emerald → violet → purple | the BANZAI signature |
| **Class** | your class colour, darker to lighter | the identity disc on cards and the level-up card use your original BANZAI class artwork either way |
| **Hardkorh** | bright green → emerald → violet → purple | the HARDKORH variant of the Banzai ramp |

The BANZAI SLAND mark on the island's top edge keeps its own identity under every accent.

## Fonts

- **Display font** - the face for titles, the SLAND wordmark and other BANZAI display text. The control cycles through, in this order: *Automatic*, *BANZAI Default*, *Shojumaru*, *Ryujin Attack*, *Gang of Three*, *Osaka Sans*, *Sekaiwo*, *Xangda Shiny*, *Ninja Naruto*, *Information Font*.
  - *BANZAI Default* is Shojumaru at 105% (the default).
  - *Automatic* uses BANZAI Default only when the complete display string is supported; otherwise the whole string uses the Information Font. Text is never spliced character by character.
  - An alternate chosen explicitly is drawn at its own size (no 105% base); any string it cannot show uses the Information Font as a whole. *Xangda Shiny* has letters only, so strings with digits fall back.
  - A saved choice of a face that is no longer shipped becomes BANZAI Default.
- **Information font** - Open Sans, for timers, values and small text and as the unsupported-string fallback. The **Font** control lets you pick another font you have installed through a shared-media font list if you prefer.
- The display-font selection is independent of BANZAI UI. The BANZAI half of the launcher remains graphical; only SLAND uses the selected display face.
- **Text size** - a slider for everything on the island (the settings window keeps its own size).
- **Font outline** - none, thin or thick.
- Authors, sources, licence basis and checksums of every shipped face are in `Media/Banzai/Fonts/FONT-NOTICES.txt` inside the addon and in `THIRD_PARTY_NOTICES.md`.

## Placement and size

- **Position** - *Top* (centred under the top edge), or *Free* after you drag it in edit mode. There is an edit-mode box with the exact coordinates.
- **Idle style** - how much the resting island shows: the full bar, a percentage, a small dot, or hidden until something happens.
- **Opacity**, **island border**, **colours** for the bar, rest and quest XP, and the settings window itself are under *More colors*, *Island border* and *Settings window*.

## Other looks

Under **Look** there are also the original BANZAI class artwork switch (on by default), accent rings on bubbles, accent hairlines and bamboo end-caps switches, and a *Forever* look variant (a bronze-edged style; a visual option only, not a platform).
