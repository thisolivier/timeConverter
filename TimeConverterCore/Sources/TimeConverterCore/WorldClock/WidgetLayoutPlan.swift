import Foundation

/// How a saved-cities widget lays its cells out (item 36b, from the
/// 2026-11-04 designs and the breakpoint brief): **the city count chooses the
/// layout, the family chooses what each cell can carry.** Pure, shared with
/// the Kotlin core, so the two widgets agree cell for cell.
///
/// | family | 1 city | 2–3 | 4 | 5–6 |
/// |---|---|---|---|---|
/// | small | hero | full-width rows, codes | 2 × 2, codes | 2 × 3, codes |
/// | medium | hero + caption beside | 1 row of columns, names + captions | 2 × 2, names + short captions | 3 × 2, names only |
/// | large | hero + caption | full-width rows, names + captions | 2 × 2, names + captions | 2 × 3, names + captions |
///
/// Seven or more cities show the first six; the Saved tab has the rest. With
/// five, the last cell spans the remaining row. The local clock is not a cell
/// (the home screen has one).
public struct WidgetLayoutPlan: Equatable, Sendable {
    public enum Family: String, Sendable, CaseIterable { case small, medium, large }
    public enum NameStyle: Equatable, Sendable { case full, code }
    public enum CaptionStyle: Equatable, Sendable { case full, short, none }

    public let family: Family
    /// The cells shown, in stored order — at most `maximumCities`.
    public let cityCount: Int
    public let columnCount: Int
    public let rowCount: Int
    public let nameStyle: NameStyle
    public let captionStyle: CaptionStyle
    /// One city at hero size with its caption beside or beneath it.
    public var isHero: Bool { cityCount == 1 }
    /// A short last row's final cell stretches across what is left.
    public var lastCellSpansRow: Bool { cityCount > 1 && cityCount % columnCount != 0 }

    public static let maximumCities = 6

    public static func plan(family: Family, cityCount rawCount: Int) -> WidgetLayoutPlan {
        let cityCount = min(max(rawCount, 0), maximumCities)
        let columns: Int
        let names: NameStyle
        let captions: CaptionStyle
        switch (family, cityCount) {
        case (_, 0), (_, 1):
            columns = 1
            names = .full
            captions = .full
        case (.small, 2...3):
            columns = 1; names = .code; captions = .none
        case (.small, 4):
            columns = 2; names = .code; captions = .none
        case (.small, _):
            columns = 2; names = .code; captions = .none
        case (.medium, 2...3):
            columns = cityCount; names = .full; captions = .short
        case (.medium, 4):
            columns = 2; names = .full; captions = .short
        case (.medium, _):
            columns = 3; names = .full; captions = .none
        case (.large, 2...3):
            columns = 1; names = .full; captions = .full
        case (.large, 4):
            columns = 2; names = .full; captions = .full
        case (.large, _):
            columns = 2; names = .full; captions = .short
        }
        let rows = cityCount == 0 ? 0 : (cityCount + columns - 1) / columns
        return WidgetLayoutPlan(
            family: family, cityCount: cityCount, columnCount: columns, rowCount: rows,
            nameStyle: names, captionStyle: captions
        )
    }

    /// The cells in reading order, row by row; the last row may be short.
    public func rows<Item>(_ items: [Item]) -> [[Item]] {
        SavedGridLayout.rows(Array(items.prefix(cityCount)), columnCount: columnCount)
    }
}
