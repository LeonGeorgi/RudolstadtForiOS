package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.loading.*
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import io.ktor.utils.io.ByteReadChannel
import kotlin.test.*
import kotlinx.coroutines.*

class TransportTests {
    @Test
    fun sourceDecodingMatchesNativeUtf8BomHandling() = runBlocking {
        val bytes = byteArrayOf(-17, -69, -65, 91, 93)
        val api = RemoteAPI(HttpRequester { HttpBytes(200, bytes) })
        assertEquals(emptyList(), api.news("https://example.test/api/"))
    }

    @Test
    fun httpKeepsStatusAndUndecodedBytes() = runBlocking {
        val bytes = byteArrayOf(0, -1, 65)
        val transport =
            HttpTransport(
                HttpClient(
                    MockEngine {
                        respond(ByteReadChannel(bytes), HttpStatusCode.ServiceUnavailable)
                    }
                )
            )
        try {
            val response = transport.get("https://example.test/api/news")
            assertEquals(503, response.statusCode)
            assertContentEquals(bytes, response.bytes)
        } finally {
            transport.close()
        }
    }

    @Test
    fun cancellationStopsTheUnderlyingRequest() = runBlocking {
        val started = CompletableDeferred<Unit>()
        val cancelled = CompletableDeferred<Unit>()
        val transport =
            HttpTransport(
                HttpClient(
                    MockEngine {
                        started.complete(Unit)
                        try {
                            awaitCancellation()
                        } finally {
                            cancelled.complete(Unit)
                        }
                    }
                )
            )
        try {
            withTimeout(5_000) {
                val request = async { transport.get("https://example.test/api/news") }
                started.await()
                request.cancelAndJoin()
                cancelled.await()
            }
        } finally {
            transport.close()
        }
    }

    @Test
    fun repositoryDecodesFestivalInKotlinAndRejectsInvalidUtf8() = runBlocking {
        val transport =
            HttpTransport(
                HttpClient(
                    MockEngine { request ->
                        val body =
                            if (request.url.encodedPath.endsWith("artists")) byteArrayOf(-1)
                            else "[]".encodeToByteArray()
                        respond(ByteReadChannel(body), HttpStatusCode.OK)
                    }
                )
            )
        try {
            val error =
                assertFailsWith<RemoteDecodingError> {
                    RemoteAPI(transport).festival("https://example.test/api/")
                }
            assertEquals("artists", error.endpoint)
            assertEquals("<non-utf8>", error.bodyPreview)
        } finally {
            transport.close()
        }
    }

    @Test
    fun repositoryKeepsHttpErrorsDistinctFromBrokenResponses() = runBlocking {
        val api = RemoteAPI(HttpRequester { HttpBytes(503, "Unavailable".encodeToByteArray()) })
        val error = assertFailsWith<RemoteHttpError> { api.news("https://example.test/api/") }
        assertEquals("news", error.endpoint)
        assertEquals(503, error.statusCode)
        assertEquals("Unavailable", error.bodyPreview)
    }
}
