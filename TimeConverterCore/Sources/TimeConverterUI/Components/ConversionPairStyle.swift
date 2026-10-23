import SwiftUI

/// Which of the two visual languages `ConversionPairView` is wearing.
///
/// The side-by-side pair is drawn three times across the design pages and the
/// *composition* is identical in all three — label, place, big time, sub-line,
/// arrow between. What changes is the ink and one piece of layout, and those
/// are exactly the two things this enum carries. Anything more would be a
/// second view pretending to be a parameter.
public enum ConversionPairStyle: String, Equatable, Sendable, CaseIterable {
    /// Pages 2 and 4: black compressed type on cream, rust arrow, `FROM`
    /// stacked above the place name.
    case paper
    /// Page 3: Apple's label greys on a system material, grey arrow, `FROM`
    /// set inline to the left of the place name on a shared baseline.
    case glass

    /// The place name and the big time.
    public var ink: Color {
        switch self {
        case .paper: return PosterPalette.ink
        case .glass: return GlassPalette.ink
        }
    }

    /// `FROM` / `TO` and the sub-line under the numerals.
    ///
    /// The paper design sets these in full-strength ink — it is a print, and a
    /// print has one ink — while the glass design steps them back to
    /// `secondaryLabel`, because on a material the hierarchy has to come from
    /// contrast rather than from size alone.
    public var quietInk: Color {
        switch self {
        case .paper: return PosterPalette.ink
        case .glass: return GlassPalette.secondaryInk
        }
    }

    /// The arrow between the columns. The single loudest difference between
    /// the two pages: rust on paper, grey on glass.
    public var arrowTint: Color {
        switch self {
        case .paper: return PosterPalette.accent
        case .glass: return GlassPalette.secondaryInk
        }
    }

    /// Whether `FROM` sits above the place name or beside it.
    ///
    /// Above on paper (pages 2 and 4), beside on glass (page 3). It tracks the
    /// style rather than the scale because it is a choice about the design's
    /// voice — the poster shouts its labels as a separate line of furniture,
    /// the panel tucks them in — and because both paper pages stack while the
    /// one glass page does not, which is the only evidence the designs offer.
    public var stacksLabelAbovePlace: Bool { self == .paper }
}

/// How big the pair is drawn.
///
/// A **step**, not free scaling, for the reason `PosterResultSection` already
/// documents at length on the iPhone: a `scaleEffect` driven by leftover space
/// makes the numerals a different size on every device and at every keyboard
/// height — so the fixed proportion of 124pt numerals against a 12pt label
/// stops being a composition and becomes an accident — and a scaled `Text`
/// renders at its unscaled size and is then resampled, which is visible as
/// softened edges on black compressed type.
public enum ConversionPairScale: Equatable, Sendable, CaseIterable {
    /// Pages 2 and 3: the design's own numbers, unmodified.
    case full
    /// Page 4, keyboard up: one step down, so the pair clears a 370pt system
    /// keyboard and still reads as poster type rather than as a label.
    case compact

    /// `FROM` / `TO`. Design: `font-size: 12px`.
    public var labelSize: CGFloat {
        switch self {
        case .full: return 12
        case .compact: return 11
        }
    }

    /// `LISBON`. Design: `font-size: 40px`, Anton, uppercase.
    public var placeSize: CGFloat {
        switch self {
        case .full: return 40
        case .compact: return 32
        }
    }

    /// `8:00`. Design: `font-size: 124px`.
    public var clockSize: CGFloat {
        switch self {
        case .full: return 124
        case .compact: return 92
        }
    }

    /// `PM`. Design: `font-size: 38px`.
    public var meridiemSize: CGFloat {
        switch self {
        case .full: return 38
        case .compact: return 28
        }
    }

    /// The item-21 zone line under the numerals, where the design drew `UTC+1`.
    /// Design: `font-size: 14px`.
    public var subLineSize: CGFloat {
        switch self {
        case .full: return 14
        case .compact: return 12.5
        }
    }

    /// The fixed middle column the arrow lives in. Design:
    /// `grid-template-columns: minmax(0, 1fr) 96px minmax(0, 1fr)`.
    ///
    /// Fixed rather than proportional so the two time columns stay equal and
    /// the arrow never drifts off centre as one place name gets longer than
    /// the other.
    public var arrowColumnWidth: CGFloat {
        switch self {
        case .full: return 96
        case .compact: return 76
        }
    }

    /// Design: `<svg width="72" height="42">`.
    public var arrowSize: CGSize {
        switch self {
        case .full: return CGSize(width: 72, height: 42)
        case .compact: return CGSize(width: 58, height: 34)
        }
    }

    /// The middle column when the arrow is carrying a phrase.
    ///
    /// Page 4 widens the gutter, and it has to: `4 hours behind` set under a
    /// 96pt-wide arrow does not fit, and a phrase that overruns its column
    /// collides with the numerals in the next one. Measured off the design,
    /// whose labeled gutter is roughly 1.75× its plain one.
    public var labeledArrowColumnWidth: CGFloat { arrowColumnWidth * 1.75 }

    /// Page 4's arrow is visibly longer and flatter than pages 2–3's — it
    /// stretches to fill the wider column rather than floating in the middle
    /// of it, which is what makes the phrase read as *its* label and not as a
    /// stray caption. Same path, different frame; see `PosterRightArrow`.
    public var labeledArrowSize: CGSize {
        CGSize(width: labeledArrowColumnWidth - 18, height: arrowSize.height)
    }

    /// The phrase under page 4's labeled arrow, sized to sit under the arrow
    /// rather than to compete with the numerals beside it.
    public var arrowLabelSize: CGFloat {
        switch self {
        case .full: return 14
        case .compact: return 13
        }
    }
}
