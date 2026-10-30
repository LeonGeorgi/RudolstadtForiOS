package de.leongeorgi.rudolstadt.loading

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.prepareGet
import io.ktor.client.statement.bodyAsChannel
import io.ktor.http.contentType
import io.ktor.utils.io.readBuffer
import kotlinx.io.readByteArray

/** Keeps response bytes intact; source decoders decide whether their UTF-8/JSON is valid. */
internal data class HttpBytes(
    val statusCode: Int,
    val bytes: ByteArray,
    val finalURL: String? = null,
)

internal fun interface HttpRequester {
    suspend fun get(url: String): HttpBytes

    suspend fun getPreview(url: String): HttpBytes = get(url)
}

internal class HttpTransport internal constructor(private val client: HttpClient) : HttpRequester {
    constructor() : this(platformHttpClient())

    override suspend fun get(url: String): HttpBytes {
        val response = client.get(url)
        return HttpBytes(response.status.value, response.body())
    }

    override suspend fun getPreview(url: String): HttpBytes =
        client.prepareGet(url).execute { response ->
            val type = response.contentType()?.withoutParameters()?.toString()
            val bytes =
                if (
                    response.status.value in 200..299 &&
                        (type == null || type == "text/html" || type == "application/xhtml+xml")
                )
                    response.bodyAsChannel().readBuffer(262144).readByteArray()
                else byteArrayOf()
            HttpBytes(response.status.value, bytes, response.call.request.url.toString())
        }

    fun close() = client.close()
}

internal expect fun platformHttpClient(): HttpClient
