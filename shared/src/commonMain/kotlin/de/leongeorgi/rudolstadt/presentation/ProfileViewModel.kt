package de.leongeorgi.rudolstadt.presentation

import de.leongeorgi.rudolstadt.profile.*

data class ProfileState(
    val profile: PersonalProfile = PersonalProfile(),
    val changes: List<ProfileRecordChange> = emptyList(),
    val pending: Set<String> = emptySet(),
    val recommendationRevision: Long = 0,
) {
    val saved: Set<Long> = profile.savedEventIDs.toSet()
    val positiveArtistIDs: Set<Long> =
        profile.artistPreferences.filter { it.rating > 0 }.mapTo(mutableSetOf()) { it.artistID }
    val ratings: Map<String, Int> =
        profile.artistPreferences.associate { it.artistID.toString() to it.rating }
    val icons: Map<String, String> =
        profile.artistPreferences
            .mapNotNull { p -> p.iconName?.let { p.artistID.toString() to it } }
            .toMap()
    val notes: Map<String, String> =
        profile.artistNotes.associate { it.artistID.toString() to it.noteText }
}

class ProfileViewModel(
    private val savedEditable: Boolean,
    private val ratingsEditable: Boolean,
    private val notesEditable: Boolean,
    private val readOnly: Boolean,
) {
    private val cell = StateCell(ProfileState())
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (ProfileState) -> Unit) = cell.observe(observer)

    fun restore(
        profile: PersonalProfile,
        changes: List<ProfileRecordChange>,
        pending: Set<String>,
    ) {
        publish(profile, changes, pending)
    }

    fun syncChanges(previous: ProfileState) = ProfileSync.changes(previous.changes, current.changes)

    fun fullUpload() =
        ProfileRecords.fullUpload(current.profile, current.changes.map { it.key }.toSet())

    fun beginFullUpload(): List<ProfileSyncAction> {
        val plan = fullUpload()
        cell.set(current.copy(pending = current.pending + plan.map { it.key }))
        return plan
    }

    private var deliveredRecommendationRevision = 0L

    fun consumeRecommendationChange(): Boolean {
        val changed = current.recommendationRevision != deliveredRecommendationRevision
        deliveredRecommendationRevision = current.recommendationRevision
        return changed
    }

    fun isSaved(id: Long) = id in current.saved

    fun rating(id: Long) = current.ratings[id.toString()] ?: 0

    fun icon(id: Long) = current.icons[id.toString()]

    fun note(id: Long) = current.notes[id.toString()]

    fun permits(mutation: ProfileMutation, metadataAvailable: Boolean): Boolean =
        !readOnly &&
            when (mutation.kind) {
                "toggleSavedEvent" -> savedEditable
                "updateBadge" -> true
                "setArtistRating",
                "setArtistIcon" -> ratingsEditable && metadataAvailable
                "setArtistNote" -> notesEditable && metadataAvailable
                else -> false
            }

    fun mutate(
        mutation: ProfileMutation,
        metadataAvailable: Boolean,
        now: Double,
        changeID: String,
    ): Boolean {
        if (!permits(mutation, metadataAvailable)) return false
        val old = current
        val profile = ProfileReducer.apply(old.profile, mutation)
        if (profile == old.profile) return false
        val key =
            when (mutation.kind) {
                "toggleSavedEvent" -> "event:${mutation.id}"
                "setArtistRating",
                "setArtistIcon" -> "rating:${mutation.id}"
                "setArtistNote" -> "note:${mutation.id}"
                else -> "profile"
            }
        val changes = old.changes.associateBy { it.key }.toMutableMap()
        if (key != "profile") {
            val version =
                ProfileVersion(
                    kotlin.math.round(
                        maxOf(now, (changes[key]?.version?.modifiedAt ?: -1e15) + .001) * 1000
                    ) / 1000,
                    changeID,
                )
            changes[key] = ProfileRecordChange(key, value(profile, key), version)
        }
        publish(profile, changes.values.toList(), old.pending + key)
        return true
    }

    fun merge(change: ProfileRecordChange): Boolean {
        val old = current
        val local = old.changes.firstOrNull { it.key == change.key }
        val localWins = ProfileSync.localWins(local?.version, change.version)
        if (localWins) cell.set(old.copy(pending = old.pending + change.key))
        else
            publish(
                change.value.apply(old.profile),
                old.changes.filter { it.key != change.key } + change,
                old.pending - change.key,
            )
        return localWins
    }

    fun acknowledge(change: ProfileRecordChange) {
        if (current.changes.firstOrNull { it.key == change.key } == change)
            cell.set(current.copy(pending = current.pending - change.key))
    }

    fun uploadFailed(key: String) {
        cell.set(current.copy(pending = current.pending + key))
    }

    fun legacyDeleted(key: String): Boolean {
        val local = current.changes.firstOrNull { it.key == key } ?: return false
        if (ProfileSync.retainAfterLegacyDeletion(local.version, key in current.pending)) {
            uploadFailed(key)
            return true
        }
        val deleted =
            when (local.value.kind) {
                "event" -> local.value.copy(isSaved = false)
                "rating" -> local.value.copy(rating = 0, iconName = null)
                "note" -> local.value.copy(noteText = "")
                else -> return false
            }
        return merge(
            ProfileRecordChange(
                key,
                deleted,
                ProfileVersion(local.version.modifiedAt, "legacy:~deleted"),
            )
        )
    }

    private fun publish(
        profile: PersonalProfile,
        changes: List<ProfileRecordChange>,
        pending: Set<String>,
    ) {
        val old = current
        val inputsChanged =
            old.profile.savedEventIDs != profile.savedEventIDs ||
                old.profile.artistPreferences.associate { it.artistID to it.rating } !=
                    profile.artistPreferences.associate { it.artistID to it.rating }
        cell.set(
            ProfileState(
                profile,
                changes,
                pending,
                old.recommendationRevision + if (inputsChanged) 1 else 0,
            )
        )
    }

    private fun value(profile: PersonalProfile, key: String): ProfileRecordValue {
        val kind = key.substringBefore(':')
        val id = key.substringAfter(':').toLong()
        val preference = profile.artistPreferences.firstOrNull { it.artistID == id }
        return ProfileRecordValue(
            kind,
            id,
            id in profile.savedEventIDs,
            preference?.rating ?: 0,
            preference?.iconName,
            profile.artistNotes.firstOrNull { it.artistID == id }?.noteText.orEmpty(),
        )
    }
}

data class SyncState(
    val account: String = "checking",
    val accountReason: String? = null,
    val phase: String = "idle",
    val message: String? = null,
    val lastError: String? = null,
    val shared: Boolean = false,
    val preparingShare: Boolean = false,
    val participantCount: Int = 0,
    val refreshedAt: Double? = null,
    val failureGeneration: Long = 0,
) {
    val shouldWarn
        get() = account == "unavailable" || phase == "error" || lastError != null
}

class SyncViewModel {
    private val cell = StateCell(SyncState())
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (SyncState) -> Unit) = cell.observe(observer)

    fun account(status: String, reason: String?) {
        cell.set(current.copy(account = status, accountReason = reason))
    }

    fun sync(phase: String, message: String?, pending: Boolean) {
        if (phase == "error")
            cell.set(
                current.copy(
                    phase = phase,
                    message = message,
                    lastError = message,
                    failureGeneration = current.failureGeneration + 1,
                )
            )
        else if (phase == "idle" && current.lastError != null)
            cell.set(current.copy(phase = "error", message = current.lastError))
        else
            cell.set(
                current.copy(
                    phase = if (phase == "idle" && pending) "syncing" else phase,
                    message = message,
                )
            )
    }

    fun assign(phase: String, message: String?) {
        cell.set(current.copy(phase = phase, message = message))
    }

    fun confirmSuccess() {
        cell.set(current.copy(phase = "idle", message = null, lastError = null))
    }

    fun sharing(shared: Boolean, preparing: Boolean, participants: Int) {
        cell.set(
            current.copy(
                shared = shared,
                preparingShare = preparing,
                participantCount = participants,
            )
        )
    }

    fun refreshed(at: Double?) {
        cell.set(current.copy(refreshedAt = at))
    }
}

data class FriendProfileState(val profiles: List<SharedProfile> = emptyList())

class FriendsViewModel {
    private val cell = StateCell(FriendProfileState())
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (FriendProfileState) -> Unit) = cell.observe(observer)

    fun restore(profiles: List<SharedProfile>) {
        cell.set(FriendProfileState(profiles))
    }

    fun saving(eventID: Long) = current.profiles.filter { eventID in it.saved }

    fun rating(artistID: Long) =
        current.profiles.filter { p ->
            p.preferences.any { it.artistID == artistID && it.rating != 0 }
        }
}
