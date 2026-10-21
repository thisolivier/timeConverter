import Testing
import SwiftUI
@testable import TimeConverter

/// Item 10 — autofocus on launch and on foreground, and *only* then.
///
/// `@FocusState` itself is platform machinery and is verified by running the
/// app (see the README's QA section). What is worth testing is the decision of
/// when to take focus, which is why it lives in `InputFocusPolicy` rather than
/// inline in the view.
struct InputFocusPolicyTests {
    @Test func launchFocusesTheField() {
        #expect(InputFocusPolicy.shouldFocusOnAppear)
    }

    @Test func returningFromTheBackgroundFocusesTheField() {
        #expect(InputFocusPolicy.shouldFocusInput(movingFrom: .background, to: .active))
    }

    /// The Catalyst case: clicking another window and back cycles
    /// active → inactive → active. Re-grabbing focus there would be stealing it
    /// mid-session.
    @Test func regainingKeyStatusDoesNotStealFocus() {
        #expect(!InputFocusPolicy.shouldFocusInput(movingFrom: .inactive, to: .active))
    }

    @Test(arguments: [ScenePhase.inactive, .background])
    func leavingTheAppNeverFocusesTheField(currentPhase: ScenePhase) {
        #expect(!InputFocusPolicy.shouldFocusInput(movingFrom: .active, to: currentPhase))
        #expect(!InputFocusPolicy.shouldFocusInput(movingFrom: .background, to: currentPhase))
    }

    /// Autofocus must not disturb the DEBUG prefill: the launch argument is
    /// still read, and still renders a conversion on the first frame without
    /// waiting for the prompt debounce.
    @Test @MainActor func autofocusDoesNotDisturbTheDebugPrefill() throws {
        let defaults = try #require(UserDefaults(suiteName: "InputFocusPolicyTests"))
        defer { defaults.removeObject(forKey: LaunchArguments.initialInputKey) }
        defaults.set("12pm ET in London", forKey: LaunchArguments.initialInputKey)

        #if DEBUG
        let prefill = try #require(LaunchArguments.initialInput(readingFrom: defaults))
        let driver = ConverterDisplayDriver(promptDelay: .milliseconds(5))
        driver.showWithoutWaiting(for: prefill, now: FixedDates.winterMidday)
        #expect(driver.displayState.convertedDisplay?.echoLine
            == "12:00 pm Eastern Time (New York, Toronto, UTC-5) → 5:00 pm London (UTC+0)")
        #else
        #expect(LaunchArguments.initialInput(readingFrom: defaults) == nil)
        #endif
    }
}
