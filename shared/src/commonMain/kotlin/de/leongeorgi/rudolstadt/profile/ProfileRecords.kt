package de.leongeorgi.rudolstadt.profile

data class ProfileRecordVersion(val key: String, val version: ProfileVersion)

/** Record identity, tombstones, historical values and upload plans are shared domain rules. */
object ProfileRecords {
    fun keys(profile: PersonalProfile, versionKeys: Set<String>): Set<String> =
        profile.savedEventIDs.map { "event:$it" }.toSet() +
            profile.artistPreferences.map { "rating:${it.artistID}" } +
            profile.artistNotes.map { "note:${it.artistID}" } +
            versionKeys.filter { value(profile, it) != null }

    fun value(profile: PersonalProfile, key: String): ProfileRecordValue? {
        val parts = key.split(':')
        if (parts.size != 2) return null
        val id = parts[1].toLongOrNull() ?: return null
        val preference = profile.artistPreferences.firstOrNull { it.artistID == id }
        return when (parts[0]) {
            "event" -> ProfileRecordValue("event", id, isSaved = id in profile.savedEventIDs)
            "rating" ->
                ProfileRecordValue(
                    "rating",
                    id,
                    rating = preference?.rating ?: 0,
                    iconName = preference?.iconName,
                )
            "note" ->
                ProfileRecordValue(
                    "note",
                    id,
                    noteText =
                        profile.artistNotes.firstOrNull { it.artistID == id }?.noteText.orEmpty(),
                )
            else -> null
        }
    }

    fun changes(
        profile: PersonalProfile,
        versions: List<ProfileRecordVersion>,
        legacyDate: Double,
        hash: (String) -> String,
    ): List<ProfileRecordChange> {
        val versionsByKey = versions.associate { it.key to it.version }
        return keys(profile, versionsByKey.keys).sorted().mapNotNull { key ->
            val value = value(profile, key) ?: return@mapNotNull null
            val version = versionsByKey[key]
            if (value.isDeleted && version == null) return@mapNotNull null
            ProfileRecordChange(
                key,
                value,
                version ?: ProfileVersion(legacyDate, "legacy:" + hash(value.legacyContent)),
            )
        }
    }

    fun fullUpload(profile: PersonalProfile, versionKeys: Set<String>): List<ProfileSyncAction> =
        listOf(ProfileSyncAction("profile")) +
            keys(profile, versionKeys).sorted().map { ProfileSyncAction(it) }

    fun applyShared(profile: SharedProfile, value: ProfileRecordValue): SharedProfile {
        if (value.kind == "note") return profile
        val result =
            value.apply(
                PersonalProfile(
                    savedEventIDs = profile.saved,
                    artistPreferences = profile.preferences,
                )
            )
        return profile.copy(saved = result.savedEventIDs, preferences = result.artistPreferences)
    }

    fun removeShared(profile: SharedProfile, key: String): SharedProfile {
        val value =
            value(
                PersonalProfile(
                    savedEventIDs = profile.saved,
                    artistPreferences = profile.preferences,
                ),
                key,
            ) ?: return profile
        return applyShared(
            profile,
            when (value.kind) {
                "event" -> value.copy(isSaved = false)
                "rating" -> value.copy(rating = 0, iconName = null)
                else -> value
            },
        )
    }
}
