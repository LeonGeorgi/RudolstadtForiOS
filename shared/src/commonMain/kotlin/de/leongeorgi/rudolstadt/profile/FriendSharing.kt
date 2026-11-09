package de.leongeorgi.rudolstadt.profile

import io.ktor.http.Url
import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class FriendPermissions(
    val savedEvents: Boolean = false,
    val ratings: Boolean = false,
    val notes: Boolean = false,
)

@Serializable data class FriendIdentity(val name: String, val hue: Double)

@Serializable
data class FriendshipRecord(
    val uid: String,
    val sharing: FriendPermissions = FriendPermissions(),
    val receiving: FriendPermissions = FriendPermissions(),
)

data class FriendConnection(
    val uid: String,
    val sharing: FriendPermissions,
    val receiving: FriendPermissions,
    val name: String? = null,
    val hue: Double = ProfileReducer.defaultHue,
    val notes: List<ArtistNote> = emptyList(),
)

/** Both categories are required for publication, including when a category is cleared. */
@Serializable
@OptIn(ExperimentalSerializationApi::class)
data class FriendShareProfile(
    @EncodeDefault
    val savedEventIDs: List<Long> = emptyList(),
    @EncodeDefault
    val artistPreferences: List<ArtistPreference> = emptyList(),
)

data class FriendInvite(val token: String) {
    val url
        get() = "https://festival.leongeorgi.de/rudolstadt/friends?v=2&token=$token"
}

object FriendSharing {
    val defaultPermissions = FriendPermissions(savedEvents = true, ratings = true, notes = false)

    private val json = Json { ignoreUnknownKeys = true }
    private val editionPattern = Regex("[a-z][a-z0-9-]{0,50}-[0-9]{4}")
    private val tokenPattern = Regex("[A-Za-z0-9_-]{43}")

    fun snapshot(profile: PersonalProfile): FriendShareProfile {
        val value = ProfileReducer.normalize(profile)
        return FriendShareProfile(value.savedEventIDs, value.artistPreferences)
    }

    fun encode(profile: PersonalProfile): String = json.encodeToString(snapshot(profile))

    fun memberships(value: String): List<FriendshipRecord> = json.decodeFromString(value)

    fun membership(value: String): FriendshipRecord = json.decodeFromString(value)

    fun identity(value: String): FriendIdentity = json.decodeFromString(value)

    fun data(value: String): FriendShareProfile = json.decodeFromString(value)

    fun notes(value: String): List<ArtistNote> =
        OwnProfileData.decodeRecords(value)
            .mapNotNull {
                it.value
                    ?.takeIf { value -> value.kind == "note" && value.noteText.isNotEmpty() }
                    ?.let { value -> ArtistNote(value.id, value.noteText) }
            }
            .sortedBy { it.artistID }

    fun profile(
        uid: String,
        edition: String,
        identity: FriendIdentity,
        saved: List<Long>,
        ratings: List<ArtistPreference>,
    ): SharedProfile {
        require(editionPattern.matches(edition))
        return SharedProfile(
                uid,
                identity.name,
                null,
                identity.name,
                identity.hue,
                edition.takeLast(4).toInt(),
                saved,
                ratings,
            )
            .ordered()
    }

    fun parseInvite(value: String): FriendInvite? {
        val url =
            try {
                Url(value)
            } catch (_: Exception) {
                return null
            }
        if (
            url.protocol.name != "https" ||
                url.host != "festival.leongeorgi.de" ||
                url.port != 443 ||
                !url.user.isNullOrEmpty() ||
                !url.password.isNullOrEmpty() ||
                url.encodedPath != "/rudolstadt/friends" ||
                url.fragment.isNotEmpty() ||
                url.parameters.names() != setOf("v", "token") ||
                url.parameters.getAll("v") != listOf("2")
        )
            return null
        val token = url.parameters.getAll("token")?.singleOrNull() ?: return null
        return if (tokenPattern.matches(token)) FriendInvite(token) else null
    }
}
