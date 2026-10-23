import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// The tap-to-replace chips under a prompt (backlog items 7 and 9).
///
/// Every chip arrives fully prepared by the presenter — a label and the edit it
/// performs — so this view decides nothing.
///
/// The design (item 18) has no chips in it, because its mockup only draws the
/// happy path. Dropping them was never on the table: they are how a user gets
/// out of an ambiguous or misspelled zone. So they are drawn in the design's
/// own vocabulary instead — square outlined boxes, ink on cream, mono label,
/// inverting to rust when pressed. They read as the little printed tickets the
/// rest of the poster implies.
///
/// The *packing* — wrapping onto as many lines as the chips need — moved into
/// `TimeConverterUI.ChipFlowLayout` in phase B, when the Mac's glass prompt
/// turned out to need the same arithmetic and none of the same paint. Nothing
/// about this screen changed with it.
struct PromptChipRow: View {
    let chips: [ReplacementChip]
    let onTap: (ReplacementChip) -> Void

    var body: some View {
        ChipFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(chips) { chip in
                Button(chip.label) { onTap(chip) }
                    .buttonStyle(PosterChipButtonStyle())
            }
        }
    }
}

/// Square, outlined, mono — and inverted while held, which is the only
/// animation anywhere in this design.
private struct PosterChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PosterTypography.mono(size: 13))
            .foregroundStyle(
                configuration.isPressed ? PosterPalette.paper : PosterPalette.ink
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(configuration.isPressed ? PosterPalette.accent : Color.clear)
            .overlay(Rectangle().strokeBorder(PosterPalette.ink, lineWidth: 1.5))
            .contentShape(Rectangle())
    }
}
