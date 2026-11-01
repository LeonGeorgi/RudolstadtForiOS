package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.discovery.ArtistPublicLink
import kotlin.test.*

class ArtistPublicLinkTests {
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
