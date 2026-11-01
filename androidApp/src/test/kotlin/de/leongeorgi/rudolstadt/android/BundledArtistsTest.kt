package de.leongeorgi.rudolstadt.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BundledArtistsTest {
    @Test
    fun loadsRealSharedResourcesAndKeepsVisibleArtists() {
        val artists =
            de.leongeorgi.rudolstadt.android.data
                .FestivalContentLoader()
                .bundled(de.leongeorgi.rudolstadt.android.data.Edition.current)
                .index
                .matching(false, emptyMap(), "", emptyMap())
        assertTrue("Expected the actual festival lineup", artists.size > 100)
        assertTrue(artists.any { it.name == "A Birchola" })
        assertFalse(
            "Hidden workshop artist must stay hidden",
            artists.any { it.name == "Aquabella" },
        )
        assertTrue(artists.all { it.name.isNotBlank() && it.isMetadataAvailable })
        assertFalse(artists.any { it.hiddenFromArtistList })
        assertEquals(artists.size, artists.map { it.artistID }.distinct().size)
    }
}
