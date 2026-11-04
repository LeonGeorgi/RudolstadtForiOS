package de.leongeorgi.rudolstadt.android

import androidx.compose.foundation.text.appendInlineContent
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.style.TextDecoration
import de.leongeorgi.rudolstadt.android.data.foldUnicodeText
import de.leongeorgi.rudolstadt.discovery.NewsMailLinks
import de.leongeorgi.rudolstadt.discovery.NewsTextLinks
import de.leongeorgi.rudolstadt.discovery.NewsWebLink
import de.leongeorgi.rudolstadt.discovery.NewsWebLinks
import de.leongeorgi.rudolstadt.discovery.ProgramInlineMention
import de.leongeorgi.rudolstadt.discovery.ProgramMentions
import de.leongeorgi.rudolstadt.discovery.TextMentionRange
import de.leongeorgi.rudolstadt.festival.ProgramArtist
import de.leongeorgi.rudolstadt.festival.ProgramPlace

internal data class NewsText(
    val subtitle: AnnotatedString,
    val content: AnnotatedString,
    val inlineContent: Map<String, ProgramInlineMention>,
    val webLinks: Map<String, NewsWebLink>,
)

private const val WEB_PREVIEW_BLOCK = "news-web-preview-block"

internal fun newsTextParagraphs(source: AnnotatedString): List<AnnotatedString> {
    val paragraphs = mutableListOf<AnnotatedString>()
    var start = 0
    source.text.forEachIndexed { index, character ->
        if (character == '\n') {
            paragraphs += source.subSequence(start, index)
            start = index + 1
        }
    }
    paragraphs += source.subSequence(start, source.length)
    return paragraphs
}

internal sealed interface NewsArticleBlock {
    data class Text(val value: AnnotatedString) : NewsArticleBlock

    data class Preview(val linkID: String) : NewsArticleBlock
}

internal fun newsArticleBlocks(source: AnnotatedString): List<NewsArticleBlock> {
    val previews = source.getStringAnnotations(WEB_PREVIEW_BLOCK, 0, source.length)
    if (previews.isEmpty()) return listOf(NewsArticleBlock.Text(source))
    val blocks = mutableListOf<NewsArticleBlock>()
    var cursor = 0
    fun appendText(end: Int) {
        var start = cursor
        var trimmedEnd = end
        while (start < trimmedEnd && source.text[start].isWhitespace()) start++
        while (trimmedEnd > start && source.text[trimmedEnd - 1].isWhitespace()) trimmedEnd--
        if (start < trimmedEnd)
            blocks += NewsArticleBlock.Text(source.subSequence(start, trimmedEnd))
    }
    for (preview in previews.sortedBy { it.start }) {
        appendText(preview.start)
        blocks += NewsArticleBlock.Preview(preview.item)
        cursor = preview.end
    }
    appendText(source.length)
    return blocks
}

internal fun linkedNewsText(
    subtitle: AnnotatedString,
    content: AnnotatedString,
    artists: List<ProgramArtist>,
    linkStyles: TextLinkStyles,
    places: List<ProgramPlace> = emptyList(),
    placeName: (ProgramPlace) -> String = { it.names.values.firstOrNull().orEmpty() },
    onPlaceClick: (String) -> Unit = {},
    onArtistClick: (Long) -> Unit,
): NewsText {
    val texts =
        listOf(subtitle, content).map { source ->
            val builder = AnnotatedString.Builder(source)
            for (link in NewsTextLinks.find(source.text)) {
                if (
                    source.getLinkAnnotations(link.range.start, link.range.endExclusive).isEmpty()
                ) {
                    builder.addLink(
                        LinkAnnotation.Url(link.url, linkStyles),
                        link.range.start,
                        link.range.endExclusive,
                    )
                }
            }
            builder.toAnnotatedString()
        }
    val mentionLinkStyles =
        TextLinkStyles(
            style = linkStyles.style?.copy(textDecoration = null),
            focusedStyle = linkStyles.focusedStyle?.copy(textDecoration = null),
            hoveredStyle = linkStyles.hoveredStyle?.copy(textDecoration = null),
            pressedStyle = linkStyles.pressedStyle?.copy(textDecoration = null),
        )
    val mentions =
        ProgramMentions.inline(
            texts.map { it.text },
            artists,
            places,
            texts.map { text ->
                text.getLinkAnnotations(0, text.length).map { TextMentionRange(it.start, it.end) }
            },
            ::foldUnicodeText,
            placeName,
        )
    val inlineContent = mutableMapOf<String, ProgramInlineMention>()
    val linked = texts.mapIndexed { index, source ->
        val builder = AnnotatedString.Builder()
        var cursor = 0
        for (mention in mentions.filter { it.textIndex == index }) {
            if (cursor < mention.range.start)
                builder.append(source.subSequence(cursor, mention.range.start))
            val artist = mention.artist
            val place = mention.place
            val tag =
                if (artist != null) "artist:${artist.artistID}" else "place:${place!!.placeKey}"
            val start = builder.length
            if (artist != null || !place?.stageCode.isNullOrBlank()) {
                inlineContent[tag] = mention
                builder.appendInlineContent(tag, "\uFFFC")
                builder.append('\u2060')
            }
            val nameStart = builder.length
            builder.append(source.subSequence(mention.range.start, mention.range.endExclusive))
            builder.addStyle(
                SpanStyle(textDecoration = TextDecoration.Underline),
                nameStart,
                builder.length,
            )
            builder.addLink(
                LinkAnnotation.Clickable(tag, mentionLinkStyles) {
                    if (artist != null) onArtistClick(artist.artistID)
                    else if (place != null) onPlaceClick(place.placeKey)
                },
                start,
                builder.length,
            )
            cursor = mention.range.endExclusive
        }
        if (cursor < source.length) builder.append(source.subSequence(cursor, source.length))
        builder.toAnnotatedString()
    }
    val webLinks = mutableMapOf<String, NewsWebLink>()
    val chips = linked.mapIndexed { index, source ->
        val builder = AnnotatedString.Builder()
        var cursor = 0
        for (link in source.getLinkAnnotations(0, source.length).sortedBy { it.start }) {
            val url = (link.item as? LinkAnnotation.Url)?.url ?: continue
            val email = NewsMailLinks.address(url)
            val label =
                email
                    ?: NewsWebLinks.label(url, source.text.substring(link.start, link.end))
                    ?: continue
            if (link.start < cursor) continue
            if (cursor < link.start) builder.append(source.subSequence(cursor, link.start))
            val tag = "web:$index:${link.start}"
            webLinks[tag] = NewsWebLink(TextMentionRange(link.start, link.end), url, label, email)
            val start = builder.length
            builder.appendInlineContent(tag, label)
            if (email == null)
                builder.addStringAnnotation(WEB_PREVIEW_BLOCK, tag, start, builder.length)
            cursor = link.end
        }
        if (cursor < source.length) builder.append(source.subSequence(cursor, source.length))
        builder.toAnnotatedString()
    }
    return NewsText(chips[0], chips[1], inlineContent, webLinks)
}
