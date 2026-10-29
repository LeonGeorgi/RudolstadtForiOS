package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.festival.*
import de.leongeorgi.rudolstadt.news.*
import de.leongeorgi.rudolstadt.planning.EventMinutes
import de.leongeorgi.rudolstadt.presentation.*
import de.leongeorgi.rudolstadt.profile.*
import kotlin.test.*

class PresentationTests {
    private val program =
        FestivalProgram(emptyList(), emptyList(), emptyList(), emptyList(), 0, 2026)

    private fun snapshot(id: Long = 1, source: String = "cache") =
        FestivalSnapshot(program, emptyList(), id, source, 100.0, null, "available")

    private val failure = AppFailure("apiNotResponding", "connection")

    @Test
    fun cachedProgramAndObservationAreSynchronousWithoutCollectionOrModelCopies() {
        val vm = FestivalViewModel(true)
        var observed: FestivalState? = null
        val subscription = vm.observe { observed = it }
        vm.restoreInitial(snapshot(), 100.0)
        assertEquals(LoadPhase.READY, vm.state.value.phase)
        assertSame(program, vm.state.value.snapshot!!.program)
        assertSame(vm.current, observed)
        assertFalse(vm.launchPlan(101.0, false).effects.contains(AppEffect.LOAD_PROGRAM))
        val previous = observed
        subscription.cancel()
        vm.clear("noConnection")
        assertSame(previous, observed)
        assertEquals(LoadPhase.FAILED, vm.state.value.phase)
    }

    @Test
    fun staleCacheStaysVisibleDuringRefreshAndFailure() {
        val vm = FestivalViewModel(true)
        val request = vm.beginLoad()
        assertEquals(
            FestivalEffect.REFRESH,
            vm.cacheReceived(request.generation, snapshot(source = "staleCache"), false).effect,
        )
        assertEquals(LoadPhase.READY, vm.current.phase)
        assertEquals(
            FestivalEffect.NONE,
            vm.remoteFailed(request.generation, failure, 200.0).effect,
        )
        assertSame(program, vm.current.snapshot!!.program)
        assertEquals("staleCache", vm.current.fallback!!.source)
        assertEquals(200.0, vm.current.snapshot!!.checkedAt)
        assertEquals(100.0, vm.current.lastDownload)
        vm.cacheDeleted()
        assertNull(vm.current.lastDownload)
        assertSame(program, vm.current.snapshot!!.program)
    }

    @Test
    fun onlyLatestGenerationMayReplaceTheProgramOrItsFailure() {
        val vm = FestivalViewModel(true)
        val first = vm.beginLoad()
        val second = vm.beginLoad()
        vm.cacheReceived(second.generation, snapshot(2), false)
        vm.remoteReceived(first.generation, snapshot(1))
        vm.remoteFailed(first.generation, failure, 300.0)
        assertEquals(2, vm.current.snapshot!!.contextID)
        assertNull(vm.current.fallback)
    }

    @Test
    fun bundleFallbackAndFailureOwnershipAreShared() {
        val vm = FestivalViewModel(true)
        val request = vm.beginLoad()
        vm.cacheReceived(request.generation, null, true)
        assertEquals(
            FestivalEffect.READ_BUNDLE,
            vm.remoteFailed(request.generation, failure, 200.0).effect,
        )
        vm.bundleReceived(request.generation, snapshot(source = "bundledBackup"))
        assertEquals("connection", vm.current.fallback!!.failure.owner)
        val missing = FestivalViewModel(false)
        val read = missing.beginLoad()
        assertEquals(
            FestivalEffect.READ_BUNDLE,
            missing.cacheReceived(read.generation, null, false).effect,
        )
        missing.bundleReceived(read.generation, null)
        assertEquals("couldNotLoadFromFile", missing.current.failure)
    }

    @Test
    fun launchAndForegroundPlansPreserveTheFastCachePathAndThrottle() {
        val vm = FestivalViewModel(true)
        vm.restoreInitial(snapshot(), 100.0)
        val launch = vm.launchPlan(101.0, false)
        assertEquals(
            listOf(AppEffect.REFRESH_RECOMMENDATIONS, AppEffect.DEFER_NEWS),
            launch.effects,
        )
        vm.completePlan(launch, 101.0)
        val active = vm.activePlan(102.0, false)
        assertEquals(
            listOf(AppEffect.REFRESH_NEWS, AppEffect.REFRESH_RECOMMENDATIONS),
            active.effects,
        )
        assertFalse(vm.activePlan(102.0, false).accepted)
        vm.completePlan(active, 102.0)
        assertEquals(AppEffect.LOAD_PROGRAM, vm.activePlan(123.0, false).effects.first())
    }

    @Test
    fun staleRecommendationCannotPublishDuringTheNextInputsDebounce() {
        val vm = RecommendationViewModel()
        val old = vm.beginRefresh()
        vm.inputsChanged()
        vm.update(old, listOf(1), emptyList(), 100.0)
        assertEquals(LoadPhase.LOADING, vm.current.phase)
        val current = vm.beginRefresh()
        vm.update(current, listOf(2), listOf(EventMinutes(2, 45)), 101.0)
        assertEquals(listOf(2L), vm.current.eventIDs)
        vm.beginRefresh()
        assertEquals(listOf(EventMinutes(2, 45)), vm.current.durations)
        vm.disable()
        vm.update(current, listOf(1), emptyList(), 102.0)
        assertTrue(vm.current.eventIDs.isEmpty())
    }

    @Test
    fun eachRecommendationRequestPublishesLoadingAndThenOneCompleteResult() {
        val vm = RecommendationViewModel()
        val phases = mutableListOf<LoadPhase>()
        val observation = vm.observe { phases.add(it.phase) }
        val request = vm.beginRefresh()
        vm.update(request, listOf(42), listOf(EventMinutes(42, 60)), 100.0)
        assertEquals(listOf(LoadPhase.LOADING, LoadPhase.READY), phases)
        assertEquals(listOf(42L), vm.current.eventIDs)
        observation.cancel()
        observation.cancel()
    }

    @Test
    fun discoveryClearsFiltersWithoutLosingSearchOrFavorites() {
        val vm = DiscoveryViewModel()
        vm.search("Folk")
        vm.favoritesOnly(true)
        vm.selectType("stage")
        vm.selectGenre("folk")
        vm.selectGroups(mapOf("region" to "europe"))
        assertTrue(vm.current.hasActiveFilters)
        vm.availableGenres(emptySet())
        assertNull(vm.current.browseGenre)
        vm.clearFilters()
        assertFalse(vm.current.hasActiveFilters)
        assertEquals("Folk", vm.current.search)
        assertTrue(vm.current.favoritesOnly)
    }

    @Test
    fun festivalSelectionPreservesLegacyPrecedenceAndRejectsRemovedEditions() {
        val current = FestivalIdentity("rudolstadt", "2026")
        val archive = FestivalIdentity("rudolstadt", "2025")
        val registered = setOf(current, archive)
        val removedLegacy =
            FestivalSelectionViewModel(registered, current, null, null, archive, true)
        assertEquals(current, removedLegacy.current.identity)
        val legacyYear = FestivalSelectionViewModel(registered, current, null, null, archive, false)
        assertEquals(archive, legacyYear.current.identity)
        val preferred =
            FestivalSelectionViewModel(registered, current, archive, current, null, true)
        assertEquals(archive, preferred.current.identity)
        preferred.select(FestivalIdentity("unknown", "2027"))
        assertEquals(current, preferred.current.identity)
    }

    private fun profile(readOnly: Boolean = false) = ProfileViewModel(true, true, true, readOnly)

    @Test
    fun profileMutationsOwnValuesVersionsAndPendingUploads() {
        val vm = profile()
        assertTrue(vm.mutate(ProfileMutation("toggleSavedEvent", 42), true, 100.0, "first"))
        assertTrue(vm.isSaved(42))
        assertTrue(vm.consumeRecommendationChange())
        assertFalse(vm.consumeRecommendationChange())
        val first = vm.current.changes.single()
        assertEquals(setOf("event:42"), vm.current.pending)
        vm.mutate(ProfileMutation("toggleSavedEvent", 42), true, 99.0, "second")
        assertEquals(100.001, vm.current.changes.single().version.modifiedAt, .000001)
        vm.acknowledge(first)
        assertEquals(setOf("event:42"), vm.current.pending)
        vm.acknowledge(vm.current.changes.single())
        assertTrue(vm.current.pending.isEmpty())
        assertFalse(vm.isSaved(42))
    }

    @Test
    fun profilePermissionsAndMissingMetadataCannotEraseUserValues() {
        val vm = profile()
        vm.mutate(ProfileMutation("setArtistRating", 7, rating = 3), true, 100.0, "rating")
        vm.mutate(ProfileMutation("setArtistRating", 8, rating = -1), true, 100.0, "negative")
        assertEquals(setOf(7L), vm.current.positiveArtistIDs)
        assertFalse(
            vm.mutate(ProfileMutation("setArtistRating", 7, rating = 0), false, 101.0, "bad")
        )
        assertEquals(3, vm.rating(7))
        assertFalse(
            profile(true).mutate(ProfileMutation("toggleSavedEvent", 42), true, 100.0, "readonly")
        )
        val limited = ProfileViewModel(true, true, false, false)
        assertFalse(
            limited.mutate(ProfileMutation("setArtistNote", 7, text = "note"), true, 100.0, "note")
        )
    }

    @Test
    fun remoteMergeRetainsNewerEditsAndLegacyDeletionsCannotDiscardThem() {
        val vm = profile()
        vm.mutate(ProfileMutation("setArtistNote", 7, text = "local"), true, 200.0, "new")
        val remote =
            ProfileRecordChange(
                "note:7",
                ProfileRecordValue("note", 7, noteText = "old"),
                ProfileVersion(100.0, "old"),
            )
        assertTrue(vm.merge(remote))
        assertEquals("local", vm.note(7))
        assertTrue(vm.legacyDeleted("note:7"))
        assertEquals("local", vm.note(7))
        assertFalse(vm.merge(remote.copy(version = ProfileVersion(300.0, "latest"))))
        assertEquals("old", vm.note(7))
        assertTrue(vm.current.pending.isEmpty())
    }

    @Test
    fun syncErrorsRemainVisibleUntilConfirmedSuccess() {
        val vm = SyncViewModel()
        vm.sync("error", "Offline", false)
        vm.sync("idle", null, false)
        assertEquals("error", vm.current.phase)
        assertTrue(vm.current.shouldWarn)
        vm.confirmSuccess()
        assertFalse(vm.current.shouldWarn)
        vm.sync("idle", null, true)
        assertEquals("syncing", vm.current.phase)
    }

    private fun message(id: Long, language: String = "de") =
        NewsMessage(id, language, "", "", "Title", "", "")

    @Test
    fun historyAndForegroundUpdatesPreventNotificationReplays() {
        val history = NewsHistoryViewModel()
        assertTrue(history.initialize(listOf(message(1))))
        assertFalse(history.notificationEligible(message(1), "de", false))
        assertTrue(history.notificationEligible(message(2), "de", false))
        history.markRead(listOf(2))
        assertFalse(history.notificationEligible(message(2), "de", false))
        assertFalse(history.notificationEligible(message(3, "en"), "de", false))
        assertFalse(history.notificationEligible(message(3), "de", true))
        history.toggleRead(2)
        assertTrue(history.notificationEligible(message(2), "de", false))
    }

    @Test
    fun articleReadStateSupportsTextIDsAndIsIsolatedByFestival() {
        val history = NewsHistoryViewModel()
        history.restoreFestivalHistory("festival/a", setOf("existing"))
        history.restoreFestivalHistory("festival/a", emptySet())
        assertTrue(history.isArticleRead("existing", "festival/a", false))
        assertEquals(
            NewsReadEffect.STORE_FESTIVAL,
            history.markArticleRead("opening", "festival/a", false),
        )
        assertFalse(history.isArticleRead("opening", "festival/b", false))
        assertEquals(NewsReadEffect.NONE, history.markArticleRead("opening", "festival/a", false))
        assertEquals(NewsReadEffect.STORE_LEGACY, history.markArticleRead("42", "current", true))
        assertEquals(listOf(42L), history.current.read)
        assertFalse(history.isArticleRead("42", "festival/a", false))
        assertEquals(
            NewsReadEffect.STORE_FESTIVAL,
            history.markArticleRead("text-id", "current", true),
        )
    }

    @Test
    fun newsRefreshDeduplicationThrottleAndDeletionAreShared() {
        val vm = NewsServiceViewModel()
        assertEquals(NewsRefreshAction.FETCH, vm.begin(true, 100.0, false))
        assertEquals(NewsRefreshAction.REUSE, vm.begin(false, 101.0, false))
        assertTrue(vm.foregroundRequested)
        vm.downloaded(listOf(message(1), message(1)), false)
        vm.finished()
        assertEquals(1, vm.current.items.size)
        assertEquals("news.storage.failed", vm.current.notice)
        assertEquals(NewsRefreshAction.AVAILABLE, vm.begin(false, 200.0, false))
        assertTrue(vm.beginDelete())
        assertFalse(vm.beginDelete())
        vm.endDelete(true)
        assertEquals(NewsRefreshAction.FETCH, vm.begin(false, 201.0, false))
    }

    @Test
    fun newsRejectsWrongFestivalAndRetainsAnExistingSnapshotAfterFailure() {
        val vm = NewsViewModel("festival", "2026")
        val snapshot = NewsSnapshot("festival", "2026", emptyList(), 1)
        assertFails { vm.apply(snapshot.copy(festivalID = "other"), emptyList(), "cache", null) }
        vm.apply(snapshot, listOf(message(1)), "cache", null)
        val request = vm.beginRefresh()
        assertEquals(NewsEffect.NONE, vm.refreshFailed(request.generation).effect)
        assertSame(snapshot, vm.current.snapshot)
        assertEquals("news.refresh.failed", vm.current.notice)
        assertEquals("item", vm.notificationDestination(1, false))
    }
}
