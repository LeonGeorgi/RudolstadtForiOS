package de.leongeorgi.rudolstadt.festival

/**
 * Festival content and rules are reusable; callers resolve resource keys with their native
 * localizer.
 */
data class ProgramInformation(
    val pageID: String,
    val titles: Map<String, String>,
    val article: ProgramContent?,
    val webURL: String?,
    val iconKind: String,
    val links: List<ProgramLink>,
    val relatedPlaces: List<String>,
)

object RudolstadtContent {
    private fun texts(key: String, localize: (String, String) -> String) =
        mapOf("de" to localize(key, "de"), "en" to localize(key, "en"))

    fun eventTags(): ProgramTagPolicy =
        ProgramTagPolicy(
            listOf(
                "Workshop",
                "Tanzworkshop",
                "Vortrag",
                "Mitmachtanz",
                "Tanzabend",
                "Kindertanz",
                "Film",
                "Ausstellung",
                "Länderschwerpunkt",
                "EBU",
                "RUTH",
            ),
            setOf("Bühne", "Straßenmusik"),
            emptyMap(),
            emptyMap(),
        )

    fun parking(localize: (String, String) -> String): List<ProgramSupplementaryPlace> {
        val category = ProgramCategory("parking", mapOf("de" to "Parkplätze", "en" to "Parking"))
        return listOf(
                Triple("parking-raiffeisen", "raiffeisenstraße", 50.723778 to 11.364995),
                Triple("parking-correns", "erich-correns-ring", 50.701339 to 11.317835),
            )
            .map { (id, key, point) ->
                ProgramSupplementaryPlace(
                    ProgramPlace("t:$id", texts("park_and_ride.parking.$key.title", localize)),
                    ProgramContent(texts("park_and_ride.parking.$key.description", localize)),
                    PlanCoordinate(point.first, point.second, false, null),
                    category,
                )
            }
    }

    fun information(localize: (String, String) -> String): List<ProgramInformation> =
        listOf(
            ProgramInformation(
                "park-and-ride",
                mapOf("de" to "Park & Ride", "en" to "Park & Ride"),
                ProgramContent(texts("park_and_ride.navi.description", localize)),
                null,
                "car",
                listOf(
                    ProgramLink(
                        "source",
                        mapOf("de" to "Offizielle Informationen", "en" to "Official information"),
                        "https://www.rudolstadt-festival.de",
                    )
                ),
                listOf("t:parking-raiffeisen", "t:parking-correns"),
            ),
            ProgramInformation(
                "bus",
                mapOf("de" to "Bus", "en" to "Bus"),
                null,
                "https://auskunft.kombus-online.eu/widget/tff/?tpl=165D206D86C",
                "bus",
                emptyList(),
                emptyList(),
            ),
        )
}
