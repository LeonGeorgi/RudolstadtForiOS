package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.festival.*
import de.leongeorgi.rudolstadt.interop.CoreBridge
import kotlin.test.*

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
                editorialContent = editorial,
            )
        return FestivalProgram(listOf(artist), emptyList(), listOf(place), listOf(event), 0, 2026)
    }

    @Test
    fun eventCatalogProvidesEventSpecificArticleFieldsAndLinks() {
        val event = program().events.single()
        val details = ProgramEventCatalog(listOf(event), event.tags).details(event.eventID)!!
        assertEquals(content.article, details.content)
        assertEquals(content.fields, details.informationFields)
        assertEquals(content.links, details.programLinks)
        assertNotEquals(event.artist.content.descriptions, details.content)
    }

    @Test
    fun editorialContentSurvivesNormalizedCacheAndSharedTagReferences() {
        val bridge = CoreBridge()
        val original = program()
        val restored = bridge.decodeProgram(bridge.encodeProgram(original))
        assertEquals(original, restored)
        assertEquals(content, restored.events.single().editorialContent)
        assertEquals(content, restored.events.single().tags.single().editorialContent)
        assertSame(restored.artists.single(), restored.events.single().artist)
    }

    @Test
    fun oldCachesRemainReadableWithoutEditorialFields() {
        val bridge = CoreBridge()
        val legacy = bridge.encodeProgram(program(null)).replace(",\"editorialContent\":null", "")
        assertFalse(legacy.contains("editorialContent"))
        val restored = bridge.decodeProgram(legacy)
        assertNull(restored.events.single().editorialContent)
        assertNull(restored.events.single().tags.single().editorialContent)
        val details =
            ProgramEventCatalog(restored.events, restored.events.single().tags).details(4)!!
        assertNull(details.content)
        assertTrue(details.informationFields.isEmpty())
        assertTrue(details.programLinks.isEmpty())
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
    fun providerEnrichmentRetainsNewContentWithoutMutatingTheOriginal() {
        val original = program(null)
        val enriched =
            ProgramPreparation.enrich(
                original,
                emptyList(),
                "Europe/Berlin",
                "en",
                emptyList(),
                emptyList(),
                listOf(EventMetadata(4, null, content)),
                emptyList(),
            )
        assertEquals(content, enriched.events.single().editorialContent)
        assertNull(original.events.single().editorialContent)
        val retained =
            ProgramPreparation.enrich(
                enriched,
                emptyList(),
                "Europe/Berlin",
                "en",
                emptyList(),
                emptyList(),
                emptyList(),
                emptyList(),
            )
        assertSame(enriched.events.single(), retained.events.single())
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
