package de.leongeorgi.rudolstadt.festival

import de.leongeorgi.rudolstadt.discovery.TextFormatting
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*

@Serializable
data class SourceArtist(
    val id: Long,
    val name: String,
    val type: Int,
    val hidden: Boolean = false,
    val countries: String = "",
    val website: String? = null,
    val facebook: String? = null,
    val youtube: String? = null,
    val instagram: String? = null,
    val descriptionDE: String? = null,
    val descriptionEN: String? = null,
    val thumbnail: String = "",
    val image: String = "",
    val isMetadataAvailable: Boolean = true,
    val summaryDE: String? = null,
    val summaryEN: String? = null,
    val tagsDE: List<String> = emptyList(),
    val tagsEN: List<String> = emptyList(),
    val genres: List<String> = emptyList(),
    val flags: List<String> = emptyList(),
    val countryCodes: List<String>? = null,
)

@Serializable data class SourceArea(val id: Long, val de: String, val en: String)

@Serializable data class SourceTag(val id: Long, val de: String, val en: String)

@Serializable
data class SourcePlace(
    val id: Long,
    val de: String,
    val en: String,
    val descriptionDE: String? = null,
    val descriptionEN: String? = null,
    val number: Int? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val area: Long,
    val type: Int,
    val isMetadataAvailable: Boolean = true,
)

@Serializable
data class SourceEvent(
    val id: Long,
    val artist: Long,
    val stage: Long,
    val start: Double? = null,
    val knownDate: Double? = null,
    val tags: List<Long> = emptyList(),
    val duration: Int? = null,
)

@Serializable
data class SourceProgram(
    val artists: List<SourceArtist>,
    val areas: List<SourceArea>,
    val places: List<SourcePlace>,
    val events: List<SourceEvent>,
    val tags: List<SourceTag>,
    val omittedRecordCount: Int = 0,
    val year: Int,
    val sitePlan: SitePlan? = null,
)

/** Source interpretation and loss accounting are identical on both platforms. */
class RudolstadtSource(private val year: Int) {
    private val bridge = TextFormatting

    private fun decoded(value: String?) = value?.let(bridge::decodeCharacterReferences)

    private fun image(path: String): String {
        val value = "https://www.rudolstadt-festival.de/$path"
        val last = value.substringBefore('?').substringAfterLast('/').lowercase()
        return if (
            last in
                setOf("aaaplatzhalter-jj406147npwtqwg.jpg", "aaaplatzhalter-eev4gvb1gk8384g.jpg")
        )
            ""
        else value
    }

    fun artist(
        record: JsonObject,
        extra: JsonObject,
        tags: List<JsonObject>,
        events: List<JsonObject>,
    ): SourceArtist {
        val id = record.long("id") ?: error("Missing artist id")
        if (record.string("name").orEmpty().trim().isEmpty())
            return SourceArtist(id, "", 4, hidden = true, isMetadataAvailable = false)
        val artistTags =
            events
                .filter { it.long("artist") == id }
                .flatMap { it.longs("tags") }
                .mapNotNull { tag -> tags.firstOrNull { it.long("id") == tag } }
        val type =
            when (record.string("category")) {
                "dancing" -> 2
                "concert" -> if (artistTags.any { it.string("title") == "Straßenmusik" }) 3 else 1
                else -> 4
            }
        val ai = extra.obj(record.string("name").orEmpty())
        val de = ai.obj("de")
        val en = ai.obj("en")
        return SourceArtist(
            id,
            decoded(record.string("name")).orEmpty(),
            type,
            record.bool("hide_artist") ?: false,
            decoded(record.string("country")).orEmpty(),
            record.string("website"),
            record.string("facebook"),
            record.string("video"),
            record.string("instagram"),
            decoded(record.string("description_de")).orEmpty(),
            decoded(record.string("description_en")).orEmpty(),
            image(record.string("img_thumb").orEmpty()),
            image(record.string("img_full").orEmpty()),
            summaryDE = de.string("summary"),
            summaryEN = en.string("summary"),
            tagsDE = de.strings("tags"),
            tagsEN = en.strings("tags"),
            genres = ai.strings("browse_genres"),
            flags =
                if (en["countries"] is JsonArray) en.strings("countries")
                else de.strings("countries"),
        )
    }

    fun place(record: JsonObject): SourcePlace {
        val id = record.long("id") ?: error("Missing place id")
        val missing = record.string("title").orEmpty().trim().isEmpty()
        val type =
            when (record.string("category")) {
                "cityticket" -> 2
                "comboticket" -> 1
                "information" -> 3
                else -> 4
            }
        return SourcePlace(
            id,
            if (missing) "Bühne unbekannt" else decoded(record.string("title")).orEmpty(),
            if (missing) "Stage unknown"
            else decoded(record.string("title_en") ?: record.string("title")).orEmpty(),
            decoded(record.string("description")),
            decoded(record.string("description_en")),
            record.int("map_number"),
            record.double("lat"),
            record.double("lon"),
            if (missing) 0L else record.long("area") ?: 0,
            if (missing) 4 else type,
            !missing,
        )
    }

    fun event(record: JsonObject): SourceEvent? {
        val id = record.long("id")?.takeIf { it > 0 } ?: return null
        val time = record.obj("start")
        val parsed =
            FestivalTime.apiTime(time.string("date").orEmpty(), time.string("timezone").orEmpty())
        val wrongYear = parsed != null && FestivalTime.local(parsed, "Europe/Berlin").year != year
        fun inYear(value: Double?) = value?.takeIf {
            FestivalTime.local(it, "Europe/Berlin").year == year
        }
        val day =
            if (wrongYear) null
            else
                inYear(
                    FestivalTime.parse(
                        record.string("day").orEmpty(),
                        "dd.MM.yyyy",
                        "Europe/Berlin",
                    )
                )
        val start =
            if (wrongYear) null
            else
                parsed
                    ?: inYear(
                        FestivalTime.parse(
                            "${record.string("day").orEmpty()} ${record.string("time").orEmpty()}",
                            "dd.MM.yyyy HH:mm",
                            "Europe/Berlin",
                        )
                    )
        return SourceEvent(
            id,
            record.long("artist")?.takeIf { it > 0 } ?: -id,
            record.long("stage")?.takeIf { it > 0 } ?: -id,
            start,
            day,
            record.longs("tags"),
        )
    }

    fun convert(root: JsonObject, extra: JsonObject): SourceProgram =
        convert(RudolstadtPayloads.decode(root), extra)

    fun convert(payload: RudolstadtPayload, extra: JsonObject): SourceProgram {
        val root = payload.root
        val omitted = payload.omittedRecordCount
        fun unique(key: String) = root.getValue(key).jsonArray.map { it.jsonObject }
        val areas =
            unique("areas").map {
                SourceArea(
                    it.long("id")!!,
                    decoded(it.string("title")).orEmpty(),
                    decoded(it.string("title_en")).orEmpty(),
                )
            }
        val artistRecords = unique("artists")
        val stageRecords = unique("stages")
        val tagRecords = unique("tags")
        val eventRecords = unique("events")
        val tags = tagRecords.map {
            SourceTag(
                it.long("id")!!,
                decoded(it.string("title")).orEmpty(),
                decoded(it.string("title_en")).orEmpty(),
            )
        }
        val artists =
            artistRecords
                .map { artist(it, extra.obj("data"), tagRecords, eventRecords) }
                .toMutableList()
        val places = stageRecords.map(::place).toMutableList()
        val artistIDs = artists.map { it.id }.toMutableSet()
        val placeIDs = places.map { it.id }.toMutableSet()
        val events = eventRecords.mapNotNull(::event)
        events.forEach {
            if (artistIDs.add(it.artist))
                artists +=
                    SourceArtist(it.artist, "", 4, hidden = true, isMetadataAvailable = false)
            if (placeIDs.add(it.stage))
                places +=
                    SourcePlace(
                        it.stage,
                        "Bühne unbekannt",
                        "Stage unknown",
                        area = 0,
                        type = 4,
                        isMetadataAvailable = false,
                    )
        }
        return SourceProgram(artists, areas, places, events, tags, omitted, year)
    }
}

internal fun JsonObject.string(key: String): String? =
    (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.content

internal fun JsonObject.int(key: String): Int? =
    (this[key] as? JsonPrimitive)?.takeIf { !it.isString }?.intOrNull

internal fun JsonObject.double(key: String): Double? =
    (this[key] as? JsonPrimitive)?.takeIf { !it.isString }?.doubleOrNull

internal fun JsonObject.bool(key: String): Boolean? =
    (this[key] as? JsonPrimitive)?.takeIf { !it.isString }?.booleanOrNull

internal fun JsonObject.obj(key: String): JsonObject =
    this[key] as? JsonObject ?: JsonObject(emptyMap())

internal fun JsonObject.ints(key: String): List<Int> =
    (this[key] as? JsonArray).orEmpty().mapNotNull {
        (it as? JsonPrimitive)?.takeIf { !it.isString }?.intOrNull
    }

internal fun JsonObject.strings(key: String): List<String> =
    (this[key] as? JsonArray).orEmpty().mapNotNull {
        (it as? JsonPrimitive)?.takeIf { it.isString }?.content
    }

internal fun JsonObject.long(key: String): Long? =
    (this[key] as? JsonPrimitive)?.takeIf { !it.isString }?.longOrNull

internal fun JsonObject.longs(key: String): List<Long> =
    (this[key] as? JsonArray).orEmpty().mapNotNull {
        (it as? JsonPrimitive)?.takeIf { !it.isString }?.longOrNull
    }
