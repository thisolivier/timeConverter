import Testing
import Foundation
@testable import TimeConverterCore

/// The DEBUG QA hooks for items 30–31. Read from a throwaway suite, never
/// from the standard domain.
struct LaunchArgumentsClocksTests {
    func withDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "LaunchArgumentsClocksTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        body(defaults)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func favouritesSeedResolvesEachZoneAndSkipsTheUnconvertible() {
        withDefaults { defaults in
            #expect(LaunchArguments.seededFavourites(readingFrom: defaults) == nil)
            defaults.set("London, ET,CST, Kolkata", forKey: LaunchArguments.favouritesKey)
            let seeded = LaunchArguments.seededFavourites(readingFrom: defaults)
            #expect(seeded?.map(\.timeZoneIdentifier) == ["Europe/London", "America/New_York", "Asia/Kolkata"])
            #expect(seeded?[1].label == .abbreviation(code: "ET", expandedName: "Eastern Time"))
        }
    }

    @Test func selectedTabAndSignedOffsets() {
        withDefaults { defaults in
            #expect(!LaunchArguments.opensOnClocksTab(readingFrom: defaults))
            defaults.set("Clocks", forKey: LaunchArguments.selectedTabKey)
            #expect(LaunchArguments.opensOnClocksTab(readingFrom: defaults))

            #expect(LaunchArguments.signedInteger(forKey: LaunchArguments.clockOffsetDaysKey, readingFrom: defaults) == 0)
            for (text, value) in [("3", 3), ("m3", -3), (" -3", -3), ("1140", 1140), ("junk", 0)] {
                defaults.set(text, forKey: LaunchArguments.clockOffsetDaysKey)
                #expect(LaunchArguments.signedInteger(
                    forKey: LaunchArguments.clockOffsetDaysKey, readingFrom: defaults
                ) == value, "\(text)")
            }
        }
    }
}
