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
- **One cross-platform `#if`, on purpose.** `PaletteTone.swift` is the only
  file that knows `UIColor` from `NSColor`. Everything else differs between
  the two shells by *layout*, which is a design decision, not a platform one.
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
| `Tokens/GlassPalette.swift` | The glass panel's material, rim lights, shadow and ink-on-glass greys, transcribed from page 3 with the CSS-to-token mapping in a table. |
| `Typography/PosterTypography.swift` | Anton → SF Compressed Black, JetBrains Mono → SF Mono, and the `.posterLabel()` modifier for the letterspaced uppercase labels. Shared by both palettes. |
| `Components/PosterArrows.swift` | `PosterArrow` (the iPhone's stroked down arrow), `PosterRightArrow` (the filled wedge between the pair's columns), and `PosterLabeledArrow` (page 4's variant with a phrase beneath). Colourless — the caller tints them. |
| `Components/ConversionPairStyle.swift` | The two knobs: `ConversionPairStyle` (paper/glass — inks, arrow tint, label placement) and `ConversionPairScale` (full/compact — every point size). |
| `Components/ConversionPairView.swift` | The side-by-side pair itself: `FROM`/`TO` columns of label, place, big time + meridiem and zone sub-line, with the arrow between them. One view for pages 2, 3 and 4. |

## Phase A scope

Built here, used by nobody yet except the iPhone (which adopts only the tokens,
the typography and the arrow shape it already had). `ConversionPairView` has
previews and tests but no shipping caller: the Mac glass panel is phase B and
the iPad layouts are phase C. The pair view's API is the contract those two
phases were extracted against —

```swift
ConversionPairView(
    display: converterDisplay,   // every string pre-rendered by the core
    style: .glass,               // .paper (pages 2, 4) | .glass (page 3)
    scale: .full,                // .full | .compact (keyboard up)
    arrowLabel: nil              // page 4 passes display.offsetPhrase
)
```
