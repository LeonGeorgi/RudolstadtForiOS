package de.leongeorgi.rudolstadt.festival

import de.leongeorgi.rudolstadt.discovery.TextFormatting
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.*

@Serializable data class SourceResult(val program: SourceProgram? = null, val error: String? = null)

object BundledSources {
    private val bridge = TextFormatting
    private val json = Json { ignoreUnknownKeys = true }

    private fun text(value: String?) = value?.let(bridge::decodeCharacterReferences)

    private fun optional(value: String?) = value?.takeIf { it.isNotEmpty() }

    private fun records(root: JsonObject, key: String): List<JsonObject> {
        val values =
            (root[key] as? JsonArray)?.map { it.jsonObject }
                ?: throw IllegalArgumentException("Missing $key")
        val ids = values.map { requireNotNull(it.long("id")) }
        require(ids.all { it > 0 } && ids.toSet().size == ids.size)
        return values
    }

    fun archive(source: String, year: Int): SourceResult =
        try {
            val root = Json.parseToJsonElement(source).jsonObject
            if (root.int("schemaVersion") != 1) SourceResult(error = "unsupportedSchema")
            else if (root.int("year") != year) SourceResult(error = "wrongYear")
            else {
                val areas =
                    records(root, "areas").map {
                        SourceArea(
                            it.long("id")!!,
                            text(it.string("de")).orEmpty(),
                            text(it.string("en")).orEmpty(),
                        )
                    }
                val tags =
                    records(root, "tags").map {
                        SourceTag(
                            it.long("id")!!,
                            text(it.string("de")).orEmpty(),
                            text(it.string("en")).orEmpty(),
                        )
                    }
                fun image(record: JsonObject, key: String, kind: String): String {
                    val value =
                        record.string(key)?.let { path ->
                            if (path.isEmpty()) ""
                            else {
                                require(path.startsWith("/assets/images/"))
                                "https://www.rudolstadt-festival.de$path"
                            }
                        }
                            ?: record.string("image").orEmpty().let {
                                if (it.isEmpty()) ""
                                else
                                    "https://www.rudolstadt-festival.de/data/$year/images/$kind/$it"
                            }
                    return value
                        .takeUnless {
                            it.substringAfterLast('/').lowercase() in
                                setOf(
                                    "aaaplatzhalter-jj406147npwtqwg.jpg",
                                    "aaaplatzhalter-eev4gvb1gk8384g.jpg",
                                )
                        }
                        .orEmpty()
                }
                val artists =
                    records(root, "artists").map {
                        val type = requireNotNull(it.int("type"))
                        require(type in 1..4 && !it.string("name").isNullOrEmpty())
                        SourceArtist(
                            it.long("id")!!,
                            text(it.string("name")).orEmpty(),
                            type,
                            it.bool("hidden") ?: false,
                            text(it.string("countries")).orEmpty(),
                            optional(it.string("website")),
                            optional(it.string("facebook")),
                            optional(it.string("youtube")),
                            optional(it.string("instagram")),
                            optional(text(it.string("de"))),
                            optional(text(it.string("en"))),
                            image(it, "thumbURL", "thumbs"),
                            image(it, "fullURL", "full"),
                        )
                    }
                val places =
                    records(root, "stages").map {
                        val area = requireNotNull(it.long("area"))
                        require(areas.any { it.id == area })
                        SourcePlace(
                            it.long("id")!!,
                            text(it.string("de")).orEmpty(),
                            text(it.string("en")).orEmpty(),
                            optional(text(it.string("descriptionDE"))),
                            optional(text(it.string("descriptionEN"))),
                            it.int("number"),
                            it.double("latitude"),
                            it.double("longitude"),
                            area,
                            it.int("type")?.takeIf { it in 1..4 } ?: 4,
                        )
                    }
                val events =
                    records(root, "events").map { record ->
                        val id = record.long("id")!!
                        val artist = requireNotNull(record.long("artist"))
                        val stage = requireNotNull(record.long("stage"))
                        val day =
                            "$year-07-${requireNotNull(record.int("day")).toString().padStart(2, '0')}"
                        val date =
                            requireNotNull(FestivalTime.parse(day, "yyyy-MM-dd", "Europe/Berlin"))
                        val start =
                            requireNotNull(
                                FestivalTime.parse(
                                    "$day ${record.string("time").orEmpty()}",
                                    "yyyy-MM-dd HH:mm",
                                    "Europe/Berlin",
                                )
                            )
                        val eventTags = record.longs("tags")
                        require(
                            artists.any { it.id == artist } &&
                                places.any { it.id == stage } &&
                                eventTags.all { tag -> tags.any { it.id == tag } }
                        )
                        SourceEvent(id, artist, stage, start, date, eventTags)
                    }
                require(artists.isNotEmpty() && events.isNotEmpty())
                SourceResult(SourceProgram(artists, areas, places, events, tags, year = year))
            }
        } catch (_: IllegalArgumentException) {
            SourceResult(error = "invalidData")
        }

    fun ludwigsburg(source: String): SourceResult =
        try {
            val root = Json.parseToJsonElement(source).jsonObject
            require(
                root.int("schemaVersion") == 1 &&
                    root.string("festivalID") == "ludwigsburg-2026" &&
                    root.int("year") == 2026 &&
                    root.string("timeZone") == "Europe/Berlin" &&
                    (root.int("omittedRecordCount") ?: -1) >= 0
            )
            val artists =
                records(root, "artists").map {
                    require(!it.string("name").isNullOrEmpty())
                    SourceArtist(
                        it.long("id")!!,
                        it.string("name")!!,
                        3,
                        countries = it.string("countries").orEmpty(),
                        website = it.string("sourceURL"),
                        facebook = it.string("facebook"),
                        youtube = it.string("youtube"),
                        instagram = it.string("instagram"),
                        descriptionDE = optional(it.string("descriptionDE")),
                        thumbnail = it.string("imageURL").orEmpty(),
                        image = it.string("imageURL").orEmpty(),
                        countryCodes = it.strings("countryCodes"),
                    )
                }
            val places =
                records(root, "stages").map {
                    require(!it.string("name").isNullOrEmpty())
                    SourcePlace(
                        it.long("id")!!,
                        it.string("name")!!,
                        it.string("name")!!,
                        area = 1,
                        type = 1,
                    )
                }
            val events =
                records(root, "events").map {
                    val artist = requireNotNull(it.long("artist"))
                    val stage = requireNotNull(it.long("stage"))
                    val duration = requireNotNull(it.int("durationMinutes"))
                    val start =
                        requireNotNull(
                            FestivalTime.parse(
                                it.string("start").orEmpty(),
                                "yyyy-MM-dd'T'HH:mm",
                                "Europe/Berlin",
                            )
                        )
                    require(
                        artists.any { it.id == artist } &&
                            places.any { it.id == stage } &&
                            duration in 1..1440 &&
                            FestivalTime.local(start, "Europe/Berlin").year == 2026
                    )
                    SourceEvent(it.long("id")!!, artist, stage, start, start, duration = duration)
                }
            require(artists.isNotEmpty() && places.isNotEmpty() && events.isNotEmpty())
            val plan = json.decodeFromString<SitePlan>(root.getValue("sitePlan").toString())
            require(
                plan.valid(places.map { it.id }.toSet()) &&
                    plan.locations.mapNotNull { it.stageID }.toSet() == places.map { it.id }.toSet()
            )
            SourceResult(
                SourceProgram(
                    artists,
                    listOf(SourceArea(1, "Festivalgelände", "Festival grounds")),
                    places,
                    events,
                    emptyList(),
                    root.int("omittedRecordCount")!!,
                    2026,
                    plan,
                )
            )
        } catch (_: IllegalArgumentException) {
            SourceResult(error = "invalidData")
        }
}
