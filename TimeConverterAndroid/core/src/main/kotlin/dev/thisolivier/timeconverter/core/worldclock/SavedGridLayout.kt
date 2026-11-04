package dev.thisolivier.timeconverter.core.worldclock

/**
 * How the Saved tab lays its clocks out (item 37): the layout follows the
 * number of clocks, local included — 1 column up to 3, 2 columns for 4–8, 3
 * columns from 9, where the caption is the short offset phrase. Port of Swift
 * `SavedGridLayout`; the views own the sizes, this owns the decision.
 */
object SavedGridLayout {
    fun columnCount(clockCount: Int): Int = when {
        clockCount < 4 -> 1
        clockCount <= 8 -> 2
        else -> 3
    }

    fun usesShortOffsetPhrase(clockCount: Int): Boolean = columnCount(clockCount) == 3

    /** The clocks in reading order, row by row; the last row may be short. */
    fun <Item> rows(items: List<Item>, columnCount: Int): List<List<Item>> =
        if (columnCount <= 0 || items.isEmpty()) emptyList() else items.chunked(columnCount)
}
