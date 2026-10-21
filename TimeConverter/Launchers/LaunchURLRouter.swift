import Foundation

/// Turns an incoming `timeconverter://` URL into a `LaunchRequest`, or nothing.
///
/// Why a URL scheme at all, when the App Shortcut and the Control Center
/// control both run `ConvertATimeIntent` in-process and need no URL? Two
/// reasons, both practical:
///
/// 1. **It is how the launcher behaviour gets QA'd headlessly.** Control Center
///    and Siri cannot be driven from a script, but
///    `xcrun simctl openurl booted timeconverter://convert` can — see the
///    README's QA section.
/// 2. **It is the fallback if an intent ever performs outside the app.** A
///    foreground intent runs in the app process today; if that ever stops being
///    true the same request can arrive as a URL without the app changing.
///
/// The scheme is matched case-insensitively (iOS lowercases schemes, but a
/// hand-typed URL may not) and the action may arrive as the host
/// (`timeconverter://convert`) or as the first path component
/// (`timeconverter:///convert`) — the two spellings are indistinguishable to a
/// user and both are produced by real-world tooling. Anything else routes
/// nowhere: an unknown action must never be guessed into a launch, because a
/// launch wipes the field.
enum LaunchURLRouter {
    static let scheme = "timeconverter"

    /// The action word that means "open ready to type".
    static let startFreshConversionAction = "convert"

    static func request(for url: URL) -> LaunchRequest? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        switch soleAction(in: url) {
        case startFreshConversionAction: return .startFreshConversion
        default: return nil
        }
    }

    /// The single action word in the URL: the host, or the only path component
    /// when there is no host. Anything deeper (`//convert/extra`) is not a
    /// spelling of a known action, so it resolves to nothing.
    private static func soleAction(in url: URL) -> String? {
        let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        if let host = url.host(), !host.isEmpty {
            guard pathComponents.isEmpty else { return nil }
            return host.lowercased()
        }
        guard pathComponents.count == 1 else { return nil }
        return pathComponents[0].lowercased()
    }
}
