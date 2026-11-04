package dev.thisolivier.timeconverter.core.worldclock

/**
 * How a saved-cities widget lays its cells out (item 36b): the city count
 * chooses the layout, the family chooses what each cell can carry. Port of
 * Swift `WidgetLayoutPlan` — same table, so the two widgets agree cell for
 * cell. Seven or more cities show the first six; five leave the last cell
 * spanning its row; the local clock is not a cell.
 */
data class WidgetLayoutPlan(
    val family: Family,
    val cityCount: Int,
    val columnCount: Int,
    val rowCount: Int,
    val nameStyle: NameStyle,
    val captionStyle: CaptionStyle,
) {
    enum class Family { Small, Medium, Large }
    enum class NameStyle { Full, Code }
    enum class CaptionStyle { Full, Short, None }

    val isHero: Boolean get() = cityCount == 1
    val lastCellSpansRow: Boolean get() = cityCount > 1 && cityCount % columnCount != 0

    fun <Item> rows(items: List<Item>): List<List<Item>> = SavedGridLayout.rows(items.take(cityCount), columnCount)

    companion object {
        const val MAXIMUM_CITIES = 6

        fun plan(family: Family, rawCount: Int): WidgetLayoutPlan {
            val cityCount = rawCount.coerceIn(0, MAXIMUM_CITIES)
            val (columns, names, captions) = when {
                cityCount <= 1 -> Triple(1, NameStyle.Full, CaptionStyle.Full)
                family == Family.Small && cityCount <= 3 -> Triple(1, NameStyle.Code, CaptionStyle.None)
                family == Family.Small -> Triple(2, NameStyle.Code, CaptionStyle.None)
                family == Family.Medium && cityCount <= 3 -> Triple(cityCount, NameStyle.Full, CaptionStyle.Short)
                family == Family.Medium && cityCount == 4 -> Triple(2, NameStyle.Full, CaptionStyle.Short)
                family == Family.Medium -> Triple(3, NameStyle.Full, CaptionStyle.None)
                cityCount <= 3 -> Triple(1, NameStyle.Full, CaptionStyle.Full)
                cityCount == 4 -> Triple(2, NameStyle.Full, CaptionStyle.Full)
                else -> Triple(2, NameStyle.Full, CaptionStyle.Short)
            }
            val rows = if (cityCount == 0) 0 else (cityCount + columns - 1) / columns
            return WidgetLayoutPlan(family, cityCount, columns, rows, names, captions)
        }
    }
}
