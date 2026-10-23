import Foundation

/// QA affordance: prefill the input field from the command line so a real
/// conversion can be screenshotted headlessly.
///
/// `UserDefaults` picks up `-key value` launch arguments automatically, so
/// there is no argument parsing to do. **DEBUG only** — a shipped build must
/// never let a launch argument drive its UI.
public enum LaunchArguments {
    static let initialInputKey = "initialInput"
    static let forceCompactKey = "forceCompact"

    /// The value of `-initialInput "12pm ET in London"`, or nil.
    public static var initialInput: String? {
        initialInput(readingFrom: .standard)
    }

    /// `-forceCompact 1`: pretend the keyboard is up, so item 19's collapsed
    /// poster can be screenshotted.
    ///
    /// It exists because the simulator usually has its software keyboard turned
    /// off, which means the one state the choreography is *about* is the one
    /// state a headless screenshot can never reach. It forces the input, not
    /// the outcome: the real `PosterLayoutMode` rule still decides, so
    /// `-forceCompact 1` on its own (empty field) correctly shows the full
    /// poster, and it has to be paired with `-initialInput` to collapse
    /// anything. Faking the answer instead would let the screenshot disagree
    /// with the app.
    public static var forcesKeyboardVisible: Bool {
        forcesKeyboardVisible(readingFrom: .standard)
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

    /// Injectable for tests, for the same reason as above.
    static func forcesKeyboardVisible(readingFrom defaults: UserDefaults) -> Bool {
        #if DEBUG
        // `bool(forKey:)` accepts `1`, `YES` and `true` alike, which is what a
        // person typing a launch argument expects.
        return defaults.bool(forKey: forceCompactKey)
        #else
        return false
        #endif
    }
}
