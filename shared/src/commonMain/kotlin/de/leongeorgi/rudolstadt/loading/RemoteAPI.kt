package de.leongeorgi.rudolstadt.loading

import de.leongeorgi.rudolstadt.discovery.MusicPreviews
import de.leongeorgi.rudolstadt.discovery.MusicReference
import de.leongeorgi.rudolstadt.discovery.NewsLinkPreview
import de.leongeorgi.rudolstadt.discovery.NewsLinkPreviews
import de.leongeorgi.rudolstadt.festival.RudolstadtPayload
import de.leongeorgi.rudolstadt.festival.RudolstadtPayloads
import de.leongeorgi.rudolstadt.news.NewsRecord
import de.leongeorgi.rudolstadt.news.NewsWire
import io.ktor.http.URLBuilder
import kotlin.time.Clock
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withTimeoutOrNull

class RemoteHttpError(val endpoint: String, val statusCode: Int, val bodyPreview: String) :
    Exception("HTTP $statusCode for endpoint '$endpoint'. Body preview: $bodyPreview")

class RemoteDecodingError(val endpoint: String, val bodyPreview: String, cause: Throwable) :
    Exception(
        "Decoding failed for endpoint '$endpoint': ${cause.message}. Body preview: $bodyPreview",
        cause,
    )

/** HTTP bytes are decoded here, before crossing the Swift boundary as typed Kotlin objects. */
class RemoteAPI internal constructor(private val http: HttpRequester) {
    constructor() : this(HttpTransport())

    private val previewMutex = Mutex()
    private val previewSlots = Semaphore(4)
    private val previews = linkedMapOf<String, NewsLinkPreview>()

    @Throws(Exception::class)
    suspend fun linkPreview(url: String, cached: NewsLinkPreview? = null): NewsLinkPreview? {
        val key = NewsLinkPreviews.requestURL(url) ?: return null
        val now = Clock.System.now().toEpochMilliseconds()
        val previous = previewMutex.withLock { previews[key] } ?: cached?.takeIf { it.url == key }
        if (previous != null && NewsLinkPreviews.isFresh(previous, now)) return previous
        val loaded = previewSlots.withPermit {
            withTimeoutOrNull(8000) {
                try {
                    val response = http.getPreview(key)
                    if (response.statusCode in 200..299 && response.bytes.isNotEmpty())
                        NewsLinkPreviews.parse(
                            key,
                            response.finalURL ?: key,
                            response.bytes.decodeToString(),
                            now,
                        )
                    else null
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (_: Exception) {
                    null
                }
            }
        }
        val result =
            loaded
                ?: previous
                ?: NewsLinkPreview(
                    key,
                    NewsLinkPreviews.domain(key),
                    fetchedAtMillis = now,
                    fetched = false,
                )
        previewMutex.withLock {
            previews[key] = result
            while (previews.size > 64) previews.remove(previews.keys.first())
        }
        return result
    }

    fun close() {
        (http as? HttpTransport)?.close()
    }

    @Throws(Exception::class)
    suspend fun festival(baseURL: String): RudolstadtPayload = coroutineScope {
        suspend fun records(endpoint: String) =
            decoded(baseURL.trimEnd('/') + "/" + endpoint, endpoint) {
                RudolstadtPayloads.records(endpoint, it)
            }
        val areas = async { records("areas") }
        val artists = async { records("artists") }
        val events = async { records("events") }
        val stages = async { records("stages") }
        val tags = async { records("tags") }
        RudolstadtPayloads.assemble(
            areas.await(),
            artists.await(),
            events.await(),
            stages.await(),
            tags.await(),
        )
    }

    @Throws(Exception::class)
    suspend fun news(baseURL: String): List<NewsRecord> =
        decoded(baseURL.trimEnd('/') + "/news", "news", NewsWire::decode)

    @Throws(Exception::class)
    suspend fun musicPreview(reference: MusicReference, validURL: (String) -> Boolean) =
        decoded(
            URLBuilder("https://itunes.apple.com/lookup")
                .apply {
                    reference.lookupParameters.forEach { parameter ->
                        val value = parameter.value
                        if (value == null) parameters.appendAll(parameter.name, emptyList())
                        else parameters.append(parameter.name, value)
                    }
                }
                .buildString(),
            "music",
        ) {
            MusicPreviews.select(it, reference, validURL)
        }

    private suspend fun <T> decoded(url: String, endpoint: String, decode: (String) -> T): T {
        val response = http.get(url)
        val source = runCatching { response.bytes.sourceText() }
        val preview =
            source.getOrNull()?.let { if (it.length > 500) it.take(500) + "..." else it }
                ?: "<non-utf8>"
        if (!HttpPolicy.isSuccess(response.statusCode)) {
            throw RemoteHttpError(endpoint, response.statusCode, preview)
        }
        return try {
            decode(source.getOrThrow())
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Exception) {
            throw RemoteDecodingError(endpoint, preview, error)
        }
    }
}
