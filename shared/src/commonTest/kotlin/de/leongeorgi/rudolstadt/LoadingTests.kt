package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.festival.FestivalTime
import de.leongeorgi.rudolstadt.festival.ProgramEvent
import de.leongeorgi.rudolstadt.interop.CoreBridge
import de.leongeorgi.rudolstadt.loading.*
import kotlin.test.*

class LoadingTests {
    @Test
    fun freshCacheFinishesWithoutNetworkOrBundle() {
        assertEquals(
            ProgramLoadAction.KEEP_CONFIRMED,
            ProgramLoadSession(true, false).cacheRead(true, true),
        )
    }

    @Test
    fun staleCacheSurvivesAnOfflineRefresh() {
        val load = ProgramLoadSession(true, false)
        assertEquals(ProgramLoadAction.REFRESH, load.cacheRead(true, false))
        assertEquals(ProgramLoadAction.KEEP_CONFIRMED, load.remoteFailed())
    }

    @Test
    fun failedRemoteLoadUsesBackupOnlyWhenNothingWasConfirmed() {
        val load = ProgramLoadSession(true, false)
        assertEquals(ProgramLoadAction.REFRESH, load.cacheRead(false, false))
        assertEquals(ProgramLoadAction.READ_BUNDLE, load.remoteFailed())
        assertEquals(ProgramLoadAction.FAIL, load.bundleRead(false))
    }

    @Test
    fun validBundleResolvesInitialNetworkFailure() {
        val load = ProgramLoadSession(true, false)
        load.cacheRead(false, false)
        load.remoteFailed()
        assertEquals(ProgramLoadAction.KEEP_CONFIRMED, load.bundleRead(true))
    }

    @Test
    fun invalidCacheAndBackupCannotEraseAnAlreadyDisplayedProgram() {
        val load = ProgramLoadSession(false, true)
        assertEquals(ProgramLoadAction.READ_BUNDLE, load.cacheRead(false, false))
        assertEquals(ProgramLoadAction.KEEP_CONFIRMED, load.bundleRead(false))
    }

    @Test
    fun archiveNeverRequestsNetworkWhenItsCacheIsAbsent() {
        assertEquals(
            ProgramLoadAction.READ_BUNDLE,
            ProgramLoadSession(false, false).cacheRead(false, false),
        )
    }

    @Test
    fun cacheAgeHasTheExistingStrictThreeHourBoundary() {
        assertFalse(CachePolicy.isStale(1.0, 10801.0))
        assertTrue(CachePolicy.isStale(1.0, 10801.001))
        assertTrue(CachePolicy.isStale(null, 1.0))
        assertTrue(CachePolicy.isStale(Double.NaN, 1.0))
        assertEquals(
            "2026_rudolstadt_data.json",
            CachePolicy.fileName(2026, "rudolstadt_data.json"),
        )
    }

    @Test
    fun olderRefreshMayNotCommitAfterANewerRefreshStarted() {
        val generation = RefreshGeneration()
        val first = generation.begin()
        val second = generation.begin()
        assertFalse(generation.isCurrent(first))
        assertTrue(generation.isCurrent(second))
    }

    @Test
    fun httpStatusClassificationPreservesFailureOwnership() {
        assertTrue(HttpPolicy.isSuccess(299))
        assertFalse(HttpPolicy.isSuccess(300))
        assertEquals(HttpFailureOwner.CLIENT, HttpPolicy.failureOwner(429))
        assertEquals(HttpFailureOwner.SERVER, HttpPolicy.failureOwner(503))
        assertEquals(HttpFailureOwner.UNKNOWN, HttpPolicy.failureOwner(302))
    }

    @Test
    fun malformedSourceIsAnErrorAndNeverAFabricatedProgram() {
        assertFailsWith<IllegalArgumentException> {
            CoreBridge().convertRudolstadt("{", "{}", 2026)
        }
        assertFailsWith<IllegalArgumentException> { CoreBridge().validSitePlan("{}", "[]") }
    }

    @Test
    fun unsupportedSourceDateFormatIsUnknown() {
        assertNull(FestivalTime.parse("2026", "not a supported format", "Europe/Berlin"))
    }

    @Test
    fun nativeEntriesRetain64BitIDsWithoutNumericDictionaryKeys() {
        val id = 136107827955517L
        val bridge = CoreBridge()
        val event = ProgramEvent(id, 1L, "n:1", 1783108800.0, duration = 45)
        val duration = bridge.durations(listOf(event)).single()
        assertEquals(id, duration.eventID)
        assertEquals(45, duration.duration.minutes)
        val assignment = bridge.assignDays(listOf(event), "Europe/Berlin", 5, null)
        assertEquals(id, assignment.eventDays.single().eventID)
        assertEquals(assignment.days.single().id, assignment.eventDays.single().dayID)
    }
}
