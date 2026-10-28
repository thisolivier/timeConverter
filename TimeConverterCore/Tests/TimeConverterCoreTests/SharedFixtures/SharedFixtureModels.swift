import Foundation

/// The cross-platform fixture schema: one case of `fixtures/conversion-cases.json`
/// at the repository root.
///
/// This Swift core is the **source of truth** — `SharedFixtureTests` writes the
/// file from `SharedFixtureCatalog` when asked to regenerate, and otherwise
/// checks the core still agrees with it. The Android core
/// (`TimeConverterAndroid/core/.../fixtures/ConversionCase.kt`) decodes the same
/// file and asserts against it, which is how two independent parsers are held
/// to one behaviour. Any field added here must be added there.
struct ConversionCaseFile: Codable, Equatable {
    var schemaVersion: Int
    var generatedBy: String
    var cases: [ConversionCase]
}

struct ConversionCase: Codable, Equatable {
    var id: String
    var input: String
    /// ISO-8601 instant injected as "now".
    var now: String
    /// IANA identifier injected as the device zone.
    var localZone: String
    var note: String?
    var expected: ExpectedOutcome
}

struct ExpectedOutcome: Codable, Equatable {
    /// `conversion`, `prompt` or `hint`.
    var kind: String
    var sourceZone: String?
    var targetZone: String?
    /// `HH:mm`, the time as typed, before any DST shift.
    var requestedTime: String?
    var dayOffset: Int?
    var display: ExpectedDisplay?
    var promptId: String?
    var message: String?
    var chips: [ExpectedChip]
}

/// `ConverterDisplay`, field for field.
struct ExpectedDisplay: Codable, Equatable {
    var echoLine: String
    var detailLine: String
    var sourceEchoLine: String
    var sourcePlaceName: String
    var sourceClockDigits: String
    var sourceMeridiem: String
    var sourceZoneLine: String
    var targetPlaceLabel: String
    var targetPlaceName: String
    var targetClockDigits: String
    var targetMeridiem: String
    var targetZoneLine: String
    var footerSentence: String
    var offsetPhrase: String
    var daylightSavingNote: String?
}

struct ExpectedChip: Codable, Equatable {
    var label: String
    var replacementText: String
    var replacementStart: Int
    var replacementEnd: Int
}
