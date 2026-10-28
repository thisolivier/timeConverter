import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// Everything below the arrow: the result band, or whatever the app has
/// instead of a result.
///
/// The design only draws the happy path, so the other two states are *styled
/// in the design's language* rather than left behind — a prompt gets the same
/// uppercase letterspaced label and mono body the result band gets, in rust
/// instead of ink. Dropping the chips to match the mockup was never an option;
/// they are the correction mechanic (items 7 and 9).
///
/// Logic-free, exactly as the old output area was: a `switch` over
/// `ConverterDisplayState`, whose every string arrives pre-rendered from
/// `TimeConverterCore`.
struct PosterResultSection: View {
    let displayState: ConverterDisplayState
    /// Item 19: `.compact` steps the numerals down so the band fits above the
    /// keyboard.
    var layoutMode: PosterLayoutMode = .full
    let onChipTap: (ReplacementChip) -> Void

    /// The design's 156pt, pulled back a little so the common `4:00` sits at
    /// full size inside an iPhone's content width instead of starting out
    /// scaled down.
    private let fullClockSize: CGFloat = 140
    private let fullMeridiemSize: CGFloat = 40

    /// ## Why a size *step* and not free scaling
    ///
    /// The obvious implementation of "squish the big time" is a `scaleEffect`
    /// driven by the space left over, and it was the wrong call twice over. It
    /// makes the numerals a different size on every device and at every
    /// keyboard height, so the poster's one fixed proportion — huge display
    /// type against 14pt mono — stops being a composition and becomes an
    /// accident; and a scaled `Text` renders at the unscaled size and is then
    /// resampled, which on black compressed type at this scale is visible as
    /// softened edges. Two deliberate sizes keep both the proportion and the
    /// crispness, and 92pt is still unmistakably poster type rather than a
    /// label. The meridiem comes down with it, in the same ratio.
    private let compactClockSize: CGFloat = 92
    private let compactMeridiemSize: CGFloat = 28

    private var clockSize: CGFloat {
        layoutMode.usesCompactResultType ? compactClockSize : fullClockSize
    }

    private var meridiemSize: CGFloat {
        layoutMode.usesCompactResultType ? compactMeridiemSize : fullMeridiemSize
    }

    var body: some View {
        switch displayState {
        case .hint:
            hintBand

        case let .converted(display):
            convertedBand(display)

        case let .problem(problem):
            problemBand(problem)
        }
    }

    // MARK: - The design's own band

    private func convertedBand(_ display: ConverterDisplay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // The star (item 31) sits beside the header; no star on a
            // `(local)` target, whose clock is always the Clocks tab's first row.
            HStack(alignment: .center, spacing: 8) {
                Text(display.targetPlaceLabel)
                    .posterLabel(size: 14)
                    .foregroundStyle(PosterPalette.ink)
                if let destination = display.favouritableTarget {
                    FavouriteStarButton(destination: destination)
                }
            }

            // One `Text`, not two in an `HStack`: concatenation keeps the
            // numerals and the meridiem on a shared baseline *and* scales them
            // together, so `12:30 AM` shrinks as one object rather than the
            // two parts drifting apart.
            (
                Text(display.targetClockDigits)
                    .font(PosterTypography.display(size: clockSize))
                    + Text(" ").font(PosterTypography.display(size: meridiemSize))
                    + Text(display.targetMeridiem)
                    .font(PosterTypography.display(size: meridiemSize))
            )
            .foregroundStyle(PosterPalette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
            .accessibilityLabel("\(display.targetClockDigits) \(display.targetMeridiem)")

            // The zone line (item 21), where `UTC-3` used to be. Hidden when
            // empty, which only happens for GMT and UTC — printing a blank
            // letterspaced line would still take 14pt of height and leave the
            // rule floating.
            if !display.targetZoneLine.isEmpty {
                Text(display.targetZoneLine)
                    // 13pt at 0.10em rather than the design's 15pt at 0.14em.
                    // The design was setting `UTC−3`: five characters, where
                    // generous letterspacing is the whole effect. This line is
                    // now up to about thirty-five — `BRASILIA STANDARD TIME
                    // (SÃO PAULO)` — and at the design's tracking it wraps to
                    // two lines on an iPhone. Tightened, it fits on one and
                    // still reads as the same family of label.
                    .posterLabel(size: 13, em: 0.10)
                    .foregroundStyle(PosterPalette.ink)
                    // Halved from 6 (item 21): the zone line is a caption on
                    // the numerals above it, and the design's gap read as a
                    // gap between two separate things.
                    .padding(.top, 3)
                    // Wraps rather than truncates if it still overflows — a
                    // city name cut mid-word would be worse than two lines.
                    .fixedSize(horizontal: false, vertical: true)
            }

            PosterRule()
                // Halved from 18, same instruction, same reason — the rule
                // closes this band, and pulling it up ties the three lines
                // together as one block.
                .padding(.top, 9)

            Text(display.footerSentence)
                .font(PosterTypography.mono(size: 14, weight: .regular))
                .foregroundStyle(PosterPalette.ink)
                .padding(.top, 14)

            // Two days a year, and it has to be legible on both of them.
            if let note = display.daylightSavingNote {
                Text(note)
                    .font(PosterTypography.mono(size: 13, weight: .regular))
                    .foregroundStyle(PosterPalette.accentText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Nothing typed yet

    private var hintBand: some View {
        Text("Type a time to convert")
            .font(PosterTypography.mono(size: 14, weight: .regular))
            .foregroundStyle(PosterPalette.quietInk)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - A prompt

    /// The verbose multi-line prompt copy is kept verbatim — it is the spec's
    /// wording and still the clearest thing on screen when a sentence will not
    /// parse. What changed is only its setting: rust mono under a letterspaced
    /// label, which is the design's vocabulary for "this band is about X".
    private func problemBand(_ problem: ConverterProblem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Can't convert yet")
                .posterLabel(size: 13)
                .foregroundStyle(PosterPalette.accentText)

            Text(problem.message)
                .font(PosterTypography.mono(size: 15, weight: .regular))
                .foregroundStyle(PosterPalette.accentText)
                .fixedSize(horizontal: false, vertical: true)

            if !problem.chips.isEmpty {
                PromptChipRow(chips: problem.chips, onTap: onChipTap)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
