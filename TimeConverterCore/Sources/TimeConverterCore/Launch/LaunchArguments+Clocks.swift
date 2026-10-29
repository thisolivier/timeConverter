import Foundation

/// DEBUG-only QA hooks for the favourites and the Clocks tab (items 30–31),
/// the same kind as `-initialInput`: `xcrun simctl` cannot tap, so a headless
/// screenshot of a starred result, the Clocks tab or a shifted slider needs
/// the state handed in at launch. A shipped build ignores all of them.
///
/// - `-favourites "London,ET,Kolkata"` — **replaces** the stored favourites
///   with what starring the target of `12pm in <zone>` would store, for each
///   comma-separated zone, so the labels are exactly a real tap's. Zones that
///   do not convert (unknown, ambiguous) are skipped. Writes through to the
///   store, i.e. to the simulator's real defaults.
/// - `-selectedTab clocks` — open on the Clocks tab.
/// - `-clockOffsetDays 3` / `-clockOffsetMinutes 1140` — start the dial at
///   that offset (the two add up). A negative value needs a leading `m` or a space
///   inside the quotes (`-clockOffsetDays m3`, `-clockOffsetDays " -3"`),
///   because a bare `-3` reads as another flag to the argument parser.
extension LaunchArguments {
    static let favouritesKey = "favourites"
    static let selectedTabKey = "selectedTab"
    static let clockOffsetDaysKey = "clockOffsetDays"
    static let clockOffsetMinutesKey = "clockOffsetMinutes"

    public static var seededFavourites: [FavouriteDestination]? {
        seededFavourites(readingFrom: .standard)
    }

    public static var opensOnClocksTab: Bool {
        opensOnClocksTab(readingFrom: .standard)
    }

    public static var initialClockOffsetDays: Int {
        signedInteger(forKey: clockOffsetDaysKey, readingFrom: .standard)
    }

    public static var initialClockOffsetMinutes: Int {
        signedInteger(forKey: clockOffsetMinutesKey, readingFrom: .standard)
    }

    // MARK: - Injectable for tests

    static func seededFavourites(readingFrom defaults: UserDefaults) -> [FavouriteDestination]? {
        #if DEBUG
        guard let value = defaults.string(forKey: favouritesKey) else { return nil }
        return value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap(FavouriteDestination.resolvingTypedZone)
        #else
        return nil
        #endif
    }

    static func opensOnClocksTab(readingFrom defaults: UserDefaults) -> Bool {
        #if DEBUG
        return defaults.string(forKey: selectedTabKey)?.lowercased() == "clocks"
        #else
        return false
        #endif
    }

    static func signedInteger(forKey key: String, readingFrom defaults: UserDefaults) -> Int {
        #if DEBUG
        guard var text = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespaces)
        else { return 0 }
        if text.hasPrefix("m") { text = "-" + text.dropFirst() }
        return Int(text) ?? 0
        #else
        return 0
        #endif
    }
}
