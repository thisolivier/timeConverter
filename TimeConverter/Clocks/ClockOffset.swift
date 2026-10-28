import Foundation

/// The Clocks tab's offset (item 31): whole days from the stepper plus
/// minutes from the slider. Kept out of the view so its rules are tested.
///
/// The slider covers −24 h…+24 h in 15-minute steps; the stepper moves the
/// day anchor with no limit, so any instant is reachable at 15-minute
/// precision however far out.
struct ClockOffset: Equatable {
    static let sliderRangeMinutes: ClosedRange<Double> = -1440...1440
    static let sliderStepMinutes: Double = 15
    /// How quickly a press must lift, unmoved, to count as a tap.
    static let tapMaximumDuration: TimeInterval = 0.35

    var days: Int = 0
    var sliderMinutes: Double = 0

    /// What `WorldClock.readings` takes. Unbounded.
    var interval: TimeInterval {
        TimeInterval(days) * 86_400 + sliderMinutes * 60
    }

    /// Back to now: the tap-on-slider gesture.
    mutating func reset() {
        self = ClockOffset()
    }

    /// The DEBUG `-clockOffsetDays` / `-clockOffsetMinutes` start, with the
    /// minutes clamped to the slider and snapped to its step.
    init(days: Int = 0, launchMinutes: Int = 0) {
        self.days = days
        self.sliderMinutes = Self.snapped(Double(launchMinutes))
    }

    static func snapped(_ minutes: Double) -> Double {
        let clamped = min(max(minutes, sliderRangeMinutes.lowerBound), sliderRangeMinutes.upperBound)
        return (clamped / sliderStepMinutes).rounded() * sliderStepMinutes
    }

    /// The fallback tap detector, from the slider's own editing callbacks: a
    /// press on the thumb that ended quickly without changing the value.
    static func editingWasATap(startValue: Double, endValue: Double, duration: TimeInterval) -> Bool {
        startValue == endValue && duration <= tapMaximumDuration
    }
}
