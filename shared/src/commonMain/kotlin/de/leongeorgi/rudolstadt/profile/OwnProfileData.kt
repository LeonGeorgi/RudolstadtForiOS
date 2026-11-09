package de.leongeorgi.rudolstadt.profile

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class OwnProfileRecord(
    val key: String,
    val version: ProfileVersion,
    val value: ProfileRecordValue? = null,
    val badgeName: String? = null,
    val hue: Double = ProfileReducer.defaultHue,
) {
    val content: String
        get() = value?.legacyContent ?: "${badgeName.orEmpty()}\n${hue}"

    fun apply(profile: PersonalProfile): PersonalProfile =
        if (key == "profile")
            profile.copy(badgeName = badgeName, badgeHue = ProfileReducer.resolvedHue(hue))
        else requireNotNull(value).apply(profile)
}

@Serializable
data class OwnProfileReplica(
    val records: List<OwnProfileRecord> = emptyList(),
    val queued: List<OwnProfileRecord> = emptyList(),
    val initialUploadComplete: Boolean = true,
)

@Serializable
data class AccountDeletionRequest(val owner: String, val receipt: String) {
    override fun toString() = "AccountDeletionRequest(redacted)"
}

@Serializable
data class OwnProfileJournal(
    val schema: Int = 1,
    val edition: String,
    val activeOwner: String? = null,
    val legacyOwner: String? = null,
    val anonymous: OwnProfileReplica = OwnProfileReplica(),
    val accounts: Map<String, OwnProfileReplica> = emptyMap(),
    // Immutable source versions survive both conflict resolution and account switching.
    val legacyBackup: List<OwnProfileRecord> = emptyList(),
    val pendingDeletion: AccountDeletionRequest? = null,
    val detachedOwners: List<String> = emptyList(),
) {
    fun replica(owner: String? = activeOwner): OwnProfileReplica =
        if (owner == null) anonymous else accounts[owner] ?: OwnProfileReplica()

    fun replacing(owner: String?, replica: OwnProfileReplica): OwnProfileJournal =
        if (owner == null) copy(anonymous = replica)
        else copy(accounts = accounts + (owner to replica))
}

@Serializable
data class OwnProfileLegacy(
    val profile: PersonalProfile,
    val changes: List<ProfileRecordChange> = emptyList(),
)

@Serializable
data class OwnProfileLocal(val journal: OwnProfileJournal? = null, val legacy: OwnProfileLegacy)

/** Per-value merge rules shared by the native platforms. Missing records never imply deletion. */
object OwnProfileData {
    private val json = Json {
        encodeDefaults = true
        ignoreUnknownKeys = true
    }

    fun encodeProfile(profile: PersonalProfile): String = json.encodeToString(profile)

    @Throws(Exception::class)
    fun encodeLocal(
        journal: String?,
        profile: PersonalProfile,
        changes: List<ProfileRecordChange>,
    ): String =
        json.encodeToString(
            OwnProfileLocal(journal?.let { decodeJournal(it) }, OwnProfileLegacy(profile, changes))
        )

    fun decodeLocal(value: String): OwnProfileLocal = json.decodeFromString(value)

    fun encodeJournal(value: OwnProfileJournal): String = json.encodeToString(value)

    fun decodeJournal(value: String): OwnProfileJournal =
        json.decodeFromString<OwnProfileJournal>(value).also { require(it.schema == 1) }

    fun encodeRecords(value: List<OwnProfileRecord>): String = json.encodeToString(value)

    fun decodeRecords(value: String): List<OwnProfileRecord> = json.decodeFromString(value)

    fun record(change: ProfileRecordChange): OwnProfileRecord =
        OwnProfileRecord(change.key, change.version, change.value)

    fun badge(name: String?, hue: Double?, version: ProfileVersion): OwnProfileRecord =
        OwnProfileRecord(
            "profile",
            version,
            badgeName = ProfileReducer.normalizedName(name),
            hue = ProfileReducer.resolvedHue(hue),
        )

    fun legacy(value: OwnProfileLegacy): List<OwnProfileRecord> {
        val normalized = ProfileReducer.normalize(value.profile)
        val changes =
            ProfileRecords.changes(
                normalized,
                value.changes.map { ProfileRecordVersion(it.key, it.version) },
                0.0,
                ::hash,
            )
        val badge =
            if (normalized.badgeName != null || normalized.badgeHue != ProfileReducer.defaultHue)
                listOf(
                    badge(
                        normalized.badgeName,
                        normalized.badgeHue,
                        ProfileVersion(
                            0.0,
                            "legacy:" + hash("${normalized.badgeName}\n${normalized.badgeHue}"),
                        ),
                    )
                )
            else emptyList()
        return changes.map(::record) + badge
    }

    fun profile(records: List<OwnProfileRecord>): PersonalProfile =
        ProfileReducer.normalize(
            records.fold(PersonalProfile()) { profile, record -> record.apply(profile) }
        )

    fun merge(
        local: List<OwnProfileRecord>,
        incoming: List<OwnProfileRecord>,
    ): List<OwnProfileRecord> {
        val values = local.associateBy { it.key }.toMutableMap()
        for (record in incoming) {
            val previous = values[record.key]
            if (previous == null || compare(record, previous) > 0) values[record.key] = record
        }
        return values.values.sortedBy { it.key }
    }

    fun compare(a: OwnProfileRecord, b: OwnProfileRecord): Int =
        a.version.compareTo(b.version).takeIf { it != 0 }
            ?: if (a.key == "profile" && b.key == "profile") {
                a.badgeName.orEmpty().compareTo(b.badgeName.orEmpty()).takeIf { it != 0 }
                    ?: ProfileReducer.resolvedHue(a.hue)
                        .compareTo(ProfileReducer.resolvedHue(b.hue))
            } else a.content.compareTo(b.content)

    fun enqueue(
        existing: List<OwnProfileRecord>,
        incoming: List<OwnProfileRecord>,
    ): List<OwnProfileRecord> {
        var queued = existing
        for (record in incoming) {
            // Every private note version reaches the owner's history, even if it loses a merge.
            queued =
                if (record.value?.kind == "note") (queued + record).distinct()
                else
                    queued.filter { it.key != record.key } +
                        merge(queued.filter { it.key == record.key }, listOf(record)).single()
        }
        return queued
    }

    fun changed(
        profile: PersonalProfile,
        mutation: ProfileMutation,
        version: ProfileVersion,
    ): OwnProfileRecord {
        val key =
            when (mutation.kind) {
                "toggleSavedEvent" -> "event:${mutation.id}"
                "setArtistRating",
                "setArtistIcon" -> "rating:${mutation.id}"
                "setArtistNote" -> "note:${mutation.id}"
                "updateBadge" -> "profile"
                else -> error("Invalid profile mutation")
            }
        return if (key == "profile") badge(profile.badgeName, profile.badgeHue, version)
        else OwnProfileRecord(key, version, requireNotNull(ProfileRecords.value(profile, key)))
    }

    // This is a deterministic legacy identity, not a secret or an authentication hash.
    private fun hash(value: String): String =
        value
            .encodeToByteArray()
            .fold(14695981039346656037uL) { hash, byte ->
                (hash xor byte.toUByte().toULong()) * 1099511628211uL
            }
            .toString(16)
}
