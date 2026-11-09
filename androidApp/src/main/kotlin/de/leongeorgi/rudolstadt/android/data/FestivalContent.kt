package de.leongeorgi.rudolstadt.android.data

import de.leongeorgi.rudolstadt.discovery.*
import de.leongeorgi.rudolstadt.festival.*
import de.leongeorgi.rudolstadt.planning.*
import de.leongeorgi.rudolstadt.presentation.ProgramDetailCatalog
import java.net.URI
import java.text.Normalizer
import java.util.Locale
import kotlinx.serialization.json.*

internal data class Edition(val definition: FestivalDefinition) {
    val key: String
        get() = definition.identity.storageKey

    val year: Int
        get() = definition.identity.editionID.toInt()

    val archive: Boolean
        get() = definition.editionKind == "archive"

    val live: Boolean
        get() = definition.identity.festivalID == "rudolstadt" && !archive

    val supportsFirebaseFriends: Boolean
        get() = definition.identity.festivalID == "rudolstadt"

    val friendsEdition: String
        get() = "${definition.identity.festivalID}-${definition.identity.editionID}"

    val experimental: Boolean
        get() = definition.editionKind == "experimental"

    val editable: Boolean
        get() = definition.userAccess == "editable"

    val notesEditable: Boolean
        get() = editable && definition.artistNotesAccess == "editable"

    companion object {
        val current =
            Edition(FestivalDefinitions.rudolstadt(FestivalDefinitions.currentYear, false))
        val all =
            listOf(current) +
                FestivalDefinitions.archiveYears.map {
                    Edition(FestivalDefinitions.rudolstadt(it, true))
                } +
                Edition(FestivalDefinitions.ludwigsburg)

        fun find(key: String) = all.firstOrNull { it.key == key } ?: current
    }
}

internal data class FestivalContent(
    val edition: Edition,
    val prepared: PreparedProgram,
    val capabilities: ProgramCapabilities,
) {
    val program: FestivalProgram
        get() = prepared.program

    val index = ProgramArtistIndex(program.artists, ::foldText)
    val artists = program.artists.associateBy { it.artistID }
    val events = program.events.associateBy { it.eventID }
    val places = program.places.associateBy { it.placeKey }
    val days
        get() = prepared.days

    val transfer: TransferSource =
        capabilities.planning ?: capabilities.distances ?: TransferSource { _, _ -> null }
    val details =
        ProgramDetailCatalog(
            program.artists,
            program.places,
            program.events,
            transfer,
            capabilities.similarities,
        )
}

/**
 * Platform adapter supplies bytes; all interpretation, day assignment and planning remain shared.
 */
internal class FestivalContentLoader(
    private val resource: (String) -> String = ::resourceText,
    private val localize: (String, String) -> String = { key, _ -> key },
) {
    fun bundled(edition: Edition): FestivalContent {
        val source =
            when {
                edition.experimental ->
                    requireNotNull(
                        BundledSources.ludwigsburg(resource("FestivalBackup/ludwigsburg_2026.json"))
                            .program
                    )
                edition.archive ->
                    requireNotNull(
                        BundledSources.archive(
                                resource("FestivalBackup/${edition.year}_archive.json"),
                                edition.year,
                            )
                            .program
                    )
                else ->
                    source(edition, resource("FestivalBackup/${edition.year}_rudolstadt_data.json"))
            }
        return prepare(edition, source)
    }

    fun remote(edition: Edition, payload: String) = prepare(edition, source(edition, payload))

    private fun source(edition: Edition, payload: String): SourceProgram {
        val extra = Json.parseToJsonElement(resource("extra_data.json")).jsonObject
        val decoded = RudolstadtPayloads.decode(payload)
        require(!RudolstadtPayloads.hasForeignEventDates(decoded, edition.year)) {
            "Program belongs to a different year"
        }
        return RudolstadtSource(edition.year).convert(decoded, extra)
    }

    private fun prepare(edition: Edition, source: SourceProgram): FestivalContent {
        require(source.artists.any { !it.hidden && it.name.isNotBlank() }) { "Empty program" }
        require(
            source.events
                .mapNotNull { it.start ?: it.knownDate }
                .all {
                    FestivalTime.local(it, edition.definition.timeZoneID).year == edition.year
                }
        ) {
            "Program belongs to a different year"
        }
        val definition = edition.definition
        val rudolstadt = definition.identity.festivalID == "rudolstadt"
        val supplements = if (rudolstadt) RudolstadtContent.parking(localize) else emptyList()
        val curated =
            if (edition.live)
                CuratedLinks.parse(
                    resource("${edition.year}_artist_urls.csv"),
                    resource("${edition.year}_artist_preview_urls.csv"),
                    ::foldText,
                )
            else emptyMap()
        val taxonomy =
            Json.decodeFromString<List<BrowseTaxonomyEntry>>(resource("browse_taxonomy.json")).map {
                it.group()
            }
        val prepared =
            ProgramPreparation.prepare(
                ProgramModels(::foldText).program(source),
                definition.timeZoneID,
                definition.dayBoundaryHour,
                definition.earliestDate,
                definition.defaultLanguage,
                definition.includesAreas,
                definition.includesAdmission,
                curated,
                taxonomy,
                supplements,
                listOf(
                    ProgramCategory("stage", mapOf("de" to "Bühnen", "en" to "Stages")),
                    ProgramCategory("entrance", mapOf("de" to "Eingänge", "en" to "Entrances")),
                    ProgramCategory(
                        "food",
                        mapOf("de" to "Essen & Trinken", "en" to "Food & drink"),
                    ),
                    ProgramCategory("parking", mapOf("de" to "Parkplätze", "en" to "Parking")),
                    ProgramCategory("toilets", mapOf("de" to "Toiletten", "en" to "Toilets")),
                    ProgramCategory("firstAid", mapOf("de" to "Erste Hilfe", "en" to "First aid")),
                    ProgramCategory("service", mapOf("de" to "Service", "en" to "Services")),
                    ProgramCategory("activity", mapOf("de" to "Aktivitäten", "en" to "Activities")),
                ),
                if (rudolstadt) RudolstadtContent.eventTags()
                else ProgramTagPolicy(null, emptySet(), emptyMap(), emptyMap()),
                ::foldText,
                { url, _ -> validWebURL(url) },
            )
        val matrix =
            if (rudolstadt) WalkingMatrices.decode(resource("stage_walk_distances.json"))
            else WalkingDistanceMatrix(emptyMap())
        val similarities =
            if (edition.live) {
                val root =
                    Json.parseToJsonElement(resource("${edition.year}_artist_similarities.json"))
                        .jsonObject
                require(root.getValue("festivalYear").jsonPrimitive.int == edition.year)
                root.getValue("similarArtistIDsByArtistID").jsonObject.map { (id, values) ->
                    SimilarArtistIDs(id.toLong(), values.jsonArray.map { it.jsonPrimitive.long })
                }
            } else null
        return FestivalContent(
            edition,
            prepared,
            ProgramCatalogs.build(
                prepared,
                matrix,
                supplements,
                similarities,
                definition.includesAreas,
                definition.includesAdmission,
                definition.automaticPlanning,
            ),
        )
    }
}

internal fun resourceText(name: String): String =
    requireNotNull(FestivalContentLoader::class.java.getResourceAsStream("/$name")) {
            "Missing resource: $name"
        }
        .bufferedReader(Charsets.UTF_8)
        .use { it.readText() }

internal fun foldText(value: String): String = foldUnicodeText(value).trim()

internal fun foldUnicodeText(value: String): String =
    Normalizer.normalize(value, Normalizer.Form.NFKD)
        .replace(Regex("\\p{M}+"), "")
        .lowercase(Locale.ROOT)

internal fun validWebURL(value: String?): String? = value?.takeIf {
    runCatching {
            URI(it).let { uri ->
                uri.scheme in setOf("https", "http") &&
                    !uri.host.isNullOrEmpty() &&
                    uri.userInfo == null
            }
        }
        .getOrDefault(false)
}

internal fun Map<String, String>.text(language: String) =
    LocalizedContent.resolve(this, language, "de")

internal fun countryName(code: String, language: String): String {
    val alpha2 = CountryParser.alpha2(code) ?: return code
    return Locale.Builder()
        .setRegion(alpha2)
        .build()
        .getDisplayCountry(Locale.forLanguageTag(language))
}

internal fun ProgramArtist.countries(language: String): String =
    content.countryCodes
        .joinToString(" · ") {
            listOfNotNull(CountryParser.flag(it), countryName(it, language)).joinToString(" ")
        }
        .ifEmpty { content.countryDescription.orEmpty().text(language) }
