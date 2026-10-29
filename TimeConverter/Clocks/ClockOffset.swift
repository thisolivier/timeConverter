import Foundation

/// The Clocks tab's offset: minutes from now, unbounded, moved by an endless
/// dial (Olivier, 2026-10-29: "a slider which is like a big dial … it can be
/// turned and turned again. One swipe is 12 hours in one direction, a second
/// pushes it another 12 hours"). That replaced build 20's bounded slider and
/// day stepper. Kept out of the view so its rules are tested.
///
/// Two parts: minutes **settled** by finished drags, and the minutes of the
/// drag **in progress**. The value the clock reads is their sum snapped to
/// 15 minutes; the dial's tick strip moves on the unsnapped sum so it follows
/// the finger smoothly.
struct ClockOffset: Equatable {
    static let stepMinutes: Double = 15
    /// One full-width swipe across the dial is 12 hours.
    static let minutesPerTrackWidth: Double = 720

    var settledMinutes: Double = 0
    var draggedMinutes: Double = 0

    /// The offset the clock shows: settled plus in-progress, snapped.
    var minutes: Double { Self.snapped(settledMinutes + draggedMinutes) }

    /// The unsnapped position, for drawing the dial mid-drag.
    var continuousMinutes: Double { settledMinutes + draggedMinutes }

    /// What `WorldClock.readings` takes. Unbounded.
    var interval: TimeInterval { minutes * 60 }

    /// The DEBUG `-clockOffsetDays` / `-clockOffsetMinutes` start, folded into
    /// one settled value and snapped.
    init(launchDays: Int = 0, launchMinutes: Int = 0) {
        settledMinutes = Self.snapped(Double(launchDays) * 1440 + Double(launchMinutes))
    }

    /// A drag in progress: rightwards is forwards in time, a whole track width
    /// is twelve hours, however many times over.
    mutating func drag(translationWidth: Double, trackWidth: Double) {
        guard trackWidth > 0 else { return }
        draggedMinutes = translationWidth / trackWidth * Self.minutesPerTrackWidth
    }

    /// The finger lifted: bank the drag, snapped, so the next swipe adds to it.
    mutating func settleDrag() {
        settledMinutes = minutes
        draggedMinutes = 0
    }

    /// Back to now: the tap-on-dial gesture.
    mutating func reset() {
        self = ClockOffset()
    }

    /// VoiceOver's increment / decrement: one step.
    mutating func step(by steps: Int) {
        settledMinutes = minutes + Double(steps) * Self.stepMinutes
        draggedMinutes = 0
    }

    static func snapped(_ minutes: Double) -> Double {
        (minutes / stepMinutes).rounded() * stepMinutes
    }
}
