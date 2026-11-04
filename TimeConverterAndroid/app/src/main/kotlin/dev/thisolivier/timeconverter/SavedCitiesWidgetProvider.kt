package dev.thisolivier.timeconverter

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews
import dev.thisolivier.timeconverter.core.worldclock.FavouritesStore
import dev.thisolivier.timeconverter.core.worldclock.SavedCitiesWidgetSupport
import dev.thisolivier.timeconverter.core.worldclock.WidgetLayoutPlan.Family
import dev.thisolivier.timeconverter.core.worldclock.WorldClock
import dev.thisolivier.timeconverter.core.worldclock.WorldClockRow
import java.time.Instant
import java.time.ZoneId

/**
 * The saved-cities home-screen widgets (backlog items 36, 36b): the saved
 * places at a glance, in three sizes — small 2×2, medium 4×2, large 4×4 —
 * whose layout follows the number of cities (`WidgetLayoutPlan`, core). One
 * provider; each size is a thin subclass with its own `appwidget-provider`
 * XML, because Android picks sizes per receiver. The local clock is left out:
 * the home screen already has one.
 *
 * ## Why `RemoteViews` and `TextClock`, not Glance
 *
 * A clock widget wants to tick every minute without waking the app, and
 * `TextClock` does exactly that on its own: given a zone, it formats itself on
 * every minute in the launcher's process. Glance has no `TextClock`, so a
 * Glance widget would need a minute-level update schedule, which the system
 * throttles. Classic `AppWidgetProvider` + `RemoteViews` is less code and
 * keeps the time honest.
 *
 * Everything that is *not* the current time — names, offset phrases, and the
 * numeral size (which depends on the 12/24-hour setting and the widget's
 * size) — is drawn at update time by [SavedCitiesWidgetRenderer]. The widget
 * redraws when the favourites change (`FavouritesModel` → [requestUpdate]),
 * when it is resized, when the clock, zone or locale settings change, and
 * otherwise on the 30-minute `updatePeriodMillis` floor.
 */
abstract class SavedCitiesWidgetProvider(private val family: Family) : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        updateWidgets(context, appWidgetManager, family, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        updateWidgets(context, appWidgetManager, family, intArrayOf(appWidgetId))
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // A 12/24-hour switch arrives as TIME_SET; a zone change moves every offset phrase.
        if (intent.action in SETTINGS_ACTIONS) requestUpdate(context)
    }

    companion object {
        private val SETTINGS_ACTIONS = setOf(
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_LOCALE_CHANGED,
        )

        private val providers = listOf(
            Family.Small to SavedCitiesSmallWidgetProvider::class.java,
            Family.Medium to SavedCitiesMediumWidgetProvider::class.java,
            Family.Large to SavedCitiesLargeWidgetProvider::class.java,
        )

        /** Redraws every placed widget of every size now — called by the app whenever the favourites change. */
        fun requestUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            for ((family, providerClass) in providers) {
                val appWidgetIds = manager.getAppWidgetIds(ComponentName(context, providerClass))
                if (appWidgetIds.isNotEmpty()) updateWidgets(context, manager, family, appWidgetIds)
            }
        }

        /** The saved places as the widget shows them: the stored order, local left out, at most six. */
        fun savedCities(context: Context): List<WorldClockRow> {
            val favourites = FavouritesStore(FavouritesModel.backingForContext(context)).favourites
            return SavedCitiesWidgetSupport.cities(WorldClock.readings(favourites, 0, Instant.now(), ZoneId.systemDefault()))
        }

        private fun updateWidgets(context: Context, manager: AppWidgetManager, family: Family, appWidgetIds: IntArray) {
            val cities = savedCities(context)
            for (appWidgetId in appWidgetIds) {
                val options = manager.getAppWidgetOptions(appWidgetId)
                // Portrait: the narrowest width and the tallest height the launcher reported.
                val widgetSize = SavedCitiesWidgetSizing.launcherSize(
                    family,
                    portraitWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH),
                    portraitHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT),
                )
                val views: RemoteViews = SavedCitiesWidgetRenderer.views(context, family, cities, widgetSize)
                manager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}

/** 2×2: one hero city, code rows, or a grid of codes. */
class SavedCitiesSmallWidgetProvider : SavedCitiesWidgetProvider(Family.Small)

/** 4×2: a hero with its caption beside a rule, or up to three columns. */
class SavedCitiesMediumWidgetProvider : SavedCitiesWidgetProvider(Family.Medium)

/** 4×4: a hero, generous full-width rows, or a grid with captions. */
class SavedCitiesLargeWidgetProvider : SavedCitiesWidgetProvider(Family.Large)
