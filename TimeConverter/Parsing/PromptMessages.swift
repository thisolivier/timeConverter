import Foundation

/// The spec's prompt copy, as a computed property on `Prompt`.
///
/// The parser returns prompts as *values* so they stay unit-testable; this
/// extension is a convenience so item 4's UI doesn't have to re-derive the
/// wording (and so the wording itself is covered by tests). P4 is a picker, so
/// its message is only the lead-in — the choices carry the detail.
///
/// P2's wording changed with the 2026-10-22 local-defaulting amendment; P3's
/// copy is gone with the prompt.
extension Prompt {
    var message: String {
        switch self {
        case .timeNotFound:
            return "Couldn't find a time — start with e.g. 14:30 or 2:30 pm"

        // Reworded by the 2026-10-22 amendment. The old copy ("add a zone
        // before 'in'") asked for the *source* specifically, which no longer
        // makes sense: one zone is now enough, on either side.
        case let .zoneNotFound(time):
            return "Convert \(time.canonicalDescription) where? "
                + "Add a timezone, city, or country"

        case let .ambiguousZone(token, _, _, _):
            return "'\(token)' could mean more than one place — pick one"

        case let .unknownZone(token, _, _):
            return "Don't recognize '\(token)' — try a timezone (ET, PST), "
                + "a major city, or a country"
        }
    }
}
