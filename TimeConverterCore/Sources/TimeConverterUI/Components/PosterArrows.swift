import SwiftUI

/// The design's arrows, transcribed from its own SVG rather than approximated
/// with SF Symbols.
///
/// `arrow.down` and `arrow.right` were the obvious shortcut and are wrong: they
/// have rounded caps, a lighter stroke and a shorter stem, and beside black
/// compressed type they read as UI chevrons instead of as printed ink. Twenty
/// lines of `Path` against the design's own viewBoxes is cheaper than the
/// compromise.
///
/// Both shapes are colourless. The paper layouts fill them with
/// `PosterPalette.accent`, the glass panel with `GlassPalette.secondaryInk` —
/// which is the single biggest visual difference between pages 2 and 3, and is
/// why these are shapes and not views with a colour baked in.

/// The vertical arrow between the input and the result on the iPhone poster.
/// **Stroked**, against the design's `0 0 26 32` viewBox.
public struct PosterArrow: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
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

/// The horizontal arrow between the FROM and TO columns on pages 2, 3 and 4.
///
/// **Filled**, not stroked, and that is the design's own choice rather than
/// ours: its SVG is a single closed path with a `fill` and no `stroke`
/// (`<svg width="72" height="42" viewBox="0 0 110 64">`, path
/// `M0 22h62V0l48 32-48 32V42H0z`). A solid wedge beside 124pt display type
/// holds its weight; a 5pt stroke at that scale would not.
///
/// Scales to whatever frame it is given, so page 4's longer, flatter arrow is
/// the same shape in a wider box rather than a second transcription.
public struct PosterRightArrow: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let horizontalScale = rect.width / 110
        let verticalScale = rect.height / 64
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * horizontalScale, y: rect.minY + y * verticalScale)
        }

        var path = Path()
        // The shaft: M0 22 h62 — a 20-unit bar across the left five-ninths.
        path.move(to: point(0, 22))
        path.addLine(to: point(62, 22))
        // The head: V0 l48 32 -48 32 V42 — a triangle twice the shaft's depth,
        // which is what stops it reading as a chevron.
        path.addLine(to: point(62, 0))
        path.addLine(to: point(110, 32))
        path.addLine(to: point(62, 64))
        path.addLine(to: point(62, 42))
        // H0 z — back along the bottom of the shaft and closed.
        path.addLine(to: point(0, 42))
        path.closeSubpath()
        return path
    }
}

/// Page 4's variant: the same right arrow with a short phrase set beneath it —
/// `4 hours behind`, in rust, in the mono face.
///
/// It exists because the keyboard-up iPad layout has no room for the footer
/// sentence, and losing the relationship between the two times along with it
/// would be losing the one thing the screen is *about*. The arrow already
/// points from the source to the target, so the phrase underneath it needs no
/// place names and fits where a sentence would not.
///
/// The label is `nil`-able at the call site rather than here: a view that draws
/// an empty `Text` still reserves its line height, which would nudge the arrow
/// off the numerals' centre. See `ConversionPairView`.
public struct PosterLabeledArrow: View {
    private let label: String
    private let tint: Color
    private let arrowSize: CGSize
    private let labelSize: CGFloat

    public init(
        label: String,
        tint: Color = PosterPalette.accent,
        arrowSize: CGSize = CGSize(width: 72, height: 42),
        labelSize: CGFloat = 14
    ) {
        self.label = label
        self.tint = tint
        self.arrowSize = arrowSize
        self.labelSize = labelSize
    }

    public var body: some View {
        VStack(spacing: 4) {
            PosterRightArrow()
                .fill(tint)
                .frame(width: arrowSize.width, height: arrowSize.height)

            Text(label)
                .font(PosterTypography.mono(size: labelSize, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                // The phrase is a fixed vocabulary — "4 hours behind",
                // "5.75 hours ahead", "Same time" — so it is allowed to
                // shrink rather than wrap or truncate: a wrapped label would
                // push the arrow off the numerals it is aligned to.
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
        // One element, read as one phrase: "4 hours behind" with a picture of
        // an arrow in the middle of it is not a sentence.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}
