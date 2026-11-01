package de.leongeorgi.rudolstadt.profile

import kotlinx.serialization.Serializable

@Serializable
data class ArtistPreference(val artistID: Long, val rating: Int, val iconName: String? = null)

@Serializable data class ArtistNote(val artistID: Long, val noteText: String)

@Serializable
data class PersonalProfile(
    val badgeName: String? = null,
    val badgeColorHex: String? = null,
    val savedEventIDs: List<Long> = emptyList(),
    val artistPreferences: List<ArtistPreference> = emptyList(),
    val artistNotes: List<ArtistNote> = emptyList(),
)

@Serializable
data class ProfileMutation(
    val kind: String,
    val id: Long = 0,
    val rating: Int = 0,
    val text: String = "",
    val color: String = "",
)

object ProfileReducer {
    fun normalize(profile: PersonalProfile): PersonalProfile =
        profile.copy(
            badgeName = normalizedName(profile.badgeName),
            badgeColorHex = resolvedColor(profile.badgeColorHex),
            savedEventIDs = profile.savedEventIDs.distinct().sorted(),
            artistPreferences =
                profile.artistPreferences
                    .associateBy { it.artistID }
                    .values
                    .sortedBy { it.artistID },
            artistNotes =
                profile.artistNotes.associateBy { it.artistID }.values.sortedBy { it.artistID },
        )

    fun apply(profile: PersonalProfile, mutation: ProfileMutation): PersonalProfile {
        val preferences = profile.artistPreferences.associateBy { it.artistID }.toMutableMap()
        val notes = profile.artistNotes.associateBy { it.artistID }.toMutableMap()
        val changed =
            when (mutation.kind) {
                "toggleSavedEvent" ->
                    profile.copy(
                        savedEventIDs =
                            profile.savedEventIDs
                                .toMutableSet()
                                .apply { if (!remove(mutation.id)) add(mutation.id) }
                                .toList()
                    )
                "updateBadge" ->
                    profile.copy(badgeName = mutation.text, badgeColorHex = mutation.color)
                "setArtistRating" -> {
                    if (mutation.rating == 0) preferences.remove(mutation.id)
                    else
                        preferences[mutation.id] =
                            ArtistPreference(
                                mutation.id,
                                mutation.rating,
                                if (mutation.rating > 0) null
                                else preferences[mutation.id]?.iconName,
                            )
                    profile.copy(artistPreferences = preferences.values.toList())
                }
                "setArtistIcon" ->
                    profile.copy(
                        artistPreferences =
                            (preferences +
                                    (mutation.id to
                                        ArtistPreference(mutation.id, -1, mutation.text)))
                                .values
                                .toList()
                    )
                "setArtistNote" -> {
                    val text = mutation.text.trim()
                    if (text.isEmpty()) notes.remove(mutation.id)
                    else notes[mutation.id] = ArtistNote(mutation.id, text)
                    profile.copy(artistNotes = notes.values.toList())
                }
                else -> error("Unknown profile mutation ${mutation.kind}")
            }
        return normalize(changed)
    }

    // Swift supplies grapheme-aware UI name truncation at its value boundary.
    fun normalizedName(value: String?): String? = value?.trim()?.takeIf { it.isNotEmpty() }

    fun resolvedColor(value: String?): String =
        value?.uppercase()?.takeIf { it in palette } ?: "#D75A3A"

    val palette =
        listOf(
            "#D75A3A",
            "#D49A1F",
            "#5E9F42",
            "#23867A",
            "#3D78E0",
            "#6B5AE0",
            "#B54E9B",
            "#8B5A3C",
        )
}

data class SharedProfile(
    val profileID: String,
    val title: String,
    val ownerName: String?,
    val badgeName: String?,
    val badgeColor: String?,
    val year: Int,
    val saved: List<Long>,
    val preferences: List<ArtistPreference>,
) {
    fun ordered() = copy(saved = saved.sorted(), preferences = preferences.sortedBy { it.artistID })
}
