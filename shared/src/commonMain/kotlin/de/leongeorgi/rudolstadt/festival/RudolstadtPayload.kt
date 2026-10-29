package de.leongeorgi.rudolstadt.festival

import kotlinx.serialization.json.*

/** Parsed wire data. Native transports never construct a second set of API models. */
class RudolstadtRecords
internal constructor(
    internal val values: JsonArray,
    val omittedRecordCount: Int,
)

class RudolstadtPayload internal constructor(internal val root: JsonObject) {
    val sourceJSON: String by lazy { root.toString() }

    val omittedRecordCount: Int
        get() = root.int("omittedRecordCount") ?: 0
}

object RudolstadtPayloads {
    private val endpoints = listOf("areas", "artists", "events", "stages", "tags")

    fun records(endpoint: String, sourceJSON: String): RudolstadtRecords {
        require(endpoint in endpoints)
        return records(endpoint, Json.parseToJsonElement(sourceJSON).jsonArray)
    }

    private fun records(endpoint: String, raw: JsonArray): RudolstadtRecords {
        val objects =
            raw.mapNotNull { it as? JsonObject }
                .filter {
                    it.long("id") != null &&
                        (endpoint !in setOf("areas", "tags") ||
                            (it.string("title") != null && it.string("title_en") != null))
                }
        val counts = objects.groupingBy { it.long("id") }.eachCount()
        val valid = objects.filter { it.long("id")!! > 0 && counts[it.long("id")] == 1 }
        return RudolstadtRecords(JsonArray(valid), raw.size - valid.size)
    }

    fun assemble(
        areas: RudolstadtRecords,
        artists: RudolstadtRecords,
        events: RudolstadtRecords,
        stages: RudolstadtRecords,
        tags: RudolstadtRecords,
    ): RudolstadtPayload = payload(listOf(areas, artists, events, stages, tags), 0)

    fun decode(sourceJSON: String): RudolstadtPayload =
        decode(Json.parseToJsonElement(sourceJSON).jsonObject)

    internal fun decode(root: JsonObject): RudolstadtPayload {
        val omitted =
            if ("omittedRecordCount" in root) {
                requireNotNull(root.int("omittedRecordCount"))
            } else 0
        require(omitted >= 0)
        return payload(endpoints.map { records(it, root.getValue(it).jsonArray) }, omitted)
    }

    private fun payload(records: List<RudolstadtRecords>, omitted: Int): RudolstadtPayload =
        RudolstadtPayload(
            buildJsonObject {
                endpoints.zip(records).forEach { (endpoint, values) ->
                    put(endpoint, values.values)
                }
                put("omittedRecordCount", omitted + records.sumOf { it.omittedRecordCount })
            }
        )
}
