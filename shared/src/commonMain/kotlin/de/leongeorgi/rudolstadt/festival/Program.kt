package de.leongeorgi.rudolstadt.festival

import kotlin.concurrent.atomics.AtomicReference
import kotlin.concurrent.atomics.ExperimentalAtomicApi
import kotlin.math.floor
import kotlin.time.Instant
import kotlinx.datetime.*
import kotlinx.serialization.Serializable

/** Platform-neutral program values. Instants use Unix seconds, never device-local dates. */
@Serializable
data class ProgramEvent(
    val id: Long,
    val artistID: Long,
    val placeID: String? = null,
    val start: Double? = null,
    val knownDate: Double? = null,
    val dayID: String? = null,
    val dayNumber: Int = 0,
    val startMinutes: Int = 0,
    val duration: Int? = null,
    val durationIsEstimated: Boolean = false,
    val eligible: Boolean = true,
)

@Serializable data class EventDuration(val minutes: Int, val isEstimated: Boolean)

object DurationResolver {
    fun resolve(events: List<ProgramEvent>): Map<Long, EventDuration> {
        val result =
            events
                .mapNotNull { e ->
                    e.duration?.let { e.id to EventDuration(it, e.durationIsEstimated) }
                }
                .toMap()
                .toMutableMap()
        events
            .filter { it.start != null && it.placeID != null }
            .groupBy { it.placeID }
            .values
            .forEach { group ->
                var next: ProgramEvent? = null
                group
                    .sortedWith(
                        compareByDescending<ProgramEvent> { it.start }.thenByDescending { it.id }
                    )
                    .forEach { event ->
                        if (event.duration == null || event.duration <= 0) {
                            var minutes = 60
                            val gap = next?.start?.let { (it - event.start!!) / 60 }
                            if (gap != null && gap > 0) {
                                val rounded = floor(gap / 30) * 30
                                val half = floor(gap / 2 / 30) * 30
                                val estimate =
                                    when {
                                        rounded < 30 -> gap
                                        rounded < 60 -> rounded
                                        half < 30 -> gap / 2
                                        half <= 90 -> half
                                        gap > 300 -> 60.0
                                        else -> 90.0
                                    }
                                minutes = if (gap < 60) gap.toInt() else maxOf(60, estimate.toInt())
                            }
                            // An existing source duration is preserved, even if invalid: validation
                            // reports it.
                            if (minutes > 0 && event.duration == null)
                                result[event.id] = EventDuration(minutes, true)
                        }
                        next = event
                    }
            }
        return result
    }
}

object FestivalTime {
    // Kotlin/Native resolves IANA zones from tzdata files. Share immutable rules
    // across events and threads instead of reopening those files for every label.
    @OptIn(ExperimentalAtomicApi::class)
    private val zones = AtomicReference<Map<String, TimeZone>>(emptyMap())

    @OptIn(ExperimentalAtomicApi::class)
    internal fun timeZone(id: String): TimeZone {
        zones.load()[id]?.let {
            return it
        }
        val resolved = TimeZone.of(id)
        while (true) {
            val current = zones.load()
            current[id]?.let {
                return it
            }
            if (zones.compareAndSet(current, current + (id to resolved))) return resolved
        }
    }

    private val sourcePatterns =
        mapOf(
            "yyyy-MM-dd HH:mm:ss" to Regex("\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}"),
            "yyyy-MM-dd HH:mm" to Regex("\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}"),
            "yyyy-MM-dd'T'HH:mm" to Regex("\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}"),
            "yyyy-MM-dd" to Regex("\\d{4}-\\d{2}-\\d{2}"),
            "dd.MM.yyyy" to Regex("(\\d{2})\\.(\\d{2})\\.(\\d{4})"),
            "dd.MM.yyyy HH:mm" to Regex("(\\d{2})\\.(\\d{2})\\.(\\d{4}) (\\d{2}):(\\d{2})"),
        )
    private val apiTimePattern = Regex("(.+)\\.(\\d{6})")

    fun parse(value: String, pattern: String, zone: String): Double? =
        try {
            val sourcePattern = requireNotNull(sourcePatterns[pattern])
            require(sourcePattern.matches(value))
            val dateTime =
                when (pattern) {
                    "yyyy-MM-dd HH:mm:ss" -> LocalDateTime.parse(value.replace(' ', 'T'))
                    "yyyy-MM-dd" -> LocalDate.parse(value).atTime(0, 0)
                    "yyyy-MM-dd HH:mm" -> LocalDateTime.parse(value.replace(' ', 'T'))
                    "yyyy-MM-dd'T'HH:mm" -> LocalDateTime.parse(value)
                    "dd.MM.yyyy",
                    "dd.MM.yyyy HH:mm" -> {
                        val match = sourcePattern.matchEntire(value)
                        requireNotNull(match)
                        val p = match.groupValues
                        LocalDate(p[3].toInt(), p[2].toInt(), p[1].toInt())
                            .atTime(
                                if (p.size > 4) p[4].toInt() else 0,
                                if (p.size > 5) p[5].toInt() else 0,
                            )
                    }
                    else ->
                        throw IllegalArgumentException("Unsupported source date pattern: $pattern")
                }
            val tz = timeZone(zone)
            val instant = dateTime.toInstant(tz)
            if (instant.toLocalDateTime(tz) != dateTime) null else instant.epochSeconds.toDouble()
        } catch (_: IllegalArgumentException) {
            null
        }

    fun apiTime(value: String, zone: String): Double? {
        val match = apiTimePattern.matchEntire(value) ?: return null
        return parse(match.groupValues[1], "yyyy-MM-dd HH:mm:ss", zone)
            ?.plus(match.groupValues[2].toDouble() / 1_000_000)
    }

    fun local(seconds: Double, zone: String): LocalDateTime = local(seconds, timeZone(zone))

    internal fun local(seconds: Double, zone: TimeZone): LocalDateTime =
        Instant.fromEpochMilliseconds((seconds * 1000).toLong()).toLocalDateTime(zone)

    fun currentDay(
        days: List<Int>,
        now: Double,
        year: Int,
        month: Int,
        zone: String = "Europe/Berlin",
    ): Int? {
        val local = local(now, zone)
        if (local.year != year || local.month.number != month) return null
        val day = local.day - if (local.hour < 5) 1 else 0
        return day.takeIf { it in days }
    }
}

object ProgramValidation {
    fun valid(
        events: List<ProgramEvent>,
        artistIDs: List<Long>,
        placeIDs: List<String>,
        dayIDs: List<String>,
    ): Boolean {
        fun <T> unique(values: List<T>) = values.size == values.toSet().size
        return unique(events.map { it.id }) &&
            unique(artistIDs) &&
            unique(placeIDs) &&
            unique(dayIDs) &&
            events.all {
                it.artistID in artistIDs &&
                    it.start?.isFinite() != false &&
                    (it.placeID == null || it.placeID in placeIDs) &&
                    (it.dayID == null || it.dayID in dayIDs) &&
                    (it.duration == null || it.duration in 1..1440)
            }
    }
}
