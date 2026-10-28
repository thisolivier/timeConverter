import Foundation
@testable import TimeConverterCore

/// The inputs the shared fixture file is generated from.
///
/// Editorial, not exhaustive: one or two cases per rule in
/// `docs/input-parsing-spec.md`, chosen so a second implementation that passes
/// them all has genuinely implemented the spec — the exhaustive coverage stays
/// in the per-rule suites beside this one. Add a row, run
/// `scripts/regenerate-fixtures.sh`, commit both.
///
/// Every case injects a `FixedDates` instant and a `FixedZones` device zone, so
/// the expected output is a fact and not a function of the machine's clock.
enum SharedFixtureCatalog {
    struct Entry {
        let id: String
        let input: String
        var now: Date = FixedDates.winterMidday
        var localZone: TimeZone = FixedZones.device
        var note: String? = nil
    }

    static let entries: [Entry] = [
        // Happy path — the grammar's four shapes.
        Entry(id: "spec-example-winter", input: "12pm ET in London",
              note: "The spec's own example; New York UTC-5, London UTC+0."),
        Entry(id: "spec-example-summer", input: "12pm ET in London", now: FixedDates.summerMidday,
              note: "Same input in July: both sides on daylight saving."),
        Entry(id: "twenty-four-hour", input: "14:30 ET in London"),
        Entry(id: "compact-twenty-four-hour", input: "1500 ET in London",
              note: "Item 27: HHmm without a colon; the last two digits are the minutes."),
        Entry(id: "compact-with-meridiem", input: "930pm Tokyo in London"),
        Entry(id: "country-alias-to-gazetteer-city", input: "23:15 UK to Porto",
              note: "Porto resolves through the bundled offline gazetteer; rolls to the next day."),
        Entry(id: "single-digit-hour", input: "6:34 UK to Lisbon"),
        Entry(id: "midnight-gmt-to-tokyo", input: "00:00 GMT in Tokyo"),
        Entry(id: "spaced-meridiem-multiword-cities", input: "9:30 am New York in Tokyo"),
        Entry(id: "previous-day-rollover", input: "11pm Tokyo in New York"),
        Entry(id: "foundation-abbreviation", input: "12:00 PST in Berlin"),
        Entry(id: "all-lowercase", input: "21:30 london in new york"),
        Entry(id: "redundant-agreeing-meridiem", input: "18pm Lisbon to Madrid"),
        Entry(id: "half-hour-offset", input: "10am Kolkata in London",
              note: "Kolkata is the tz identifier city."),
        Entry(id: "gazetteer-city-half-hour", input: "10am Mumbai in London",
              note: "Item 26: Mumbai via the grown offline gazetteer."),
        Entry(id: "gazetteer-city-default-source", input: "3pm in Barcelona",
              note: "Item 26: Barcelona via the gazetteer; source defaults to local."),
        Entry(id: "three-quarter-hour-offset", input: "3pm Kathmandu in London"),
        Entry(id: "same-zone-both-sides", input: "9am Paris in Paris"),
        Entry(id: "antarctic-station-city", input: "3pm in McMurdo",
              note: "Item 25: a station resolves as a tz-database city; southern summer, UTC+13."),
        Entry(id: "twelve-am-southern-to-western", input: "12am Sydney to Los Angeles"),

        // Local-zone defaulting (item 14) — device zone is Los Angeles.
        Entry(id: "default-source-to-local", input: "7pm in London"),
        Entry(id: "default-target-to-local", input: "7pm East Coast"),
        Entry(id: "default-with-tokyo-device", input: "7pm in London", localZone: FixedZones.tokyo),

        // Bare zone (item 22) and `now` (item 23) read the injected clock to the minute.
        Entry(id: "bare-zone-converts-now", input: "ET", now: FixedDates.winterAfternoonWithMinutes),
        Entry(id: "bare-zone-follows-dst", input: "ET", now: FixedDates.summerAfternoonWithMinutes),
        Entry(id: "now-keyword", input: "now in Bangkok", now: FixedDates.winterAfternoonWithMinutes),
        Entry(id: "now-with-named-source", input: "now ET in London", now: FixedDates.winterAfternoonWithMinutes),

        // Daylight-saving policy on the two days a year it applies.
        Entry(id: "dst-spring-forward-gap", input: "2:30 am New York in London",
              now: FixedDates.newYorkSpringForwardDay),
        Entry(id: "dst-fall-back-overlap", input: "1:30 am New York in London",
              now: FixedDates.newYorkFallBackDay),

        // Prompts.
        Entry(id: "p1-digits-only", input: "12"),
        Entry(id: "p1-contradicting-meridiem", input: "13:00 am ET in London"),
        Entry(id: "p1-two-places-no-time", input: "london to paris"),
        Entry(id: "p2-time-only", input: "7pm"),
        Entry(id: "p2-dangling-conjunction", input: "7pm in"),
        Entry(id: "p2-bare-now", input: "now"),
        Entry(id: "p4-ambiguous-abbreviation", input: "9am CST to IST"),
        Entry(id: "p4-two-candidate-country", input: "06:34 Portugal in PST"),
        Entry(id: "p4-antarctica-stations", input: "3pm in Antarctica",
              note: "Item 25: one chip per research station with a distinct clock."),
        Entry(id: "p5-typo-with-suggestions", input: "9am Lodnon to Paris"),
        Entry(id: "p5-bare-unknown-word", input: "hello"),
        Entry(id: "p5-now-as-destination", input: "9am in now"),

        // Quiet.
        Entry(id: "hint-empty", input: ""),
        Entry(id: "hint-whitespace", input: "   "),
    ]
}
