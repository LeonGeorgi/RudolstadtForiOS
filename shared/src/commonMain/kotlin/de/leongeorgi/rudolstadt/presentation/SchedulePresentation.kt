package de.leongeorgi.rudolstadt.presentation

import de.leongeorgi.rudolstadt.discovery.ScheduleFilter
import de.leongeorgi.rudolstadt.festival.ProgramOccurrence

data class ScheduleState(
    val phase: LoadPhase,
    val events: List<ProgramOccurrence>,
    val failure: String? = null,
)

/** A derived UI state; both native screens read the same filter and loading decisions. */
object SchedulePresentation {
    fun shown(
        events: List<ProgramOccurrence>,
        filter: String,
        profile: ProfileState,
        recommendation: RecommendationState,
    ): ScheduleState {
        if (filter == "optimal" && recommendation.phase != LoadPhase.READY) {
            return ScheduleState(
                recommendation.phase,
                emptyList(),
                if (recommendation.phase == LoadPhase.FAILED) "couldNotLoadFromFile" else null,
            )
        }
        return ScheduleState(
            LoadPhase.READY,
            ScheduleFilter.occurrences(
                events,
                filter,
                profile.saved,
                profile.positiveArtistIDs,
                (recommendation.eventIDs + recommendation.savedEventIDs).toSet(),
            ),
        )
    }
}
