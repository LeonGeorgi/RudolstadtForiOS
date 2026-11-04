package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.festival.*
import de.leongeorgi.rudolstadt.planning.*
import kotlin.test.*

class PlanDayTimelineTests {
    private val walking = TransferSource { _, _ -> Transfer(400.0, 5, "knownRoute") }
    private val unknownWalking = TransferSource { _, _ -> null }

    private fun event(
        id: Long,
        minute: Int,
        duration: EventDuration? = null,
        stage: String = "$id",
    ) =
        ProgramOccurrence(
            id,
            1783155600.0 + minute * 60,
            1783123200.0,
            ProgramPlace(stage, mapOf("en" to stage)),
            ProgramArtist(
                id,
                "Artist $id",
                false,
                ProgramArtistDetails(ProgramContent(emptyMap())),
            ),
            emptyList(),
            eventDuration = duration,
        )

    @Test
    fun allConcertsRemainVisibleInChronologicalOrder() {
        val events = listOf(event(3, 420), event(1, 0), event(2, 240))
        val entries = PlanDayTimeline.entries(events, walking)
        assertEquals(listOf(1L, 2L, 3L), entries.map { it.event.eventID })
        assertSame(events[1], entries.first().event)
    }

    @Test
    fun fifteenMinuteOffsetOnlyMarksTheLaterConcert() {
        val first = event(1, 0)
        val second = event(2, 15)
        val entries = PlanDayTimeline.entries(listOf(first, second), walking)
        assertEquals(listOf(false, true), entries.map { it.hasConflict })
        assertEquals(listOf(first), entries.last().previousConflicts)
        assertEquals(
            listOf(first.startTimestamp, second.startTimestamp),
            entries.map { it.event.startTimestamp },
        )
        assertTrue(entries.last().incomingWalks.isEmpty())
    }

    @Test
    fun estimatedEndsIdentifyEarlierConflictsWithoutChangingDisplayTiming() {
        val first = event(1, 0, EventDuration(180, true))
        val second = event(2, 60)
        val entries = PlanDayTimeline.entries(listOf(first, second), walking)
        assertEquals(listOf(false, true), entries.map { it.hasConflict })
        assertEquals(listOf(first), entries.last().previousConflicts)
        assertNull(entries.first().event.confirmedDuration)
        assertEquals(first.startTimestamp, entries.first().event.startTimestamp)
    }

    @Test
    fun longRunningEarlierConcertIsCheckedEvenWhenItIsNotAdjacent() {
        val first = event(1, 0, EventDuration(120, false))
        val short = event(2, 30, EventDuration(15, false))
        val later = event(3, 90)
        val entries = PlanDayTimeline.entries(listOf(first, short, later), walking)
        assertEquals(listOf(false, true, true), entries.map { it.hasConflict })
        assertEquals(listOf(first), entries[1].previousConflicts)
        assertEquals(listOf(first), entries[2].previousConflicts)
    }

    @Test
    fun aConcertThatOnlyConflictsWithAFutureConcertStaysNeutral() {
        val first = event(1, 0, EventDuration(15, true))
        val middle = event(2, 60, EventDuration(60, true))
        val later = event(3, 90, EventDuration(60, true))
        val entries = PlanDayTimeline.entries(listOf(first, middle, later), walking)
        assertEquals(listOf(false, false, true), entries.map { it.hasConflict })
        assertEquals(listOf(middle), entries.last().previousConflicts)
    }

    @Test
    fun simultaneousConcertsUseStableOrderAndOnlyReferenceEarlierEntries() {
        val entries =
            PlanDayTimeline.entries(listOf(event(3, 0), event(1, 0), event(2, 0)), walking)
        assertEquals(listOf(1L, 2L, 3L), entries.map { it.id })
        assertEquals(listOf(false, true, true), entries.map { it.hasConflict })
        assertEquals(listOf(1L), entries[1].previousConflicts.map { it.eventID })
        assertEquals(listOf(1L, 2L), entries[2].previousConflicts.map { it.eventID })
    }

    @Test
    fun confirmedShortConcertDoesNotCreateFalseNearbyConflict() {
        val entries =
            PlanDayTimeline.entries(
                listOf(event(1, 0, EventDuration(5, false)), event(2, 15)),
                walking,
            )
        assertTrue(entries.none { it.hasConflict })
        assertFalse(entries.last().hasDashedConnectorBefore)
    }

    @Test
    fun incomingRouteBelongsToTheIndividualConcertNotFutureAlternatives() {
        val entries =
            PlanDayTimeline.entries(listOf(event(1, 0), event(2, 120), event(3, 135)), walking)
        assertEquals(listOf("2"), entries[1].incomingWalks.map { it.to.placeKey })
        assertTrue(entries[2].incomingWalks.isEmpty())
        assertEquals(event(2, 120).startTimestamp!! - 300, entries[1].departureTimestamp)
    }

    @Test
    fun followingConcertRetainsBothPossibleWalkingOrigins() {
        val entries =
            PlanDayTimeline.entries(
                listOf(
                    event(1, 0, EventDuration(60, true)),
                    event(2, 15, EventDuration(60, true)),
                    event(3, 180),
                ),
                walking,
            )
        val later = entries.last()
        assertFalse(later.hasConflict)
        assertEquals(setOf("1", "2"), later.incomingWalks.map { it.from.placeKey }.toSet())
        assertTrue(later.incomingWalks.all { it.to.placeKey == "3" })
    }

    @Test
    fun unknownRouteDoesNotInventADepartureOrMinimumLengthBreak() {
        val next =
            PlanDayTimeline.entries(
                    listOf(event(1, 0, EventDuration(30, false)), event(2, 120)),
                    unknownWalking,
                )
                .last()
        assertTrue(next.hasUnknownWalkingTime)
        assertNull(next.departureTimestamp)
        assertFalse(next.hasDashedConnectorBefore)
    }

    @Test
    fun samePlaceHasNoWalkingSectionAndUnplacedEventsStayOutOfTimedEntries() {
        val first = event(1, 0, EventDuration(30, false), "same")
        val second = event(2, 120, stage = "same")
        val unplaced = event(3, 0).copy(startTimestamp = null)
        val entries = PlanDayTimeline.entries(listOf(first, second, unplaced), walking)
        assertEquals(2, entries.size)
        assertTrue(entries.last().incomingWalks.isEmpty())
        assertTrue(entries.last().hasDashedConnectorBefore)
    }

    @Test
    fun insufficientWalkingTimeOnlyMarksTheLaterConcert() {
        val first = event(1, 0, EventDuration(30, false))
        val entries = PlanDayTimeline.entries(listOf(first, event(2, 32)), walking)
        assertEquals(listOf(false, true), entries.map { it.hasConflict })
        assertEquals(listOf(first), entries.last().previousConflicts)
    }

    @Test
    fun positiveStartGapWithoutAnyEndDoesNotEstablishAMinimumLengthBreak() {
        val entries = PlanDayTimeline.entries(listOf(event(1, 0), event(2, 240)), walking)
        assertFalse(entries.last().hasDashedConnectorBefore)
    }

    @Test
    fun partiallyUnknownOriginsDoNotPromiseASharedDepartureTime() {
        val partialWalking = TransferSource { from, _ ->
            if (from == "1") Transfer(400.0, 5, "knownRoute") else null
        }
        val last =
            PlanDayTimeline.entries(
                    listOf(
                        event(1, 0, EventDuration(60, true)),
                        event(2, 15, EventDuration(60, true)),
                        event(3, 180),
                    ),
                    partialWalking,
                )
                .last()
        assertTrue(last.hasUnknownWalkingTime)
        assertNull(last.departureTimestamp)
        assertFalse(last.hasDashedConnectorBefore)
    }

    @Test
    fun screenshotDayOnlyShowsTheLongBreaks() {
        val entries =
            PlanDayTimeline.entries(
                listOf(
                    event(1, 0, EventDuration(60, true), "Neumarkt"),
                    event(2, 360, EventDuration(60, true), "Schulplatz"),
                    event(3, 450, EventDuration(90, true), "Heinepark"),
                    event(4, 600, EventDuration(60, true), "Heinepark"),
                ),
                walking,
            )
        assertEquals(listOf(false, true, false, true), entries.map { it.hasDashedConnectorBefore })
        assertEquals(listOf(0, 1, 1, 0), entries.map { it.incomingWalks.size })
        assertTrue(entries.none { it.hasConflict })
    }

    @Test
    fun confirmedBackToBackConcertsKeepTheConnectorSolid() {
        val entries =
            PlanDayTimeline.entries(
                listOf(event(1, 0, EventDuration(60, false), "same"), event(2, 60, stage = "same")),
                walking,
            )
        assertFalse(entries.last().hasDashedConnectorBefore)
        assertTrue(entries.none { it.hasConflict })
    }

    @Test
    fun walkingTimeCanReduceTheGapBelowTheMinimumBreakLength() {
        val next =
            PlanDayTimeline.entries(
                    listOf(event(1, 0, EventDuration(60, true)), event(2, 120)),
                    walking,
                )
                .last()
        assertFalse(next.hasDashedConnectorBefore)
        assertEquals(event(2, 120).startTimestamp!! - 300, next.departureTimestamp)
    }

    @Test
    fun estimatedBackToBackConcertsAtTheSamePlaceKeepTheConnectorSolid() {
        val entries =
            PlanDayTimeline.entries(
                listOf(event(1, 0, EventDuration(60, true), "same"), event(2, 60, stage = "same")),
                walking,
            )
        assertFalse(entries.last().hasDashedConnectorBefore)
    }

    @Test
    fun minimumBreakIsInclusiveAtSixtyMinutesAfterWalking() {
        for ((nextMinute, expected) in listOf(124 to false, 125 to true, 126 to true)) {
            val entries =
                PlanDayTimeline.entries(
                    listOf(event(1, 0, EventDuration(60, true)), event(2, nextMinute)),
                    walking,
                )
            assertEquals(
                expected,
                entries.last().hasDashedConnectorBefore,
                "Start at minute $nextMinute",
            )
        }
    }

    @Test
    fun samePlaceDoesNotSubtractAnUnnecessaryWalkingTime() {
        val entries =
            PlanDayTimeline.entries(
                listOf(event(1, 0, EventDuration(60, true), "same"), event(2, 120, stage = "same")),
                walking,
            )
        assertTrue(entries.last().incomingWalks.isEmpty())
        assertTrue(entries.last().hasDashedConnectorBefore)
    }

    @Test
    fun breakAfterOverlappingConcertsUsesTheLatestPossibleEnd() {
        for ((nextMinute, expected) in listOf(240 to false, 245 to true)) {
            val last =
                PlanDayTimeline.entries(
                        listOf(
                            event(1, 0, EventDuration(120, true)),
                            event(2, 30, EventDuration(150, true)),
                            event(3, nextMinute),
                        ),
                        walking,
                    )
                    .last()
            assertFalse(last.hasConflict)
            assertEquals(expected, last.hasDashedConnectorBefore)
        }
    }
}
