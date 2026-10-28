import Testing
import Foundation
@testable import TimeConverter

/// The Clocks tab's offset rules (item 31).
struct ClockOffsetTests {
    @Test func intervalIsDaysPlusSliderMinutes() {
        var offset = ClockOffset()
        #expect(offset.interval == 0)
        offset.days = -3
        offset.sliderMinutes = 90
        #expect(offset.interval == -3 * 86_400 + 90 * 60)
    }

    @Test func resetReturnsToNow() {
        var offset = ClockOffset(days: 4, launchMinutes: 1140)
        offset.reset()
        #expect(offset == ClockOffset())
    }

    @Test func launchMinutesAreClampedAndSnapped() {
        #expect(ClockOffset(launchMinutes: 1140).sliderMinutes == 1140)
        #expect(ClockOffset(launchMinutes: 22).sliderMinutes == 15)
        #expect(ClockOffset(launchMinutes: -5000).sliderMinutes == -1440)
        #expect(ClockOffset(days: 7).days == 7)
    }

    @Test func onlyAQuickUnmovedPressIsATap() {
        #expect(ClockOffset.editingWasATap(startValue: 0, endValue: 0, duration: 0.1))
        #expect(!ClockOffset.editingWasATap(startValue: 0, endValue: 15, duration: 0.1))
        #expect(!ClockOffset.editingWasATap(startValue: 0, endValue: 0, duration: 1.0))
    }
}
