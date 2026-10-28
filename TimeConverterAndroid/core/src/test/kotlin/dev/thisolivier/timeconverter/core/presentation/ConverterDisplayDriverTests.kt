package dev.thisolivier.timeconverter.core.presentation

import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/** Item 8 — the 600 ms prompt debounce, on a fake clock. Mirrors Swift `ConverterDisplayDriverTests`. */
class ConverterDisplayDriverTests {
    private val winterMidday = Instant.parse("2026-01-15T12:00:00Z")
    private val losAngeles = ZoneId.of("America/Los_Angeles")
    private val scheduler = FakePromptScheduler()
    private val observedStates = mutableListOf<ConverterDisplayState>()
    private val driver = ConverterDisplayDriver(scheduler, onDisplayStateChange = { observedStates += it })

    private fun type(input: String) = driver.inputDidChange(input, winterMidday, losAngeles)
    private val problem get() = (driver.displayState as? ConverterDisplayState.Problem)?.problem

    @Test
    fun `the shipped delay is the decided six hundred milliseconds`() {
        assertEquals(600, ConverterDisplayDriver.DEFAULT_PROMPT_DELAY_MILLIS)
    }

    @Test
    fun `a conversion appears on the same keystroke`() {
        type("12pm ET in London")
        assertNotNull(driver.displayState.convertedDisplay)
        assertEquals(0, scheduler.pendingCount)
    }

    @Test
    fun `a single zone sentence converts as soon as it is complete`() {
        type("7pm in London")
        assertEquals(
            "7:00 pm Los Angeles (local, UTC-8) → 3:00 am London (UTC+0) +1d",
            driver.displayState.convertedDisplay?.echoLine,
        )
    }

    @Test
    fun `clearing the field returns to the hint immediately`() {
        type("12pm ET in London")
        type("")
        assertEquals(ConverterDisplayState.Hint, driver.displayState)
    }

    @Test
    fun `a prompt is withheld until the delay elapses`() {
        type("12pm ET in Lond")
        assertEquals(ConverterDisplayState.Hint, driver.displayState)
        scheduler.advanceBy(599)
        assertEquals(ConverterDisplayState.Hint, driver.displayState)
        scheduler.advanceBy(1)
        assertTrue(problem!!.message.startsWith("Don't recognize 'lond'"))
    }

    @Test
    fun `typing through many invalid states shows no prompt along the way`() {
        for (partialInput in listOf("1", "12", "12p", "12pm", "12pm ", "12pm n", "12pm na", "12pm nar")) {
            type(partialInput)
            scheduler.advanceBy(100)
            assertEquals(ConverterDisplayState.Hint, driver.displayState, "'$partialInput' flashed a prompt")
        }
        assertTrue(observedStates.none { it is ConverterDisplayState.Problem })
        scheduler.advanceBy(600)
        assertTrue(problem!!.message.contains("'nar'"))
        assertEquals(1, observedStates.count { it is ConverterDisplayState.Problem })
    }

    @Test
    fun `editing a valid sentence does not leave the old conversion visible`() {
        type("12pm ET in London")
        type("12pm ET in Londonx")
        assertEquals(ConverterDisplayState.Hint, driver.displayState)
    }

    @Test
    fun `a conversion arriving cancels the pending prompt`() {
        type("12pm ET in Londo")
        type("12pm ET in London")
        scheduler.advanceBy(1_000)
        assertNotNull(driver.displayState.convertedDisplay)
    }

    @Test
    fun `submitting shows the prompt at once`() {
        driver.showWithoutWaiting("12pm ET in Lodnon", winterMidday, losAngeles)
        assertTrue(problem!!.chips.isNotEmpty())
    }

    @Test
    fun `a chip tap shows the next prompt without waiting`() {
        driver.showWithoutWaiting("9am CST to IST", winterMidday, losAngeles)
        val chicago = problem!!.chips.first()
        val rewritten = driver.apply(chicago, "9am CST to IST", winterMidday, losAngeles)
        assertEquals("9am Chicago to IST", rewritten)
        assertTrue(problem!!.message.startsWith("'ist' could mean"))
    }

    @Test
    fun `the change notification following a chip tap is ignored`() {
        driver.showWithoutWaiting("9am CST to IST", winterMidday, losAngeles)
        val rewritten = driver.apply(problem!!.chips.first(), "9am CST to IST", winterMidday, losAngeles)
        type(rewritten)
        assertTrue(problem!!.message.startsWith("'ist' could mean"))
    }

    @Test
    fun `typing after a bypass is debounced again`() {
        driver.showWithoutWaiting("12pm ET in Lodnon", winterMidday, losAngeles)
        type("12pm ET in Lodno")
        assertEquals(ConverterDisplayState.Hint, driver.displayState)
        scheduler.advanceBy(600)
        assertNotNull(problem)
    }

    @Test
    fun `a prefilled input renders without waiting`() {
        driver.showWithoutWaiting("9:30 am New York to Lisbon", winterMidday, losAngeles)
        assertEquals(
            "9:30 am New York (UTC-5) → 2:30 pm Lisbon (UTC+0)",
            driver.displayState.convertedDisplay?.echoLine,
        )
    }
}
