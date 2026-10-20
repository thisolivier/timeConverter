import Foundation

/// The spec's prompt copy, as a computed property on `Prompt`.
///
/// The parser returns prompts as *values* so they stay unit-testable; this
/// extension is a convenience so item 4's UI doesn't have to re-derive the
/// wording (and so the wording itself is covered by tests). P4 is a picker, so
/// its message is only the lead-in — the choices carry the detail.
extension Prompt {
    var message: String {
        switch self {
        case .timeNotFound:
            return "Couldn't find a time — start with e.g. 14:30 or 2:30 pm"

        case let .missingSourceZone(time, conjunction):
            let conjunctionHint = conjunction.map { "'\($0.rawValue)'" } ?? "'in' or 'to'"
            return "Where is \(time.canonicalDescription)? Add a zone before \(conjunctionHint)"

        case let .missingTargetZone(time, sourceZoneToken):
            return "Convert \(time.canonicalDescription) \(sourceZoneToken) to where? "
                + "Add 'in' or 'to' + a place"

        case let .ambiguousZone(token, _, _):
            return "'\(token)' could mean more than one place — pick one"

        case let .unknownZone(token, _):
            return "Don't recognize '\(token)' — try a timezone (ET, PST), "
                + "a major city, or a country"
        }
    }
}
