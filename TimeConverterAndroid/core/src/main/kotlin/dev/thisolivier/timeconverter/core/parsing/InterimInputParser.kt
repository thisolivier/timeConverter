package dev.thisolivier.timeconverter.core.parsing

import dev.thisolivier.timeconverter.core.engine.ConversionEngine
import dev.thisolivier.timeconverter.core.engine.ConversionRequest
import dev.thisolivier.timeconverter.core.engine.ConversionResult
import dev.thisolivier.timeconverter.core.engine.ResolvedZone
import dev.thisolivier.timeconverter.core.engine.ZoneDisplayName
import dev.thisolivier.timeconverter.core.engine.ZoneLabel
import java.time.Instant
import java.time.ZoneId

/**
 * INTERIM. A deliberately small parser so the Android shell has something to
 * convert while the real port of the Swift parser (resolver chain, prompts,
 * chips, local defaulting, `now`, bare zones) is pending — backlog item 24b.
 *
 * It covers the grammar's shape (`<time> <zone> in|to <zone>`, or one zone
 * with the other side defaulting to local) over a tiny alias table plus the
 * tz database's own city names. Everything it cannot do returns a
 * [Outcome.Problem] with a hand-written message. Nothing here is asserted by
 * the shared fixtures; the fixture parser suite stays ignored until this
 * file is replaced.
 */
object InterimInputParser {
    sealed interface Outcome {
        data object Hint : Outcome
        data class Converted(val result: ConversionResult) : Outcome
        data class Problem(val message: String) : Outcome
    }

    private val aliases: Map<String, Pair<String, ZoneLabel.Abbreviation>> = listOf(
        Triple("et", "America/New_York", "Eastern Time"),
        Triple("eastern", "America/New_York", "Eastern Time"),
        Triple("east coast", "America/New_York", "Eastern Time"),
        Triple("ct", "America/Chicago", "Central Time"),
        Triple("mt", "America/Denver", "Mountain Time"),
        Triple("pt", "America/Los_Angeles", "Pacific Time"),
        Triple("pst", "America/Los_Angeles", "Pacific Standard Time"),
        Triple("west coast", "America/Los_Angeles", "Pacific Time"),
        Triple("uk", "Europe/London", "UK Time"),
        Triple("gmt", "GMT", "Greenwich Mean Time"),
        Triple("utc", "UTC", "Coordinated Universal Time"),
        Triple("cet", "Europe/Paris", "Central European Time"),
    ).associate { (code, identifier, expanded) ->
        code to (identifier to ZoneLabel.Abbreviation(code.uppercase(), expanded))
    }

    /** `new york` → `America/New_York`, built once from the live database. */
    private val citiesByName: Map<String, String> = ZoneId.getAvailableZoneIds()
        .filter { it.contains('/') && !it.startsWith("Etc/") }
        .sorted()
        .associateBy { ZoneDisplayName.forIdentifier(it).lowercase() }

    fun parse(rawInput: String, now: Instant, localZone: ZoneId): Outcome {
        val normalized = rawInput.trim().lowercase().replace(Regex("\\s+"), " ")
        if (normalized.isEmpty()) return Outcome.Hint

        val timeMatch = TimeTokenParser.matchAtStart(normalized)
            ?: return Outcome.Problem("Couldn't find a time — start with e.g. 14:30 or 2:30 pm")
        val remainder = timeMatch.remainder
        if (remainder.isEmpty()) {
            return Outcome.Problem("Convert ${timeMatch.time.canonicalDescription} where? Add a timezone, city, or country")
        }

        val conjunction = Regex("""^(?:in|to) (.+)$""").find(remainder)
        val sides = when {
            conjunction != null -> null to conjunction.groupValues[1]
            " in " in remainder || " to " in remainder -> {
                val parts = remainder.split(Regex(" (?:in|to) "), limit = 2)
                parts[0] to parts[1]
            }
            else -> remainder to null
        }

        val local = ResolvedZone.place(localZone.id, isDeviceLocal = true)
        val source = sides.first?.let { resolve(it) ?: return Outcome.Problem(unknown(it)) } ?: local
        val target = sides.second?.let { resolve(it) ?: return Outcome.Problem(unknown(it)) } ?: local

        return Outcome.Converted(
            ConversionEngine.convert(ConversionRequest(timeMatch.time, source, target, now))
        )
    }

    private fun resolve(token: String): ResolvedZone? {
        aliases[token]?.let { (identifier, label) ->
            return ResolvedZone(ZoneId.of(identifier), label.expandedName, label = label)
        }
        return citiesByName[token]?.let { ResolvedZone.place(it) }
    }

    private fun unknown(token: String) =
        "Don't recognize '$token' — try a timezone (ET, PST), a major city, or a country"
}
