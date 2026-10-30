package dev.thisolivier.timeconverter.core.parsing

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Step 5 — the offline fallback gazetteer: cities the tz database has no zone
 * for (Porto, Mumbai, Barcelona, Portland — ~3,100 editorial entries since item 34). Port
 * of Swift `OfflineFallbackZoneResolver`. Knowledge lives in data, not code.
 */
class OfflineFallbackZoneResolver(
    /** Defaults to the bundled file; tests can supply their own entries. */
    val identifiersByPlaceName: Map<String, List<String>> = OfflineFallbackGazetteer.bundledEntries,
    /**
     * For a name split across zones, what each zone's chip says and writes back
     * (item 34b): `portland` → `Portland, Oregon` / `Portland Oregon`, not `Los
     * Angeles`. Parallel to the entry's identifiers; absent for single-zone names.
     */
    val choicesByPlaceName: Map<String, List<PlaceChoice>> = OfflineFallbackGazetteer.bundledChoices,
) : ZoneResolver {
    override val matchSource = ZoneMatchSource.OfflineFallbackList

    override fun candidates(normalizedZoneToken: String): List<ZoneCandidate> {
        val choices = choicesByPlaceName[normalizedZoneToken].orEmpty()
        return identifiersByPlaceName[normalizedZoneToken].orEmpty().mapIndexed { index, identifier ->
            ZoneCandidate(identifier, matchSource, placeChoice = choices.getOrNull(index))
        }
    }

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

    private val bundledText: String? by lazy { OfflineFallbackGazetteer::class.java.getResource(RESOURCE_PATH)?.readText() }

    /** Decoded once, on first use. */
    val bundledEntries: Map<String, List<String>> by lazy { bundledText?.let(::decodeEntries) ?: emptyMap() }
    val bundledChoices: Map<String, List<PlaceChoice>> by lazy { bundledText?.let(::decodeChoices) ?: emptyMap() }

    /** Lowercased names; an entry with no identifiers is skipped; a repeated name keeps the last entry, as in Swift. */
    fun decodeEntries(text: String): Map<String, List<String>> {
        val identifiersByPlaceName = LinkedHashMap<String, List<String>>()
        for (entry in decodeFile(text)?.entries.orEmpty()) {
            if (entry.timeZoneIdentifiers.isNotEmpty()) identifiersByPlaceName[entry.name.lowercase()] = entry.timeZoneIdentifiers
        }
        return identifiersByPlaceName
    }

    /** Only entries that carry `choices`; a mismatched count is left for the tests to reject, not silently dropped. */
    fun decodeChoices(text: String): Map<String, List<PlaceChoice>> {
        val choicesByPlaceName = LinkedHashMap<String, List<PlaceChoice>>()
        for (entry in decodeFile(text)?.entries.orEmpty()) {
            val choices = entry.choices
            if (!choices.isNullOrEmpty()) choicesByPlaceName[entry.name.lowercase()] = choices.map { PlaceChoice(it.label, it.typed) }
        }
        return choicesByPlaceName
    }

    private fun decodeFile(text: String): GazetteerFile? = try {
        json.decodeFromString<GazetteerFile>(text)
    } catch (_: IllegalArgumentException) {
        null
    }

    @Serializable
    data class GazetteerFile(val version: Int, val entries: List<Entry>) {
        @Serializable
        data class Entry(val name: String, val timeZoneIdentifiers: List<String>, val choices: List<Choice>? = null) {
            /** `label` is what the chip says (`Portland, Oregon`); `typed` is what it writes back (`Portland Oregon`). */
            @Serializable
            data class Choice(val label: String, val typed: String)
        }
    }
}
