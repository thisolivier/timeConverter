# Poster

The iPhone's half of the poster design, from
`docs/design/Time Converter.{pdf,html}` (backlog item 18). A retro print
poster: cream paper, black condensed display type, one rust accent,
letterspaced uppercase labels, hard rules.

**The tokens themselves now live elsewhere.** Item 20 moved `PosterPalette`,
`PosterTypography` / `.posterLabel()` and the `PosterArrow` shape into the
`TimeConverterUI` product inside the `TimeConverterCore` package, so the iPad
layouts and the Mac glass panel draw from the same ones. They moved unchanged
— this screen renders byte-identically to what it shipped — and the reasoning
that used to be documented here travelled with them. What stayed in this
directory is the furniture only the iPhone's vertical poster uses.

Nothing here knows what a timezone is. These are shapes and layout, plus one
view (`PosterResultSection`) that switches over a `ConverterDisplayState`
whose strings all arrive pre-rendered from `TimeConverterCore`.

## Working patterns

- **System fonts only. No font files are bundled.** The design sets Anton and
  JetBrains Mono; this renders SF Compressed Black
  (`Font.system(size:weight:).width(.compressed)`) and SF Mono
  (`design: .monospaced`). SF Compressed is not Anton — slightly wider,
  rounder counters — but it is the same *kind* of face, which is what the
  design is using Anton for.
- **Three colour tokens and nothing else.** `paper`, `ink`, `accent`, taken
  verbatim from the design's inline styles. A fourth value, `accentText`,
  exists only because rust-on-cream at body size is 4.04:1 and needed
  deepening to clear AA; it is the same hue. All four now come from
  `TimeConverterUI`.
- **The footer names its subject** (item 20). `São Paulo is 4 hours behind
  Lisbon.` rather than the bare `4 hours behind Lisbon.` the iPhone shipped
  with. The sentence is built in the core and is the same on every platform;
  nothing in this directory changed to adopt it. It is the one intended
  difference between this screen today and its last screenshot.
- **Dark mode is a straight inversion**, not a second palette: ink becomes the
  paper, cream becomes the ink. The accent is lifted (`#E0633F`) because
  `#B5391F` on near-black is 2.4:1 and vanishes. Both modes have a `#Preview`
  in `ContentView.swift`.
- **Fixed point sizes, not text styles.** The poster is a composition — a
  140pt numeral next to a 12pt label — and letting the two scale
  independently destroys it. Long results stay legible through
  `minimumScaleFactor` instead. This is the thing to revisit if accessibility
  sizes are asked for.
- **Two size steps, not free scaling** (item 19). When the keyboard collapses
  the layout, the numerals go 140 → 92pt and the meridiem 40 → 28pt, as a
  *step*. A `scaleEffect` driven by the space left over was the obvious
  implementation and is wrong twice: it makes the numerals a different size on
  every device and at every keyboard height, so the fixed proportion above
  stops being a composition and becomes an accident, and a scaled `Text`
  renders at its unscaled size and is resampled, which is visible as softened
  edges on black compressed type at this scale.
- **The zone line is set tighter than the design's offset was** (item 21). The
  design set `UTC−3` at 15pt / 0.14em, where generous letterspacing across five
  characters *is* the effect. That slot now holds up to about thirty-five
  characters — `BRASILIA STANDARD TIME (SÃO PAULO)` — which wraps to two lines
  at the design's tracking, so it is 13pt / 0.10em here. The gaps below the big
  time (6 → 3) and below the zone line (18 → 9) are halved, which pulls the
  header, numerals and zone line together into one block instead of three
  stacked things.
- **Square corners everywhere.** A corner radius on the input box is the one
  change that would make the whole screen look like a form instead of a print.
- **Our features get styled, never dropped.** The mockup draws only the happy
  path, so the prompt and its tap-to-replace chips are rendered *in the
  design's vocabulary* — letterspaced label, rust mono body, square outlined
  chips that invert when pressed — rather than left in system styling or
  removed to match the picture.

## Components

| File | Purpose |
|---|---|
| `PosterComponents.swift` | `PosterRule`, `PosterArrowSeparator` and `PosterBox` — this screen's own furniture. The arrow *shape* it strokes comes from `TimeConverterUI`. |
| `FavouriteStarButton.swift` | Item 31's star at the far right of the result's time row (`12:45 AM   ☆`/`★`). Shown only when `ConverterDisplay.favouritableTarget` is non-nil (never for a `(local)` target); reads the `FavouritesStore` from the environment, optionally, so previews draw no star. |
| `PosterResultSection.swift` | Everything below the arrow: the result band, the hint, or a prompt plus chips. Logic-free. Takes a `PosterLayoutMode` and owns the two display-type sizes that go with it. |

Imported from `TimeConverterUI` rather than defined here: `PosterPalette` (the
colour tokens, as appearance-reactive colours, carrying the contrast
reasoning), `PosterTypography` plus the `.posterLabel()` modifier, and
`PosterArrow` (transcribed from the design's own SVG rather than approximated
with `arrow.down`). That module also holds the pieces this screen does *not*
use — the glass palette, the right-pointing arrow and `ConversionPairView` —
which are for the Mac and iPad layouts in phases B and C.

The layout that assembles these — title, rule, labelled input box with the
source echo inside it, arrow band, result — is `ContentView.swift`, one level
up, because it also owns the behaviour (focus, scene phase, the launcher
mailbox, and since item 19 the keyboard choreography) that the redesign
deliberately left untouched. `KeyboardVisibility.swift` beside it supplies the
one platform fact that choreography needs; the decision it feeds is
`PosterLayoutMode`, in `TimeConverterCore`, where it is unit-tested.
