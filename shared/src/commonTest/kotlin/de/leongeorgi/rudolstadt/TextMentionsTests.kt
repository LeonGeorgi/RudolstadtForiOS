package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.discovery.TextMentionRange
import de.leongeorgi.rudolstadt.discovery.TextMentions
import kotlin.test.*

class TextMentionsTests {
    private fun ranges(text: String, candidate: String) =
        TextMentions.ranges(text, candidate) {
            it.lowercase()
                .replace("ñ", "n")
                .replace("ß", "ss")
                .replace("\u0303", "")
                .replace("\u0301", "")
        }

    @Test
    fun findsAllWholeNamesInOriginalAppearanceOrder() {
        val text = "SuperBand, Band2, 2Band, Band. (BAND)!"
        val matches = ranges(text, " Band ")
        assertEquals(
            listOf("Band", "BAND"),
            matches.map { text.substring(it.start, it.endExclusive) },
        )
        assertEquals(listOf(25, 32), matches.map { it.start })
    }

    @Test
    fun keepsUtf16OffsetsAfterEmojiAndLengthChangingFolds() {
        val text = "🎶 Straße: La Nin\u0303a! La Niña."
        assertEquals(
            listOf(TextMentionRange(11, 19), TextMentionRange(21, 28)),
            ranges(text, "La Nina"),
        )
    }

    @Test
    fun includesTrailingCombiningMarksInOriginalRange() {
        val text = "Nina\u0301 spielt."
        assertEquals(listOf(TextMentionRange(0, 5)), ranges(text, "Nina"))
    }

    @Test
    fun matchesFoldedExpansionOnlyAsAWholeSegment() {
        assertEquals(listOf(TextMentionRange(0, 1)), ranges("ß!", "SS"))
        assertTrue(ranges("ß!", "s").isEmpty())
    }

    @Test
    fun keepsPunctuationAndInternalWhitespaceSignificant() {
        assertTrue(ranges("Ramsch Rosen", "Ramsch & Rosen").isEmpty())
        assertTrue(ranges("A  B", "A B").isEmpty())
        assertEquals(listOf(TextMentionRange(1, 15)), ranges("(Ramsch & Rosen)", "Ramsch & Rosen"))
    }

    @Test
    fun respectsSupplementaryLetterBoundaries() {
        assertTrue(ranges("𐐀Band", "Band").isEmpty())
        assertTrue(ranges("Band𐐀", "Band").isEmpty())
        assertEquals(listOf(TextMentionRange(2, 6)), ranges("🎶Band🎶", "Band"))
    }

    @Test
    fun ignoresEmptyNamesAndMissingMatches() {
        assertTrue(ranges("Band", " \n ").isEmpty())
        assertTrue(ranges("", "Band").isEmpty())
        assertTrue(ranges("Band", "Other").isEmpty())
        assertTrue(TextMentions.ranges("Band", "Band") { "" }.isEmpty())
    }
}
