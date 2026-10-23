import AppKit
/// QA affordance: `-appearance dark` (or `light`) forces the app's appearance
/// at launch, so both halves of the glass design can be looked at without
/// changing the whole machine's System Settings and changing it back.
///
/// It exists because the glass palette's dark values are *derived* rather than
/// designed — the mockup ships light only — so they need looking at more than
/// the light ones do, and "switch the Mac to dark mode, summon, switch back"
/// is enough friction that it does not get done.
///
/// Reads from `UserDefaults`, which picks `-key value` launch arguments up for
/// free, exactly as `LaunchArguments` does on iOS. **DEBUG only**: a shipped
/// build must never let a launch argument drive its appearance.
///
/// Not `@MainActor` as a type: only the half that touches `NSApp` needs the
/// main actor, and isolating the *reading* of a launch argument along with it
/// would force every test of the rule onto the main actor for no reason.
enum MacAppearanceOverride {
    static let key = "appearance"

    @MainActor
    static func applyIfRequested() {
        #if DEBUG
        guard let name = requestedAppearance(readingFrom: .standard) else { return }
        NSApp.appearance = NSAppearance(named: name)
        #endif
    }

    /// Injectable, so a test never has to write to the standard domain.
    static func requestedAppearance(
        readingFrom defaults: UserDefaults
    ) -> NSAppearance.Name? {
        switch defaults.string(forKey: key)?.lowercased() {
        case "dark": return .darkAqua
        case "light": return .aqua
        default: return nil
        }
    }
}
