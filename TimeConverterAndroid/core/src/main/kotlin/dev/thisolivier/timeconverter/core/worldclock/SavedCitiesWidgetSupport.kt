package dev.thisolivier.timeconverter.core.worldclock

/**
 * The pure part of the saved-cities home-screen widget (item 36). Port of
 * Swift `SavedCitiesWidgetSupport`: the row cap is the same on both platforms
 * so the two widgets show the same list.
 */
object SavedCitiesWidgetSupport {
    /** The widget shows the local row and this many favourites; the rest are in the app. */
    const val MAXIMUM_FAVOURITE_ROWS = 5

    /** Local first, then favourites in stored order, capped. */
    fun rows(display: WorldClockDisplay): List<WorldClockRow> = display.rows.take(1 + MAXIMUM_FAVOURITE_ROWS)
}
