package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.discovery.ArtistPublicLink
import de.leongeorgi.rudolstadt.festival.*
import kotlin.test.*

class ArtistPublicLinkTests {
    @Test
    fun sharesAndParsesAnOptionalSelectedConcert() {
        val link = ArtistPublicLink(2026, 67, 68)
        assertEquals("https://festival.leongeorgi.de/rudolstadt/2026/artists/67?event=68", link.url())
        assertEquals(link, ArtistPublicLink.parse(assertNotNull(link.url())))
        assertEquals(link, ArtistPublicLink.parse("https://festival.leongeorgi.de/rudolstadt/2026/artists/67/?source=share&event=%36%38#concert"))
        assertEquals(link, ArtistPublicLink.parse("https://rudolstadt.leongeorgi.de/2026/artists/67?event=68"))
        assertNull(ArtistPublicLink(2026, 67, 0).url())
        assertNull(ArtistPublicLink(2026, 67, -1).url())
    }

    @Test
    fun invalidOrAmbiguousOptionalSelectionsFallBackToTheArtist() {
        val base = "https://festival.leongeorgi.de/rudolstadt/2026/artists/67"
        for (query in listOf("event=", "event=no", "event=0", "event=-1", "event=+68", "event=068", "event=68&event=244", "event=68&event=68", "event=999999999999999999999999", "source=event%3D68")) {
            assertEquals(ArtistPublicLink(2026, 67), ArtistPublicLink.parse("$base?$query"), query)
        }
        assertEquals(ArtistPublicLink(2026, 67), ArtistPublicLink.parse("$base#?event=68"))
    }

    @Test
    fun onlySelectsAnExistingConcertBelongingToTheLinkedArtist() {
        fun event(id: Long, artist: Long) = ProgramOccurrence(
            id, 1000.0, 1000.0, ProgramPlace("stage", mapOf("en" to "Stage")),
            ProgramArtist(artist, "Artist", false, ProgramArtistDetails(ProgramContent(emptyMap()))), emptyList(),
        )
        val events = listOf(event(68, 67), event(69, 23))
        assertEquals(68L, ArtistPublicLink(2026, 67, 68).selectedEventID(events))
        assertNull(ArtistPublicLink(2026, 67, 69).selectedEventID(events))
        assertNull(ArtistPublicLink(2026, 67, 999).selectedEventID(events))
        assertNull(ArtistPublicLink(2026, 67).selectedEventID(events))
    }

    @Test
    fun sharesLinksUnderTheFestivalNamespace() {
        val link = ArtistPublicLink(2026, 123)
        val url = assertNotNull(link.url())
        assertEquals("https://festival.leongeorgi.de/rudolstadt/2026/artists/123", url)
        assertEquals(link, ArtistPublicLink.parse(url))
        assertNull(ArtistPublicLink(26, 123).url())
        assertNull(ArtistPublicLink(2026, 0).url())
        assertNull(ArtistPublicLink(2026, -1).url())
    }

    @Test
    fun acceptsWebLinkVariantsAndPreviouslySharedLinks() {
        for (url in
            listOf(
                "https://festival.leongeorgi.de/rudolstadt/2026/artists/123/",
                "https://festival.leongeorgi.de/rudolstadt/2026/artists/123?source=share#artist",
                "HTTPS://FESTIVAL.LEONGEORGI.DE:443/rudolstadt/2026/artists/123",
                "https://rudolstadt.leongeorgi.de/2026/artists/123",
                "https://RUDOLSTADT.LEONGEORGI.DE:443/2026/artists/123/?source=share#artist",
            )) {
            val link = assertNotNull(ArtistPublicLink.parse(url), url)
            assertEquals(ArtistPublicLink(2026, 123), link, url)
            assertEquals("https://festival.leongeorgi.de/rudolstadt/2026/artists/123", link.url())
        }
        assertEquals(
            ArtistPublicLink(2025, 123),
            ArtistPublicLink.parse("https://festival.leongeorgi.de/rudolstadt/2025/artists/123"),
        )
    }

    @Test
    fun rejectsUnrelatedDomainsFestivalsAndMalformedRoutes() {
        for (url in
            listOf(
                "http://festival.leongeorgi.de/rudolstadt/2026/artists/123",
                "https://festival.leongeorgi.de.example.com/rudolstadt/2026/artists/123",
                "https://festival.leongeorgi.de@evil.example/rudolstadt/2026/artists/123",
                "https://user@festival.leongeorgi.de/rudolstadt/2026/artists/123",
                "https://festival.leongeorgi.de:8443/rudolstadt/2026/artists/123",
                "https://festival.leongeorgi.de/2026/artists/123",
                "https://festival.leongeorgi.de/other/2026/artists/123",
                "https://festival.leongeorgi.de/Rudolstadt/2026/artists/123",
                "https://festival.leongeorgi.de/rudolstadt/2026/Artists/123",
                "https://festival.leongeorgi.de/rudolstadt/2026/artists/123/extra",
                "https://festival.leongeorgi.de/rudolstadt/26/artists/123",
                "https://festival.leongeorgi.de/rudolstadt/0000/artists/123",
                "https://festival.leongeorgi.de/rudolstadt/2026/artists/0",
                "https://festival.leongeorgi.de/rudolstadt/2026/artists/-123",
                "https://festival.leongeorgi.de/rudolstadt/2026/artists/+123",
                "https://festival.leongeorgi.de/rudolstadt/2026/artists/999999999999999999999999",
                "https://rudolstadt.leongeorgi.de/rudolstadt/2026/artists/123",
                "https://rudolstadt.leongeorgi.de/2026/Artists/123",
            )) {
            assertNull(ArtistPublicLink.parse(url), url)
        }
    }
}
