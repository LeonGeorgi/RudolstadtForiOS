package de.leongeorgi.rudolstadt.presentation

import de.leongeorgi.rudolstadt.festival.FestivalTime
import kotlinx.datetime.*

data class PlanFreshness(
    val generatedAt: Double,
    val source: String,
    val dataUpdatedAt: Double?,
    val recommendationsAvailable: Boolean,
    val recommendationsAt: Double?,
    val friendsAvailable: Boolean,
    val friendsAt: Double?,
)

data class PlanFreshnessPolicy(
    val maximumFestivalDataAge: Double = 10800.0,
    val maximumRecommendationAge: Double = 86400.0,
    val maximumFriendDataAge: Double = 86400.0,
    val maximumSnapshotAge: Double = 86400.0,
    val maximumClockSkew: Double = 300.0,
) {
    fun staleReasons(input: PlanFreshness, now: Double, scheduleOnly: Boolean): List<String> =
        buildList {
            fun timestamp(value: Double?, maxAge: Double, unknown: String?, old: String) {
                when {
                    value == null -> if (unknown != null) add(unknown)
                    value - now > maximumClockSkew ->
                        if ("timestampInFuture" !in this) add("timestampInFuture")
                    now - value > maxAge -> add(old)
                }
            }
            if (input.source == "staleCache" || input.source == "bundledBackup")
                add("fallbackFestivalData")
            else
                timestamp(
                    input.dataUpdatedAt,
                    maximumFestivalDataAge,
                    "festivalDataAgeUnknown",
                    "festivalDataTooOld",
                )
            if (!scheduleOnly) {
                if (input.recommendationsAvailable)
                    timestamp(
                        input.recommendationsAt,
                        maximumRecommendationAge,
                        "recommendationsAgeUnknown",
                        "recommendationsTooOld",
                    )
                if (input.friendsAvailable)
                    timestamp(
                        input.friendsAt,
                        maximumFriendDataAge,
                        "friendDataAgeUnknown",
                        "friendDataTooOld",
                    )
            }
            timestamp(input.generatedAt, maximumSnapshotAge, null, "snapshotTooOld")
        }

    fun friendCountsAreFresh(input: PlanFreshness, now: Double): Boolean {
        val updated = input.friendsAt ?: return false
        return input.friendsAvailable &&
            now - updated >= -maximumClockSkew &&
            now - updated <= maximumFriendDataAge &&
            now - input.generatedAt >= -maximumClockSkew &&
            now - input.generatedAt <= maximumSnapshotAge
    }

    internal fun boundaries(input: PlanFreshness, now: Double): List<Double> = buildList {
        fun append(value: Double?, age: Double) {
            if (value == null) return
            (value - maximumClockSkew).takeIf { it > now }?.let(::add)
            // Staleness starts strictly after the limit, matching the original widget policy.
            (value + age + 1).takeIf { it > now }?.let(::add)
        }
        if (input.source == "remote" || input.source == "cache")
            append(input.dataUpdatedAt, maximumFestivalDataAge)
        append(input.generatedAt, maximumSnapshotAge)
    }
}

data class PlanEvent(
    val eventID: Long,
    val start: Double,
    val end: Double,
    val day: Int,
    val saved: Boolean,
    val friendSaveCount: Int?,
)

data class PlanTransition(val from: Long, val to: Long, val status: String)

data class PlanConflict(val first: Long, val second: Long, val minutes: Int)

data class PersonalPlanSnapshot(
    val year: Int,
    val events: List<PlanEvent>,
    val missingSavedCount: Int?,
    val hasUnplacedSavedEvents: Boolean,
    val incompleteProgram: Boolean,
    val freshness: PlanFreshness,
    val transitions: List<PlanTransition>,
    val conflicts: List<PlanConflict>,
)

data class NextPlanEntry(
    val timestamp: Double,
    val kind: String,
    val eventID: Long? = null,
    val ongoing: Boolean = false,
    val stale: Boolean = false,
)

data class NextPlanTimeline(val entries: List<NextPlanEntry>, val reloadAtEnd: Boolean)

data class DayPlanRow(
    val eventID: Long,
    val ongoing: Boolean,
    val conflictMinutes: Int?,
    val incomingTransitionIndex: Int?,
    val friendSaveCount: Int?,
)

data class DayPlanState(
    val kind: String,
    val day: Int? = null,
    val displayDate: Double? = null,
    val rows: List<DayPlanRow> = emptyList(),
    val stale: Boolean = false,
)

/** Derived plan state for native watch/widget surfaces and future Android equivalents. */
object PersonalPlan {
    private val eventOrder =
        compareBy<PlanEvent> { it.start }.thenByDescending { it.end }.thenBy { it.eventID }

    fun next(input: PersonalPlanSnapshot, now: Double, policy: PlanFreshnessPolicy): NextPlanEntry {
        val stale = policy.staleReasons(input.freshness, now, true).isNotEmpty()
        fun result(kind: String, event: PlanEvent? = null, ongoing: Boolean = false) =
            NextPlanEntry(now, kind, event?.eventID, ongoing, stale)
        if (input.hasUnplacedSavedEvents || input.incompleteProgram)
            return result("planUnavailable")
        if (input.events.isEmpty()) return result("programUnavailable")
        if (input.events.all { it.end <= now }) return result("festivalEnded")
        val saved = input.events.filter { it.saved }
        if (saved.isEmpty())
            return result(if (input.missingSavedCount == 0) "noSavedEvents" else "planUnavailable")
        val started = saved.filter { it.start <= now }
        val latest = started.maxOfOrNull { it.start }
        val active = started.filter { it.start == latest }.minWithOrNull(eventOrder)
        if (active != null && active.end > now) return result("event", active, true)
        val upcoming = saved.filter { it.start > now }.minWithOrNull(eventOrder)
        return if (upcoming != null) result("event", upcoming) else result("planEnded")
    }

    fun timeline(
        input: PersonalPlanSnapshot,
        now: Double,
        policy: PlanFreshnessPolicy,
        maximumEntries: Int,
    ): NextPlanTimeline {
        val end = input.events.maxOfOrNull { it.end }
        val boundaries =
            (listOf(now) +
                    input.events
                        .filter { it.saved }
                        .flatMap { listOf(it.start, it.end) }
                        .filter { it > now } +
                    listOfNotNull(end?.takeIf { it > now }) +
                    policy.boundaries(input.freshness, now).filter { end == null || it <= end })
                .distinct()
                .sorted()
        val entries = mutableListOf<NextPlanEntry>()
        val limit = maximumEntries.coerceAtLeast(2)
        for (date in boundaries) {
            val candidate = next(input, date, policy)
            val previous = entries.lastOrNull()
            if (
                previous == null ||
                    previous.kind != candidate.kind ||
                    previous.eventID != candidate.eventID ||
                    previous.ongoing != candidate.ongoing ||
                    previous.stale != candidate.stale
            ) {
                entries.add(candidate)
                if (entries.size > limit) return NextPlanTimeline(entries.take(limit), true)
            }
        }
        return NextPlanTimeline(entries, false)
    }

    fun day(
        input: PersonalPlanSnapshot,
        now: Double,
        zone: String,
        policy: PlanFreshnessPolicy,
    ): DayPlanState {
        val stale = policy.staleReasons(input.freshness, now, true).isNotEmpty()
        fun result(kind: String) = DayPlanState(kind, stale = stale)
        if (input.events.isEmpty()) return result("programUnavailable")
        if (input.events.all { it.end <= now })
            return result(if (input.incompleteProgram) "programUnavailable" else "festivalEnded")
        val saved = input.events.filter { it.saved }.sortedWith(eventOrder)
        if (saved.isEmpty())
            return result(if (input.missingSavedCount == 0) "noSavedEvents" else "planUnavailable")
        val date = FestivalTime.local(now, zone)
        val day = date.day - if (date.hour < 5) 1 else 0
        if (
            date.year != input.year ||
                date.month != Month.JULY ||
                input.events.none { it.day == day }
        )
            return result("noFestivalToday")
        val events = saved.filter { it.day == day }
        if (events.isEmpty()) return result("noSavedEventsToday")
        val visible =
            events.filter { it.start <= now && it.end > now } + events.filter { it.start > now }
        if (visible.isEmpty()) return result("planEnded")
        val visibleIDs = visible.map { it.eventID }.toSet()
        val sourceIDs = events.map { it.eventID }.toSet()
        val friends = policy.friendCountsAreFresh(input.freshness, now)
        val priorities = mapOf("impossible" to 0, "tight" to 1, "unknown" to 2, "comfortable" to 3)
        val rows = visible.map { event ->
            val conflict =
                input.conflicts
                    .mapNotNull {
                        val other =
                            when (event.eventID) {
                                it.first -> it.second
                                it.second -> it.first
                                else -> null
                            }
                        if (other in visibleIDs) it.minutes else null
                    }
                    .maxOrNull()
            val incoming =
                input.transitions
                    .withIndex()
                    .filter {
                        it.value.to == event.eventID &&
                            it.value.from in sourceIDs &&
                            it.value.status != "comfortable"
                    }
                    .minWithOrNull(
                        compareBy<IndexedValue<PlanTransition>> { priorities[it.value.status] ?: 3 }
                            .thenBy { it.value.from }
                    )
                    ?.index
            DayPlanRow(
                event.eventID,
                event.start <= now,
                conflict,
                incoming,
                if (friends) event.friendSaveCount?.takeIf { it > 0 } else null,
            )
        }
        val display =
            LocalDate(input.year, 7, day)
                .atTime(12, 0)
                .toInstant(FestivalTime.timeZone(zone))
                .epochSeconds
                .toDouble()
        return DayPlanState("plan", day, display, rows, stale)
    }
}
