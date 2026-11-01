package de.leongeorgi.rudolstadt.presentation

import de.leongeorgi.rudolstadt.news.*

data class NewsState(
    val phase: LoadPhase = LoadPhase.LOADING,
    val items: List<NewsMessage> = emptyList(),
    val source: String? = null,
    val notice: String? = null,
    val failure: String? = null,
    val snapshot: NewsSnapshot? = null,
)

enum class NewsEffect {
    NONE,
    READ_CACHE,
    REFRESH,
    READ_BUNDLE,
}

data class NewsRequest(val generation: Long, val effect: NewsEffect)

class NewsViewModel(
    private val festivalID: String = "rudolstadt",
    private val editionID: String = "2026",
) {
    private val cell = StateCell(NewsState())
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (NewsState) -> Unit) = cell.observe(observer)

    private var generation = 0L
    private var failedRefresh = false

    fun present(items: List<NewsMessage>, source: String?, notice: String?, failure: String?) {
        cell.set(
            NewsState(
                if (failure == null) LoadPhase.READY else LoadPhase.FAILED,
                items,
                source,
                notice,
                failure,
                if (failure == null) sourceSnapshot(items, source, notice) else null,
            )
        )
    }

    @Throws(Exception::class)
    fun apply(snapshot: NewsSnapshot, items: List<NewsMessage>, source: String?, notice: String?) {
        require(
            snapshot.festivalID == festivalID &&
                snapshot.editionID == editionID &&
                snapshot.articles.map { it.articleID }.toSet().size == snapshot.articles.size
        ) {
            "Invalid news snapshot identity or IDs"
        }
        cell.set(NewsState(LoadPhase.READY, items, source, notice, snapshot = snapshot))
    }

    @Throws(Exception::class)
    fun applySnapshot(snapshot: NewsSnapshot) {
        apply(
            snapshot,
            NewsSnapshots.messages(snapshot),
            when (snapshot.snapshotSource) {
                "bundledBackup" -> "bundle"
                else -> snapshot.snapshotSource
            },
            snapshot.noticeKey ?: if (snapshot.noticeTexts != null) "news.refresh.failed" else null,
        )
    }

    fun sourceSnapshot(items: List<NewsMessage>, source: String?, notice: String?) =
        NewsSnapshots.fromMessages(items, festivalID, editionID, source, notice)

    fun beginRefresh(): NewsRequest {
        generation++
        failedRefresh = false
        return request(if (current.snapshot == null) NewsEffect.READ_CACHE else NewsEffect.REFRESH)
    }

    fun isCurrent(token: Long) = generation == token

    fun cacheFinished(token: Long): NewsRequest =
        request(if (isCurrent(token)) NewsEffect.REFRESH else NewsEffect.NONE)

    fun refreshFailed(token: Long): NewsRequest {
        if (!isCurrent(token)) return request(NewsEffect.NONE)
        failedRefresh = true
        if (current.snapshot == null) return request(NewsEffect.READ_BUNDLE)
        return bundleFinished(token)
    }

    fun bundleFinished(token: Long): NewsRequest {
        if (isCurrent(token) && failedRefresh)
            cell.set(
                current.copy(
                    notice = "news.refresh.failed",
                    phase = if (current.snapshot == null) LoadPhase.FAILED else current.phase,
                    failure = if (current.snapshot == null) "apiNotResponding" else current.failure,
                )
            )
        return request(NewsEffect.NONE)
    }

    fun notificationDestination(id: Long, refreshed: Boolean): String =
        if (current.phase == LoadPhase.READY && current.items.any { it.newsID == id }) "item"
        else if (refreshed) "list" else "loading"

    private var lastAttempt: Double? = null
    private var running = false
    private var deleting = false
    private var foreground = false
    val foregroundRequested
        get() = foreground

    fun begin(background: Boolean, now: Double, freshDisk: Boolean): NewsRefreshAction {
        if (deleting) return NewsRefreshAction.AVAILABLE
        if (running) {
            if (!background) foreground = true
            return NewsRefreshAction.REUSE
        }
        if (lastAttempt?.let { now - it < 180 } == true || (lastAttempt == null && freshDisk))
            return NewsRefreshAction.AVAILABLE
        lastAttempt = now
        running = true
        foreground = !background
        return NewsRefreshAction.FETCH
    }

    fun finished() {
        running = false
    }

    fun beginDelete(): Boolean {
        if (deleting) return false
        deleting = true
        return true
    }

    fun endDelete(deleted: Boolean) {
        deleting = false
        if (deleted) {
            running = false
            lastAttempt = null
            cell.set(NewsState())
        }
    }

    fun hasResult() = current.phase == LoadPhase.READY

    private fun publishService(items: List<NewsMessage>, source: String?, notice: String?) {
        val unique = unique(items)
        cell.set(
            NewsState(
                LoadPhase.READY,
                unique,
                source,
                notice,
                snapshot = sourceSnapshot(unique, source, notice),
            )
        )
    }

    fun cached(items: List<NewsMessage>) {
        publishService(items, "cache", current.notice)
    }

    fun bundled(items: List<NewsMessage>) {
        publishService(items, "bundle", current.notice)
    }

    fun downloadedRecords(
        records: List<NewsRecord>,
        stored: Boolean,
        history: NewsHistoryViewModel,
        language: String,
    ): NewsDelivery {
        val items = unique(records.map { it.message() })
        val baseline = history.initialize(items)
        downloaded(items, stored)
        if (baseline || foregroundRequested) {
            history.remember(items.map { it.newsID })
            return NewsDelivery(items, emptyList())
        }
        // Record ineligible items before the first system handoff, even if the task expires later.
        history.remember(
            items
                .filter { it.newsID in history.current.read || it.languageCode != language }
                .map { it.newsID }
        )
        return NewsDelivery(
            items,
            items.filter { history.notificationEligible(it, language, false) },
        )
    }

    fun downloaded(items: List<NewsMessage>, stored: Boolean) {
        publishService(items, "remote", if (stored) null else "news.storage.failed")
    }

    fun failed() {
        cell.set(
            current.copy(
                phase = if (hasResult()) LoadPhase.READY else LoadPhase.FAILED,
                failure = if (hasResult()) null else "apiNotResponding",
                notice =
                    if (hasResult())
                        (if (current.source == "bundle") "news.refresh.bundle"
                        else "news.refresh.failed")
                    else current.notice,
            )
        )
    }

    fun unique(items: List<NewsMessage>) = items.distinctBy { it.newsID }

    private fun request(effect: NewsEffect) = NewsRequest(generation, effect)
}

data class NewsHistoryState(
    val read: List<Long> = emptyList(),
    val known: List<Long> = emptyList(),
    val initialized: Boolean = false,
    val festivalRead: Map<String, Set<String>> = emptyMap(),
)

enum class NewsReadEffect {
    NONE,
    STORE_LEGACY,
    STORE_FESTIVAL,
}

class NewsHistoryViewModel {
    private val cell = StateCell(NewsHistoryState())
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (NewsHistoryState) -> Unit) = cell.observe(observer)

    fun restore(read: List<Long>, known: List<Long>, initialized: Boolean) {
        cell.set(NewsHistoryState(read, known, initialized))
    }

    fun setRead(ids: List<Long>) {
        cell.set(current.copy(read = ids))
    }

    fun setKnown(ids: List<Long>) {
        cell.set(current.copy(known = ids))
    }

    fun setInitialized(value: Boolean) {
        cell.set(current.copy(initialized = value))
    }

    fun markRead(ids: List<Long>) {
        cell.set(current.copy(read = (current.read + ids).distinct()))
    }

    fun toggleRead(id: Long) {
        cell.set(
            current.copy(read = if (id in current.read) current.read - id else current.read + id)
        )
    }

    fun remember(ids: List<Long>) {
        cell.set(current.copy(known = (current.known + ids).distinct()))
    }

    fun hasFestivalHistory(scope: String) = scope in current.festivalRead

    fun restoreFestivalHistory(scope: String, ids: Set<String>) {
        if (!hasFestivalHistory(scope))
            cell.set(current.copy(festivalRead = current.festivalRead + (scope to ids.toSet())))
    }

    fun festivalReadIDs(scope: String): List<String> =
        current.festivalRead[scope].orEmpty().sorted()

    fun isArticleRead(id: String, scope: String, legacy: Boolean): Boolean {
        val numericID = if (legacy) id.toLongOrNull() else null
        return if (numericID != null) numericID in current.read
        else id in current.festivalRead[scope].orEmpty()
    }

    fun markArticleRead(id: String, scope: String, legacy: Boolean): NewsReadEffect {
        if (isArticleRead(id, scope, legacy)) return NewsReadEffect.NONE
        val numericID = if (legacy) id.toLongOrNull() else null
        if (numericID != null) {
            markRead(listOf(numericID))
            return NewsReadEffect.STORE_LEGACY
        }
        cell.set(
            current.copy(
                festivalRead =
                    current.festivalRead + (scope to (current.festivalRead[scope].orEmpty() + id))
            )
        )
        return NewsReadEffect.STORE_FESTIVAL
    }

    fun initialize(items: List<NewsMessage>): Boolean {
        if (current.initialized) return false
        val first = current.known.isEmpty()
        cell.set(
            current.copy(
                initialized = true,
                known = if (first) items.map { it.newsID }.distinct() else current.known,
            )
        )
        return first
    }

    fun notificationEligible(item: NewsMessage, language: String, foreground: Boolean): Boolean =
        !foreground &&
            item.newsID !in current.read &&
            item.newsID !in current.known &&
            item.languageCode == language
}

enum class NewsRefreshAction {
    AVAILABLE,
    REUSE,
    FETCH,
}

typealias NewsServiceViewModel = NewsViewModel
