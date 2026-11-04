package dev.thisolivier.timeconverter

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import dev.thisolivier.timeconverter.SavedCitiesWidgetRenderer.ClockStyle
import dev.thisolivier.timeconverter.core.worldclock.FavouriteDestination
import dev.thisolivier.timeconverter.core.worldclock.SavedCitiesWidgetSupport
import dev.thisolivier.timeconverter.core.worldclock.WidgetLayoutPlan.Family
import dev.thisolivier.timeconverter.core.worldclock.WorldClock
import java.time.Instant
import java.time.ZoneId

/**
 * DEBUG only (src/debug): every saved-cities widget face, inflated in-process
 * from the same `RemoteViews` the launcher gets, at each family's nominal dp
 * size, in a scroll view — so a headless emulator can photograph them
 * (`adb exec-out screencap`), since placing a real widget needs the launcher.
 *
 * Optional string extras narrow the sheet: `family` (`small`, `medium`,
 * `large`), `clock` (`12`, `24`), `counts` (`1,3,6`). Default: every family
 * × 0…6 cities × both clocks. Sample cities: London, Los Angeles, Tokyo,
 * São Paulo, New York, Lisbon, through the real parser.
 *
 * ```
 * adb shell am start -n dev.thisolivier.timeconverter/.WidgetPreviewActivity --es family small --es clock 12
 * ```
 */
class WidgetPreviewActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val families = intent.getStringExtra("family")?.let { requested ->
            Family.entries.filter { it.name.equals(requested, ignoreCase = true) }
        } ?: Family.entries
        val clockStyles = when (intent.getStringExtra("clock")) {
            "12" -> listOf(ClockStyle.TwelveHour)
            "24" -> listOf(ClockStyle.TwentyFourHour)
            else -> listOf(ClockStyle.TwelveHour, ClockStyle.TwentyFourHour)
        }
        val counts = intent.getStringExtra("counts")?.split(',')?.mapNotNull { it.trim().toIntOrNull() } ?: (0..6).toList()

        val sampleFavourites = listOf("London", "Los Angeles", "Tokyo", "Sao Paulo", "New York", "Lisbon")
            .mapNotNull { FavouriteDestination.resolvingTypedZone(it) }
        val sampleCities = SavedCitiesWidgetSupport.cities(
            WorldClock.readings(sampleFavourites, 0, Instant.now(), ZoneId.systemDefault()),
        )

        val sheet = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pixels(16f), pixels(32f), pixels(16f), pixels(48f))
        }
        for (family in families) for (count in counts) for (clockStyle in clockStyles) {
            val clockName = if (clockStyle == ClockStyle.TwelveHour) "12h" else "24h"
            sheet.addView(TextView(this).apply {
                text = "${family.name.uppercase()} · $count · $clockName"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                setPadding(0, pixels(12f), 0, pixels(4f))
            })
            val widgetSize = SavedCitiesWidgetSizing.nominalSize(family)
            val frame = FrameLayout(this)
            val views = SavedCitiesWidgetRenderer.views(this, family, sampleCities.take(count), widgetSize, clockStyle)
            frame.addView(views.apply(this, frame))
            sheet.addView(frame, LinearLayout.LayoutParams(pixels(widgetSize.width), pixels(widgetSize.height)))
        }
        setContentView(ScrollView(this).apply {
            setBackgroundColor(Color.rgb(0x3A, 0x3A, 0x3C))
            addView(sheet, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        })
    }

    private fun pixels(dp: Float): Int = (dp * resources.displayMetrics.density).toInt()
}
