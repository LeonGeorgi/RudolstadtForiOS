package de.leongeorgi.rudolstadt.festival

import de.leongeorgi.rudolstadt.discovery.CountryParser
import de.leongeorgi.rudolstadt.planning.PlaceLocation
import kotlinx.datetime.atStartOfDayIn
import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Immutable program objects shared directly with native views. No platform UI state lives here. */
@Serializable data class ProgramContent(val texts: Map<String, String>, val html: Boolean = false)

@Serializable
data class ProgramLink(
    val linkID: String,
    val titles: Map<String, String>,
    val destination: String,
    val inAppBrowser: Boolean = false,
)

/** Localized, labeled participation information, such as audience or equipment to bring. */
@Serializable
data class ProgramInformationField(
    val fieldID: String,
    val titles: Map<String, String>,
    val values: Map<String, String>,
) {
    val hasContent: Boolean
        get() = titles.values.any { it.isNotBlank() } && values.values.any { it.isNotBlank() }
}

/** Optional editorial content supplied by a festival source, independent of artist biographies. */
@Serializable
data class ProgramEditorialContent(
    val article: ProgramContent? = null,
    val fields: List<ProgramInformationField> = emptyList(),
    val links: List<ProgramLink> = emptyList(),
) {
    val hasContent: Boolean
        get() =
            article?.texts?.values?.any { it.isNotBlank() } == true ||
                fields.any { it.hasContent } ||
                links.any { it.destination.isNotBlank() }
}

/** Event-specific content can only be supplied by opting into the festival feature. */
@Serializable data class EventDetailContent(val eventID: Long, val content: ProgramEditorialContent)

/** Presence enables concert detail pages for the festival, even without additional content. */
@Serializable
data class EventDetailsFeature(val contents: List<EventDetailContent> = emptyList()) {
    fun details(id: Long): ProgramEditorialContent? =
        contents.firstOrNull { it.eventID == id }?.content

    fun validFor(eventIDs: Set<Long>): Boolean =
        contents.map { it.eventID }.distinct().size == contents.size &&
            contents.all { it.eventID in eventIDs }
}

@Serializable
data class ProgramArtistDetails(
    val descriptions: ProgramContent,
    val thumbnail: String? = null,
    val image: String? = null,
    val countryCodes: List<String> = emptyList(),
    val links: List<ProgramLink> = emptyList(),
    val countryDescription: Map<String, String>? = null,
    val keywords: Map<String, List<String>> = emptyMap(),
    val previewKind: String = "automatic",
    val previewURL: String? = null,
)

@Serializable
data class ProgramSummary(
    val text: String,
    val language: String,
    val aiGenerated: Boolean,
    val sourceURL: String? = null,
)

@Serializable
data class ProgramArtist(
    val artistID: Long,
    val name: String,
    val hiddenFromArtistList: Boolean,
    val content: ProgramArtistDetails,
    val groups: Map<String, List<String>> = emptyMap(),
    val summaries: List<ProgramSummary> = emptyList(),
    val defaultLanguage: String? = null,
    val isMetadataAvailable: Boolean = true,
    val fallbackCountryFlags: List<String> = emptyList(),
) {
    fun withMetadata(
        content: ProgramArtistDetails,
        groups: Map<String, List<String>>,
        summaries: List<ProgramSummary>,
        defaultLanguage: String?,
    ): ProgramArtist =
        copy(
            content = content,
            groups = groups,
            summaries = summaries,
            defaultLanguage = defaultLanguage,
        )
}

@Serializable data class ProgramArea(val areaID: Long, val names: Map<String, String>)

@Serializable
data class ProgramCategory(
    val categoryID: String,
    val titles: Map<String, String>,
    val descriptionTexts: Map<String, String>? = null,
    val systemImageName: String? = null,
    val tintHex: String? = null,
    val darkTintHex: String? = null,
)

@Serializable
data class ProgramPlace(
    val placeKey: String,
    val names: Map<String, String>,
    val descriptions: ProgramContent? = null,
    val latitude: Double = Double.NaN,
    val longitude: Double = Double.NaN,
    val area: ProgramArea? = null,
    val typeCode: Int = 4,
    val defaultLanguage: String? = null,
    val isMetadataAvailable: Boolean = true,
    val locationIsApproximate: Boolean = false,
    val stageCode: String? = null,
    val admission: ProgramCategory? = null,
    val mapGrouping: ProgramCategory? = null,
) {
    fun withMetadata(
        descriptions: ProgramContent?,
        latitude: Double,
        longitude: Double,
        area: ProgramArea?,
        defaultLanguage: String?,
        locationIsApproximate: Boolean,
        stageCode: String?,
        admission: ProgramCategory?,
        mapGrouping: ProgramCategory?,
    ): ProgramPlace =
        copy(
            descriptions = descriptions,
            latitude = latitude,
            longitude = longitude,
            area = area,
            defaultLanguage = defaultLanguage,
            locationIsApproximate = locationIsApproximate,
            stageCode = stageCode,
            admission = admission,
            mapGrouping = mapGrouping,
        )

    val hasUsableLocation: Boolean
        get() = isMetadataAvailable && PlaceLocation(placeKey, latitude, longitude).hasCoordinates

    // Native place selection has always used identity equality, independent of enrichment.
    override fun equals(other: Any?): Boolean = other is ProgramPlace && placeKey == other.placeKey

    override fun hashCode(): Int = placeKey.hashCode()
}

@Serializable
data class ProgramTag(
    val tagID: String,
    val titles: Map<String, String>,
    val introductionTexts: Map<String, String>? = null,
    val isDiscoverable: Boolean = true,
    val showsOnTimeline: Boolean = true,
    val editorialContent: ProgramEditorialContent? = null,
)

@Serializable
data class OccurrenceDay(val date: ProgramDay, val titles: Map<String, String>? = null)

@Serializable
data class ProgramOccurrence(
    val eventID: Long,
    val startTimestamp: Double?,
    val knownDateTimestamp: Double?,
    val stage: ProgramPlace,
    val artist: ProgramArtist,
    val tags: List<ProgramTag>,
    val eventDuration: EventDuration? = null,
    val assignedDay: OccurrenceDay? = null,
    val zoneID: String = "Europe/Berlin",
) {
    /** Explicit festival timing for display; estimates remain available for planning. */
    val confirmedDuration: EventDuration?
        get() = eventDuration?.takeUnless { it.isEstimated }

    val festivalDayNumber
        get() =
            FestivalDays.day(
                startTimestamp ?: 0.0,
                startTimestamp != null,
                knownDateTimestamp ?: 0.0,
                knownDateTimestamp != null,
                assignedDay?.date?.day ?: 0,
                zoneID,
            )

    val festivalHourValue
        get() =
            FestivalDays.hour(
                startTimestamp ?: 0.0,
                startTimestamp != null,
                assignedDay?.date?.start ?: 0.0,
                assignedDay != null,
                zoneID,
            )

    val startMinute
        get() =
            FestivalDays.startMinutes(
                startTimestamp ?: 0.0,
                startTimestamp != null,
                assignedDay?.date?.start ?: 0.0,
                assignedDay != null,
                zoneID,
            )

    val eligibleForPlanning: Boolean
        get() =
            startTimestamp != null &&
                artist.isMetadataAvailable &&
                stage.isMetadataAvailable &&
                (if (assignedDay != null) eventDuration != null
                else
                    stage.hasUsableLocation &&
                        !stage.locationIsApproximate &&
                        stage.typeCode in 1..3)

    fun planningEvent(duration: Int?, eligible: Boolean, forPlanning: Boolean): ProgramEvent =
        ProgramEvent(
            eventID,
            artist.artistID,
            stage.placeKey.takeIf { stage.isMetadataAvailable },
            startTimestamp,
            knownDateTimestamp,
            assignedDay?.date?.id,
            if (forPlanning)
                FestivalDays.day(
                    startTimestamp ?: 0.0,
                    startTimestamp != null,
                    knownDateTimestamp ?: 0.0,
                    knownDateTimestamp != null,
                    assignedDay?.date?.day ?: 0,
                    zoneID,
                )
            else 0,
            if (forPlanning)
                FestivalDays.startMinutes(
                    startTimestamp ?: 0.0,
                    startTimestamp != null,
                    assignedDay?.date?.start ?: 0.0,
                    assignedDay != null,
                    zoneID,
                )
            else 0,
            duration,
            eventDuration?.isEstimated ?: false,
            eligible,
        )

    fun withMetadata(
        stage: ProgramPlace,
        artist: ProgramArtist,
        tags: List<ProgramTag>,
        eventDuration: EventDuration?,
        assignedDay: OccurrenceDay?,
        zoneID: String,
    ): ProgramOccurrence =
        copy(
            stage = stage,
            artist = artist,
            tags = tags,
            eventDuration = eventDuration,
            assignedDay = assignedDay,
            zoneID = zoneID,
        )
}

/** Source-to-domain conversion happens once in Kotlin; native code retains these exact objects. */
@Serializable
data class FestivalProgram(
    val artists: List<ProgramArtist>,
    val areas: List<ProgramArea>,
    val places: List<ProgramPlace>,
    val events: List<ProgramOccurrence>,
    val omittedRecordCount: Int,
    val year: Int,
    val sitePlan: SitePlan? = null,
    val eventDetails: EventDetailsFeature? = null,
)

data class ProgramResult(val program: FestivalProgram?, val error: String?)

class ProgramModels(private val fold: (String) -> String) {
    private val countries = CountryParser(fold)

    fun artist(source: SourceArtist): ProgramArtist {
        fun social(value: String?, prefix: String): String? =
            value
                ?.takeIf { it.isNotEmpty() }
                ?.let {
                    if (it.contains("http")) it else prefix + it
                }
        val links =
            listOf(
                    "website" to source.website,
                    "facebook" to social(source.facebook, "https://www.facebook.com/"),
                    "youtube" to social(source.youtube, "https://www.youtube.com/watch?v="),
                    "instagram" to source.instagram,
                )
                .mapNotNull { (id, url) ->
                    url?.takeIf { it.isNotEmpty() }?.let { ProgramLink(id, mapOf("en" to id), it) }
                }
        return ProgramArtist(
            source.id,
            source.name,
            source.hidden,
            ProgramArtistDetails(
                ProgramContent(bilingual(source.descriptionDE, source.descriptionEN), true),
                source.thumbnail,
                source.image,
                source.countryCodes ?: countries.parse(source.countries).distinct(),
                links,
                bilingual(source.countries, source.countries),
                mapOf("de" to source.tagsDE, "en" to source.tagsEN),
            ),
            mapOf(
                "artist-kind" to listOf(source.type.toString()),
                "genre" to source.genres.distinct(),
            ),
            bilingual(source.summaryDE, source.summaryEN).map { (language, text) ->
                ProgramSummary(text, language, true)
            },
            isMetadataAvailable = source.isMetadataAvailable,
            fallbackCountryFlags = source.flags,
        )
    }

    fun place(source: SourcePlace, areas: List<ProgramArea>): ProgramPlace {
        if (!source.isMetadataAvailable)
            return ProgramPlace(
                "n:${source.id}",
                bilingual("Bühne unbekannt", "Stage unknown"),
                ProgramContent(emptyMap()),
                area = ProgramArea(0, bilingual("Bereich unbekannt", "Area unknown")),
                isMetadataAvailable = false,
            )
        return ProgramPlace(
            "n:${source.id}",
            bilingual(source.de, source.en),
            ProgramContent(bilingual(source.descriptionDE, source.descriptionEN)),
            source.latitude ?: Double.NaN,
            source.longitude ?: Double.NaN,
            areas.firstOrNull { it.areaID == source.area }
                ?: ProgramArea(source.area, bilingual("Sonstige Orte", "Other locations")),
            source.type,
            stageCode = source.number?.toString(),
        )
    }

    fun event(
        source: SourceEvent,
        artists: List<ProgramArtist>,
        places: List<ProgramPlace>,
        tags: List<ProgramTag>,
    ): ProgramOccurrence =
        event(
            source,
            artists.associateBy { it.artistID },
            places.associateBy { it.placeKey },
            tags.associateBy { it.tagID },
        )

    private fun event(
        source: SourceEvent,
        artists: Map<Long, ProgramArtist>,
        places: Map<String, ProgramPlace>,
        tags: Map<String, ProgramTag>,
    ): ProgramOccurrence =
        ProgramOccurrence(
            source.id,
            source.start,
            source.start?.let {
                FestivalTime.local(it, "Europe/Berlin")
                    .date
                    .atStartOfDayIn(FestivalTime.timeZone("Europe/Berlin"))
                    .epochSeconds
                    .toDouble()
            } ?: source.knownDate,
            places["n:${source.stage}"]
                ?: place(
                    SourcePlace(
                        source.stage,
                        "Bühne unbekannt",
                        "Stage unknown",
                        area = 0,
                        type = 4,
                        isMetadataAvailable = false,
                    ),
                    emptyList(),
                ),
            artists[source.artist]
                ?: artist(
                    SourceArtist(source.artist, "", 4, hidden = true, isMetadataAvailable = false)
                ),
            source.tags.mapNotNull { tags[it.toString()] },
            source.duration?.let { EventDuration(it, false) },
        )

    fun program(source: SourceProgram): FestivalProgram {
        val areas = source.areas.map { ProgramArea(it.id, bilingual(it.de, it.en)) }
        val tags = source.tags.map { ProgramTag(it.id.toString(), bilingual(it.de, it.en)) }
        val artists =
            source.artists
                .map(::artist)
                .sortedWith(compareBy<ProgramArtist> { fold(it.name) }.thenBy { it.artistID })
        val places =
            source.places.map { value ->
                val place = place(value, areas)
                if (source.sitePlan == null) place
                else {
                    val location = source.sitePlan.locations.firstOrNull { it.stageID == value.id }
                    place.copy(
                        descriptions =
                            ProgramContent(bilingual(location?.noteDE, location?.noteEN)),
                        latitude = location?.coordinate?.latitude ?: Double.NaN,
                        longitude = location?.coordinate?.longitude ?: Double.NaN,
                        locationIsApproximate = location?.coordinate?.isApproximate ?: false,
                        stageCode = location?.reference,
                    )
                }
            }
        val byArtist = artists.associateBy { it.artistID }
        val byPlace = places.associateBy { it.placeKey }
        val byTag = tags.associateBy { it.tagID }
        val events = source.events.map { event(it, byArtist, byPlace, byTag) }
        return FestivalProgram(
            artists,
            areas,
            places,
            events,
            source.omittedRecordCount,
            source.year,
            source.sitePlan,
        )
    }

    private fun bilingual(de: String?, en: String?): Map<String, String> = buildMap {
        de?.let { put("de", it) }
        en?.let { put("en", it) }
    }
}

/**
 * Normalized on-disk graph: events refer to catalog objects instead of serializing them repeatedly.
 */
@Serializable
@OptIn(ExperimentalSerializationApi::class)
internal data class CachedOccurrence(
    val id: Long,
    val artist: Long,
    val place: String,
    val tags: List<String>,
    val start: Double?,
    val knownDate: Double?,
    val duration: EventDuration?,
    val day: OccurrenceDay?,
    val zone: String,
    @SerialName("editorialContent")
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    val legacyEditorialContent: ProgramEditorialContent? = null,
)

@Serializable
internal data class CachedFestivalProgram(
    val artists: List<ProgramArtist>,
    val areas: List<ProgramArea>,
    val places: List<ProgramPlace>,
    val tags: List<ProgramTag>,
    val events: List<CachedOccurrence>,
    val omittedRecordCount: Int,
    val year: Int,
    val sitePlan: SitePlan?,
    val eventDetails: EventDetailsFeature? = null,
    val formatVersion: Int = 1,
) {
    fun program(): FestivalProgram {
        require(formatVersion in 1..2) { "Unsupported program cache version" }
        require(
            (formatVersion == 1 && eventDetails == null) ||
                events.all { it.legacyEditorialContent == null }
        ) {
            "Event content must be supplied through the event-details feature"
        }
        val details =
            if (formatVersion == 1 && eventDetails == null)
                events
                    .mapNotNull { event ->
                        event.legacyEditorialContent?.let { EventDetailContent(event.id, it) }
                    }
                    .takeIf { it.isNotEmpty() }
                    ?.let(::EventDetailsFeature)
            else eventDetails
        require(details?.validFor(events.map { it.id }.toSet()) != false) {
            "Invalid event-details references"
        }
        val artistsByID = artists.associateBy { it.artistID }
        val placesByID = places.associateBy { it.placeKey }
        val tagsByID = tags.associateBy { it.tagID }
        require(
            artistsByID.size == artists.size &&
                placesByID.size == places.size &&
                tagsByID.size == tags.size
        )
        require(events.map { it.id }.distinct().size == events.size)
        return FestivalProgram(
            artists,
            areas,
            places,
            events.map { event ->
                ProgramOccurrence(
                    event.id,
                    event.start,
                    event.knownDate,
                    requireNotNull(placesByID[event.place]),
                    requireNotNull(artistsByID[event.artist]),
                    event.tags.map { requireNotNull(tagsByID[it]) },
                    event.duration,
                    event.day,
                    event.zone,
                )
            },
            omittedRecordCount,
            year,
            sitePlan,
            details,
        )
    }

    companion object {
        fun from(program: FestivalProgram): CachedFestivalProgram {
            require(
                program.eventDetails?.validFor(program.events.map { it.eventID }.toSet()) != false
            ) {
                "Invalid event-details references"
            }
            return CachedFestivalProgram(
                program.artists,
                program.areas,
                program.places,
                program.events.flatMap { it.tags }.distinctBy { it.tagID },
                program.events.map { event ->
                    CachedOccurrence(
                        event.eventID,
                        event.artist.artistID,
                        event.stage.placeKey,
                        event.tags.map { it.tagID },
                        event.startTimestamp,
                        event.knownDateTimestamp,
                        event.eventDuration,
                        event.assignedDay,
                        event.zoneID,
                    )
                },
                program.omittedRecordCount,
                program.year,
                program.sitePlan,
                program.eventDetails,
                2,
            )
        }
    }
}
