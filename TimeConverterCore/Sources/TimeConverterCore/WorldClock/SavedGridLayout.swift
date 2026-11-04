import Foundation

/// How the Saved tab lays its clocks out (item 37, from the 2026-11-04
/// designs): the layout follows the **number of clocks**, the local one
/// included, and the type size follows the layout.
///
/// | clocks | columns | caption |
/// |---|---|---|
/// | 1–3 | 1 | full offset phrase (`8 hours behind`) |
/// | 4–8 | 2 | full offset phrase |
/// | 9+ | 3 | short offset phrase (`8h behind`) |
///
/// Pure arithmetic, shared with the Kotlin core so the two Saved tabs agree.
/// The views own the point sizes; this owns the decision.
public enum SavedGridLayout {
    public static func columnCount(forClockCount clockCount: Int) -> Int {
        switch clockCount {
        case ..<4: return 1
        case 4...8: return 2
        default: return 3
        }
    }

    /// Whether the layout's caption is the short offset phrase.
    public static func usesShortOffsetPhrase(forClockCount clockCount: Int) -> Bool {
        columnCount(forClockCount: clockCount) == 3
    }

    /// The clocks in reading order, row by row; the last row may be short.
    public static func rows<Item>(_ items: [Item], columnCount: Int) -> [[Item]] {
        guard columnCount > 0, !items.isEmpty else { return [] }
        return stride(from: 0, to: items.count, by: columnCount).map {
            Array(items[$0..<min($0 + columnCount, items.count)])
        }
    }
}
