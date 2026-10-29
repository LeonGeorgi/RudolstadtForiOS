package de.leongeorgi.rudolstadt.festival

import de.leongeorgi.rudolstadt.planning.*

data class ProgramPlaceInformation(
    val content: ProgramContent?,
    val programLinks: List<ProgramLink>,
)

data class ProgramEventInformation(
    val content: ProgramContent?,
    val tags: List<ProgramTag>,
    val programLinks: List<ProgramLink>,
    val informationFields: List<ProgramInformationField> = emptyList(),
)

data class ProgramAdmission(val categoryIDs: Set<String>, val notes: Map<String, String>?)

data class ProgramAirDistance(val meters: Double, val approximate: Boolean)

data class ProgramWalkingTransfer(val transfer: Transfer, val approximate: Boolean)

class ProgramArtistCatalog(values: List<ProgramArtist>, val groupings: List<ProgramGrouping>) {
    private val artists = values.associateBy { it.artistID }

    fun artist(id: Long) = artists[id]

    fun details(id: Long) = artist(id)?.content

    fun languages(id: Long) = artist(id)?.summaries.orEmpty().map { it.language }.toSet()

    fun summary(id: Long, language: String) =
        artist(id)?.summaries?.firstOrNull { it.language == language }

    fun groupIDs(id: Long, grouping: String) = artist(id)?.groups?.get(grouping).orEmpty().toSet()
}

class ProgramPlaceCatalog(
    places: List<ProgramPlace>,
    val areas: List<ProgramArea>,
    val categories: List<ProgramCategory>,
    eventPlaces: List<ProgramOccurrence>,
    supplementary: List<ProgramSupplementaryPlace>,
) {
    private val places = places.associateBy { it.placeKey }
    private val eventPlaces = eventPlaces.associate { it.eventID to it.stage.placeKey }
    private val supplementary = supplementary.associateBy { it.place.placeKey }

    fun details(id: String): ProgramPlaceInformation? =
        supplementary[id]?.let { ProgramPlaceInformation(it.descriptions, it.links) }
            ?: places[id]?.let { ProgramPlaceInformation(it.descriptions, emptyList()) }

    fun areaIDs(id: String): Set<Long> =
        places[id]
            ?.area
            ?.areaID
            ?.takeIf { area -> areas.any { it.areaID == area } }
            ?.let(::setOf)
            .orEmpty()

    fun admission(id: String): ProgramAdmission? {
        val place = places[id] ?: return null
        val category = place.typeCode.takeIf { it != 4 }?.toString() ?: return null
        return if (categories.any { it.categoryID == category })
            ProgramAdmission(setOf(category), null)
        else null
    }

    fun eventAdmission(id: Long) = eventPlaces[id]?.let(::admission)
}

class ProgramEventCatalog(events: List<ProgramOccurrence>, val tags: List<ProgramTag>) {
    private val events = events.associateBy { it.eventID }

    fun details(id: Long) =
        events[id]?.let {
            ProgramEventInformation(
                it.editorialContent?.article,
                it.tags.mapNotNull { tag -> tags.firstOrNull { it.tagID == tag.tagID } },
                it.editorialContent?.links.orEmpty(),
                it.editorialContent?.fields.orEmpty(),
            )
        }
}

data class SimilarArtistIDs(val artistID: Long, val similarIDs: List<Long>)

class ProgramSimilarityCatalog(values: List<SimilarArtistIDs>) {
    private val values = values.associate { it.artistID to it.similarIDs }

    fun similar(id: Long, limit: Int) = values[id].orEmpty().take(limit.coerceAtLeast(0))

    fun similarArtists(id: Long, artists: List<ProgramArtist>, limit: Int): List<ProgramArtist> =
        matchingArtists(id, artists.associateBy { it.artistID }, limit)

    internal fun matchingArtists(
        id: Long,
        artists: Map<Long, ProgramArtist>,
        limit: Int,
    ): List<ProgramArtist> =
        if (limit <= 0) emptyList()
        else
            values[id]
                .orEmpty()
                .asSequence()
                .filter { it != id }
                .mapNotNull { artists[it] }
                .filter { !it.hiddenFromArtistList }
                .take(limit)
                .toList()
}

class ProgramDistanceCatalog(
    val estimator: TransferEstimator,
    coordinates: List<ProgramCoordinate>,
    private val knownPlaceIDs: Set<String>,
    val eligibleIDs: Set<Long>,
) : TransferSource {
    val walkingSource: TransferSource
        get() = TransferSource { from, to -> walking(from, to)?.transfer }

    override fun transfer(from: String, to: String): Transfer? =
        planningTransfer(from, to)?.transfer

    private val coordinates = coordinates.associate { it.placeKey to it.coordinate }

    fun straightLine(from: String, to: String): ProgramAirDistance? {
        val a = coordinates[from] ?: return null
        val b = coordinates[to] ?: return null
        val meters =
            PlaceLocation(from, a.latitude, a.longitude)
                .airDistance(PlaceLocation(to, b.latitude, b.longitude)) ?: return null
        return ProgramAirDistance(meters, a.isApproximate || b.isApproximate)
    }

    fun walking(from: String, to: String): ProgramWalkingTransfer? {
        if (from !in knownPlaceIDs || to !in knownPlaceIDs) return null
        return estimator.estimate(from, to)?.let {
            ProgramWalkingTransfer(
                it,
                coordinates[from]?.isApproximate == true || coordinates[to]?.isApproximate == true,
            )
        }
    }

    fun planningTransfer(from: String, to: String): ProgramWalkingTransfer? =
        if (coordinates[from]?.isApproximate == true || coordinates[to]?.isApproximate == true) null
        else walking(from, to)
}

data class ProgramCapabilities(
    val artists: ProgramArtistCatalog,
    val places: ProgramPlaceCatalog,
    val events: ProgramEventCatalog,
    val admission: ProgramPlaceCatalog?,
    val summaries: ProgramArtistCatalog?,
    val similarities: ProgramSimilarityCatalog?,
    val areas: ProgramPlaceCatalog?,
    val distances: ProgramDistanceCatalog?,
    val planning: ProgramDistanceCatalog?,
)

object ProgramCatalogs {
    fun build(
        prepared: PreparedProgram,
        matrix: WalkingDistanceMatrix,
        supplementary: List<ProgramSupplementaryPlace>,
        similarities: List<SimilarArtistIDs>?,
        includesAreas: Boolean,
        includesAdmission: Boolean,
        automaticPlanning: Boolean,
    ): ProgramCapabilities {
        val program = prepared.program
        val artists = ProgramArtistCatalog(program.artists, prepared.groupings)
        val places =
            ProgramPlaceCatalog(
                program.places,
                program.areas,
                prepared.admission,
                program.events,
                supplementary,
            )
        val valid = program.places.filter { it.isMetadataAvailable }
        val known = valid.map { it.placeKey }.toSet()
        val locations =
            valid.map { PlaceLocation(it.placeKey, it.latitude, it.longitude) } +
                prepared.coordinates
                    .filter { it.placeKey !in known }
                    .map {
                        PlaceLocation(it.placeKey, it.coordinate.latitude, it.coordinate.longitude)
                    }
        val distances =
            ProgramDistanceCatalog(
                TransferEstimator(locations, matrix),
                prepared.coordinates,
                program.places.map { it.placeKey }.toSet(),
                program.events
                    .filter {
                        it.startTimestamp != null &&
                            it.stage.isMetadataAvailable &&
                            it.eventDuration != null
                    }
                    .map { it.eventID }
                    .toSet(),
            )
        return ProgramCapabilities(
            artists,
            places,
            ProgramEventCatalog(program.events, prepared.tags),
            places.takeIf { includesAdmission },
            artists.takeIf { program.artists.any { it.summaries.isNotEmpty() } },
            similarities?.let(::ProgramSimilarityCatalog),
            places.takeIf { includesAreas },
            distances.takeUnless { prepared.coordinates.isEmpty() && matrix.placeIDs.isEmpty() },
            distances.takeIf { automaticPlanning },
        )
    }
}
