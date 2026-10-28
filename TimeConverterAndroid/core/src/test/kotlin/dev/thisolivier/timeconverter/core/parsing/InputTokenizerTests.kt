package dev.thisolivier.timeconverter.core.parsing

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull

/** Normalisation, the first-standalone-conjunction split and raw ranges. Mirrors Swift `InputTokenizerTests` + `RawTextRangeTests`. */
class InputTokenizerTests {
    private fun tokens(input: String) = assertIs<InputTokenizer.Result.Tokenized>(InputTokenizer.tokenize(input), input).tokens

    private fun substring(range: RawTextRange?, input: String) = range?.let { RawTextEditing.substring(it, input) }

    @Test
    fun `normalization trims, collapses and lowercases`() {
        assertEquals("12pm et in london", InputTokenizer.normalize("  12PM   ET   IN   LONDON  "))
        assertEquals("9:30 am new york to lisbon", InputTokenizer.normalize("9:30 AM\tNew  York\nto Lisbon"))
        assertEquals("7pm in paris", InputTokenizer.normalize("7pm in Paris"))
    }

    @Test
    fun `the conjunction splits the zone tokens`() {
        val expectations = listOf(
            SplitRow("12pm ET in London", "et", Conjunction.In, "london"),
            SplitRow("23:15 UK to Porto", "uk", Conjunction.To, "porto"),
            SplitRow("9:30 am New York to Lisbon", "new york", Conjunction.To, "lisbon"),
            SplitRow("06:34 Portugal in PST", "portugal", Conjunction.In, "pst"),
            SplitRow("9am new york to south africa", "new york", Conjunction.To, "south africa"),
        )
        for (row in expectations) {
            val tokenized = tokens(row.input)
            assertEquals(row.source, tokenized.sourceZoneToken, row.input)
            assertEquals(row.conjunction, tokenized.conjunction, row.input)
            assertEquals(row.target, tokenized.targetZoneToken, row.input)
        }
    }

    private data class SplitRow(val input: String, val source: String, val conjunction: Conjunction, val target: String)

    @Test
    fun `only the first standalone conjunction splits, and never inside a word`() {
        assertEquals("porto", tokens("23:15 uk to porto").targetZoneToken)
        val tokenized = tokens("12pm et in london in paris")
        assertEquals("et", tokenized.sourceZoneToken)
        assertEquals("london in paris", tokenized.targetZoneToken)
    }

    @Test
    fun `one named side leaves the other empty, decided by the conjunction`() {
        val target = tokens("7pm in London")
        assertNull(target.sourceZone)
        assertEquals("london", target.targetZoneToken)
        val source = tokens("7pm east coast")
        assertEquals("east coast", source.sourceZoneToken)
        assertNull(source.targetZone)
        assertEquals("tokyo", tokens("7pm tokyo in").sourceZoneToken)
    }

    @Test
    fun `a bare zone is one target token with no time`() {
        for (input in listOf("east coast", "East Coast", "EAST COAST", "  east   coast  ")) {
            val tokenized = tokens(input)
            assertNull(tokenized.time)
            assertNull(tokenized.sourceZone)
            assertEquals("east coast", tokenized.targetZoneToken)
            assertEquals(input.trim(), substring(tokenized.targetZone?.rawRange, input))
        }
    }

    @Test
    fun `bare-zone rejections are structural and become P1`() {
        for (input in listOf("12", "12345", "06", "13:00 am", "!!!", "london to paris", "25:00 london")) {
            assertIs<Prompt.TimeNotFound>(assertIs<InputTokenizer.Result.Prompted>(InputTokenizer.tokenize(input), input).prompt)
        }
    }

    @Test
    fun `a leading now is a time with no value, and only a leading now`() {
        val now = tokens("now in Bangkok")
        assertNull(now.time)
        assertEquals("bangkok", now.targetZoneToken)
        assertEquals("nowhere", tokens("nowhere").targetZoneToken)
        assertEquals("now", tokens("9am in now").targetZoneToken)
        val bareNow = assertIs<InputTokenizer.Result.Prompted>(InputTokenizer.tokenize("now")).prompt
        assertEquals(Prompt.ZoneNotFound(null), bareNow)
    }

    @Test
    fun `zone ranges address the raw characters the user typed`() {
        val expectations = listOf(
            Triple("12PM CST IN LONDON", "CST", "LONDON"),
            Triple("   12pm    CST    in    London  ", "CST", "London"),
            Triple("9am  New   York  to  Narnia", "New   York", "Narnia"),
        )
        for ((input, source, target) in expectations) {
            val tokenized = tokens(input)
            assertEquals(source, substring(tokenized.sourceZone?.rawRange, input), input)
            assertEquals(target, substring(tokenized.targetZone?.rawRange, input), input)
        }
    }

    @Test
    fun `identical tokens on both sides get distinct ranges`() {
        val tokenized = tokens("9am CST to CST")
        assertEquals(RawTextRange(4, 7), tokenized.sourceZone?.rawRange)
        assertEquals(RawTextRange(11, 14), tokenized.targetZone?.rawRange)
    }

    /** UTF-16 offsets on this side: a flag is four units, and the range covers all of them. */
    @Test
    fun `astral characters are never split`() {
        val input = "9am 🇬🇧 to Narnia"
        val tokenized = tokens(input)
        assertEquals(RawTextRange(4, 8), tokenized.sourceZone?.rawRange)
        assertEquals("9am UK to Narnia", RawTextEditing.replacing(tokenized.sourceZone!!.rawRange, "UK", input))
        assertEquals("Narnia", substring(tokenized.targetZone?.rawRange, input))
    }
}
