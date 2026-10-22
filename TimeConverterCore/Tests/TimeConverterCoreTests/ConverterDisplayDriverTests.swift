import Testing
import Foundation
@testable import TimeConverterCore

/// Item 8 — the 600 ms prompt debounce.
///
/// The delay is injected so these run in milliseconds rather than seconds, and
/// `waitForPendingPrompt()` awaits the driver's own task instead of sleeping a
/// guessed interval, which is what keeps them deterministic.
@MainActor
struct ConverterDisplayDriverTests {
    private static let testDelay: Duration = .milliseconds(5)

    private func makeDriver() -> ConverterDisplayDriver {
        ConverterDisplayDriver(promptDelay: Self.testDelay)
    }

    @Test func theShippedDelayIsTheDecidedSixHundredMilliseconds() {
        #expect(ConverterDisplayDriver.defaultPromptDelay == .milliseconds(600))
    }

    // MARK: Results never wait

    @Test func aConversionAppearsOnTheSameKeystroke() {
        let driver = makeDriver()
        driver.inputDidChange(to: "12pm ET in London", now: FixedDates.winterMidday)
        #expect(driver.displayState.convertedDisplay != nil)
    }

    /// A single named zone is a complete sentence now, and a conversion is
    /// still never held back — the answer arrives on the keystroke that
    /// completes it, with the defaulted side marked `(local)`.
    @Test func aSingleZoneSentenceConvertsAsSoonAsItIsComplete() {
        let driver = makeDriver()
        driver.inputDidChange(
            to: "7pm in London", now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        )
        #expect(driver.displayState.convertedDisplay?.echoLine
            == "7:00 pm Los Angeles (local, UTC-8) → 3:00 am London (UTC+0) +1d")
    }

    @Test func clearingTheFieldReturnsToTheHintImmediately() {
        let driver = makeDriver()
        driver.inputDidChange(to: "12pm ET in London", now: FixedDates.winterMidday)
        driver.inputDidChange(to: "", now: FixedDates.winterMidday)
        #expect(driver.displayState == .hint)
    }

    // MARK: Prompts wait

    @Test func aPromptIsWithheldUntilTheDelayElapses() async {
        let driver = makeDriver()
        driver.inputDidChange(to: "12pm ET in Lond", now: FixedDates.winterMidday)
        // Nothing yet: mid-word, the user is still typing.
        #expect(driver.displayState == .hint)

        await driver.waitForPendingPrompt()
        #expect(driver.displayState.problemMessage?.contains("Don't recognize 'lond'") == true)
    }

    /// The point of the debounce: typing through a sequence of unparseable
    /// states shows one prompt at the end, not one per keystroke.
    ///
    /// The walk now ends in a half-typed *unknown* place rather than in
    /// `12pm et`: since the 2026-10-22 local-defaulting amendment one named
    /// zone is a complete sentence, so `12pm et` converts on the keystroke that
    /// finishes it — see `aSingleZoneSentenceConvertsAsSoonAsItIsComplete`.
    @Test func typingThroughManyInvalidStatesShowsNoPromptAlongTheWay() async {
        let driver = makeDriver()
        for partialInput in ["1", "12", "12p", "12pm", "12pm ", "12pm n", "12pm na", "12pm nar"] {
            driver.inputDidChange(to: partialInput, now: FixedDates.winterMidday)
            #expect(driver.displayState == .hint, "'\(partialInput)' flashed a prompt")
        }
        await driver.waitForPendingPrompt()
        #expect(driver.displayState.problemMessage != nil)
    }

    /// A conversion already on screen is replaced by the hint rather than left
    /// standing under edited text — a stale answer is worse than none.
    @Test func editingAValidSentenceDoesNotLeaveTheOldConversionVisible() {
        let driver = makeDriver()
        driver.inputDidChange(to: "12pm ET in London", now: FixedDates.winterMidday)
        driver.inputDidChange(to: "12pm ET in Londonx", now: FixedDates.winterMidday)
        #expect(driver.displayState == .hint)
    }

    // MARK: Bypasses

    @Test func submittingShowsThePromptAtOnce() {
        let driver = makeDriver()
        driver.showWithoutWaiting(for: "12pm ET in Lodnon", now: FixedDates.winterMidday)
        #expect(driver.displayState.problemMessage != nil)
        #expect(driver.displayState.problemChips?.isEmpty == false)
    }

    @Test func aChipTapShowsTheNextPromptWithoutWaiting() throws {
        let driver = makeDriver()
        driver.showWithoutWaiting(for: "9am CST to IST", now: FixedDates.winterMidday)
        let chicago = try #require(driver.displayState.problemChips?.first)

        let rewritten = driver.apply(chicago, to: "9am CST to IST", now: FixedDates.winterMidday)
        #expect(rewritten == "9am Chicago to IST")
        #expect(driver.displayState.problemMessage?.hasPrefix("'ist' could mean") == true)
    }

    /// The view's ordinary change notification fires *after* a chip tap has
    /// already updated the display. It must not re-hide the prompt the tap just
    /// revealed.
    @Test func theChangeNotificationFollowingAChipTapIsIgnored() throws {
        let driver = makeDriver()
        driver.showWithoutWaiting(for: "9am CST to IST", now: FixedDates.winterMidday)
        let chicago = try #require(driver.displayState.problemChips?.first)

        let rewritten = driver.apply(chicago, to: "9am CST to IST", now: FixedDates.winterMidday)
        driver.inputDidChange(to: rewritten, now: FixedDates.winterMidday)
        #expect(driver.displayState.problemMessage?.hasPrefix("'ist' could mean") == true)
    }

    /// Typing again after a bypass is ordinary typing and goes back to waiting.
    @Test func typingAfterABypassIsDebouncedAgain() async {
        let driver = makeDriver()
        driver.showWithoutWaiting(for: "12pm ET in Lodnon", now: FixedDates.winterMidday)
        driver.inputDidChange(to: "12pm ET in Lodno", now: FixedDates.winterMidday)
        #expect(driver.displayState == .hint)
        await driver.waitForPendingPrompt()
        #expect(driver.displayState.problemMessage != nil)
    }

    /// Launch: the DEBUG `-initialInput` prefill must not photograph an empty
    /// hint, so it goes through the bypass too.
    @Test func aPrefilledInputRendersWithoutWaiting() {
        let driver = makeDriver()
        driver.showWithoutWaiting(for: "9:30 am New York to Lisbon", now: FixedDates.winterMidday)
        #expect(driver.displayState.convertedDisplay?.echoLine
            == "9:30 am New York (UTC-5) → 2:30 pm Lisbon (UTC+0)")
    }
}
