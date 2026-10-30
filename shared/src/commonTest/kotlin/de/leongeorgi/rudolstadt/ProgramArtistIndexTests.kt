package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.discovery.*
import de.leongeorgi.rudolstadt.festival.*
import kotlin.test.*

class ProgramArtistIndexTests {
    private fun artist(
        id: Long,
        name: String,
        groups: Map<String, List<String>> = emptyMap(),
        hidden: Boolean = false,
    ) = ProgramArtist(id, name, hidden, ProgramArtistDetails(ProgramContent(emptyMap())), groups)

    private val artists =
        listOf(
            artist(3, "Bravo", mapOf("kind" to listOf("band"), "genre" to listOf("folk", "jazz"))),
            artist(2, "Alpha", mapOf("kind" to listOf("solo"), "genre" to listOf("folk"))),
            artist(1, "Álpha", mapOf("kind" to listOf("band"), "genre" to listOf("folk"))),
            artist(4, "Hidden", hidden = true),
        )
    private val index = ProgramArtistIndex(artists) { it.lowercase().replace("á", "a") }

    @Test
    fun groupFiltersIntersectAndHiddenArtistsNeverLeak() {
        assertEquals(
            listOf(1L, 3L),
            index.matching(false, emptyMap(), "", mapOf("kind" to "band", "genre" to "folk")).map {
                it.artistID
            },
        )
        assertTrue(index.matching(false, emptyMap(), "", mapOf("genre" to "unknown")).isEmpty())
        assertEquals(3, index.matching(false, emptyMap(), "", emptyMap()).size)
    }

    @Test
    fun normalizedSearchAndFavoritesUseTheSameIndex() {
        assertEquals(
            listOf(1L),
            index
                .matching(true, mapOf("1" to 2, "2" to -1, "invalid" to 3), "alpha", emptyMap())
                .map { it.artistID },
        )
        assertEquals(
            listOf(3L),
            index.matching(false, emptyMap(), "brav", emptyMap()).map { it.artistID },
        )
    }

    @Test
    fun hostsControlCollationAndRetainCanonicalObjects() {
        val collation =
            object : TextCollation {
                override fun compare(a: String, b: String) = b.compareTo(a)
            }
        val result = index.matching(false, emptyMap(), "", emptyMap(), collation)
        assertEquals(listOf(3L, 2L, 1L), result.map { it.artistID })
        assertSame(artists[0], result.first())
    }
}
