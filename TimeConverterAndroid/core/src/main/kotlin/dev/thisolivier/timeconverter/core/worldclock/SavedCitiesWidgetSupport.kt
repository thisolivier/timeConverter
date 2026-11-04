package dev.thisolivier.timeconverter.core.worldclock

/**
 * The pure part of the saved-cities home-screen widget (item 36). Port of
 * Swift `SavedCitiesWidgetSupport`: the row cap is the same on both platforms
 * so the two widgets show the same list.
 */
object SavedCitiesWidgetSupport {
    /** The saved places in stored order, at most `WidgetLayoutPlan.MAXIMUM_CITIES`; the local clock is left out (the home screen has one). */
    fun cities(display: WorldClockDisplay): List<WorldClockRow> = display.rows.filter { !it.isLocal }.take(WidgetLayoutPlan.MAXIMUM_CITIES)
}
