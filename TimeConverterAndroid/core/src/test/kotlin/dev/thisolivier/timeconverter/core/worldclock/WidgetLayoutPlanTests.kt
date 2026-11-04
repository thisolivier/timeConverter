package dev.thisolivier.timeconverter.core.worldclock

import dev.thisolivier.timeconverter.core.engine.ZoneLabel
import dev.thisolivier.timeconverter.core.worldclock.WidgetLayoutPlan.CaptionStyle
import dev.thisolivier.timeconverter.core.worldclock.WidgetLayoutPlan.Family
import dev.thisolivier.timeconverter.core.worldclock.WidgetLayoutPlan.NameStyle
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Item 36b — mirrors Swift `WidgetLayoutPlanTests`. */
class WidgetLayoutPlanTests {
    private fun shape(family: Family, count: Int) = WidgetLayoutPlan.plan(family, count).let { Triple(it.columnCount, it.rowCount, it.nameStyle to it.captionStyle) }

    @Test
    fun `the brief's table`() {
        assertEquals(Triple(1, 3, NameStyle.Code to CaptionStyle.None), shape(Family.Small, 3))
        assertEquals(Triple(2, 2, NameStyle.Code to CaptionStyle.None), shape(Family.Small, 4))
        assertEquals(Triple(2, 3, NameStyle.Code to CaptionStyle.None), shape(Family.Small, 6))
        assertEquals(Triple(3, 1, NameStyle.Full to CaptionStyle.Short), shape(Family.Medium, 3))
        assertEquals(Triple(2, 2, NameStyle.Full to CaptionStyle.Short), shape(Family.Medium, 4))
        assertEquals(Triple(3, 2, NameStyle.Full to CaptionStyle.None), shape(Family.Medium, 6))
        assertEquals(Triple(1, 3, NameStyle.Full to CaptionStyle.Full), shape(Family.Large, 3))
        assertEquals(Triple(2, 2, NameStyle.Full to CaptionStyle.Full), shape(Family.Large, 4))
        assertEquals(Triple(2, 3, NameStyle.Full to CaptionStyle.Short), shape(Family.Large, 6))
    }

    @Test
    fun `one city is a hero, seven are capped at six, five span the last row`() {
        for (family in Family.entries) assertTrue(WidgetLayoutPlan.plan(family, 1).isHero)
        assertEquals(6, WidgetLayoutPlan.plan(Family.Large, 9).cityCount)
        assertTrue(WidgetLayoutPlan.plan(Family.Large, 5).lastCellSpansRow)
        assertFalse(WidgetLayoutPlan.plan(Family.Large, 6).lastCellSpansRow)
        assertEquals(listOf(listOf(1, 2), listOf(3, 4), listOf(5)), WidgetLayoutPlan.plan(Family.Large, 5).rows((1..9).toList()))
    }

    @Test
    fun `short names are curated, cut or the code`() {
        assertEquals("LA", ShortPlaceNames.shortName(ZoneLabel.Place("Los Angeles", false), "Los Angeles"))
        assertEquals("KATH", ShortPlaceNames.shortName(ZoneLabel.Place("Kathmandu", false), "Kathmandu"))
        assertEquals("PORT", ShortPlaceNames.shortName(ZoneLabel.Place("Portland, Oregon", false), "Portland"))
        assertEquals("ET", ShortPlaceNames.shortName(ZoneLabel.Abbreviation("ET", "Eastern Time"), "ET"))
        assertEquals("ATL", ShortPlaceNames.shortName(ZoneLabel.Place("Atlantis", false), "Atlantis"))
        assertTrue(ShortPlaceNames.bundledNames.size > 3000, "short-names.json missing from the classpath?")
    }
}
