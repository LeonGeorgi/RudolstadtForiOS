package de.leongeorgi.rudolstadt.loading

import de.leongeorgi.rudolstadt.discovery.MusicPreviews
import de.leongeorgi.rudolstadt.discovery.MusicReference
import de.leongeorgi.rudolstadt.festival.RudolstadtPayload
import de.leongeorgi.rudolstadt.festival.RudolstadtPayloads
import de.leongeorgi.rudolstadt.news.NewsRecord
import de.leongeorgi.rudolstadt.news.NewsWire
import io.ktor.http.URLBuilder
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope

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
