package dev.thisolivier.timeconverter.core.presentation

import dev.thisolivier.timeconverter.core.engine.ConversionResult
import dev.thisolivier.timeconverter.core.engine.WallClockResolver
import dev.thisolivier.timeconverter.core.engine.ZoneNames
import dev.thisolivier.timeconverter.core.engine.ZoneReading
import dev.thisolivier.timeconverter.core.parsing.InputParser
import dev.thisolivier.timeconverter.core.parsing.Prompt
import dev.thisolivier.timeconverter.core.parsing.ZoneSuggestionEngine
import java.time.Instant
import java.time.ZoneId

/**
 * Glue between the parser and the view — the only place parse output becomes
 * display values. Pure: `now` and `localZone` are parameters; the activity is
 * the one place that reads the clock. Port of Swift `ConverterPresenter`.
 *
 * The parser is injectable (its resolver chain also feeds the did-you-mean
 * chips), as in Swift; the default is the full port with the standard chain.
 */
class ConverterPresenter(
    private val parser: InputParser = InputParser(),
) {
    /** What an input produces *before* the did-you-mean scan — the driver's cheap first look. */
    sealed interface Evaluation {
        data object Hint : Evaluation
        data class Converted(val display: ConverterDisplay) : Evaluation
        data class Prompted(val prompt: Prompt) : Evaluation
    }

    fun evaluate(rawInput: String, now: Instant, localZone: ZoneId): Evaluation {
        // Empty input stays quiet rather than scolding with P1 before anything is typed.
        if (rawInput.isBlank()) return Evaluation.Hint
        return when (val outcome = parser.parseAndConvert(rawInput, now, localZone)) {
            is InputParser.Outcome.Converted -> Evaluation.Converted(display(outcome.result))
            is InputParser.Outcome.Prompted -> Evaluation.Prompted(outcome.prompt)
        }
    }

    fun displayState(evaluation: Evaluation): ConverterDisplayState = when (evaluation) {
        Evaluation.Hint -> ConverterDisplayState.Hint
        is Evaluation.Converted -> ConverterDisplayState.Converted(evaluation.display)
        is Evaluation.Prompted -> ConverterDisplayState.Problem(problem(evaluation.prompt))
    }

    fun displayState(rawInput: String, now: Instant, localZone: ZoneId): ConverterDisplayState =
        displayState(evaluate(rawInput, now, localZone))

    // Prompts

    fun problem(prompt: Prompt): ConverterProblem = ConverterProblem(problemLine(prompt), chips(prompt))

    fun chips(prompt: Prompt): List<ReplacementChip> = when (prompt) {
        is Prompt.AmbiguousZone -> prompt.choices.map { choice ->
            ReplacementChip(
                label = "${choice.representativeCity} (${choice.utcOffsetDescription})",
                replacementText = choice.representativeCity,
                replacementRange = prompt.tokenRange,
            )
        }
        // Never auto-accepted, not even a unique distance-1 match — the tap is the point.
        is Prompt.UnknownZone -> ZoneSuggestionEngine.suggestions(prompt.token, parser.zoneResolverChain).map { suggestion ->
            ReplacementChip("${suggestion.label}?", suggestion.label, prompt.tokenRange)
        }
        is Prompt.TimeNotFound, is Prompt.ZoneNotFound -> emptyList()
    }

    companion object {
        /** P4 also lists its candidates inline, as the Swift copy does. */
        fun problemLine(prompt: Prompt): String {
            if (prompt !is Prompt.AmbiguousZone || prompt.choices.isEmpty()) return prompt.message
            val candidateList = prompt.choices.joinToString(", ") { "${it.representativeCity} (${it.utcOffsetDescription})" }
            return "${prompt.message}: $candidateList"
        }

        fun display(result: ConversionResult): ConverterDisplay {
            val note = daylightSavingNote(result)
            val detailLine = "${result.source.timeZoneIdentifier} → ${result.target.timeZoneIdentifier}" +
                (note?.let { " · $it" } ?: "")
            return ConverterDisplay(
                echoLine = result.summary,
                detailLine = detailLine,
                sourceEchoLine = sourceEchoLine(result),
                sourcePlaceName = result.source.placeNameDescription,
                sourceClockDigits = result.source.clockDigits,
                sourceMeridiem = result.source.uppercasedMeridiem,
                sourceZoneLine = zoneDetail(result.source),
                targetPlaceLabel = result.target.headerDescription,
                targetPlaceName = result.target.placeNameDescription,
                targetClockDigits = result.target.clockDigits,
                targetMeridiem = result.target.uppercasedMeridiem,
                targetZoneLine = targetZoneLine(result),
                footerSentence = result.relativeOffsetSentence,
                offsetPhrase = result.relativeOffsetPhrase,
                daylightSavingNote = note,
            )
        }

        /** `Lisbon · 8:00 PM` — no UTC offset since item 21. */
        fun sourceEchoLine(result: ConversionResult): String =
            "${result.source.placeDescription} · ${result.source.uppercasedTime}"

        /** The zone name and cities, with the rollover note riding along — `next day` must never be lost. */
        fun targetZoneLine(result: ConversionResult): String {
            val zoneDetail = zoneDetail(result.target)
            val rollover = result.dayRolloverNote ?: return zoneDetail
            return if (zoneDetail.isEmpty()) rollover else "$zoneDetail · $rollover"
        }

        /** Names the plain city, even when the echo expanded an abbreviation. */
        fun daylightSavingNote(result: ConversionResult): String? {
            val requestedTime = result.requestedTime.twelveHourDescription
            val city = result.source.cityName
            return when (result.wallClockDisposition) {
                WallClockResolver.Disposition.Unambiguous -> null
                WallClockResolver.Disposition.NonexistentTimeShiftedForward ->
                    "$requestedTime doesn't exist today in $city — clocks went forward"
                WallClockResolver.Disposition.RepeatedTimeTookEarlier ->
                    "$requestedTime happens twice today in $city — showing the first"
            }
        }

        /** The iOS-origin zone name plus representative cities, or an abbreviation's own cities. */
        private fun zoneDetail(reading: ZoneReading): String = ZoneNames.zoneDetailLine(reading)
    }
}
