import Combine
import SwiftUI
import TimeConverterCore

/// Is the software keyboard up? — the one fact item 19's choreography needs
/// from the platform.
///
/// Extracted from `ContentView` for the same reason `InputFocusPolicy` was: the
/// view should read as a layout, and "subscribe to two UIKit notifications and
/// merge them" is not layout. The *decision* that follows from this fact lives
/// in `PosterLayoutMode`, in the core package, where it is unit-tested.
///
/// ## Why notifications rather than the safe area
///
/// SwiftUI does fold the keyboard into the bottom safe-area inset, so a
/// `GeometryReader` could infer this by watching that inset grow. It would also
/// mean picking a threshold to separate "home indicator" from "keyboard", and
/// reading an inset the enclosing `ScrollView` has already consumed. Two
/// notifications with unambiguous names are the honest version.
///
/// `willShow`/`willHide` rather than `didShow`/`didHide`: the animation should
/// start with the keyboard's, not after it.
extension View {
    /// Keeps `binding` true for as long as the keyboard is on screen.
    ///
    /// The DEBUG `-forceCompact` launch argument is folded in here, at the one
    /// place keyboard visibility is established, so nothing downstream has to
    /// know the flag exists — including the layout rule, which stays a pure
    /// function of (input, keyboard).
    func observingKeyboardVisibility(into binding: Binding<Bool>) -> some View {
        onReceive(KeyboardVisibility.changes) { keyboardIsOnScreen in
            binding.wrappedValue = keyboardIsOnScreen
                || LaunchArguments.forcesKeyboardVisible
        }
    }
}

enum KeyboardVisibility {
    /// The value the field starts at, before any notification has arrived.
    ///
    /// False in an ordinary launch — the keyboard is not up yet even though
    /// item 10 is about to focus the field, and the `willShow` that follows
    /// corrects it one frame later. True only under `-forceCompact`, which has
    /// to be right on the *first* frame because a screenshot run may never
    /// produce a keyboard notification at all.
    static var initialValue: Bool { LaunchArguments.forcesKeyboardVisible }

    /// `true` when the keyboard is coming up, `false` when it is going away.
    ///
    /// The two notifications are merged and mapped to plain `Bool`s before they
    /// reach the view, which keeps a non-`Sendable` `Notification` out of the
    /// main-actor closure entirely.
    static var changes: AnyPublisher<Bool, Never> {
        let center = NotificationCenter.default
        return center.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }
            .merge(with: center.publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in false })
            .eraseToAnyPublisher()
    }
}
