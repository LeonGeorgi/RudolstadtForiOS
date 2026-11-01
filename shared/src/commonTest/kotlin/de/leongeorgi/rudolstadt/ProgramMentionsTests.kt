package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.discovery.*
import de.leongeorgi.rudolstadt.festival.*
import kotlin.test.*

class ProgramMentionsTests {
    @Test
    fun inlineLinksPreferSubtitleAndProtectExternalLinks() {
        val artist =
            ProgramArtist(1, "Band", false, ProgramArtistDetails(ProgramContent(emptyMap())))
        val stage = ProgramPlace("church", mapOf("de" to "Kirche"), stageCode = "8")
        val result =
            ProgramMentions.inline(
                listOf("Band", "Band und Kirche, Kirche"),
                listOf(artist),
                listOf(stage),
                listOf(emptyList(), listOf(TextMentionRange(9, 15))),
                String::lowercase,
                { it.names.getValue("de") },
            )
        assertEquals(2, result.size)
        assertSame(artist, result[0].artist)
        assertEquals(0, result[0].textIndex)
        assertSame(stage, result[1].place)
        assertEquals(TextMentionRange(17, 23), result[1].range)
    }

    @Test
    fun inlineLinksResolveOverlapsAcrossArtistAndPlaceNames() {
        val artist =
            ProgramArtist(1, "Band", false, ProgramArtistDetails(ProgramContent(emptyMap())))
        val stage = ProgramPlace("s", mapOf("de" to "Band Bühne"))
        val text = "Band Bühne und Band"
        val result =
            ProgramMentions.inline(
                listOf(text),
                listOf(artist, artist),
                listOf(stage, stage),
                emptyList(),
                String::lowercase,
                { it.names.getValue("de") },
            )
        assertEquals(
            listOf("Band Bühne", "Band"),
            result.map { text.substring(it.range.start, it.range.endExclusive) },
        )
        assertSame(stage, result[0].place)
        assertSame(artist, result[1].artist)
    }

    @Test
    fun referencesUseWholeNamesAndAppearanceOrderAndRetainObjects() {
        val artists =
            listOf("La Ni", "Aba Trio", "La Niña").mapIndexed { i, name ->
                ProgramArtist(
                    i.toLong(),
                    name,
                    false,
                    ProgramArtistDetails(ProgramContent(emptyMap())),
                )
            }
        val places = listOf(ProgramPlace("s", mapOf("de" to "Große Bühne")))
        fun normalize(value: String) =
            TextSearch.normalizedMention(value.lowercase().replace("ñ", "n"))
        val result =
            ProgramMentions.find(
                normalize("La Nina und Aba Trio. Nicht SuperAba Trio. Große Bühne!"),
                artists,
                places,
                { normalize(it.name) },
                { normalize(it.names.getValue("de")) },
            )
        assertEquals(listOf(artists[2], artists[1]), result.artists)
        assertEquals(places, result.places)
        assertSame(artists[2], result.artists.first())
        assertTrue(
            ProgramMentions.find("superaba trio", artists, places, { normalize(it.name) }, { "" })
                .artists
                .isEmpty()
        )
    }
}
