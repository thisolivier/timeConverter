import Testing
import Foundation
@testable import TimeConverterCore

/// Item 30's clock, edge by edge. The shared fixtures pin whole displays;
/// these name the individual rules.
struct WorldClockTests {
    static let london = FavouriteDestination(
        timeZoneIdentifier: "Europe/London", label: .place(name: "London", isDeviceLocal: false)
    )
    static let tokyo = FavouriteDestination(
        timeZoneIdentifier: "Asia/Tokyo", label: .place(name: "Tokyo", isDeviceLocal: false)
    )
    static let kolkata = FavouriteDestination(
        timeZoneIdentifier: "Asia/Kolkata", label: .place(name: "Kolkata", isDeviceLocal: false)
    )
    static let easternTime = FavouriteDestination(
        timeZoneIdentifier: "America/New_York", label: .abbreviation(code: "ET", expandedName: "Eastern Time")
    )

    /// 3:42 PM on Thu 15 Jan in Los Angeles.
    func readings(_ favourites: [FavouriteDestination], minutes: Int = 0,
                  now: Date = FixedDates.winterAfternoonWithMinutes,
                  localZone: TimeZone = FixedZones.losAngeles) -> WorldClockDisplay {
        WorldClock.readings(favourites: favourites, offset: TimeInterval(minutes * 60), now: now, localZone: localZone)
    }

    @Test func localRowComesFirstAndIsLabelledLocal() {
        let display = readings([Self.london])
        #expect(display.rows.map(\.placeName) == ["Los Angeles (local)", "London"])
        #expect(display.rows[0].isLocal)
        #expect(display.rows[0].offsetPhrase.isEmpty)
        #expect(display.rows[1].favourite == Self.london)
        #expect(display.readout == "Today 3:42 PM")
        #expect(display.offsetDescription == nil)
    }

    @Test func dayMarkerIsRelativeToTheLocalRowAcrossMidnight() {
        let live = readings([Self.london, Self.tokyo])
        #expect(live.rows[1].zoneLine == "United Kingdom Time (London)")
        #expect(live.rows[2].zoneLine == "Japan Standard Time (Tokyo) · next day")

        // +9 h: London passes midnight, but so has nothing local — 12:42 AM
        // Friday in Los Angeles; London 8:42 AM Fri, same day as local now.
        let shifted = readings([Self.london, Self.tokyo], minutes: 9 * 60)
        #expect(shifted.readout == "Tomorrow 12:42 AM")
        #expect(shifted.rows[1].zoneLine == "United Kingdom Time (London)")
        #expect(shifted.rows[2].zoneLine == "Japan Standard Time (Tokyo)")

        // Going back far enough puts London on the local day and Los Angeles
        // ahead of nobody: −16 h is 11:42 PM Wed; London 7:42 AM Thu.
        let back = readings([Self.london], minutes: -16 * 60)
        #expect(back.readout == "Yesterday 11:42 PM")
        #expect(back.rows[1].zoneLine == "United Kingdom Time (London) · next day")
    }

    @Test func aWestwardFavouriteCanBeOnThePreviousDay() {
        let honolulu = FavouriteDestination(
            timeZoneIdentifier: "Pacific/Honolulu", label: .place(name: "Honolulu", isDeviceLocal: false)
        )
        // 12:30 AM Fri in Los Angeles is 10:30 PM Thu in Honolulu.
        let display = readings([honolulu], minutes: 8 * 60 + 48)
        #expect(display.rows[1].clockDigits == "10:30")
        #expect(display.rows[1].zoneLine.hasSuffix(" · previous day"))
        #expect(display.rows[1].offsetPhrase == "2 hours behind")
    }

    @Test func minusFortyFiveMinutes() {
        let display = readings([Self.london], minutes: -45)
        #expect(display.offsetDescription == "\u{2212}45 min")
        #expect(display.readout == "Today 2:57 PM")
        #expect(display.rows[1].clockDigits == "10:57")
        #expect(display.rows[1].meridiem == "PM")
    }

    @Test func plusThreeDaysReadsAsAWeekdayAndDate() {
        let display = readings([Self.london], minutes: 3 * 1440)
        #expect(display.readout == "Sun 18 Jan, 3:42 PM")
        #expect(display.offsetDescription == "+3 d")
        #expect(readings([], minutes: 3 * 1440 + 135).offsetDescription == "+3 d 2 h 15 min")
        #expect(readings([], minutes: -3 * 1440).readout == "Mon 12 Jan, 3:42 PM")
    }

    /// The offset is a `TimeInterval`, unbounded — a year out is fine.
    @Test func theOffsetIsUnbounded() {
        let display = readings([Self.london], minutes: 365 * 1440)
        #expect(display.readout == "Fri 15 Jan, 3:42 PM")
        #expect(display.offsetDescription == "+365 d")
    }

    /// 1:30 AM EST + 1 h = 2:30 AM, which never happens on 8 March in New
    /// York: the converter's policy moves it to 3:00 AM EDT.
    @Test func aShiftIntoTheSpringForwardGapMovesToTheNextValidInstant() {
        let newYork = TimeZone(identifier: "America/New_York")!
        let display = readings([Self.london], minutes: 60,
                               now: FixedDates.utc(year: 2026, month: 3, day: 8, hour: 6, minute: 30), localZone: newYork)
        #expect(display.readout == "Today 3:00 AM")
        #expect(display.rows[1].clockDigits == "7:00")
        #expect(display.rows[1].offsetPhrase == "4 hours ahead")
    }

    /// `+1 d` across the change keeps the local wall clock, not 24 hours.
    @Test func aDayShiftKeepsTheLocalWallClockAcrossDaylightSaving() {
        let newYork = TimeZone(identifier: "America/New_York")!
        let saturdayNoon = FixedDates.utc(year: 2026, month: 3, day: 7, hour: 17)
        let display = readings([Self.london], minutes: 1440, now: saturdayNoon, localZone: newYork)
        #expect(display.readout == "Tomorrow 12:00 PM")
        #expect(display.rows[1].clockDigits == "4:00")
    }

    @Test func aHalfHourZone() {
        let display = readings([Self.kolkata])
        #expect(display.rows[1].clockDigits == "5:12")
        #expect(display.rows[1].meridiem == "AM")
        #expect(display.rows[1].offsetPhrase == "13.5 hours ahead")
        #expect(display.rows[1].zoneLine == "India Standard Time (Kolkata, Mumbai) · next day")
    }

    @Test func aCodeLabelKeepsTheCodeAndShowsOnlyTheCities() {
        let display = readings([Self.easternTime])
        #expect(display.rows[1].placeName == "ET (Eastern Time)")
        #expect(display.rows[1].zoneLine == "New York, Toronto")
        #expect(display.rows[1].id == Self.easternTime.id)
    }

    /// Rows read exactly as the converter's result band does.
    @Test func aRowMatchesTheConverterResultBand() throws {
        let converted = try #require(ConverterPresenter()
            .displayState(for: "3:42pm Los Angeles in Tokyo", now: FixedDates.winterAfternoonWithMinutes)
            .convertedDisplay)
        let row = readings([Self.tokyo]).rows[1]
        #expect(row.clockDigits == converted.targetClockDigits)
        #expect(row.meridiem == converted.targetMeridiem)
        #expect(row.zoneLine == converted.targetZoneLine)
        #expect(row.offsetPhrase == converted.offsetPhrase)
    }

    @Test func aStaleIdentifierIsSkipped() {
        let stale = FavouriteDestination(
            timeZoneIdentifier: "Mars/Olympus_Mons", label: .place(name: "Olympus Mons", isDeviceLocal: false)
        )
        #expect(readings([stale, Self.london]).rows.map(\.placeName) == ["Los Angeles (local)", "London"])
    }
}
