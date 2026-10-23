# Poster

The iOS app's visual language, from `docs/design/Time Converter.{pdf,html}`
(backlog item 18). A retro print poster: cream paper, black condensed display
type, one rust accent, letterspaced uppercase labels, hard rules.

Nothing here knows what a timezone is. These are colours, fonts and shapes,
plus one view (`PosterResultSection`) that switches over a
`ConverterDisplayState` whose strings all arrive pre-rendered from
`TimeConverterCore`.

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
  deepening to clear AA; it is the same hue.
- **Dark mode is a straight inversion**, not a second palette: ink becomes the
  paper, cream becomes the ink. The accent is lifted (`#E0633F`) because
  `#B5391F` on near-black is 2.4:1 and vanishes. Both modes have a `#Preview`
  in `ContentView.swift`.
- **Fixed point sizes, not text styles.** The poster is a composition — a
  140pt numeral next to a 12pt label — and letting the two scale
  independently destroys it. Long results stay legible through
  `minimumScaleFactor` instead. This is the thing to revisit if accessibility
  sizes are asked for.
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
| `PosterPalette.swift` | The colour tokens, as dynamic colours so both appearances resolve with no view state. Carries the contrast reasoning. |
| `PosterTypography.swift` | Anton → SF Compressed Black, JetBrains Mono → SF Mono, and the `.posterLabel()` modifier for the 0.16em uppercase labels. |
| `PosterComponents.swift` | `PosterRule`, `PosterArrowSeparator`, `PosterArrow` (transcribed from the design's own SVG rather than approximated with `arrow.down`), `PosterBox`. |
| `PosterResultSection.swift` | Everything below the arrow: the result band, the hint, or a prompt plus chips. Logic-free. |

The layout that assembles these — title, rule, labelled input box with the
source echo inside it, arrow band, result — is `ContentView.swift`, one level
up, because it also owns the behaviour (focus, scene phase, the launcher
mailbox) that the redesign deliberately left untouched.
