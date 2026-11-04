package dev.thisolivier.timeconverter.core.worldclock

import dev.thisolivier.timeconverter.core.engine.ZoneLabel
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The widgets' 3–4-letter place names (item 36b), read from the Swift core's
 * `/short-names.json` on this module's classpath — every tz city and
 * gazetteer name has one. Port of Swift `ShortPlaceNames`: the listed form, a
 * code as itself, otherwise the first three letters of the compact name.
 */
object ShortPlaceNames {
    const val RESOURCE_PATH = "/short-names.json"

    private val json = Json { ignoreUnknownKeys = true }

    val bundledNames: Map<String, String> by lazy {
        ShortPlaceNames::class.java.getResource(RESOURCE_PATH)?.readText()?.let(::decodeNames) ?: emptyMap()
    }

    fun shortName(label: ZoneLabel?, compactPlaceName: String): String {
        if (label is ZoneLabel.Abbreviation) return label.code
        return bundledNames[compactPlaceName.lowercase()] ?: compactPlaceName.take(3).uppercase()
    }

    fun decodeNames(text: String): Map<String, String> = try {
        json.decodeFromString<ShortNamesFile>(text).names
    } catch (_: IllegalArgumentException) {
        emptyMap()
    }

    @Serializable
    data class ShortNamesFile(val version: Int, val names: Map<String, String>)
}
