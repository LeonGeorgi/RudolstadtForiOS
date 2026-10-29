package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.festival.*
import de.leongeorgi.rudolstadt.interop.CoreBridge
import kotlin.test.*

class ProgramModelTests {
    private val largeID = 9_007_199_254_740_993L

    private fun program(): FestivalProgram = ProgramModels {
        it.lowercase()
    }
        .program(
            SourceProgram(
                listOf(
                    SourceArtist(
                        largeID,
                        "Band",
                        1,
                        countries = "Germany",
                        website = "https://example.com",
                        descriptionDE = "Beschreibung",
                        descriptionEN = "Description",
                        summaryDE = "Kurz",
                        tagsDE = listOf("Folk"),
                        genres = listOf("folk"),
                        flags = listOf("🇩🇪"),
                    )
                ),
                listOf(SourceArea(1, "Park", "Park")),
                listOf(SourcePlace(2, "Bühne", "Stage", area = 1, type = 1)),
                listOf(SourceEvent(largeID + 1, largeID, 2, tags = listOf(3), duration = 45)),
                listOf(SourceTag(3, "Tanz", "Dance")),
                omittedRecordCount = 2,
                year = 2026,
            )
        )

    @Test
    fun eventsRetainCatalogInstancesAndAllContent() {
        val program = program()
        val artist = program.artists.single()
        val event = program.events.single()
        assertSame(artist, event.artist)
        assertSame(program.places.single(), event.stage)
        assertSame(program.areas.single(), event.stage.area)
        assertEquals(largeID, artist.artistID)
        assertEquals(listOf("DEU"), artist.content.countryCodes)
        assertEquals("Description", artist.content.descriptions.texts["en"])
        assertEquals("https://example.com", artist.content.links.single().destination)
        assertEquals(listOf("Folk"), artist.content.keywords["de"])
        assertEquals(listOf("folk"), artist.groups["genre"])
        assertEquals("Kurz", artist.summaries.single().text)
        assertEquals("Dance", event.tags.single().titles["en"])
        assertEquals(EventDuration(45, false), event.eventDuration)
        assertEquals(2, program.omittedRecordCount)
    }

    @Test
    fun enrichingOneProgramCannotChangeAnotherReference() {
        val program = program()
        val old = program.events.single()
        val artist =
            old.artist.withMetadata(
                old.artist.content.copy(previewKind = "disabled"),
                old.artist.groups,
                old.artist.summaries,
                "de",
            )
        val event =
            old.withMetadata(
                old.stage,
                artist,
                old.tags,
                old.eventDuration,
                old.assignedDay,
                old.zoneID,
            )
        assertEquals("automatic", old.artist.content.previewKind)
        assertNull(old.artist.defaultLanguage)
        assertEquals("disabled", event.artist.content.previewKind)
        assertEquals("de", event.artist.defaultLanguage)
    }

    @Test
    fun diskRoundTripPreserves64BitIDsAndRestoresSharedReferences() {
        val bridge = CoreBridge()
        val restored = bridge.decodeProgram(bridge.encodeProgram(program()))
        assertEquals(largeID + 1, restored.events.single().eventID)
        assertSame(restored.artists.single(), restored.events.single().artist)
        assertSame(restored.places.single(), restored.events.single().stage)
        assertEquals(program(), restored)
    }

    @Test
    fun brokenCachedRelationshipsAreRecoverableErrors() {
        val bridge = CoreBridge()
        val json = bridge.encodeProgram(program())
        val broken = json.replace("\"artist\":$largeID", "\"artist\":99")
        assertNotEquals(json, broken)
        assertFailsWith<IllegalArgumentException> { bridge.decodeProgram(broken) }
    }

    @Test
    fun placesUseIdentityEqualityAfterEnrichment() {
        val place = program().places.single()
        val enriched =
            place.withMetadata(
                place.descriptions,
                50.72,
                11.34,
                place.area,
                "de",
                true,
                "A",
                null,
                null,
            )
        assertEquals(place, enriched)
        assertEquals(place.hashCode(), enriched.hashCode())
        assertEquals(1, setOf(place, enriched).size)
    }

    @Test
    fun filteringRetainsSharedObjectsAndUnplacedEventsWithoutCalendarWork() {
        val first = program().events.single().copy(eventID = 101, zoneID = "Invalid/Zone")
        val second = first.copy(eventID = 202, artist = first.artist.copy(artistID = 9))
        val events = listOf(second, first)
        val bridge = CoreBridge()
        fun filtered(filter: String) =
            bridge.filterOccurrences(
                events,
                filter,
                saved = setOf(101),
                positiveArtists = setOf(9),
                recommended = setOf(202),
            )
        assertEquals(listOf(202L, 101L), filtered("all").map { it.eventID })
        assertSame(second, filtered("all").first())
        assertSame(first, filtered("saved").single())
        assertEquals(events, filtered("interesting"))
        assertEquals(events, filtered("optimal"))
        assertNull(filtered("saved").single().startTimestamp)
    }

    @Test
    fun reusedZoneRulesPreserveDSTChangesAndIndependentTimeZones() {
        val before =
            assertNotNull(FestivalTime.parse("2026-10-25 00:30", "yyyy-MM-dd HH:mm", "UTC"))
        val after = assertNotNull(FestivalTime.parse("2026-10-25 01:30", "yyyy-MM-dd HH:mm", "UTC"))
        repeat(3) {
            assertEquals(2, FestivalTime.local(before, "Europe/Berlin").hour)
            assertEquals(2, FestivalTime.local(after, "Europe/Berlin").hour)
            assertEquals(9, FestivalTime.local(before, "Asia/Tokyo").hour)
            assertEquals(10, FestivalTime.local(after, "Asia/Tokyo").hour)
            assertEquals(0, FestivalTime.local(before, "UTC").hour)
            assertEquals(1, FestivalTime.local(after, "UTC").hour)
        }
    }
}
