package dev.thisolivier.timeconverter.core.parsing

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Step 5 — the offline fallback gazetteer: cities the tz database has no zone
 * for (Porto, Mumbai, Barcelona — ~300 editorial entries since item 26). Port
 * of Swift `OfflineFallbackZoneResolver`. Knowledge lives in data, not code.
 */
class OfflineFallbackZoneResolver(
    /** Defaults to the bundled file; tests can supply their own entries. */
    val identifiersByPlaceName: Map<String, List<String>> = OfflineFallbackGazetteer.bundledEntries,
) : ZoneResolver {
    override val matchSource = ZoneMatchSource.OfflineFallbackList

    override fun candidates(normalizedZoneToken: String): List<ZoneCandidate> =
        identifiersByPlaceName[normalizedZoneToken].orEmpty().map { ZoneCandidate(it, matchSource) }

    override val vocabulary: List<ZoneVocabularyEntry>
        get() = identifiersByPlaceName.keys.map {
            ZoneVocabularyEntry(it, ZoneVocabularyEntry.Shape.PlaceName, matchSource)
        }
}

/**
 * Reads `/fallback-cities.json` — the Swift core's resource, put on this
 * module's classpath by `core/build.gradle.kts` straight from
 * `TimeConverterCore/Sources/TimeConverterCore/Resources/` (one file, no copy).
 * A missing or malformed file degrades to an empty table: tokens then fall
 * through to P5 rather than crashing. `OfflineFallbackGazetteerTests` is what
 * guarantees the file is actually there.
 */
object OfflineFallbackGazetteer {
    const val RESOURCE_PATH = "/fallback-cities.json"

    private val json = Json { ignoreUnknownKeys = true }

    /** Decoded once, on first use. */
    val bundledEntries: Map<String, List<String>> by lazy {
        val text = OfflineFallbackGazetteer::class.java.getResource(RESOURCE_PATH)?.readText() ?: return@lazy emptyMap()
        decodeEntries(text)
    }

    /** Lowercased names; an entry with no identifiers is skipped; a repeated name keeps the last entry, as in Swift. */
    fun decodeEntries(text: String): Map<String, List<String>> {
        val file = try {
            json.decodeFromString<GazetteerFile>(text)
        } catch (_: IllegalArgumentException) {
            return emptyMap()
        }
        val identifiersByPlaceName = LinkedHashMap<String, List<String>>()
        for (entry in file.entries) {
            if (entry.timeZoneIdentifiers.isNotEmpty()) identifiersByPlaceName[entry.name.lowercase()] = entry.timeZoneIdentifiers
        }
        return identifiersByPlaceName
    }

    @Serializable
    data class GazetteerFile(val version: Int, val entries: List<Entry>) {
        @Serializable
        data class Entry(val name: String, val timeZoneIdentifiers: List<String>)
    }
}
