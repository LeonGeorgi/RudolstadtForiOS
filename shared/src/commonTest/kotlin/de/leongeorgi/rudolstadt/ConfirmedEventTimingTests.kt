package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.festival.*
import kotlin.test.*

class ConfirmedEventTimingTests {
    private fun event(duration: EventDuration?) =
        ProgramOccurrence(
            1,
            1000.0,
            1000.0,
            ProgramPlace("stage", mapOf("en" to "Stage")),
            ProgramArtist(2, "Artist", false, ProgramArtistDetails(ProgramContent(emptyMap()))),
            emptyList(),
            eventDuration = duration,
        )

    @Test
    fun estimatedDurationIsNotDisplayedButKeepsKnownStartAndPlanningTiming() {
        val duration = EventDuration(90, true)
        val occurrence = event(duration)
        assertNull(occurrence.confirmedDuration)
        assertEquals(1000.0, occurrence.startTimestamp)
        assertEquals(duration, occurrence.eventDuration)
        assertEquals(
            90,
            occurrence.planningEvent(occurrence.eventDuration?.minutes, true, false).duration,
        )
    }

    @Test
    fun explicitDurationCanBeDisplayed() {
        val duration = EventDuration(75, false)
        assertEquals(duration, event(duration).confirmedDuration)
    }

    @Test
    fun missingDurationDoesNotCreateADisplayValue() {
        assertNull(event(null).confirmedDuration)
    }
}
