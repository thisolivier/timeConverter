package dev.thisolivier.timeconverter

import dev.thisolivier.timeconverter.SavedCitiesWidgetSizing.Face
import dev.thisolivier.timeconverter.SavedCitiesWidgetSizing.SizeDp
import dev.thisolivier.timeconverter.SavedCitiesWidgetSizing.TimeWidths
import dev.thisolivier.timeconverter.core.worldclock.WidgetLayoutPlan
import dev.thisolivier.timeconverter.core.worldclock.WidgetLayoutPlan.Family
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The widget's dp arithmetic (item 36b): faces, cell sizes, and the numeral fitting its narrowest cell. */
class SavedCitiesWidgetSizingTests {
    // Roughly Roboto Condensed Bold: `12:38` ≈ 2.2 em, ` AM` at 0.4 ≈ 0.55 em.
    private val twelveHourWidths = TimeWidths(digitsEms = 2.2f, meridiemEms = 0.55f)
    private val twentyFourHourWidths = TimeWidths(digitsEms = 2.2f, meridiemEms = 0f)

    /** `LOS ANGELES` or a four-letter code; `8 hours behind`. */
    private fun sizes(family: Family, count: Int, widths: TimeWidths = twelveHourWidths, size: SizeDp? = null): SavedCitiesWidgetSizing.TypeSizes {
        val plan = WidgetLayoutPlan.plan(family, count)
        return SavedCitiesWidgetSizing.typeSizes(
            plan = plan,
            widgetSize = size ?: SavedCitiesWidgetSizing.nominalSize(family),
            timeWidths = widths,
            longestLabel = if (plan.nameStyle == WidgetLayoutPlan.NameStyle.Code) 4 else 11,
            longestCaption = 14,
        )
    }

    @Test
    fun theFaceFollowsThePlan() {
        fun face(family: Family, count: Int) = SavedCitiesWidgetSizing.face(WidgetLayoutPlan.plan(family, count))
        assertEquals(Face.Empty, face(Family.Medium, 0))
        assertEquals(Face.SmallHero, face(Family.Small, 1))
        assertEquals(Face.MediumHero, face(Family.Medium, 1))
        assertEquals(Face.LargeHero, face(Family.Large, 1))
        assertEquals(Face.CodeRows, face(Family.Small, 3))
        assertEquals(Face.Grid, face(Family.Small, 4))
        assertEquals(Face.Grid, face(Family.Medium, 3))
        assertEquals(Face.WideRows, face(Family.Large, 2))
        assertEquals(Face.Grid, face(Family.Large, 6))
    }

    @Test
    fun theLauncherSizeFallsBackToNominalUntilReported() {
        assertEquals(SizeDp(150f, 150f), SavedCitiesWidgetSizing.launcherSize(Family.Small, 0, 0))
        assertEquals(SizeDp(320f, 330f), SavedCitiesWidgetSizing.launcherSize(Family.Large, 320, 0))
        assertEquals(SizeDp(180f, 190f), SavedCitiesWidgetSizing.launcherSize(Family.Small, 180, 190))
    }

    @Test
    fun cellsShareTheWidgetLessPaddingAndHairlines() {
        val plan = WidgetLayoutPlan.plan(Family.Medium, 6) // 3 × 2
        val cell = SavedCitiesWidgetSizing.cellContentSize(plan, SizeDp(320f, 150f))
        // The middle cell pads both sides: (320 − 2×16 − 2 hairlines) / 3 − 2×8 = 79.33; (150 − 2×12 − 1) / 2 − 2×3 = 56.5
        assertEquals(79.33f, cell.width, 0.01f)
        assertEquals(56.5f, cell.height, 0.01f)
        // Two columns: each cell pads only its hairline side. (150 − 2×12 − 1) / 2 − 5 = 57.5
        val smallGrid = SavedCitiesWidgetSizing.cellContentSize(WidgetLayoutPlan.plan(Family.Small, 6), SizeDp(150f, 150f))
        assertEquals(57.5f, smallGrid.width, 0.01f)
    }

    @Test
    fun theWidestTwelveHourTimeFitsTheNarrowestCellOfEveryFace() {
        for (family in Family.entries) for (count in 1..6) {
            val plan = WidgetLayoutPlan.plan(family, count)
            val face = SavedCitiesWidgetSizing.face(plan)
            if (face != Face.Grid && face != Face.SmallHero && face != Face.LargeHero) continue
            val numeral = sizes(family, count).time
            val timeWidth = numeral * (twelveHourWidths.digitsEms + twelveHourWidths.meridiemEms) + SavedCitiesWidgetSizing.MERIDIEM_GAP_DP
            val cellWidth = SavedCitiesWidgetSizing.cellContentSize(plan, SavedCitiesWidgetSizing.nominalSize(family)).width
            assertTrue("$family $count: $timeWidth > $cellWidth", timeWidth <= cellWidth)
        }
    }

    @Test
    fun twentyFourHourNumeralsAreNeverSmallerThanTwelveHourOnes() {
        for (family in Family.entries) for (count in 1..6) {
            assertTrue(sizes(family, count, twentyFourHourWidths).time >= sizes(family, count).time)
        }
    }

    @Test
    fun theHeroNumeralIsTheBiggestInItsFamily() {
        // Not monotonic beyond that: dropping captions (medium, 5–6) frees height for the numeral.
        for (family in Family.entries) {
            val hero = sizes(family, 1).time
            val others = (2..6).map { sizes(family, it).time }
            assertTrue("$family $hero vs $others", others.all { it < hero })
        }
    }

    @Test
    fun aBiggerPlacementScalesTheTypeUpWithinBounds() {
        val nominal = sizes(Family.Small, 1)
        val bigger = sizes(Family.Small, 1, size = SizeDp(200f, 200f))
        assertTrue(bigger.label > nominal.label)
        assertTrue(bigger.time >= nominal.time)
        assertEquals(1.4f, SavedCitiesWidgetSizing.scale(Family.Small, SizeDp(600f, 600f)), 0f)
        assertEquals(0.8f, SavedCitiesWidgetSizing.scale(Family.Small, SizeDp(60f, 60f)), 0f)
    }

    @Test
    fun theMeridiemIsSmallerButLegible() {
        val gridSizes = sizes(Family.Small, 6)
        assertTrue(gridSizes.meridiem < gridSizes.time)
        assertTrue(gridSizes.meridiem >= 8f)
    }
}
