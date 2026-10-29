package de.leongeorgi.rudolstadt.loading

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get

/** Keeps response bytes intact; source decoders decide whether their UTF-8/JSON is valid. */
internal data class HttpBytes(val statusCode: Int, val bytes: ByteArray)

internal fun interface HttpRequester {
    suspend fun get(url: String): HttpBytes
}

internal class HttpTransport internal constructor(private val client: HttpClient) : HttpRequester {
    constructor() : this(platformHttpClient())

    override suspend fun get(url: String): HttpBytes {
        val response = client.get(url)
        return HttpBytes(response.status.value, response.body())
    }

    fun close() = client.close()
}

internal expect fun platformHttpClient(): HttpClient
