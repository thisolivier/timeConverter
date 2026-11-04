import SwiftUI
import TimeConverterCore
import TimeConverterUI
import WidgetKit

/// The large widget's face: poster paper and ink, one compact row per clock.
/// Logic-free, like `WorldClockRowView` in the app — every string arrives
/// rendered in the entry.
struct SavedCitiesWidgetView: View {
    let entry: SavedCitiesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entry.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Rectangle()
                        .fill(PosterPalette.ink.opacity(0.15))
                        .frame(height: 1)
                }
                SavedCitiesWidgetRow(row: row)
            }
            if !entry.hasFavourites {
                Spacer(minLength: 8)
                Text("Star a place on the Convert tab and it appears here.")
                    .font(PosterTypography.mono(size: 11, weight: .regular))
                    .foregroundStyle(PosterPalette.ink.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(PosterPalette.paper, for: .widget)
    }
}

/// One clock: name and zone on the left, digits and the relative offset on
/// the right. The same slots as the app's row, laid out sideways because a
/// widget row has width to spare and height to ration.
private struct SavedCitiesWidgetRow: View {
    let row: WorldClockRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.placeName)
                    .posterLabel(size: 11)
                    .lineLimit(1)
                if !row.zoneLine.isEmpty {
                    Text(row.zoneLine)
                        .posterLabel(size: 7, em: 0.10)
                        .opacity(0.7)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                (
                    Text(row.clockDigits).font(PosterTypography.display(size: 24))
                        + Text(" ").font(PosterTypography.display(size: 11))
                        + Text(row.meridiem).font(PosterTypography.display(size: 11))
                )
                .lineLimit(1)
                .accessibilityLabel("\(row.clockDigits) \(row.meridiem)")
                if !row.offsetPhrase.isEmpty {
                    Text(row.offsetPhrase)
                        .font(PosterTypography.mono(size: 9, weight: .regular))
                        .opacity(0.55)
                        .lineLimit(1)
                }
            }
        }
        .foregroundStyle(PosterPalette.ink)
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}
