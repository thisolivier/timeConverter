import Foundation

/// QA affordance: prefill the input field from the command line so a real
/// conversion can be screenshotted headlessly.
///
/// `UserDefaults` picks up `-key value` launch arguments automatically, so
/// there is no argument parsing to do. **DEBUG only** — a shipped build must
/// never let a launch argument drive its UI.
public enum LaunchArguments {
    static let initialInputKey = "initialInput"

    /// The value of `-initialInput "12pm ET in London"`, or nil.
    public static var initialInput: String? {
        initialInput(readingFrom: .standard)
    }

    /// Injectable for tests, which must not write to the standard domain.
    static func initialInput(readingFrom defaults: UserDefaults) -> String? {
        #if DEBUG
        guard let value = defaults.string(forKey: initialInputKey),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return value
        #else
        return nil
        #endif
    }
}
