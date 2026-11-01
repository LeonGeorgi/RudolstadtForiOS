package de.leongeorgi.rudolstadt.loading

/** Effects are executed by platform adapters; all fallback decisions stay shared. */
enum class ProgramLoadAction {
    REFRESH,
    READ_BUNDLE,
    KEEP_CONFIRMED,
    FAIL,
}

class ProgramLoadSession(private val refreshable: Boolean, hasConfirmedProgram: Boolean) {
    private var hasConfirmedProgram = hasConfirmedProgram

    fun cacheRead(accepted: Boolean, fresh: Boolean): ProgramLoadAction {
        hasConfirmedProgram = hasConfirmedProgram || accepted
        return when {
            accepted && fresh -> ProgramLoadAction.KEEP_CONFIRMED
            refreshable -> ProgramLoadAction.REFRESH
            else -> ProgramLoadAction.READ_BUNDLE
        }
    }

    fun remoteFailed(): ProgramLoadAction =
        if (hasConfirmedProgram) ProgramLoadAction.KEEP_CONFIRMED else ProgramLoadAction.READ_BUNDLE

    fun bundleRead(accepted: Boolean): ProgramLoadAction {
        hasConfirmedProgram = hasConfirmedProgram || accepted
        return if (hasConfirmedProgram) ProgramLoadAction.KEEP_CONFIRMED else ProgramLoadAction.FAIL
    }
}

/** Call from the owning actor/thread. An older refresh may never overwrite newer data. */
class RefreshGeneration {
    private var generation = 0L

    fun begin(): Long = ++generation

    fun isCurrent(token: Long): Boolean = token == generation
}

object CachePolicy {
    const val maximumAgeSeconds = 3 * 60 * 60.0

    fun fileName(year: Int, name: String): String = "${year}_$name"

    fun isStale(modifiedAt: Double?, now: Double): Boolean =
        modifiedAt == null ||
            !modifiedAt.isFinite() ||
            !now.isFinite() ||
            modifiedAt < now - maximumAgeSeconds

    fun isOlderThan(modifiedAt: Double?, cutoff: Double): Boolean =
        modifiedAt == null || !modifiedAt.isFinite() || modifiedAt < cutoff
}

enum class HttpFailureOwner {
    SERVER,
    CLIENT,
    UNKNOWN,
}

object HttpPolicy {
    fun isSuccess(statusCode: Int): Boolean = statusCode in 200..299

    fun failureOwner(statusCode: Int): HttpFailureOwner =
        when (statusCode) {
            in 500..599 -> HttpFailureOwner.SERVER
            in 400..499 -> HttpFailureOwner.CLIENT
            else -> HttpFailureOwner.UNKNOWN
        }
}
