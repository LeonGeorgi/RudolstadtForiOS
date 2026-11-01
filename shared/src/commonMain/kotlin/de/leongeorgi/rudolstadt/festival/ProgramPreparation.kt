package de.leongeorgi.rudolstadt.festival

import de.leongeorgi.rudolstadt.discovery.CuratedArtistLinks
import kotlinx.datetime.LocalDate

data class ArtistMetadata(
    val artistID: Long,
    val content: ProgramArtistDetails?,
    val groups: Map<String, List<String>>?,
    val summaries: List<ProgramSummary>?,
)

data class PlaceMetadata(
    val placeKey: String,
    val descriptions: ProgramContent?,
    val coordinate: PlanCoordinate?,
    val area: ProgramArea?,
    val admission: ProgramCategory?,
    val mapCategory: ProgramCategory?,
)

data class EventMetadata(
    val eventID: Long,
    val tags: List<ProgramTag>?,
)

data class ProgramGroup(val groupID: String, val titles: Map<String, String>)

data class ProgramGrouping(
    val groupingID: String,
    val titles: Map<String, String>,
    val groups: List<ProgramGroup>,
)

data class ProgramCoordinate(val placeKey: String, val coordinate: PlanCoordinate)

data class ProgramSupplementaryPlace(
    val place: ProgramPlace,
    val descriptions: ProgramContent?,
    val coordinate: PlanCoordinate?,
    val category: ProgramCategory?,
    val links: List<ProgramLink> = emptyList(),
)

data class ProgramTagPolicy(
    val discoveryOrder: List<String>?,
    val hiddenTimelineNames: Set<String>,
    val titleOverrides: Map<String, Map<String, String>>,
    val introductions: Map<String, Map<String, String>>,
)

data class PreparedProgram(
    val program: FestivalProgram,
    val days: List<ProgramDay>,
    val groupings: List<ProgramGrouping>,
    val admission: List<ProgramCategory>,
    val mapCategories: List<ProgramCategory>,
    val mapAssignments: Map<String, String>,
    val coordinates: List<ProgramCoordinate>,
    val tags: List<ProgramTag>,
)

/** One common preparation path for remote data, old caches, archives and experiments. */
object ProgramPreparation {
    /** Resolve native feature-provider projections in one batch, retaining the canonical graph. */
    @Throws(Exception::class)
    fun enrich(
        input: FestivalProgram,
        days: List<OccurrenceDay>,
        zone: String,
        defaultLanguage: String,
        artistMetadata: List<ArtistMetadata>,
        placeMetadata: List<PlaceMetadata>,
        eventMetadata: List<EventMetadata>,
        areas: List<ProgramArea>,
    ): FestivalProgram {
        require(valid(input, days.map { it.date })) { "Invalid festival snapshot" }
        val artistOverrides = artistMetadata.associateBy { it.artistID }
        val placeOverrides = placeMetadata.associateBy { it.placeKey }
        val eventOverrides = eventMetadata.associateBy { it.eventID }
        val artists =
            input.artists.map { original ->
                val metadata = artistOverrides[original.artistID]
                val value =
                    original.copy(
                        content = metadata?.content ?: original.content,
                        groups = metadata?.groups ?: original.groups,
                        summaries = metadata?.summaries ?: original.summaries,
                        defaultLanguage = defaultLanguage,
                    )
                if (value == original) original else value
            }
        val places =
            input.places.map { original ->
                val metadata = placeOverrides[original.placeKey]
                val value =
                    original.copy(
                        descriptions = metadata?.descriptions ?: original.descriptions,
                        latitude = metadata?.coordinate?.latitude ?: original.latitude,
                        longitude = metadata?.coordinate?.longitude ?: original.longitude,
                        locationIsApproximate =
                            metadata?.coordinate?.isApproximate ?: original.locationIsApproximate,
                        area = metadata?.area,
                        admission = metadata?.admission,
                        mapGrouping = metadata?.mapCategory,
                        defaultLanguage = defaultLanguage,
                    )
                // Place equality intentionally compares identity only, not enriched metadata.
                if (
                    value.descriptions == original.descriptions &&
                        value.latitude.toBits() == original.latitude.toBits() &&
                        value.longitude.toBits() == original.longitude.toBits() &&
                        value.locationIsApproximate == original.locationIsApproximate &&
                        value.area == original.area &&
                        value.admission == original.admission &&
                        value.mapGrouping == original.mapGrouping &&
                        value.defaultLanguage == original.defaultLanguage
                )
                    original
                else value
            }
        val artistsByID = artists.associateBy { it.artistID }
        val placesByID = places.associateBy { it.placeKey }
        val daysByID = days.associateBy { it.date.id }
        val events =
            input.events.map { original ->
                val value =
                    original.copy(
                        artist = artistsByID.getValue(original.artist.artistID),
                        stage = placesByID[original.stage.placeKey] ?: original.stage,
                        tags = eventOverrides[original.eventID]?.tags ?: original.tags,
                        assignedDay = original.assignedDay?.date?.id?.let { daysByID[it] },
                        zoneID = zone,
                    )
                if (
                    value.artist === original.artist &&
                        value.stage === original.stage &&
                        value.tags === original.tags &&
                        value.assignedDay == original.assignedDay &&
                        value.zoneID == original.zoneID
                )
                    original
                else value
            }
        return input.copy(
            artists = artists,
            places = places,
            events = events,
            areas = areas,
            year = days.firstOrNull()?.date?.year ?: input.year,
        )
    }

    @Throws(Exception::class)
    fun prepare(
        input: FestivalProgram,
        zone: String,
        boundaryHour: Int,
        earliestDate: String?,
        defaultLanguage: String,
        includesAreas: Boolean,
        includesAdmission: Boolean,
        musicLinks: Map<String, CuratedArtistLinks>,
        taxonomy: List<ProgramGroup>,
        supplementaryPlaces: List<ProgramSupplementaryPlace>,
        planCategories: List<ProgramCategory>,
        tagPolicy: ProgramTagPolicy,
        normalizeLinkKey: (String) -> String,
        resolveURL: (String, Boolean) -> String?,
    ): PreparedProgram {
        val artists =
            input.artists.map { artist ->
                val music = musicLinks[artist.name] ?: musicLinks[normalizeLinkKey(artist.name)]
                val content =
                    if (music == null) artist.content
                    else {
                        val links =
                            listOf(
                                    "spotify" to music.spotifyURL,
                                    "appleMusic" to music.appleMusicURL,
                                )
                                .mapNotNull { (id, url) ->
                                    url?.let { resolveURL(it, true) }
                                        ?.let { ProgramLink(id, mapOf("en" to id), it) }
                                }
                        val previewURL = music.previewURL?.let { resolveURL(it, false) }
                        artist.content.copy(
                            links = artist.content.links + links,
                            previewKind =
                                when (music.preview) {
                                    "automatic" -> artist.content.previewKind
                                    "songURL" -> if (previewURL == null) "disabled" else "songURL"
                                    else -> "disabled"
                                },
                            previewURL =
                                if (music.preview == "automatic") artist.content.previewURL
                                else previewURL,
                        )
                    }
                artist.copy(content = content, defaultLanguage = defaultLanguage)
            }
        val validPlaces = input.places.filter { it.isMetadataAvailable }
        val extras = input.sitePlan?.locations.orEmpty().filter { it.stageID == null }
        val coordinates = linkedMapOf<String, PlanCoordinate>()
        validPlaces
            .filter { it.hasUsableLocation }
            .forEach { place ->
                coordinates[place.placeKey] =
                    PlanCoordinate(
                        place.latitude,
                        place.longitude,
                        place.locationIsApproximate,
                        input.sitePlan?.coordinateSourceURL,
                    )
            }
        extras.forEach { place -> place.coordinate?.let { coordinates["t:${place.id}"] = it } }
        supplementaryPlaces.forEach { place ->
            place.coordinate?.let { coordinates[place.place.placeKey] = it }
        }
        val admission = if (includesAdmission) admissionCategories else emptyList()
        val categories =
            if (input.sitePlan != null) planCategories.toMutableList()
            else admission.map { it.copy(systemImageName = "music.mic") }.toMutableList()
        val assignments = linkedMapOf<String, String>()
        if (input.sitePlan != null)
            input.sitePlan.locations.forEach {
                assignments[it.stageID?.let { id -> "n:$id" } ?: "t:${it.id}"] = it.category
            }
        else validPlaces.forEach { assignments[it.placeKey] = it.typeCode.toString() }
        supplementaryPlaces.forEach { extra ->
            extra.category?.let { category ->
                if (categories.none { it.categoryID == category.categoryID }) categories += category
                assignments[extra.place.placeKey] = category.categoryID
            }
        }
        val areas = if (includesAreas) input.areas else emptyList()
        val places =
            (validPlaces +
                    supplementaryPlaces.map { extra ->
                        extra.place.copy(
                            descriptions = extra.descriptions,
                            latitude = extra.coordinate?.latitude ?: Double.NaN,
                            longitude = extra.coordinate?.longitude ?: Double.NaN,
                            locationIsApproximate = extra.coordinate?.isApproximate ?: false,
                            mapGrouping = extra.category,
                        )
                    } +
                    extras.map {
                        ProgramPlace(
                            "t:${it.id}",
                            bilingual(it.nameDE, it.nameEN),
                            ProgramContent(bilingual(it.noteDE, it.noteEN)),
                            stageCode = it.reference,
                        )
                    })
                .map { place ->
                    val coordinate = coordinates[place.placeKey]
                    place.copy(
                        defaultLanguage = defaultLanguage,
                        latitude = coordinate?.latitude ?: place.latitude,
                        longitude = coordinate?.longitude ?: place.longitude,
                        locationIsApproximate =
                            coordinate?.isApproximate ?: place.locationIsApproximate,
                        area =
                            place.area?.takeIf { area -> areas.any { it.areaID == area.areaID } },
                        admission =
                            admission
                                .firstOrNull { it.categoryID == place.typeCode.toString() }
                                ?.takeIf { place in validPlaces },
                        mapGrouping =
                            categories.firstOrNull { it.categoryID == assignments[place.placeKey] },
                    )
                }
        val rawEvents =
            input.events.map { it.planningEvent(it.eventDuration?.minutes, true, false) }
        val assignment = FestivalDays.assign(rawEvents, zone, boundaryHour, earliestDate)
        val days = assignment.days.associateBy { it.id }
        val durations = DurationResolver.resolve(rawEvents)
        val tags = tags(input.events, tagPolicy)
        val byTag = tags.associateBy { it.tagID }
        val byArtist = artists.associateBy { it.artistID }
        val byPlace = places.associateBy { it.placeKey }
        val events =
            input.events.map { event ->
                event.copy(
                    artist = byArtist[event.artist.artistID] ?: event.artist,
                    stage =
                        byPlace[event.stage.placeKey]
                            ?: event.stage.copy(defaultLanguage = defaultLanguage),
                    tags = event.tags.mapNotNull { byTag[it.tagID] },
                    assignedDay =
                        assignment.eventDays[event.eventID]
                            ?.let { days[it] }
                            ?.let { OccurrenceDay(it) },
                    eventDuration = durations[event.eventID],
                    zoneID = zone,
                )
            }
        val groupings =
            mutableListOf(
                ProgramGrouping(
                    "artist-kind",
                    bilingual("Künstlerarten", "Artist types"),
                    artistKinds,
                )
            )
        if (taxonomy.isNotEmpty())
            groupings += ProgramGrouping("genre", bilingual("Genres", "Genres"), taxonomy)
        val program = input.copy(artists = artists, areas = areas, places = places, events = events)
        require(valid(program, assignment.days)) { "Invalid prepared festival program" }
        return PreparedProgram(
            program,
            assignment.days,
            groupings,
            admission,
            categories,
            assignments,
            coordinates.map { ProgramCoordinate(it.key, it.value) },
            tags,
        )
    }

    fun tags(events: List<ProgramOccurrence>, policy: ProgramTagPolicy): List<ProgramTag> =
        events
            .flatMap { it.tags }
            .distinctBy { it.tagID }
            .sortedWith { a, b ->
                fun rank(tag: ProgramTag) =
                    policy.discoveryOrder?.indexOf(tag.titles["de"])?.takeIf { it >= 0 }
                        ?: Int.MAX_VALUE
                val order = rank(a).compareTo(rank(b))
                if (order != 0) order else compareTagIDs(a.tagID, b.tagID)
            }
            .map { tag ->
                val name = tag.titles["de"].orEmpty()
                tag.copy(
                    titles = policy.titleOverrides[name] ?: tag.titles,
                    introductionTexts = tag.introductionTexts ?: policy.introductions[name],
                    isDiscoverable = policy.discoveryOrder?.contains(name) ?: true,
                    showsOnTimeline = name !in policy.hiddenTimelineNames,
                )
            }

    private fun compareTagIDs(a: String, b: String): Int {
        val first = a.toLongOrNull()
        val second = b.toLongOrNull()
        return if (first != null && second != null) first.compareTo(second) else a.compareTo(b)
    }

    fun valid(program: FestivalProgram, days: List<ProgramDay>): Boolean =
        program.eventDetails?.validFor(program.events.map { it.eventID }.toSet()) != false &&
            ProgramValidation.valid(
                program.events.map { it.planningEvent(it.eventDuration?.minutes, true, false) },
                program.artists.map { it.artistID },
                program.places.map { it.placeKey },
                days.map { it.id },
            ) &&
            days.all { day ->
                day.start.isFinite() &&
                    day.end.isFinite() &&
                    (day.end - day.start).isFinite() &&
                    day.end > day.start &&
                    runCatching { LocalDate(day.year, day.month, day.day) }.isSuccess
            } &&
            program.events.all { event ->
                val day =
                    event.assignedDay?.date?.id?.let { id -> days.firstOrNull { it.id == id } }
                event.startTimestamp == null ||
                    day == null ||
                    (event.startTimestamp >= day.start && event.startTimestamp < day.end)
            }

    private fun bilingual(de: String?, en: String?): Map<String, String> = buildMap {
        de?.takeIf { it.isNotEmpty() }?.let { put("de", it) }
        en?.takeIf { it.isNotEmpty() }?.let { put("en", it) }
    }

    private val artistKinds =
        listOf(
            ProgramGroup("1", bilingual("Bühnenmusik", "Stage music")),
            ProgramGroup("2", bilingual("Tanz", "Dance")),
            ProgramGroup("3", bilingual("Straßenmusik", "Street music")),
            ProgramGroup("4", bilingual("Sonstige", "Other")),
        )
    private val admissionCategories =
        listOf(
            ProgramCategory(
                "1",
                bilingual("Dauerkarte", "Festival ticket"),
                tintHex = "#BA5661",
                darkTintHex = "#DA8188",
            ),
            ProgramCategory(
                "2",
                bilingual("Dauer- und Tageskarte", "Day and festival ticket"),
                tintHex = "#078393",
                darkTintHex = "#4EABBA",
            ),
            ProgramCategory(
                "3",
                bilingual("Sonstige", "Other"),
                tintHex = "#64619B",
                darkTintHex = "#9392C8",
            ),
        )
}
