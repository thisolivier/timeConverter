package dev.thisolivier.timeconverter.core.parsing

import dev.thisolivier.timeconverter.core.engine.ConversionEngine
import dev.thisolivier.timeconverter.core.engine.ConversionRequest
import dev.thisolivier.timeconverter.core.engine.ConversionResult
import dev.thisolivier.timeconverter.core.engine.ResolvedZone
import dev.thisolivier.timeconverter.core.engine.UtcOffsetFormatting
import java.time.Instant
import java.time.ZoneId

/**
 * The entry point: freeform string in, a conversion to run or a prompt to
 * show. Port of Swift `InputParser`. Pure — `now` and `localZone` are
 * injected; nothing here reads the clock or the device zone.
 */
class InputParser(val zoneResolverChain: ZoneResolverChain = ZoneResolverChain.standard) {
    /** What the UI ultimately wants: a rendered result, or a prompt. Port of Swift `ConversionOutcome`. */
    sealed interface Outcome {
        data class Converted(val result: ConversionResult) : Outcome
        data class Prompted(val prompt: Prompt) : Outcome
    }

    /**
     * [now] decides "today" in the source zone, prices the P4 offsets, and —
     * for a bare zone or a leading `now` — is the time itself. [localZone]
     * fills whichever side the user didn't name, and only that.
     */
    fun parse(input: String, now: Instant, localZone: ZoneId): ParseOutcome {
        val tokens = when (val tokenized = InputTokenizer.tokenize(input)) {
            is InputTokenizer.Result.Prompted -> return ParseOutcome.Prompted(tokenized.prompt)
            is InputTokenizer.Result.Tokenized -> tokenized.tokens
        }
        // Left to right, so two bad tokens are asked about in reading order.
        val sourceZone = when (val step = resolveOrDefault(tokens.sourceZone, ZoneSide.Source, now, localZone)) {
            is ZoneStep.Prompted -> return ParseOutcome.Prompted(step.prompt)
            is ZoneStep.Resolved -> step.zone
        }
        val targetZone = when (val step = resolveOrDefault(tokens.targetZone, ZoneSide.Target, now, localZone)) {
            is ZoneStep.Prompted -> return ParseOutcome.Prompted(step.prompt)
            is ZoneStep.Resolved -> step.zone
        }
        // No typed time (bare zone, `now`): the current wall clock, read in the resolved source zone.
        val time = tokens.time ?: ParsedTime.wallClock(now, sourceZone.zone)
        return ParseOutcome.Request(ConversionRequest(time, sourceZone, targetZone, now))
    }

    /** `parse` then `ConversionEngine.convert`. */
    fun parseAndConvert(input: String, now: Instant, localZone: ZoneId): Outcome =
        when (val outcome = parse(input, now, localZone)) {
            is ParseOutcome.Prompted -> Outcome.Prompted(outcome.prompt)
            is ParseOutcome.Request -> Outcome.Converted(ConversionEngine.convert(outcome.request))
        }

    private sealed interface ZoneStep {
        data class Resolved(val zone: ResolvedZone) : ZoneStep
        data class Prompted(val prompt: Prompt) : ZoneStep
    }

    /** The only place local defaulting happens: an unnamed side is the injected device zone. */
    private fun resolveOrDefault(zoneToken: InputTokenizer.ZoneToken?, side: ZoneSide, now: Instant, localZone: ZoneId): ZoneStep {
        if (zoneToken == null) return ZoneStep.Resolved(ResolvedZone.deviceLocal(localZone))
        return when (val resolution = zoneResolverChain.resolve(zoneToken.text)) {
            is ZoneResolution.Resolved -> ZoneStep.Resolved(resolution.zone)
            is ZoneResolution.Ambiguous -> ZoneStep.Prompted(
                Prompt.AmbiguousZone(zoneToken.text, side, zoneToken.rawRange, choices(resolution.candidates, now))
            )
            ZoneResolution.Unknown -> ZoneStep.Prompted(Prompt.UnknownZone(zoneToken.text, side, zoneToken.rawRange))
        }
    }

    companion object {
        /**
         * Picker rows: the plain city (a chip writes it back, so it must be
         * typeable) and the UTC offset at the injected instant.
         */
        fun choices(candidates: List<ZoneCandidate>, instant: Instant): List<ZoneChoice> =
            candidates.filter { ZoneResolverChain.isValidIdentifier(it.timeZoneIdentifier) }.map { candidate ->
                ZoneChoice(
                    timeZoneIdentifier = candidate.timeZoneIdentifier,
                    representativeCity = candidate.representativeCityName,
                    utcOffsetDescription = UtcOffsetFormatting.description(ZoneId.of(candidate.timeZoneIdentifier), instant),
                )
            }
    }
}
