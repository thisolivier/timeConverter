package dev.thisolivier.timeconverter.core.fixtures

import dev.thisolivier.timeconverter.core.engine.ConversionEngine
import dev.thisolivier.timeconverter.core.engine.ConversionRequest
import dev.thisolivier.timeconverter.core.engine.ResolvedZone
import dev.thisolivier.timeconverter.core.parsing.ParsedTime
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The engine half of the shared contract.
 *
 * The parser is not ported yet, so these start from the fixture's *resolved*
 * request (zones + requested time + now) and check the zone arithmetic: the
 * poster digits, meridiems, day rollover and the name-free offset phrase.
 * Everything that depends on how a token resolved (echo lines, zone names,
 * `(local)` markers) is asserted by `SharedFixtureParserTests` once the parser
 * exists. Together the two suites cover every field in the file.
 */
class SharedFixtureEngineTests {
    private val file = SharedFixtures.load()
    private val conversions = file.cases.filter { it.expected.kind == "conversion" }

    @Test
    fun `fixture file loads and has conversions, prompts and hints`() {
        assertEquals(1, file.schemaVersion)
        assertTrue(conversions.isNotEmpty())
        assertTrue(file.cases.any { it.expected.kind == "prompt" })
        assertTrue(file.cases.any { it.expected.kind == "hint" })
    }

    @Test
    fun `engine agrees with every conversion fixture`() {
        val failures = conversions.mapNotNull { case ->
            val expected = case.expected
            val display = expected.display!!
            val result = ConversionEngine.convert(
                ConversionRequest(
                    time = ParsedTime.fromCanonical(expected.requestedTime!!)!!,
                    sourceZone = ResolvedZone.place(expected.sourceZone!!),
                    targetZone = ResolvedZone.place(expected.targetZone!!),
                    referenceInstant = Instant.parse(case.now),
                )
            )
            val mismatches = listOfNotNull(
                mismatch("sourceClockDigits", display.sourceClockDigits, result.source.clockDigits),
                mismatch("sourceMeridiem", display.sourceMeridiem, result.source.uppercasedMeridiem),
                mismatch("targetClockDigits", display.targetClockDigits, result.target.clockDigits),
                mismatch("targetMeridiem", display.targetMeridiem, result.target.uppercasedMeridiem),
                mismatch("dayOffset", expected.dayOffset.toString(), result.dayOffset.toString()),
                mismatch("offsetPhrase", display.offsetPhrase, result.relativeOffsetPhrase),
                mismatch("rollover note", display.targetZoneLine.substringAfter(" · ", ""), result.dayRolloverNote ?: ""),
            )
            if (mismatches.isEmpty()) null else "${case.id} (${case.input}):\n    " + mismatches.joinToString("\n    ")
        }
        assertTrue(failures.isEmpty(), "Engine disagrees with ${failures.size} fixture(s):\n" + failures.joinToString("\n"))
    }

    private fun mismatch(field: String, expected: String, actual: String): String? =
        if (expected == actual) null else "$field: expected `$expected`, got `$actual`"
}
