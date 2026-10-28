package dev.thisolivier.timeconverter.core.fixtures

import dev.thisolivier.timeconverter.core.parsing.InputParser
import dev.thisolivier.timeconverter.core.presentation.ConverterDisplay
import dev.thisolivier.timeconverter.core.presentation.ConverterPresenter
import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The parser half of the shared contract — every fixture, end to end, from the
 * typed string to the full display or prompt, compared exactly with no
 * wildcards. Renders each case the way Swift `SharedFixtureTests` generated it
 * (presenter for the display and the prompt; parser for the resolved request)
 * and asserts the rendered [ExpectedOutcome] equals the file's.
 */
class SharedFixtureParserTests {
    private val file = SharedFixtures.load()

    @Test
    fun `parser agrees with every fixture end to end`() {
        val failures = file.cases.mapNotNull { case ->
            val actual = render(case)
            if (actual == case.expected) null
            else "${case.id} (${case.input}):\n    expected ${case.expected}\n    actual   $actual"
        }
        assertTrue(
            failures.isEmpty(),
            "Parser disagrees with ${failures.size} of ${file.cases.size} fixture(s):\n" + failures.joinToString("\n"),
        )
    }

    @Test
    fun `every fixture kind is exercised`() {
        val kinds = file.cases.map { it.expected.kind }.toSet()
        assertEquals(setOf("conversion", "prompt", "hint"), kinds)
        assertTrue(file.cases.size >= 43, "fixture file shrank to ${file.cases.size} cases")
    }

    private fun render(case: ConversionCase): ExpectedOutcome {
        val presenter = ConverterPresenter()
        val now = Instant.parse(case.now)
        val localZone = ZoneId.of(case.localZone)
        return when (val evaluation = presenter.evaluate(case.input, now, localZone)) {
            ConverterPresenter.Evaluation.Hint -> ExpectedOutcome(kind = "hint")
            is ConverterPresenter.Evaluation.Converted -> {
                // The display carries no identifiers, so parse once more for the request underneath.
                val result = (InputParser().parseAndConvert(case.input, now, localZone) as InputParser.Outcome.Converted).result
                ExpectedOutcome(
                    kind = "conversion",
                    sourceZone = result.source.timeZoneIdentifier,
                    targetZone = result.target.timeZoneIdentifier,
                    requestedTime = result.requestedTime.canonicalDescription,
                    dayOffset = result.dayOffset,
                    display = expectedDisplay(evaluation.display),
                )
            }
            is ConverterPresenter.Evaluation.Prompted -> {
                val problem = presenter.problem(evaluation.prompt)
                ExpectedOutcome(
                    kind = "prompt",
                    promptId = evaluation.prompt.specIdentifier,
                    message = problem.message,
                    chips = problem.chips.map {
                        ExpectedChip(it.label, it.replacementText, it.replacementRange.startOffset, it.replacementRange.endOffset)
                    },
                )
            }
        }
    }

    private fun expectedDisplay(display: ConverterDisplay) = ExpectedDisplay(
        echoLine = display.echoLine,
        detailLine = display.detailLine,
        sourceEchoLine = display.sourceEchoLine,
        sourcePlaceName = display.sourcePlaceName,
        sourceClockDigits = display.sourceClockDigits,
        sourceMeridiem = display.sourceMeridiem,
        sourceZoneLine = display.sourceZoneLine,
        targetPlaceLabel = display.targetPlaceLabel,
        targetPlaceName = display.targetPlaceName,
        targetClockDigits = display.targetClockDigits,
        targetMeridiem = display.targetMeridiem,
        targetZoneLine = display.targetZoneLine,
        footerSentence = display.footerSentence,
        offsetPhrase = display.offsetPhrase,
        daylightSavingNote = display.daylightSavingNote,
    )
}
