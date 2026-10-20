import Testing
import Foundation
@testable import TimeConverter

/// Smoke tests proving the test harness and the system timezone database the
/// app will depend on are both working. Real parser tests arrive with item 3.
struct EnvironmentSmokeTests {
    @Test func timeZoneDatabaseResolvesCommonIdentifiers() {
        #expect(TimeZone(identifier: "Europe/London") != nil)
        #expect(TimeZone(identifier: "Europe/Lisbon") != nil)
        #expect(TimeZone(identifier: "America/New_York") != nil)
        #expect(TimeZone(identifier: "America/Los_Angeles") != nil)
    }

    @Test func timeZoneAbbreviationsResolve() {
        #expect(TimeZone(abbreviation: "EST") != nil)
        #expect(TimeZone(abbreviation: "PST") != nil)
    }
}
