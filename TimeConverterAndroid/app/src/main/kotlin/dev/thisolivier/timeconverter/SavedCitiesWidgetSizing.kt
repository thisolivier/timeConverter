package dev.thisolivier.timeconverter

import dev.thisolivier.timeconverter.core.worldclock.WidgetLayoutPlan
import dev.thisolivier.timeconverter.core.worldclock.WidgetLayoutPlan.Family
import kotlin.math.floor
import kotlin.math.min

/**
 * The saved-cities widget's dp arithmetic (item 36b), kept free of Android so
 * the JVM tests can hold it. `WidgetLayoutPlan` (core) decides the layout —
 * columns, rows, names, captions; this decides how big things are drawn.
 *
 * The approach mirrors the iOS `WidgetTypeSizes`: each face has a designed
 * size per family (the 2026-11-04 designs' proportions on a phone's nominal
 * widget size), scaled to the space the launcher actually gave, and then the
 * numeral is capped so the widest time the cell can show — `12:38 AM` on a
 * 12-hour device, `20:38` on a 24-hour one — fits the narrowest cell, across
 * and down. One numeral size per face, so cells never disagree.
 */
object SavedCitiesWidgetSizing {
    /** A widget's (or a cell's) size in dp. */
    data class SizeDp(val width: Float, val height: Float)

    /** Every text size on one face, in dp. */
    data class TypeSizes(val label: Float, val time: Float, val caption: Float) {
        /** The AM/PM beside the digits, as the iOS face draws it, never below legible. */
        val meridiem: Float get() = maxOf(8f, floor(time * MERIDIEM_RATIO))
    }

    /** The shape of the face, which picks the cell layout. */
    enum class Face { Empty, SmallHero, MediumHero, LargeHero, CodeRows, WideRows, Grid }

    /**
     * How wide the widest time is, in ems of the numeral size — measured by
     * the caller with the real typeface (`Paint`), so the arithmetic here
     * stays exact without Android. `meridiemEms` is the AM/PM already at
     * [MERIDIEM_RATIO] of the numeral, 0 on a 24-hour clock.
     */
    data class TimeWidths(val digitsEms: Float, val meridiemEms: Float)

    const val MERIDIEM_RATIO = 0.4f
    const val MERIDIEM_GAP_DP = 3f
    const val HAIRLINE_DP = 1f
    /** Monospace advance (0.6 em) plus the labels' 0.16 em letter spacing. */
    const val LABEL_CHARACTER_EMS = 0.76f
    const val CAPTION_CHARACTER_EMS = 0.6f
    /** Line height of a numeral with font padding off, in ems. */
    const val NUMERAL_LINE_EMS = 1.18f
    const val TEXT_LINE_EMS = 1.3f

    /** The launcher's nominal sizes for 2×2, 4×2 and 4×4 cells on a phone. */
    fun nominalSize(family: Family): SizeDp = when (family) {
        Family.Small -> SizeDp(150f, 150f)
        Family.Medium -> SizeDp(320f, 150f)
        Family.Large -> SizeDp(320f, 330f)
    }

    /**
     * The size the launcher reports for a placed widget (portrait width and
     * height, in dp), or the nominal size when it has not said yet (0).
     */
    fun launcherSize(family: Family, portraitWidth: Int, portraitHeight: Int): SizeDp =
        if (portraitWidth <= 0 || portraitHeight <= 0) nominalSize(family)
        else SizeDp(portraitWidth.toFloat(), portraitHeight.toFloat())

    fun face(plan: WidgetLayoutPlan): Face = when {
        plan.cityCount == 0 -> Face.Empty
        plan.isHero -> when (plan.family) {
            Family.Small -> Face.SmallHero
            Family.Medium -> Face.MediumHero
            Family.Large -> Face.LargeHero
        }
        plan.columnCount == 1 && plan.family == Family.Small -> Face.CodeRows
        plan.columnCount == 1 -> Face.WideRows
        else -> Face.Grid
    }

    /** Padding inside the widget's paper; tighter on the small widget (compression step 1). */
    fun outerPadding(family: Family): SizeDp = if (family == Family.Small) SizeDp(12f, 10f) else SizeDp(16f, 12f)

    /** Padding inside one cell; a one-column face needs none across. */
    fun cellPadding(plan: WidgetLayoutPlan): SizeDp = when {
        plan.columnCount == 1 -> SizeDp(0f, 2f)
        plan.family == Family.Small -> SizeDp(5f, 2f)
        else -> SizeDp(8f, 3f)
    }

    /** The designed sizes before fitting — the iOS point sizes scaled to the phone's widget dp. */
    fun designedSizes(plan: WidgetLayoutPlan): TypeSizes = when (face(plan)) {
        Face.Empty -> TypeSizes(label = 10f, time = 0f, caption = 12f)
        Face.SmallHero -> TypeSizes(label = 10f, time = 44f, caption = 11f)
        Face.MediumHero -> TypeSizes(label = 11f, time = 72f, caption = 13f)
        Face.LargeHero -> TypeSizes(label = 13f, time = 100f, caption = 15f)
        Face.CodeRows -> TypeSizes(label = 10f, time = 28f, caption = 9f)
        Face.WideRows -> TypeSizes(label = 11f, time = 56f, caption = 12f)
        Face.Grid -> when (plan.family) {
            Family.Small -> if (plan.rowCount <= 2) TypeSizes(9f, 26f, 9f) else TypeSizes(9f, 22f, 9f)
            Family.Medium -> when {
                plan.rowCount == 1 && plan.columnCount == 2 -> TypeSizes(10f, 44f, 11f)
                plan.rowCount == 1 -> TypeSizes(9f, 34f, 10f)
                else -> TypeSizes(9f, 32f, 9f)
            }
            Family.Large -> if (plan.rowCount <= 2) TypeSizes(11f, 52f, 12f) else TypeSizes(10f, 42f, 11f)
        }
    }

    /** How far the launcher's space departs from nominal; labels and captions follow it within bounds. */
    fun scale(family: Family, widgetSize: SizeDp): Float {
        val nominal = nominalSize(family)
        return min(widgetSize.width / nominal.width, widgetSize.height / nominal.height).coerceIn(0.8f, 1.4f)
    }

    /** The space the narrowest cell's content gets: the widget less padding and hairlines, split evenly. */
    fun cellContentSize(plan: WidgetLayoutPlan, widgetSize: SizeDp): SizeDp {
        val outer = outerPadding(plan.family)
        val cell = cellPadding(plan)
        val columns = maxOf(1, plan.columnCount)
        val rows = maxOf(1, plan.rowCount)
        val innerWidth = widgetSize.width - 2 * outer.width - (columns - 1) * HAIRLINE_DP
        val innerHeight = widgetSize.height - 2 * outer.height - (rows - 1) * HAIRLINE_DP
        // Cells pad only the sides that meet a hairline: none in one column,
        // one each in two, two for the middle of three (the narrowest).
        val paddedSides = minOf(2, columns - 1)
        return SizeDp(innerWidth / columns - paddedSides * cell.width, innerHeight / rows - 2 * cell.height)
    }

    /**
     * The face's sizes for this widget. `longestCaption` is the longest caption
     * the face will show, in characters (it shares the width with the time on
     * the wide rows; for the medium hero, which sets it a word per line, pass
     * the longest word); `longestLabel` the longest label in characters.
     */
    fun typeSizes(
        plan: WidgetLayoutPlan,
        widgetSize: SizeDp,
        timeWidths: TimeWidths,
        longestLabel: Int,
        longestCaption: Int,
    ): TypeSizes {
        val scaleFactor = scale(plan.family, widgetSize)
        val designed = designedSizes(plan)
        val label = floor(designed.label * scaleFactor)
        val caption = floor(designed.caption * scaleFactor)
        if (face(plan) == Face.Empty) return TypeSizes(label, 0f, caption)
        val cell = cellContentSize(plan, widgetSize)
        val showsCaption = plan.captionStyle != WidgetLayoutPlan.CaptionStyle.None
        val labelLine = label * TEXT_LINE_EMS
        val captionLine = if (showsCaption) caption * TEXT_LINE_EMS else 0f
        val captionWidth = longestCaption * CAPTION_CHARACTER_EMS * caption
        val (widthForTime, heightForTime) = when (face(plan)) {
            Face.CodeRows -> (cell.width - longestLabel * LABEL_CHARACTER_EMS * label - 6f) to cell.height
            Face.WideRows -> (cell.width - captionWidth - 8f) to (cell.height - labelLine - 2f)
            Face.MediumHero -> {
                // The caption stands one word per line to the right of a rule.
                (cell.width - 2 * 14f - HAIRLINE_DP - longestCaption * CAPTION_CHARACTER_EMS * caption) to
                    (cell.height - labelLine - 4f)
            }
            Face.LargeHero -> cell.width to (cell.height - labelLine - captionLine - 6f - 2 * 14f - HAIRLINE_DP)
            Face.SmallHero -> cell.width to (cell.height - labelLine - captionLine - 4f)
            else -> cell.width to (cell.height - labelLine - captionLine - 2f)
        }
        val gap = if (timeWidths.meridiemEms > 0f) MERIDIEM_GAP_DP else 0f
        val fitAcross = (widthForTime - gap) / (timeWidths.digitsEms + timeWidths.meridiemEms)
        val fitDown = heightForTime / NUMERAL_LINE_EMS
        val time = floor(min(designed.time * scaleFactor, min(fitAcross, fitDown))).coerceAtLeast(10f)
        return TypeSizes(label, time, caption)
    }
}
