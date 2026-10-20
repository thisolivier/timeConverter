import Foundation

/// Splits a freeform string into its four grammar parts, per the spec's
/// tokenization steps: normalise, match the time at the start, then find the
/// **first standalone** conjunction and cut the rest in two around it.
enum InputTokenizer {
    struct Tokens: Equatable, Sendable {
        let time: ParsedTime
        let sourceZoneToken: String
        let conjunction: Conjunction
        let targetZoneToken: String
    }

    enum Result: Equatable, Sendable {
        case tokens(Tokens)
        case prompt(Prompt)
    }

    /// Trim, collapse runs of whitespace to single spaces, lowercase.
    /// Matching is case-insensitive throughout, so everything downstream of
    /// here works on the lowercased copy.
    static func normalize(_ input: String) -> String {
        input
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()
    }

    static func tokenize(_ input: String) -> Result {
        let normalizedInput = normalize(input)

        guard let timeMatch = TimeTokenParser.match(atStartOf: normalizedInput) else {
            return .prompt(.timeNotFound(input: normalizedInput))
        }

        let remainingWords = timeMatch.remainder
            .split(separator: " ")
            .map(String.init)

        // Scanning for the *first* standalone conjunction is what keeps "Porto"
        // safe: "to" inside a word is not a word, so it never splits. It also
        // means a zone name containing a standalone "in"/"to" between the two
        // zones cannot occur — an accepted limitation of the closed list.
        let conjunctionIndex = remainingWords.firstIndex { word in
            Conjunction(rawValue: word) != nil
        }

        guard let conjunctionIndex else {
            // Nothing after the time at all: the first thing missing, reading
            // left to right, is the source zone.
            guard !remainingWords.isEmpty else {
                return .prompt(.missingSourceZone(time: timeMatch.time, conjunction: nil))
            }
            return .prompt(.missingTargetZone(
                time: timeMatch.time,
                sourceZoneToken: remainingWords.joined(separator: " ")
            ))
        }

        let conjunction = Conjunction(rawValue: remainingWords[conjunctionIndex])!
        let sourceZoneToken = remainingWords[..<conjunctionIndex].joined(separator: " ")
        let targetZoneToken = remainingWords[(conjunctionIndex + 1)...].joined(separator: " ")

        if sourceZoneToken.isEmpty {
            return .prompt(.missingSourceZone(time: timeMatch.time, conjunction: conjunction))
        }
        if targetZoneToken.isEmpty {
            return .prompt(.missingTargetZone(
                time: timeMatch.time,
                sourceZoneToken: sourceZoneToken
            ))
        }

        return .tokens(Tokens(
            time: timeMatch.time,
            sourceZoneToken: sourceZoneToken,
            conjunction: conjunction,
            targetZoneToken: targetZoneToken
        ))
    }
}
