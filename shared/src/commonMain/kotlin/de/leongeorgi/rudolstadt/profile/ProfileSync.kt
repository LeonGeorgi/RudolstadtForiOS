package de.leongeorgi.rudolstadt.profile

import kotlinx.serialization.Serializable

@Serializable
data class ProfileRecordValue(
    val kind: String,
    val id: Long,
    val isSaved: Boolean = false,
    val rating: Int = 0,
    val iconName: String? = null,
    val noteText: String = "",
) {
    val key
        get() = "$kind:$id"

    val isDeleted
        get() =
            when (kind) {
                "event" -> !isSaved
                "rating" -> rating == 0
                "note" -> noteText.isEmpty()
                else -> false
            }

    val legacyContent
        get() =
            when (kind) {
                "event" -> "event:$isSaved"
                "rating" -> "rating:$rating:${iconName.orEmpty()}"
                "note" -> "note:$noteText"
                else -> error("Invalid profile record")
            }

    fun apply(profile: PersonalProfile): PersonalProfile =
        ProfileReducer.normalize(
            when (kind) {
                "event" ->
                    profile.copy(
                        savedEventIDs =
                            profile.savedEventIDs.filter { it != id } +
                                if (isSaved) listOf(id) else emptyList()
                    )
                "rating" ->
                    profile.copy(
                        artistPreferences =
                            profile.artistPreferences.filter { it.artistID != id } +
                                if (!isDeleted) listOf(ArtistPreference(id, rating, iconName))
                                else emptyList()
                    )
                "note" ->
                    profile.copy(
                        artistNotes =
                            profile.artistNotes.filter { it.artistID != id } +
                                if (!isDeleted) listOf(ArtistNote(id, noteText)) else emptyList()
                    )
                else -> error("Invalid profile record")
            }
        )
}

@Serializable
data class ProfileVersion(val modifiedAt: Double, val changeID: String) :
    Comparable<ProfileVersion> {
    override fun compareTo(other: ProfileVersion): Int =
        modifiedAt.compareTo(other.modifiedAt).takeIf { it != 0 }
            ?: changeID.compareTo(other.changeID)

    val isLegacy
        get() = changeID.startsWith("legacy:")
}

@Serializable
data class ProfileRecordChange(
    val key: String,
    val value: ProfileRecordValue,
    val version: ProfileVersion,
)

@Serializable data class ProfileSyncAction(val key: String, val delete: Boolean = false)

object ProfileSync {
    fun changes(
        old: List<ProfileRecordChange>,
        new: List<ProfileRecordChange>,
    ): List<ProfileSyncAction> {
        val oldByKey = old.associateBy { it.key }
        val newByKey = new.associateBy { it.key }
        return listOf(ProfileSyncAction("profile")) +
            (oldByKey.keys + newByKey.keys).sorted().mapNotNull { key ->
                if (oldByKey[key] == newByKey[key]) null
                else ProfileSyncAction(key, newByKey[key] == null)
            }
    }

    fun localWins(local: ProfileVersion?, remote: ProfileVersion): Boolean =
        local != null && local > remote

    fun retainAfterLegacyDeletion(version: ProfileVersion, pending: Boolean): Boolean =
        !version.isLegacy || pending
}
