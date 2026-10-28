package dev.thisolivier.timeconverter.core.parsing

import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** The five-step chain: which resolver answers, and what more than one meaning does. Mirrors Swift `ZoneResolverChainTests`. */
class ZoneResolverChainTests {
    private val chain = ZoneResolverChain.standard

    @Test
    fun `the chain is the five specified resolvers in order`() {
        assertEquals(
            listOf(
                ZoneMatchSource.AliasTable, ZoneMatchSource.FoundationAbbreviation, ZoneMatchSource.TimeZoneDatabaseCity,
                ZoneMatchSource.CountryTable, ZoneMatchSource.OfflineFallbackList,
            ),
            chain.resolvers.map { it.matchSource },
        )
    }

    @Test
    fun `each token resolves through the expected step, earlier steps shadowing later ones`() {
        val expectations = listOf(
            Triple("et", "America/New_York", ZoneMatchSource.AliasTable),
            Triple("uk", "Europe/London", ZoneMatchSource.AliasTable),
            Triple("cet", "Europe/Paris", ZoneMatchSource.AliasTable),
            Triple("pst", "America/Los_Angeles", ZoneMatchSource.FoundationAbbreviation),
            Triple("gmt", "GMT", ZoneMatchSource.FoundationAbbreviation),
            Triple("ict", "Asia/Bangkok", ZoneMatchSource.FoundationAbbreviation),
            Triple("london", "Europe/London", ZoneMatchSource.TimeZoneDatabaseCity),
            Triple("new york", "America/New_York", ZoneMatchSource.TimeZoneDatabaseCity),
            Triple("mcmurdo", "Antarctica/McMurdo", ZoneMatchSource.TimeZoneDatabaseCity),
            Triple("buenos aires", "America/Argentina/Buenos_Aires", ZoneMatchSource.TimeZoneDatabaseCity),
            Triple("japan", "Asia/Tokyo", ZoneMatchSource.CountryTable),
            Triple("south africa", "Africa/Johannesburg", ZoneMatchSource.CountryTable),
            Triple("portugal", "Europe/Lisbon", ZoneMatchSource.CountryTable),
            Triple("argentina", "America/Argentina/Buenos_Aires", ZoneMatchSource.CountryTable),
            Triple("porto", "Europe/Lisbon", ZoneMatchSource.OfflineFallbackList),
            Triple("manchester", "Europe/London", ZoneMatchSource.OfflineFallbackList),
            Triple("bangkok", "Asia/Bangkok", ZoneMatchSource.TimeZoneDatabaseCity),
        )
        for ((token, identifier, source) in expectations) {
            val zone = assertIs<ZoneResolution.Resolved>(chain.resolve(token), token).zone
            assertEquals(identifier, zone.zone.id, token)
            assertEquals(source, zone.matchSource, token)
            assertEquals(token, zone.originalToken)
        }
    }

    @Test
    fun `legacy country and alias identifiers are not indexed as cities`() {
        val legacy = listOf(
            "portugal", "japan", "gb", "eire", "turkey", "egypt", "iceland", "poland", "israel", "cuba",
            "iran", "libya", "prc", "roc", "rok", "nz", "hongkong", "uct", "universal", "zulu",
            // tzdata backward links java.time carries and Apple's list does not
            "nsw", "saigon", "dacca", "yap", "faeroe", "ujung pandang",
        )
        for (token in legacy) assertNull(TimeZoneDatabaseCityResolver.identifiersByCityName[token], token)
    }

    @Test
    fun `only real area-prefixed identifiers are city-bearing`() {
        assertTrue(TimeZoneDatabaseCityResolver.isCityBearing("Europe/London"))
        assertTrue(TimeZoneDatabaseCityResolver.isCityBearing("America/Argentina/Buenos_Aires"))
        for (identifier in listOf("Portugal", "Japan", "GB", "US/Pacific", "Canada/Eastern", "Etc/GMT+5")) {
            assertFalse(TimeZoneDatabaseCityResolver.isCityBearing(identifier), identifier)
        }
        assertTrue(TimeZoneDatabaseCityResolver.identifiersByCityName.values.flatten().all { it.contains('/') })
    }

    @Test
    fun `no city name collides, so step 3 never prompts on this tz database`() {
        val collisions = TimeZoneDatabaseCityResolver.identifiersByCityName.filterValues { it.size > 1 }
        assertTrue(collisions.isEmpty(), "$collisions")
    }

    @Test
    fun `cst and ist are ambiguous in curated order, overriding step 2`() {
        val cst = assertIs<ZoneResolution.Ambiguous>(chain.resolve("cst")).candidates
        assertEquals(listOf("America/Chicago", "Asia/Shanghai"), cst.map { it.timeZoneIdentifier })
        assertTrue(cst.all { it.matchSource == ZoneMatchSource.AliasTable })
        val ist = assertIs<ZoneResolution.Ambiguous>(chain.resolve("ist")).candidates
        assertEquals(listOf("Asia/Kolkata", "Europe/Dublin"), ist.map { it.timeZoneIdentifier })
    }

    @Test
    fun `usa offers the six primary zones and the no-clock countries all prompt`() {
        val usa = assertIs<ZoneResolution.Ambiguous>(chain.resolve("usa")).candidates
        assertEquals(
            listOf("America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles", "America/Anchorage", "Pacific/Honolulu"),
            usa.map { it.timeZoneIdentifier },
        )
        for (country in listOf("australia", "brazil", "canada", "russia", "mexico", "antarctica")) {
            assertTrue(assertIs<ZoneResolution.Ambiguous>(chain.resolve(country), country).candidates.size > 1)
        }
    }

    @Test
    fun `every country entry is canonical with one zone or prompts with several`() {
        for ((country, zones) in CountryZoneTable.zonesByCountryName) {
            when (zones) {
                is CountryZones.Canonical -> assertEquals(1, zones.candidateIdentifiers.size, country)
                is CountryZones.NoCanonicalClock -> assertTrue(zones.candidateIdentifiers.size > 1, country)
            }
        }
    }

    @Test
    fun `unrecognised tokens are unknown`() {
        for (token in listOf("narnia", "zzz", "atlantis", "")) assertEquals(ZoneResolution.Unknown, chain.resolve(token))
    }

    @Test
    fun `an abbreviation the tables expand is labelled as one, an uncurated one is a place`() {
        val et = assertIs<ZoneResolution.Resolved>(chain.resolve("east coast")).zone
        assertEquals("In East Coast (Eastern Time)", et.label.headerDescription)
        assertEquals(listOf("New York", "Toronto"), et.representativeCities)
        val ict = assertIs<ZoneResolution.Resolved>(chain.resolve("ict")).zone
        assertEquals("In Bangkok", ict.label.headerDescription)
    }

    @Test
    fun `every table identifier and every snapshot abbreviation is a valid java time zone`() {
        val identifiers = AliasZoneTable.meaningsByAlias.values.flatten().map { it.timeZoneIdentifier } +
            CountryZoneTable.zonesByCountryName.values.flatMap { it.candidateIdentifiers } +
            OfflineFallbackGazetteer.bundledEntries.values.flatten() +
            FoundationAbbreviationSnapshot.identifiersByAbbreviation.values
        for (identifier in identifiers) ZoneId.of(identifier)
        assertTrue(AliasZoneTable.meaningsByAlias.keys.all { it == it.lowercase() })
        assertTrue(CountryZoneTable.zonesByCountryName.keys.all { it == it.lowercase() })
    }
}
