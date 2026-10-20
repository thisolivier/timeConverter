import Foundation

/// Step 5 — the offline fallback gazetteer.
///
/// Cities the tz database has no zone for (Porto, Manchester). This is the one
/// resolver whose knowledge lives in **data, not code**: it reads a bundled
/// JSON file, so swapping the two QA seeds for a full gazetteer is a file
/// change with no recompilation of the chain.
struct OfflineFallbackZoneResolver: ZoneResolver {
    let matchSource: ZoneMatchSource = .offlineFallbackList

    private let identifiersByPlaceName: [String: [String]]

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

    /// Checked against both the bundle holding this code and the main bundle,
    /// so the lookup works the same in the app and under the test host.
    static var bundledFileURL: URL? {
        let candidateBundles = [Bundle(for: GazetteerBundleToken.self), Bundle.main]
        for bundle in candidateBundles {
            if let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) {
                return url
            }
        }
        return nil
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

/// Anchor class for `Bundle(for:)` — the reliable way to find the bundle this
/// code shipped in, whether that is the app or a framework.
private final class GazetteerBundleToken {}
