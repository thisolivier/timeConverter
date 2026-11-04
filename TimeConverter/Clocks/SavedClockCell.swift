import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// The point sizes for one of the three grid densities (item 37). The
/// decision of which density is `SavedGridLayout`'s; the numbers are the
/// 2026-11-04 design's, scaled from its 292pt canvas to a 390pt phone.
///
/// Every cell in a layout shares one numeral size, so a `12:38 AM` beside a
/// `3:38 PM` reads as one row of clocks rather than two sizes of type; a
/// numeral that still will not fit its column scales down alone, as the
/// result band's does.
struct SavedCellDensity {
    let columnCount: Int

    var labelSize: CGFloat { [12, 11, 10][index] }
    var clockSize: CGFloat { [92, 56, 40][index] }
    var meridiemSize: CGFloat { [28, 18, 13][index] }
    var captionSize: CGFloat { [15, 13, 11][index] }
    var horizontalPadding: CGFloat { [28, 20, 14][index] }
    var verticalPadding: CGFloat { [22, 18, 14][index] }
    /// The three-column layout has no room for `8 hours behind`.
    var usesShortOffsetPhrase: Bool { columnCount >= 3 }
    /// Nor for `LONDON (LOCAL)`; its caption says `Local time` instead.
    var usesCompactPlaceName: Bool { columnCount >= 3 }

    private var index: Int { min(max(columnCount, 1), 3) - 1 }
}

/// One clock in the Saved grid: the place label, the numerals with a smaller
/// meridiem on the same baseline, and a caption — the offset phrase, or
/// `Local time` on the local clock. Logic-free, like `PosterResultSection`.
struct SavedClockCell: View {
    let clock: WorldClockRow
    let density: SavedCellDensity

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(density.usesCompactPlaceName ? clock.compactPlaceName : clock.placeName)
                .posterLabel(size: density.labelSize)
                .foregroundStyle(PosterPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            (
                Text(clock.clockDigits).font(PosterTypography.display(size: density.clockSize))
                    + Text(" ").font(PosterTypography.display(size: density.meridiemSize))
                    + Text(clock.meridiem).font(PosterTypography.display(size: density.meridiemSize))
            )
            .foregroundStyle(PosterPalette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.top, 4)
            .accessibilityLabel("\(clock.clockDigits) \(clock.meridiem)")

            Text(caption)
                .font(PosterTypography.mono(size: density.captionSize, weight: .regular))
                .foregroundStyle(PosterPalette.quietInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 4)
        }
        .padding(.horizontal, density.horizontalPadding)
        .padding(.vertical, density.verticalPadding)
        .accessibilityElement(children: .combine)
    }

    private var caption: String {
        if clock.isLocal { return "Local time" }
        return density.usesShortOffsetPhrase ? clock.shortOffsetPhrase : clock.offsetPhrase
    }
}
