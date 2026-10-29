package dev.thisolivier.timeconverter.core.presentation

import dev.thisolivier.timeconverter.core.parsing.RawTextEditing
import dev.thisolivier.timeconverter.core.parsing.RawTextRange
import dev.thisolivier.timeconverter.core.worldclock.FavouriteDestination

/**
 * The three things the UI can be showing. Port of Swift `ConverterDisplayState`.
 * The view is a `when` over this and nothing else.
 */
sealed interface ConverterDisplayState {
    /** Nothing typed yet, or a prompt still held back by the debounce. */
    data object Hint : ConverterDisplayState
    data class Converted(val display: ConverterDisplay) : ConverterDisplayState
    /** P1, P2, P4 or P5: the spec's message plus any chips. */
    data class Problem(val problem: ConverterProblem) : ConverterDisplayState

    /** The conversion, when there is one — the input box reads its source echo. */
    val convertedDisplay: ConverterDisplay? get() = (this as? Converted)?.display
}

/**
 * Pre-rendered strings for the output area, so the view holds no logic. Field
 * for field the Swift `ConverterDisplay` (see its doc comment for the history
 * of each slot); the shared fixtures assert every one.
 */
data class ConverterDisplay(
    /** `12:00 pm New York (UTC-5) → 5:00 pm London (UTC+0) +1d` — the Mac's one sentence. */
    val echoLine: String,
    /** `America/New_York → Europe/London`, plus the DST note when there is one. */
    val detailLine: String,
    /** `Lisbon · 8:00 PM` — drawn inside the input box under a hairline. */
    val sourceEchoLine: String,
    val sourcePlaceName: String,
    val sourceClockDigits: String,
    val sourceMeridiem: String,
    val sourceZoneLine: String,
    /** `In São Paulo` / `In ET (Eastern Time)` — natural case; the view uppercases. */
    val targetPlaceLabel: String,
    val targetPlaceName: String,
    /** `4:00` — poster scale. */
    val targetClockDigits: String,
    /** `PM`. */
    val targetMeridiem: String,
    /** Zone name (item 21) plus any rollover note; empty for GMT/UTC, and then the view draws nothing. */
    val targetZoneLine: String,
    /** `São Paulo is 4 hours behind Lisbon.` */
    val footerSentence: String,
    /** `4 hours behind`. */
    val offsetPhrase: String,
    /** Two days a year; null otherwise. */
    val daylightSavingNote: String?,
    /** What the star on the time row stores (items 31/32); null for a `(local)` target, which has no star. */
    val favouritableTarget: FavouriteDestination? = null,
)

/** A prompt, ready to render: the spec's message and zero or more tap-to-replace chips. */
data class ConverterProblem(val message: String, val chips: List<ReplacementChip> = emptyList())

/**
 * One chip under a prompt. The typed sentence is the single source of truth,
 * so a chip carries an edit to it — a span of the raw input and its
 * replacement — rather than a parallel selection. Port of Swift `ReplacementChip`.
 */
data class ReplacementChip(
    /** `Chicago (UTC-6)` for an ambiguity, `London?` for a did-you-mean. */
    val label: String,
    val replacementText: String,
    val replacementRange: RawTextRange,
) {
    /** Stable within a row. */
    val id: String
        get() = "${replacementRange.startOffset}..<${replacementRange.endOffset}:$replacementText"

    fun applied(rawInput: String): String = RawTextEditing.replacing(replacementRange, replacementText, rawInput)
}
