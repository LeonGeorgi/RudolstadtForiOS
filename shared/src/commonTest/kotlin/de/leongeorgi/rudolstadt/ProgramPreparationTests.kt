package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.discovery.CuratedArtistLinks
import de.leongeorgi.rudolstadt.festival.*
import kotlin.test.*
import kotlinx.serialization.json.*

class ProgramPreparationTests {
    @Test
    fun supplementalDataAndTaxonomyKeepTheirExternalWireKeys() {
        val bridge = de.leongeorgi.rudolstadt.interop.CoreBridge()
        val extra =
            bridge.decodeProgramExtras(
                """{"data":{"Band":{"en":{"summary":"Summary"},"browse_genres":["folk"]}}}"""
            )
        val source =
            """{"areas":[],"artists":[{"id":11,"name":"Band"}],"events":[],"stages":[],"tags":[]}"""
        val program =
            bridge.programFromRudolstadtPayload(
                bridge.decodeRudolstadtPayload(source),
                extra,
                2026,
            ) {
                it
            }
        assertEquals("Summary", program.artists.single().summaries.single().text)
        assertEquals(listOf("folk"), program.artists.single().groups["genre"])
        assertEquals(extra.sourceJSON, bridge.decodeProgramExtras(extra.sourceJSON).sourceJSON)
        val entry =
            bridge
                .decodeBrowseTaxonomy(
                    """[{"id":"folk","label_de":"Folk","label_en":"Folk music"}]"""
                )
                .single()
        assertEquals("Folk music", entry.group().titles["en"])
        assertFails { bridge.decodeProgramExtras("{\"data\":null}") }
        assertFails { bridge.decodeBrowseTaxonomy("[{\"id\":1}]") }
    }

    @Test
    fun batchedEnrichmentRetargetsEventsWithoutMutatingExistingObjects() {
        val prepared = prepare()
        val original = prepared.program
        val artist = original.artists.single()
        val place = original.places.single()
        val content = artist.content.copy(previewKind = "disabled")
        val changed =
            ProgramPreparation.enrich(
                original,
                prepared.days.map { OccurrenceDay(it) },
                "Europe/Berlin",
                "fr",
                listOf(
                    ArtistMetadata(
                        artist.artistID,
                        content,
                        mapOf("custom" to listOf("folk")),
                        emptyList(),
                    )
                ),
                listOf(
                    PlaceMetadata(
                        place.placeKey,
                        ProgramContent(mapOf("fr" to "Cour")),
                        null,
                        null,
                        null,
                        null,
                    )
                ),
                listOf(EventMetadata(original.events.first().eventID, emptyList())),
                emptyList(),
            )
        assertSame(changed.artists.single(), changed.events.first().artist)
        assertSame(changed.places.single(), changed.events.first().stage)
        assertEquals("Cour", changed.events.first().stage.descriptions?.texts?.get("fr"))
        assertEquals("disabled", changed.events.first().artist.content.previewKind)
        assertTrue(changed.events.first().tags.isEmpty())
        assertNull(changed.places.single().admission)
        assertNull(changed.places.single().area)
        assertEquals("automatic", artist.content.previewKind)
        assertEquals("de", place.defaultLanguage)
        assertTrue(original.events.first().tags.isNotEmpty())
    }

    private val empty = "{\"areas\":[],\"artists\":[],\"events\":[],\"stages\":[],\"tags\":[]}"
    private val policy = ProgramTagPolicy(null, emptySet(), emptyMap(), emptyMap())

    @Test
    fun wireRecordsAndLossCountsSurviveRepeatedDiskRoundTrips() {
        val input =
            empty.replace(
                "\"events\":[]",
                "\"events\":[{\"id\":9007199254740993},{\"id\":42},{\"id\":42},{\"id\":0},{\"id\":-1},{\"id\":\"bad\"},null,17]",
            )
        var payload = RudolstadtPayloads.decode(input)
        repeat(3) {
            assertEquals(7, payload.omittedRecordCount)
            val program = ProgramModels {
                it
            }
                .program(RudolstadtSource(2026).convert(payload, JsonObject(emptyMap())))
            val event = program.events.single()
            assertEquals(9007199254740993L, event.eventID)
            assertNull(event.startTimestamp)
            assertFalse(event.artist.isMetadataAvailable)
            assertFalse(event.stage.isMetadataAvailable)
            assertEquals(7, program.omittedRecordCount)
            payload = RudolstadtPayloads.decode(payload.sourceJSON)
        }
    }

    @Test
    fun invalidStructuresFailWhileMalformedIndividualRecordsAreCounted() {
        for (json in
            listOf(
                "{",
                "[]",
                "{}",
                empty.replace("\"events\":[]", "\"events\":{}"),
                empty.dropLast(1) + ",\"omittedRecordCount\":\"invalid\"}",
            )) {
            assertFails { RudolstadtPayloads.decode(json) }
        }
        assertFails { RudolstadtPayloads.records("events", "{}") }
        val areas =
            RudolstadtPayloads.records(
                "areas",
                "[{\"id\":1},null,{\"id\":2,\"title\":\"Park\",\"title_en\":\"Park\"}]",
            )
        val payload =
            RudolstadtPayloads.assemble(
                areas,
                RudolstadtPayloads.records("artists", "[]"),
                RudolstadtPayloads.records("events", "[]"),
                RudolstadtPayloads.records("stages", "[]"),
                RudolstadtPayloads.records("tags", "[]"),
            )
        assertEquals(2, payload.omittedRecordCount)
        assertEquals(
            1,
            Json.parseToJsonElement(payload.sourceJSON).jsonObject.getValue("areas").jsonArray.size,
        )
    }

    private fun source(): FestivalProgram {
        val artist =
            ProgramArtist(
                11,
                "Band",
                false,
                ProgramArtistDetails(ProgramContent(mapOf("de" to "Beschreibung"))),
                groups = mapOf("artist-kind" to listOf("1")),
            )
        val area = ProgramArea(1, mapOf("de" to "Park"))
        val place =
            ProgramPlace(
                "n:22",
                mapOf("de" to "Bühne"),
                latitude = 50.72,
                longitude = 11.34,
                area = area,
                typeCode = 2,
            )
        val time = FestivalTime.parse("2026-07-04 01:30", "yyyy-MM-dd HH:mm", "Europe/Berlin")!!
        val tags =
            listOf(
                ProgramTag("10", mapOf("de" to "Workshop")),
                ProgramTag("2", mapOf("de" to "Musik")),
            )
        val events =
            listOf(
                ProgramOccurrence(31, time, time, place, artist, tags),
                ProgramOccurrence(
                    32,
                    time + 3600,
                    time,
                    place,
                    artist,
                    emptyList(),
                    EventDuration(45, false),
                ),
            )
        return FestivalProgram(listOf(artist), listOf(area), listOf(place), events, 3, 2026)
    }

    private fun prepare(
        program: FestivalProgram = source(),
        areas: Boolean = true,
        admission: Boolean = true,
        music: Map<String, CuratedArtistLinks> = emptyMap(),
        extras: List<ProgramSupplementaryPlace> = emptyList(),
        tagPolicy: ProgramTagPolicy = policy,
        earliest: String? = null,
    ): PreparedProgram =
        ProgramPreparation.prepare(
            program,
            "Europe/Berlin",
            5,
            earliest,
            "de",
            areas,
            admission,
            music,
            listOf(ProgramGroup("folk", mapOf("de" to "Folk"))),
            extras,
            emptyList(),
            tagPolicy,
            { it.lowercase() },
            { value, absolute -> value.takeIf { !absolute || it.startsWith("https:") } },
        )

    @Test
    fun completeProgramUsesSharedCatalogReferencesAndPreservesPublishedDurations() {
        val original = source()
        val prepared = prepare(original)
        val program = prepared.program
        assertEquals("2026-07-03", prepared.days.single().id)
        assertEquals("de", program.artists.single().defaultLanguage)
        assertEquals(EventDuration(60, true), program.events.first().eventDuration)
        assertEquals(EventDuration(45, false), program.events.last().eventDuration)
        assertSame(program.artists.single(), program.events.first().artist)
        assertSame(program.places.single(), program.events.first().stage)
        assertEquals("2", program.places.single().admission?.categoryID)
        assertEquals(listOf("artist-kind", "genre"), prepared.groupings.map { it.groupingID })
        assertEquals(3, program.omittedRecordCount)
        assertNull(original.artists.single().defaultLanguage)
        assertNull(original.events.first().eventDuration)
        assertTrue(ProgramPreparation.valid(program, prepared.days))
    }

    @Test
    fun musicSelectionAndTagRulesAreAppliedWithoutLosingOriginalContent() {
        val music = CuratedArtistLinks("https://spotify.example/band", "invalid", "disabled")
        val rule =
            ProgramTagPolicy(
                listOf("Workshop"),
                setOf("Musik"),
                mapOf("Workshop" to mapOf("fr" to "Atelier")),
                mapOf("Workshop" to mapOf("de" to "Einleitung")),
            )
        val prepared = prepare(music = mapOf("band" to music), tagPolicy = rule)
        val content = prepared.program.artists.single().content
        assertEquals("Beschreibung", content.descriptions.texts["de"])
        assertEquals("spotify", content.links.single().linkID)
        assertEquals("disabled", content.previewKind)
        assertEquals(listOf("10", "2"), prepared.tags.map { it.tagID })
        assertEquals("Atelier", prepared.tags.first().titles["fr"])
        assertFalse(prepared.tags.last().isDiscoverable)
        assertFalse(prepared.tags.last().showsOnTimeline)
        assertEquals(listOf("2", "10"), prepare().tags.map { it.tagID })
        assertSame(prepared.tags.first(), prepared.program.events.first().tags.first())
    }

    @Test
    fun supplementaryPlacesAndUnsupportedFeaturesDoNotInventAreasOrAdmission() {
        val extra =
            ProgramSupplementaryPlace(
                ProgramPlace("t:parking", mapOf("de" to "Parkplatz")),
                ProgramContent(mapOf("de" to "Hinweise")),
                PlanCoordinate(50.7, 11.3, true),
                ProgramCategory("parking", mapOf("de" to "Parken")),
            )
        val prepared = prepare(areas = false, admission = false, extras = listOf(extra))
        assertTrue(prepared.program.areas.isEmpty())
        assertTrue(prepared.admission.isEmpty())
        assertTrue(prepared.program.places.all { it.area == null && it.admission == null })
        assertEquals("parking", prepared.mapAssignments["t:parking"])
        assertTrue(
            prepared.coordinates.single { it.placeKey == "t:parking" }.coordinate.isApproximate
        )
        assertEquals("Hinweise", prepared.program.places.last().descriptions?.texts?.get("de"))
    }

    @Test
    fun unknownDatesAndMissingReferencesRemainUnknown() {
        val program = ProgramModels {
            it
        }
            .program(
                RudolstadtSource(2026)
                    .convert(
                        RudolstadtPayloads.decode(
                            empty.replace("\"events\":[]", "\"events\":[{\"id\":99}]")
                        ),
                        JsonObject(emptyMap()),
                    )
            )
        val prepared = prepare(program)
        assertTrue(prepared.days.isEmpty())
        assertTrue(prepared.program.places.isEmpty())
        val event = prepared.program.events.single()
        assertNull(event.assignedDay)
        assertNull(event.eventDuration)
        assertFalse(event.eligibleForPlanning)
        assertFalse(event.stage.isMetadataAvailable)
    }

    @Test
    fun invalidDurationsDuplicateIDsAndDayAssignmentsAreRejected() {
        val input = source()
        assertFails { prepare(input.copy(events = input.events + input.events.first())) }
        assertFails {
            prepare(
                input.copy(
                    events =
                        listOf(input.events.first().copy(eventDuration = EventDuration(0, false)))
                )
            )
        }
        assertTrue(prepare(earliest = "2026-07-04").program.events.all { it.assignedDay == null })
    }
}
