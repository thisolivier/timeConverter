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

/// Whether the two columns sit beside each other or one above the other.
///
/// Side by side is the design — all three pages draw it that way, and it is
/// the composition: two readings of one instant, with an arrow pointing from
/// the first to the second. `.stacked` exists for one caller, the Mac's
/// `MenuBarExtra` dropdown, where the design simply cannot be drawn: a menu-bar
/// popover is around 400pt wide and the pair needs about 600 at full scale and
/// 440 at compact, so side by side there would mean `minimumScaleFactor`
/// shrinking the numerals to caption size — which is not a smaller version of
/// the poster, it is the poster destroyed.
///
/// Stacking keeps the type at poster scale and spends height instead, which a
/// dropdown has and a panel width does not. The arrow turns with it: the
/// down-pointing `PosterArrow` the iPhone already uses between its input and
/// its result, which is the same gesture read vertically.
///
/// Nobody picks this by hand — `GlassPanelMetrics` derives it from the width it
/// has, so the stacked layout appears exactly when the side-by-side one will
/// not fit.
public enum ConversionPairAxis: String, Equatable, Sendable, CaseIterable {
    /// Pages 2, 3 and 4: `FROM` ──▶ `TO`.
    case sideBySide
    /// The narrow fallback: `FROM` above a down arrow above `TO`.
    case stacked
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

    // MARK: - Does it fit?

    /// Roughly how wide one time column has to be to draw `8:00 PM` at this
    /// step without shrinking it.
    ///
    /// An estimate from font metrics rather than a measurement, and that is the
    /// right trade: the alternative is laying out a `Text` to ask it, which
    /// needs a view context, a run loop and a real font, none of which exist
    /// where this is called (a layout decision made before the window opens)
    /// and all of which would make it untestable. The arithmetic, in ems of the
    /// relevant size:
    ///
    /// - `8:00` — three digits at SF Compressed Black's ~0.44em advance plus a
    ///   colon at ~0.25em: **1.57em** of `clockSize`.
    /// - the gap before the meridiem, set at the meridiem's size: **0.3em**.
    /// - `PM` — two caps at ~0.55em: **1.1em** of `meridiemSize`.
    ///
    /// Deliberately an *under*-estimate of nothing: it is sized for the common
    /// four-character clock. A rare `12:00` is one digit wider and is exactly
    /// what `minimumScaleFactor` is for. What this stops is the case where
    /// *every* conversion renders shrunken, which is a layout bug rather than a
    /// long-value accommodation.
    public var minimumColumnWidth: CGFloat {
        clockSize * 1.57 + meridiemSize * 0.3 + meridiemSize * 1.1
    }

    /// The narrowest content width this step's side-by-side pair can be drawn
    /// in: two time columns and the design's fixed gutter between them.
    public var minimumSideBySideWidth: CGFloat {
        minimumColumnWidth * 2 + arrowColumnWidth
    }

    /// The largest step whose side-by-side pair fits `width`, or `nil` when
    /// even the compact one does not and the caller has to stack.
    ///
    /// Ordered largest-first on purpose: the design is the full step, the
    /// compact step is a concession, and stacking is a last resort. A caller
    /// that wants the design gets it whenever the design fits.
    public static func largestFittingSideBySide(in width: CGFloat) -> ConversionPairScale? {
        [.full, .compact].first { width >= $0.minimumSideBySideWidth }
    }
}
