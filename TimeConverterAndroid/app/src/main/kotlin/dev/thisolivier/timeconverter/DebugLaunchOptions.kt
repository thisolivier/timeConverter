package dev.thisolivier.timeconverter

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import dev.thisolivier.timeconverter.core.worldclock.FavouriteDestination

/**
 * DEBUG-only launch extras for QA, the twins of the iOS `-favourites`,
 * `-selectedTab` and `-clockOffsetMinutes` launch arguments
 * (`scripts/run-android.sh --favourites … --tab clocks --offset-minutes …`).
 * String extras throughout, like `initialInput`. Ignored on a release build.
 *
 * - `favourites` — `London,ET,Tokyo`: REPLACES the stored favourites with what
 *   starring the target of `12pm in <zone>` would store, through the real
 *   parser; zones that do not convert (unknown, ambiguous) are skipped.
 * - `selectedTab` — `clocks` opens on the Clocks tab.
 * - `clockOffsetMinutes` — a signed integer; `m960` also means −960 (the iOS
 *   spelling, for shells that eat a leading minus).
 */
data class DebugLaunchOptions(
    val seededFavourites: List<FavouriteDestination>? = null,
    val opensOnClocksTab: Boolean = false,
    val clockOffsetMinutes: Int = 0,
) {
    val isScripted: Boolean get() = seededFavourites != null || opensOnClocksTab || clockOffsetMinutes != 0

    companion object {
        const val FAVOURITES_EXTRA = "favourites"
        const val SELECTED_TAB_EXTRA = "selectedTab"
        const val CLOCK_OFFSET_MINUTES_EXTRA = "clockOffsetMinutes"

        fun read(context: Context, intent: Intent?): DebugLaunchOptions {
            val isDebuggable = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
            if (!isDebuggable || intent == null) return DebugLaunchOptions()
            return parse(
                favourites = intent.getStringExtra(FAVOURITES_EXTRA),
                selectedTab = intent.getStringExtra(SELECTED_TAB_EXTRA),
                clockOffsetMinutes = intent.getStringExtra(CLOCK_OFFSET_MINUTES_EXTRA),
            )
        }

        /** The pure half, for JVM tests. */
        fun parse(favourites: String?, selectedTab: String?, clockOffsetMinutes: String?) = DebugLaunchOptions(
            seededFavourites = favourites?.let(::seededFavourites),
            opensOnClocksTab = selectedTab?.trim().equals("clocks", ignoreCase = true),
            clockOffsetMinutes = signedInteger(clockOffsetMinutes),
        )

        fun seededFavourites(commaSeparatedZones: String): List<FavouriteDestination> =
            commaSeparatedZones.split(',')
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .mapNotNull(FavouriteDestination::resolvingTypedZone)

        fun signedInteger(text: String?): Int {
            val trimmed = text?.trim().orEmpty()
            val normalised = if (trimmed.startsWith("m")) "-" + trimmed.drop(1) else trimmed
            return normalised.toIntOrNull() ?: 0
        }
    }
}
