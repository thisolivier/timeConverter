import Foundation
import Observation

/// What a launcher asks the app to do the moment it opens it (backlog item 11).
///
/// There is deliberately one case. A launcher is a *faster path to the
/// keyboard*, not a second interaction model: nothing here can carry a typed
/// sentence, pick a time zone, or pre-run a conversion. If a future launcher
/// needs to say something else, it gets a case — and the switch in `ContentView`
/// stops compiling until it is handled, which is the point of an enum here
/// rather than a bare `Bool`.
enum LaunchRequest: Equatable, Sendable {
    /// "Open with an empty field, ready to type."
    case startFreshConversion
}

extension LaunchRequest {
    /// The input the app should be showing once this request has been honoured.
    ///
    /// Empty, always — even when the user had a half-typed sentence in the
    /// field. A launcher is pressed to *start* a conversion, so leaving the
    /// previous text in place would mean the first keystroke silently edits
    /// something the user did not put there in this session. The typed sentence
    /// is still the single source of truth; a launcher simply resets it.
    var inputToStartFrom: String {
        switch self {
        case .startFreshConversion: ""
        }
    }
}

/// The one-slot mailbox between a launcher and the running app.
///
/// `ConvertATimeIntent` runs in the app's own process (it is a foreground
/// intent), but it has no reference to the view, and the ordering between
/// "intent performed" and "view appeared" differs between a cold launch and a
/// warm one. So the intent posts here and `ContentView` drains the mailbox from
/// both `onAppear` and an observation of `pendingRequest` — whichever happens
/// second finds it empty.
///
/// A single slot, not a queue: two launcher presses in a row mean exactly the
/// same thing as one.
@MainActor
@Observable
final class LaunchRequestInbox {
    /// The app's mailbox. Tests use their own instance.
    static let shared = LaunchRequestInbox()

    private(set) var pendingRequest: LaunchRequest?

    init(pendingRequest: LaunchRequest? = nil) {
        self.pendingRequest = pendingRequest
    }

    func post(_ request: LaunchRequest) {
        pendingRequest = request
    }

    /// Reads and clears in one step, so a request is honoured exactly once no
    /// matter how many times the view looks.
    func takePendingRequest() -> LaunchRequest? {
        defer { pendingRequest = nil }
        return pendingRequest
    }
}
