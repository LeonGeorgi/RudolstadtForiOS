package de.leongeorgi.rudolstadt.presentation

import de.leongeorgi.rudolstadt.planning.EventMinutes

data class RecommendationState(
    val phase: LoadPhase = LoadPhase.LOADING,
    val eventIDs: List<Long> = emptyList(),
    val durations: List<EventMinutes>? = null,
    val generatedAt: Double? = null,
    val requestGeneration: Long = 0,
)

class RecommendationViewModel {
    private val cell = StateCell(RecommendationState())
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (RecommendationState) -> Unit) = cell.observe(observer)

    private var generation = 0L

    fun reset() {
        generation++
        cell.set(RecommendationState(requestGeneration = generation))
    }

    fun unavailable() {
        generation++
        cell.set(RecommendationState(LoadPhase.FAILED, requestGeneration = generation))
    }

    fun disable() {
        generation++
        cell.set(RecommendationState(LoadPhase.READY, requestGeneration = generation))
    }

    /** A newer input invalidates an in-flight result immediately, even during debounce. */
    fun inputsChanged(): Long = ++generation

    fun beginRefresh(): Long {
        generation++
        cell.set(RecommendationState(durations = current.durations, requestGeneration = generation))
        return generation
    }

    fun update(token: Long, ids: List<Long>, durations: List<EventMinutes>, now: Double) {
        if (token == generation)
            cell.set(RecommendationState(LoadPhase.READY, ids, durations, now, generation))
    }

    fun complete(
        token: Long,
        result: de.leongeorgi.rudolstadt.planning.RecommendationResult,
        now: Double,
    ) {
        update(token, result.eventIDs, result.durations, now)
    }

    fun beginCalculation(hasProgram: Boolean, planning: String): Long? =
        when (preparationAction(hasProgram, planning)) {
            "reset" -> {
                reset()
                null
            }
            "disable" -> {
                disable()
                null
            }
            "unavailable" -> {
                unavailable()
                null
            }
            else -> beginRefresh()
        }

    fun preparationAction(hasProgram: Boolean, planning: String): String =
        when {
            !hasProgram -> "reset"
            planning == "unsupported" -> "disable"
            planning == "unavailable" -> "unavailable"
            else -> "compute"
        }
}
