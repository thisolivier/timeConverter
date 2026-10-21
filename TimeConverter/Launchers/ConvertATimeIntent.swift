import AppIntents

/// "Convert a time" — the one intent behind every launcher (backlog item 11).
///
/// It takes no parameters and returns no value: it opens the app with an empty,
/// focused field. That is the honest limit of what a launcher can do for a
/// typed-input tool, and it is deliberately the *whole* feature — a Siri intent
/// that accepted a sentence parameter would need its own error and
/// disambiguation flow, which could not match the app's chips. Parked in
/// `docs/ux-v1-proposal.md` under "Deliberately not now".
///
/// ## Two call sites, one type
///
/// `TimeConverterShortcuts` exposes it to Siri, Spotlight and the Shortcuts app;
/// `ConvertATimeControl` (in the `TimeConverterControls` extension) exposes it
/// to Control Center and the lock screen. The *source file is a member of both
/// targets* — see `project.yml` — because a control's button action must be
/// resolvable inside the extension, while the app needs the same type to run
/// it. Shipping it in only one target is the classic reason a Control Center
/// button does nothing when tapped.
///
/// ## Why `supportedModes` and not `openAppWhenRun`
///
/// `openAppWhenRun` is deprecated as of iOS 26 (which this app targets) in
/// favour of `IntentModes`. `.foreground(.immediate)` is the same promise:
/// bring the app forward now, then run `perform()` in the app's process.
struct ConvertATimeIntent: AppIntent {
    static let title: LocalizedStringResource = "Convert a time"

    static let description = IntentDescription(
        "Opens Time Converter with the input field empty and ready to type in.",
        categoryName: "Converting"
    )

    /// Bring the app forward, then run in the app's process.
    static let supportedModes: IntentModes = .foreground(.immediate)

    /// Offer it in Spotlight and the Shortcuts app, not just via the phrase.
    static let isDiscoverable = true

    @MainActor
    func perform() async throws -> some IntentResult {
        LaunchRequestInbox.shared.post(.startFreshConversion)
        return .result()
    }
}
