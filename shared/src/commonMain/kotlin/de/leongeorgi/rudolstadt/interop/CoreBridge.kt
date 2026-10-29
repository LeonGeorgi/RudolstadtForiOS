package de.leongeorgi.rudolstadt.interop

import de.leongeorgi.rudolstadt.discovery.ArtistPublicLink
import de.leongeorgi.rudolstadt.discovery.CountryParser
import de.leongeorgi.rudolstadt.discovery.CuratedArtistLinks
import de.leongeorgi.rudolstadt.discovery.CuratedLinks
import de.leongeorgi.rudolstadt.discovery.Discovery
import de.leongeorgi.rudolstadt.discovery.DiscoveryArtist
import de.leongeorgi.rudolstadt.discovery.DiscoveryRequest
import de.leongeorgi.rudolstadt.discovery.FriendRecommendation
import de.leongeorgi.rudolstadt.discovery.ScheduleFilter
import de.leongeorgi.rudolstadt.discovery.TextCollation
import de.leongeorgi.rudolstadt.discovery.TextFormatting
import de.leongeorgi.rudolstadt.discovery.TextSearch
import de.leongeorgi.rudolstadt.festival.BrowseTaxonomyEntry
import de.leongeorgi.rudolstadt.festival.BundledSources
import de.leongeorgi.rudolstadt.festival.CachedFestivalProgram
import de.leongeorgi.rudolstadt.festival.DurationResolver
import de.leongeorgi.rudolstadt.festival.EventDuration
import de.leongeorgi.rudolstadt.festival.FestivalDays
import de.leongeorgi.rudolstadt.festival.FestivalDefinition
import de.leongeorgi.rudolstadt.festival.FestivalDefinitions
import de.leongeorgi.rudolstadt.festival.FestivalIdentity
import de.leongeorgi.rudolstadt.festival.FestivalProgram
import de.leongeorgi.rudolstadt.festival.FestivalTime
import de.leongeorgi.rudolstadt.festival.MapGeometry
import de.leongeorgi.rudolstadt.festival.MapValidation
import de.leongeorgi.rudolstadt.festival.PlanBackground
import de.leongeorgi.rudolstadt.festival.ProgramArea
import de.leongeorgi.rudolstadt.festival.ProgramArtist
import de.leongeorgi.rudolstadt.festival.ProgramDay
import de.leongeorgi.rudolstadt.festival.ProgramEvent
import de.leongeorgi.rudolstadt.festival.ProgramExtras
import de.leongeorgi.rudolstadt.festival.ProgramModels
import de.leongeorgi.rudolstadt.festival.ProgramOccurrence
import de.leongeorgi.rudolstadt.festival.ProgramPlace
import de.leongeorgi.rudolstadt.festival.ProgramResult
import de.leongeorgi.rudolstadt.festival.ProgramTag
import de.leongeorgi.rudolstadt.festival.ProgramValidation
import de.leongeorgi.rudolstadt.festival.RudolstadtPayload
import de.leongeorgi.rudolstadt.festival.RudolstadtPayloads
import de.leongeorgi.rudolstadt.festival.RudolstadtRecords
import de.leongeorgi.rudolstadt.festival.RudolstadtSource
import de.leongeorgi.rudolstadt.festival.SitePlan
import de.leongeorgi.rudolstadt.festival.obj
import de.leongeorgi.rudolstadt.planning.PlaceLocation
import de.leongeorgi.rudolstadt.planning.PlanningRequest
import de.leongeorgi.rudolstadt.planning.RecommendationPlanner
import de.leongeorgi.rudolstadt.planning.Transfer
import de.leongeorgi.rudolstadt.planning.TransferEstimator
import de.leongeorgi.rudolstadt.planning.TransferPolicy
import de.leongeorgi.rudolstadt.planning.TransitionAssessment
import de.leongeorgi.rudolstadt.planning.TransitionEvaluator
import de.leongeorgi.rudolstadt.planning.TransitionPolicy
import de.leongeorgi.rudolstadt.planning.WalkingDistanceMatrix
import de.leongeorgi.rudolstadt.profile.PersonalProfile
import de.leongeorgi.rudolstadt.profile.ProfileMutation
import de.leongeorgi.rudolstadt.profile.ProfileRecordChange
import de.leongeorgi.rudolstadt.profile.ProfileRecordValue
import de.leongeorgi.rudolstadt.profile.ProfileReducer
import de.leongeorgi.rudolstadt.profile.ProfileSync
import de.leongeorgi.rudolstadt.profile.ProfileSyncAction
import de.leongeorgi.rudolstadt.profile.ProfileVersion
import kotlinx.serialization.*
import kotlinx.serialization.json.*

/** Typed domain facade. Serialized source formats have an explicit throwing boundary. */
class CoreBridge {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        allowSpecialFloatingPointValues = true
    }

    @Throws(Exception::class)
    fun validSitePlan(planJSON: String, stagesJSON: String): Boolean =
        json.decodeFromString<SitePlan>(planJSON).valid(json.decodeFromString(stagesJSON))

    fun validPlanBackground(name: String, width: Double, height: Double): Boolean =
        PlanBackground(name, width, height, "").isValid

    fun validPlanPoint(x: Double, y: Double): Boolean =
        x.isFinite() && y.isFinite() && x in 0.0..1.0 && y in 0.0..1.0

    fun currentYear(): Int = FestivalDefinitions.currentYear

    fun archiveYears(): List<Int> = FestivalDefinitions.archiveYears

    fun rudolstadtDefinition(year: Int, archive: Boolean): FestivalDefinition =
        FestivalDefinitions.rudolstadt(year, archive)

    fun ludwigsburgDefinition(): FestivalDefinition = FestivalDefinitions.ludwigsburg

    fun identityStorageKey(festivalID: String, editionID: String): String =
        FestivalIdentity(festivalID, editionID).storageKey

    fun search(fields: List<String>, term: String, requireAllTerms: Boolean): Boolean =
        if (requireAllTerms) TextSearch.all(fields, term) else TextSearch.any(fields, term)

    fun normalizeMention(value: String): String = TextSearch.normalizedMention(value)

    fun firstMention(text: String, candidate: String): Int? =
        TextSearch.firstMention(text, candidate)

    fun curatedLinks(
        contents: String,
        previewContents: String?,
        normalize: (String) -> String,
    ): Map<String, CuratedArtistLinks> = CuratedLinks.parse(contents, previewContents, normalize)

    fun artistLink(year: Int, artistID: Long): String? = ArtistPublicLink(year, artistID).url()

    fun parseArtistLink(value: String): ArtistPublicLink? = ArtistPublicLink.parse(value)

    fun usableCoordinates(latitude: Double, longitude: Double): Boolean =
        PlaceLocation("", latitude, longitude).hasCoordinates

    fun completeEvent(
        hasProgramDay: Boolean,
        hasStart: Boolean,
        hasArtist: Boolean,
        hasPlace: Boolean,
        hasDuration: Boolean,
        hasLocation: Boolean,
        locationIsApproximate: Boolean,
        hasPlaceType: Boolean,
    ): Boolean =
        hasStart &&
            hasArtist &&
            hasPlace &&
            (if (hasProgramDay) hasDuration
            else hasLocation && !locationIsApproximate && hasPlaceType)

    fun compareEventTimes(
        firstStart: Double,
        firstHasStart: Boolean,
        firstKnownDate: Double,
        firstHasKnownDate: Boolean,
        firstID: Long,
        secondStart: Double,
        secondHasStart: Boolean,
        secondKnownDate: Double,
        secondHasKnownDate: Boolean,
        secondID: Long,
    ): Int {
        fun compare(x: Double, knownX: Boolean, y: Double, knownY: Boolean): Int =
            if (knownX && knownY) x.compareTo(y) else if (knownX) -1 else if (knownY) 1 else 0
        return compare(firstStart, firstHasStart, secondStart, secondHasStart).takeIf { it != 0 }
            ?: compare(firstKnownDate, firstHasKnownDate, secondKnownDate, secondHasKnownDate)
                .takeIf { it != 0 }
            ?: firstID.compareTo(secondID)
    }

    fun applyRecord(profile: PersonalProfile, value: ProfileRecordValue): PersonalProfile =
        value.apply(profile)

    fun recordDeleted(value: ProfileRecordValue): Boolean = value.isDeleted

    fun legacyRecordContent(value: ProfileRecordValue): String = value.legacyContent

    fun compareVersions(
        firstDate: Double,
        firstID: String,
        secondDate: Double,
        secondID: String,
    ): Int = ProfileVersion(firstDate, firstID).compareTo(ProfileVersion(secondDate, secondID))

    fun profileSyncChanges(
        old: List<ProfileRecordChange>,
        new: List<ProfileRecordChange>,
    ): List<ProfileSyncAction> = ProfileSync.changes(old, new)

    @Throws(IllegalArgumentException::class)
    fun assignDays(
        events: List<ProgramEvent>,
        zone: String,
        boundaryHour: Int,
        earliestDate: String?,
    ): AssignedDays {
        val assignment = FestivalDays.assign(events, zone, boundaryHour, earliestDate)
        return AssignedDays(
            assignment.days,
            assignment.eventDays.map { EventDay(it.key, it.value) },
        )
    }

    fun festivalHour(
        start: Double,
        hasStart: Boolean,
        programDayStart: Double,
        hasProgramDay: Boolean,
        zone: String,
    ): Int = FestivalDays.hour(start, hasStart, programDayStart, hasProgramDay, zone)

    fun festivalDay(
        start: Double,
        hasStart: Boolean,
        knownDate: Double,
        hasKnownDate: Boolean,
        explicitDay: Int,
        zone: String,
    ): Int = FestivalDays.day(start, hasStart, knownDate, hasKnownDate, explicitDay, zone)

    fun startMinutes(
        start: Double,
        hasStart: Boolean,
        programDayStart: Double,
        hasProgramDay: Boolean,
        zone: String,
    ): Int = FestivalDays.startMinutes(start, hasStart, programDayStart, hasProgramDay, zone)

    fun validDays(days: List<ProgramDay>, events: List<ProgramEvent>): Boolean =
        days.all { it.start.isFinite() && (it.end - it.start).isFinite() && it.end > it.start } &&
            events.all { e ->
                e.start == null ||
                    e.dayID == null ||
                    days
                        .firstOrNull { it.id == e.dayID }
                        ?.let { e.start >= it.start && e.start < it.end } != false
            }

    fun validMaps(maps: List<MapGeometry>, defaultID: String, places: Set<String>): Boolean =
        MapValidation.valid(maps, defaultID, places)

    fun countryTable(name: String): Map<String, String> = CountryParser.table(name)

    fun countryCodes(
        value: String,
        preservingUKNations: Boolean,
        fold: (String) -> String,
    ): List<String> = CountryParser(fold).parse(value, preservingUKNations)

    fun alpha2CountryCode(value: String): String? = CountryParser.alpha2(value)

    fun countryFlag(value: String): String? = CountryParser.flag(value)

    fun artistOverview(request: DiscoveryRequest, collation: TextCollation): List<Long> =
        Discovery.artistOverview(
            request.artists,
            request.favoritesOnly,
            request.ratings,
            request.search,
            collation,
        )

    fun friends(request: DiscoveryRequest, collation: TextCollation): List<FriendRecommendation> =
        Discovery.friendRecommendations(
            request.profiles,
            request.artists,
            request.events,
            request.excluded,
            collation,
        )

    fun excludedArtists(request: DiscoveryRequest): Set<Long> =
        Discovery.excludedArtists(request.savedEventIDs, request.ratings, request.events)

    fun similarArtists(
        artistID: Long,
        ranked: List<Long>,
        artists: List<DiscoveryArtist>,
        catalogYear: Int,
        year: Int,
        limit: Int,
    ): List<Long> = Discovery.similarArtists(artistID, ranked, artists, catalogYear, year, limit)

    fun filterOccurrences(
        events: List<ProgramOccurrence>,
        filter: String,
        saved: Set<Long>,
        positiveArtists: Set<Long>,
        recommended: Set<Long>,
    ): List<ProgramOccurrence> =
        ScheduleFilter.occurrences(events, filter, saved, positiveArtists, recommended)

    fun filterEvents(
        events: List<ProgramEvent>,
        filter: String,
        saved: Set<Long>,
        positiveArtists: Set<Long>,
        recommended: Set<Long>,
    ): List<Long> = ScheduleFilter.eventIDs(events, filter, saved, positiveArtists, recommended)

    @Throws(Exception::class)
    fun convertArchive(sourceJSON: String, year: Int, fold: (String) -> String): ProgramResult {
        val result = BundledSources.archive(sourceJSON, year)
        return ProgramResult(result.program?.let { ProgramModels(fold).program(it) }, result.error)
    }

    @Throws(Exception::class)
    fun convertLudwigsburg(sourceJSON: String, fold: (String) -> String): ProgramResult {
        val result = BundledSources.ludwigsburg(sourceJSON)
        return ProgramResult(result.program?.let { ProgramModels(fold).program(it) }, result.error)
    }

    fun emptyProgramExtras(): ProgramExtras = ProgramExtras.empty()

    @Throws(Exception::class)
    fun decodeProgramExtras(sourceJSON: String): ProgramExtras = ProgramExtras.decode(sourceJSON)

    @Throws(Exception::class)
    fun decodeBrowseTaxonomy(sourceJSON: String): List<BrowseTaxonomyEntry> =
        json.decodeFromString(sourceJSON)

    @Throws(Exception::class)
    fun rudolstadtRecords(endpoint: String, sourceJSON: String): RudolstadtRecords =
        RudolstadtPayloads.records(endpoint, sourceJSON)

    @Throws(Exception::class)
    fun decodeRudolstadtPayload(sourceJSON: String): RudolstadtPayload =
        RudolstadtPayloads.decode(sourceJSON)

    fun assembleRudolstadtPayload(
        areas: RudolstadtRecords,
        artists: RudolstadtRecords,
        events: RudolstadtRecords,
        stages: RudolstadtRecords,
        tags: RudolstadtRecords,
    ): RudolstadtPayload = RudolstadtPayloads.assemble(areas, artists, events, stages, tags)

    @Throws(Exception::class)
    fun programFromRudolstadtPayload(
        payload: RudolstadtPayload,
        extraData: ProgramExtras,
        year: Int,
        fold: (String) -> String,
    ): FestivalProgram =
        ProgramModels(fold).program(RudolstadtSource(year).convert(payload, extraData.root))

    @Throws(Exception::class)
    fun convertRudolstadt(
        sourceJSON: String,
        extraJSON: String,
        year: Int,
        fold: (String) -> String = { it },
    ): FestivalProgram =
        ProgramModels(fold)
            .program(
                RudolstadtSource(year)
                    .convert(
                        json.parseToJsonElement(sourceJSON).jsonObject,
                        json.parseToJsonElement(extraJSON).jsonObject,
                    )
            )

    @Throws(Exception::class)
    fun convertArtist(
        sourceJSON: String,
        extraJSON: String,
        tagsJSON: String,
        eventsJSON: String,
        year: Int,
        fold: (String) -> String,
    ): ProgramArtist =
        ProgramModels(fold)
            .artist(
                RudolstadtSource(year)
                    .artist(
                        json.parseToJsonElement(sourceJSON).jsonObject,
                        json.parseToJsonElement(extraJSON).jsonObject.obj("data"),
                        json.decodeFromString(tagsJSON),
                        json.decodeFromString(eventsJSON),
                    )
            )

    @Throws(Exception::class)
    fun convertPlace(sourceJSON: String, year: Int, areas: List<ProgramArea>): ProgramPlace =
        ProgramModels {
            it
        }
        .place(RudolstadtSource(year).place(json.parseToJsonElement(sourceJSON).jsonObject), areas)

    @Throws(Exception::class)
    fun convertEvent(
        sourceJSON: String,
        year: Int,
        artists: List<ProgramArtist>,
        places: List<ProgramPlace>,
        tags: List<ProgramTag>,
        fold: (String) -> String,
    ): ProgramOccurrence? =
        RudolstadtSource(year).event(json.parseToJsonElement(sourceJSON).jsonObject)?.let {
            ProgramModels(fold).event(it, artists, places, tags)
        }

    @Throws(Exception::class)
    fun encodeProgram(program: FestivalProgram): String =
        json.encodeToString(CachedFestivalProgram.from(program))

    @Throws(Exception::class)
    fun decodeProgram(cacheJSON: String): FestivalProgram =
        json.decodeFromString<CachedFestivalProgram>(cacheJSON).program()

    fun durations(events: List<ProgramEvent>): List<ResolvedDuration> =
        DurationResolver.resolve(events).map { ResolvedDuration(it.key, it.value) }

    fun recommendations(request: PlanningRequest, cancelled: () -> Boolean): List<Long> =
        RecommendationPlanner(request, cancelled).generate()

    fun transition(
        first: ProgramEvent,
        firstDuration: Int,
        second: ProgramEvent,
        secondDuration: Int,
        transfer: Transfer?,
        policy: TransitionPolicy,
    ): TransitionAssessment =
        TransitionEvaluator.assess(first, firstDuration, second, secondDuration, transfer, policy)

    fun normalizedMatrix(
        matrix: Map<String, Map<String, Double>>
    ): Map<String, Map<String, Double>> = WalkingDistanceMatrix(matrix).distances

    fun matrixDistance(
        matrix: Map<String, Map<String, Double>>,
        from: String,
        to: String,
        allowed: Set<String>?,
    ): Double? = WalkingDistanceMatrix(matrix).distance(from, to, allowed)

    fun airDistance(first: PlaceLocation, second: PlaceLocation): Double? =
        first.airDistance(second)

    fun applyProfile(profile: PersonalProfile, mutation: ProfileMutation): PersonalProfile =
        ProfileReducer.apply(profile, mutation)

    fun normalizeProfile(profile: PersonalProfile): PersonalProfile =
        ProfileReducer.normalize(profile)

    fun resolveText(
        values: Map<String, String>,
        requested: String,
        defaultLanguage: String?,
    ): String =
        de.leongeorgi.rudolstadt.discovery.LocalizedContent.resolve(
            values,
            requested,
            defaultLanguage,
        )

    fun parseDate(value: String, pattern: String, zone: String): Double? =
        FestivalTime.parse(value, pattern, zone)

    fun apiTime(value: String, zone: String): Double? = FestivalTime.apiTime(value, zone)

    fun currentDay(days: List<Int>, now: Double, year: Int, month: Int): Int? =
        FestivalTime.currentDay(days, now, year, month)

    fun validateProgram(
        events: List<ProgramEvent>,
        artists: List<Long>,
        places: List<String>,
        days: List<String>,
    ): Boolean = ProgramValidation.valid(events, artists, places, days)

    fun formatText(value: String): String = TextFormatting.formatText(value)

    fun decodeCharacterReferences(value: String): String =
        TextFormatting.decodeCharacterReferences(value)
}

class WalkingEngine(
    locations: List<PlaceLocation>,
    matrix: Map<String, Map<String, Double>>,
    policy: TransferPolicy,
) {
    private val estimator = TransferEstimator(locations, WalkingDistanceMatrix(matrix), policy)

    fun estimate(from: String, to: String): Transfer? = estimator.estimate(from, to)
}

// NSDictionary copies numeric keys as NSNumber, losing Kotlin's boxed subclass.
// Entry values keep primitive IDs typed across the Objective-C boundary.
data class ResolvedDuration(val eventID: Long, val duration: EventDuration)

data class EventDay(val eventID: Long, val dayID: String)

data class AssignedDays(val days: List<ProgramDay>, val eventDays: List<EventDay>)
