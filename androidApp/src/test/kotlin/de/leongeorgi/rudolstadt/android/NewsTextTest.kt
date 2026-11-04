package de.leongeorgi.rudolstadt.android

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import de.leongeorgi.rudolstadt.festival.ProgramArtist
import de.leongeorgi.rudolstadt.festival.ProgramArtistDetails
import de.leongeorgi.rudolstadt.festival.ProgramContent
import de.leongeorgi.rudolstadt.festival.ProgramPlace
import org.junit.Assert.*
import org.junit.Test

class NewsTextTest {
    @Test
    fun mailBadgesRecognizePlainAndHtmlAddressesWithoutLinkingArtistNamesInsideThem() {
        val mailto = "mailto:band%2Blive%40example.com?subject=Festival"
        val source =
            AnnotatedString.Builder(
                    "Kontakt und music27@rudolstadt-festival.de. https://example.com/info@host.de"
                )
                .apply {
                    addLink(LinkAnnotation.Url(mailto), 0, 7)
                }
                .toAnnotatedString()
        val text =
            linkedNewsText(AnnotatedString(""), source, listOf(artist(1, "music27")), styles) {}
        val emails = text.webLinks.values.filter { it.emailAddress != null }
        assertEquals(
            listOf("band+live@example.com", "music27@rudolstadt-festival.de"),
            emails.map { it.label },
        )
        assertEquals(mailto, emails.first().url)
        assertEquals(3, text.webLinks.size)
        assertTrue(artistLinks(text.content).isEmpty())
        assertTrue(text.content.text.contains("music27@rudolstadt-festival.de."))
    }

    private val styles = TextLinkStyles()

    @Test
    fun selectableParagraphsKeepFormattingMailAnnotationsAndTheFinalBlankLine() {
        val source =
            AnnotatedString.Builder("Kontakt\nE-Mail\n")
                .apply {
                    addStyle(SpanStyle(fontWeight = FontWeight.Bold), 0, 7)
                    addLink(LinkAnnotation.Url("mailto:band@example.com"), 8, 14)
                    addStringAnnotation("inline-control", "mail-badge", 8, 14)
                }
                .toAnnotatedString()
        val paragraphs = newsTextParagraphs(source)
        assertEquals(listOf("Kontakt", "E-Mail", ""), paragraphs.map { it.text })
        assertEquals(FontWeight.Bold, paragraphs[0].spanStyles.single().item.fontWeight)
        assertEquals(
            "mailto:band@example.com",
            (paragraphs[1].getLinkAnnotations(0, 6).single().item as LinkAnnotation.Url).url,
        )
        assertEquals(
            "mail-badge",
            paragraphs[1].getStringAnnotations("inline-control", 0, 6).single().item,
        )
    }

    @Test
    fun previewBlocksPreserveSurroundingFormattingAndInlineArtistAndMailLinks() {
        val source =
            AnnotatedString.Builder(
                    "Band\n\nhttps://example.com/info\n\nKontakt: music27@example.com"
                )
                .apply { addStyle(SpanStyle(fontWeight = FontWeight.Bold), 0, 4) }
                .toAnnotatedString()
        val text = linkedNewsText(AnnotatedString(""), source, listOf(artist(1, "Band")), styles) {}
        val blocks = newsArticleBlocks(text.content)
        assertEquals(3, blocks.size)
        val first = (blocks[0] as NewsArticleBlock.Text).value
        assertEquals("Band", visible(first.text))
        assertEquals(FontWeight.Bold, first.spanStyles.first().item.fontWeight)
        assertEquals(1, artistLinks(first).size)
        val preview = blocks[1] as NewsArticleBlock.Preview
        assertEquals("https://example.com/info", text.webLinks.getValue(preview.linkID).url)
        val last = (blocks[2] as NewsArticleBlock.Text).value
        assertEquals("Kontakt: music27@example.com", last.text)
        assertEquals(1, newsArticleBlocks(last).size)
    }

    @Test
    fun adjacentPreviewsDoNotProduceBlankTextBlocks() {
        val text =
            linkedNewsText(
                AnnotatedString(""),
                AnnotatedString("https://example.com/one\n\nhttps://example.com/two"),
                emptyList(),
                styles,
            ) {}
        val blocks = newsArticleBlocks(text.content)
        assertEquals(2, blocks.size)
        assertEquals(
            listOf("https://example.com/one", "https://example.com/two"),
            blocks.map { text.webLinks.getValue((it as NewsArticleBlock.Preview).linkID).url },
        )
    }

    private fun visible(text: String) = text.replace("\uFFFC", "").replace("\u2060", "")

    private fun artist(id: Long, name: String) =
        ProgramArtist(id, name, false, ProgramArtistDetails(ProgramContent(emptyMap())))

    private fun artistLinks(text: AnnotatedString) =
        text.getLinkAnnotations(0, text.length).filter { it.item is LinkAnnotation.Clickable }

    @Test
    fun linksOnlyFirstMentionAndPrefersSubtitleWithArtistNavigation() {
        val clicked = mutableListOf<Long>()
        val text =
            linkedNewsText(
                AnnotatedString("Band, Band!"),
                AnnotatedString("Band spielt heute."),
                listOf(artist(42, "Band")),
                styles,
                onArtistClick = clicked::add,
            )
        val link = artistLinks(text.subtitle).single()
        assertEquals(0, link.start)
        assertEquals("Band", visible(text.subtitle.text.substring(link.start, link.end)))
        assertTrue(artistLinks(text.content).isEmpty())
        val annotation = link.item as LinkAnnotation.Clickable
        annotation.linkInteractionListener?.onClick(annotation)
        assertEquals(listOf(42L), clicked)
    }

    @Test
    fun findsOriginalBodyRangeAfterEmojiAndAcrossDecomposedAccents() {
        val body = "🎶 La Nin\u0303a und LA NIÑA!"
        val text =
            linkedNewsText(
                AnnotatedString("Heute im Programm"),
                AnnotatedString(body),
                listOf(artist(1, "La Niña")),
                styles,
            ) {}
        val link = artistLinks(text.content).single()
        assertEquals(3, link.start)
        assertEquals("La Nin\u0303a", visible(text.content.text.substring(link.start, link.end)))
        assertTrue(artistLinks(text.subtitle).isEmpty())
    }

    @Test
    fun longerNamesWinOverlapsAndShorterNameCanUseLaterMention() {
        val text =
            linkedNewsText(
                AnnotatedString(""),
                AnnotatedString("The Band trifft Band. The Band."),
                listOf(artist(1, "Band"), artist(2, "The Band")),
                styles,
            ) {}
        val links = artistLinks(text.content)
        assertEquals(
            listOf("The Band", "Band"),
            links.map { visible(text.content.text.substring(it.start, it.end)) },
        )
        assertEquals(
            listOf("artist:2", "artist:1"),
            links.map { (it.item as LinkAnnotation.Clickable).tag },
        )
    }

    @Test
    fun preservesExistingWebLinksAndFormattingWithoutOverlappingArtistLinks() {
        val original =
            AnnotatedString.Builder("Band und Band")
                .apply {
                    addLink(LinkAnnotation.Url("https://example.com", styles), 0, 4)
                    addStyle(SpanStyle(fontWeight = FontWeight.Bold), 4, 9)
                }
                .toAnnotatedString()
        val text =
            linkedNewsText(
                AnnotatedString(""),
                original,
                listOf(artist(1, "Band")),
                styles,
            ) {}
        val links = text.content.getLinkAnnotations(0, text.content.length)
        assertEquals(original.text, visible(text.content.text))
        assertTrue(text.content.spanStyles.containsAll(original.spanStyles))
        assertEquals("https://example.com", text.webLinks.values.single().url)
        assertEquals("Band", text.webLinks.values.single().label)
        assertEquals(1, links.size)
        assertEquals(9, artistLinks(text.content).single().start)
    }

    @Test
    fun respectsWholeNamesWhitespaceAndWidthFolding() {
        val text =
            linkedNewsText(
                AnnotatedString(""),
                AnnotatedString("SuperBand, ＢＡＮＤ und A B"),
                listOf(artist(1, "Band"), artist(2, "A B")),
                styles,
            ) {}
        val links = artistLinks(text.content)
        assertEquals(
            listOf("ＢＡＮＤ", "A B"),
            links.map { visible(text.content.text.substring(it.start, it.end)) },
        )
    }

    @Test
    fun stageNumbersAndNamesShareNavigationAndOnlyFirstMentionIsDecorated() {
        val stage = ProgramPlace("s:church", mapOf("de" to "Lutherkirche"), stageCode = "8")
        val clicked = mutableListOf<String>()
        val text =
            linkedNewsText(
                AnnotatedString("Lutherkirche"),
                AnnotatedString("Lutherkirche und Band."),
                listOf(artist(1, "Band")),
                styles,
                places = listOf(stage),
                onPlaceClick = { clicked += it },
                onArtistClick = {},
            )
        val link = text.subtitle.getLinkAnnotations(0, text.subtitle.length).single()
        val annotation = link.item as LinkAnnotation.Clickable
        assertEquals("place:s:church", annotation.tag)
        assertSame(stage, text.inlineContent[annotation.tag]?.place)
        annotation.linkInteractionListener?.onClick(annotation)
        assertEquals(listOf("s:church"), clicked)
        assertEquals("Lutherkirche", visible(text.subtitle.text))
        assertEquals(
            listOf("artist:1"),
            text.content.getLinkAnnotations(0, text.content.length).map {
                (it.item as LinkAnnotation.Clickable).tag
            },
        )
    }

    @Test
    fun rawAndHtmlUrlsBecomeShortChipsWithoutLosingTheirFullDestinations() {
        val url = "https://www.example.com/programme?language=de#tickets"
        val source =
            AnnotatedString.Builder("Mehr: $url, Programm und Band.")
                .apply {
                    val start = 8 + url.length
                    addLink(LinkAnnotation.Url(url), start, start + 8)
                }
                .toAnnotatedString()
        val text = linkedNewsText(AnnotatedString(""), source, listOf(artist(1, "Band")), styles) {}
        assertEquals(listOf(url, url), text.webLinks.values.map { it.url })
        assertEquals(listOf("example.com/…", "Programm"), text.webLinks.values.map { it.label })
        assertEquals("Mehr: example.com/…, Programm und Band.", visible(text.content.text))
        val link = artistLinks(text.content).single()
        assertEquals("Band", visible(text.content.text.substring(link.start, link.end)))
    }

    @Test
    fun underlinesNamesWhileImagesAndNumbersKeepTheSameLinkWithoutUnderline() {
        val text =
            linkedNewsText(
                AnnotatedString(""),
                AnnotatedString("Band und Lutherkirche"),
                listOf(artist(1, "Band")),
                TextLinkStyles(SpanStyle(textDecoration = TextDecoration.Underline)),
                places =
                    listOf(ProgramPlace("church", mapOf("de" to "Lutherkirche"), stageCode = "8")),
                onArtistClick = {},
            )
        val underlined =
            text.content.spanStyles.filter { it.item.textDecoration == TextDecoration.Underline }
        assertEquals(
            listOf("Band", "Lutherkirche"),
            underlined.map { text.content.text.substring(it.start, it.end) },
        )
        val links = artistLinks(text.content)
        assertEquals(2, links.size)
        links.forEachIndexed { index, link ->
            assertEquals('\uFFFC', text.content.text[link.start])
            assertEquals(underlined[index].end, link.end)
            assertNull((link.item as LinkAnnotation.Clickable).styles?.style?.textDecoration)
        }
    }

    @Test
    fun unnumberedPlaceStillLinksWithoutAnEmptyIcon() {
        val text =
            linkedNewsText(
                AnnotatedString(""),
                AnnotatedString("Park"),
                emptyList(),
                styles,
                places = listOf(ProgramPlace("park", mapOf("de" to "Park"))),
                onArtistClick = {},
            )
        assertEquals("Park", text.content.text)
        assertTrue(text.inlineContent.isEmpty())
        assertEquals(1, text.content.getLinkAnnotations(0, text.content.length).size)
    }
}
