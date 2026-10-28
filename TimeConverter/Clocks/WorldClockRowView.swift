import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// One clock: the `WorldClockRow` strings in the poster's own fonts at a
/// modest size. Logic-free, like `PosterResultSection`.
struct WorldClockRowView: View {
    let row: WorldClockRow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.placeName)
                .posterLabel(size: 12)
                .foregroundStyle(PosterPalette.ink)

            // One concatenated `Text`, as on the result band: digits and
            // meridiem share a baseline.
            (
                Text(row.clockDigits).font(PosterTypography.display(size: 44))
                    + Text(" ").font(PosterTypography.display(size: 16))
                    + Text(row.meridiem).font(PosterTypography.display(size: 16))
            )
            .foregroundStyle(PosterPalette.ink)
            .accessibilityLabel("\(row.clockDigits) \(row.meridiem)")

            if !row.zoneLine.isEmpty {
                Text(row.zoneLine)
                    .posterLabel(size: 10, em: 0.10)
                    .foregroundStyle(PosterPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !row.offsetPhrase.isEmpty {
                Text(row.offsetPhrase)
                    .font(PosterTypography.mono(size: 12, weight: .regular))
                    .foregroundStyle(PosterPalette.quietInk)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
