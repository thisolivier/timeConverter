import Foundation

/// Turns "this wall-clock time, today, in this zone" into a single instant,
/// applying the spec's DST policy explicitly rather than trusting
/// `Calendar.date(from:)` to pick for us.
///
/// Policy:
/// - A time that exists once → that instant.
/// - A time that exists twice (clocks went back) → the **earlier** instant.
/// - A time that never happens (clocks went forward) → the **next valid
///   instant**, i.e. the transition itself.
///
/// No prompt in any case; the UTC offsets in the output make the choice visible.
enum WallClockResolver {
    /// Which branch of the policy applied — surfaced so the UI and the tests
    /// can assert the DST behaviour directly.
    enum Disposition: Equatable, Sendable {
        /// The requested wall time exists exactly once.
        case unambiguous
        /// Clocks went back: the requested time happened twice, earlier taken.
        case repeatedTimeTookEarlier
        /// Clocks went forward: the requested time never happened, shifted to
        /// the next valid instant.
        case nonexistentTimeShiftedForward
    }

    struct Outcome: Equatable, Sendable {
        let instant: Date
        let disposition: Disposition
    }

    /// `referenceDate` supplies "today": the calendar day is read *in the
    /// source zone*, so a caller in London converting a New York time near
    /// midnight still gets New York's today.
    static func resolve(
        wallClock time: ParsedTime,
        onDayOf referenceDate: Date,
        in timeZone: TimeZone
    ) -> Outcome {
        let dayComponents = GregorianCalendars.calendar(in: timeZone)
            .dateComponents([.year, .month, .day], from: referenceDate)

        // The requested wall time read as if it were UTC. Subtracting a
        // candidate offset from this gives the instant that *would* show that
        // wall time if the zone were at that offset.
        guard let wallTimeAsUTC = GregorianCalendars.utc.date(from: DateComponents(
            year: dayComponents.year,
            month: dayComponents.month,
            day: dayComponents.day,
            hour: time.hour,
            minute: time.minute
        )) else {
            return Outcome(instant: referenceDate, disposition: .unambiguous)
        }

        // Any offset in force within a day either side of the target is a
        // candidate — that window always brackets a DST transition on the day.
        let candidateOffsets = Set([-86_400.0, 0.0, 86_400.0].map { dayShift in
            timeZone.secondsFromGMT(for: wallTimeAsUTC.addingTimeInterval(dayShift))
        })

        var candidateInstants: [Date] = []
        var validInstants: [Date] = []
        for offset in candidateOffsets {
            let candidateInstant = wallTimeAsUTC.addingTimeInterval(-Double(offset))
            candidateInstants.append(candidateInstant)
            // Self-consistency check: the zone really is at `offset` then, so
            // the wall clock there really does read the requested time.
            if timeZone.secondsFromGMT(for: candidateInstant) == offset {
                validInstants.append(candidateInstant)
            }
        }

        if let earliestValidInstant = validInstants.min() {
            return Outcome(
                instant: earliestValidInstant,
                disposition: validInstants.count > 1 ? .repeatedTimeTookEarlier : .unambiguous
            )
        }

        return Outcome(
            instant: nextValidInstant(after: candidateInstants, in: timeZone),
            disposition: .nonexistentTimeShiftedForward
        )
    }

    /// In a spring-forward gap the rejected candidates straddle the transition:
    /// the one computed with the pre-transition offset lands after it, the one
    /// with the post-transition offset lands before it. So the first transition
    /// following the earliest candidate *is* the gap's end — the next valid
    /// instant, whose wall clock reads just past the requested time.
    private static func nextValidInstant(after candidateInstants: [Date], in timeZone: TimeZone) -> Date {
        guard let earliestCandidate = candidateInstants.min() else { return Date(timeIntervalSince1970: 0) }
        if let transition = timeZone.nextDaylightSavingTimeTransition(after: earliestCandidate) {
            return transition
        }
        return candidateInstants.max() ?? earliestCandidate
    }
}
