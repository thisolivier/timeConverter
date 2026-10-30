package dev.thisolivier.timeconverter.core.parsing

/**
 * One candidate offered by a P4 picker: a representative city and the UTC
 * offset at the injected reference instant. Port of Swift `ZoneChoice`.
 */
data class ZoneChoice(
    val timeZoneIdentifier: String,
    /** What the row says: the identifier's city, or a split place name's own label (`Portland, Oregon`, item 34b). */
    val representativeCity: String,
    val utcOffsetDescription: String,
    /** What tapping the row writes into the sentence; equal to the label except for split names (`Portland Oregon`). */
    val typedForm: String = representativeCity,
)

/**
 * The spec's prompts, as values — port of Swift `Prompt` + `PromptMessages`.
 * The parser emits them, the presenter renders them. P3 is retired.
 */
sealed interface Prompt {
    /** P1 — no parseable time at the start of the input. `input` is the normalised text. */
    data class TimeNotFound(val input: String) : Prompt

    /** P2 — a time but no zone anywhere. `time` is null for `now`. */
    data class ZoneNotFound(val time: ParsedTime?) : Prompt

    /** P4 — the token means more than one place; never silently defaulted. */
    data class AmbiguousZone(
        val token: String,
        val side: ZoneSide,
        val tokenRange: RawTextRange,
        val choices: List<ZoneChoice>,
    ) : Prompt

    /** P5 — nothing recognised the token. Same rewrite range as P4, for did-you-mean chips. */
    data class UnknownZone(val token: String, val side: ZoneSide, val tokenRange: RawTextRange) : Prompt

    /** The raw span a correction chip rewrites; null for P1 and P2, which have no single token. */
    val offendingTokenRange: RawTextRange?
        get() = when (this) {
            is AmbiguousZone -> tokenRange
            is UnknownZone -> tokenRange
            else -> null
        }

    val specIdentifier: String
        get() = when (this) {
            is TimeNotFound -> "P1"
            is ZoneNotFound -> "P2"
            is AmbiguousZone -> "P4"
            is UnknownZone -> "P5"
        }

    /** The spec's copy, word for word. P4's is only the lead-in; the presenter appends the choices. */
    val message: String
        get() = when (this) {
            is TimeNotFound -> "Couldn't find a time — start with e.g. 14:30 or 2:30 pm"
            is ZoneNotFound ->
                "Convert ${time?.twelveHourDescription ?: "now"} where? Add a timezone, city, or country"
            is AmbiguousZone -> "'$token' could mean more than one place — pick one"
            is UnknownZone ->
                "Don't recognize '$token' — try a timezone (ET, PST), a major city, or a country"
        }
}
