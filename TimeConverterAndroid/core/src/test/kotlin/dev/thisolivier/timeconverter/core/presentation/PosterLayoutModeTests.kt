package dev.thisolivier.timeconverter.core.presentation

import kotlin.test.Test
import kotlin.test.assertEquals

/** Item 19's truth table. Mirrors Swift `PosterLayoutModeTests`. */
class PosterLayoutModeTests {
    @Test
    fun `only input with the keyboard up collapses`() {
        assertEquals(PosterLayoutMode.Full, PosterLayoutMode.mode(hasInput = false, keyboardIsVisible = false))
        assertEquals(PosterLayoutMode.Full, PosterLayoutMode.mode(hasInput = false, keyboardIsVisible = true))
        assertEquals(PosterLayoutMode.Full, PosterLayoutMode.mode(hasInput = true, keyboardIsVisible = false))
        assertEquals(PosterLayoutMode.Compact, PosterLayoutMode.mode(hasInput = true, keyboardIsVisible = true))
    }

    @Test
    fun `whitespace is not input`() {
        assertEquals(PosterLayoutMode.Full, PosterLayoutMode.mode("   ", keyboardIsVisible = true))
        assertEquals(PosterLayoutMode.Compact, PosterLayoutMode.mode("7pm", keyboardIsVisible = true))
    }

    @Test
    fun `the title block and compact type are opposite faces of the mode`() {
        assertEquals(true, PosterLayoutMode.Full.showsTitleBlock)
        assertEquals(false, PosterLayoutMode.Compact.showsTitleBlock)
        assertEquals(true, PosterLayoutMode.Compact.usesCompactResultType)
    }
}
