package dev.thisolivier.timeconverter.core.parsing

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class TimeTokenParserTests {
    private fun time(input: String): ParsedTime? = TimeTokenParser.matchAtStart(input)?.time

    @Test
    fun `twelve hour forms`() {
        assertEquals(ParsedTime(12, 0), time("12pm et in london"))
        assertEquals(ParsedTime(0, 0), time("12am sydney"))
        assertEquals(ParsedTime(9, 30), time("9:30 am new york in tokyo"))
        assertEquals(ParsedTime(18, 0), time("18pm lisbon to madrid"))
    }

    @Test
    fun `twenty four hour needs a colon`() {
        assertEquals(ParsedTime(14, 30), time("14:30 et in london"))
        assertEquals(ParsedTime(6, 34), time("6:34 uk to lisbon"))
        assertNull(time("1230 et in london"))
        assertNull(time("12"))
        assertNull(time("25:00 et"))
    }

    @Test
    fun `a contradicting meridiem fails rather than retrying as 24 hour`() {
        assertNull(time("13:00 am et in london"))
        assertNull(time("0:30 pm et"))
    }

    @Test
    fun `remainder and its offset are absolute`() {
        val match = TimeTokenParser.matchAtStart("12pm  et in london")!!
        assertEquals("et in london", match.remainder)
        assertEquals(6, match.remainderStartOffset)
    }
}
