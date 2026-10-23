import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// A disambiguation prompt and its tap-to-replace chips, drawn on glass.
///
/// The design (page 3) has no prompts in it — like the iPhone's poster, it
/// draws only the happy path. Dropping them was never on the table: P4 and P5
/// chips are how a user gets out of an ambiguous or misspelled zone, and P1 and
/// P2 are the only thing on screen when a sentence will not parse at all.
///
/// So they are drawn in the panel's own vocabulary, which is a different
/// vocabulary from the poster's and deliberately so. The iPhone sets its
/// prompts in rust — caption and message both — because the poster has an
/// accent colour and a prompt is the one place it is allowed to shout. Glass
/// has no accent: the single colour decision page 3 makes is that the arrow is
/// *grey* rather than rust, and adding a second accent for the error state
/// would undo it. On a material, hue does not carry and weight does, so the
/// hierarchy here is built the way the rest of the panel's is — a quiet
/// letterspaced caption over a full-strength message.
///
/// Logic-free: both strings arrive pre-rendered on `ConverterProblem`, and each
/// chip already carries the edit it performs.
struct GlassPromptView: View {
    let problem: ConverterProblem
    let metrics: GlassPanelMetrics
    let onChipTap: (ReplacementChip) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.footerRuleSpacing) {
            Text("Can't convert yet")
                .posterLabel(size: ConversionPairScale.full.labelSize)
                .foregroundStyle(GlassPalette.promptCaptionInk)

            Text(problem.message)
                .font(PosterTypography.mono(size: messageSize, weight: .regular))
                .foregroundStyle(GlassPalette.promptMessageInk)
                // The spec's prompt copy is several sentences for P2 and P5 and
                // is kept verbatim, so it has to be allowed to use the height
                // it needs rather than being truncated into uselessness.
                .fixedSize(horizontal: false, vertical: true)

            if !problem.chips.isEmpty {
                ChipFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(problem.chips) { chip in
                        Button(chip.label) { onChipTap(chip) }
                            .buttonStyle(GlassChipButtonStyle())
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One step under the input line's mono and one over the footer's, which
    /// puts the prompt where the conversion would have been in the reading
    /// order as well as on the screen.
    private var messageSize: CGFloat { metrics.footerFontSize + 1 }
}

/// A chip on glass: a rounded, outlined, translucent control in the mono face.
///
/// `.buttonStyle` rather than a tap gesture on a styled `Text`, because the
/// chips have to stay real buttons — focusable, space-activatable, and visible
/// to VoiceOver as controls. `contentShape` makes the whole rounded rectangle
/// the hit target rather than just the glyphs, which on a one-word label like
/// `ET?` is the difference between a chip you can click and one you can nearly
/// click.
///
/// Translucent rather than opaque: an opaque pill on a frosted panel reads as a
/// sticker. The fill is enough to separate the chip from the material behind it
/// and no more, and the pressed state goes a long way further because a 10%
/// change in fill is invisible on a surface that is already showing the
/// desktop through it.
private struct GlassChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: GlassPalette.chipCornerRadius, style: .continuous
        )
        return configuration.label
            .font(PosterTypography.mono(size: 13))
            .foregroundStyle(GlassPalette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                shape.fill(
                    configuration.isPressed
                        ? GlassPalette.chipPressedFill
                        : GlassPalette.chipFill
                )
            )
            .overlay(
                shape.strokeBorder(
                    GlassPalette.chipStroke, lineWidth: GlassPalette.hairlineThickness
                )
            )
            .contentShape(shape)
    }
}
