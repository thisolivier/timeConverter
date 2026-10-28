package dev.thisolivier.timeconverter.core.presentation

import dev.thisolivier.timeconverter.core.fixtures.ConversionCase
import dev.thisolivier.timeconverter.core.fixtures.ExpectedDisplay
import dev.thisolivier.timeconverter.core.fixtures.SharedFixtures
import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The presenter against the shared fixtures with the real parser: every
 * `ConverterDisplay` slot of every conversion, and the copy and chips of every
 * prompt, compared exactly (zone lines included — the names come from the
 * iOS-origin snapshot and the cities from `ZoneRepresentativeCities`).
 */
class ConverterPresenterTests {
    private val presenter = ConverterPresenter()
    private val cases = SharedFixtures.load().cases

    private fun state(case: ConversionCase) =
        presenter.displayState(case.input, Instant.parse(case.now), ZoneId.of(case.localZone))

    @Test
    fun `every slot matches every conversion fixture`() {
        val failures = cases.filter { it.expected.kind == "conversion" }.mapNotNull { case ->
            val id = case.id
            val display = state(case).convertedDisplay ?: return@mapNotNull "$id: not converted (${state(case)})"
            mismatches(case.expected.display!!, display).takeIf { it.isNotEmpty() }
                ?.let { "$id (${case.input}):\n    " + it.joinToString("\n    ") }
        }
        assertTrue(failures.isEmpty(), failures.joinToString("\n"))
    }

    @Test
    fun `prompt copy and chips match every prompt and hint fixture`() {
        val failures = cases.filter { it.expected.kind != "conversion" }.mapNotNull { case ->
            val id = case.id
            val actual = state(case)
            val expected = case.expected
            val ok = when (expected.kind) {
                "hint" -> actual == ConverterDisplayState.Hint
                else -> actual is ConverterDisplayState.Problem &&
                    actual.problem.message == expected.message &&
                    actual.problem.chips.map { listOf(it.label, it.replacementText, it.replacementRange.startOffset, it.replacementRange.endOffset) } ==
                    expected.chips.map { listOf(it.label, it.replacementText, it.replacementStart, it.replacementEnd) }
            }
            if (ok) null else "$id (${case.input}): expected ${expected.message} ${expected.chips}, got $actual"
        }
        assertTrue(failures.isEmpty(), failures.joinToString("\n"))
    }

    @Test
    fun `the rollover note rides the target zone line`() {
        val display = presenter.displayState("12am Sydney to Los Angeles", Instant.parse("2026-01-15T12:00:00Z"), ZoneId.of("UTC"))
            .convertedDisplay!!
        assertEquals("Pacific Time (Los Angeles, Vancouver) · previous day", display.targetZoneLine)
    }

    @Test
    fun `gmt has an empty zone line and no rollover`() {
        val display = presenter.displayState("1pm Tokyo in GMT", Instant.parse("2026-01-15T12:00:00Z"), ZoneId.of("UTC"))
            .convertedDisplay!!
        assertEquals("", display.targetZoneLine)
        assertEquals("In GMT (Greenwich Mean Time)", display.targetPlaceLabel)
    }

    private fun mismatches(expected: ExpectedDisplay, actual: ConverterDisplay): List<String> = listOfNotNull(
        compare("echoLine", expected.echoLine, actual.echoLine),
        compare("detailLine", expected.detailLine, actual.detailLine),
        compare("sourceEchoLine", expected.sourceEchoLine, actual.sourceEchoLine),
        compare("sourcePlaceName", expected.sourcePlaceName, actual.sourcePlaceName),
        compare("sourceClockDigits", expected.sourceClockDigits, actual.sourceClockDigits),
        compare("sourceMeridiem", expected.sourceMeridiem, actual.sourceMeridiem),
        compare("sourceZoneLine", expected.sourceZoneLine, actual.sourceZoneLine),
        compare("targetPlaceLabel", expected.targetPlaceLabel, actual.targetPlaceLabel),
        compare("targetPlaceName", expected.targetPlaceName, actual.targetPlaceName),
        compare("targetClockDigits", expected.targetClockDigits, actual.targetClockDigits),
        compare("targetMeridiem", expected.targetMeridiem, actual.targetMeridiem),
        compare("targetZoneLine", expected.targetZoneLine, actual.targetZoneLine),
        compare("footerSentence", expected.footerSentence, actual.footerSentence),
        compare("offsetPhrase", expected.offsetPhrase, actual.offsetPhrase),
        compare("daylightSavingNote", expected.daylightSavingNote.toString(), actual.daylightSavingNote.toString()),
    )

    private fun compare(field: String, expected: String, actual: String): String? =
        if (expected == actual) null else "$field: expected `$expected`, got `$actual`"
}
