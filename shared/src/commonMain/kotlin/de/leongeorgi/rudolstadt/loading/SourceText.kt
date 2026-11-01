package de.leongeorgi.rudolstadt.loading

/** Match Foundation's UTF-8 source decoding: accept a BOM, never replace invalid bytes. */
internal fun ByteArray.sourceText(): String =
    decodeToString(throwOnInvalidSequence = true).removePrefix("\uFEFF")
