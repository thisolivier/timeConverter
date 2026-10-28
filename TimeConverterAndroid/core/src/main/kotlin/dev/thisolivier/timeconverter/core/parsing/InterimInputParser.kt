package dev.thisolivier.timeconverter.core.parsing

import dev.thisolivier.timeconverter.core.engine.ConversionEngine
import dev.thisolivier.timeconverter.core.engine.ConversionRequest
import dev.thisolivier.timeconverter.core.engine.ConversionResult
import dev.thisolivier.timeconverter.core.engine.ResolvedZone
import dev.thisolivier.timeconverter.core.engine.UtcOffsetFormatting
import dev.thisolivier.timeconverter.core.engine.ZoneLabel
import java.time.Instant
import java.time.ZoneId

/**
 * INTERIM. A deliberately small parser so the Android shell has real
 * conversions and real prompts while the port of the Swift parser (resolver
 * chain, country table, gazetteer, `now`, bare zones) is pending — backlog 24b.
 *
 * Grammar: `<time> [<zone>] [in|to <zone>]`, a missing side defaulting to the
 * device zone. Zones come from [InterimZoneTable]. It emits the spec's prompts
 * with the spec's copy — P1, P2, P4 (the ambiguous codes `cst`/`ist`, with
 * candidates and the token's raw range) and P5 (with the token's raw range for
 * did-you-mean chips). Only the prompt fixtures it can express are asserted.
 */
object InterimInputParser {
    sealed interface Outcome {
        data class Converted(val result: ConversionResult) : Outcome
        data class Prompted(val prompt: Prompt) : Outcome
    }

    private sealed interface SideResolution {
        data class Resolved(val zone: ResolvedZone) : SideResolution
        data class Failed(val prompt: Prompt) : SideResolution
    }

    private val leadingConjunction = Regex("""^(?:in|to) """)
    private val middleConjunction = Regex(""" (?:in|to)(?: |$)""")

    fun parse(rawInput: String, now: Instant, localZone: ZoneId): Outcome {
        val input = NormalizedInput(rawInput)
        val timeMatch = TimeTokenParser.matchAtStart(input.text)
            ?: return Outcome.Prompted(Prompt.TimeNotFound(rawInput))
        val remainder = timeMatch.remainder
        if (remainder.isEmpty() || remainder == "in" || remainder == "to") {
            return Outcome.Prompted(Prompt.ZoneNotFound(timeMatch.time))
        }

        val remainderStart = timeMatch.remainderStartOffset
        val remainderEnd = remainderStart + remainder.length
        var sourceSpan: IntRange? = null
        var targetSpan: IntRange? = null
        val leading = leadingConjunction.find(remainder)
        val middle = middleConjunction.find(remainder)
        when {
            leading != null -> targetSpan = (remainderStart + leading.range.last + 1) until remainderEnd
            middle != null -> {
                sourceSpan = remainderStart until (remainderStart + middle.range.first)
                targetSpan = (remainderStart + middle.range.last + 1) until remainderEnd
            }
            else -> sourceSpan = remainderStart until remainderEnd
        }

        val local = ResolvedZone.place(localZone.id, isDeviceLocal = true)
        val source = when (val resolution = resolveSide(input, sourceSpan, now)) {
            null -> local
            is SideResolution.Resolved -> resolution.zone
            is SideResolution.Failed -> return Outcome.Prompted(resolution.prompt)
        }
        val target = when (val resolution = resolveSide(input, targetSpan, now)) {
            null -> local
            is SideResolution.Resolved -> resolution.zone
            is SideResolution.Failed -> return Outcome.Prompted(resolution.prompt)
        }
        return Outcome.Converted(ConversionEngine.convert(ConversionRequest(timeMatch.time, source, target, now)))
    }

    /** Null when the side is absent (it defaults to local). */
    private fun resolveSide(input: NormalizedInput, span: IntRange?, now: Instant): SideResolution? {
        if (span == null || span.isEmpty()) return null
        val token = input.text.substring(span.first, span.last + 1)
        val tokenRange = input.rawRange(span.first, span.last + 1)

        InterimZoneTable.meaningsByAlias[token]?.let { meanings ->
            if (meanings.size > 1) {
                val choices = meanings.map { meaning ->
                    ZoneChoice(
                        timeZoneIdentifier = meaning.timeZoneIdentifier,
                        representativeCity = meaning.representativeCities.first(),
                        utcOffsetDescription = UtcOffsetFormatting.description(ZoneId.of(meaning.timeZoneIdentifier), now),
                    )
                }
                return SideResolution.Failed(Prompt.AmbiguousZone(token, tokenRange, choices))
            }
            val meaning = meanings.single()
            return SideResolution.Resolved(
                ResolvedZone(
                    zone = ZoneId.of(meaning.timeZoneIdentifier),
                    displayName = meaning.expandedName,
                    representativeCities = meaning.representativeCities,
                    label = ZoneLabel.Abbreviation(token.uppercase(), meaning.expandedName),
                )
            )
        }
        InterimZoneTable.cityIdentifiersByName[token]?.let { identifier ->
            return SideResolution.Resolved(ResolvedZone.place(identifier))
        }
        return SideResolution.Failed(Prompt.UnknownZone(token, tokenRange))
    }
}
