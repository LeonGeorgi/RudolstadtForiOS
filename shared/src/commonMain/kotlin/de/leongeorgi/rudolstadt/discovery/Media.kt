package de.leongeorgi.rudolstadt.discovery

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** Native URL libraries provide syntax/escaping; media interpretation is platform-independent. */
data class MediaParameter(val name: String, val value: String?)

data class MediaURLParts(
    val scheme: String?,
    val host: String?,
    val path: List<String>,
    val query: List<MediaParameter>,
)

enum class MusicKind {
    ARTIST,
    ALBUM,
    SONG,
}

data class MusicReference(val kind: MusicKind, val catalogID: Long, val storefront: String) {
    val lookupParameters
        get() =
            listOf(
                MediaParameter("id", catalogID.toString()),
                MediaParameter("entity", "song"),
                MediaParameter("limit", if (kind == MusicKind.ARTIST) "50" else "10"),
                MediaParameter("country", storefront.uppercase()),
            )
}

data class MusicPreviewSelection(
    val trackName: String,
    val artistName: String,
    val audioURL: String,
)

object MediaLinks {
    fun music(parts: MediaURLParts): MusicReference? {
        if (parts.scheme?.lowercase() != "https" || parts.host?.lowercase() != "music.apple.com")
            return null
        if (parts.path.size < 3) return null
        val kind =
            when (parts.path[1].lowercase()) {
                "artist" -> MusicKind.ARTIST
                "album" -> MusicKind.ALBUM
                "song" -> MusicKind.SONG
                else -> return null
            }
        val id = parts.path.last().toLongOrNull()?.takeIf { it > 0 } ?: return null
        val store = parts.path.first().lowercase().takeIf { it.isNotEmpty() } ?: return null
        val track =
            parts.query.firstOrNull { it.name == "i" }?.value?.toLongOrNull()?.takeIf { it > 0 }
        return if (kind == MusicKind.ALBUM && track != null)
            MusicReference(MusicKind.SONG, track, store)
        else MusicReference(kind, id, store)
    }

    fun previewReference(
        links: CuratedArtistLinks,
        parse: (String) -> MediaURLParts?,
    ): MusicReference? {
        val source =
            when (links.preview) {
                "disabled" -> return null
                "songURL" -> links.previewURL ?: links.appleMusicURL
                else -> links.appleMusicURL
            } ?: return null
        val reference = parse(source)?.let(::music) ?: return null
        return reference.takeIf {
            links.preview != "songURL" || links.previewURL == null || it.kind == MusicKind.SONG
        }
    }

    fun youtube(parts: MediaURLParts): String? {
        val host = parts.host?.lowercase() ?: return null
        if (host == "youtu.be" || host.endsWith(".youtu.be"))
            return sanitizedVideoID(parts.path.firstOrNull().orEmpty())
        if (!host.contains("youtube.com") && !host.contains("youtube-nocookie.com")) return null
        parts.query
            .firstOrNull { it.name == "v" }
            ?.value
            ?.let(::sanitizedVideoID)
            ?.let {
                return it
            }
        for (marker in listOf("embed", "shorts", "live", "v")) {
            val index = parts.path.indexOf(marker)
            if (index >= 0 && index + 1 < parts.path.size)
                return sanitizedVideoID(parts.path[index + 1])
        }
        return null
    }

    private fun sanitizedVideoID(value: String): String? =
        value
            .trim()
            .filter { it.isLetterOrDigit() || it == '-' || it == '_' }
            .takeIf { it.isNotEmpty() }

    fun youtubeThumbnail(id: String) = "https://i.ytimg.com/vi/$id/hqdefault.jpg"
}

object MusicPreviews {
    private val json = Json { ignoreUnknownKeys = true }

    @Throws(Exception::class)
    fun select(
        sourceJSON: String,
        reference: MusicReference,
        validURL: (String) -> Boolean,
    ): MusicPreviewSelection? {
        val results = json.decodeFromString<LookupResponse>(sourceJSON).results
        require(results.all { it.previewURL == null || validURL(it.previewURL) }) {
            "Invalid preview URL"
        }
        val result =
            results.firstOrNull {
                it.kind == "song" &&
                    it.trackName != null &&
                    it.artistName != null &&
                    it.previewURL != null &&
                    when (reference.kind) {
                        MusicKind.ARTIST -> it.artistID == reference.catalogID
                        MusicKind.ALBUM -> it.collectionID == reference.catalogID
                        MusicKind.SONG -> it.trackID == reference.catalogID
                    }
            } ?: return null
        return MusicPreviewSelection(result.trackName!!, result.artistName!!, result.previewURL!!)
    }

    @Serializable private data class LookupResponse(val results: List<LookupResult>)

    @Serializable
    private data class LookupResult(
        val kind: String? = null,
        @SerialName("artistId") val artistID: Long? = null,
        @SerialName("collectionId") val collectionID: Long? = null,
        @SerialName("trackId") val trackID: Long? = null,
        val artistName: String? = null,
        val trackName: String? = null,
        @SerialName("previewUrl") val previewURL: String? = null,
    )
}
