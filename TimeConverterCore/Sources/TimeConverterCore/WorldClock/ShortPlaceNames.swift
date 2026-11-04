import Foundation

/// The widgets' tightest cells have room for three or four letters (item
/// 36b): `LON`, `TOK`, `NYC`, `KATH`. Every place a favourite can carry —
/// every tz city and gazetteer name — has a hand-correctable shortening in
/// `short-names.json` (shared with the Kotlin core; shortened names people
/// write casually, not airport codes; a famous initialism may be two letters,
/// `LA`, `SF`). A name somehow missing is cut to its first three letters, and
/// a code label is its own short form.
enum ShortPlaceNames {
    static let resourceName = "short-names"
    static let resourceExtension = "json"

    static let bundledNames: [String: String] = decodeNames(
        at: Bundle.module.url(forResource: resourceName, withExtension: resourceExtension)
    )

    /// `label` is how the favourite was starred; `compactPlaceName` is the row's
    /// narrow-cell name (`Portland` for `Portland, Oregon`), which is what the
    /// three-letter cut is taken from.
    static func shortName(for label: ZoneLabel?, compactPlaceName: String) -> String {
        if case let .abbreviation(code, _) = label { return code }
        if let curated = bundledNames[compactPlaceName.lowercased()] { return curated }
        return String(compactPlaceName.prefix(3)).uppercased()
    }

    static func decodeNames(at fileURL: URL?) -> [String: String] {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let file = try? JSONDecoder().decode(ShortNamesFile.self, from: data)
        else { return [:] }
        return file.names
    }

    struct ShortNamesFile: Decodable {
        let version: Int
        let names: [String: String]
    }
}
