import Testing
import Foundation
@testable import TimeConverterCore

/// Item 36b — the widgets' layout follows the city count and the family.
struct WidgetLayoutPlanTests {
    private func shape(_ family: WidgetLayoutPlan.Family, _ count: Int)
        -> (Int, Int, WidgetLayoutPlan.NameStyle, WidgetLayoutPlan.CaptionStyle) {
        let plan = WidgetLayoutPlan.plan(family: family, cityCount: count)
        return (plan.columnCount, plan.rowCount, plan.nameStyle, plan.captionStyle)
    }

    @Test func theBriefsTable() {
        #expect(shape(.small, 3) == (1, 3, .code, .none))
        #expect(shape(.small, 4) == (2, 2, .code, .none))
        #expect(shape(.small, 6) == (2, 3, .code, .none))
        #expect(shape(.medium, 3) == (3, 1, .full, .short))
        #expect(shape(.medium, 4) == (2, 2, .full, .short))
        #expect(shape(.medium, 6) == (3, 2, .full, .none))
        #expect(shape(.large, 3) == (1, 3, .full, .full))
        #expect(shape(.large, 4) == (2, 2, .full, .full))
        #expect(shape(.large, 6) == (2, 3, .full, .short))
    }

    @Test func oneCityIsAHeroSevenAreCappedFiveSpanTheLastRow() {
        for family in WidgetLayoutPlan.Family.allCases {
            #expect(WidgetLayoutPlan.plan(family: family, cityCount: 1).isHero)
        }
        #expect(WidgetLayoutPlan.plan(family: .large, cityCount: 9).cityCount == 6)
        #expect(WidgetLayoutPlan.plan(family: .large, cityCount: 5).lastCellSpansRow)
        #expect(!WidgetLayoutPlan.plan(family: .large, cityCount: 6).lastCellSpansRow)
        #expect(WidgetLayoutPlan.plan(family: .large, cityCount: 5).rows(Array(1...9)) == [[1, 2], [3, 4], [5]])
    }

    @Test func shortNamesAreCuratedCutOrTheCode() throws {
        #expect(ShortPlaceNames.bundledNames.count > 3000)
        let favourites = try ["Los Angeles", "Kathmandu", "Portland Oregon", "ET", "Sao Paulo"].map {
            try #require(FavouriteDestination.resolvingTypedZone($0))
        }
        let display = WorldClock.readings(
            favourites: favourites, offset: 0, now: FixedDates.winterMidday, localZone: FixedZones.device
        )
        #expect(display.rows.map(\.shortPlaceName) == ["LA", "LA", "KATH", "PORT", "ET", "SÃO"])
        #expect(ShortPlaceNames.shortName(for: .place(name: "Atlantis", isDeviceLocal: false), compactPlaceName: "Atlantis") == "ATL")
    }

    @Test func twentyFourHourDigitsAreZeroPadded() throws {
        let favourites = try ["Tokyo", "London"].map { try #require(FavouriteDestination.resolvingTypedZone($0)) }
        // 12:00 UTC on 15 Jan: Los Angeles 4:00 AM, Tokyo 9:00 PM, London 12:00 PM.
        let display = WorldClock.readings(
            favourites: favourites, offset: 0, now: FixedDates.winterMidday, localZone: FixedZones.device
        )
        #expect(display.rows.map(\.twentyFourHourDigits) == ["04:00", "21:00", "12:00"])
        #expect(display.rows.map(\.clockDigits) == ["4:00", "9:00", "12:00"])
    }

    /// Every name a favourite can carry has a hand-written short form, so the
    /// first-three-letters fallback is only ever for data that drifted.
    @Test func everyPlaceNameHasAShortForm() {
        let table = ShortPlaceNames.bundledNames
        var missing: [String] = []
        for identifier in TimeZone.knownTimeZoneIdentifiers where TimeZoneDatabaseCityResolver.isCityBearing(identifier) {
            let city = ZoneDisplayName.forIdentifier(identifier)
            if table[city.lowercased()] == nil { missing.append(city) }
        }
        for (name, _) in OfflineFallbackGazetteer.bundledEntries {
            let display = OfflineFallbackGazetteer.bundledDisplayNames[name] ?? ZoneTokenDisplay.placeName(forToken: name)
            let compact = String(display.prefix { $0 != "," })
            if table[compact.lowercased()] == nil { missing.append(compact) }
        }
        #expect(missing.isEmpty, "no short form for: \(missing.prefix(20))")
    }
}
