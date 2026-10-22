import Foundation
import Observation

/// What a launcher asks the app to do the moment it opens it (backlog items 11
/// and 12a).
///
/// A launcher is a *faster path to the keyboard*, not a second interaction
/// model: nothing here can carry a typed sentence, pick a time zone, or pre-run
/// a conversion. What the cases distinguish is only what happens to the
/// sentence already in the field — and because this is an enum, adding a third
/// answer stops `ContentView` compiling until it is handled, which is the point.
enum LaunchRequest: Equatable, Sendable {
    /// "Open with an empty field, ready to type." The App Shortcut, the Control
    /// Center control, and `timeconverter://convert`.
    case startFreshConversion

    /// "Show me the window again." The Mac menu-bar item and ⌃⌥T (item 12a).
    ///
    /// A separate case because summoning a window is *not* a request to throw
    /// away what is in it. On the Mac the app lives all day behind other
    /// windows, so ⌃⌥T is routinely pressed to get back to a sentence mid-edit
    /// — clearing it there would be destroying work, where clearing it on a
    /// Control Center press is obeying the button.
    case summonWithoutReset
}

extension LaunchRequest {
    /// The input the app should be showing once this request has been honoured,
    /// or `nil` for "leave the typed sentence exactly as it is".
    ///
    /// For a launcher it is empty, always — even when the user had a half-typed
    /// sentence in the field. A launcher is pressed to *start* a conversion, so
    /// leaving the previous text in place would mean the first keystroke
    /// silently edits something the user did not put there in this session. The
    /// typed sentence is still the single source of truth; a launcher simply
    /// resets it, and a summon does not touch it.
    var inputToStartFrom: String? {
        switch self {
        case .startFreshConversion: ""
        case .summonWithoutReset: nil
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
/// The Mac menu bar (item 12a) posts here too, from the same main thread — the
/// bundle raises the window, the app honours the request.
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
