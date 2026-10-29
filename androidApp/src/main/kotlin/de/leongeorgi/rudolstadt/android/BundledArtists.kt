package de.leongeorgi.rudolstadt.android

import de.leongeorgi.rudolstadt.festival.FestivalDefinitions
import de.leongeorgi.rudolstadt.festival.ProgramArtist
import de.leongeorgi.rudolstadt.festival.ProgramModels
import de.leongeorgi.rudolstadt.festival.RudolstadtPayloads
import de.leongeorgi.rudolstadt.festival.RudolstadtSource
import java.text.Normalizer
import java.util.Locale
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject

/** Reads the shared module's actual packaged resources, without a second copy of the data. */
internal object BundledArtists {
    fun load(): List<ProgramArtist> {
        val year = FestivalDefinitions.currentYear
        val payload =
            RudolstadtPayloads.decode(resource("FestivalBackup/${year}_rudolstadt_data.json"))
        val extra = Json.parseToJsonElement(resource("extra_data.json")).jsonObject
        val source = RudolstadtSource(year).convert(payload, extra)
        return ProgramModels(::fold).program(source).artists.filter {
            !it.hiddenFromArtistList && it.isMetadataAvailable
        }
    }

    private fun resource(name: String): String =
        requireNotNull(BundledArtists::class.java.getResourceAsStream("/$name")) {
                "Missing bundled resource: $name"
            }
            .bufferedReader(Charsets.UTF_8)
            .use { it.readText() }

    private fun fold(value: String): String =
        Normalizer.normalize(value, Normalizer.Form.NFKD)
            .replace(Regex("\\p{M}+"), "")
            .lowercase(Locale.ROOT)
}
