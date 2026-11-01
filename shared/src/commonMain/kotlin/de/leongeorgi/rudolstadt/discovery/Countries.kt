package de.leongeorgi.rudolstadt.discovery

class CountryParser(private val fold: (String) -> String) {
    fun parse(value: String, preservingUKNations: Boolean = false): List<String> {
        val clean = preprocess(value)
        if (clean.isEmpty()) return emptyList()
        if (preservingUKNations) {
            table("ukNationCodes")[normalize(clean)]?.let {
                return listOf(it)
            }
            if (clean.uppercase() in table("ukNamesEN")) return listOf(clean.uppercase())
        }
        code(clean)?.let {
            return listOf(it)
        }
        for (separator in listOf("/", ";", "|", "•", "·", "&", "+")) {
            val parts = clean.split(separator).map(::preprocess).filter(String::isNotEmpty)
            if (parts.size > 1) return parts.flatMap { parse(it, preservingUKNations) }
        }
        for (separator in listOf(",", " und ", " and ", " et ")) {
            val parts = clean.split(separator).map(::preprocess).filter(String::isNotEmpty)
            if (parts.size > 1) {
                val parsed = parts.flatMap { parse(it, preservingUKNations) }
                if (parsed.isNotEmpty()) return parsed
            }
        }
        return emptyList()
    }

    private fun code(value: String): String? {
        val candidate = Regex("[^A-Z]").replace(preprocess(value).uppercase(), "")
        if (candidate.length == 3) {
            if (candidate in table("isoA3ToA2")) return candidate
            table("alpha3Aliases")[candidate]?.let {
                return it
            }
        }
        val matched =
            table("lookup")[normalize(value)]
                ?: table("lookup")[normalize(strip(value))]
                ?: return null
        return table("isoA2ToA3")[matched] ?: matched
    }

    private fun normalize(value: String): String =
        fold(strip(value))
            .lowercase()
            .replace("&", " and ")
            .replace(Regex("[.'’]"), "")
            .replace(Regex("[^\\p{L}\\p{N}]+"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()

    private fun strip(value: String): String =
        preprocess(
            value
                .replace(Regex("\\(.*?\\)|\\[.*?\\]|\\{.*?\\}"), " ")
                .replace(Regex("^(aus|from|originating from)\\s+", RegexOption.IGNORE_CASE), "")
        )

    private fun preprocess(value: String): String =
        value
            .replace('\u00a0', ' ')
            .replace('–', '-')
            .replace('—', '-')
            .replace('／', '/')
            .replace('＆', '&')
            .trim()
            .replace(Regex("\\s+"), " ")

    companion object {
        fun table(name: String): Map<String, String> = CountryData.tables[name].orEmpty()

        fun alpha2(code: String): String? =
            code.uppercase().let {
                table("isoA3ToA2")[it] ?: it.takeIf { it in table("isoA2ToA3") }
            }

        fun flag(code: String): String? {
            val normalized = table("alpha3Aliases")[code.uppercase()] ?: code.uppercase()
            val alpha2 = alpha2(normalized) ?: return null
            return alpha2
                .map { 127397 + it.code }
                .joinToString("") { scalar ->
                    "${((scalar - 0x10000) / 1024 + 0xd800).toChar()}${((scalar - 0x10000) % 1024 + 0xdc00).toChar()}"
                }
        }
    }
}
