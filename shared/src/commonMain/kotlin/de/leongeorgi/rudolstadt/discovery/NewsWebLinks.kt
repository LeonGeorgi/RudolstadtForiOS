package de.leongeorgi.rudolstadt.discovery

import io.ktor.http.URLParserException
import io.ktor.http.URLProtocol
import io.ktor.http.Url
import io.ktor.http.decodeURLPart

data class NewsWebLink(
    val range: TextMentionRange,
    val url: String,
    val label: String,
    val emailAddress: String? = null,
)

object NewsWebLinks {
    private val pattern =
        Regex("\\b(?:https?://|www\\.)[^\\s<>\"\\uFFFC]+", RegexOption.IGNORE_CASE)

    fun label(url: String, displayedText: String = url): String? {
        val parsed =
            try {
                Url(url)
            } catch (_: URLParserException) {
                return null
            } catch (_: IllegalArgumentException) {
                return null
            }
        if (parsed.protocol != URLProtocol.HTTP && parsed.protocol != URLProtocol.HTTPS) return null
        if (parsed.host.isBlank()) return null
        val original = displayedText.trim()
        val text =
            if (original.isNotEmpty() && !pattern.matches(original)) original
            else {
                parsed.host.removePrefix("www.") +
                    if (parsed.encodedPath.trim('/').isNotEmpty()) "/…" else ""
            }
        return if (text.length <= 32) text else text.take(31).trimEnd { it.isHighSurrogate() } + "…"
    }

    fun find(text: String): List<NewsWebLink> =
        pattern
            .findAll(text)
            .mapNotNull { match ->
                var raw = match.value.trimEnd('.', ',', ';', ':', '!', '?')
                for ((closing, opening) in listOf(')' to '(', ']' to '[')) {
                    while (
                        raw.endsWith(closing) &&
                            raw.count { it == closing } > raw.count { it == opening }
                    ) raw = raw.dropLast(1)
                }
                val url = if (raw.startsWith("www.", ignoreCase = true)) "https://$raw" else raw
                label(url)?.let {
                    NewsWebLink(
                        TextMentionRange(match.range.first, match.range.first + raw.length),
                        url,
                        it,
                    )
                }
            }
            .toList()
}

object NewsMailLinks {
    private val email =
        Regex(
            "[\\p{L}\\p{N}!#$%&'*+/=?^_`{|}~.-]+@[\\p{L}\\p{N}](?:[\\p{L}\\p{N}-]*[\\p{L}\\p{N}])?(?:\\.[\\p{L}\\p{N}](?:[\\p{L}\\p{N}-]*[\\p{L}\\p{N}])?)+"
        )
    private val mailto = Regex("\\bmailto:[^\\s<>\"\\uFFFC]+", RegexOption.IGNORE_CASE)

    fun address(url: String): String? {
        if (!url.startsWith("mailto:", ignoreCase = true)) return null
        val address =
            try {
                url.substring(7).substringBefore('?').substringBefore('#').decodeURLPart()
            } catch (_: IllegalArgumentException) {
                return null
            }
        val local = address.substringBefore('@')
        return address.takeIf {
            email.matches(it) && !local.startsWith('.') && !local.endsWith('.') && ".." !in local
        }
    }

    fun find(text: String): List<NewsWebLink> {
        val explicit =
            mailto
                .findAll(text)
                .mapNotNull { match ->
                    val url = match.value.trimEnd('.', ',', ';', ')', ']')
                    address(url)?.let {
                        NewsWebLink(
                            TextMentionRange(match.range.first, match.range.first + url.length),
                            url,
                            it,
                            it,
                        )
                    }
                }
                .toList()
        val plain =
            email
                .findAll(text)
                .mapNotNull { match ->
                    val range = TextMentionRange(match.range.first, match.range.last + 1)
                    if (
                        explicit.any {
                            range.start < it.range.endExclusive &&
                                it.range.start < range.endExclusive
                        }
                    )
                        return@mapNotNull null
                    val url = "mailto:${match.value}"
                    address(url)?.let { NewsWebLink(range, url, it, it) }
                }
                .toList()
        return (explicit + plain).sortedBy { it.range.start }
    }
}

/** An outer destination protects addresses embedded in its path or query. */
object NewsTextLinks {
    fun find(text: String): List<NewsWebLink> {
        val result = mutableListOf<NewsWebLink>()
        val candidates =
            (NewsWebLinks.find(text) + NewsMailLinks.find(text)).sortedWith(
                compareBy<NewsWebLink> { it.range.start }.thenByDescending { it.range.endExclusive }
            )
        for (link in candidates) {
            if (
                result.none {
                    link.range.start < it.range.endExclusive &&
                        it.range.start < link.range.endExclusive
                }
            )
                result += link
        }
        return result.sortedBy { it.range.start }
    }
}
