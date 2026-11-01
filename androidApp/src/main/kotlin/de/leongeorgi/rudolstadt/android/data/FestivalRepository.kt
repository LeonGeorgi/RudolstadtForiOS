package de.leongeorgi.rudolstadt.android.data

import android.content.Context
import android.util.AtomicFile
import de.leongeorgi.rudolstadt.loading.RemoteAPI
import de.leongeorgi.rudolstadt.news.*
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable internal data class CachedDocument(val timestamp: Double, val content: String)

internal class FestivalRepository(private val context: Context) {
    private val remote = RemoteAPI()
    private val loader =
        FestivalContentLoader(
            localize = { key, lang ->
                val configuration =
                    android.content.res.Configuration(context.resources.configuration)
                configuration.setLocale(java.util.Locale.forLanguageTag(lang))
                val resources = context.createConfigurationContext(configuration).resources
                val id =
                    when (key) {
                        "park_and_ride.navi.description" ->
                            de.leongeorgi.rudolstadt.android.R.string.park_and_ride_navi_description
                        "park_and_ride.parking.raiffeisenstraße.title" ->
                            de.leongeorgi.rudolstadt.android.R.string
                                .park_and_ride_parking_raiffeisenstrasse_title
                        "park_and_ride.parking.raiffeisenstraße.description" ->
                            de.leongeorgi.rudolstadt.android.R.string
                                .park_and_ride_parking_raiffeisenstrasse_description
                        "park_and_ride.parking.erich-correns-ring.title" ->
                            de.leongeorgi.rudolstadt.android.R.string
                                .park_and_ride_parking_erich_correns_ring_title
                        "park_and_ride.parking.erich-correns-ring.description" ->
                            de.leongeorgi.rudolstadt.android.R.string
                                .park_and_ride_parking_erich_correns_ring_description
                        else -> error("Unknown festival text: $key")
                    }
                resources.getString(id)
            }
        )

    fun close() = remote.close()

    suspend fun bundle(edition: Edition) = withContext(Dispatchers.IO) { loader.bundled(edition) }

    suspend fun cached(edition: Edition): Pair<FestivalContent, Double>? =
        withContext(Dispatchers.IO) {
            read("program-${edition.year}")?.let {
                loader.remote(edition, it.content) to it.timestamp
            }
        }

    suspend fun refresh(edition: Edition): Pair<FestivalContent, Double> =
        withContext(Dispatchers.IO) {
            val payload = remote.festival(API).sourceJSON
            val content = loader.remote(edition, payload)
            val now = System.currentTimeMillis() / 1000.0
            write("program-${edition.year}", CachedDocument(now, payload))
            content to now
        }

    suspend fun bundledNews(): NewsSnapshot =
        withContext(Dispatchers.IO) {
            snapshot(
                NewsWire.decode(resourceText("FestivalBackup/2026_news.json")),
                "bundledBackup",
            )
        }

    suspend fun cachedNews(): Pair<NewsSnapshot, Double>? =
        withContext(Dispatchers.IO) {
            read("news-2026")?.let {
                snapshot(NewsWire.decode(it.content), "cache") to it.timestamp
            }
        }

    suspend fun refreshNews(): Pair<NewsSnapshot, Double> =
        withContext(Dispatchers.IO) {
            val records = remote.news(API)
            val now = System.currentTimeMillis() / 1000.0
            val snapshot = snapshot(records, "remote")
            write("news-2026", CachedDocument(now, NewsWire.encode(records)))
            snapshot to now
        }

    private fun snapshot(records: List<NewsRecord>, source: String) =
        NewsSnapshots.fromMessages(
            records.map { it.message() },
            "rudolstadt",
            "2026",
            source,
            null,
        )

    private fun file(name: String) = AtomicFile(File(context.cacheDir, "$name.json"))

    private fun read(name: String): CachedDocument? {
        val file = file(name)
        if (!file.baseFile.exists()) return null
        return file.openRead().bufferedReader().use { Json.decodeFromString(it.readText()) }
    }

    private fun write(name: String, value: CachedDocument) {
        val file = file(name)
        val output = file.startWrite()
        try {
            output.write(Json.encodeToString(value).encodeToByteArray())
            file.finishWrite(output)
        } catch (failure: Exception) {
            file.failWrite(output)
            throw failure
        }
    }

    companion object {
        const val API = "https://www.rudolstadt-festival.de/api"
    }
}
