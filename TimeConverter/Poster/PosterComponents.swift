import SwiftUI

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

/// The arrow itself, transcribed from the design's own SVG rather than
/// approximated with an SF Symbol.
///
/// `arrow.down` was the obvious shortcut and is wrong: it has rounded caps, a
/// lighter stroke and a shorter stem, and beside black compressed type it reads
/// as a UI chevron instead of as printed ink. Ten lines of `Path` against the
/// design's `0 0 26 32` viewBox is cheaper than the compromise.
struct PosterArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let horizontalScale = rect.width / 26
        let verticalScale = rect.height / 32
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * horizontalScale, y: rect.minY + y * verticalScale)
        }

        var path = Path()
        // The stem: M13 0 V26.
        path.move(to: point(13, 0))
        path.addLine(to: point(13, 26))
        // The head: M2 16 L13 28 L24 16.
        path.move(to: point(2, 16))
        path.addLine(to: point(13, 28))
        path.addLine(to: point(24, 16))
        return path
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
