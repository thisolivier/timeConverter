import Testing
import Foundation
@testable import TimeConverter

/// The Clocks tab's endless dial, as rules (item 31, reworked 2026-10-29).
struct ClockOffsetTests {
    @Test func aFullWidthPullLeftIsTwelveHoursForwardAndTheNextAddsToIt() {
        var offset = ClockOffset()
        offset.drag(translationWidth: -390, trackWidth: 390)
        #expect(offset.minutes == 720)
        offset.settleDrag()
        #expect(offset.settledMinutes == 720 && offset.draggedMinutes == 0)

        offset.drag(translationWidth: -390, trackWidth: 390)
        offset.settleDrag()
        #expect(offset.minutes == 1440)
        #expect(offset.interval == 1440 * 60)

        // Pulling right is backwards; nothing stops it going past zero.
        offset.drag(translationWidth: 3 * 390, trackWidth: 390)
        offset.settleDrag()
        #expect(offset.minutes == -720)
    }

    @Test func theValueSnapsToFifteenMinutesButTheStripDoesNot() {
        var offset = ClockOffset()
        offset.drag(translationWidth: -10, trackWidth: 720)   // 10 minutes
        #expect(offset.minutes == 15)
        #expect(offset.continuousMinutes == 10)
        offset.drag(translationWidth: -7, trackWidth: 720)    // 7 minutes
        #expect(offset.minutes == 0)
        offset.settleDrag()
        #expect(offset.settledMinutes == 0)
    }

    @Test func aZeroWidthTrackIsIgnored() {
        var offset = ClockOffset()
        offset.drag(translationWidth: 100, trackWidth: 0)
        #expect(offset.minutes == 0)
    }

    @Test func resetReturnsToNow() {
        var offset = ClockOffset(launchDays: 4, launchMinutes: 1140)
        offset.drag(translationWidth: 50, trackWidth: 390)
        offset.reset()
        #expect(offset == ClockOffset())
    }

    @Test func launchArgumentsFoldIntoOneSnappedValue() {
        #expect(ClockOffset(launchMinutes: 1140).minutes == 1140)
        #expect(ClockOffset(launchMinutes: 22).minutes == 15)
        #expect(ClockOffset(launchDays: -3).minutes == -3 * 1440)
        #expect(ClockOffset(launchDays: 1, launchMinutes: 90).minutes == 1530)
    }

    @Test func voiceOverStepsByOneTick() {
        var offset = ClockOffset()
        offset.step(by: 1)
        offset.step(by: 1)
        #expect(offset.minutes == 30)
        offset.step(by: -3)
        #expect(offset.minutes == -15)
    }
}
