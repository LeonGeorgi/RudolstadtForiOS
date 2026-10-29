@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class, kotlinx.cinterop.BetaInteropApi::class)

package de.leongeorgi.rudolstadt.interop

import de.leongeorgi.rudolstadt.discovery.MusicPreviewSelection
import de.leongeorgi.rudolstadt.discovery.MusicReference
import de.leongeorgi.rudolstadt.festival.RudolstadtPayload
import de.leongeorgi.rudolstadt.loading.HttpBytes
import de.leongeorgi.rudolstadt.loading.HttpRequester
import de.leongeorgi.rudolstadt.loading.HttpTransport
import de.leongeorgi.rudolstadt.loading.RemoteAPI
import de.leongeorgi.rudolstadt.loading.RemoteDecodingError
import de.leongeorgi.rudolstadt.loading.RemoteHttpError
import de.leongeorgi.rudolstadt.news.NewsRecord
import io.ktor.client.engine.darwin.DarwinHttpRequestException
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import platform.Foundation.NSData
import platform.Foundation.NSError
import platform.Foundation.NSLocalizedDescriptionKey
import platform.Foundation.NSURLErrorDomain
import platform.Foundation.NSURLErrorUnknown
import platform.Foundation.getBytes

private fun NSData.asBytes(): ByteArray {
    require(length <= Int.MAX_VALUE.toULong())
    return ByteArray(length.toInt()).also { bytes ->
        if (bytes.isNotEmpty()) bytes.usePinned { getBytes(it.addressOf(0), length) }
    }
}

/** One request owns its cancellation, including cancellation before the coroutine starts. */
class AppleRequest {
    internal val job = Job()

    fun cancel() = job.cancel()
}

class AppleHttpResponse(val statusCode: Int, val data: NSData)

/** Allows native tests to inject responses without changing the shared request/decoding path. */
interface AppleHttpSource {
    fun get(
        url: String,
        completion: (AppleHttpResponse?, NSError?) -> Unit,
    ): () -> Unit
}

class AppleTransportFailure(val error: NSError) : Exception(error.localizedDescription)

/** The HTTP client is lazy; restoring the synchronous disk cache does not initialize it. */
class AppleRemoteClient(private val source: AppleHttpSource?) {
    constructor() : this(null)

    private val api by lazy {
        RemoteAPI(
            if (source == null) HttpTransport()
            else
                HttpRequester { url ->
                    suspendCancellableCoroutine { continuation ->
                        val call =
                            source.get(url) { response, error ->
                                if (error != null)
                                    continuation.resumeWithException(AppleTransportFailure(error))
                                else if (response != null)
                                    continuation.resume(
                                        HttpBytes(response.statusCode, response.data.asBytes())
                                    )
                                else
                                    continuation.resumeWithException(
                                        IllegalStateException("Missing HTTP response")
                                    )
                            }
                        continuation.invokeOnCancellation { call() }
                    }
                }
        )
    }

    @Throws(Exception::class)
    suspend fun festival(baseURL: String, request: AppleRequest): RudolstadtPayload =
        perform(request) { api.festival(baseURL) }

    @Throws(Exception::class)
    suspend fun news(baseURL: String, request: AppleRequest): List<NewsRecord> =
        perform(request) { api.news(baseURL) }

    @Throws(Exception::class)
    suspend fun musicPreview(
        reference: MusicReference,
        validURL: (String) -> Boolean,
        request: AppleRequest,
    ): MusicPreviewSelection? = perform(request) { api.musicPreview(reference, validURL) }

    private suspend fun <T> perform(request: AppleRequest, block: suspend () -> T): T {
        try {
            return withContext(Dispatchers.Default + request.job) { block() }
        } catch (error: CancellationException) {
            throw error
        } catch (error: RemoteHttpError) {
            throw error
        } catch (error: RemoteDecodingError) {
            throw error
        } catch (error: AppleTransportFailure) {
            throw error
        } catch (error: DarwinHttpRequestException) {
            throw AppleTransportFailure(error.origin)
        } catch (error: Exception) {
            throw AppleTransportFailure(
                NSError(
                    domain = NSURLErrorDomain,
                    code = NSURLErrorUnknown,
                    userInfo =
                        mapOf(
                            NSLocalizedDescriptionKey to (error.message ?: "HTTP request failed")
                        ),
                )
            )
        } finally {
            request.job.complete()
        }
    }
}
