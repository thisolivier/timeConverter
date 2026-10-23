import SwiftUI
import TimeConverterUI

/// The pieces of the poster that are **this screen's** furniture rather than
/// the design system's.
///
/// The colour tokens, the typefaces and the arrow *shapes* moved into
/// `TimeConverterUI` in item 20 so the iPad and the Mac draw from the same
/// ones. What stayed here is what only the iPhone's vertical poster uses: its
/// 2pt rules, the rule-and-arrow band that separates input from result, and the
/// outlined input box. None of it is wrong to share later; none of it has a
/// second caller today.

/// The design's horizontal rules. Two weights: the 2pt rules that divide the
/// poster into bands, and the 1pt hairline inside the input box.
struct PosterRule: View {
    var thickness: CGFloat = 2

    var body: some View {
        Rectangle()
            .fill(PosterPalette.ink)
            .frame(height: thickness)
    }
}

/// The rule-and-arrow band between the input and the result: two 2pt rules
/// with a rust down-arrow floating in the gap.
struct PosterArrowSeparator: View {
    var body: some View {
        HStack(spacing: 12) {
            PosterRule()
            PosterArrow()
                .stroke(
                    PosterPalette.accent,
                    style: StrokeStyle(lineWidth: 5, lineCap: .butt, lineJoin: .miter)
                )
                .frame(width: 26, height: 32)
            PosterRule()
        }
        .accessibilityHidden(true)
    }
}

/// The design's outlined input box: a 2pt ink rectangle, square corners.
///
/// Square because every other edge in the poster is square — a corner radius
/// here is the single change that would make the whole screen look like a form.
struct PosterBox<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().strokeBorder(PosterPalette.ink, lineWidth: 2))
    }
}
