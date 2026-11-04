package dev.thisolivier.timeconverter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import dev.thisolivier.timeconverter.core.worldclock.FavouritesStore
import dev.thisolivier.timeconverter.core.worldclock.SavedCitiesWidgetSupport
import dev.thisolivier.timeconverter.core.worldclock.WorldClock
import dev.thisolivier.timeconverter.core.worldclock.WorldClockRow
import java.time.Instant
import java.time.ZoneId

/**
 * The saved-cities home-screen widget (backlog item 36): the Clocks tab's rows
 * at a glance — the local clock and up to five favourites. One size for the
 * MVP (4×3 cells, resizable), the Android twin of the iOS `.systemLarge`.
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
 * Everything that is *not* the current time — the place name, the zone line
 * with its day marker, the offset phrase — comes from `WorldClock.readings`,
 * the same strings the Clocks tab shows, rendered at update time. Those change
 * rarely (a favourite starred or removed, a zone crossing midnight, a DST
 * change), so the widget is redrawn when the favourites change
 * (`FavouritesModel` → [requestUpdate]) and otherwise on the 30-minute
 * `updatePeriodMillis` floor, which is the right cadence for a day marker.
 */
class SavedCitiesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val views = buildViews(context)
        for (appWidgetId in appWidgetIds) appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    companion object {
        /** Redraws every placed widget now — called by the app whenever the favourites change. */
        fun requestUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, SavedCitiesWidgetProvider::class.java))
            if (ids.isEmpty()) return
            manager.updateAppWidget(ids, buildViews(context))
        }

        /** The whole widget: one row per clock, an explanatory line when nothing is starred, tap opens the app. */
        fun buildViews(context: Context): RemoteViews {
            val favourites = FavouritesStore(FavouritesModel.backingForContext(context)).favourites
            val display = WorldClock.readings(favourites, 0, Instant.now(), ZoneId.systemDefault())
            val rows = SavedCitiesWidgetSupport.rows(display)
            val views = RemoteViews(context.packageName, R.layout.widget_saved_cities)
            views.removeAllViews(R.id.widget_rows)
            rows.forEachIndexed { index, row ->
                if (index > 0) views.addView(R.id.widget_rows, RemoteViews(context.packageName, R.layout.widget_saved_cities_divider))
                views.addView(R.id.widget_rows, rowViews(context, row))
            }
            views.setViewVisibility(R.id.widget_empty, if (favourites.isEmpty()) View.VISIBLE else View.GONE)
            val openApp = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.widget_root, openApp)
            return views
        }

        /** One clock. The two `TextClock`s (digits, meridiem) tick on their own in the row's zone. */
        private fun rowViews(context: Context, row: WorldClockRow): RemoteViews {
            val zoneIdentifier = row.favourite?.timeZoneIdentifier ?: ZoneId.systemDefault().id
            return RemoteViews(context.packageName, R.layout.widget_saved_cities_row).apply {
                setTextViewText(R.id.row_place_name, row.placeName)
                setTextViewText(R.id.row_zone_line, row.zoneLine)
                setViewVisibility(R.id.row_zone_line, if (row.zoneLine.isEmpty()) View.GONE else View.VISIBLE)
                setTextViewText(R.id.row_offset_phrase, row.offsetPhrase)
                setViewVisibility(R.id.row_offset_phrase, if (row.offsetPhrase.isEmpty()) View.GONE else View.VISIBLE)
                setString(R.id.row_clock_digits, "setTimeZone", zoneIdentifier)
                setString(R.id.row_clock_meridiem, "setTimeZone", zoneIdentifier)
            }
        }
    }
}
