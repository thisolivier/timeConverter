import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// What a saved-cities widget shows, independent of WidgetKit so the app's
/// DEBUG preview screen can draw the same faces (item 36b).
struct SavedCitiesWidgetContent: Equatable {
    /// The saved places only, in stored order, at most six.
    let cities: [WorldClockRow]
    /// Whether the device shows 24-hour time (`20:38`) or 12-hour (`8:38 PM`).
    let usesTwentyFourHourClock: Bool
}

/// The face of the saved-cities widget, in the three families, from the
/// 2026-11-04 designs. The layout — columns, rows, which name, which caption
/// — is `WidgetLayoutPlan`'s decision (core, shared with Android); this view
/// owns the point sizes and the hairlines.
///
/// ## Type sizes
///
/// Every cell in a face shares one numeral size, chosen for the widest time
/// the cell could show (`12:38 AM`, `20:38`) at the narrowest column of that
/// layout, so the numerals never resize as the clock changes and a `12:38 AM`
/// beside a `3:38 PM` reads as one row. The brief's compression order is
/// applied by the plan — padding, then short captions, then codes, then no
/// captions — and only as a last resort does `minimumScaleFactor` step a
/// numeral down.
struct SavedCitiesWidgetFace: View {
    let content: SavedCitiesWidgetContent
    let family: WidgetLayoutPlan.Family

    private var plan: WidgetLayoutPlan {
        WidgetLayoutPlan.plan(family: family, cityCount: content.cities.count)
    }

    var body: some View {
        if content.cities.isEmpty {
            emptyFace
        } else if plan.isHero, let city = content.cities.first {
            heroFace(city)
        } else {
            gridFace
        }
    }

    // MARK: - Nothing saved

    private var emptyFace: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Saved cities")
                .posterLabel(size: 11)
            Text("Star a place in Time Converter and it appears here.")
                .font(PosterTypography.mono(size: family == .small ? 11 : 13, weight: .regular))
                .foregroundStyle(PosterPalette.quietInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(PosterPalette.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - One city

    private func heroFace(_ city: WorldClockRow) -> some View {
        let sizes = WidgetTypeSizes.hero(family)
        return Group {
            switch family {
            case .small:
                VStack(alignment: .leading, spacing: 0) {
                    cityLabel(city, style: .full, size: sizes.label)
                    Spacer(minLength: 2)
                    timeText(city, size: sizes.time)
                    Spacer(minLength: 2)
                    captionText(city.offsetPhrase, size: sizes.caption)
                }
            case .medium:
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        cityLabel(city, style: .full, size: sizes.label)
                        timeText(city, size: sizes.time)
                    }
                    WidgetHairline(vertical: true)
                    Text(city.offsetPhrase.replacingOccurrences(of: " ", with: "\n"))
                        .font(PosterTypography.mono(size: sizes.caption, weight: .regular))
                        .foregroundStyle(PosterPalette.quietInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .large:
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    cityLabel(city, style: .full, size: sizes.label)
                    timeText(city, size: sizes.time)
                        .padding(.top, 6)
                    WidgetHairline()
                        .padding(.vertical, 14)
                    captionText(city.offsetPhrase, size: sizes.caption)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Two to six

    private var gridFace: some View {
        let sizes = WidgetTypeSizes.grid(plan)
        let rows = plan.rows(content.cities)
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                if rowIndex > 0 { WidgetHairline() }
                HStack(alignment: .center, spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { cellIndex, city in
                        if cellIndex > 0 { WidgetHairline(vertical: true) }
                        cell(city, sizes: sizes)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func cell(_ city: WorldClockRow, sizes: WidgetTypeSizes) -> some View {
        let caption = captionString(city)
        let horizontalPadding: CGFloat = plan.columnCount == 1 ? 2 : 8
        if plan.family == .small, plan.columnCount == 1 {
            // The small widget's rows: code on the left, time on the right.
            HStack(alignment: .firstTextBaseline) {
                cityLabel(city, style: plan.nameStyle, size: sizes.label)
                Spacer(minLength: 6)
                timeText(city, size: sizes.time)
            }
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if plan.family == .large, plan.columnCount == 1 {
            // The large widget's rows: name over time, caption at the right.
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    cityLabel(city, style: plan.nameStyle, size: sizes.label)
                    timeText(city, size: sizes.time)
                }
                Spacer(minLength: 8)
                if let caption { captionText(caption, size: sizes.caption) }
            }
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                cityLabel(city, style: plan.nameStyle, size: sizes.label)
                timeText(city, size: sizes.time)
                if let caption { captionText(caption, size: sizes.caption) }
            }
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func captionString(_ city: WorldClockRow) -> String? {
        switch plan.captionStyle {
        case .full: return city.offsetPhrase
        case .short: return city.shortOffsetPhrase
        case .none: return nil
        }
    }

    // MARK: - The three kinds of text

    private func cityLabel(_ city: WorldClockRow, style: WidgetLayoutPlan.NameStyle, size: CGFloat) -> some View {
        Text(style == .code ? city.shortPlaceName : city.compactPlaceName)
            .posterLabel(size: size)
            .foregroundStyle(PosterPalette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private func timeText(_ city: WorldClockRow, size: CGFloat) -> some View {
        let meridiemSize = (size * 0.36).rounded()
        let text: Text
        if content.usesTwentyFourHourClock {
            text = Text(city.twentyFourHourDigits).font(PosterTypography.display(size: size))
        } else {
            text = Text(city.clockDigits).font(PosterTypography.display(size: size))
                + Text(" ").font(PosterTypography.display(size: meridiemSize))
                + Text(city.meridiem).font(PosterTypography.display(size: meridiemSize))
        }
        return text
            .foregroundStyle(PosterPalette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityLabel("\(city.clockDigits) \(city.meridiem)")
    }

    private func captionText(_ caption: String, size: CGFloat) -> some View {
        Text(caption)
            .font(PosterTypography.mono(size: size, weight: .regular))
            .foregroundStyle(PosterPalette.quietInk)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

/// The hairlines between cells: ink at 60%, 1pt.
struct WidgetHairline: View {
    var vertical = false

    var body: some View {
        Rectangle()
            .fill(PosterPalette.ink.opacity(0.6))
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}

/// The point sizes per family and layout — the designs' proportions on the
/// iPhone's widget sizes (small 170pt square, medium 364 × 170, large
/// 364 × 382), each numeral size chosen so the widest time fits the
/// narrowest cell of that layout.
struct WidgetTypeSizes {
    let label: CGFloat
    let time: CGFloat
    let caption: CGFloat

    static func hero(_ family: WidgetLayoutPlan.Family) -> WidgetTypeSizes {
        switch family {
        case .small: return WidgetTypeSizes(label: 11, time: 46, caption: 12)
        case .medium: return WidgetTypeSizes(label: 12, time: 72, caption: 14)
        case .large: return WidgetTypeSizes(label: 16, time: 112, caption: 18)
        }
    }

    static func grid(_ plan: WidgetLayoutPlan) -> WidgetTypeSizes {
        switch (plan.family, plan.columnCount, plan.rowCount) {
        case (.small, 1, _): return WidgetTypeSizes(label: 11, time: 28, caption: 10)
        case (.small, _, 2): return WidgetTypeSizes(label: 10, time: 26, caption: 10)
        case (.small, _, _): return WidgetTypeSizes(label: 9, time: 22, caption: 9)
        case (.medium, 2, 1), (.medium, 3, 1): return WidgetTypeSizes(label: 10, time: 34, caption: 11)
        case (.medium, 2, _): return WidgetTypeSizes(label: 10, time: 28, caption: 10)
        case (.medium, _, _): return WidgetTypeSizes(label: 9, time: 28, caption: 10)
        case (.large, 1, _): return WidgetTypeSizes(label: 12, time: 52, caption: 13)
        case (.large, _, 2): return WidgetTypeSizes(label: 11, time: 44, caption: 12)
        case (.large, _, _): return WidgetTypeSizes(label: 10, time: 36, caption: 11)
        }
    }
}
