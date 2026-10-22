import Foundation

/// Step 5 — the offline fallback gazetteer.
///
/// Cities the tz database has no zone for (Porto, Manchester). This is the one
/// resolver whose knowledge lives in **data, not code**: it reads a bundled
/// JSON file, so swapping the two QA seeds for a full gazetteer is a file
/// change with no recompilation of the chain.
struct OfflineFallbackZoneResolver: ZoneResolver {
    let matchSource: ZoneMatchSource = .offlineFallbackList

    /// Deliberately readable rather than private: the did-you-mean suggester
    /// (item 9) has to be able to enumerate the gazetteer, and a one-way table
    /// that only answers exact lookups cannot suggest `Porto` for `Prto`.
    /// Still `let`, still set once at init — exposing it adds a reader, not a
    /// mutation path.
    let identifiersByPlaceName: [String: [String]]

    /// Defaults to the bundled file. The parameter exists so tests (and a
    /// future "downloaded gazetteer" path) can supply their own entries.
    init(identifiersByPlaceName: [String: [String]] = OfflineFallbackGazetteer.bundledEntries) {
        self.identifiersByPlaceName = identifiersByPlaceName
    }

    func candidates(for normalizedZoneToken: String) -> [ZoneCandidate] {
        guard let identifiers = identifiersByPlaceName[normalizedZoneToken] else { return [] }
        return identifiers.map {
            ZoneCandidate(timeZoneIdentifier: $0, matchSource: matchSource)
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
        guard let fileURL, let fileData = try? Data(contentsOf: fileURL) else { return [:] }
        guard let file = try? JSONDecoder().decode(GazetteerFile.self, from: fileData) else {
            return [:]
        }
        var identifiersByPlaceName: [String: [String]] = [:]
        for entry in file.entries where !entry.timeZoneIdentifiers.isEmpty {
            identifiersByPlaceName[entry.name.lowercased()] = entry.timeZoneIdentifiers
        }
        return identifiersByPlaceName
    }

    struct GazetteerFile: Decodable {
        let version: Int
        let entries: [Entry]

        struct Entry: Decodable {
            let name: String
            let timeZoneIdentifiers: [String]
        }
    }
}
