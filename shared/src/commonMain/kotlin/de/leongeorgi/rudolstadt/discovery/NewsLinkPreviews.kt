package de.leongeorgi.rudolstadt.discovery

import io.ktor.http.URLBuilder
import io.ktor.http.URLProtocol
import io.ktor.http.Url
import io.ktor.http.takeFrom
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class NewsLinkPreview(
    val url: String,
    val domain: String,
    val title: String? = null,
    val imageURL: String? = null,
    val fetchedAtMillis: Long,
    val fetched: Boolean = true,
)

object NewsLinkPreviews {
    private val json = Json { ignoreUnknownKeys = true }
    private val ignored =
        Regex(
            "<!--.*?-->|<(script|style)\\b[^>]*>.*?</\\1\\s*>",
            setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
        )
    private val meta = Regex("<meta\\b(?:[^'\">]|'[^']*'|\"[^\"]*\")*>", RegexOption.IGNORE_CASE)
    private val attributes = Regex("([\\w:-]+)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))")
    private val titleTag =
        Regex(
            "<title\\b[^>]*>(.*?)</title\\s*>",
            setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
        )

    fun requestURL(url: String): String? =
        try {
            val parsed = Url(url)
            url.substringBefore('#').takeIf {
                (url.startsWith("https://", true) || url.startsWith("http://", true)) &&
                    parsed.protocol in listOf(URLProtocol.HTTP, URLProtocol.HTTPS) &&
                    parsed.host.isNotBlank()
            }
        } catch (_: Exception) {
            null
        }

    fun domain(url: String): String = Url(url).host.removePrefix("www.")

    fun cacheKey(url: String): String = (requestURL(url) ?: url).hashCode().toUInt().toString(16)

    fun encode(preview: NewsLinkPreview): String = json.encodeToString(preview)

    fun decode(value: String): NewsLinkPreview? =
        try {
            json.decodeFromString<NewsLinkPreview>(value)
        } catch (_: Exception) {
            null
        }

    fun isFresh(preview: NewsLinkPreview, nowMillis: Long): Boolean =
        nowMillis >= preview.fetchedAtMillis &&
            nowMillis - preview.fetchedAtMillis <
                if (preview.fetched) 6 * 60 * 60 * 1000L else 5 * 60 * 1000L

    fun parse(url: String, documentURL: String, html: String, nowMillis: Long): NewsLinkPreview {
        val cleaned = ignored.replace(html.take(262144), "")
        val head =
            cleaned.take(
                Regex("</head\\s*>", RegexOption.IGNORE_CASE).find(cleaned)?.range?.first
                    ?: cleaned.length
            )
        val values = mutableMapOf<String, String>()
        for (tag in meta.findAll(head)) {
            val fields =
                attributes.findAll(tag.value).associate { match ->
                    match.groupValues[1].lowercase() to
                        decodeEntities(
                            match.groupValues.drop(2).firstOrNull { it.isNotEmpty() }.orEmpty()
                        )
                }
            val name = (fields["property"] ?: fields["name"])?.lowercase() ?: continue
            fields["content"]
                ?.takeIf { it.isNotBlank() }
                ?.let { if (name !in values) values[name] = it }
        }
        val title =
            sequenceOf(
                    values["og:title"],
                    values["twitter:title"],
                    titleTag.find(head)?.groupValues?.get(1)?.let(::decodeEntities),
                )
                .filterNotNull()
                .map { it.replace(Regex("\\s+"), " ").trim() }
                .firstOrNull { it.isNotEmpty() }
                ?.take(300)
        val image =
            sequenceOf(
                    values["og:image:secure_url"],
                    values["og:image"],
                    values["og:image:url"],
                    values["twitter:image"],
                    values["twitter:image:src"],
                )
                .filterNotNull()
                .mapNotNull { value ->
                    try {
                        val builder = URLBuilder(documentURL).takeFrom(value.trim())
                        val path = mutableListOf<String>()
                        for (segment in builder.encodedPathSegments) {
                            when (segment) {
                                "." -> Unit
                                ".." ->
                                    if (path.lastOrNull()?.isNotEmpty() == true)
                                        path.removeAt(path.lastIndex)
                                else -> path += segment
                            }
                        }
                        builder.encodedPathSegments = path
                        builder.buildString().let(::requestURL)
                    } catch (_: Exception) {
                        null
                    }
                }
                .firstOrNull()
        return NewsLinkPreview(url, domain(url), title, image, nowMillis)
    }

    private fun decodeEntities(value: String): String =
        TextFormatting.decodeCharacterReferences(value)
            .replace("&quot;", "\"")
            .replace("&apos;", "'")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&nbsp;", " ")
            .replace("&amp;", "&")
}
