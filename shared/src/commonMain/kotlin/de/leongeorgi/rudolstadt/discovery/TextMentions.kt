package de.leongeorgi.rudolstadt.discovery

/** UTF-16 offsets into the original, unmodified text; endExclusive is not part of the match. */
data class TextMentionRange(val start: Int, val endExclusive: Int)

object TextMentions {
    private val combiningMarks = Regex("\\p{M}+")
    private val alphanumeric = Regex("[\\p{L}\\p{N}]")

    /** Hosts fold case, diacritics and character width without trimming or removing punctuation. */
    fun ranges(text: String, candidate: String, fold: (String) -> String): List<TextMentionRange> {
        val name = fold(candidate.trim())
        if (name.isEmpty()) return emptyList()

        val folded = StringBuilder()
        val starts = mutableListOf<Int>()
        val ends = mutableListOf<Int>()
        var offset = 0
        while (offset < text.length) {
            var end = scalarEnd(text, offset)
            combiningMarks.matchAt(text, end)?.let { end = it.range.last + 1 }
            val segment = fold(text.substring(offset, end))
            folded.append(segment)
            repeat(segment.length) {
                starts += offset
                ends += end
            }
            offset = end
        }

        val searchable = folded.toString()
        val matches = mutableListOf<TextMentionRange>()
        var from = 0
        while (from < searchable.length) {
            val start = searchable.indexOf(name, from)
            if (start < 0) break
            val end = start + name.length
            val startsSegment = start == 0 || starts[start - 1] != starts[start]
            val endsSegment = end == searchable.length || ends[end - 1] != ends[end]
            val before =
                if (start == 0) ""
                else searchable.substring(scalarStartBefore(searchable, start), start)
            val after =
                if (end == searchable.length) ""
                else searchable.substring(end, scalarEnd(searchable, end))
            if (
                startsSegment &&
                    endsSegment &&
                    !alphanumeric.containsMatchIn(before) &&
                    !alphanumeric.containsMatchIn(after)
            ) {
                matches += TextMentionRange(starts[start], ends[end - 1])
            }
            from = end
        }
        return matches
    }

    private fun scalarEnd(text: String, start: Int): Int =
        start +
            if (
                text[start].isHighSurrogate() &&
                    start + 1 < text.length &&
                    text[start + 1].isLowSurrogate()
            )
                2
            else 1

    private fun scalarStartBefore(text: String, end: Int): Int =
        end -
            if (end > 1 && text[end - 1].isLowSurrogate() && text[end - 2].isHighSurrogate()) 2
            else 1
}
