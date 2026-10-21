import AppIntents

/// The App Shortcut: "Convert a time in Time Converter 3000".
///
/// An `AppShortcutsProvider` is the whole of slice 1 of backlog item 11 — no
/// extension, no provisioning, no new target. The system picks it up from the
/// app's App Intents metadata at install time, which is what puts the phrase in
/// front of Siri and the row in Spotlight and the Shortcuts app ("Shortcuts →
/// App Shortcuts → Time Converter 3000") without the user configuring anything.
///
/// ## Rules worth knowing before editing a phrase
///
/// - **Every phrase must contain `\(.applicationName)`.** It is a compile-time
///   requirement of `AppShortcutPhrase`, and `.applicationName` resolves to the
///   installed app's display name (plus any synonyms), which is why the phrases
///   below read naturally whether the icon says "TimeConverter" or the store
///   says "Time Converter 3000".
/// - **Phrase order matters**: the first is the one Siri suggests.
/// - `shortTitle` and `systemImageName` are required (iOS 17+) — they are the
///   label and glyph on the Shortcuts tile.
struct TimeConverterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ConvertATimeIntent(),
            phrases: [
                "Convert a time in \(.applicationName)",
                "Convert a time with \(.applicationName)",
                "New conversion in \(.applicationName)"
            ],
            shortTitle: "Convert a time",
            systemImageName: "globe.badge.clock"
        )
    }
}
