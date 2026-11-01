package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.discovery.NewsMailLinks
import de.leongeorgi.rudolstadt.discovery.NewsTextLinks
import de.leongeorgi.rudolstadt.discovery.NewsWebLinks
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class NewsWebLinksTests {
    @Test
    fun nestedDestinationsStayPartOfTheOuterLink() {
        val text =
            "https://example.com/info@example.org mailto:live@example.com?body=https://example.com"
        val links = NewsTextLinks.find(text)
        assertEquals(2, links.size)
        assertNull(links[0].emailAddress)
        assertEquals("live@example.com", links[1].emailAddress)
        assertEquals("mailto:live@example.com?body=https://example.com", links[1].url)
    }

    @Test
    fun emailBadgesKeepRecipientsAndCompositionParametersSeparate() {
        val text =
            "🎵 music27@rudolstadt-festival.de, mailto:band%2Blive%40example.com?subject=Festival&body=Hallo."
        val links = NewsMailLinks.find(text)
        assertEquals(
            listOf("music27@rudolstadt-festival.de", "band+live@example.com"),
            links.map { it.emailAddress },
        )
        assertEquals("mailto:music27@rudolstadt-festival.de", links[0].url)
        assertEquals("mailto:band%2Blive%40example.com?subject=Festival&body=Hallo", links[1].url)
        assertEquals(
            "music27@rudolstadt-festival.de",
            text.substring(links[0].range.start, links[0].range.endExclusive),
        )
        assertNull(NewsMailLinks.address("https://example.com/a@b.de"))
        assertNull(NewsMailLinks.address("mailto:not-an-email"))
        assertNull(NewsMailLinks.address("mailto:one%0Atwo@example.com"))
    }

    @Test
    fun shortLabelsKeepTheDestinationAndHideQueryAndFragment() {
        val url = "https://www.example.com/news/full-story?language=de#tickets"
        val link = NewsWebLinks.find("Mehr: $url.").single()
        assertEquals(url, link.url)
        assertEquals("example.com/…", link.label)
        assertEquals(url, "Mehr: $url.".substring(link.range.start, link.range.endExclusive))
        assertEquals("Programm", NewsWebLinks.label(url, "Programm"))
        assertEquals("example.com", NewsWebLinks.label("https://www.example.com/?tracking=1"))
        assertNull(NewsWebLinks.label("mailto:info@example.com"))
        assertNull(NewsWebLinks.label("rudolstadt://artist/42"))
        assertNull(NewsWebLinks.label("https://example.com:invalid/path"))
    }

    @Test
    fun detectsWwwAndKeepsBalancedParenthesesButExcludesSentencePunctuation() {
        val text = "(https://example.com/story_(live)), www.example.com."
        val links = NewsWebLinks.find(text)
        assertEquals(
            listOf("https://example.com/story_(live)", "https://www.example.com"),
            links.map { it.url },
        )
        assertEquals(listOf("example.com/…", "example.com"), links.map { it.label })
    }
}
