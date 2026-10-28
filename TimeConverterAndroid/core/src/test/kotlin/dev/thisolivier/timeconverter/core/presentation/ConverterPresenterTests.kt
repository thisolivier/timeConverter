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
 * The presenter against the shared fixtures, for the cases the INTERIM parser
 * can express. Every `ConverterDisplay` slot is compared, the two zone lines
 * with their leading OS-supplied name wildcarded (fixtures/readme.md). When
 * the parser port lands, `SharedFixtureParserTests` takes over all cases.
 */
class ConverterPresenterTests {
    private val presenter = ConverterPresenter()
    private val casesById = SharedFixtures.load().cases.associateBy { it.id }

    private val conversionCasesTheInterimParserCovers = listOf(
        "spec-example-winter", "spec-example-summer", "twenty-four-hour", "single-digit-hour",
        "midnight-gmt-to-tokyo", "spaced-meridiem-multiword-cities", "previous-day-rollover",
        "all-lowercase", "redundant-agreeing-meridiem", "half-hour-offset", "three-quarter-hour-offset",
        "default-source-to-local", "default-with-tokyo-device", "dst-spring-forward-gap", "dst-fall-back-overlap",
    )

    private val promptCasesTheInterimParserCovers = listOf(
        "p1-digits-only", "p1-contradicting-meridiem", "p1-two-places-no-time", "p2-time-only",
        "p2-dangling-conjunction", "p4-ambiguous-abbreviation", "p5-typo-with-suggestions",
        "p5-now-as-destination", "hint-empty", "hint-whitespace",
    )

    private fun state(case: ConversionCase) =
        presenter.displayState(case.input, Instant.parse(case.now), ZoneId.of(case.localZone))

    @Test
    fun `every slot matches the conversion fixtures the interim parser covers`() {
        val failures = conversionCasesTheInterimParserCovers.mapNotNull { id ->
            val case = casesById.getValue(id)
            val display = state(case).convertedDisplay ?: return@mapNotNull "$id: not converted (${state(case)})"
            mismatches(case.expected.display!!, display).takeIf { it.isNotEmpty() }
                ?.let { "$id (${case.input}):\n    " + it.joinToString("\n    ") }
        }
        assertTrue(failures.isEmpty(), failures.joinToString("\n"))
    }

    @Test
    fun `prompt copy and chips match the prompt fixtures the interim parser covers`() {
        val failures = promptCasesTheInterimParserCovers.mapNotNull { id ->
            val case = casesById.getValue(id)
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
        assertTrue(display.targetZoneLine.endsWith(" (Los Angeles) · previous day"), display.targetZoneLine)
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
        compare("sourceZoneLine", neutral(expected.sourceZoneLine), neutral(actual.sourceZoneLine)),
        compare("targetPlaceLabel", expected.targetPlaceLabel, actual.targetPlaceLabel),
        compare("targetPlaceName", expected.targetPlaceName, actual.targetPlaceName),
        compare("targetClockDigits", expected.targetClockDigits, actual.targetClockDigits),
        compare("targetMeridiem", expected.targetMeridiem, actual.targetMeridiem),
        compare("targetZoneLine", neutral(expected.targetZoneLine), neutral(actual.targetZoneLine)),
        compare("footerSentence", expected.footerSentence, actual.footerSentence),
        compare("offsetPhrase", expected.offsetPhrase, actual.offsetPhrase),
        compare("daylightSavingNote", expected.daylightSavingNote.toString(), actual.daylightSavingNote.toString()),
    )

    /**
     * `Japan Standard Time (Tokyo) · next day` → `* · next day`. The leading
     * name is ICU's (fixtures/readme.md), and the parenthesised city list on a
     * place-labelled side comes from Swift's `ZoneRepresentativeCities`, which
     * arrives with the shared name table — until then `ZoneNames` names the
     * zone's own city only. Abbreviation-side lines (`New York, Toronto`) have
     * no parenthesis and stay exact; the rollover note always stays exact.
     */
    private fun neutral(zoneLine: String): String {
        val parenthesisIndex = zoneLine.indexOf(" (")
        if (parenthesisIndex < 0) return zoneLine
        return "*" + zoneLine.substring(zoneLine.indexOf(')', parenthesisIndex) + 1)
    }

    private fun compare(field: String, expected: String, actual: String): String? =
        if (expected == actual) null else "$field: expected `$expected`, got `$actual`"
}
