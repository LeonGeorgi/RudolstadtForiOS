package de.leongeorgi.rudolstadt.festival

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*

/** Supplemental source JSON stays in the same runtime as its program converter. */
class ProgramExtras internal constructor(internal val root: JsonObject) {
    val sourceJSON: String by lazy { root.toString() }

    companion object {
        fun empty(): ProgramExtras =
            ProgramExtras(buildJsonObject { put("data", JsonObject(emptyMap())) })

        fun decode(sourceJSON: String): ProgramExtras {
            val root = Json.parseToJsonElement(sourceJSON).jsonObject
            require(root["data"] is JsonObject)
            return ProgramExtras(root)
        }
    }
}

@Serializable
data class BrowseTaxonomyEntry(
    val id: String,
    @SerialName("label_de") val labelDE: String,
    @SerialName("label_en") val labelEN: String,
) {
    fun group(): ProgramGroup = ProgramGroup(id, mapOf("de" to labelDE, "en" to labelEN))
}
