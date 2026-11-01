package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.discovery.*
import de.leongeorgi.rudolstadt.loading.*
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.headersOf
import kotlin.test.*
import kotlin.time.Clock
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield

class NewsLinkPreviewTests {
    @Test
    fun readsOpenGraphCaseInsensitiveWithEntitiesAndRedirectRelativeImages() {
        val preview =
            NewsLinkPreviews.parse(
                "https://example.com/old",
                "https://example.com/news/story/",
                """
                <head><title>Fallback</title>
                <!-- <meta property='og:title' content='Wrong'> -->
                <script>const fake = '<meta property="og:title" content="Wrong">';</script>
                <META content='Folk &amp; Welt &#8211; &quot;Live&quot;' PROPERTY='og:title'>
                <meta property=og:image content='../cover.jpg?size=large&amp;crop=square'>
                </head><meta property='og:title' content='Wrong body'>
                """
                    .trimIndent(),
                100,
            )
        assertEquals("Folk & Welt – \"Live\"", preview.title)
        assertEquals("https://example.com/news/cover.jpg?size=large&crop=square", preview.imageURL)
        assertEquals("example.com", preview.domain)
    }

    @Test
    fun missingFieldsRemainOptionalAndUnsafeImagesAreIgnored() {
        val withoutImage =
            NewsLinkPreviews.parse(
                "https://www.example.com",
                "https://www.example.com",
                "<title>A &amp; B</title>",
                100,
            )
        assertEquals("A & B", withoutImage.title)
        assertNull(withoutImage.imageURL)
        val empty =
            NewsLinkPreviews.parse(
                "https://example.com",
                "https://example.com",
                "<meta property=og:image content='javascript:bad'>",
                100,
            )
        assertNull(empty.title)
        assertNull(empty.imageURL)
        assertEquals("example.com", empty.domain)
        val twitter =
            NewsLinkPreviews.parse(
                "https://example.com",
                "https://example.com/news",
                "<meta name='twitter:title' content='News'><meta name='twitter:image' content='//cdn.example.com/image.jpg'>",
                100,
            )
        assertEquals("https://cdn.example.com/image.jpg", twitter.imageURL)
    }

    @Test
    fun cacheSurvivesEncodingAndHasExplicitFreshnessBoundaries() {
        val preview =
            NewsLinkPreview("https://example.com/path", "example.com", fetchedAtMillis = 100)
        assertEquals(preview, NewsLinkPreviews.decode(NewsLinkPreviews.encode(preview)))
        assertTrue(NewsLinkPreviews.isFresh(preview, 100))
        assertFalse(NewsLinkPreviews.isFresh(preview, 100 + 6 * 60 * 60 * 1000L))
        assertFalse(NewsLinkPreviews.isFresh(preview, 99))
        assertFalse(NewsLinkPreviews.isFresh(preview.copy(fetched = false), 100 + 5 * 60 * 1000L))
        assertNull(NewsLinkPreviews.decode("not JSON"))
        assertEquals(
            NewsLinkPreviews.cacheKey(preview.url),
            NewsLinkPreviews.cacheKey(preview.url + "#section"),
        )
        assertNull(NewsLinkPreviews.requestURL("mailto:a@example.com"))
        assertNull(NewsLinkPreviews.requestURL("/relative"))
    }

    @Test
    fun reusesMemoryAndDiskCacheAndRetainsStaleMetadataOffline() = runBlocking {
        var calls = 0
        val now = Clock.System.now().toEpochMilliseconds()
        val api =
            RemoteAPI(
                HttpRequester {
                    calls++
                    HttpBytes(200, "<title>News</title>".encodeToByteArray())
                }
            )
        val first = api.linkPreview("https://example.com#first")
        assertEquals(first, api.linkPreview("https://example.com#second"))
        assertEquals(1, calls)
        val disk =
            NewsLinkPreview("https://other.com", "other.com", "Cached", fetchedAtMillis = now)
        assertEquals(disk, api.linkPreview(disk.url, disk))
        assertEquals(1, calls)
        val offline = RemoteAPI(HttpRequester { error("offline") })
        val stale = disk.copy(fetchedAtMillis = 0)
        assertEquals(stale, offline.linkPreview(stale.url, stale))
        val fallback = assertNotNull(offline.linkPreview("https://example.com"))
        assertEquals("example.com", fallback.domain)
        assertFalse(fallback.fetched)
    }

    @Test
    fun previewTransportBoundsHtmlAndDoesNotReadImagesAsHtml() = runBlocking {
        val client =
            HttpClient(
                MockEngine {
                    respond(
                        "<title>News</title>" + "x".repeat(300000),
                        headers = headersOf("Content-Type", "text/html"),
                    )
                }
            )
        try {
            assertEquals(262144, HttpTransport(client).getPreview("https://example.com").bytes.size)
        } finally {
            client.close()
        }
        val imageClient =
            HttpClient(
                MockEngine {
                    respond("image data", headers = headersOf("Content-Type", "image/png"))
                }
            )
        try {
            assertTrue(HttpTransport(imageClient).getPreview("https://example.com").bytes.isEmpty())
        } finally {
            imageClient.close()
        }
    }

    @Test
    fun cancellationIsNotTurnedIntoAFailedPreview() = runBlocking {
        var started = false
        var returned = false
        val api =
            RemoteAPI(
                HttpRequester {
                    started = true
                    awaitCancellation()
                }
            )
        val job = launch {
            api.linkPreview("https://example.com")
            returned = true
        }
        while (!started) yield()
        job.cancelAndJoin()
        assertFalse(returned)
    }
}
