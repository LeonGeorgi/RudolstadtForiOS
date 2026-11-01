package de.leongeorgi.rudolstadt.android

import android.content.Context
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import okhttp3.Dispatcher
import okhttp3.OkHttpClient
import org.maplibre.android.MapLibre
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.module.http.HttpRequestUtil
import org.maplibre.android.offline.*

/** Shared by all map views and downloads, including the provider's request limit. */
internal object CityMap {
    const val styleUrl = "https://tiles.openfreemap.org/styles/positron"
    const val minZoom = 10.0
    const val maxZoom = 16.0
    const val north = 50.755
    const val south = 50.685
    const val west = 11.285
    const val east = 11.405
    private var initialized = false

    fun initialize(context: Context) {
        if (initialized) return
        MapLibre.getInstance(context.applicationContext)
        HttpRequestUtil.setOkHttpClient(
            OkHttpClient.Builder()
                .dispatcher(
                    Dispatcher().apply {
                        maxRequests = 4
                        maxRequestsPerHost = 4
                    }
                )
                .addInterceptor { chain ->
                    chain.proceed(
                        chain
                            .request()
                            .newBuilder()
                            .header(
                                "User-Agent",
                                "RudolstadtAndroid/0.1 (+https://github.com/LeonGeorgi/RudolstadtForiOS)",
                            )
                            .build()
                    )
                }
                .build()
        )
        initialized = true
    }
}

internal data class OfflineCityMapState(
    val loading: Boolean = true,
    val exists: Boolean = false,
    val downloading: Boolean = false,
    val complete: Boolean = false,
    val bytes: Long = 0,
    val progress: Float? = null,
    val busy: Boolean = false,
    val failed: Boolean = false,
    val limitReached: Boolean = false,
)

/** One explicitly requested city package; never resumes downloads on launch. Main thread only. */
internal class OfflineCityMap(context: Context) {
    private val manager: OfflineManager
    private val mutableState = MutableStateFlow(OfflineCityMapState())
    val state = mutableState.asStateFlow()
    private var region: OfflineRegion? = null
    private var foreground = true
    private val pixelRatio = context.resources.displayMetrics.density
    private val metadata = "rudolstadt-city-v1".toByteArray(Charsets.UTF_8)

    init {
        CityMap.initialize(context)
        manager = OfflineManager.getInstance(context.applicationContext)
        load()
    }

    fun load() {
        if (mutableState.value.busy || region != null) return
        mutableState.value = OfflineCityMapState()
        manager.listOfflineRegions(
            object : OfflineManager.ListOfflineRegionsCallback {
                override fun onList(offlineRegions: Array<OfflineRegion>?) {
                    val saved = offlineRegions?.firstOrNull { it.metadata.contentEquals(metadata) }
                    if (saved == null) mutableState.value = OfflineCityMapState(loading = false)
                    else attach(saved)
                }

                override fun onError(error: String) = failure(error)
            }
        )
    }

    private fun attach(saved: OfflineRegion) {
        region = saved
        saved.setDownloadState(OfflineRegion.STATE_INACTIVE)
        mutableState.value = OfflineCityMapState(loading = false, exists = true)
        saved.setObserver(
            object : OfflineRegion.OfflineRegionObserver {
                override fun onStatusChanged(status: OfflineRegionStatus) = status(status)

                override fun onError(error: OfflineRegionError) = failure(error.message)

                override fun mapboxTileCountLimitExceeded(limit: Long) = exceededLimit()
            }
        )
        saved.getStatus(
            object : OfflineRegion.OfflineRegionStatusCallback {
                override fun onStatus(status: OfflineRegionStatus?) {
                    if (status != null) status(status)
                    else failure("Offline region status is unavailable")
                }

                override fun onError(error: String?) =
                    failure(error ?: "Offline region status is unavailable")
            }
        )
    }

    fun download() {
        val current = mutableState.value
        if (
            current.loading ||
                current.busy ||
                current.downloading ||
                current.complete ||
                !foreground ||
                current.limitReached
        )
            return
        if (region != null) {
            mutableState.value = current.copy(downloading = true, failed = false)
            region?.setDownloadState(OfflineRegion.STATE_ACTIVE)
            return
        }
        mutableState.value = current.copy(busy = true, failed = false)
        val definition =
            OfflineTilePyramidRegionDefinition(
                CityMap.styleUrl,
                LatLngBounds.from(CityMap.north, CityMap.east, CityMap.south, CityMap.west),
                CityMap.minZoom,
                CityMap.maxZoom,
                pixelRatio,
                false,
            )
        manager.createOfflineRegion(
            definition,
            metadata,
            object : OfflineManager.CreateOfflineRegionCallback {
                override fun onCreate(offlineRegion: OfflineRegion) {
                    attach(offlineRegion)
                    if (foreground) download()
                }

                override fun onError(error: String) = failure(error)
            },
        )
    }

    private fun status(status: OfflineRegionStatus) {
        val previous = mutableState.value
        val complete = status.isComplete
        // Reserve headroom for the at most four requests already in flight.
        if (
            !complete &&
                (status.completedResourceSize >= 45_000_000 || status.completedTileCount >= 2_800)
        ) {
            exceededLimit()
            return
        }
        mutableState.value =
            previous.copy(
                bytes = status.completedResourceSize,
                complete = complete,
                progress =
                    if (status.isRequiredResourceCountPrecise && status.requiredResourceCount > 0)
                        (status.completedResourceCount.toFloat() / status.requiredResourceCount)
                            .coerceIn(0f, 1f)
                    else null,
                downloading = previous.downloading && !complete,
            )
        if (complete && previous.downloading) region?.setDownloadState(OfflineRegion.STATE_INACTIVE)
    }

    private fun exceededLimit() {
        region?.setDownloadState(OfflineRegion.STATE_INACTIVE)
        mutableState.value =
            mutableState.value.copy(downloading = false, busy = false, limitReached = true)
    }

    private fun failure(error: String) {
        Log.w("OfflineCityMap", error)
        region?.setDownloadState(OfflineRegion.STATE_INACTIVE)
        mutableState.value =
            mutableState.value.copy(
                loading = false,
                busy = false,
                downloading = false,
                failed = true,
            )
    }

    fun pause() {
        region?.setDownloadState(OfflineRegion.STATE_INACTIVE)
        mutableState.value = mutableState.value.copy(downloading = false)
    }

    fun foreground(value: Boolean) {
        foreground = value
        if (!value) pause()
    }

    fun close() {
        foreground(false)
        region?.setObserver(null)
    }

    fun delete() {
        val saved = region ?: return
        if (mutableState.value.busy) return
        pause()
        mutableState.value = mutableState.value.copy(busy = true)
        saved.delete(
            object : OfflineRegion.OfflineRegionDeleteCallback {
                override fun onDelete() {
                    region = null
                    mutableState.value = OfflineCityMapState(loading = false)
                }

                override fun onError(error: String) = failure(error)
            }
        )
    }
}
