package de.leongeorgi.rudolstadt.festival

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class FestivalIdentity(val festivalID: String, val editionID: String) {
    val storageKey
        get() = encode(festivalID) + "/" + encode(editionID)

    private fun encode(value: String): String =
        value.encodeToByteArray().joinToString("") { byte ->
            val code = byte.toInt() and 255
            if (code in 48..57 || code in 65..90 || code in 97..122) code.toChar().toString()
            else "%" + code.toString(16).uppercase().padStart(2, '0')
        }
}

@Serializable data class PublicLink(val id: String, val title: Map<String, String>, val url: String)

@Serializable
data class FestivalDefinition(
    val identity: FestivalIdentity,
    val name: Map<String, String>,
    val editionKind: String,
    @SerialName("zone") val timeZoneID: String = "Europe/Berlin",
    val defaultLanguage: String = "de",
    val links: List<PublicLink>,
    val noticeID: String? = null,
    val notice: Map<String, String>? = null,
    val userAccess: String = "editable",
    val dayBoundaryHour: Int,
    val includesAreas: Boolean,
    val includesAdmission: Boolean,
    val automaticPlanning: Boolean,
    val earliestDate: String? = null,
    val artistNotesAccess: String = userAccess,
) {
    val metadata
        get() = programMetadata()

    val earliestCalendarDate: CalendarDate?
        get() {
            val parts = earliestDate?.split('-')?.mapNotNull { it.toIntOrNull() } ?: return null
            return if (parts.size == 3) CalendarDate(parts[0], parts[1], parts[2]) else null
        }
}

object FestivalDefinitions {
    const val currentYear = 2026
    val archiveYears = listOf(2025, 2024, 2023, 2022, 2019)

    fun rudolstadt(year: Int, archive: Boolean): FestivalDefinition =
        FestivalDefinition(
            FestivalIdentity("rudolstadt", year.toString()),
            mapOf("de" to "Rudolstadt", "en" to "Rudolstadt"),
            if (archive) "archive" else "regular",
            links =
                listOf(
                    PublicLink(
                        "website",
                        mapOf("de" to "Offizielle Website", "en" to "Official website"),
                        "https://www.rudolstadt-festival.de",
                    ),
                    PublicLink(
                        "official-app",
                        mapOf("de" to "Offizielle App", "en" to "Official app"),
                        "https://apps.apple.com/app/id534902145",
                    ),
                ),
            noticeID = if (archive) "archive" else null,
            notice =
                if (archive)
                    mapOf("de" to "Archiv · Rudolstadt $year", "en" to "Archive · Rudolstadt $year")
                else null,
            artistNotesAccess = if (archive) "readOnly" else "editable",
            dayBoundaryHour = 5,
            includesAreas = true,
            includesAdmission = true,
            automaticPlanning = !archive,
            earliestDate = if (year == 2023) "2023-07-06" else null,
        )

    val ludwigsburg =
        FestivalDefinition(
            FestivalIdentity("ludwigsburg", "2026"),
            mapOf(
                "de" to "Straßenmusikfestival Ludwigsburg",
                "en" to "Ludwigsburg Street Music Festival",
            ),
            "experimental",
            links =
                listOf(
                    PublicLink(
                        "website",
                        mapOf("de" to "Website", "en" to "Website"),
                        "https://strassenmusikfestival.de",
                    )
                ),
            noticeID = "experimental",
            notice =
                mapOf(
                    "de" to "Testfestival · Straßenmusikfestival Ludwigsburg 2026",
                    "en" to "Trial festival · Ludwigsburg Street Music Festival 2026",
                ),
            dayBoundaryHour = 0,
            includesAreas = false,
            includesAdmission = false,
            automaticPlanning = false,
        )
}
