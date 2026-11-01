package de.leongeorgi.rudolstadt.presentation

import de.leongeorgi.rudolstadt.festival.*
import de.leongeorgi.rudolstadt.planning.*
import kotlinx.datetime.*

data class TimelineItem(val event: ProgramOccurrence?, val gapSeconds: Double = 0.0)

data class TimelineColumn(val place: ProgramPlace, val items: List<TimelineItem>)

data class ProgramTimelineData(val ticks: List<Double>, val columns: List<TimelineColumn>)

data class ProgramTimelineDay(val day: OccurrenceDay, val timeline: ProgramTimelineData)

object ProgramTimeline {
    fun buildDays(
        events: List<ProgramOccurrence>,
        days: List<OccurrenceDay>,
        durations: List<EventMinutes>,
        zone: String,
        placePrecedes: (ProgramPlace, ProgramPlace) -> Boolean,
    ): List<ProgramTimelineDay> {
        val grouped =
            events.filter { it.startTimestamp != null }.groupBy { it.assignedDay?.date?.id }
        return days.map { day ->
            ProgramTimelineDay(
                day,
                build(
                    grouped[day.date.id].orEmpty(),
                    durations,
                    zone,
                    alignedColumns = true,
                    longerFirst = true,
                    placePrecedes = placePrecedes,
                ),
            )
        }
    }

    fun build(
        events: List<ProgramOccurrence>,
        durations: List<EventMinutes>,
        zone: String,
        alignedColumns: Boolean,
        longerFirst: Boolean,
        placePrecedes: (ProgramPlace, ProgramPlace) -> Boolean,
    ): ProgramTimelineData {
        val minutes = durations.associate { it.eventID to it.minutes }
        fun end(event: ProgramOccurrence) =
            event.startTimestamp?.plus((minutes[event.eventID] ?: 60).coerceAtLeast(0) * 60.0)
        val first = events.mapNotNull { it.startTimestamp }.minOrNull()
        val last = events.mapNotNull(::end).maxOrNull()
        val columns =
            events
                .groupBy { it.stage }
                .map { (place, values) ->
                    val sorted = values.sortedWith { a, b ->
                        if (
                            longerFirst &&
                                a.startTimestamp != null &&
                                b.startTimestamp != null &&
                                a.startTimestamp == b.startTimestamp
                        )
                            compareValues(end(b), end(a)).takeIf { it != 0 }
                                ?: a.eventID.compareTo(b.eventID)
                        else if (ProgramSchedule.precedes(a, b)) -1
                        else if (ProgramSchedule.precedes(b, a)) 1 else 0
                    }
                    var cursor =
                        if (alignedColumns) first
                        else values.mapNotNull { it.startTimestamp }.minOrNull()
                    val items = mutableListOf<TimelineItem>()
                    for (event in sorted) {
                        val start = event.startTimestamp ?: continue
                        if (cursor != null && start < cursor) continue
                        if (cursor != null && cursor < start)
                            items.add(TimelineItem(null, start - cursor))
                        items.add(TimelineItem(event))
                        end(event)?.let { if (cursor == null || it > cursor) cursor = it }
                    }
                    TimelineColumn(place, items)
                }
                .sortedWith { a, b ->
                    if (placePrecedes(a.place, b.place)) -1
                    else if (placePrecedes(b.place, a.place)) 1 else 0
                }
        return ProgramTimelineData(
            if (first != null && last != null) halfHours(first, last, zone) else emptyList(),
            columns,
        )
    }

    fun halfHours(start: Double, end: Double, zone: String): List<Double> {
        val local = FestivalTime.local(start, zone)
        var cursor =
            local.date
                .atTime(local.hour, local.minute / 30 * 30)
                .toInstant(FestivalTime.timeZone(zone))
                .epochSeconds
                .toDouble()
        return buildList {
            while (cursor < end) {
                add(cursor)
                cursor += 1800
            }
            add(cursor)
        }
    }
}

data class ArtistEventConflicts(val eventID: Long, val events: List<ProgramOccurrence>)

data class PlaceDayEvents(val dayID: String, val events: List<ProgramOccurrence>)

data class NearbyPlace(val place: ProgramPlace, val transfer: Transfer)

/** Retained with a program snapshot; indexes are built on first use, not at app startup. */
class ProgramDetailCatalog(
    private val artists: List<ProgramArtist>,
    private val places: List<ProgramPlace>,
    private val events: List<ProgramOccurrence>,
    private val transfer: TransferSource,
    private val similarities: ProgramSimilarityCatalog?,
) {
    private val artistsByID by lazy { artists.associateBy { it.artistID } }
    private val eventsByArtist by lazy { events.groupBy { it.artist.artistID } }
    private val eventOrder by lazy {
        events.mapIndexed { index, event -> event.eventID to index }.toMap()
    }
    private val eventsByID by lazy { events.associateBy { it.eventID } }
    private val durations by lazy {
        events
            .mapNotNull { event -> event.eventDuration?.let { event.eventID to it.minutes } }
            .toMap()
    }
    private val daysByPlace by lazy {
        events
            .groupBy { it.stage.placeKey }
            .mapValues { (id, values) ->
                ProgramDetails.placeDays(values, id)
            }
    }
    private val nearbyByPlace by lazy {
        places.associate { place ->
            place.placeKey to
                lazy { ProgramDetails.nearby(places, place.placeKey, transfer, 10, 10) }
        }
    }

    fun artistEvents(id: Long): List<ProgramOccurrence> = eventsByArtist[id].orEmpty()

    fun placeDays(id: String): List<PlaceDayEvents> = daysByPlace[id].orEmpty()

    fun nearby(id: String): List<NearbyPlace> = nearbyByPlace[id]?.value.orEmpty()

    fun similarArtists(id: Long, limit: Int): List<ProgramArtist> =
        similarities?.matchingArtists(id, artistsByID, limit).orEmpty()

    fun conflicts(id: Long, saved: Set<Long>): List<ArtistEventConflicts> {
        val artistEvents = artistEvents(id)
        if (saved.isEmpty() || artistEvents.isEmpty())
            return artistEvents.map { ArtistEventConflicts(it.eventID, emptyList()) }
        return ProgramDetails.conflictsWithDurations(
            artistEvents,
            saved.mapNotNull { eventsByID[it] }.sortedBy { eventOrder[it.eventID] },
            durations,
            transfer,
        )
    }

    fun initialPlaceDay(
        id: String,
        highlighted: Long?,
        days: List<ProgramDay>,
        now: Double,
    ): String {
        eventsByID[highlighted]?.assignedDay?.let {
            return it.date.id
        }
        val available = placeDays(id).map { it.dayID }.toSet()
        return days.firstOrNull { it.id in available && now >= it.start && now < it.end }?.id
            ?: available.sorted().firstOrNull().orEmpty()
    }
}

object ProgramDetails {
    fun conflicts(
        artistEvents: List<ProgramOccurrence>,
        events: List<ProgramOccurrence>,
        saved: Set<Long>,
        transfer: TransferSource,
    ): List<ArtistEventConflicts> {
        val savedEvents = events.filter { it.eventID in saved }
        val durations =
            events
                .mapNotNull { event -> event.eventDuration?.let { event.eventID to it.minutes } }
                .toMap()
        return conflictsWithDurations(artistEvents, savedEvents, durations, transfer)
    }

    internal fun conflictsWithDurations(
        artistEvents: List<ProgramOccurrence>,
        savedEvents: List<ProgramOccurrence>,
        durations: Map<Long, Int>,
        transfer: TransferSource,
    ): List<ArtistEventConflicts> = artistEvents.map { event ->
        ArtistEventConflicts(
            event.eventID,
            savedEvents.filter { other ->
                other.artist.artistID != event.artist.artistID &&
                    durations[other.eventID] != null &&
                    durations[event.eventID] != null &&
                    ProgramTransitions.assess(
                            other,
                            durations.getValue(other.eventID),
                            event,
                            durations.getValue(event.eventID),
                            TransitionPolicy.savedEventWarning,
                            transfer,
                        )
                        .status == "impossible"
            },
        )
    }

    fun placeDays(events: List<ProgramOccurrence>, placeID: String): List<PlaceDayEvents> =
        events
            .filter { it.stage.placeKey == placeID }
            .groupBy { event ->
                event.assignedDay?.date?.id
                    ?: event.knownDateTimestamp
                        ?.let {
                            val date = FestivalTime.local(it, event.zoneID).date
                            (if (event.startTimestamp != null && event.festivalHourValue >= 24)
                                    date.minus(DatePeriod(days = 1))
                                else date)
                                .toString()
                        }
                        .orEmpty()
            }
            .map { PlaceDayEvents(it.key, it.value) }

    fun initialPlaceDay(
        events: List<ProgramOccurrence>,
        placeID: String,
        highlighted: Long?,
        days: List<ProgramDay>,
        now: Double,
    ): String {
        events
            .firstOrNull { it.eventID == highlighted }
            ?.assignedDay
            ?.let {
                return it.date.id
            }
        val available = placeDays(events, placeID).map { it.dayID }.toSet()
        return days.firstOrNull { it.id in available && now >= it.start && now < it.end }?.id
            ?: available.sorted().firstOrNull().orEmpty()
    }

    fun nearby(
        places: List<ProgramPlace>,
        sourceID: String,
        transfer: TransferSource,
        maximumMinutes: Int,
        limit: Int,
    ): List<NearbyPlace> =
        places
            .filter { it.placeKey != sourceID }
            .mapNotNull { place ->
                transfer
                    .transfer(sourceID, place.placeKey)
                    ?.takeIf { it.walkingMinutes <= maximumMinutes }
                    ?.let { NearbyPlace(place, it) }
            }
            .sortedBy { it.transfer.distanceInMeters }
            .take(limit.coerceAtLeast(0))
}
