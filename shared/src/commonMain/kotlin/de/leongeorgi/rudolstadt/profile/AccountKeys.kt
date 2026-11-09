package de.leongeorgi.rudolstadt.profile

/** A 160-bit bearer credential. Entropy comes exclusively from each platform's secure RNG. */
object AccountKeys {
    private const val alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

    fun isStandaloneAccount(uid: String): Boolean = Regex("key_[A-Za-z0-9_-]{24}").matches(uid)

    fun fromEntropy(hex: String): String? {
        if (hex.length != 40 || hex.any { it.digitToIntOrNull(16) == null }) return null
        val bits = hex.map { it.digitToInt(16).toString(2).padStart(4, '0') }.joinToString("")
        return format(bits.chunked(5).map { alphabet[it.toInt(2)] }.joinToString(""))
    }

    fun normalize(value: String): String? {
        if (value.length > 128) return null
        val compact = value.filterNot { it == '-' || it.isWhitespace() }.uppercase()
        if (!compact.startsWith("FF1") || compact.length != 35) return null
        val secret = compact.drop(3)
        if (secret.any { it !in alphabet }) return null
        return format(secret)
    }

    private fun format(secret: String) = "FF1-" + secret.chunked(4).joinToString("-")
}
