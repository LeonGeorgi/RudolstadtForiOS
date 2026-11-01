package de.leongeorgi.rudolstadt.planning

import de.leongeorgi.rudolstadt.festival.ProgramEvent
import kotlin.math.*
import kotlinx.serialization.Serializable

@Serializable
data class TransitionPolicy(
    val arrivalBufferMinutes: Int,
    val maximumMissedMinutes: Int,
    val tightTransitionThresholdMinutes: Int,
    val estimatedTransfersCanBlock: Boolean,
) {
    companion object {
        val recommendation = TransitionPolicy(2, 0, 5, false)
        val savedEventWarning = TransitionPolicy(0, 5, 5, true)
    }
}

@Serializable
data class TransitionAssessment(
    val firstEventID: Long,
    val secondEventID: Long,
    val timeOverlapMinutes: Int,
    val availableTransferMinutes: Int? = null,
    val transfer: Transfer? = null,
    val projectedLatenessMinutes: Int? = null,
    val status: String,
) {
    val isConflict
        get() = status == "impossible"
}

object TransitionEvaluator {
    fun assess(
        first: ProgramEvent,
        firstDuration: Int,
        second: ProgramEvent,
        secondDuration: Int,
        transfer: Transfer?,
        policy: TransitionPolicy,
    ): TransitionAssessment {
        val firstBefore =
            compareValues(first.start, second.start).takeIf { it != 0 }
                ?: compareValues(
                        first.start?.plus(maxOf(0, firstDuration) * 60),
                        second.start?.plus(maxOf(0, secondDuration) * 60),
                    )
                    .takeIf { it != 0 }
                ?: first.id.compareTo(second.id)
        val a = if (firstBefore <= 0) first else second
        val b = if (firstBefore <= 0) second else first
        val da = maxOf(0, if (firstBefore <= 0) firstDuration else secondDuration)
        val db = maxOf(0, if (firstBefore <= 0) secondDuration else firstDuration)
        if (a.start == null || b.start == null)
            return TransitionAssessment(first.id, second.id, 0, status = "unknown")
        if ((a.dayID ?: a.dayNumber.toString()) != (b.dayID ?: b.dayNumber.toString()))
            return TransitionAssessment(a.id, b.id, 0, status = "notApplicable")
        val aEnd = a.start + da * 60
        val bEnd = b.start + db * 60
        val overlap = ceil(maxOf(0.0, minOf(aEnd, bEnd) - maxOf(a.start, b.start)) / 60).toInt()
        val available = floor((b.start - aEnd) / 60 - maxOf(0, policy.arrivalBufferMinutes)).toInt()
        val lateness = transfer?.let { maxOf(0, it.walkingMinutes - available) }
        val missed = maxOf(0, policy.maximumMissedMinutes)
        val status =
            when {
                overlap > missed -> "impossible"
                transfer == null || lateness == null -> "unknown"
                lateness > missed ->
                    if (transfer.isEstimated && !policy.estimatedTransfersCanBlock) "unknown"
                    else "impossible"
                available - transfer.walkingMinutes <=
                    maxOf(0, policy.tightTransitionThresholdMinutes) -> "tight"
                else -> "comfortable"
            }
        return TransitionAssessment(a.id, b.id, overlap, available, transfer, lateness, status)
    }
}

@Serializable
data class PlanningRequest(
    val events: List<ProgramEvent>,
    val savedEventIDs: List<Long>,
    val ratings: Map<Long, Int>,
    val now: Double,
    val transfers: Map<String, Map<String, Transfer>> = emptyMap(),
    val requiresKnownTransfers: Boolean = false,
)

class RecommendationPlanner(
    private val request: PlanningRequest,
    private val cancelled: () -> Boolean = { false },
) {
    fun score(event: ProgramEvent): Int = (request.ratings[event.artistID] ?: 0).let { it * it }

    fun generate(): List<Long> {
        if (cancelled()) return emptyList()
        val events = request.events.filter { it.eligible }
        val savedIDs = request.savedEventIDs.toSet()
        val order =
            compareBy<ProgramEvent> { it.dayNumber }.thenBy { it.startMinutes }.thenBy { it.id }
        val priority = compareByDescending<ProgramEvent> { score(it) }.then(order)
        val saved = events.filter { it.id in savedIDs }.sortedWith(order)
        val savedArtists = saved.map { it.artistID }.toSet()
        val interesting =
            events
                .filter {
                    (request.ratings[it.artistID] ?: 0) > 0 &&
                        it.id !in savedIDs &&
                        it.artistID !in savedArtists &&
                        saved.none { other -> intersects(other, it) } &&
                        it.start != null &&
                        it.start >= request.now
                }
                .sortedWith(priority)
        val groups = interesting.groupBy { it.artistID }
        var solution = saved.toMutableList()
        groups.keys
            .sortedWith(compareByDescending<Long> { request.ratings[it] ?: 0 }.thenBy { it })
            .forEach { artist ->
                if (cancelled()) return emptyList()
                groups[artist]
                    .orEmpty()
                    .firstOrNull { event -> solution.none { intersects(it, event) } }
                    ?.let { solution.add(it) }
            }
        solution.sortWith(order)
        var improved = true
        while (improved) {
            if (cancelled()) return emptyList()
            improved = false
            interesting.forEach { event ->
                if (solution.none { it.id == event.id }) {
                    val conflicts = solution.filter {
                        it.id !in savedIDs &&
                            (it.artistID == event.artistID || intersects(it, event))
                    }
                    if (score(event) > conflicts.sumOf { score(it) }) {
                        val candidate = solution.filter { it !in conflicts }
                        if (candidate.none { intersects(it, event) }) {
                            solution = (candidate + event).sortedWith(order).toMutableList()
                            improved = true
                        }
                    }
                }
            }
        }
        return solution.filter { it.id !in savedIDs }.map { it.id }
    }

    private fun intersects(a: ProgramEvent, b: ProgramEvent): Boolean {
        val order =
            compareBy<ProgramEvent> { it.start }
                .thenBy { it.start?.plus((it.duration ?: 60) * 60) }
                .thenBy { it.id }
        val (from, to) = if (order.compare(a, b) <= 0) a to b else b to a
        val transfer = request.transfers[from.placeID]?.get(to.placeID)
        val assessment =
            TransitionEvaluator.assess(
                a,
                a.duration ?: 60,
                b,
                b.duration ?: 60,
                transfer,
                TransitionPolicy.recommendation,
            )
        return assessment.isConflict ||
            (request.requiresKnownTransfers && assessment.status == "unknown")
    }
}
