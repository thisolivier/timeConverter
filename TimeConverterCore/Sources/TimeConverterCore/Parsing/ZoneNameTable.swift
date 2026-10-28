import Foundation

/// The bundled zone-name snapshot: `Resources/zone-names.json`, a flat
/// `{ "<tz identifier>": "<generic name>" }` object.
///
/// It is a mechanical capture of what **iOS** answers for
/// `TimeZone.localizedName(for: .generic, locale: en_US)`, written on the iOS
/// simulator by `scripts/regenerate-zone-names.sh`. iOS is the origin: macOS
/// and Android read this same file rather than asking their own ICU, so all
/// three platforms print the same name. A value may be hand-edited where iOS's
/// wording reads badly — regenerating would undo that, so note it in the
/// commit.
///
/// A missing or malformed file degrades to an empty table (every zone then
/// takes the `"<City> Time"` fallback); `ZoneNameSnapshotTests` is what
/// guarantees the shipped file is present and complete.
enum ZoneNameTable {
    static let resourceName = "zone-names"
    static let resourceExtension = "json"

    /// Decoded once, on first use.
    static let namesByIdentifier: [String: String] = {
        guard let fileURL = Bundle.module.url(forResource: resourceName, withExtension: resourceExtension),
              let fileData = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: fileData)
        else { return [:] }
        return decoded
    }()

    static func genericName(forIdentifier timeZoneIdentifier: String) -> String? {
        namesByIdentifier[timeZoneIdentifier]
    }
}
