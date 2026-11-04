package dev.thisolivier.timeconverter

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.graphics.Typeface
import android.text.format.DateFormat
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import dev.thisolivier.timeconverter.SavedCitiesWidgetSizing.Face
import dev.thisolivier.timeconverter.SavedCitiesWidgetSizing.SizeDp
import dev.thisolivier.timeconverter.SavedCitiesWidgetSizing.TimeWidths
import dev.thisolivier.timeconverter.SavedCitiesWidgetSizing.TypeSizes
import dev.thisolivier.timeconverter.core.worldclock.WidgetLayoutPlan
import dev.thisolivier.timeconverter.core.worldclock.WidgetLayoutPlan.CaptionStyle
import dev.thisolivier.timeconverter.core.worldclock.WidgetLayoutPlan.Family
import dev.thisolivier.timeconverter.core.worldclock.WidgetLayoutPlan.NameStyle
import dev.thisolivier.timeconverter.core.worldclock.WorldClockRow
import java.text.DateFormatSymbols
import java.time.ZoneId

/**
 * Draws one saved-cities widget face as `RemoteViews` (item 36b). The
 * provider and the DEBUG `WidgetPreviewActivity` both call [views], so the
 * preview shows exactly what the launcher gets.
 *
 * The face is nested `LinearLayout`s: rows of weighted cell slots with
 * hairlines between, each slot holding one of the cell layouts
 * (`widget_cell_stacked`, `widget_cell_code_row`, `widget_cell_wide_row`) or,
 * for one city, a hero layout. Each time is a pair of `TextClock`s given the
 * city's zone, so the widget ticks without the app.
 */
object SavedCitiesWidgetRenderer {
    /** The device's 12/24-hour setting, or one forced for the DEBUG preview. */
    enum class ClockStyle { FollowDevice, TwelveHour, TwentyFourHour }

    fun views(
        context: Context,
        family: Family,
        cities: List<WorldClockRow>,
        widgetSize: SizeDp,
        clockStyle: ClockStyle = ClockStyle.FollowDevice,
    ): RemoteViews {
        val plan = WidgetLayoutPlan.plan(family, cities.size)
        val shownCities = cities.take(plan.cityCount)
        val face = SavedCitiesWidgetSizing.face(plan)
        val usesTwentyFourHour = when (clockStyle) {
            ClockStyle.FollowDevice -> DateFormat.is24HourFormat(context)
            ClockStyle.TwelveHour -> false
            ClockStyle.TwentyFourHour -> true
        }
        val sizes = SavedCitiesWidgetSizing.typeSizes(
            plan = plan,
            widgetSize = widgetSize,
            timeWidths = measuredTimeWidths(usesTwentyFourHour),
            longestLabel = shownCities.maxOfOrNull { labelText(plan, it).length } ?: 0,
            longestCaption = shownCities.maxOfOrNull { longestCaptionRun(face, captionText(plan, it).orEmpty()) } ?: 0,
        )
        val packageName = context.packageName
        val root = RemoteViews(packageName, R.layout.widget_saved_cities)
        val outerPadding = SavedCitiesWidgetSizing.outerPadding(family)
        root.setViewPadding(
            R.id.widget_root,
            pixels(context, outerPadding.width), pixels(context, outerPadding.height),
            pixels(context, outerPadding.width), pixels(context, outerPadding.height),
        )
        root.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))
        if (face == Face.Empty) {
            root.setViewVisibility(R.id.widget_face, View.GONE)
            root.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            root.setTextViewTextSize(R.id.widget_empty_title, TypedValue.COMPLEX_UNIT_DIP, sizes.label)
            root.setTextViewTextSize(R.id.widget_empty_line, TypedValue.COMPLEX_UNIT_DIP, sizes.caption)
            return root
        }
        root.setViewVisibility(R.id.widget_empty, View.GONE)
        root.setViewVisibility(R.id.widget_face, View.VISIBLE)
        root.removeAllViews(R.id.widget_face)
        val clockFormats = ClockFormats.forStyle(clockStyle)
        if (plan.isHero) {
            val heroLayout = when (face) {
                Face.SmallHero -> R.layout.widget_hero_small
                Face.MediumHero -> R.layout.widget_hero_medium
                else -> R.layout.widget_hero_large
            }
            val city = shownCities.first()
            val caption = if (face == Face.MediumHero) city.offsetPhrase.replace(' ', '\n') else city.offsetPhrase
            root.addView(R.id.widget_face, cellViews(context, heroLayout, city, labelText(plan, city), caption, sizes, clockFormats))
            return root
        }
        val cellLayout = when (face) {
            Face.CodeRows -> R.layout.widget_cell_code_row
            Face.WideRows -> R.layout.widget_cell_wide_row
            else -> R.layout.widget_cell_stacked
        }
        val cellPadding = SavedCitiesWidgetSizing.cellPadding(plan)
        plan.rows(shownCities).forEachIndexed { rowIndex, rowCities ->
            if (rowIndex > 0) root.addView(R.id.widget_face, RemoteViews(packageName, R.layout.widget_hairline_horizontal))
            val rowViews = RemoteViews(packageName, R.layout.widget_grid_row)
            rowCities.forEachIndexed { columnIndex, city ->
                if (columnIndex > 0) rowViews.addView(R.id.grid_row, RemoteViews(packageName, R.layout.widget_hairline_vertical))
                val isLastInRow = columnIndex == rowCities.lastIndex
                val span = if (isLastInRow) plan.columnCount - rowCities.size + 1 else 1
                val cell = cellViews(context, cellLayout, city, labelText(plan, city), captionText(plan, city), sizes, clockFormats)
                // The first column sits on the widget's own padding; the others step off their hairline.
                val startPadding = if (columnIndex == 0) 0f else cellPadding.width
                val endPadding = if (columnIndex + span >= plan.columnCount) 0f else cellPadding.width
                cell.setViewPadding(
                    R.id.cell,
                    pixels(context, startPadding), pixels(context, cellPadding.height),
                    pixels(context, endPadding), pixels(context, cellPadding.height),
                )
                val slot = RemoteViews(packageName, slotLayout(span))
                slot.addView(R.id.cell_slot, cell)
                rowViews.addView(R.id.grid_row, slot)
            }
            root.addView(R.id.widget_face, rowViews)
        }
        return root
    }

    /** The name the plan asks for: a code (`LON`) or the compact name (`Portland`). */
    fun labelText(plan: WidgetLayoutPlan, city: WorldClockRow): String =
        if (plan.nameStyle == NameStyle.Code) city.shortPlaceName else city.compactPlaceName

    /** The caption the plan asks for; the hero always shows the full phrase. */
    fun captionText(plan: WidgetLayoutPlan, city: WorldClockRow): String? = when {
        plan.isHero -> city.offsetPhrase
        plan.captionStyle == CaptionStyle.Full -> city.offsetPhrase
        plan.captionStyle == CaptionStyle.Short -> city.shortOffsetPhrase
        else -> null
    }

    /** The medium hero sets its caption one word per line, so only the longest word competes for width. */
    private fun longestCaptionRun(face: Face, caption: String): Int =
        if (face == Face.MediumHero) caption.split(' ').maxOf { it.length } else caption.length

    private fun slotLayout(span: Int): Int = when (span) {
        1 -> R.layout.widget_cell_slot_1
        2 -> R.layout.widget_cell_slot_2
        else -> R.layout.widget_cell_slot_3
    }

    private fun cellViews(
        context: Context,
        layout: Int,
        city: WorldClockRow,
        label: String,
        caption: String?,
        sizes: TypeSizes,
        clockFormats: ClockFormats,
    ): RemoteViews = RemoteViews(context.packageName, layout).apply {
        setTextViewText(R.id.cell_label, label)
        setTextViewTextSize(R.id.cell_label, TypedValue.COMPLEX_UNIT_DIP, sizes.label)
        if (layout != R.layout.widget_cell_code_row) {
            setTextViewText(R.id.cell_caption, caption.orEmpty())
            setTextViewTextSize(R.id.cell_caption, TypedValue.COMPLEX_UNIT_DIP, sizes.caption)
            setViewVisibility(R.id.cell_caption, if (caption.isNullOrEmpty()) View.GONE else View.VISIBLE)
        }
        val zoneIdentifier = city.favourite?.timeZoneIdentifier ?: ZoneId.systemDefault().id
        setString(R.id.clock_digits, "setTimeZone", zoneIdentifier)
        setString(R.id.clock_meridiem, "setTimeZone", zoneIdentifier)
        setTextViewTextSize(R.id.clock_digits, TypedValue.COMPLEX_UNIT_DIP, sizes.time)
        setTextViewTextSize(R.id.clock_meridiem, TypedValue.COMPLEX_UNIT_DIP, sizes.meridiem)
        setCharSequence(R.id.clock_digits, "setFormat12Hour", clockFormats.digitsTwelveHour)
        setCharSequence(R.id.clock_digits, "setFormat24Hour", clockFormats.digitsTwentyFourHour)
        setCharSequence(R.id.clock_meridiem, "setFormat12Hour", clockFormats.meridiemTwelveHour)
        setCharSequence(R.id.clock_meridiem, "setFormat24Hour", clockFormats.meridiemTwentyFourHour)
    }

    /**
     * The `TextClock` formats. Following the device, TextClock picks the
     * 12- or 24-hour pair itself; the DEBUG preview forces one by giving
     * both slots the same format.
     */
    private data class ClockFormats(
        val digitsTwelveHour: String,
        val digitsTwentyFourHour: String,
        val meridiemTwelveHour: String,
        val meridiemTwentyFourHour: String,
    ) {
        companion object {
            fun forStyle(style: ClockStyle): ClockFormats = when (style) {
                ClockStyle.FollowDevice -> ClockFormats("h:mm", "HH:mm", "a", "")
                ClockStyle.TwelveHour -> ClockFormats("h:mm", "h:mm", "a", "a")
                ClockStyle.TwentyFourHour -> ClockFormats("HH:mm", "HH:mm", "", "")
            }
        }
    }

    /** The widest time in ems of the real numeral face: `12:38` + AM/PM, or `20:38`. */
    private fun measuredTimeWidths(usesTwentyFourHour: Boolean): TimeWidths {
        val referenceSize = 100f
        val paint = Paint().apply {
            typeface = Typeface.create("sans-serif-condensed", Typeface.BOLD)
            textSize = referenceSize
        }
        if (usesTwentyFourHour) return TimeWidths(paint.measureText("20:38") / referenceSize, 0f)
        val widestMeridiem = DateFormatSymbols.getInstance().amPmStrings.maxOf { paint.measureText(it) }
        return TimeWidths(
            digitsEms = paint.measureText("12:38") / referenceSize,
            meridiemEms = widestMeridiem * SavedCitiesWidgetSizing.MERIDIEM_RATIO / referenceSize,
        )
    }

    /** A tap opens the Saved tab, not the converter (Olivier, 2026-11-04). */
    private fun openAppIntent(context: Context): PendingIntent = OpenSavedTabLaunch.pendingIntent(context)

    private fun pixels(context: Context, dp: Float): Int = (dp * context.resources.displayMetrics.density).toInt()
}
