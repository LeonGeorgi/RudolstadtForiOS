package de.leongeorgi.rudolstadt.android

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.SystemClock
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.core.location.LocationListenerCompat
import androidx.core.location.LocationManagerCompat
import androidx.core.location.LocationRequestCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.*

internal data class MapLocationState(
    val location: Location? = null,
    val locating: Boolean = false,
    val unavailable: Boolean = false,
)

internal fun hasLocationPermission(context: Context): Boolean =
    context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED ||
        context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

internal fun isRecentLocation(
    fixNanos: Long,
    nowNanos: Long,
    maximumAgeMillis: Long = 120_000,
): Boolean =
    fixNanos > 0 && nowNanos >= fixNanos && nowNanos - fixNanos <= maximumAgeMillis * 1_000_000

/** Opt-in, foreground-only tracking. Old fixes are never presented as a current location. */
@Composable
internal fun rememberMapLocation(enabled: Boolean, request: Int): MapLocationState {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var state by remember { mutableStateOf(MapLocationState()) }
    LaunchedEffect(enabled, request, context, lifecycle) {
        state = MapLocationState()
        if (!enabled) return@LaunchedEffect
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            if (!hasLocationPermission(context)) {
                state = MapLocationState(unavailable = true)
                return@repeatOnLifecycle
            }
            val manager = context.getSystemService(LocationManager::class.java)
            val listener =
                object : LocationListenerCompat {
                    override fun onLocationChanged(location: Location) {
                        if (
                            isRecentLocation(
                                location.elapsedRealtimeNanos,
                                SystemClock.elapsedRealtimeNanos(),
                            )
                        )
                            state = MapLocationState(location = location)
                    }

                    override fun onProviderDisabled(provider: String) {
                        if (!LocationManagerCompat.isLocationEnabled(manager))
                            state = MapLocationState(unavailable = true)
                    }
                }
            try {
                val providers =
                    manager.getProviders(true).filter {
                        it in
                            setOf(
                                LocationManager.GPS_PROVIDER,
                                LocationManager.NETWORK_PROVIDER,
                                "fused",
                            )
                    }
                if (providers.isEmpty()) {
                    state = MapLocationState(unavailable = true)
                    return@repeatOnLifecycle
                }
                // A very recent fix avoids a blank map while sensors acquire the next update.
                val recent =
                    providers
                        .mapNotNull { manager.getLastKnownLocation(it) }
                        .filter {
                            isRecentLocation(
                                it.elapsedRealtimeNanos,
                                SystemClock.elapsedRealtimeNanos(),
                                15_000,
                            )
                        }
                        .maxByOrNull { it.elapsedRealtimeNanos }
                state = MapLocationState(location = recent, locating = recent == null)
                val request =
                    LocationRequestCompat.Builder(5_000).setMinUpdateIntervalMillis(2_000).build()
                providers.forEach {
                    LocationManagerCompat.requestLocationUpdates(
                        manager,
                        it,
                        request,
                        ContextCompat.getMainExecutor(context),
                        listener,
                    )
                }
                val startedAt = SystemClock.elapsedRealtime()
                while (isActive) {
                    delay(1_000)
                    val fix = state.location
                    if (
                        fix != null &&
                            !isRecentLocation(
                                fix.elapsedRealtimeNanos,
                                SystemClock.elapsedRealtimeNanos(),
                            )
                    )
                        state = MapLocationState(unavailable = true)
                    else if (fix == null && SystemClock.elapsedRealtime() - startedAt > 20_000)
                        state = MapLocationState(unavailable = true)
                }
            } catch (_: SecurityException) {
                state = MapLocationState(unavailable = true)
            } catch (_: IllegalArgumentException) {
                state = MapLocationState(unavailable = true)
            } finally {
                runCatching { manager.removeUpdates(listener) }
                if (!currentCoroutineContext().isActive) state = MapLocationState()
            }
        }
    }
    return state
}
