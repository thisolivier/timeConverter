package dev.thisolivier.timeconverter.core.presentation

import dev.thisolivier.timeconverter.core.parsing.RawTextEditing
import dev.thisolivier.timeconverter.core.parsing.RawTextRange
import dev.thisolivier.timeconverter.core.parsing.ZoneSuggestionEngine
import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Items 7 and 9 — chips rewrite the raw sentence. Mirrors Swift `ReplacementChipTests`. */
class ReplacementChipTests {
    private val presenter = ConverterPresenter()
    private val winterMidday = Instant.parse("2026-01-15T12:00:00Z")
    private val losAngeles = ZoneId.of("America/Los_Angeles")

    private fun chips(input: String): List<ReplacementChip> =
        (presenter.displayState(input, winterMidday, losAngeles) as? ConverterDisplayState.Problem)?.problem?.chips.orEmpty()

    @Test
    fun `a chip replaces exactly its span`() {
        val chip = ReplacementChip("Chicago (UTC-6)", "Chicago", RawTextRange(4, 7))
        assertEquals("9am Chicago to IST", chip.applied("9am CST to IST"))
    }

    @Test
    fun `a range that no longer fits leaves the input unchanged`() {
        val chip = ReplacementChip("London?", "London", RawTextRange(4, 30))
        assertEquals("9am Lodnon", chip.applied("9am Lodnon"))
        assertEquals(null, RawTextEditing.substring(RawTextRange(3, 1), "abc"))
    }

    @Test
    fun `ambiguous chips address the typed token, case and spacing as typed`() {
        val input = "  9am   CST  to IST"
        val offered = chips(input)
        assertEquals(listOf("Chicago (UTC-6)", "Shanghai (UTC+8)"), offered.map { it.label })
        assertEquals("CST", RawTextEditing.substring(offered.first().replacementRange, input))
        assertEquals("  9am   Shanghai  to IST", offered.last().applied(input))
    }

    @Test
    fun `did-you-mean chips rewrite the misspelling and then convert`() {
        val input = "9am Lodnon to Paris"
        val offered = chips(input)
        assertEquals(listOf("London?"), offered.map { it.label })
        val rewritten = offered.single().applied(input)
        assertEquals("9am London to Paris", rewritten)
        assertTrue(presenter.displayState(rewritten, winterMidday, losAngeles) is ConverterDisplayState.Converted)
    }

    @Test
    fun `picking both meanings in turn converts`() {
        val afterFirst = chips("9am CST to IST").first().applied("9am CST to IST")
        val afterSecond = chips(afterFirst).first().applied(afterFirst)
        assertEquals("9am Chicago to Kolkata", afterSecond)
        assertTrue(presenter.displayState(afterSecond, winterMidday, losAngeles) is ConverterDisplayState.Converted)
    }

    @Test
    fun `a code-shaped typo is never offered a neighbouring code`() {
        val suggestions = ZoneSuggestionEngine.suggestions("cxt")
        assertTrue(suggestions.none { it.label == "CET" || it.label == "CST" || it.label == "CT" }, "$suggestions")
    }

    @Test
    fun `suggestions are capped at three and nothing is offered for nonsense`() {
        assertTrue(ZoneSuggestionEngine.suggestions("bahi").size <= ZoneSuggestionEngine.MAXIMUM_SUGGESTION_COUNT)
        assertTrue(ZoneSuggestionEngine.suggestions("qqqqqqqq").isEmpty())
        assertTrue(chips("9am in now").isEmpty())
    }
}
