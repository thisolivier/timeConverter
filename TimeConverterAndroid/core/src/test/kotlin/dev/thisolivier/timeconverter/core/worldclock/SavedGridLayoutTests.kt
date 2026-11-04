package dev.thisolivier.timeconverter.core.worldclock

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Item 37 — mirrors Swift `SavedGridLayoutTests`. */
class SavedGridLayoutTests {
    @Test
    fun `columns follow the clock count`() {
        for ((count, expected) in listOf(0 to 1, 1 to 1, 3 to 1, 4 to 2, 8 to 2, 9 to 3, 20 to 3)) {
            assertEquals(expected, SavedGridLayout.columnCount(count), "count $count")
        }
        assertFalse(SavedGridLayout.usesShortOffsetPhrase(8))
        assertTrue(SavedGridLayout.usesShortOffsetPhrase(9))
    }

    @Test
    fun `rows read left to right with a short last row`() {
        assertEquals(listOf(listOf(1, 2, 3), listOf(4, 5, 6), listOf(7, 8, 9), listOf(10)), SavedGridLayout.rows((1..10).toList(), 3))
        assertEquals(emptyList(), SavedGridLayout.rows(emptyList<Int>(), 2))
    }
}
