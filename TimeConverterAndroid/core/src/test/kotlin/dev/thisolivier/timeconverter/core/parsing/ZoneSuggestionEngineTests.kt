package dev.thisolivier.timeconverter.core.parsing

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Item 9's did-you-mean and its editorial policy, over the real chain. Mirrors Swift `ZoneSuggestionEngineTests`. */
class ZoneSuggestionEngineTests {
    private fun suggestedTokens(typo: String) = ZoneSuggestionEngine.suggestions(typo).map { it.token }

    @Test
    fun `bounded edit distance agrees and refuses to report past the limit`() {
        assertEquals(0, EditDistance.levenshtein("london", "london", 2))
        assertEquals(1, EditDistance.levenshtein("londn", "london", 2))
        assertEquals(2, EditDistance.levenshtein("lodnon", "london", 2))
        assertNull(EditDistance.levenshtein("narnia", "london", 2))
        assertNull(EditDistance.levenshtein("a", "abcdef", 2))
        assertEquals(2, EditDistance.levenshtein("", "ab", 2))
    }

    @Test
    fun `the QA list's typos suggest the intended place`() {
        val typos = mapOf(
            "lodnon" to "london", "londn" to "london", "lonndon" to "london", "toyko" to "tokyo",
            "pairs" to "paris", "new yrok" to "new york", "los angelos" to "los angeles",
            "portgual" to "portugal", "newyork" to "new york", "prto" to "porto",
        )
        for ((typo, expected) in typos) assertTrue(expected in suggestedTokens(typo), "$typo suggested ${suggestedTokens(typo)}")
    }

    @Test
    fun `at most three, ordered by distance, never repeated, never the token itself`() {
        for (typo in listOf("lodnon", "londn", "toyko", "portgual", "pairs", "amsterdm", "ukk", "cest", "wst")) {
            val suggestions = ZoneSuggestionEngine.suggestions(typo)
            assertTrue(suggestions.size <= ZoneSuggestionEngine.MAXIMUM_SUGGESTION_COUNT, typo)
            assertEquals(suggestions.map { it.editDistance }.sorted(), suggestions.map { it.editDistance }, typo)
            assertEquals(suggestions.size, suggestions.map { it.token }.toSet().size, typo)
        }
        assertFalse("london" in suggestedTokens("london"))
        assertTrue(suggestedTokens("qqqqqqqqqq").isEmpty())
        assertTrue(suggestedTokens("").isEmpty())
        assertTrue(suggestedTokens("hello").isEmpty())
    }

    @Test
    fun `mutually close zone codes are withheld from code-shaped typos`() {
        for (typo in listOf("cat", "cpt", "cwt", "nst", "mdt", "cxt")) {
            val offeredCodes = ZoneSuggestionEngine.suggestions(typo).filter {
                it.matchSource == ZoneMatchSource.AliasTable || it.matchSource == ZoneMatchSource.FoundationAbbreviation
            }
            assertTrue(offeredCodes.isEmpty(), "$typo offered ${offeredCodes.map { it.token }}")
        }
        assertFalse("cst" in suggestedTokens("cet"))
        assertFalse("cet" in suggestedTokens("cst"))
    }

    @Test
    fun `a code with a single neighbour is still offered, a two-letter typo offers nothing`() {
        assertTrue("pst" in suggestedTokens("psr"))
        assertTrue(suggestedTokens("rt").isEmpty())
    }

    @Test
    fun `short tokens are held to a single edit`() {
        assertTrue("oslo" in suggestedTokens("oslp"))
        assertFalse("oslo" in suggestedTokens("qslp"))
        assertEquals(4, ZoneSuggestionEngine.SHORT_TOKEN_LENGTH_THRESHOLD)
        assertEquals(3, ZoneSuggestionEngine.MAXIMUM_SUGGESTION_COUNT)
    }

    @Test
    fun `every resolver exposes vocabulary and every vocabulary token resolves`() {
        for (resolver in ZoneResolverChain.standard.resolvers) {
            assertTrue(resolver.vocabulary.isNotEmpty(), "${resolver.matchSource} has no vocabulary")
            for (entry in resolver.vocabulary) {
                assertEquals(entry.token.lowercase(), entry.token)
                assertTrue(resolver.candidates(entry.token).isNotEmpty(), "${entry.token} does not resolve")
            }
        }
    }

    @Test
    fun `alias codes are abbreviation-shaped and phrases and places are place-shaped`() {
        val aliasVocabulary = AliasZoneResolver.vocabulary
        assertTrue(aliasVocabulary.filter { ' ' !in it.token }.all { it.shape == ZoneVocabularyEntry.Shape.Abbreviation })
        assertTrue(aliasVocabulary.filter { ' ' in it.token }.all { it.shape == ZoneVocabularyEntry.Shape.PlaceName })
        assertTrue(FoundationAbbreviationZoneResolver.vocabulary.all { it.shape == ZoneVocabularyEntry.Shape.Abbreviation })
        assertTrue(TimeZoneDatabaseCityResolver.vocabulary.all { it.shape == ZoneVocabularyEntry.Shape.PlaceName })
        assertTrue(CountryZoneResolver.vocabulary.all { it.shape == ZoneVocabularyEntry.Shape.PlaceName })
    }

    @Test
    fun `labels are chip-ready, capitalised the way Foundation does`() {
        fun place(token: String) = ZoneVocabularyEntry(token, ZoneVocabularyEntry.Shape.PlaceName, ZoneMatchSource.TimeZoneDatabaseCity).suggestionLabel
        assertEquals("New York", place("new york"))
        assertEquals("Port-Au-Prince", place("port-au-prince"))
        assertEquals("U.S.", place("u.s."))
        assertEquals("St. John's", place("st. john's"))
        assertEquals("PST", ZoneVocabularyEntry("pst", ZoneVocabularyEntry.Shape.Abbreviation, ZoneMatchSource.FoundationAbbreviation).suggestionLabel)
        assertEquals("East Coast", ZoneTokenDisplay.label("east coast"))
        assertEquals("ET", ZoneTokenDisplay.label("et"))
    }
}
