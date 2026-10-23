import SwiftUI
import TimeConverterCore

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
    let onChipTap: (ReplacementChip) -> Void

    /// The design's 156pt, pulled back a little so the common `4:00` sits at
    /// full size inside an iPhone's content width instead of starting out
    /// scaled down.
    private let clockSize: CGFloat = 140
    private let meridiemSize: CGFloat = 40

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
            Text(display.targetPlaceLabel)
                .posterLabel(size: 14)
                .foregroundStyle(PosterPalette.ink)

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

            Text(display.targetOffsetLine)
                .posterLabel(size: 14, em: 0.14)
                .foregroundStyle(PosterPalette.ink)
                .padding(.top, 6)

            PosterRule()
                .padding(.top, 18)

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
