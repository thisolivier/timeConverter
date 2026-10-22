import Testing
import Foundation
@testable import TimeConverterCore

/// The DEBUG `-initialInput` prefill (QA affordance, see the README).
///
/// This test used to live in the app target's `InputFocusPolicyTests`, because
/// the prefill and the autofocus rule shipped together in item 10. It moved
/// here with `LaunchArguments` and `ConverterDisplayDriver`: the thing being
/// asserted is that a prefilled sentence renders its conversion on the first
/// frame *without* waiting for the prompt debounce, and none of that is view
/// code. The `@FocusState` half stayed behind with the view.
struct LaunchArgumentsTests {
    /// A suite name per test, not one shared across the suite: Swift Testing
    /// runs these in parallel and a shared `UserDefaults` suite makes one
    /// test's cleanup the other's missing prefill.
    @Test @MainActor func theDebugPrefillRendersImmediately() throws {
        let defaults = try #require(UserDefaults(suiteName: "LaunchArgumentsTests.prefill"))
        defer { defaults.removeObject(forKey: LaunchArguments.initialInputKey) }
        defaults.set("12pm ET in London", forKey: LaunchArguments.initialInputKey)

        #if DEBUG
        let prefill = try #require(LaunchArguments.initialInput(readingFrom: defaults))
        let driver = ConverterDisplayDriver(promptDelay: .milliseconds(5))
        driver.showWithoutWaiting(for: prefill, now: FixedDates.winterMidday)
        #expect(driver.displayState.convertedDisplay?.echoLine
            == "12:00 pm Eastern Time (New York, Toronto, UTC-5) → 5:00 pm London (UTC+0)")
        #else
        // A shipped build must never let a launch argument drive its UI.
        #expect(LaunchArguments.initialInput(readingFrom: defaults) == nil)
        #endif
    }

    /// Blank and whitespace-only values are "no prefill", not an empty
    /// sentence — otherwise `-initialInput ""` would look like a launcher press.
    @Test func blankValuesAreNoPrefillAtAll() throws {
        let defaults = try #require(UserDefaults(suiteName: "LaunchArgumentsTests"))
        defer { defaults.removeObject(forKey: LaunchArguments.initialInputKey) }

        for blank in ["", "   ", "\n"] {
            defaults.set(blank, forKey: LaunchArguments.initialInputKey)
            #expect(LaunchArguments.initialInput(readingFrom: defaults) == nil)
        }
    }
}
