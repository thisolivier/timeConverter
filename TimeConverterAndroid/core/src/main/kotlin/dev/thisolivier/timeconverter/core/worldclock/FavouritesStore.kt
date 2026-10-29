package dev.thisolivier.timeconverter.core.worldclock

import dev.thisolivier.timeconverter.core.engine.ZoneLabel
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/**
 * The one string slot the store writes to — `SharedPreferences` in the app,
 * a plain map in tests, so no test ever touches real preferences.
 */
interface KeyValueBacking {
    fun getString(key: String): String?
    fun putString(key: String, value: String)
}

/** A map-backed [KeyValueBacking] for tests and previews. */
class InMemoryKeyValueBacking(private val values: MutableMap<String, String> = mutableMapOf()) : KeyValueBacking {
    override fun getString(key: String): String? = values[key]
    override fun putString(key: String, value: String) {
        values[key] = value
    }
}

/**
 * The starred destinations, in the order they were starred. Port of Swift
 * `FavouritesStore`: one JSON array under one key of an injected backing.
 *
 * The JSON is Swift's synthesized `Codable` shape, key for key —
 * `{"timeZoneIdentifier":…,"label":{"place":{"name":…,"isDeviceLocal":false}}}`
 * or `{"abbreviation":{"code":…,"expandedName":…}}` — so the two platforms
 * store the same thing. Unreadable data degrades to no favourites.
 *
 * Not observable itself (`:core` has no Compose); [onChange] lets the app
 * mirror [favourites] into Compose state.
 */
class FavouritesStore(
    private val backing: KeyValueBacking,
    private val onChange: (List<FavouriteDestination>) -> Unit = {},
) {
    var favourites: List<FavouriteDestination> = load(backing)
        private set

    fun isFavourite(destination: FavouriteDestination): Boolean =
        favourites.any { it.timeZoneIdentifier == destination.timeZoneIdentifier && it.label == destination.label }

    /** Adds at the end, or removes if already starred. */
    fun toggle(destination: FavouriteDestination) {
        if (isFavourite(destination)) remove(destination) else update(favourites + destination)
    }

    fun remove(destination: FavouriteDestination) = update(favourites.filterNot { it == destination })

    /** Replaces the whole list — the DEBUG `favourites` seed's entry point. */
    fun replaceAll(destinations: List<FavouriteDestination>) = update(destinations)

    private fun update(newFavourites: List<FavouriteDestination>) {
        favourites = newFavourites
        backing.putString(DEFAULTS_KEY, encode(newFavourites))
        onChange(newFavourites)
    }

    companion object {
        /** The same key as Swift's `FavouritesStore.defaultsKey`. */
        const val DEFAULTS_KEY = "favouriteDestinations"

        private val json = Json { explicitNulls = false; ignoreUnknownKeys = true }
        private val listSerializer = ListSerializer(StoredFavourite.serializer())

        fun encode(favourites: List<FavouriteDestination>): String =
            json.encodeToString(listSerializer, favourites.map(StoredFavourite::from))

        fun decode(text: String): List<FavouriteDestination> =
            json.decodeFromString(listSerializer, text).mapNotNull(StoredFavourite::destination)

        private fun load(backing: KeyValueBacking): List<FavouriteDestination> {
            val text = backing.getString(DEFAULTS_KEY) ?: return emptyList()
            return try {
                decode(text)
            } catch (_: IllegalArgumentException) {
                emptyList()
            }
        }
    }
}

/** Swift's synthesized `Codable` form of `FavouriteDestination` / `ZoneLabel`. */
@Serializable
private data class StoredFavourite(val timeZoneIdentifier: String, val label: StoredLabel) {
    fun destination(): FavouriteDestination? {
        val zoneLabel = label.place?.let { ZoneLabel.Place(it.name, it.isDeviceLocal) }
            ?: label.abbreviation?.let { ZoneLabel.Abbreviation(it.code, it.expandedName) }
            ?: return null
        return FavouriteDestination(timeZoneIdentifier, zoneLabel)
    }

    companion object {
        fun from(destination: FavouriteDestination) = StoredFavourite(
            destination.timeZoneIdentifier,
            when (val label = destination.label) {
                is ZoneLabel.Place -> StoredLabel(place = StoredPlace(label.name, label.isDeviceLocal))
                is ZoneLabel.Abbreviation -> StoredLabel(abbreviation = StoredAbbreviation(label.code, label.expandedName))
            },
        )
    }
}

@Serializable
private data class StoredLabel(val place: StoredPlace? = null, val abbreviation: StoredAbbreviation? = null)

@Serializable
private data class StoredPlace(val name: String, val isDeviceLocal: Boolean)

@Serializable
private data class StoredAbbreviation(val code: String, val expandedName: String)
