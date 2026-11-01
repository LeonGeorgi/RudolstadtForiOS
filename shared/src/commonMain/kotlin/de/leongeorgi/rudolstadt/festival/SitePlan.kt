package de.leongeorgi.rudolstadt.festival

import de.leongeorgi.rudolstadt.planning.PlaceLocation
import kotlinx.serialization.Serializable

@Serializable
data class PlanCoordinate(
    val latitude: Double,
    val longitude: Double,
    val isApproximate: Boolean,
    val sourceURL: String? = null,
) {
    val isValid
        get() = PlaceLocation("", latitude, longitude).hasCoordinates
}

@Serializable
data class PlanLocation(
    val id: String,
    val category: String,
    val nameDE: String,
    val nameEN: String,
    val noteDE: String? = null,
    val noteEN: String? = null,
    val reference: String? = null,
    val stageID: Long? = null,
    val point: MapPoint? = null,
    val coordinate: PlanCoordinate? = null,
)

@Serializable
data class PlanBackground(
    val resourceName: String,
    val width: Double,
    val height: Double,
    val sha256: String,
) {
    val isValid
        get() =
            validResourceName(resourceName) &&
                width.isFinite() &&
                height.isFinite() &&
                width > 0 &&
                height > 0
}

@Serializable
data class SitePlan(
    val resourceName: String,
    val sourceURL: String,
    val sourceSHA256: String,
    val coordinateSourceURL: String? = null,
    val locations: List<PlanLocation>,
    val background: PlanBackground? = null,
) {
    fun valid(stageIDs: Set<Long>): Boolean {
        if (
            !validResourceName(resourceName) ||
                !sourceURL.startsWith("https:") ||
                sourceSHA256.isEmpty() ||
                locations.isEmpty() ||
                locations.map { it.id }.toSet().size != locations.size
        )
            return false
        val linked = mutableSetOf<Long>()
        return locations.all { location ->
            location.category in
                setOf(
                    "stage",
                    "entrance",
                    "food",
                    "parking",
                    "toilets",
                    "firstAid",
                    "service",
                    "activity",
                ) &&
                location.id.isNotEmpty() &&
                location.nameDE.isNotEmpty() &&
                location.nameEN.isNotEmpty() &&
                (location.point?.let {
                    it.x.isFinite() && it.y.isFinite() && it.x in 0.0..1.0 && it.y in 0.0..1.0
                } != false) &&
                location.coordinate?.isValid != false &&
                (if (location.stageID != null)
                    location.category == "stage" &&
                        location.stageID in stageIDs &&
                        linked.add(location.stageID) &&
                        location.point != null
                else location.category != "stage")
        }
    }
}

internal fun validResourceName(value: String) =
    value.isNotEmpty() && '/' !in value && ".." !in value
