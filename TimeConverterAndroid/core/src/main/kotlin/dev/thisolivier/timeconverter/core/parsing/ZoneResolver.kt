package dev.thisolivier.timeconverter.core.parsing

import dev.thisolivier.timeconverter.core.engine.ResolvedZone
import dev.thisolivier.timeconverter.core.engine.ZoneLabel
import java.time.DateTimeException
import java.time.ZoneId

/**
 * One step in the zone-resolution chain: a token in, zero or more candidate
 * meanings out. Port of Swift `ZoneResolver`.
 */
interface ZoneResolver {
    val matchSource: ZoneMatchSource

    /** [normalizedZoneToken] is already trimmed, whitespace-collapsed and lowercased. */
    fun candidates(normalizedZoneToken: String): List<ZoneCandidate>

    /** Everything this resolver could match, for the did-you-mean suggester. Additive; resolution never reads it. */
    val vocabulary: List<ZoneVocabularyEntry> get() = emptyList()
}

/** What the chain concluded about one token. Port of Swift `ZoneResolution`. */
sealed interface ZoneResolution {
    data class Resolved(val zone: ResolvedZone) : ZoneResolution
    /** More than one meaning: always prompt, never pick a default. */
    data class Ambiguous(val candidates: List<ZoneCandidate>) : ZoneResolution
    data object Unknown : ZoneResolution
}

/**
 * The resolvers in order; the first with ≥1 candidate answers. Resolution
 * order is data — [standard] is the spec's five steps.
 */
class ZoneResolverChain(val resolvers: List<ZoneResolver>) {
    fun resolve(normalizedZoneToken: String): ZoneResolution {
        for (resolver in resolvers) {
            val candidates = validUniqueCandidates(resolver.candidates(normalizedZoneToken))
            val onlyCandidate = candidates.firstOrNull() ?: continue
            if (candidates.size > 1) return ZoneResolution.Ambiguous(candidates)
            return ZoneResolution.Resolved(resolvedZone(onlyCandidate, normalizedZoneToken))
        }
        return ZoneResolution.Unknown
    }

    companion object {
        /** The five resolvers from the spec, in order. */
        val standard: ZoneResolverChain by lazy {
            ZoneResolverChain(
                listOf(
                    AliasZoneResolver,
                    FoundationAbbreviationZoneResolver,
                    TimeZoneDatabaseCityResolver,
                    CountryZoneResolver,
                    OfflineFallbackZoneResolver(),
                )
            )
        }

        /** A curated abbreviation shows code + expansion; everything else is a place (item 21). */
        private fun resolvedZone(candidate: ZoneCandidate, token: String): ResolvedZone {
            val display = candidate.abbreviationDisplay
            val displayName = candidate.echoDisplayName
            return ResolvedZone(
                zone = ZoneId.of(candidate.timeZoneIdentifier),
                displayName = displayName,
                representativeCities = display?.representativeCities.orEmpty(),
                label = if (display == null) ZoneLabel.Place(displayName, isDeviceLocal = false)
                else ZoneLabel.Abbreviation(ZoneTokenDisplay.label(token), display.name),
                matchSource = candidate.matchSource,
                originalToken = token,
            )
        }

        /**
         * Drops identifiers this runtime cannot build a zone from (a stale table
         * entry degrades to "not found") and repeats, keeping curated table order.
         */
        private fun validUniqueCandidates(candidates: List<ZoneCandidate>): List<ZoneCandidate> =
            candidates.filter { isValidIdentifier(it.timeZoneIdentifier) }.distinctBy { it.timeZoneIdentifier }

        fun isValidIdentifier(identifier: String): Boolean = try {
            ZoneId.of(identifier)
            true
        } catch (_: DateTimeException) {
            false
        }
    }
}
