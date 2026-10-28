import Foundation

/// Everything the Clocks tab draws, pre-rendered (item 30). Like
/// `ConverterDisplay`, the view holds no logic: it lays these strings out.
public struct WorldClockDisplay: Equatable, Sendable {
    /// The shifted local time and its day, above the slider:
    /// `Today 2:30 PM`, `Tomorrow 9:15 AM`, `Yesterday 11:00 PM`, and beyond
    /// one day `Fri 31 Oct, 9:15 AM`.
    public let readout: String
    /// The signed offset once non-zero — `+5 h`, `−45 min`, `+3 d 2 h` (a true
    /// minus sign) — and `nil` at zero, where the clock is simply live.
    public let offsetDescription: String?
    /// The local row first, then one per favourite in stored order.
    public let rows: [WorldClockRow]
}

/// One clock. The same slots the converter's result band has, read off the
/// same `ZoneReading`, so a favourite reads here exactly as it did there.
public struct WorldClockRow: Equatable, Sendable, Identifiable {
    /// `local` for the first row, the favourite's own id otherwise.
    public let id: String
    /// `London`, `ET (Eastern Time)`, `Los Angeles (local)` — natural case;
    /// uppercasing is the view's job.
    public let placeName: String
    /// `5:00`.
    public let clockDigits: String
    /// `PM`.
    public let meridiem: String
    /// Item-21 zone line plus a day marker when this row's date differs from
    /// the local row's: `Japan Standard Time (Tokyo) · next day`. Empty for
    /// GMT/UTC with no marker, as on the result band.
    public let zoneLine: String
    /// `5 hours ahead`, `Same time`, against the local zone at the shown
    /// instant. Empty on the local row, which has nothing to be relative to.
    public let offsetPhrase: String
    /// The favourite this row shows, for swipe-to-delete; `nil` on the local row.
    public let favourite: FavouriteDestination?

    public var isLocal: Bool { favourite == nil }
}
