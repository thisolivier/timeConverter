import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// Page 3, assembled: the typed line, a hairline, the conversion, a hairline,
/// the footer — inside the glass.
///
/// ```
///   8pm Lisbon in São Paulo
///   ─────────────────────────────────────────────
///   FROM LISBON            TO SÃO PAULO
///   8:00 PM          ──▶   4:00 PM
///   Western European Time  Brasília Standard Time
///   ─────────────────────────────────────────────
///   São Paulo is 4 hours behind Lisbon.   Quit
/// ```
///
/// **Stateless.** It owns no input text, no driver and no focus — it is handed
/// a `GlassResultSection` and renders it. That is what lets the same layout
/// serve the live panel, the live dropdown and `ImageRenderer`'s offscreen
/// pass, which renders known states into PNGs for a design review that a
/// headless machine cannot screenshot.
///
/// The input field is a parameter rather than a member for the same reason: the
/// live callers hand over a focused `TextField` bound to their own state, and
/// the offscreen renderer hands over a `Text`, and neither has to know what the
/// other does.
struct GlassConverterLayout<InputField: View>: View {
    let presentation: GlassPresentation
    let section: GlassResultSection
    /// Normally the presentation's own — a floating window's glass for the
    /// panel, none at all for the dropdown. Overridden only by the offscreen
    /// renderer, which has no window for a behind-window material to sample
    /// and would otherwise photograph ink on nothing. See
    /// `GlassPanelSurfaceStyle.offscreen`.
    var surfaceStyle: GlassPanelSurfaceStyle?
    let onChipTap: (ReplacementChip) -> Void
    @ViewBuilder let inputField: () -> InputField

    private var metrics: GlassPanelMetrics { presentation.metrics }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            inputBlock
            resultBlock
            footerBlock
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.vertical, metrics.verticalPadding)
        .frame(width: metrics.totalWidth, alignment: .leading)
        .glassPanelSurface(surfaceStyle ?? presentation.surfaceStyle)
    }

    // MARK: - The typed line

    /// The design's `padding: 6px 4px 0` is an optical inset, not a layout one:
    /// it stops the oversized mono line from sitting hard against the panel's
    /// padding box, where it reads as cramped even though it is not.
    private var inputBlock: some View {
        VStack(alignment: .leading, spacing: metrics.inputRuleSpacing) {
            inputField()
                .padding(.top, metrics.inputTopPadding)
                .padding(.leading, metrics.inputLeadingPadding)
            GlassHairline()
        }
    }

    // MARK: - The conversion, or whatever there is instead

    @ViewBuilder
    private var resultBlock: some View {
        Group {
            switch section {
            case .hint:
                Text("Type a time to convert")
                    .font(PosterTypography.mono(size: metrics.footerFontSize + 1, weight: .regular))
                    .foregroundStyle(GlassPalette.secondaryInk)

            case let .pair(display):
                ConversionPairView(
                    display: display,
                    style: .glass,
                    scale: metrics.pairScale,
                    axis: metrics.pairAxis
                )

            case let .prompt(problem):
                GlassPromptView(
                    problem: problem, metrics: metrics, onChipTap: onChipTap
                )
            }
        }
        // Keeps the empty state from collapsing the panel to a sliver of glass
        // around one grey sentence. Not the pair's full height — matching that
        // would leave a prompt floating in an acre of nothing — just enough
        // that the panel still reads as a panel before anything is typed.
        .frame(
            maxWidth: .infinity,
            minHeight: metrics.inputFontSize * 2,
            alignment: .topLeading
        )
    }

    // MARK: - The footer

    private var footerBlock: some View {
        VStack(alignment: .leading, spacing: metrics.footerRuleSpacing) {
            GlassHairline()

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    // Always drawn, even when empty, so the footer line keeps
                    // its height and the panel does not change size between a
                    // conversion and a prompt.
                    Text(GlassFooterText.text(for: section, presentation: presentation))
                        .font(PosterTypography.mono(
                            size: metrics.footerFontSize, weight: .regular
                        ))
                        .foregroundStyle(GlassPalette.footerInk)
                        .fixedSize(horizontal: false, vertical: true)

                    // Two days a year, and it has to be legible on both.
                    if let note = GlassFooterText.note(for: section) {
                        Text(note)
                            .font(PosterTypography.mono(
                                size: metrics.footerFontSize - 2, weight: .regular
                            ))
                            .foregroundStyle(GlassPalette.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                quitButton
            }
        }
    }

    /// An app with no Dock icon and no menu bar of its own has no other way
    /// out, so this cannot move — but it can be quiet. Set in the footer's own
    /// mono at the footer's own weight, it reads as the last word of the
    /// furniture rather than as a button bolted onto a poster.
    private var quitButton: some View {
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .buttonStyle(.plain)
            .font(PosterTypography.mono(size: metrics.footerFontSize, weight: .regular))
            .foregroundStyle(GlassPalette.secondaryInk)
            .accessibilityLabel("Quit Time Converter")
    }
}

/// The design's typed line: oversized mono, no box, no background, no focus
/// ring — the panel *is* the box.
///
/// Shared by the two live callers so the one piece of the layout a user
/// actually types into is described once. `.plain` is doing real work here: a
/// `.roundedBorder` field would put a second container inside a panel whose
/// entire job is to be the container.
struct GlassInputField: View {
    @Binding var text: String
    let metrics: GlassPanelMetrics
    let onSubmit: () -> Void

    var body: some View {
        TextField("e.g. 12pm ET in London", text: $text)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .lineLimit(1)
            .glassInputLine(metrics: metrics)
            // Submitting is an action, not typing, so it skips the debounce.
            .onSubmit(onSubmit)
    }
}

/// The same line, drawn rather than edited.
///
/// `ImageRenderer` cannot rasterise a `TextField` — it is an AppKit control
/// under the SwiftUI surface, and an offscreen pass has no view hierarchy to
/// host one, so it renders as SwiftUI's yellow "unsupported" bar. The offscreen
/// QA renderer therefore hands the layout this instead, and because both go
/// through `glassInputLine` the picture is of the real type at the real size
/// rather than of something that resembles it.
struct GlassInputEcho: View {
    let text: String
    let metrics: GlassPanelMetrics

    var body: some View {
        Text(text.isEmpty ? "e.g. 12pm ET in London" : text)
            .lineLimit(1)
            .glassInputLine(metrics: metrics)
            // The placeholder is furniture, not content, and has to read as
            // such in a picture the way it does in the live field.
            .opacity(text.isEmpty ? 0.45 : 1)
    }
}

private extension View {
    /// The design's typed line: oversized mono at weight 500, in the panel's
    /// full-strength ink. One definition, two callers — the live field and the
    /// offscreen echo — so a picture of the panel cannot flatter it.
    func glassInputLine(metrics: GlassPanelMetrics) -> some View {
        font(PosterTypography.mono(size: metrics.inputFontSize, weight: .medium))
            .foregroundStyle(GlassPalette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
