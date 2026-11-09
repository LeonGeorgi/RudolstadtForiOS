package de.leongeorgi.rudolstadt.profile

import de.leongeorgi.rudolstadt.presentation.StateCell
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.math.round
import kotlin.time.Clock
import kotlin.uuid.Uuid
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.*

enum class OwnProfileProblem {
    LOCAL_STORAGE,
    CONNECTION,
}

enum class OwnProfilePhase {
    LOADING,
    LOCAL,
    CONNECTING,
    MIGRATING,
    SYNCING,
    READY,
    ERROR,
}

data class OwnProfileSyncState(
    val initialized: Boolean = false,
    val uid: String? = null,
    val profile: PersonalProfile = PersonalProfile(),
    val phase: OwnProfilePhase = OwnProfilePhase.LOADING,
    val problem: OwnProfileProblem? = null,
    val pendingCount: Int = 0,
    val migrationComplete: Boolean = false,
    val lastSyncedAt: Double? = null,
    val deletingAccount: Boolean = false,
)

/** Durable, account-scoped replicas. Only a persisted queue is allowed to reach Firebase. */
class OwnProfileController
internal constructor(
    private val edition: String,
    private val transport: OwnProfileTransport,
    private val scope: CoroutineScope,
    private val now: () -> Double,
    private val changeID: () -> String,
    private val sendDelayMillis: Long = 600,
    private val archiveSharing: Boolean = false,
) {
    constructor(
        edition: String,
        transport: OwnProfileTransport,
    ) : this(edition, transport, false)

    constructor(
        edition: String,
        transport: OwnProfileTransport,
        archiveSharing: Boolean,
    ) : this(
        edition,
        transport,
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
        { Clock.System.now().toEpochMilliseconds() / 1000.0 },
        { Uuid.random().toString() },
        archiveSharing = archiveSharing,
    )

    private val cell = StateCell(OwnProfileSyncState())
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (OwnProfileSyncState) -> Unit) = cell.observe(observer)

    private val storage = Mutex()
    private var journal: OwnProfileJournal? = null
    private var durable = false
    private var closed = false
    private var generation = 0
    private var requestedOwner: String? = null
    private var accountKnown = false
    private var account: FriendsSubscription? = null
    private var records: FriendsSubscription? = null
    private var sending: Job? = null
    private var settling: Job? = null
    private var serverSeen = false
    private var archiveSeed: Job? = null
    private var archiveSeedSeen = false
    private var reconnect: Job? = null
    private var reconnectDelay = 1000L
    private var delayedSend: Job? = null
    private var editsBeforeLoad = mutableListOf<ProfileMutation>()

    init {
        account = transport.observeAccount { uid -> scope.launch { accountChanged(uid) } }
        scope.launch { load() }
    }

    private suspend fun load() {
        try {
            storage.withLock {
                val local = OwnProfileData.decodeLocal(awaitResult { transport.loadLocal(it) })
                val source = OwnProfileData.legacy(local.legacy)
                val loaded =
                    local.journal?.also { require(it.schema == 1 && it.edition == edition) }
                        ?: OwnProfileJournal(
                            edition = edition,
                            anonymous =
                                OwnProfileReplica(
                                    records = source,
                                    queued = if (archiveSharing) emptyList() else source,
                                ),
                            legacyBackup = source,
                        )
                journal = loaded
                for (mutation in editsBeforeLoad) applyMutation(loaded.activeOwner, mutation)
                editsBeforeLoad.clear()
                save(requireNotNull(journal))
            }
            if (loadedDeletion()) emit(OwnProfilePhase.LOCAL, null)
            else if (accountKnown) switchAccount(requestedOwner)
        } catch (_: CancellationException) {} catch (_: Exception) {
            fail(OwnProfileProblem.LOCAL_STORAGE)
        }
    }

    private suspend fun accountChanged(owner: String?) {
        if (closed || (accountKnown && requestedOwner == owner)) return
        accountKnown = true
        requestedOwner = owner
        generation++
        stopNetwork()
        if (journal != null && !loadedDeletion()) switchAccount(owner)
    }

    private fun loadedDeletion() = journal?.pendingDeletion != null

    internal val pendingDeletion
        get() = journal?.pendingDeletion

    internal suspend fun prepareAccountDeletion(request: AccountDeletionRequest) {
        check(!closed && journal != null)
        generation++
        stopNetwork()
        storage.withLock {
            val before = requireNotNull(journal)
            check(before.pendingDeletion == null || before.pendingDeletion == request)
            check(before.activeOwner == request.owner)
            save(before.copy(pendingDeletion = request))
            emit(OwnProfilePhase.LOCAL, null)
        }
    }

    internal suspend fun finishAccountDeletion(owner: String) {
        generation++
        stopNetwork()
        storage.withLock {
            val before = requireNotNull(journal)
            val replica = before.replica(owner)
            // Preserve every current value and pending edit, including private notes.
            // Keep them local; a later, explicitly chosen first account can import them.
            val local =
                replica.copy(
                    queued =
                        if (archiveSharing) replica.queued
                        else OwnProfileData.enqueue(replica.records, replica.queued),
                    initialUploadComplete = true,
                )
            try {
                save(
                    before.copy(
                        activeOwner = null,
                        legacyOwner =
                            if (requestedOwner != null && requestedOwner != owner) owner else null,
                        anonymous = local,
                        accounts = before.accounts - owner,
                        pendingDeletion = null,
                        detachedOwners = (before.detachedOwners + owner).distinct(),
                    )
                )
            } catch (error: Exception) {
                journal = before
                emit(OwnProfilePhase.ERROR, OwnProfileProblem.LOCAL_STORAGE)
                throw error
            }
            emit(OwnProfilePhase.LOCAL, null)
        }
        if (requestedOwner != null && requestedOwner != owner) switchAccount(requestedOwner)
    }

    private suspend fun switchAccount(owner: String?) {
        if (owner != null && owner in requireNotNull(journal).detachedOwners) {
            emit(OwnProfilePhase.LOCAL, null)
            return
        }
        val expected = generation
        try {
            val previousOwner = journal?.activeOwner
            if (owner == null && previousOwner != null && !loadedDeletion()) {
                val deleted =
                    awaitResult<Boolean> { done ->
                        transport.checkAccountDeleted(previousOwner) { done(it, null) }
                    }
                if (generation != expected || requestedOwner != owner) return
                if (deleted) {
                    finishAccountDeletion(previousOwner)
                    return
                }
            }
            storage.withLock {
                if (requestedOwner != owner || generation != expected) return
                var next = requireNotNull(journal)
                if (owner != null && next.legacyOwner == null) {
                    next =
                        next.copy(
                            legacyOwner = owner,
                            accounts =
                                next.accounts +
                                    (owner to next.anonymous.copy(initialUploadComplete = false)),
                        )
                } else if (
                    owner != null && next.legacyOwner == owner && next.anonymous.queued.isNotEmpty()
                ) {
                    val replica = next.replica(owner)
                    next =
                        next.replacing(
                            owner,
                            replica.copy(
                                records =
                                    OwnProfileData.merge(replica.records, next.anonymous.queued),
                                queued =
                                    OwnProfileData.enqueue(replica.queued, next.anonymous.queued),
                            ),
                        )
                }
                if (owner != null && owner == next.legacyOwner)
                    next = next.copy(anonymous = next.anonymous.copy(queued = emptyList()))
                save(next.copy(activeOwner = owner))
            }
            if (!isCurrent(owner, expected)) return
            if (owner == null) emit(OwnProfilePhase.LOCAL, null) else startSession(owner, expected)
        } catch (_: CancellationException) {} catch (_: Exception) {
            fail(OwnProfileProblem.LOCAL_STORAGE)
        }
    }

    fun mutate(mutation: ProfileMutation) {
        if (closed) return
        val owner = journal?.activeOwner
        if (journal == null) {
            editsBeforeLoad += mutation
            return
        }
        scope.launch {
            try {
                storage.withLock {
                    val retainedOwner = owner.takeUnless {
                        it in requireNotNull(journal).detachedOwners
                    }
                    applyMutation(retainedOwner, mutation)
                    save(requireNotNull(journal))
                }
                scheduleSend()
            } catch (_: CancellationException) {} catch (_: Exception) {
                fail(OwnProfileProblem.LOCAL_STORAGE)
            }
        }
    }

    private fun applyMutation(owner: String?, mutation: ProfileMutation) {
        val before = requireNotNull(journal)
        val replica = before.replica(owner)
        val previous = OwnProfileData.profile(replica.records)
        val profile = ProfileReducer.apply(previous, mutation)
        if (profile == previous) return
        val provisional = OwnProfileData.changed(profile, mutation, ProfileVersion(0.0, ""))
        val previousDate =
            replica.records.firstOrNull { it.key == provisional.key }?.version?.modifiedAt ?: 0.0
        val version =
            ProfileVersion(round(maxOf(now(), previousDate + .001) * 1000) / 1000, changeID())
        val record = provisional.copy(version = version)
        val queued =
            if (record.value?.kind == "note")
                replica.queued.filter { it.key != record.key || it in before.legacyBackup } + record
            else OwnProfileData.enqueue(replica.queued, listOf(record))
        journal =
            before.replacing(
                owner,
                replica.copy(
                    records = OwnProfileData.merge(replica.records, listOf(record)),
                    queued = queued.distinct(),
                ),
            )
    }

    private fun scheduleSend() {
        delayedSend?.cancel()
        delayedSend = scope.launch {
            delay(sendDelayMillis)
            delayedSend = null
            kick()
        }
    }

    /** Native persistence must save the journal and the projected profile together. */
    private suspend fun save(next: OwnProfileJournal) {
        journal = next
        durable = false
        emit()
        awaitResult<Unit> { done ->
            transport.saveLocal(
                OwnProfileData.encodeJournal(next),
                OwnProfileData.encodeProfile(OwnProfileData.profile(next.replica().records)),
            ) {
                done(Unit, it)
            }
        }
        durable = true
        emit()
    }

    private fun startSession(owner: String, expected: Int) {
        serverSeen = false
        emit(
            if (requireNotNull(journal).replica(owner).initialUploadComplete)
                OwnProfilePhase.CONNECTING
            else OwnProfilePhase.MIGRATING,
            null,
        )
        records =
            transport.observeRecords(edition, owner) { payload, fromServer, error ->
                scope.launch {
                    if (!isCurrent(owner, expected)) return@launch
                    if (error != null || payload == null) {
                        if (error == FriendsTransportError.PERMISSION_DENIED) {
                            val deleted =
                                awaitResult<Boolean> { done ->
                                    transport.checkAccountDeleted(owner) { done(it, null) }
                                }
                            if (!isCurrent(owner, expected)) return@launch
                            if (deleted) {
                                finishAccountDeletion(owner)
                                transport.signOutDeletedAccount(owner) {}
                                return@launch
                            }
                        }
                        fail(OwnProfileProblem.CONNECTION)
                        return@launch
                    }
                    try {
                        val incoming = OwnProfileData.decodeRecords(payload)
                        storage.withLock {
                            if (!isCurrent(owner, expected)) return@withLock
                            val before = requireNotNull(journal)
                            val replica = before.replica(owner)
                            val merged = OwnProfileData.merge(replica.records, incoming)
                            if (merged != replica.records)
                                save(before.replacing(owner, replica.copy(records = merged)))
                            if (fromServer) serverSeen = true
                        }
                        kick()
                    } catch (_: CancellationException) {} catch (_: Exception) {
                        fail(OwnProfileProblem.LOCAL_STORAGE)
                    }
                }
            }
        if (archiveSharing) loadArchiveSeed(owner, expected)
        kick()
    }

    private fun loadArchiveSeed(owner: String, expected: Int) {
        archiveSeed = scope.launch {
            try {
                val incoming = syncRecords(owner, emptyList())
                storage.withLock {
                    if (!isCurrent(owner, expected)) return@withLock
                    val before = requireNotNull(journal)
                    val replica = before.replica(owner)
                    val authoritative =
                        replica.records.filterNot {
                            it.version.changeID == "archive-shared-fallback"
                        }
                    val merged = OwnProfileData.merge(authoritative, incoming)
                    if (merged != replica.records)
                        save(before.replacing(owner, replica.copy(records = merged)))
                    archiveSeedSeen = true
                }
                kick()
            } catch (_: CancellationException) {} catch (_: Exception) {
                if (isCurrent(owner, expected))
                    fail(
                        if (durable) OwnProfileProblem.CONNECTION
                        else OwnProfileProblem.LOCAL_STORAGE
                    )
            }
        }
    }

    private suspend fun syncRecords(owner: String, batch: List<OwnProfileRecord>): List<OwnProfileRecord> {
        val payload = buildJsonObject {
            put("edition", edition)
            put("owner", owner)
            put("records", Json.parseToJsonElement(OwnProfileData.encodeRecords(batch)))
            if (archiveSharing) put("archiveSharing", true)
        }
        val response = awaitResult<String> { transport.syncRecords(payload.toString(), it) }
        val data = Json.parseToJsonElement(response).jsonObject
        if (archiveSharing) check(data["archiveSharing"]?.jsonPrimitive?.boolean == true)
        return OwnProfileData.decodeRecords(data.getValue("records").toString())
    }

    private fun kick() {
        // A listener may confirm a committed write whose response was lost. Wait for the
        // scheduled retry rather than immediately resending the still-pending queue.
        if (current.problem != null || loadedDeletion()) return
        val value = journal ?: return
        val owner = value.activeOwner ?: return
        if (!isCurrent(owner, generation) || !durable || !serverSeen ||
            (archiveSharing && !archiveSeedSeen)
        ) return
        if (value.replica(owner).initialUploadComplete && delayedSend?.isActive == true) return
        if (value.replica(owner).queued.isEmpty()) {
            if (value.replica(owner).initialUploadComplete) {
                reconnectDelay = 1000
                emit(OwnProfilePhase.READY, null)
            } else if (settling?.isActive != true) {
                val expected = generation
                settling = scope.launch {
                    try {
                        settle(owner, expected)
                    } catch (_: CancellationException) {} catch (_: Exception) {
                        if (isCurrent(owner, expected)) fail(OwnProfileProblem.LOCAL_STORAGE)
                    }
                }
            }
            return
        }
        if (sending?.isActive == true) return
        val expected = generation
        sending = scope.launch {
            try {
                while (isCurrent(owner, expected)) {
                    val batch = storage.withLock {
                        if (!durable) return@withLock emptyList()
                        batch(requireNotNull(journal).replica(owner).queued)
                    }
                    if (batch.isEmpty()) break
                    emit(OwnProfilePhase.SYNCING, null)
                    val acknowledged = syncRecords(owner, batch)
                    if (!isCurrent(owner, expected)) return@launch
                    storage.withLock {
                        if (!isCurrent(owner, expected)) return@withLock
                        val before = requireNotNull(journal)
                        val replica = before.replica(owner)
                        save(
                            before.replacing(
                                owner,
                                replica.copy(
                                    records = OwnProfileData.merge(replica.records, acknowledged),
                                    queued = replica.queued.filter { it !in batch },
                                ),
                            )
                        )
                    }
                    cell.set(current.copy(lastSyncedAt = now()))
                }
                if (isCurrent(owner, expected) && durable) {
                    settle(owner, expected)
                }
            } catch (_: CancellationException) {} catch (_: Exception) {
                if (isCurrent(owner, expected))
                    fail(
                        if (durable) OwnProfileProblem.CONNECTION
                        else OwnProfileProblem.LOCAL_STORAGE
                    )
            }
        }
    }

    private suspend fun settle(owner: String, expected: Int) {
        storage.withLock {
            if (!isCurrent(owner, expected) || !durable) return@withLock
            val before = requireNotNull(journal)
            val replica = before.replica(owner)
            if (replica.queued.isNotEmpty()) return@withLock
            if (!replica.initialUploadComplete)
                save(before.replacing(owner, replica.copy(initialUploadComplete = true)))
            reconnectDelay = 1000
            emit(OwnProfilePhase.READY, null)
        }
    }

    fun retry() {
        if (closed) return
        scope.launch {
            try {
                if (journal == null) {
                    load()
                    return@launch
                }
                generation++
                stopNetwork()
                if (loadedDeletion()) {
                    storage.withLock { save(requireNotNull(journal)) }
                    emit(OwnProfilePhase.LOCAL, null)
                } else switchAccount(requestedOwner)
            } catch (_: CancellationException) {} catch (_: Exception) {
                fail(OwnProfileProblem.LOCAL_STORAGE)
            }
        }
    }

    private fun batch(queued: List<OwnProfileRecord>): List<OwnProfileRecord> {
        val result = mutableListOf<OwnProfileRecord>()
        var bytes = 0
        for (record in queued.take(50)) {
            val size = OwnProfileData.encodeRecords(listOf(record)).encodeToByteArray().size
            if (result.isNotEmpty() && bytes + size > 2_000_000) break
            result += record
            bytes += size
        }
        return result
    }

    private fun emit(
        phase: OwnProfilePhase = current.phase,
        problem: OwnProfileProblem? = current.problem,
    ) {
        if (closed) return
        val value = journal
        val replica = value?.replica()
        cell.set(
            current.copy(
                initialized = value != null,
                uid = value?.activeOwner,
                profile = replica?.let { OwnProfileData.profile(it.records) } ?: current.profile,
                phase = phase,
                problem = problem,
                pendingCount = replica?.queued?.size ?: 0,
                migrationComplete =
                    replica?.initialUploadComplete == true && value.activeOwner != null,
                deletingAccount = value?.pendingDeletion != null,
            )
        )
    }

    private fun fail(problem: OwnProfileProblem) {
        emit(OwnProfilePhase.ERROR, problem)
        if (
            closed ||
                problem == OwnProfileProblem.LOCAL_STORAGE ||
                requestedOwner == null ||
                reconnect?.isActive == true
        )
            return
        reconnect = scope.launch {
            delay(reconnectDelay)
            reconnectDelay = (reconnectDelay * 2).coerceAtMost(60_000)
            reconnect = null
            retry()
        }
    }

    private fun isCurrent(owner: String?, expected: Int) =
        !closed &&
            generation == expected &&
            requestedOwner == owner &&
            journal?.activeOwner == owner &&
            !loadedDeletion()

    private fun stopNetwork() {
        delayedSend?.cancel()
        delayedSend = null
        reconnect?.cancel()
        reconnect = null
        records?.cancel()
        records = null
        sending?.cancel()
        sending = null
        settling?.cancel()
        settling = null
        archiveSeed?.cancel()
        archiveSeed = null
        archiveSeedSeen = false
        serverSeen = false
    }

    fun close() {
        if (closed) return
        closed = true
        generation++
        account?.cancel()
        stopNetwork()
        scope.cancel()
    }

    private suspend fun <T : Any> awaitResult(
        start: ((T?, FriendsTransportError?) -> Unit) -> Unit
    ): T = suspendCancellableCoroutine { continuation ->
        start { value, error ->
            if (continuation.isActive) {
                if (error == FriendsTransportError.CANCELLED) continuation.cancel()
                else if (error != null || value == null)
                    continuation.resumeWithException(
                        IllegalStateException("Profile sync transport failed")
                    )
                else continuation.resume(value)
            }
        }
    }
}
