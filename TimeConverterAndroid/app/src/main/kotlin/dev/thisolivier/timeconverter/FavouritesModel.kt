package dev.thisolivier.timeconverter

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import dev.thisolivier.timeconverter.core.worldclock.FavouriteDestination
import dev.thisolivier.timeconverter.core.worldclock.FavouritesStore
import dev.thisolivier.timeconverter.core.worldclock.KeyValueBacking

/** The core store's backing on `SharedPreferences` — the twin of iOS's `UserDefaults.standard`. */
class SharedPreferencesBacking(private val preferences: SharedPreferences) : KeyValueBacking {
    override fun getString(key: String): String? = preferences.getString(key, null)
    override fun putString(key: String, value: String) {
        preferences.edit().putString(key, value).apply()
    }
}

/**
 * The core [FavouritesStore] with its list mirrored into Compose state, so the
 * star and the Clocks tab redraw when a favourite is added or removed anywhere
 * (the job `@Observable` does on iOS). One per activity.
 */
class FavouritesModel(backing: KeyValueBacking) {
    var favourites by mutableStateOf<List<FavouriteDestination>>(emptyList())
        private set

    private val store = FavouritesStore(backing) { favourites = it }

    init {
        favourites = store.favourites
    }

    fun isFavourite(destination: FavouriteDestination): Boolean =
        favourites.any { it.timeZoneIdentifier == destination.timeZoneIdentifier && it.label == destination.label }

    fun toggle(destination: FavouriteDestination) = store.toggle(destination)
    fun remove(destination: FavouriteDestination) = store.remove(destination)
    fun replaceAll(destinations: List<FavouriteDestination>) = store.replaceAll(destinations)

    companion object {
        private const val PREFERENCES_NAME = "favourites"

        fun forContext(context: Context): FavouritesModel = FavouritesModel(
            SharedPreferencesBacking(context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE))
        )
    }
}
