package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.festival.*
import de.leongeorgi.rudolstadt.interop.CoreBridge
import kotlin.test.*
import kotlinx.serialization.json.*

class ProgramEditorialContentTests {
    private val content =
        ProgramEditorialContent(
            ProgramContent(mapOf("de" to "Gemeinsam musizieren", "en" to "Play music together")),
            listOf(
                ProgramInformationField(
                    "equipment",
                    mapOf("de" to "Mitbringen", "en" to "Bring along"),
                    mapOf("de" to "Eigenes Instrument", "en" to "Your own instrument"),
                )
            ),
            listOf(
                ProgramLink("details", mapOf("en" to "Details"), "https://example.com/workshop")
            ),
        )

    private fun program(editorial: ProgramEditorialContent? = content): FestivalProgram {
        val artist =
            ProgramArtist(
                1,
                "Band",
                false,
                ProgramArtistDetails(ProgramContent(mapOf("en" to "Biography"))),
            )
        val place = ProgramPlace("n:2", mapOf("en" to "Stage"))
        val tag =
            ProgramTag(
                "3",
                mapOf("de" to "Workshop"),
                mapOf("en" to "Supplied introduction"),
                editorialContent = editorial,
            )
        val event =
            ProgramOccurrence(
                4,
                null,
                null,
                place,
                artist,
                listOf(tag),
            )
        return FestivalProgram(
            listOf(artist),
            emptyList(),
            listOf(place),
            listOf(event),
            0,
            2026,
            eventDetails =
                editorial?.let { EventDetailsFeature(listOf(EventDetailContent(4, it))) },
        )
    }

    @Test
    fun featureOwnsEventContentIndependentlyOfArtistDescriptions() {
        val program = program()
        assertEquals(content, program.eventDetails!!.details(4))
        assertNotEquals(
            program.events.single().artist.content.descriptions,
            program.eventDetails.details(4)?.article,
        )
        assertNull(program.eventDetails.details(999))
    }

    @Test
    fun featureAndCategoryContentSurviveNormalizedCache() {
        val bridge = CoreBridge()
        val original = program()
        val restored = bridge.decodeProgram(bridge.encodeProgram(original))
        assertEquals(original, restored)
        assertEquals(content, restored.eventDetails!!.details(4))
        assertEquals(content, restored.events.single().tags.single().editorialContent)
        assertSame(restored.artists.single(), restored.events.single().artist)
    }

    @Test
    fun disabledAndEnabledButEmptyFeaturesRemainDistinct() {
        val bridge = CoreBridge()
        val disabled = program(null)
        val enabled = disabled.copy(eventDetails = EventDetailsFeature())
        assertNull(bridge.decodeProgram(bridge.encodeProgram(disabled)).eventDetails)
        assertEquals(enabled, bridge.decodeProgram(bridge.encodeProgram(enabled)))
        assertNull(enabled.eventDetails!!.details(4))
        assertTrue(ProgramPreparation.valid(enabled, emptyList()))
    }

    @Test
    fun tagsAndCategoryContentDoNotEnableConcertDetails() {
        val program = program().copy(eventDetails = null)
        assertTrue(program.events.single().tags.single().editorialContent!!.hasContent)
        val prepared =
            PreparedProgram(
                program,
                emptyList(),
                emptyList(),
                emptyList(),
                emptyList(),
                emptyMap(),
                emptyList(),
                program.events.single().tags,
            )
        val capabilities =
            ProgramCatalogs.build(
                prepared,
                de.leongeorgi.rudolstadt.planning.WalkingDistanceMatrix(emptyMap()),
                emptyList(),
                null,
                false,
                false,
                false,
            )
        assertNull(capabilities.eventDetails)
        assertEquals("3", prepared.tags.single().tagID)
    }

    @Test
    fun unknownAndDuplicateEventDetailsAreRejectedAtImportAndExport() {
        val bridge = CoreBridge()
        val original = program()
        for (entries in
            listOf(
                listOf(EventDetailContent(999, content)),
                listOf(EventDetailContent(4, content), EventDetailContent(4, content)),
            )) {
            val invalid = original.copy(eventDetails = EventDetailsFeature(entries))
            assertFalse(ProgramPreparation.valid(invalid, emptyList()))
            assertFails { bridge.encodeProgram(invalid) }
            val cache =
                Json.parseToJsonElement(bridge.encodeProgram(original)).jsonObject.toMutableMap()
            cache["eventDetails"] = Json.encodeToJsonElement(EventDetailsFeature(entries))
            assertFails { bridge.decodeProgram(JsonObject(cache).toString()) }
        }
    }

    @Test
    fun legacyInlineContentMigratesIntoAnExplicitFeature() {
        val bridge = CoreBridge()
        val cache =
            Json.parseToJsonElement(bridge.encodeProgram(program(null))).jsonObject.toMutableMap()
        cache.remove("formatVersion")
        cache.remove("eventDetails")
        val event = cache.getValue("events").jsonArray.single().jsonObject.toMutableMap()
        event["editorialContent"] = Json.encodeToJsonElement(content)
        cache["events"] = JsonArray(listOf(JsonObject(event)))
        val restored = bridge.decodeProgram(JsonObject(cache).toString())
        assertEquals(content, restored.eventDetails!!.details(4))
        val current = Json.parseToJsonElement(bridge.encodeProgram(restored)).jsonObject
        assertEquals(2, current.getValue("formatVersion").jsonPrimitive.int)
        assertEquals(restored, bridge.decodeProgram(current.toString()))
    }

    @Test
    fun currentCachesCannotBypassTheFeatureWithInlineContent() {
        val bridge = CoreBridge()
        val cache =
            Json.parseToJsonElement(bridge.encodeProgram(program(null))).jsonObject.toMutableMap()
        val event = cache.getValue("events").jsonArray.single().jsonObject.toMutableMap()
        event["editorialContent"] = Json.encodeToJsonElement(content)
        cache["events"] = JsonArray(listOf(JsonObject(event)))
        assertFails { bridge.decodeProgram(JsonObject(cache).toString()) }
    }

    @Test
    fun oldCachesWithoutContentKeepTheFeatureDisabled() {
        val bridge = CoreBridge()
        val cache =
            Json.parseToJsonElement(bridge.encodeProgram(program(null))).jsonObject.toMutableMap()
        cache.remove("formatVersion")
        cache.remove("eventDetails")
        assertNull(bridge.decodeProgram(JsonObject(cache).toString()).eventDetails)
    }

    @Test
    fun suppliedCategoryContentAndIntroductionSurviveFestivalPolicy() {
        val event = program().events.single()
        val tags =
            ProgramPreparation.tags(
                listOf(event),
                ProgramTagPolicy(
                    listOf("Workshop"),
                    emptySet(),
                    emptyMap(),
                    mapOf("Workshop" to mapOf("en" to "Fallback")),
                ),
            )
        assertEquals("Supplied introduction", tags.single().introductionTexts?.get("en"))
        assertEquals(content, tags.single().editorialContent)
    }

    @Test
    fun metadataEnrichmentPreservesTheFeatureAndNeverEnablesItForTags() {
        val original = program()
        val enriched =
            ProgramPreparation.enrich(
                original,
                emptyList(),
                "Europe/Berlin",
                "en",
                emptyList(),
                emptyList(),
                listOf(EventMetadata(4, emptyList())),
                emptyList(),
            )
        assertSame(original.eventDetails, enriched.eventDetails)
        assertTrue(enriched.events.single().tags.isEmpty())
        assertTrue(original.events.single().tags.isNotEmpty())
        val disabled =
            ProgramPreparation.enrich(
                program(null),
                emptyList(),
                "Europe/Berlin",
                "en",
                emptyList(),
                emptyList(),
                listOf(EventMetadata(4, original.events.single().tags)),
                emptyList(),
            )
        assertNull(disabled.eventDetails)
    }

    @Test
    fun emptyEditorialDataIsOptionalWhileFieldsOrLinksCanStandAlone() {
        assertFalse(ProgramEditorialContent().hasContent)
        assertFalse(ProgramEditorialContent(ProgramContent(mapOf("en" to "  "))).hasContent)
        assertFalse(
            ProgramEditorialContent(
                    fields =
                        listOf(ProgramInformationField("empty", mapOf("en" to "Bring"), emptyMap()))
                )
                .hasContent
        )
        assertTrue(ProgramEditorialContent(fields = content.fields).hasContent)
        assertTrue(ProgramEditorialContent(links = content.links).hasContent)
    }
}
