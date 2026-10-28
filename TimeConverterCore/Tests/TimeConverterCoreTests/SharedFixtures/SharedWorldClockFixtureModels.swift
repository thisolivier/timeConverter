import Foundation

/// The schema of `fixtures/world-clock-cases.json` (item 30). Same rules as
/// `SharedFixtureModels.swift`: this Swift core writes it, both cores assert
/// it, and any field added here must be added to the Kotlin side too.
struct WorldClockCaseFile: Codable, Equatable {
    var schemaVersion: Int
    var generatedBy: String
    var cases: [WorldClockCase]
}

struct WorldClockCase: Codable, Equatable {
    var id: String
    var note: String?
    /// ISO-8601 instant injected as "now".
    var now: String
    /// IANA identifier injected as the device zone.
    var localZone: String
    /// The slider plus the day stepper, in whole seconds (always a whole
    /// number of minutes).
    var offsetSeconds: Int
    var favourites: [WorldClockFixtureFavourite]
    var expected: ExpectedWorldClock
}

/// A `FavouriteDestination`, spelled out field by field rather than in
/// Swift's synthesized enum coding, so Kotlin can read it plainly.
struct WorldClockFixtureFavourite: Codable, Equatable {
    var timeZoneIdentifier: String
    /// `place` or `code`.
    var labelKind: String
    /// Set for `place`.
    var name: String?
    /// Set for `code`.
    var code: String?
    var expandedName: String?
}

/// `WorldClockDisplay`, field for field.
struct ExpectedWorldClock: Codable, Equatable {
    var readout: String
    var offsetDescription: String?
    var rows: [ExpectedWorldClockRow]
}

struct ExpectedWorldClockRow: Codable, Equatable {
    var isLocal: Bool
    var placeName: String
    var clockDigits: String
    var meridiem: String
    var zoneLine: String
    var offsetPhrase: String
}
