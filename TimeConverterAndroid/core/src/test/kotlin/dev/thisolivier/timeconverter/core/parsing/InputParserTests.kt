package dev.thisolivier.timeconverter.core.parsing

import dev.thisolivier.timeconverter.core.engine.ConversionRequest
import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Prompts, local defaulting, bare zones and `now`. Mirrors the shape of Swift
 * `PromptTests`, `LocalZoneDefaultingTests`, `BareZoneInputTests` and `NowKeywordTests`.
 */
class InputParserTests {
    private val parser = InputParser()
    private val winterAfternoon = Instant.parse("2026-01-15T15:42:00Z")
    private val losAngeles = ZoneId.of("America/Los_Angeles")

    private fun prompt(input: String): Prompt =
        assertIs<ParseOutcome.Prompted>(parser.parse(input, winterAfternoon, losAngeles), input).prompt

    private fun request(input: String, localZone: ZoneId = losAngeles): ConversionRequest =
        assertIs<ParseOutcome.Request>(parser.parse(input, winterAfternoon, localZone), input).request

    @Test
    fun `each prompt carries the spec's id and copy`() {
        assertEquals("P1", prompt("12").specIdentifier)
        assertEquals("Couldn't find a time — start with e.g. 14:30 or 2:30 pm", prompt("12").message)
        assertEquals("Convert 7:00 pm where? Add a timezone, city, or country", prompt("7pm in").message)
        assertEquals("Convert now where? Add a timezone, city, or country", prompt("now in").message)
        assertEquals("'usa' could mean more than one place — pick one", prompt("9am in USA").message)
        assertEquals("Don't recognize 'narnia' — try a timezone (ET, PST), a major city, or a country", prompt("9am ET in Narnia").message)
    }

    @Test
    fun `P4 and P5 carry their side and the raw range of the offending token`() {
        val ambiguous = assertIs<Prompt.AmbiguousZone>(prompt("9am CST in London"))
        assertEquals(ZoneSide.Source, ambiguous.side)
        assertEquals(RawTextRange(4, 7), ambiguous.offendingTokenRange)
        val unknown = assertIs<Prompt.UnknownZone>(prompt("9am ET in Lodnon"))
        assertEquals(ZoneSide.Target, unknown.side)
        assertEquals(RawTextRange(10, 16), unknown.offendingTokenRange)
        for (input in listOf("12", "3pm", "3pm in")) assertNull(prompt(input).offendingTokenRange, input)
    }

    @Test
    fun `the first bad token is asked about first`() {
        assertEquals("cst", assertIs<Prompt.AmbiguousZone>(prompt("9am CST to Narnia")).token)
        assertEquals("narnia", assertIs<Prompt.UnknownZone>(prompt("9am Narnia to CST")).token)
    }

    @Test
    fun `P4 choices are the plain cities with offsets at the injected instant`() {
        val usa = assertIs<Prompt.AmbiguousZone>(prompt("9am in USA"))
        assertEquals(
            listOf("New York (UTC-5)", "Chicago (UTC-6)", "Denver (UTC-7)", "Los Angeles (UTC-8)", "Anchorage (UTC-9)", "Honolulu (UTC-10)"),
            usa.choices.map { "${it.representativeCity} (${it.utcOffsetDescription})" },
        )
        val summer = parser.parse("9am CST in London", Instant.parse("2026-07-15T12:00:00Z"), losAngeles)
        val summerChoices = assertIs<Prompt.AmbiguousZone>(assertIs<ParseOutcome.Prompted>(summer).prompt).choices
        assertEquals(listOf("UTC-5", "UTC+8"), summerChoices.map { it.utcOffsetDescription })
    }

    @Test
    fun `an unnamed side is the injected device zone, marked as such`() {
        val toLondon = request("7pm in London", ZoneId.of("Asia/Tokyo"))
        assertEquals("Asia/Tokyo", toLondon.sourceZone.zone.id)
        assertEquals(ZoneMatchSource.DeviceLocalZone, toLondon.sourceZone.matchSource)
        assertTrue(toLondon.sourceZone.isDeviceLocalZone)
        val fromEastCoast = request("7pm East Coast")
        assertEquals("America/New_York", fromEastCoast.sourceZone.zone.id)
        assertEquals("America/Los_Angeles", fromEastCoast.targetZone.zone.id)
        assertTrue(fromEastCoast.targetZone.isDeviceLocalZone)
    }

    @Test
    fun `typing your own zone is not marked local`() {
        assertEquals(false, request("7pm Los Angeles in London").sourceZone.isDeviceLocalZone)
    }

    @Test
    fun `a bare zone converts the current device clock, minutes included`() {
        for ((input, identifier) in listOf("ET" to "America/New_York", "japan" to "Asia/Tokyo", "Porto" to "Europe/Lisbon", "PST" to "America/Los_Angeles")) {
            val bare = request(input)
            assertEquals(ParsedTime(7, 42), bare.time, input)
            assertTrue(bare.sourceZone.isDeviceLocalZone, input)
            assertEquals(identifier, bare.targetZone.zone.id, input)
        }
    }

    @Test
    fun `now reads the clock in the resolved source zone`() {
        assertEquals(ParsedTime(7, 42), request("now in Bangkok").time)
        val named = request("now ET in London")
        assertEquals(ParsedTime(10, 42), named.time)
        assertEquals("America/New_York", named.sourceZone.zone.id)
        assertEquals("Don't recognize 'now' — try a timezone (ET, PST), a major city, or a country", prompt("9am in now").message)
    }

    @Test
    fun `antarctica prompts with its stations and a station resolves by name`() {
        val stations = assertIs<Prompt.AmbiguousZone>(prompt("3pm in Antarctica")).choices.map { it.representativeCity }
        assertEquals(listOf("McMurdo", "Macquarie", "Casey", "Davis", "Mawson", "Syowa", "Troll", "Rothera"), stations)
        assertEquals("Antarctica/Troll", request("3pm in troll").targetZone.zone.id)
    }

    @Test
    fun `a full conversion renders through parseAndConvert`() {
        val outcome = assertIs<InputParser.Outcome.Converted>(parser.parseAndConvert("12pm ET in London", winterAfternoon, losAngeles))
        assertEquals("12:00 pm Eastern Time (New York, Toronto, UTC-5) → 5:00 pm London (UTC+0)", outcome.result.summary)
    }
}
