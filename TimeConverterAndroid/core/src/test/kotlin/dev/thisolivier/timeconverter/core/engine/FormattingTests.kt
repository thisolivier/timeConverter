package dev.thisolivier.timeconverter.core.engine

import kotlin.test.Test
import kotlin.test.assertEquals

class FormattingTests {
    @Test
    fun `twelve hour description`() {
        assertEquals("12:00 am", TimeFormatting.twelveHourDescription(0, 0))
        assertEquals("12:00 pm", TimeFormatting.twelveHourDescription(12, 0))
        assertEquals("5:07 pm", TimeFormatting.twelveHourDescription(17, 7))
    }

    @Test
    fun `utc offsets`() {
        assertEquals("UTC+0", UtcOffsetFormatting.description(0))
        assertEquals("UTC-5", UtcOffsetFormatting.description(-5 * 3600))
        assertEquals("UTC+5:30", UtcOffsetFormatting.description(5 * 3600 + 1800))
        assertEquals("UTC+5:45", UtcOffsetFormatting.description(5 * 3600 + 2700))
    }

    @Test
    fun `relative offset sentence and phrase`() {
        assertEquals("São Paulo is 4 hours behind Lisbon.", RelativeOffsetFormatting.sentence(-4 * 3600, "São Paulo", "Lisbon"))
        assertEquals("London is 1 hour ahead of Lisbon.", RelativeOffsetFormatting.sentence(3600, "London", "Lisbon"))
        assertEquals("Madrid is the same time as Paris.", RelativeOffsetFormatting.sentence(0, "Madrid", "Paris"))
        assertEquals("Same time as Paris.", RelativeOffsetFormatting.sentence(0, "Paris", "Paris"))
        assertEquals("5.75 hours ahead", RelativeOffsetFormatting.phrase(5 * 3600 + 2700))
        assertEquals("4.5 hours behind", RelativeOffsetFormatting.phrase(-(4 * 3600 + 1800)))
        assertEquals("Same time", RelativeOffsetFormatting.phrase(0))
    }
}
