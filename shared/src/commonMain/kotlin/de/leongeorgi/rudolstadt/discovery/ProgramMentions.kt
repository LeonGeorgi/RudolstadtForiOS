package de.leongeorgi.rudolstadt.discovery

import de.leongeorgi.rudolstadt.festival.ProgramArtist
import de.leongeorgi.rudolstadt.festival.ProgramPlace

data class ProgramMentionResult(val artists: List<ProgramArtist>, val places: List<ProgramPlace>)

data class ProgramInlineMention(
    val textIndex: Int,
    val range: TextMentionRange,
    val artist: ProgramArtist?,
    val place: ProgramPlace?,
)

/** Hosts normalize Unicode and localized names; matching and appearance order are shared. */
object ProgramMentions {
    /** Texts are in reading order, so a subtitle takes precedence over the article body. */
    fun inline(
        texts: List<String>,
        artists: List<ProgramArtist>,
        places: List<ProgramPlace>,
        occupiedRanges: List<List<TextMentionRange>>,
        fold: (String) -> String,
        placeName: (ProgramPlace) -> String,
    ): List<ProgramInlineMention> {
        data class Candidate(val name: String, val artist: ProgramArtist?, val place: ProgramPlace?)

        val candidates =
            artists.distinctBy { it.artistID }.map { Candidate(it.name, it, null) } +
                places.distinctBy { it.placeKey }.map { Candidate(placeName(it), null, it) }
        val occupied = texts.indices.map { occupiedRanges.getOrNull(it).orEmpty().toMutableList() }
        val result = mutableListOf<ProgramInlineMention>()
        for (candidate in candidates.sortedByDescending { it.name.length }) {
            for (index in texts.indices) {
                val range =
                    TextMentions.ranges(texts[index], candidate.name, fold).firstOrNull { match ->
                        occupied[index].none {
                            match.start < it.endExclusive && it.start < match.endExclusive
                        }
                    } ?: continue
                result += ProgramInlineMention(index, range, candidate.artist, candidate.place)
                occupied[index] += range
                break
            }
        }
        return result.sortedWith(compareBy({ it.textIndex }, { it.range.start }))
    }

    fun find(
        normalizedText: String,
        artists: List<ProgramArtist>,
        places: List<ProgramPlace>,
        normalizedArtistName: (ProgramArtist) -> String,
        normalizedPlaceName: (ProgramPlace) -> String,
    ) =
        ProgramMentionResult(
            artists
                .mapNotNull { artist ->
                    TextSearch.firstMention(normalizedText, normalizedArtistName(artist))?.let {
                        artist to it
                    }
                }
                .sortedBy { it.second }
                .map { it.first },
            places.filter {
                TextSearch.firstMention(normalizedText, normalizedPlaceName(it)) != null
            },
        )
}
