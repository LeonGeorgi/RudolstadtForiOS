package de.leongeorgi.rudolstadt.presentation

import de.leongeorgi.rudolstadt.festival.FestivalIdentity

data class FestivalSelectionState(val identity: FestivalIdentity)

class FestivalSelectionViewModel(
    private val registered: Set<FestivalIdentity>,
    private val defaultIdentity: FestivalIdentity,
    preferred: FestivalIdentity?,
    legacy: FestivalIdentity?,
    legacyYear: FestivalIdentity?,
    legacyPresent: Boolean,
) {
    private val cell =
        StateCell(
            FestivalSelectionState(
                preferred?.takeIf { it in registered }
                    ?: (if (legacyPresent) legacy?.takeIf { it in registered }
                    else legacyYear?.takeIf { it in registered })
                    ?: defaultIdentity
            )
        )
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (FestivalSelectionState) -> Unit) = cell.observe(observer)

    fun select(identity: FestivalIdentity) {
        cell.set(FestivalSelectionState(if (identity in registered) identity else defaultIdentity))
    }
}
