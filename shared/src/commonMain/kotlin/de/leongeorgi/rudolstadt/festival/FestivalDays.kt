package de.leongeorgi.rudolstadt.festival

import de.leongeorgi.rudolstadt.planning.PlaceLocation
import kotlinx.datetime.*
import kotlinx.serialization.Serializable

@Serializable
data class ProgramDay(
    val id: String,
    val year: Int,
    val month: Int,
    val day: Int,
    val start: Double,
    val end: Double,
)

@Serializable data class DayAssignment(val days: List<ProgramDay>, val eventDays: Map<Long, String>)

object FestivalDays {
    fun assign(
        events: List<ProgramEvent>,
        zone: String,
        boundaryHour: Int,
        earliestDate: String?,
    ): DayAssignment {
        val tz = FestivalTime.timeZone(zone)
        val earliest = earliestDate?.let(LocalDate::parse)
        val days = mutableMapOf<String, ProgramDay>()
        val assignments = mutableMapOf<Long, String>()
        events.forEach { event ->
            val date = (event.start ?: event.knownDate)?.let { FestivalTime.local(it, tz) }
            if (date != null) {
                val logicalDate =
                    if (event.start != null && date.hour < boundaryHour)
                        date.date.minus(DatePeriod(days = 1))
                    else date.date
                if (earliest == null || logicalDate >= earliest) {
                    val id = logicalDate.toString()
                    if (id !in days) {
                        val start =
                            logicalDate
                                .atTime(boundaryHour, 0)
                                .toInstant(tz)
                                .epochSeconds
                                .toDouble()
                        val end =
                            logicalDate
                                .plus(DatePeriod(days = 1))
                                .atTime(boundaryHour, 0)
                                .toInstant(tz)
                                .epochSeconds
                                .toDouble()
                        days[id] =
                            ProgramDay(
                                id,
                                logicalDate.year,
                                logicalDate.month.number,
                                logicalDate.day,
                                start,
                                end,
                            )
                    }
                    assignments[event.id] = id
                }
            }
        }
        return DayAssignment(days.values.sortedBy { it.start }, assignments)
    }

    fun hour(
        start: Double,
        hasStart: Boolean,
        programDayStart: Double,
        hasProgramDay: Boolean,
        zone: String,
    ): Int {
        if (!hasStart) return 0
        if (hasProgramDay) {
            val midnight =
                FestivalTime.local(programDayStart, zone)
                    .date
                    .atStartOfDayIn(FestivalTime.timeZone(zone))
                    .epochSeconds
            return ((start - midnight) / 3600).toInt()
        }
        val hour = FestivalTime.local(start, zone).hour
        return if (hour < 5) hour + 24 else hour
    }

    fun day(
        start: Double,
        hasStart: Boolean,
        knownDate: Double,
        hasKnownDate: Boolean,
        explicitDay: Int,
        zone: String,
    ): Int {
        if (explicitDay > 0) return explicitDay
        if (!hasKnownDate) return 0
        return FestivalTime.local(knownDate, zone).day -
            if (hasStart && FestivalTime.local(start, zone).hour < 5) 1 else 0
    }

    fun startMinutes(
        start: Double,
        hasStart: Boolean,
        programDayStart: Double,
        hasProgramDay: Boolean,
        zone: String,
    ): Int =
        if (!hasStart) 0
        else
            hour(start, true, programDayStart, hasProgramDay, zone) * 60 +
                FestivalTime.local(start, zone).minute
}

@Serializable
data class MapGeometry(
    val id: String,
    val placeIDs: List<String>,
    val coordinates: List<PlaceLocation> = emptyList(),
    val positions: List<MapPoint> = emptyList(),
    val width: Double? = null,
    val height: Double? = null,
)

@Serializable data class MapPoint(val x: Double, val y: Double)

object MapValidation {
    fun valid(maps: List<MapGeometry>, defaultID: String, places: Set<String>): Boolean {
        if (
            maps.isEmpty() ||
                maps.map { it.id }.toSet().size != maps.size ||
                maps.none { it.id == defaultID }
        )
            return false
        return maps.all { map ->
            map.placeIDs.all { it in places } &&
                map.coordinates.all {
                    it.latitude.isFinite() &&
                        it.longitude.isFinite() &&
                        it.latitude in -90.0..90.0 &&
                        it.longitude in -180.0..180.0
                } &&
                map.positions.all {
                    it.x.isFinite() && it.y.isFinite() && it.x in 0.0..1.0 && it.y in 0.0..1.0
                } &&
                (map.width == null || (map.width.isFinite() && map.width > 0)) &&
                (map.height == null || (map.height.isFinite() && map.height > 0))
        }
    }
}
