import Testing
@testable import TimeConverterCore

/// Item 37 — the Saved tab's layout follows the clock count.
struct SavedGridLayoutTests {
    @Test(arguments: [
        (0, 1), (1, 1), (2, 1), (3, 1),
        (4, 2), (5, 2), (8, 2),
        (9, 3), (10, 3), (20, 3),
    ])
    func columnsFollowTheClockCount(clockCount: Int, expectedColumns: Int) {
        #expect(SavedGridLayout.columnCount(forClockCount: clockCount) == expectedColumns)
    }

    @Test func onlyTheThreeColumnLayoutShortensTheOffsetPhrase() {
        #expect(!SavedGridLayout.usesShortOffsetPhrase(forClockCount: 3))
        #expect(!SavedGridLayout.usesShortOffsetPhrase(forClockCount: 8))
        #expect(SavedGridLayout.usesShortOffsetPhrase(forClockCount: 9))
    }

    @Test func rowsReadLeftToRightWithAShortLastRow() {
        let rows = SavedGridLayout.rows(Array(1...10), columnCount: 3)
        #expect(rows == [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10]])
        #expect(SavedGridLayout.rows([Int](), columnCount: 2).isEmpty)
        #expect(SavedGridLayout.rows([1, 2, 3, 4], columnCount: 2) == [[1, 2], [3, 4]])
    }
}
