package de.leongeorgi.rudolstadt.presentation

import de.leongeorgi.rudolstadt.festival.FestivalProgram
import de.leongeorgi.rudolstadt.festival.OccurrenceDay
import de.leongeorgi.rudolstadt.loading.ProgramLoadAction
import de.leongeorgi.rudolstadt.loading.ProgramLoadSession

/** contextID addresses optional platform services; all program and application state is typed. */
data class FestivalSnapshot(
    val program: FestivalProgram,
    val days: List<OccurrenceDay>,
    val contextID: Long,
    val source: String?,
    val updatedAt: Double?,
    val checkedAt: Double?,
    val planning: String,
)

data class FestivalFallback(val source: String, val failure: AppFailure, val checkedAt: Double)

data class FestivalState(
    val phase: LoadPhase = LoadPhase.LOADING,
    val snapshot: FestivalSnapshot? = null,
    val failure: String? = null,
    val fallback: FestivalFallback? = null,
    val lastDownload: Double? = null,
)

enum class FestivalEffect {
    NONE,
    READ_CACHE,
    REFRESH,
    READ_BUNDLE,
}

enum class AppEffect {
    LOAD_PROGRAM,
    REFRESH_RECOMMENDATIONS,
    REFRESH_NEWS,
    DEFER_NEWS,
}

data class AppRefreshPlan(val effects: List<AppEffect>, val launch: Boolean, val accepted: Boolean)

data class FestivalRequest(val generation: Long, val effect: FestivalEffect)

class FestivalViewModel(private val refreshable: Boolean) {
    val recommendationDebounceMillis: Long
        get() = 180

    val newsDelayMillis: Long
        get() = 2000

    private val cell = StateCell(FestivalState())
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (FestivalState) -> Unit) = cell.observe(observer)

    private var generation = 0L
    private var session: ProgramLoadSession? = null
    private var cacheFailed = false
    private var remoteFailure: AppFailure? = null
    private var checkedAt = 0.0
    private var initialRestored = false
    private var launchLoaded = false
    private var activeRefresh = false
    private var lastActive: Double? = null

    fun present(snapshot: FestivalSnapshot) {
        cell.set(FestivalState(LoadPhase.READY, snapshot, lastDownload = snapshot.updatedAt))
    }

    fun restoreInitial(snapshot: FestivalSnapshot, now: Double) {
        present(snapshot)
        initialRestored = true
        lastActive = now
    }

    fun clear(failure: String?) {
        cell.set(
            FestivalState(
                if (failure == null) LoadPhase.LOADING else LoadPhase.FAILED,
                failure = failure,
            )
        )
    }

    fun beginLoad(): FestivalRequest {
        generation++
        session = ProgramLoadSession(refreshable, current.snapshot != null)
        cacheFailed = false
        remoteFailure = null
        return request(FestivalEffect.READ_CACHE)
    }

    fun isCurrent(token: Long) = token == generation

    fun cacheReceived(token: Long, snapshot: FestivalSnapshot?, failed: Boolean): FestivalRequest {
        if (!isCurrent(token)) return request(FestivalEffect.NONE)
        cacheFailed = failed
        if (snapshot != null) present(snapshot)
        val action = session!!.cacheRead(snapshot != null, snapshot?.source == "cache" && !failed)
        return request(
            when (action) {
                ProgramLoadAction.REFRESH -> FestivalEffect.REFRESH
                ProgramLoadAction.READ_BUNDLE -> FestivalEffect.READ_BUNDLE
                else -> FestivalEffect.NONE
            }
        )
    }

    fun remoteReceived(token: Long, snapshot: FestivalSnapshot): FestivalRequest {
        if (isCurrent(token)) present(snapshot)
        return request(FestivalEffect.NONE)
    }

    fun remoteFailed(token: Long, failure: AppFailure, now: Double): FestivalRequest {
        if (!isCurrent(token)) return request(FestivalEffect.NONE)
        remoteFailure = failure
        checkedAt = now
        if (session!!.remoteFailed() == ProgramLoadAction.READ_BUNDLE)
            return request(FestivalEffect.READ_BUNDLE)
        finishFailure()
        return request(FestivalEffect.NONE)
    }

    fun bundleReceived(token: Long, snapshot: FestivalSnapshot?): FestivalRequest {
        if (!isCurrent(token)) return request(FestivalEffect.NONE)
        if (snapshot != null) present(snapshot)
        val action = session!!.bundleRead(snapshot != null)
        if (remoteFailure != null) finishFailure()
        else if (action == ProgramLoadAction.FAIL) clear("couldNotLoadFromFile")
        return request(FestivalEffect.NONE)
    }

    private fun finishFailure() {
        val failure = remoteFailure ?: return
        val snapshot = current.snapshot
        if (snapshot != null) {
            cell.set(
                current.copy(
                    snapshot = snapshot.copy(checkedAt = checkedAt),
                    fallback =
                        if (snapshot.source in listOf("staleCache", "bundledBackup"))
                            FestivalFallback(snapshot.source!!, failure, checkedAt)
                        else current.fallback,
                )
            )
        } else
            clear(
                if (failure.reason.isNotEmpty()) failure.reason
                else if (cacheFailed) "couldNotLoadFromFile" else "apiNotResponding"
            )
    }

    fun cacheDeleted() {
        initialRestored = false
        cell.set(current.copy(lastDownload = null))
    }

    fun isCacheStale() =
        current.snapshot?.source !in
            listOf(
                "cache",
                "remote",
                "bundledArchive",
                "bundledExperiment",
                "preview",
                "screenshot",
            )

    fun beginActive(now: Double): Boolean {
        if (activeRefresh) return false
        activeRefresh = true
        return true
    }

    fun shouldLoadOnActive(now: Double): Boolean =
        current.snapshot == null ||
            (refreshable && (isCacheStale() || lastActive?.let { now - it >= 20 } != false))

    fun endActive(now: Double) {
        activeRefresh = false
        lastActive = now
    }

    fun hasLoadedLaunch() = launchLoaded

    fun shouldLoadOnLaunch() = !initialRestored || isCacheStale()

    fun finishLaunch() {
        initialRestored = false
        launchLoaded = current.snapshot != null
    }

    private fun request(effect: FestivalEffect) = FestivalRequest(generation, effect)

    fun activePlan(now: Double, screenshot: Boolean): AppRefreshPlan {
        if (!beginActive(now)) return AppRefreshPlan(emptyList(), false, false)
        val effects =
            if (screenshot) listOf(AppEffect.REFRESH_RECOMMENDATIONS)
            else
                buildList {
                    if (shouldLoadOnActive(now)) add(AppEffect.LOAD_PROGRAM)
                    add(AppEffect.REFRESH_NEWS)
                    add(AppEffect.REFRESH_RECOMMENDATIONS)
                }
        return AppRefreshPlan(effects, false, true)
    }

    fun launchPlan(now: Double, screenshot: Boolean): AppRefreshPlan {
        if (launchLoaded) return activePlan(now, screenshot)
        return AppRefreshPlan(
            buildList {
                if (!screenshot && shouldLoadOnLaunch()) add(AppEffect.LOAD_PROGRAM)
                add(AppEffect.REFRESH_RECOMMENDATIONS)
                add(AppEffect.DEFER_NEWS)
            },
            true,
            true,
        )
    }

    fun completePlan(plan: AppRefreshPlan, now: Double) {
        if (!plan.accepted) return
        if (plan.launch) finishLaunch() else endActive(now)
    }
}
