package de.leongeorgi.rudolstadt.android

import de.leongeorgi.rudolstadt.android.data.Edition
import de.leongeorgi.rudolstadt.android.data.FestivalContentLoader
import kotlin.math.*
import org.junit.Assert.*
import org.junit.Test

class CityMapTest {
    @Test
    fun offlineAreaCoversEveryLocatedRudolstadtVenueIncludingCampsitesAndParking() {
        val loader = FestivalContentLoader()
        val editions = Edition.all.filter { it.definition.identity.festivalID == "rudolstadt" }
        assertTrue(editions.isNotEmpty())
        editions.forEach { edition ->
            val places = loader.bundled(edition).program.places.filter { it.hasUsableLocation }
            assertTrue(places.isNotEmpty())
            places.forEach { place ->
                assertTrue(
                    "${edition.key}: ${place.placeKey} is outside the offline map (${place.latitude}, ${place.longitude})",
                    place.latitude in CityMap.south..CityMap.north &&
                        place.longitude in CityMap.west..CityMap.east,
                )
            }
        }
    }

    @Test
    fun fullZoomPyramidStaysWellBelowProvidersOfflineTileLimit() {
        fun x(longitude: Double, n: Double) = floor((longitude + 180.0) / 360.0 * n).toInt()
        fun y(latitude: Double, n: Double): Int {
            val radians = Math.toRadians(latitude)
            return floor((1.0 - ln(tan(radians) + 1.0 / cos(radians)) / PI) / 2.0 * n).toInt()
        }
        // Conservative: count all zooms even when the source can overzoom fewer native tiles.
        val tileCount =
            (CityMap.minZoom.toInt()..CityMap.maxZoom.toInt()).sumOf { zoom ->
                val n = 2.0.pow(zoom)
                (x(CityMap.east, n) - x(CityMap.west, n) + 1) *
                    (y(CityMap.south, n) - y(CityMap.north, n) + 1)
            }
        assertTrue("Unexpectedly large download: $tileCount tiles", tileCount < 1_000)
    }
}
