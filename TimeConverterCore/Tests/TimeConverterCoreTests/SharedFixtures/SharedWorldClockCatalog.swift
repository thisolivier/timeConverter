import Foundation
@testable import TimeConverterCore

/// The inputs `fixtures/world-clock-cases.json` is generated from (item 30).
///
/// Favourites are written as the zone a user would have typed after `in`, and
/// resolved through the real parser into exactly the destination a tap on the
/// star would store; the fixture file then spells each one out explicitly, so
/// the Android side never needs to parse to read it.
///
/// Add a row, run `scripts/regenerate-fixtures.sh`, commit both.
enum SharedWorldClockCatalog {
    struct Entry {
        let id: String
        var now: Date = FixedDates.winterAfternoonWithMinutes
        var localZone: TimeZone = FixedZones.device
        var offsetMinutes: Int = 0
        var favouriteZones: [String] = []
        var note: String? = nil
    }

    /// 2026-03-08 06:30 UTC — 1:30 AM EST in New York, half an hour before the
    /// clocks go forward, so +1 h lands in the gap.
    static let newYorkJustBeforeSpringForward = FixedDates.utc(year: 2026, month: 3, day: 8, hour: 6, minute: 30)
    /// 2026-11-01 06:30 UTC — the *second* 1:30 AM in New York (EST again).
    static let newYorkSecondRepeatedHour = FixedDates.utc(year: 2026, month: 11, day: 1, hour: 6, minute: 30)
    static let newYork = TimeZone(identifier: "America/New_York")!

    static let threeFavourites = ["London", "ET", "Tokyo"]

    static let entries: [Entry] = [
        Entry(id: "no-favourites",
              note: "Only the local row. Device zone Los Angeles, 3:42 PM on Thu 15 Jan."),
        Entry(id: "three-favourites-now", favouriteZones: threeFavourites,
              note: "Live clock: Tokyo is already on Friday, so its row carries the next-day marker."),
        Entry(id: "plus-24-hours-crossing-a-day", offsetMinutes: 24 * 60, favouriteZones: threeFavourites,
              note: "Readout says Tomorrow; markers stay relative to the local row's date."),
        Entry(id: "plus-19-hours-next-day", offsetMinutes: 19 * 60, favouriteZones: threeFavourites,
              note: "Local is tomorrow morning; Tokyo has moved on to the day after."),
        Entry(id: "minus-45-minutes", offsetMinutes: -45, favouriteZones: threeFavourites,
              note: "The offset uses a true minus sign."),
        Entry(id: "plus-3-days-2-hours-weekday-readout", offsetMinutes: 3 * 1440 + 120, favouriteZones: ["London"],
              note: "Beyond one day the readout names the weekday and date."),
        Entry(id: "minus-1-day-yesterday", offsetMinutes: -1440, favouriteZones: ["London"]),
        Entry(id: "half-hour-zone", favouriteZones: ["Kolkata", "Kathmandu"],
              note: "Offset phrases in fractional hours; Kolkata on the next day."),
        Entry(id: "dst-gap-landing", now: newYorkJustBeforeSpringForward, localZone: newYork,
              offsetMinutes: 60, favouriteZones: ["London"],
              note: "1:30 AM + 1 h is 2:30 AM, which never happens in New York that day: the converter's policy moves it to 3:00 AM EDT."),
        Entry(id: "repeated-hour-live", now: newYorkSecondRepeatedHour, localZone: newYork,
              favouriteZones: ["London"],
              note: "At zero the real instant is read directly, so the second 1:30 AM shows London 6:30 AM, not 5:30."),
        Entry(id: "code-labelled-favourites", favouriteZones: ["ET", "JST", "east coast"],
              note: "Code labels keep the code and its expansion; the zone line is the curated cities only."),
    ]
}
