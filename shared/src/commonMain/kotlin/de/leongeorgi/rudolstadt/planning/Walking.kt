package de.leongeorgi.rudolstadt.planning

import kotlin.math.*
import kotlinx.serialization.Serializable

fun interface TransferSource {
    fun transfer(from: String, to: String): Transfer?
}

@Serializable
data class PlaceLocation(val id: String, val latitude: Double, val longitude: Double) {
    val hasCoordinates
        get() =
            latitude.isFinite() &&
                longitude.isFinite() &&
                latitude in -90.0..90.0 &&
                longitude in -180.0..180.0 &&
                (latitude != 0.0 || longitude != 0.0)

    fun airDistance(other: PlaceLocation): Double? {
        if (!hasCoordinates || !other.hasCoordinates) return null
        val lat1 = latitude * PI / 180
        val lat2 = other.latitude * PI / 180
        val dLat = (other.latitude - latitude) * PI / 180
        val dLon = (other.longitude - longitude) * PI / 180
        val h = sin(dLat / 2).pow(2) + cos(lat1) * cos(lat2) * sin(dLon / 2).pow(2)
        return 6_371_000 * 2 * atan2(sqrt(h), sqrt(maxOf(0.0, 1 - h)))
    }
}

@Serializable
data class Transfer(val distanceInMeters: Double, val walkingMinutes: Int, val source: String) {
    val isEstimated
        get() = source == "anchoredEstimate" || source == "directCoordinateEstimate"
}

@Serializable
data class TransferPolicy(
    val walkingSpeedInMetersPerMinute: Double = 80.0,
    val coordinateDetourFactor: Double = 1.5,
    val maximumAnchorDistanceInMeters: Double = 300.0,
    val maximumAnchorCount: Int = 3,
    val knownRouteAirDistanceToleranceInMeters: Double = 100.0,
) {
    fun normalized() =
        copy(
            walkingSpeedInMetersPerMinute =
                walkingSpeedInMetersPerMinute.takeIf { it.isFinite() && it > 0 } ?: 80.0,
            coordinateDetourFactor =
                coordinateDetourFactor.takeIf { it.isFinite() && it > 0 } ?: 1.5,
            maximumAnchorDistanceInMeters =
                maximumAnchorDistanceInMeters.takeIf { it.isFinite() && it >= 0 } ?: 300.0,
            maximumAnchorCount = maximumAnchorCount.coerceIn(0, 10),
            knownRouteAirDistanceToleranceInMeters =
                knownRouteAirDistanceToleranceInMeters.takeIf { it.isFinite() && it >= 0 } ?: 100.0,
        )
}

class WalkingDistanceMatrix(distances: Map<String, Map<String, Double>>) {
    val distances: Map<String, Map<String, Double>>
    val placeIDs
        get() = distances.keys

    init {
        val graph = mutableMapOf<String, MutableMap<String, Double>>()
        distances.forEach { (from, targets) ->
            targets.forEach { (to, distance) ->
                if (distance.isFinite() && distance in 0.0..100_000.0) {
                    val best = minOf(distance, graph[from]?.get(to) ?: Double.POSITIVE_INFINITY)
                    graph.getOrPut(from) { mutableMapOf() }[to] = best
                    graph.getOrPut(to) { mutableMapOf() }[from] = best
                }
            }
        }
        this.distances = graph
    }

    override fun equals(other: Any?): Boolean =
        other is WalkingDistanceMatrix && distances == other.distances

    override fun hashCode(): Int = distances.hashCode()

    fun distance(from: String, to: String, allowed: Set<String>? = null): Double? {
        if (from == to) return if (from in placeIDs) 0.0 else null
        distances[from]?.get(to)?.let {
            return it
        }
        if (from !in placeIDs || to !in placeIDs) return null
        val remaining =
            placeIDs
                .filter { allowed == null || it in allowed || it == from || it == to }
                .toMutableSet()
        val costs = mutableMapOf(from to 0.0)
        while (remaining.isNotEmpty()) {
            val current = remaining.minBy { costs[it] ?: Double.POSITIVE_INFINITY }
            val cost = costs[current] ?: return null
            if (current == to) return cost
            remaining.remove(current)
            distances[current].orEmpty().forEach { (neighbor, edge) ->
                if (
                    neighbor in remaining &&
                        cost + edge < (costs[neighbor] ?: Double.POSITIVE_INFINITY)
                )
                    costs[neighbor] = cost + edge
            }
        }
        return null
    }
}

class TransferEstimator(
    locations: List<PlaceLocation>,
    private val matrix: WalkingDistanceMatrix,
    policy: TransferPolicy = TransferPolicy(),
) : TransferSource {
    private val locations = locations.associateBy { it.id }
    private val policy = policy.normalized()

    override fun transfer(from: String, to: String): Transfer? =
        if (locations[from]?.hasCoordinates == true && locations[to]?.hasCoordinates == true)
            estimate(from, to)
        else null

    private data class Anchor(val location: PlaceLocation, val connector: Double)

    fun estimate(from: String, to: String): Transfer? {
        if (from == to) return Transfer(0.0, 0, "sameStage")
        val a = locations[from] ?: return null
        val b = locations[to] ?: return null
        known(a, b)?.let {
            return make(it, "knownRoute")
        }
        val candidates =
            anchors(a)
                .flatMap { x ->
                    anchors(b).mapNotNull { y ->
                        known(x.location, y.location)?.let {
                            (x.connector + it + y.connector) to "anchoredEstimate"
                        }
                    }
                }
                .toMutableList()
        if (candidates.isEmpty() || (from !in matrix.placeIDs && to !in matrix.placeIDs)) {
            a.airDistance(b)?.let {
                candidates += (it * policy.coordinateDetourFactor) to "directCoordinateEstimate"
            }
        }
        val best =
            candidates.minWithOrNull(
                compareBy<Pair<Double, String>> { it.first }
                    .thenBy { if (it.second == "anchoredEstimate") 1 else 2 }
            ) ?: return null
        return make(best.first, best.second)
    }

    private fun known(a: PlaceLocation, b: PlaceLocation): Double? {
        val distance = matrix.distance(a.id, b.id, locations.keys + a.id + b.id) ?: return null
        val air = a.airDistance(b)
        return distance.takeUnless {
            air != null && distance + policy.knownRouteAirDistanceToleranceInMeters < air
        }
    }

    private fun anchors(location: PlaceLocation): List<Anchor> {
        if (location.id in matrix.placeIDs) return listOf(Anchor(location, 0.0))
        if (!location.hasCoordinates) return emptyList()
        return locations.values
            .mapNotNull { candidate ->
                if (candidate.id == location.id || candidate.id !in matrix.placeIDs) null
                else
                    location
                        .airDistance(candidate)
                        ?.takeIf { it <= policy.maximumAnchorDistanceInMeters }
                        ?.let { Anchor(candidate, it * policy.coordinateDetourFactor) }
            }
            .sortedWith(
                compareBy<Anchor> { it.connector }
                    .thenComparator { a, b -> comparePlaceIDs(a.location.id, b.location.id) }
            )
            .take(policy.maximumAnchorCount)
    }

    private fun make(distance: Double, source: String): Transfer? {
        if (!distance.isFinite() || distance !in 0.0..100_000.0) return null
        val minutes = ceil(distance / policy.walkingSpeedInMetersPerMinute)
        if (!minutes.isFinite() || minutes > Int.MAX_VALUE) return null
        return Transfer(
            distance,
            if (source == "sameStage") 0 else maxOf(1, minutes.toInt()),
            source,
        )
    }
}

internal fun comparePlaceIDs(a: String, b: String): Int {
    val x = a.removePrefix("n:").toLongOrNull()
    val y = b.removePrefix("n:").toLongOrNull()
    return if (x != null && y != null) x.compareTo(y)
    else if (x != null) -1 else if (y != null) 1 else a.compareTo(b)
}

/** Decoding belongs to the shared matrix; the platform only supplies resource bytes. */
object WalkingMatrices {
    @Throws(Exception::class)
    fun decode(sourceJSON: String): WalkingDistanceMatrix {
        val root = kotlinx.serialization.json.Json.parseToJsonElement(sourceJSON)
        require(root is kotlinx.serialization.json.JsonObject) { "Invalid walking-distance matrix" }
        val distances =
            root
                .mapNotNull { (source, targets) ->
                    val from = source.toLongOrNull() ?: return@mapNotNull null
                    if (targets !is kotlinx.serialization.json.JsonObject) return@mapNotNull null
                    "n:$from" to
                        targets
                            .mapNotNull { (target, value) ->
                                val to = target.toLongOrNull() ?: return@mapNotNull null
                                val number =
                                    value as? kotlinx.serialization.json.JsonPrimitive
                                        ?: return@mapNotNull null
                                if (number.isString) return@mapNotNull null
                                number.content.toDoubleOrNull()?.let { "n:$to" to it }
                            }
                            .toMap()
                }
                .toMap()
        return WalkingDistanceMatrix(distances)
    }
}
