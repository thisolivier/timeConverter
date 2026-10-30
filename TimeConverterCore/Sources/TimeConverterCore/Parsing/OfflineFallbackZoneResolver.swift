import Foundation

/// Step 5 — the offline fallback gazetteer.
///
/// Places the tz database has no zone for (Porto, Mumbai, Barcelona, and
/// since item 34 Portland, Salzburg, Kerala — ~3,100 editorial entries). This
/// is the one resolver whose knowledge lives in **data, not code**: it reads a
/// bundled JSON file, so growing or swapping the gazetteer is a file change
/// with no recompilation of the chain.
struct OfflineFallbackZoneResolver: ZoneResolver {
    let matchSource: ZoneMatchSource = .offlineFallbackList

    /// Deliberately readable rather than private: the did-you-mean suggester
    /// (item 9) has to be able to enumerate the gazetteer, and a one-way table
    /// that only answers exact lookups cannot suggest `Porto` for `Prto`.
    /// Still `let`, still set once at init — exposing it adds a reader, not a
    /// mutation path.
    let identifiersByPlaceName: [String: [String]]

    /// For a name split across zones, what each zone's picker chip says and
    /// writes back (item 34b): `portland` → `Portland, Oregon` / `Portland
    /// Oregon`, not `Los Angeles`. Parallel to the entry's identifiers; absent
    /// for the single-zone majority, which never show a picker.
    let choicesByPlaceName: [String: [PlaceChoice]]

    /// Defaults to the bundled file. The parameters exist so tests (and a
    /// future "downloaded gazetteer" path) can supply their own entries.
    init(
        identifiersByPlaceName: [String: [String]] = OfflineFallbackGazetteer.bundledEntries,
        choicesByPlaceName: [String: [PlaceChoice]] = OfflineFallbackGazetteer.bundledChoices
    ) {
        self.identifiersByPlaceName = identifiersByPlaceName
        self.choicesByPlaceName = choicesByPlaceName
    }

    func candidates(for normalizedZoneToken: String) -> [ZoneCandidate] {
        guard let identifiers = identifiersByPlaceName[normalizedZoneToken] else { return [] }
        let choices = choicesByPlaceName[normalizedZoneToken] ?? []
        return identifiers.enumerated().map { index, identifier in
            ZoneCandidate(
                timeZoneIdentifier: identifier,
                matchSource: matchSource,
                placeChoice: index < choices.count ? choices[index] : nil
            )
        }
    }

    var vocabulary: [ZoneVocabularyEntry] {
        identifiersByPlaceName.keys.map {
            ZoneVocabularyEntry(token: $0, shape: .placeName, matchSource: matchSource)
        }
    }
}

/// Locates and decodes the bundled gazetteer file.
///
/// A missing or malformed file degrades to an empty table — the chain then
/// reports the token as unknown (P5) rather than crashing. The bundling test in
/// `OfflineFallbackGazetteerTests` is what guarantees the file is actually
/// present in the shipped app.
enum OfflineFallbackGazetteer {
    static let resourceName = "fallback-cities"
    static let resourceExtension = "json"

    /// Decoded once, on first use.
    static let bundledEntries: [String: [String]] = decodeEntries(at: bundledFileURL)
    static let bundledChoices: [String: [PlaceChoice]] = decodeChoices(at: bundledFileURL)

    /// `Bundle.module` — the resource bundle SwiftPM generates for this target
    /// — and nothing else.
    ///
    /// It used to search `Bundle(for:)` then `Bundle.main`, because the file was
    /// compiled into the app target and the test host was a different bundle.
    /// Now that the gazetteer ships inside `TimeConverterCore`, `Bundle.module`
    /// is the single correct answer in all four situations that matter: the iOS
    /// app, the macOS app, `swift test`, and `xcodebuild test`. Falling back to
    /// `Bundle.main` would actively hide the bug this is most likely to have —
    /// a resource declaration missing from `Package.swift` — by quietly finding
    /// a stale copy double-bundled in the app.
    static var bundledFileURL: URL? {
        Bundle.module.url(forResource: resourceName, withExtension: resourceExtension)
    }

    static func decodeEntries(at fileURL: URL?) -> [String: [String]] {
        var identifiersByPlaceName: [String: [String]] = [:]
        for entry in decodeFile(at: fileURL)?.entries ?? [] where !entry.timeZoneIdentifiers.isEmpty {
            identifiersByPlaceName[entry.name.lowercased()] = entry.timeZoneIdentifiers
        }
        return identifiersByPlaceName
    }

    /// Only entries that carry `choices` appear here; a mismatched count is
    /// kept as-is and left for `GazetteerCoverageTests` to reject, rather than
    /// silently dropping labels.
    static func decodeChoices(at fileURL: URL?) -> [String: [PlaceChoice]] {
        var choicesByPlaceName: [String: [PlaceChoice]] = [:]
        for entry in decodeFile(at: fileURL)?.entries ?? [] {
            guard let choices = entry.choices, !choices.isEmpty else { continue }
            choicesByPlaceName[entry.name.lowercased()] = choices.map {
                PlaceChoice(label: $0.label, typedForm: $0.typed)
            }
        }
        return choicesByPlaceName
    }

    private static func decodeFile(at fileURL: URL?) -> GazetteerFile? {
        guard let fileURL, let fileData = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(GazetteerFile.self, from: fileData)
    }

    struct GazetteerFile: Decodable {
        let version: Int
        let entries: [Entry]

        struct Entry: Decodable {
            let name: String
            let timeZoneIdentifiers: [String]
            /// Parallel to `timeZoneIdentifiers`, present only on split names.
            let choices: [Choice]?

            struct Choice: Decodable {
                /// What the chip and the prompt say: `Portland, Oregon`.
                let label: String
                /// What tapping the chip writes into the sentence, which must
                /// itself resolve to this zone: `Portland Oregon`.
                let typed: String
            }
        }
    }
}
