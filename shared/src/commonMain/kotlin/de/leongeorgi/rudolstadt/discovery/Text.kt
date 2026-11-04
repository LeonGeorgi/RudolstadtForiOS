package de.leongeorgi.rudolstadt.discovery

import de.leongeorgi.rudolstadt.festival.ProgramOccurrence
import io.ktor.http.Url
import kotlinx.serialization.Serializable

object TextSearch {
    fun any(fields: List<String>, search: String): Boolean =
        search.isEmpty() || fields.any { search in it }

    fun all(fields: List<String>, search: String): Boolean =
        search.isEmpty() ||
            search.split(' ').filter(String::isNotEmpty).all { term -> fields.any { term in it } }

    fun normalizedMention(value: String): String =
        value.lowercase().replace(Regex("[^\\p{L}\\p{N}]+"), " ").replace(Regex("\\s+"), " ").trim()

    fun firstMention(text: String, candidate: String): Int? {
        if (candidate.isEmpty()) return null
        var from = 0
        while (from <= text.length) {
            val index = text.indexOf(candidate, from)
            if (index < 0) return null
            val end = index + candidate.length
            if ((index == 0 || text[index - 1] == ' ') && (end == text.length || text[end] == ' '))
                return index
            from = end
        }
        return null
    }
}

@Serializable
data class CuratedArtistLinks(
    val spotifyURL: String? = null,
    val appleMusicURL: String? = null,
    val preview: String = "automatic",
    val previewURL: String? = null,
)

object CuratedLinks {
    fun parse(
        contents: String,
        previewContents: String?,
        normalize: (String) -> String,
    ): Map<String, CuratedArtistLinks> {
        val previews = mutableMapOf<String, String>()
        previewContents?.lineSequence()?.forEach { row ->
            val columns = row.split('~')
            if (columns.size >= 2) {
                val name = columns[0].trim()
                val selection = columns[1].trim()
                if (name.isNotEmpty() && name != "Artist Name" && selection.isNotEmpty()) {
                    previews[name] = selection
                    previews.putIfAbsentCommon(normalize(name), selection)
                }
            }
        }
        val links = mutableMapOf<String, CuratedArtistLinks>()
        contents.lineSequence().forEach { row ->
            val columns = row.split('~')
            if (columns.size >= 3) {
                val name = columns[0].trim()
                if (name.isNotEmpty() && name != "Artist Name") {
                    val key = normalize(name)
                    val preview = previews[name] ?: previews[key]
                    val value =
                        CuratedArtistLinks(
                            columns[1].trim().takeIf(String::isNotEmpty),
                            columns[2].trim().takeIf(String::isNotEmpty),
                            if (preview == null) "automatic"
                            else if (preview.equals("disabled", true)) "disabled" else "songURL",
                            preview?.takeUnless { it.equals("disabled", true) },
                        )
                    links[name] = value
                    links.putIfAbsentCommon(key, value)
                }
            }
        }
        return links
    }

    private fun <K, V> MutableMap<K, V>.putIfAbsentCommon(key: K, value: V) {
        if (!containsKey(key)) put(key, value)
    }
}

@Serializable
data class ArtistPublicLink(val year: Int, val artistID: Long, val eventID: Long? = null) {
    fun url(): String? =
        if (year in 1000..9999 && artistID > 0 && (eventID == null || eventID > 0))
            "https://festival.leongeorgi.de/rudolstadt/$year/artists/$artistID" +
                (eventID?.let { "?event=$it" } ?: "")
        else null

    fun selectedEventID(events: List<ProgramOccurrence>): Long? =
        events.firstOrNull { it.eventID == eventID && it.artist.artistID == artistID }?.eventID

    companion object {
        fun parse(value: String): ArtistPublicLink? {
            val match =
                Regex(
                        "https://(?:festival\\.leongeorgi\\.de(?::443)?/rudolstadt|rudolstadt\\.leongeorgi\\.de(?::443)?)/(\\d{4})/artists/([1-9]\\d*)/?(?:[?#].*)?",
                        RegexOption.IGNORE_CASE,
                    )
                    .matchEntire(value) ?: return null
            val year =
                match.groupValues[1].toIntOrNull()?.takeIf {
                    it > 0 && it.toString() == match.groupValues[1]
                } ?: return null
            val id = match.groupValues[2].toLongOrNull() ?: return null
            // Scheme and host are case-insensitive; path components remain case-sensitive.
            val path =
                value
                    .substringAfter("://")
                    .substringAfter('/')
                    .substringBefore('?')
                    .substringBefore('#')
                    .removeSuffix("/")
            val artistPath = "$year/artists/$id"
            if (path != artistPath && path != "rudolstadt/$artistPath") return null
            // Invalid or ambiguous optional selections must not break an artist link.
            val event = runCatching { Url(value).parameters.getAll("event") }.getOrNull()
                ?.singleOrNull()?.takeIf { Regex("[1-9]\\d*").matches(it) }?.toLongOrNull()
            return ArtistPublicLink(year, id, event)
        }
    }
}

object TextFormatting {
    private val hexadecimalReference = Regex("&#x([0-9A-Fa-f]+);")
    private val decimalReference = Regex("&#([0-9]+);")
    private val lineBreak = Regex(" ?<br> ?")

    fun formatText(value: String): String =
        lineBreak.replace(value, "\n").let { text ->
            var result = text
            for (code in 34..45) result = result.replace("&#$code;", code.toChar().toString())
            result.replace("&nbsp;", " ").replace("&amp;", "&").trim()
        }

    fun decodeCharacterReferences(value: String): String {
        if ("&#" !in value) return value
        fun scalar(code: Int): String? =
            when {
                code !in 0..0x10ffff || code in 0xd800..0xdfff -> null
                code < 0x10000 -> code.toChar().toString()
                else ->
                    "${((code - 0x10000) / 1024 + 0xd800).toChar()}${((code - 0x10000) % 1024 + 0xdc00).toChar()}"
            }
        var result = value
        for ((pattern, radix) in
            listOf(hexadecimalReference to 16, decimalReference to 10)) result =
            pattern.replace(result) { match ->
                match.groupValues[1].toIntOrNull(radix)?.let(::scalar) ?: match.value
            }
        return result
    }
}

object LocalizedContent {
    fun resolve(values: Map<String, String>, requested: String, defaultLanguage: String?): String {
        val tag = requested.replace('_', '-')
        val base = tag.substringBefore('-')
        val matching = values.keys.sorted().firstOrNull { it.substringBefore('-') == base }
        return listOfNotNull(tag, matching, defaultLanguage).firstNotNullOfOrNull {
            values[it]?.takeIf(String::isNotEmpty)
        }
            ?: values.keys
                .sorted()
                .firstNotNullOfOrNull { values[it]?.takeIf(String::isNotEmpty) }
                .orEmpty()
    }
}
