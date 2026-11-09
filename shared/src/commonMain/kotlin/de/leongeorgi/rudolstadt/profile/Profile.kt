package de.leongeorgi.rudolstadt.profile

import kotlinx.serialization.Serializable

@Serializable
data class ArtistPreference(val artistID: Long, val rating: Int, val iconName: String? = null)

@Serializable data class ArtistNote(val artistID: Long, val noteText: String)

@Serializable
data class PersonalProfile(
    val badgeName: String? = null,
    val badgeHue: Double = ProfileReducer.defaultHue,
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
    val hue: Double = ProfileReducer.defaultHue,
)

object ProfileReducer {
    fun normalize(profile: PersonalProfile): PersonalProfile =
        profile.copy(
            badgeName = normalizedName(profile.badgeName),
            badgeHue = resolvedHue(profile.badgeHue),
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
                    profile.copy(badgeName = mutation.text, badgeHue = resolvedHue(mutation.hue))
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

    const val defaultHue = 30.0

    fun resolvedHue(value: Double?): Double {
        if (value == null || !value.isFinite()) return defaultHue
        return ((value % 360.0) + 360.0) % 360.0
    }
}

data class SharedProfile(
    val profileID: String,
    val title: String,
    val ownerName: String?,
    val badgeName: String?,
    val badgeHue: Double,
    val year: Int,
    val saved: List<Long>,
    val preferences: List<ArtistPreference>,
) {
    fun ordered() = copy(saved = saved.sorted(), preferences = preferences.sortedBy { it.artistID })
}
