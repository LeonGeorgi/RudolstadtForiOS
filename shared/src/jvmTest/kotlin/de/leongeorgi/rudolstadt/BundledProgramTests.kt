package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.discovery.CountryParser
import de.leongeorgi.rudolstadt.festival.BundledSources
import de.leongeorgi.rudolstadt.festival.FestivalDefinitions
import de.leongeorgi.rudolstadt.festival.RudolstadtSource
import java.text.Normalizer
import kotlin.test.*
import kotlinx.serialization.json.*

class BundledProgramTests {
    private fun resource(name: String): String =
        requireNotNull(javaClass.getResourceAsStream("/$name")).bufferedReader().use {
            it.readText()
        }

    @Test
    fun everyArchiveLoadsWithoutLosingEntities() {
        FestivalDefinitions.archiveYears.forEach { year ->
            val source = resource("FestivalBackup/${year}_archive.json")
            val expected = Json.parseToJsonElement(source).jsonObject
            val result = BundledSources.archive(source, year)
            assertNull(result.error, "Archive $year")
            val program = assertNotNull(result.program)
            assertEquals(expected.getValue("events").jsonArray.size, program.events.size)
            assertEquals(expected.getValue("artists").jsonArray.size, program.artists.size)
            assertTrue(program.events.all { it.start != null })
        }
    }

    @Test
    fun ludwigsburgRetainsStable64BitEventIDsAndPublishedDurations() {
        val result = BundledSources.ludwigsburg(resource("FestivalBackup/ludwigsburg_2026.json"))
        assertNull(result.error)
        val program = assertNotNull(result.program)
        assertEquals(37, program.artists.size)
        assertEquals(219, program.events.size)
        assertTrue(program.events.any { it.id > Int.MAX_VALUE })
        assertTrue(program.events.all { it.duration != null && it.duration > 0 })
        assertEquals(136107827955517L, program.events.first().id)
    }

    @Test
    fun currentProgramKeepsReferencesAndLossAccounting() {
        val source =
            Json.parseToJsonElement(resource("FestivalBackup/2026_rudolstadt_data.json")).jsonObject
        val extra = Json.parseToJsonElement(resource("extra_data.json")).jsonObject
        val program = RudolstadtSource(2026).convert(source, extra)
        assertTrue(program.events.isNotEmpty())
        assertTrue(
            program.events.all { event ->
                program.artists.any { it.id == event.artist } &&
                    program.places.any { it.id == event.stage }
            }
        )
        assertTrue(program.omittedRecordCount >= 0)
    }

    @Test
    fun countryParserRetainsFestivalAliasesAndUKNations() {
        val parser = CountryParser {
            Normalizer.normalize(it, Normalizer.Form.NFKD).replace(Regex("\\p{M}+"), "").lowercase()
        }
        assertEquals(listOf("DEU", "USA"), parser.parse("Deutschland / USA"))
        assertEquals(
            listOf("ENG", "SCO"),
            parser.parse("England / Scotland", preservingUKNations = true),
        )
        assertEquals("🇺🇸", CountryParser.flag("USA"))
    }
}
