import Testing
import SwiftUI
@testable import TimeConverter

/// Item 10 — autofocus on launch and on foreground, and *only* then.
///
/// `@FocusState` itself is platform machinery and is verified by running the
/// app (see the README's QA section). What is worth testing is the decision of
/// when to take focus, which is why it lives in `InputFocusPolicy` rather than
/// inline in the view.
///
/// One of this suite's tests moved out with the core extraction (item 16): the
/// DEBUG-prefill assertion is now `LaunchArgumentsTests` in
/// `TimeConverterCore`, where `LaunchArguments` and `ConverterDisplayDriver`
/// live. What is left here is the part that genuinely belongs to the iOS shell.
struct InputFocusPolicyTests {
    @Test func launchFocusesTheField() {
        #expect(InputFocusPolicy.shouldFocusOnAppear(isFirstAppearance: true))
    }

    /// Coming back to Convert from the Clocks tab re-runs `onAppear`; the
    /// keyboard must not pop up for that.
    @Test func returningToTheTabDoesNotFocusTheField() {
        #expect(!InputFocusPolicy.shouldFocusOnAppear(isFirstAppearance: false))
    }

    @Test func aLauncherFocusesTheFieldEvenMidSession() {
        #expect(InputFocusPolicy.shouldFocusOnLaunchRequest)
    }

    @Test func returningFromTheBackgroundFocusesTheField() {
        #expect(InputFocusPolicy.shouldFocusInput(movingFrom: .background, to: .active))
    }

    /// Clicking another window and back cycles active → inactive → active on
    /// iPad multitasking (and used to on Mac Catalyst, before the Mac became
    /// its own target). Re-grabbing focus there would be stealing it
    /// mid-session.
    @Test func regainingKeyStatusDoesNotStealFocus() {
        #expect(!InputFocusPolicy.shouldFocusInput(movingFrom: .inactive, to: .active))
    }

    @Test(arguments: [ScenePhase.inactive, .background])
    func leavingTheAppNeverFocusesTheField(currentPhase: ScenePhase) {
        #expect(!InputFocusPolicy.shouldFocusInput(movingFrom: .active, to: currentPhase))
        #expect(!InputFocusPolicy.shouldFocusInput(movingFrom: .background, to: currentPhase))
    }
}
