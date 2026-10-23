# TimeConverterUI

The shared SwiftUI design layer — backlog item 20, phase A. Second product of
the `TimeConverterCore` package, built for iOS 26 and macOS 26, depending on
`TimeConverterCore` and depended on by both app targets.

It exists because three of the four design pages
(`docs/design/Time Converter-selection.pdf`) draw the *same* side-by-side
conversion in two different visual languages, and building that twice — once
for the Mac glass panel, once for the iPad poster — would guarantee the two
drift. Extracting it first is what makes phases B and C assembly rather than
re-implementation.

## Working patterns

- **Core stays UI-free.** The dependency points one way: this module imports
  `TimeConverterCore`, never the reverse, and nothing in `TimeConverterCore`
  imports SwiftUI. A real target boundary rather than another folder, because
  that boundary is the thing enforcing it.
- **Two palettes, not one with variants.** `PosterPalette` is a print — opaque
  cream, opaque ink, one rust accent — and `GlassPalette` is a system material
  over the user's desktop, inked in Apple's label greys. They agree about
  nothing, and pretending otherwise would produce a palette that serves
  neither. What *is* shared is the typography: both designs set the same two
  faces, at their own sizes.
- **Design values are transcribed verbatim and the derivation is written
  down.** Every light-appearance glass token is the design's own literal, with
  a table in `GlassPalette.swift` mapping each CSS declaration to its token.
  The designs ship light only, so the dark values are derived — mostly by
  keeping the design's alphas and swapping Apple's light `secondaryLabel`
  tint for its dark one, which is a transcription rather than a new decision.
  The three that could not be mirrored mechanically say so in a comment.
- **System fonts only. No font files are bundled.** The designs set Anton and
  JetBrains Mono; this renders SF Compressed Black and SF Mono. See
  `PosterTypography.swift` for why the substitution is the right one.
- **Two cross-platform `#if`s, on purpose, and no more.** `PaletteTone.swift`
  is the only file that knows `UIColor` from `NSColor`;
  `GlassPanelSurface.swift` is the only one that knows `NSVisualEffectView`.
  Both earn it the same way: there is no cross-platform spelling, because
  there is no cross-platform *concept*. Everything else differs between the
  two shells by layout, which is a design decision, not a platform one.
- **Where the system has a real equivalent, the system wins.** The glass
  panel's frosting is an `NSVisualEffectView` and its shadow is the window's,
  rather than a transcription of the CSS. The mapping, declaration by
  declaration, is a table in `GlassPanelSurface.swift` — including the two
  design tokens that are deliberately *not* drawn on screen and what supplies
  them instead.
- **Layout decisions are derived from measurement, not declared.** The Mac
  dropdown stacks the conversion pair because
  `ConversionPairScale.largestFittingSideBySide(in:)` says no step fits at
  400pt — not because anything says `.stacked`. Pin a layout by hand and it
  survives the width change that invalidates it.
- **Two size steps, not free scaling.** `ConversionPairScale` is `.full` or
  `.compact`. A `scaleEffect` driven by leftover space makes the numerals a
  different size on every device and resamples black compressed type into
  softness; the iPhone already learned this in item 19.
- **No UTC offsets anywhere.** The designs draw `UTC+1` / `UTC−3` under the
  two times; this draws item-21 zone lines instead, on every platform. That is
  working assumption 1 of `docs/sprint-plan-ipad-mac.md` — item 21 is the newer
  decision. If Olivier rules the other way it changes in one place, and
  `ZoneReading.utcOffsetDescription` never went anywhere.
- **Tests cover what actually breaks.** Not snapshots — a pixel baseline
  asserts that SF Compressed renders the way it did the day it was taken.
  `Tests/TimeConverterUITests` covers the hand-transcribed arrow geometry, the
  proportions between the two size steps, and that the two styles genuinely
  disagree about their inks.

## Components

| File | Purpose |
|---|---|
| `Tokens/PaletteTone.swift` | One literal colour from a design file, plus `AppearanceReactiveColor` — the single `UIColor`/`NSColor` fork that pairs a light tone with a dark one. |
| `Tokens/PosterPalette.swift` | The paper design's cream/ink/rust, moved unchanged from the iOS app so the iPad draws from the same tokens the iPhone does. |
| `Tokens/GlassPalette.swift` | The glass panel's rim lights, shadow, ink-on-glass greys and chip tokens, transcribed from page 3 with the CSS-to-token mapping in a table. |
| `Tokens/GlassPanelMetrics.swift` | The same design measured instead of coloured: 740pt wide, `padding: 26px 30px`, the section gaps, the 34pt input. Plus the derived `.narrow` variant for the Mac dropdown, whose pair axis and size step it computes rather than declares. |
| `Typography/PosterTypography.swift` | Anton → SF Compressed Black, JetBrains Mono → SF Mono, and the `.posterLabel()` modifier for the letterspaced uppercase labels. Shared by both palettes. |
| `Components/PosterArrows.swift` | `PosterArrow` (the stroked down arrow, used by the iPhone and by the stacked pair), `PosterRightArrow` (the filled wedge between the pair's columns), and `PosterLabeledArrow` (page 4's variant with a phrase beneath). Colourless — the caller tints them. |
| `Components/GlassPanelSurface.swift` | Page 3's chrome: the `NSVisualEffectView` frosting, the rim stroke, the two inset highlights, the 30pt radius — in the three containers it can be drawn in (floating window / inside a system popover / offscreen). Plus `GlassHairline`, the design's 1pt rule. |
| `Components/ConversionPairStyle.swift` | The three knobs: `ConversionPairStyle` (paper/glass — inks, arrow tint, label placement), `ConversionPairScale` (full/compact — every point size, plus the fitting arithmetic) and `ConversionPairAxis` (side by side / stacked). |
| `Components/ConversionPairCells.swift` | One side's three pieces — caption + place, big time, zone line — shared by both axes, which need the same cells in different containers. |
| `Components/ConversionPairView.swift` | The pair itself: `FROM`/`TO` columns with the arrow between them (the design) or above and below (the narrow fallback). One view for pages 2, 3 and 4. |
| `Components/ChipFlowLayout.swift` | Wraps a row of tap-to-replace chips onto as many lines as they need. Pure geometry — both shells pack identically and paint completely differently. |

## Consumers

```swift
ConversionPairView(
    display: converterDisplay,   // every string pre-rendered by the core
    style: .glass,               // .paper (pages 2, 4) | .glass (page 3)
    scale: metrics.pairScale,    // .full | .compact — derived, not declared
    axis: metrics.pairAxis,      // .sideBySide | .stacked — likewise
    arrowLabel: nil              // page 4 passes display.offsetPhrase
)
```

- **iPhone** (phase A): the tokens, the typography and the arrow shape it
  already had. Its vertical poster is unchanged.
- **Mac** (phase B, shipping): the glass panel and the menu-bar dropdown are
  built entirely out of this module — `GlassPanelSurface`, `GlassPanelMetrics`
  and `ConversionPairView` — with only the state and the window plumbing left
  in `TimeConverterMac`.
- **iPad** (phase C, not yet): pages 2 and 4, paper, reusing the same pair at
  `.paper` and `.compact`.
