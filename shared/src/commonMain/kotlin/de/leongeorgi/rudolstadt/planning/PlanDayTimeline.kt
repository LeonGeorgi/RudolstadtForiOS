package de.leongeorgi.rudolstadt.planning

import de.leongeorgi.rudolstadt.festival.ProgramOccurrence
import de.leongeorgi.rudolstadt.festival.ProgramPlace

data class PlanTimelineWalk(
    val from: ProgramPlace,
    val to: ProgramPlace,
    val transfer: Transfer?,
    val departureTimestamp: Double?,
)

data class PlanTimelineEntry(
    val event: ProgramOccurrence,
    val previousConflicts: List<ProgramOccurrence>,
    val incomingWalks: List<PlanTimelineWalk>,
    /** A break of at least an hour after walking; calculated concert ends stay hidden. */
    val hasDashedConnectorBefore: Boolean,
) {
    val id: Long
        get() = event.eventID

    val hasConflict: Boolean
        get() = previousConflicts.isNotEmpty()

    val hasUnknownWalkingTime: Boolean
        get() = incomingWalks.any { it.transfer == null }

    val minimumWalkingMinutes: Int?
        get() = incomingWalks.mapNotNull { it.transfer?.walkingMinutes }.minOrNull()

    val maximumWalkingMinutes: Int?
        get() = incomingWalks.mapNotNull { it.transfer?.walkingMinutes }.maxOrNull()

    val departureTimestamp: Double?
        get() =
            if (hasUnknownWalkingTime) null
            else incomingWalks.mapNotNull { it.departureTimestamp }.minOrNull()
}

/** A chronological view of the selected day, including past saved concerts. */
object PlanDayTimeline {
    // Warn about near-simultaneous starts without inventing an end for an untimed concert.
    private const val NEARBY_START_SECONDS = 15 * 60.0
    private const val MINIMUM_BREAK_SECONDS = 60 * 60.0

    fun entries(
        events: List<ProgramOccurrence>,
        transfer: TransferSource,
    ): List<PlanTimelineEntry> {
        val sorted =
            events
                .filter { it.startTimestamp?.isFinite() == true }
                .sortedWith(ProgramSchedule.order)
        // Retain possible origins after overlapping concerts without choosing what was attended.
        var recentChoices = emptyList<ProgramOccurrence>()
        return sorted.mapIndexed { index, event ->
            val previousConflicts =
                sorted.subList(0, index).filter {
                    conflictsWith(it, event, transfer)
                }
            val previous =
                if (previousConflicts.isEmpty())
                    recentChoices.filter {
                        it.festivalDayNumber == event.festivalDayNumber
                    }
                else emptyList()
            val walks =
                previous
                    .mapNotNull { from ->
                        if (from.stage.placeKey == event.stage.placeKey) return@mapNotNull null
                        val route = transfer.transfer(from.stage.placeKey, event.stage.placeKey)
                        if (route?.walkingMinutes == 0) return@mapNotNull null
                        PlanTimelineWalk(
                            from.stage,
                            event.stage,
                            route,
                            route?.let { event.startTimestamp?.minus(it.walkingMinutes * 60.0) },
                        )
                    }
                    .distinctBy { it.from.placeKey to it.to.placeKey }
            val planningEnds = previous.mapNotNull(::planningEnd)
            val nextDeparture =
                walks.mapNotNull { it.departureTimestamp }.minOrNull() ?: event.startTimestamp
            val dashedConnector =
                previous.isNotEmpty() &&
                    planningEnds.size == previous.size &&
                    walks.none { it.transfer == null } &&
                    nextDeparture != null &&
                    planningEnds.maxOrNull()?.let {
                        nextDeparture - it >= MINIMUM_BREAK_SECONDS
                    } == true
            recentChoices =
                if (previousConflicts.isEmpty()) listOf(event) else recentChoices + event
            PlanTimelineEntry(event, previousConflicts, walks, dashedConnector)
        }
    }

    private fun conflictsWith(
        first: ProgramOccurrence,
        second: ProgramOccurrence,
        transfer: TransferSource,
    ): Boolean {
        if (first.festivalDayNumber != second.festivalDayNumber) return false
        val firstStart = first.startTimestamp ?: return false
        val secondStart = second.startTimestamp ?: return false
        val end = planningEnd(first)
        if (end == null) return secondStart - firstStart <= NEARBY_START_SECONDS
        if (secondStart < end) return true
        val walkingMinutes =
            if (first.stage.placeKey == second.stage.placeKey) 0
            else
                transfer.transfer(first.stage.placeKey, second.stage.placeKey)?.walkingMinutes
                    ?: return false
        return end + walkingMinutes * 60.0 > secondStart
    }

    /**
     * Source estimates participate in planning, while confirmedDuration remains the display API.
     */
    private fun planningEnd(event: ProgramOccurrence): Double? =
        event.eventDuration
            ?.takeIf { it.minutes > 0 }
            ?.let {
                event.startTimestamp?.plus(it.minutes * 60.0)
            }
}
