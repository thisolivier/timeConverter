import SwiftUI

/// The two typefaces of the design, rendered with **system fonts only** — no
/// font files are bundled.
///
/// Shared by both visual languages. The glass design (page 3) sets the same
/// Anton and JetBrains Mono as the paper poster does, at its own sizes — the
/// type is the constant across the two, the colour is the variable.
///
/// ## Display: Anton → SF Compressed Black
///
/// The design sets its headline and its result numerals in Anton: a single
/// weight, very heavy, very narrow, uppercase-feeling grotesque. The closest
/// thing the system ships is San Francisco at `.black` weight in the
/// `.compressed` width — `Font.system(size:weight:).width(.compressed)`,
/// available since iOS 16 and therefore unconditionally available on this
/// app's iOS 26 / macOS 26 floor.
///
/// It is not Anton. SF Compressed Black is a little less narrow, its counters
/// are rounder, and its digits have SF's flatter terminals. What it does match
/// is the thing the design is actually using Anton *for* — a black, condensed,
/// poster-scale display face that makes `4:00` an image rather than a label.
/// `.condensed` was tried first and is visibly too wide at 140pt;
/// `.compressed` is the right call.
///
/// ## Mono: JetBrains Mono → SF Mono
///
/// `Font.system(design: .monospaced)` is SF Mono, which is what the design's
/// own fallback stack asks for (`ui-monospace`). Close enough that the
/// substitution is invisible in everything but the lowercase `l`.
///
/// ## Dynamic Type
///
/// Sizes are fixed points rather than text styles, because the design is a
/// poster with a fixed internal proportion — a 156pt numeral beside a 12pt
/// label is the composition, and letting the two scale independently destroys
/// it. Legibility is instead protected by `minimumScaleFactor` on the display
/// type, which keeps a long result on one line at any width. Honest trade-off,
/// and the thing to revisit if accessibility sizes are ever asked for.
public enum PosterTypography {
    /// Anton's stand-in. Used for the two title lines, the place names and the
    /// result numerals.
    public static func display(size: CGFloat) -> Font {
        Font.system(size: size, weight: .black).width(.compressed)
    }

    /// SF Mono, for every detail line in both designs: the typed input, the box
    /// echo, the labels, the sub-lines, the footer.
    public static func mono(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }

    /// The design's uppercase letterspaced labels — `TIME & PLACES`,
    /// `IN SÃO PAULO`, `FROM`, `TO` — at 0.16em, converted to the points
    /// SwiftUI's `tracking` wants.
    public static func labelTracking(forSize size: CGFloat, em: CGFloat = 0.16) -> CGFloat {
        size * em
    }
}

extension View {
    /// One of the design's small uppercase letterspaced labels.
    ///
    /// Uppercasing happens here rather than in the presenter on purpose: the
    /// label's *content* is `In São Paulo`, and shouting it is typography.
    /// `textCase` also uppercases correctly for the locale, which a
    /// `.uppercased()` in a string builder would not.
    public func posterLabel(size: CGFloat = 13, em: CGFloat = 0.16) -> some View {
        self
            .font(PosterTypography.mono(size: size))
            .tracking(PosterTypography.labelTracking(forSize: size, em: em))
            .textCase(.uppercase)
    }
}
