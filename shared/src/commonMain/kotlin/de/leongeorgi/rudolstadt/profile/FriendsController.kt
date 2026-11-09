package de.leongeorgi.rudolstadt.profile

import de.leongeorgi.rudolstadt.presentation.StateCell
import io.ktor.http.Url
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.*

enum class FriendsError {
    GENERAL,
    PUBLISH,
    INVALID_LINK,
    AUTHENTICATION,
    AUTH_CONFIGURATION,
    ACCOUNT_CONFLICT,
}

data class EmailLinkDelivery(val recipient: String, val revision: Int, val isResend: Boolean)

data class FriendsState(
    val uid: String? = null,
    val active: Boolean = false,
    val busy: Boolean = false,
    val error: FriendsError? = null,
    val emailDelivery: EmailLinkDelivery? = null,
    val loginLink: String? = null,
    val invitation: FriendInvite? = null,
    val previewName: String? = null,
    val ownInvite: String? = null,
    val friends: List<SharedProfile> = emptyList(),
    val connections: List<FriendConnection> = emptyList(),
    val identity: FriendIdentity? = null,
    val identityLoaded: Boolean = false,
    val archiveEdition: String? = null,
    val archiveFriends: List<SharedProfile> = emptyList(),
) {
    val emailSent: Boolean
        get() = emailDelivery != null
}

/**
 * Owns the complete client workflow. All state and listener callbacks are confined to its UI scope.
 */
class FriendsController
internal constructor(
    private val edition: String,
    private val transport: FriendsTransport,
    private val scope: CoroutineScope,
    private val publishDelayMillis: Long = 600,
    private val accountActions: AccountActionGate = AccountActionGate(),
) {
    constructor(
        edition: String,
        transport: FriendsTransport,
    ) : this(edition, transport, CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate))

    constructor(
        edition: String,
        transport: FriendsTransport,
        accountActions: AccountActionGate,
    ) : this(
        edition,
        transport,
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
        accountActions = accountActions,
    )

    private val cell = StateCell(FriendsState())
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (FriendsState) -> Unit) = cell.observe(observer)

    private var closed = false
    private var generation = 0
    private var account: FriendsSubscription? = null
    private var memberships: FriendsSubscription? = null
    private var membershipToken: Any? = null

    private class PublishFailure(cause: Exception) : Exception(cause)

    private class ProfileWatch {
        var identitySubscription: FriendsSubscription? = null
        var identity: FriendIdentity? = null
        val editions = mutableMapOf<String, EditionWatch>()

        fun close() {
            identitySubscription?.cancel()
            editions.values.forEach { it.close() }
            editions.clear()
        }
    }

    private class EditionWatch {
        val subscriptions = mutableListOf<FriendsSubscription>()
        var saved: List<Long>? = null
        var ratings: List<ArtistPreference>? = null

        fun close() {
            subscriptions.forEach { it.cancel() }
            subscriptions.clear()
        }
    }

    private val watches = mutableMapOf<String, ProfileWatch>()
    private val connections = mutableMapOf<String, FriendshipRecord>()
    private var archiveEdition: String? = null
    private var ownIdentity: FriendsSubscription? = null
    private var sourceOwner: String? = null
    private var sourceReady = false
    private var local = PersonalProfile()
    private var lastPublished: FriendShareProfile? = null
    private val publishMutex = Mutex()
    private var publishJob: Job? = null
    private var dirty = false

    init {
        account = transport.observeAccount { uid ->
            scope.launch { if (!closed) accountChanged(uid) }
        }
    }

    fun close() {
        if (closed) return
        closed = true
        generation++
        account?.cancel()
        stopFriends()
        ownIdentity?.cancel()
        scope.cancel()
        cell.set(FriendsState())
    }

    private fun update(change: (FriendsState) -> FriendsState) {
        if (!closed) cell.set(change(current))
    }

    private fun accountChanged(uid: String?) {
        if (uid == current.uid) return
        generation++
        publishJob?.cancel()
        publishJob = null
        dirty = false
        lastPublished = null
        stopFriends()
        ownIdentity?.cancel()
        ownIdentity = null
        // Only the invitation survives an account change.
        cell.set(
            FriendsState(
                uid = uid,
                invitation = current.invitation,
                archiveEdition = archiveEdition,
            )
        )
        if (uid != null) {
            val expected = generation
            ownIdentity =
                transport.observeIdentity(uid) { payload, error ->
                    scope.launch {
                        if (generation != expected || closed) return@launch
                        if (error != null) {
                            update { it.copy(error = FriendsError.GENERAL) }
                            return@launch
                        }
                        try {
                            val identity = payload?.let(FriendSharing::identity)
                            update {
                                it.copy(identity = identity, active = identity != null, identityLoaded = true)
                            }
                            if (identity != null) schedulePublish()
                        } catch (_: Exception) {
                            update { it.copy(error = FriendsError.GENERAL) }
                        }
                    }
                }
            observeFriends()
        }
    }

    private fun action(block: suspend (Int) -> Unit) {
        if (closed || current.busy) return
        val lease = accountActions.acquire() ?: return
        val expected = generation
        update { it.copy(busy = true, error = null) }
        scope
            .launch {
                try {
                    block(expected)
                } catch (_: CancellationException) {} catch (error: Exception) {
                    if (generation == expected) {
                        val kind = if (error is PublishFailure) FriendsError.PUBLISH else FriendsError.GENERAL
                        update { it.copy(error = kind) }
                    }
                } finally {
                    if (generation == expected) update { it.copy(busy = false) }
                }
            }
            .invokeOnCompletion { accountActions.release(lease) }
    }

    /**
     * Runs only the native credential exchange; auth callbacks own the resulting account change.
     */
    fun authenticate(start: ((FriendsTransportError?) -> Unit) -> Unit) = action { expected ->
        val error =
            suspendCancellableCoroutine<FriendsTransportError?> { continuation ->
                start { if (continuation.isActive) continuation.resume(it) }
            }
        if (generation == expected && error != null && error != FriendsTransportError.CANCELLED)
            update {
                it.copy(
                    error =
                        when (error) {
                            FriendsTransportError.AUTH_CONFIGURATION ->
                                FriendsError.AUTH_CONFIGURATION
                            FriendsTransportError.ACCOUNT_CONFLICT -> FriendsError.ACCOUNT_CONFLICT
                            else -> FriendsError.AUTHENTICATION
                        }
                )
            }
    }

    fun sendEmail(email: String) = action { expected ->
        val recipient = email.trim()
        awaitResult<Unit> { done -> transport.sendEmail(recipient) { done(Unit, it) } }
        if (generation == expected)
            update {
                val previous = it.emailDelivery
                it.copy(
                    emailDelivery =
                        EmailLinkDelivery(
                            recipient,
                            (previous?.revision ?: 0) + 1,
                            previous?.recipient == recipient,
                        )
                )
            }
    }

    fun finishEmail(email: String, link: String) = action { expected ->
        require(transport.isEmailLink(link))
        awaitResult<Unit> { done -> transport.finishEmail(email.trim(), link) { done(Unit, it) } }
        if (generation == expected) update { it.copy(loginLink = null, emailDelivery = null) }
    }

    fun dismissEmailLink() = update { it.copy(loginLink = null, error = null) }

    fun signOut() = action {
        awaitResult<Unit> { done -> transport.signOut { done(Unit, it) } }
    }

    fun receive(value: String): Boolean {
        if (closed) return false
        val invite = FriendSharing.parseInvite(value)
        if (invite != null) {
            update {
                it.copy(
                    invitation = invite,
                    previewName = null,
                    error = null,
                )
            }
            return true
        }
        val url =
            try {
                Url(value)
            } catch (_: Exception) {
                return false
            }
        if (
            url.protocol.name == "https" &&
                url.host == FriendsConfiguration.authDomain &&
                url.port == 443 &&
                url.user.isNullOrEmpty() &&
                url.password.isNullOrEmpty() &&
                transport.isEmailLink(value)
        ) {
            update { it.copy(loginLink = value, error = null) }
            return true
        }
        return false
    }

    fun dismissInvite() = update {
        it.copy(
            invitation = null,
            previewName = null,
        )
    }

    fun setFriendSharing(
        uid: String,
        savedEvents: Boolean,
        ratings: Boolean,
        notes: Boolean = false,
    ) = action { expected ->
        val result =
            call(
                "updateFriendSharing",
                expected,
                buildJsonObject {
                    put("uid", uid)
                    put(
                        "sharing",
                        Json.encodeToJsonElement(FriendPermissions(savedEvents, ratings, notes)),
                    )
                },
            )
        val updated = FriendSharing.membership(result.getValue("connection").toString())
        connections[uid]?.let { applyConnection(updated.copy(receiving = it.receiving), expected) }
    }

    fun invalidLink() = update { it.copy(error = FriendsError.INVALID_LINK) }

    fun activate(profile: PersonalProfile) = action { expected ->
        check(current.uid != null)
        val identity =
            FriendIdentity(
                profile.badgeName.orEmpty().trim(),
                ProfileReducer.resolvedHue(profile.badgeHue),
            )
        val response =
            call(
                "setFriendIdentity",
                expected,
                buildJsonObject { put("identity", Json.encodeToJsonElement(identity)) },
            )
        update {
            it.copy(
                active = true,
                identity = FriendSharing.identity(response.getValue("identity").toString()),
                identityLoaded = true,
            )
        }
        if (sourceReady && sourceOwner == current.uid) publish(expected)
    }

    /**
     * A fresh account must not overwrite a shared festival profile with an unmerged local cache.
     */
    fun syncProfile(profile: PersonalProfile, owner: String?, ready: Boolean) {
        local = profile
        sourceOwner = owner
        sourceReady = ready
        if (ready) schedulePublish()
    }

    /** Observes the selected archive alongside the current edition. */
    fun showArchive(edition: String?) {
        if (closed || archiveEdition == edition) return
        require(edition != this.edition)
        val previous = archiveEdition
        archiveEdition = edition
        if (previous != null) watches.values.forEach { it.editions.remove(previous)?.close() }
        updateFriends()
        if (edition != null) {
            for ((uid, watch) in watches) observeEdition(uid, watch, edition, generation)
        }
    }

    private fun schedulePublish() {
        if (closed || !current.active || !sourceReady || sourceOwner != current.uid) return
        dirty = true
        if (publishJob?.isActive == true) return
        val expected = generation
        publishJob = scope.launch {
            try {
                while (dirty) {
                    delay(publishDelayMillis)
                    dirty = false
                    if (!sourceReady || sourceOwner != current.uid) break
                    publish(expected)
                }
            } catch (_: CancellationException) {} catch (_: Exception) {
                if (generation == expected) update { it.copy(error = FriendsError.PUBLISH) }
            }
        }
    }

    fun retryPublish() = action { expected ->
        check(current.active)
        if (sourceReady && sourceOwner == current.uid) publish(expected)
        observeFriends()
    }

    private suspend fun publish(expected: Int) = publishMutex.withLock {
        checkSession(expected)
        check(current.uid != null && sourceReady && sourceOwner == current.uid)
        val snapshot = FriendSharing.snapshot(local)
        if (snapshot != lastPublished) {
            try {
                call(
                    "publishFriendProfile",
                    expected,
                    buildJsonObject {
                        put("edition", edition)
                        put("profile", Json.encodeToJsonElement(snapshot))
                    },
                )
                lastPublished = snapshot
            } catch (error: Exception) {
                // A failed response does not establish which profile reached the server.
                if (generation == expected) lastPublished = null
                if (error is CancellationException) throw error
                throw PublishFailure(error)
            }
        }
    }

    fun createInvite() = action { expected ->
        check(current.active)
        val sharing = FriendSharing.defaultPermissions
        val result =
            call(
                "createFriendInvite",
                expected,
                buildJsonObject { put("sharing", Json.encodeToJsonElement(sharing)) },
            )
        val token = result.getValue("token").jsonPrimitive.content
        val invite = FriendInvite(token)
        require(FriendSharing.parseInvite(invite.url) == invite)
        update { it.copy(ownInvite = invite.url) }
    }

    fun previewInvite() = action { expected ->
        val invite = current.invitation ?: return@action
        val result =
            call("previewFriendInvite", expected, buildJsonObject { put("token", invite.token) })
        if (current.invitation == invite)
            update {
                it.copy(previewName = result.getValue("name").jsonPrimitive.content)
            }
    }

    fun acceptInvite() = action { expected ->
        check(current.active)
        val invite = current.invitation ?: return@action
        call(
            "acceptFriendInvite",
            expected,
            buildJsonObject {
                put("token", invite.token)
                put("sharing", Json.encodeToJsonElement(FriendSharing.defaultPermissions))
            },
        )
        if (current.invitation == invite) dismissInvite()
    }

    fun removeFriend(uid: String) = action { expected ->
        check(current.active)
        call("removeFriend", expected, buildJsonObject { put("uid", uid) })
    }

    private suspend fun call(
        name: String,
        expected: Int,
        values: JsonObject = JsonObject(emptyMap()),
    ): JsonObject {
        checkSession(expected)
        val payload =
            JsonObject(
                    values +
                        mapOf(
                            "protocol" to JsonPrimitive(2),
                            "owner" to JsonPrimitive(requireNotNull(current.uid)),
                        )
                )
                .toString()
        val response = awaitResult<String> { done -> transport.call(name, payload, done) }
        checkSession(expected)
        return Json.parseToJsonElement(response).jsonObject
    }

    private fun checkSession(expected: Int) {
        if (closed || generation != expected) throw CancellationException("Account changed")
    }

    private fun stopFriends() {
        membershipToken = null
        memberships?.cancel()
        memberships = null
        watches.values.forEach { it.close() }
        watches.clear()
        connections.clear()
    }

    private fun observeFriends() {
        val owner = current.uid ?: return
        stopFriends()
        updateFriends()
        val expected = generation
        val token = Any()
        membershipToken = token
        val subscription =
            transport.observeMemberships(owner) { payload, error ->
                scope.launch {
                    if (generation != expected || membershipToken !== token) return@launch
                    if (error != null || payload == null) {
                        update { it.copy(error = FriendsError.GENERAL) }
                        return@launch
                    }
                    try {
                        val values = FriendSharing.memberships(payload).associateBy { it.uid }
                        for (uid in connections.keys.toSet() - values.keys) removeProfile(uid)
                        for (value in values.values) applyConnection(value, expected)
                    } catch (_: Exception) {
                        update { it.copy(error = FriendsError.GENERAL) }
                    }
                }
            }
        if (membershipToken === token) memberships = subscription else subscription.cancel()
    }

    private fun applyConnection(value: FriendshipRecord, expected: Int) {
        val before = connections.put(value.uid, value)
        if (before == null || before.receiving != value.receiving)
            observeProfile(value.uid, expected)
        updateFriends()
    }

    private fun observeProfile(uid: String, expected: Int) {
        val previous = watches.remove(uid)
        previous?.close()
        val watch = ProfileWatch().also { it.identity = previous?.identity }
        watches[uid] = watch
        watch.identitySubscription =
            transport.observeIdentity(uid) { payload, error ->
                receiveProfileChange(uid, expected, error, { isCurrent(uid, watch, expected) }) {
                    watch.identity =
                        if (error == null) payload?.let(FriendSharing::identity) else null
                }
            }
        observeEdition(uid, watch, edition, expected)
        archiveEdition?.let { observeEdition(uid, watch, it, expected) }
    }

    private fun observeEdition(uid: String, watch: ProfileWatch, edition: String, expected: Int) {
        if (!isCurrent(uid, watch, expected)) return
        val grant = connections.getValue(uid).receiving
        val content = EditionWatch()
        watch.editions[edition] = content
        val isCurrent = { isCurrent(uid, watch, expected) && watch.editions[edition] === content }
        fun observe(category: String, apply: (FriendShareProfile?) -> Unit) {
            if (!isCurrent()) return
            val subscription =
                transport.observeCategory(edition, uid, category) { payload, error ->
                    receiveProfileChange(uid, expected, error, isCurrent) {
                        apply(
                            if (error == null)
                                payload?.let(FriendSharing::data) ?: FriendShareProfile()
                            else null
                        )
                    }
                }
            if (isCurrent()) content.subscriptions += subscription else subscription.cancel()
        }
        if (grant.savedEvents) observe("savedEvents") { content.saved = it?.savedEventIDs }
        if (grant.ratings) observe("ratings") { content.ratings = it?.artistPreferences }
    }

    private fun receiveProfileChange(
        uid: String,
        expected: Int,
        error: FriendsTransportError?,
        isCurrent: () -> Boolean,
        apply: () -> Unit,
    ) {
        scope.launch {
            if (!isCurrent()) return@launch
            try {
                apply()
                updateFriends()
                if (error == FriendsTransportError.PERMISSION_DENIED)
                    reconcileRevocation(uid, expected, isCurrent)
                else if (error != null) update { it.copy(error = FriendsError.GENERAL) }
            } catch (_: Exception) {
                update { it.copy(error = FriendsError.GENERAL) }
            }
        }
    }

    private suspend fun reconcileRevocation(uid: String, expected: Int, isCurrent: () -> Boolean) {
        try {
            val result =
                call("friendConnectionStatus", expected, buildJsonObject { put("uid", uid) })
            if (!isCurrent()) return
            val value = result["connection"]
            if (value == null || value is JsonNull) removeProfile(uid)
            else {
                val updated = FriendSharing.membership(value.toString())
                if (updated.receiving == connections[uid]?.receiving)
                    update { it.copy(error = FriendsError.GENERAL) }
                else applyConnection(updated, expected)
            }
        } catch (_: CancellationException) {} catch (_: Exception) {
            if (isCurrent()) update { it.copy(error = FriendsError.GENERAL) }
        }
    }

    private fun isCurrent(uid: String, watch: ProfileWatch, expected: Int) =
        !closed && generation == expected && watches[uid] === watch

    private fun removeProfile(uid: String) {
        watches.remove(uid)?.close()
        connections.remove(uid)
        updateFriends()
    }

    private fun profilesFor(edition: String): List<SharedProfile> =
        watches
            .mapNotNull { (uid, watch) ->
                val identity = watch.identity ?: return@mapNotNull null
                val grant = connections.getValue(uid).receiving
                val content = watch.editions[edition]
                if (
                    (grant.savedEvents && content?.saved == null) ||
                        (grant.ratings && content?.ratings == null)
                )
                    return@mapNotNull null
                FriendSharing.profile(
                    uid,
                    edition,
                    identity,
                    content?.saved.orEmpty(),
                    content?.ratings.orEmpty(),
                )
            }
            .sortedWith(compareBy({ it.title.lowercase() }, { it.profileID }))

    private fun updateFriends() = update { state ->
        state.copy(
            friends = profilesFor(edition),
            archiveEdition = archiveEdition,
            archiveFriends = archiveEdition?.let(::profilesFor).orEmpty(),
            connections =
                connections.values
                    .map { value ->
                        FriendConnection(
                            value.uid,
                            value.sharing,
                            value.receiving,
                            watches[value.uid]?.identity?.name,
                            watches[value.uid]?.identity?.hue ?: ProfileReducer.defaultHue,
                        )
                    }
                    .sortedWith(compareBy({ it.name.orEmpty().lowercase() }, { it.uid })),
        )
    }

    private suspend fun <T : Any> awaitResult(
        start: ((T?, FriendsTransportError?) -> Unit) -> Unit
    ): T = suspendCancellableCoroutine { continuation ->
        start { value, error ->
            if (continuation.isActive) {
                when {
                    error == FriendsTransportError.CANCELLED -> continuation.cancel()
                    error != null || value == null ->
                        continuation.resumeWithException(
                            IllegalStateException("Friend transport failed")
                        )
                    else -> continuation.resume(value)
                }
            }
        }
    }
}
