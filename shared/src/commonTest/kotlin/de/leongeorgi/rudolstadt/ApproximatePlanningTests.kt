package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.festival.*
import de.leongeorgi.rudolstadt.planning.*
import kotlin.test.*

class ApproximatePlanningTests {
    private val locations =
        listOf(
            PlaceLocation("n:1", 50.7180, 11.3320),
            PlaceLocation("n:2", 50.7198, 11.3345),
            PlaceLocation("n:3", 50.7216, 11.3370),
        )

    private fun catalog(places: List<PlaceLocation> = locations) =
        ProgramDistanceCatalog(
            TransferEstimator(places, WalkingDistanceMatrix(emptyMap())),
            places.map {
                ProgramCoordinate(
                    it.id,
                    PlanCoordinate(it.latitude, it.longitude, true, null),
                )
            },
            places.map { it.id }.toSet(),
            setOf(1L, 2L, 3L, 4L),
        )

    @Test
    fun approximatePositionsProvidePlanningEstimatesAndRetainTheirUncertainty() {
        val catalog = catalog()
        val walking = assertNotNull(catalog.walking("n:1", "n:2"))
        val planning = assertNotNull(catalog.planningTransfer("n:1", "n:2"))
        assertEquals(walking, planning)
        assertTrue(planning.approximate)
        assertTrue(planning.transfer.isEstimated)
        assertTrue(planning.transfer.walkingMinutes > 0)
        assertEquals(planning.transfer, catalog.transfer("n:1", "n:2"))
    }

    @Test
    fun remainingOnAnApproximateStageNeedsNoWalkingTime() {
        val transfer = assertNotNull(catalog().planningTransfer("n:1", "n:1"))
        assertEquals(0, transfer.transfer.walkingMinutes)
        assertEquals("sameStage", transfer.transfer.source)
        assertTrue(transfer.approximate)
    }

    @Test
    fun estimatesAllowSeveralConcertsButStillNeedEnoughWalkingTime() {
        fun event(id: Long, minutes: Int, place: Int) =
            ProgramOccurrence(
                id,
                1783094400.0 + minutes * 60,
                1783036800.0,
                ProgramPlace("n:$place", mapOf("en" to "Stage $place")),
                ProgramArtist(
                    id,
                    "Artist $id",
                    false,
                    ProgramArtistDetails(ProgramContent(emptyMap())),
                ),
                emptyList(),
                EventDuration(60, false),
            )
        val events = listOf(event(1, 0, 1), event(2, 61, 2), event(3, 90, 2), event(4, 180, 3))
        val program =
            FestivalProgram(
                events.map { it.artist },
                emptyList(),
                events.map { it.stage }.distinctBy { it.placeKey },
                events,
                0,
                2026,
            )
        val catalog = catalog()
        val result =
            ProgramRecommendations.build(
                program,
                emptyList(),
                events.associate { it.artist.artistID.toString() to 2 },
                0.0,
                true,
                catalog.eligibleIDs,
                catalog,
            ) {
                false
            }
        assertEquals(listOf(1L, 3L, 4L), result.eventIDs)
    }

    @Test
    fun missingPositionsAndUnknownStagesDoNotAcquireInventedWalkingTimes() {
        val catalog = catalog(locations + PlaceLocation("n:4", Double.NaN, Double.NaN))
        assertNull(catalog.planningTransfer("n:1", "n:4"))
        assertNull(catalog.planningTransfer("n:1", "unknown"))
    }
}
