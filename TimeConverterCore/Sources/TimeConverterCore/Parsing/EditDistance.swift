import Foundation

/// Bounded Levenshtein distance, for the did-you-mean suggester (item 9).
///
/// Bounded rather than plain: the suggester only ever cares about distances of
/// 1 or 2, and refusing to finish a computation that has already exceeded the
/// limit is what keeps a ~1,100-entry vocabulary scan cheap enough to run on a
/// prompt. The cheap length pre-check rejects most of the vocabulary before any
/// matrix work happens at all.
enum EditDistance {
    /// The edit distance between two strings, or nil when it exceeds `limit`.
    static func levenshtein(_ first: String, _ second: String, limitedTo limit: Int) -> Int? {
        let firstCharacters = Array(first)
        let secondCharacters = Array(second)

        // Insertions and deletions each cost 1, so a length gap is a floor on
        // the distance — no matrix needed to rule these out.
        guard abs(firstCharacters.count - secondCharacters.count) <= limit else { return nil }
        guard !firstCharacters.isEmpty else {
            return secondCharacters.count <= limit ? secondCharacters.count : nil
        }
        guard !secondCharacters.isEmpty else {
            return firstCharacters.count <= limit ? firstCharacters.count : nil
        }

        // Two rolling rows instead of the full matrix: only the previous row is
        // ever read.
        var previousRow = Array(0...secondCharacters.count)
        for (firstIndex, firstCharacter) in firstCharacters.enumerated() {
            var currentRow: [Int] = [firstIndex + 1]
            currentRow.reserveCapacity(secondCharacters.count + 1)
            for (secondIndex, secondCharacter) in secondCharacters.enumerated() {
                let substitutionCost = previousRow[secondIndex]
                    + (firstCharacter == secondCharacter ? 0 : 1)
                let insertionCost = currentRow[secondIndex] + 1
                let deletionCost = previousRow[secondIndex + 1] + 1
                currentRow.append(min(substitutionCost, insertionCost, deletionCost))
            }
            // Every alignment of the remaining characters passes through some
            // cell of this row, and costs never decrease, so a row whose
            // cheapest cell already exceeds the limit cannot recover.
            guard let cheapestCellInRow = currentRow.min(), cheapestCellInRow <= limit else {
                return nil
            }
            previousRow = currentRow
        }

        let distance = previousRow[secondCharacters.count]
        return distance <= limit ? distance : nil
    }
}
