package de.leongeorgi.rudolstadt.planning

import de.leongeorgi.rudolstadt.festival.*

data class EventMinutes(val eventID: Long, val minutes: Int)

/** Complete calculation result. Native clients retain it instead of rebuilding an output model. */
data class RecommendationResult(val eventIDs: List<Long>, val durations: List<EventMinutes>)

object ProgramRecommendations {
    fun build(
        program: FestivalProgram,
        saved: List<Long>,
        ratings: Map<String, Int>,
        now: Double,
        capabilityBacked: Boolean,
        eligibleIDs: Set<Long>?,
        transfer: TransferSource,
        cancelled: () -> Boolean,
    ): RecommendationResult {
        val durations =
            if (capabilityBacked)
                program.events.mapNotNull { event ->
                    event.eventDuration?.let { EventMinutes(event.eventID, it.minutes) }
                }
            else
                DurationResolver.resolve(
                        program.events.map {
                            it.planningEvent(
                                it.eventDuration?.minutes,
                                it.eligibleForPlanning,
                                false,
                            )
                        }
                    )
                    .map { EventMinutes(it.key, it.value.minutes) }
        if (capabilityBacked && eligibleIDs == null)
            return RecommendationResult(emptyList(), durations)
        val minutes = durations.associate { it.eventID to it.minutes }
        val events =
            program.events
                .filter {
                    eligibleIDs?.contains(it.eventID) ?: it.eligibleForPlanning
                }
                .map { it.planningEvent(minutes[it.eventID] ?: 60, true, true) }
        val places = events.mapNotNull { it.placeID }.distinct()
        val transfers = places.associateWith { from ->
            places
                .mapNotNull { to ->
                    if (cancelled()) return RecommendationResult(emptyList(), durations)
                    transfer.transfer(from, to)?.let { to to it }
                }
                .toMap()
        }
        val ids =
            RecommendationPlanner(
                    PlanningRequest(
                        events,
                        saved,
                        ratings
                            .mapNotNull { (id, value) -> id.toLongOrNull()?.let { it to value } }
                            .toMap(),
                        now,
                        transfers,
                        capabilityBacked,
                    ),
                    cancelled,
                )
                .generate()
        return RecommendationResult(ids, durations.sortedBy { it.eventID })
    }
}

data class ProgramSections(
    val scheduled: List<ProgramOccurrence>,
    val unknownTime: List<ProgramOccurrence>,
    val unknownDate: List<ProgramOccurrence>,
) {
    val unplaced
        get() = (unknownTime + unknownDate).sortedWith(ProgramSchedule.order)
}

object ProgramSchedule {
    internal val order =
        compareBy<ProgramOccurrence> { it.startTimestamp == null }
            .thenBy { it.startTimestamp }
            .thenBy { it.knownDateTimestamp == null }
            .thenBy { it.knownDateTimestamp }
            .thenBy { it.eventID }

    fun day(event: ProgramOccurrence): Int = event.festivalDayNumber

    fun precedes(first: ProgramOccurrence, second: ProgramOccurrence): Boolean =
        order.compare(first, second) < 0

    fun days(events: List<ProgramOccurrence>): List<Int> =
        events.map(::day).distinct().filter { it > 0 }.sorted()

    fun unplaced(events: List<ProgramOccurrence>): List<ProgramOccurrence> =
        events.filter { it.startTimestamp == null || it.assignedDay == null }.sortedWith(order)

    fun sections(
        events: List<ProgramOccurrence>,
        dayNumber: Int?,
        dayID: String?,
    ): ProgramSections {
        fun selected(e: ProgramOccurrence) =
            if (dayNumber != null) day(e) == dayNumber else e.assignedDay?.date?.id == dayID
        return ProgramSections(
            events.filter { it.startTimestamp != null && selected(it) },
            events.filter {
                it.startTimestamp == null && it.knownDateTimestamp != null && selected(it)
            },
            events.filter {
                if (dayNumber != null) it.knownDateTimestamp == null else it.assignedDay == null
            },
        )
    }
}

object ProgramTransitions {
    fun assess(
        first: ProgramOccurrence,
        firstDuration: Int,
        second: ProgramOccurrence,
        secondDuration: Int,
        policy: TransitionPolicy,
        transfer: TransferSource,
    ): TransitionAssessment {
        val order =
            compareBy<ProgramOccurrence> { it.startTimestamp }
                .thenBy {
                    it.startTimestamp?.plus(
                        (if (it === first) firstDuration else secondDuration).coerceAtLeast(0) * 60
                    )
                }
                .thenBy { it.eventID }
        val (a, b) = if (order.compare(first, second) <= 0) first to second else second to first
        return TransitionEvaluator.assess(
            first.planningEvent(firstDuration, true, true),
            firstDuration,
            second.planningEvent(secondDuration, true, true),
            secondDuration,
            transfer.transfer(a.stage.placeKey, b.stage.placeKey),
            policy,
        )
    }
}

data class PlanOverlap(val firstEventID: Long, val secondEventID: Long, val overlapMinutes: Int)

data class PlanFacts(val transitions: List<TransitionAssessment>, val overlaps: List<PlanOverlap>)

/** Plan facts serve native watch transport and Android without depending on either UI toolkit. */
object PlanFactsCalculator {
    fun calculate(
        events: List<ProgramOccurrence>,
        durations: List<EventMinutes>,
        defaultMinutes: Int,
        transfer: TransferSource,
    ): PlanFacts {
        val minutes = durations.associate { it.eventID to it.minutes }
        fun duration(event: ProgramOccurrence) = minutes[event.eventID] ?: defaultMinutes
        fun assess(a: ProgramOccurrence, b: ProgramOccurrence) =
            ProgramTransitions.assess(
                a,
                duration(a),
                b,
                duration(b),
                TransitionPolicy.savedEventWarning,
                transfer,
            )
        val transitions = mutableListOf<TransitionAssessment>()
        val overlaps = mutableListOf<PlanOverlap>()
        val priority =
            mapOf(
                "impossible" to 0,
                "tight" to 1,
                "unknown" to 2,
                "comfortable" to 3,
                "notApplicable" to 4,
            )
        val order =
            compareBy<TransitionAssessment> { priority[it.status] ?: 4 }
                .thenByDescending { it.projectedLatenessMinutes ?: -1 }
                .thenByDescending { it.transfer?.walkingMinutes ?: -1 }
                .thenBy { it.firstEventID }
        for ((_, dayEvents) in
            events.groupBy { it.festivalDayNumber }.toList().sortedBy { it.first }) {
            val sorted = dayEvents.sortedWith(ProgramSchedule.order)
            val groups = mutableListOf<MutableList<ProgramOccurrence>>()
            var groupEnd: Double? = null
            for (event in sorted) {
                val start = event.startTimestamp ?: continue
                val end = start + duration(event) * 60
                if (groupEnd != null && start < groupEnd) {
                    groups.last().add(event)
                    groupEnd = maxOf(groupEnd, end)
                } else {
                    groups.add(mutableListOf(event))
                    groupEnd = end
                }
            }
            groups.zipWithNext().forEach { (previous, next) ->
                next.forEach { event ->
                    previous.map { assess(it, event) }.minWithOrNull(order)?.let(transitions::add)
                }
            }
            for (first in sorted.indices) for (second in first + 1 until sorted.size) {
                val assessment = assess(sorted[first], sorted[second])
                if (assessment.timeOverlapMinutes > 0)
                    overlaps.add(
                        PlanOverlap(
                            assessment.firstEventID,
                            assessment.secondEventID,
                            assessment.timeOverlapMinutes,
                        )
                    )
            }
        }
        return PlanFacts(transitions, overlaps)
    }
}
