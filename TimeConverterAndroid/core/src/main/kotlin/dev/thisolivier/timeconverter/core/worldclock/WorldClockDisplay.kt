package dev.thisolivier.timeconverter.core.worldclock

/**
 * Everything the Clocks tab draws, pre-rendered. Port of Swift
 * `WorldClockDisplay`: the view holds no logic, it lays these strings out.
 */
data class WorldClockDisplay(
    /** `Today 2:30 PM`, `Tomorrow 9:15 AM`, `Yesterday 11:00 PM`, `Fri 31 Oct, 9:15 AM`. */
    val readout: String,
    /** `+5 h`, `−45 min` (U+2212), `+3 d 2 h`; null at zero, where the clock is live. */
    val offsetDescription: String?,
    /** The local row first, then one per favourite in stored order. */
    val rows: List<WorldClockRow>,
)

/** One clock — the converter's result-band slots, read off the same `ZoneReading`. Port of Swift `WorldClockRow`. */
data class WorldClockRow(
    /** `local` for the first row, the favourite's own id otherwise. */
    val id: String,
    /** `London`, `ET (Eastern Time)`, `Los Angeles (local)` — natural case; the view uppercases. */
    val placeName: String,
    /** `5:00`. */
    val clockDigits: String,
    /** `PM`. */
    val meridiem: String,
    /** Item-21 zone line plus a day marker against the real local today; empty for GMT/UTC with no marker. */
    val zoneLine: String,
    /** `5 hours ahead`, `Same time`; empty on the local row. */
    val offsetPhrase: String,
    /** The favourite this row shows, for delete; null on the local row. */
    val favourite: FavouriteDestination?,
) {
    val isLocal: Boolean get() = favourite == null
}
