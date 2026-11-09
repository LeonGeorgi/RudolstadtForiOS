package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.discovery.Discovery
import de.leongeorgi.rudolstadt.discovery.DiscoveryArtist
import de.leongeorgi.rudolstadt.discovery.TextCollation
import de.leongeorgi.rudolstadt.festival.DurationResolver
import de.leongeorgi.rudolstadt.festival.EventDuration
import de.leongeorgi.rudolstadt.festival.FestivalTime
import de.leongeorgi.rudolstadt.festival.ProgramEvent
import de.leongeorgi.rudolstadt.festival.RudolstadtSource
import de.leongeorgi.rudolstadt.interop.CoreBridge
import de.leongeorgi.rudolstadt.interop.WalkingEngine
import de.leongeorgi.rudolstadt.planning.PlaceLocation
import de.leongeorgi.rudolstadt.planning.PlanningRequest
import de.leongeorgi.rudolstadt.planning.RecommendationPlanner
import de.leongeorgi.rudolstadt.planning.Transfer
import de.leongeorgi.rudolstadt.planning.TransferEstimator
import de.leongeorgi.rudolstadt.planning.TransferPolicy
import de.leongeorgi.rudolstadt.planning.TransitionEvaluator
import de.leongeorgi.rudolstadt.planning.TransitionPolicy
import de.leongeorgi.rudolstadt.planning.WalkingDistanceMatrix
import de.leongeorgi.rudolstadt.profile.ArtistNote
import de.leongeorgi.rudolstadt.profile.ArtistPreference
import de.leongeorgi.rudolstadt.profile.PersonalProfile
import de.leongeorgi.rudolstadt.profile.ProfileMutation
import de.leongeorgi.rudolstadt.profile.ProfileRecordChange
import de.leongeorgi.rudolstadt.profile.ProfileRecordValue
import de.leongeorgi.rudolstadt.profile.ProfileReducer
import de.leongeorgi.rudolstadt.profile.ProfileSync
import de.leongeorgi.rudolstadt.profile.ProfileSyncAction
import de.leongeorgi.rudolstadt.profile.ProfileVersion
import kotlin.test.*
import kotlinx.serialization.json.*

class CoreTests {
    private fun event(
        id: Int,
        start: Double?,
        artist: Int = id,
        place: String? = "n:1",
        duration: Int? = null,
    ) =
        ProgramEvent(
            id.toLong(),
            artist.toLong(),
            place,
            start,
            dayNumber = 4,
            startMinutes = (start ?: 0.0).toInt() / 60,
            duration = duration,
        )

    @Test
    fun durationPreservesPublishedValuesAndMarksEstimates() {
        val result =
            DurationResolver.resolve(
                listOf(event(1, 0.0), event(2, 1800.0, duration = 45), event(3, 7200.0))
            )
        assertEquals(EventDuration(30, true), result[1L])
        assertEquals(EventDuration(45, false), result[2L])
        assertEquals(EventDuration(60, true), result[3L])
    }

    @Test
    fun unknownTimeAndPlaceDoNotReceiveInventedDurations() {
        assertTrue(
            DurationResolver.resolve(listOf(event(1, null), event(2, 0.0, place = null))).isEmpty()
        )
    }

    @Test
    fun graphUsesShortestPathsAndRejectsInvalidDistances() {
        val matrix =
            WalkingDistanceMatrix(
                mapOf("a" to mapOf("b" to 100.0, "bad" to Double.NaN), "b" to mapOf("c" to 150.0))
            )
        assertEquals(250.0, matrix.distance("c", "a"))
        assertNull(matrix.distance("a", "c", setOf("a", "c")))
        assertFalse("bad" in matrix.placeIDs)
    }

    @Test
    fun matrixKeepsSmallestUndirectedEdge() {
        val matrix =
            WalkingDistanceMatrix(mapOf("a" to mapOf("b" to 100.0), "b" to mapOf("a" to 80.0)))
        assertEquals(80.0, matrix.distance("a", "b"))
    }

    @Test
    fun transferUsesKnownRouteAndRoundsUpMinutes() {
        val locations =
            listOf(PlaceLocation("n:1", 50.0, 11.0), PlaceLocation("n:2", 50.0001, 11.0))
        val estimator =
            TransferEstimator(
                locations,
                WalkingDistanceMatrix(mapOf("n:1" to mapOf("n:2" to 161.0))),
            )
        assertEquals(Transfer(161.0, 3, "knownRoute"), estimator.estimate("n:1", "n:2"))
        assertEquals(Transfer(0.0, 0, "sameStage"), estimator.estimate("n:1", "n:1"))
    }

    @Test
    fun sameNumericAndTextIDsRemainDistinct() {
        assertNull(
            TransferEstimator(emptyList(), WalkingDistanceMatrix(emptyMap())).estimate("n:1", "t:1")
        )
    }

    @Test
    fun estimatedWalkDoesNotBlockRecommendationsButWarnsForSavedEvents() {
        val a = event(1, 0.0)
        val b = event(2, 3600.0)
        val transfer = Transfer(1000.0, 15, "directCoordinateEstimate")
        assertEquals(
            "unknown",
            TransitionEvaluator.assess(a, 60, b, 60, transfer, TransitionPolicy.recommendation)
                .status,
        )
        assertEquals(
            "impossible",
            TransitionEvaluator.assess(a, 60, b, 60, transfer, TransitionPolicy.savedEventWarning)
                .status,
        )
    }

    @Test
    fun overlapsBlockEvenWithoutKnownTransfer() {
        assertEquals(
            "impossible",
            TransitionEvaluator.assess(
                    event(1, 0.0),
                    60,
                    event(2, 1800.0),
                    60,
                    null,
                    TransitionPolicy.recommendation,
                )
                .status,
        )
    }

    @Test
    fun programDayIdentitySeparatesEqualDayNumbersAcrossMonths() {
        val a = event(1, 0.0).copy(dayID = "2026-06-04")
        val b = event(2, 0.0).copy(dayID = "2026-07-04")
        assertEquals(
            "notApplicable",
            TransitionEvaluator.assess(a, 60, b, 60, null, TransitionPolicy.recommendation).status,
        )
    }

    @Test
    fun recommendationRespectsSavedArtistsAndFutureDates() {
        val events =
            listOf(
                event(1, 0.0),
                event(2, 7200.0, artist = 1),
                event(3, 14400.0, artist = 2),
                event(4, -7200.0, artist = 3),
            )
        val request = PlanningRequest(events, listOf(1L), mapOf(1L to 3, 2L to 2, 3L to 3), 0.0)
        assertEquals(listOf(3L), RecommendationPlanner(request).generate())
    }

    @Test
    fun requiredMissingTransfersDoNotProducePlausibleSchedules() {
        val request =
            PlanningRequest(
                listOf(event(1, 0.0), event(2, 7200.0)),
                listOf(1L),
                mapOf(2L to 3),
                0.0,
                requiresKnownTransfers = true,
            )
        assertTrue(RecommendationPlanner(request).generate().isEmpty())
    }

    @Test
    fun profileMutationsRetainUnrelatedStateAndNormalizeOrder() {
        val original =
            PersonalProfile(
                "Me",
                30.0,
                listOf(3L, 1L, 3L),
                listOf(ArtistPreference(1, -1, "star")),
                listOf(ArtistNote(3, "Keep")),
            )
        val changed =
            ProfileReducer.apply(original, ProfileMutation("setArtistRating", 1, rating = 2))
        assertEquals(listOf(1L, 3L), changed.savedEventIDs)
        assertEquals(listOf(ArtistPreference(1, 2)), changed.artistPreferences)
        assertEquals(original.artistNotes, changed.artistNotes)
    }

    @Test
    fun noteDeletionAndUnsavingAreExplicit() {
        val original =
            PersonalProfile(null, 30.0, listOf(2L), artistNotes = listOf(ArtistNote(2, "text")))
        val deleted =
            ProfileReducer.apply(original, ProfileMutation("setArtistNote", 2, text = "  \n "))
        assertTrue(deleted.artistNotes.isEmpty())
        assertTrue(
            ProfileReducer.apply(deleted, ProfileMutation("toggleSavedEvent", 2))
                .savedEventIDs
                .isEmpty()
        )
    }

    @Test
    fun dateParsingIsStrictAndIndependentOfDeviceZone() {
        assertNull(FestivalTime.parse("31.02.2026", "dd.MM.yyyy", "Europe/Berlin"))
        assertNull(FestivalTime.parse("29.03.2026 02:30", "dd.MM.yyyy HH:mm", "Europe/Berlin"))
        assertEquals(
            7200.0,
            FestivalTime.parse("04.07.2026 12:00", "dd.MM.yyyy HH:mm", "UTC")!! -
                FestivalTime.parse("04.07.2026 12:00", "dd.MM.yyyy HH:mm", "Europe/Berlin")!!,
        )
    }

    @Test
    fun earlyMorningBelongsToPreviousFestivalDay() {
        val now = FestivalTime.parse("05.07.2026 04:59", "dd.MM.yyyy HH:mm", "Europe/Berlin")!!
        assertEquals(4, FestivalTime.currentDay(listOf(4, 5), now, 2026, 7))
        assertNull(FestivalTime.currentDay(listOf(4, 5), now, 2025, 7))
    }

    @Test
    fun apiTimestampPreservesMicrosecondsAndRejectsBadZones() {
        val base =
            FestivalTime.parse("2026-07-04 12:00:00", "yyyy-MM-dd HH:mm:ss", "Europe/Berlin")!!
        assertEquals(
            base + .123456,
            FestivalTime.apiTime("2026-07-04 12:00:00.123456", "Europe/Berlin"),
        )
        assertNull(FestivalTime.apiTime("2026-07-04 12:00:00.000000", "bad-zone"))
        assertNull(FestivalTime.apiTime("2026-07-04 12:00.000000", "Europe/Berlin"))
        assertNull(FestivalTime.parse("2026-07-04 12:00:00", "yyyy-MM-dd HH:mm", "Europe/Berlin"))
    }

    @Test
    fun localizationFallsBackByRegionThenDefaultThenStableOrder() {
        val bridge = CoreBridge()
        assertEquals(
            "Bonjour",
            bridge.resolveText(mapOf("fr" to "Bonjour", "en" to "Hello"), "fr_CA", "en"),
        )
        assertEquals(
            "Hello",
            bridge.resolveText(mapOf("fr" to "Bonjour", "en" to "Hello"), "ja", "en"),
        )
    }

    @Test
    fun htmlNumericEntitiesPreserveEmojiAndInvalidScalars() {
        assertEquals(
            "🎵 & invalid: &#xD800;",
            CoreBridge().decodeCharacterReferences("&#x1F3B5; &#38; invalid: &#xD800;"),
        )
    }

    @Test
    fun sourceRetainsIdentifiableEventsWithMissingReferences() {
        val root =
            Json.parseToJsonElement(
                    """{"artists":[],"areas":[],"stages":[],"tags":[],"events":[{"id":12}]}"""
                )
                .jsonObject
        val program = RudolstadtSource(2026).convert(root, JsonObject(emptyMap()))
        assertEquals(-12L, program.artists.single().id)
        assertFalse(program.artists.single().isMetadataAvailable)
        assertNull(program.events.single().start)
    }

    @Test
    fun sourceCountsDuplicateAndMalformedRecords() {
        val root =
            Json.parseToJsonElement(
                    """{"artists":[{"id":1},{"id":1},{"name":"bad"}],"areas":[],"stages":[],"tags":[],"events":[],"omittedRecordCount":2}"""
                )
                .jsonObject
        assertEquals(
            5,
            RudolstadtSource(2026).convert(root, JsonObject(emptyMap())).omittedRecordCount,
        )
    }

    @Test
    fun typedBridgeKeepsNonFiniteCoordinatesUnknown() {
        val value =
            WalkingEngine(
                listOf(PlaceLocation("a", Double.NaN, Double.NaN)),
                emptyMap(),
                TransferPolicy(),
            )
        assertNull(value.estimate("a", "b"))
    }

    @Test
    fun cancelledPlanningDoesNotPublishAPartialSchedule() {
        val request = PlanningRequest(listOf(event(1, 0.0)), emptyList(), mapOf(1L to 3), 0.0)
        assertTrue(RecommendationPlanner(request, cancelled = { true }).generate().isEmpty())
    }

    @Test
    fun profileVersionsConvergeAcrossDeliveryOrderAndKeepTombstones() {
        val older = ProfileVersion(1.0, "b")
        val newer = ProfileVersion(1.0, "c")
        assertTrue(ProfileSync.localWins(newer, older))
        assertFalse(ProfileSync.localWins(older, newer))
        val record = ProfileRecordValue("event", 4, isSaved = false)
        val change = ProfileRecordChange("event:4", record, newer)
        assertEquals(
            listOf(ProfileSyncAction("profile"), ProfileSyncAction("event:4")),
            ProfileSync.changes(emptyList(), listOf(change)),
        )
    }

    @Test
    fun artistOverviewUsesHostCollationAndPreservesEqualNameRatingOrder() {
        val reverse =
            object : TextCollation {
                override fun compare(a: String, b: String) = b.compareTo(a)
            }
        val artists = listOf(DiscoveryArtist(1, "A"), DiscoveryArtist(2, "B"))
        assertEquals(
            listOf(2L, 1L),
            Discovery.artistOverview(artists, false, emptyMap(), "", reverse),
        )
    }

    @Test
    fun malformedLocalizedRecordsAreCountedBeforeDuplicateIDs() {
        val root =
            Json.parseToJsonElement(
                    """{"artists":[],"areas":[{"id":1,"title":"Park","title_en":"Park"},{"id":1,"title":"broken"}],"stages":[],"tags":[{"id":2,"title":"broken"}],"events":[]}"""
                )
                .jsonObject
        val program = RudolstadtSource(2026).convert(root, JsonObject(emptyMap()))
        assertEquals(1, program.areas.size)
        assertTrue(program.tags.isEmpty())
        assertEquals(2, program.omittedRecordCount)
    }
}
