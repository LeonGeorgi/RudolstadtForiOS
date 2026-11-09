package de.leongeorgi.rudolstadt.profile

import de.leongeorgi.rudolstadt.presentation.StateCell
import kotlin.coroutines.resume
import kotlinx.coroutines.*
import kotlinx.serialization.json.*

interface AccountDeletionTransport {
    fun observeAccount(changed: (String?) -> Unit): FriendsSubscription

    fun secureKeyEntropy(): String?

    fun call(name: String, payload: String, completed: (String?, FriendsTransportError?) -> Unit)

    fun signOutDeletedAccount(owner: String, completed: (FriendsTransportError?) -> Unit)
}

enum class AccountDeletionProblem {
    CONNECTION,
    LOCAL_STORAGE,
    AUTHENTICATION,
}

data class AccountDeletionState(
    val uid: String? = null,
    val busy: Boolean = false,
    val pending: Boolean = false,
    val deleted: Boolean = false,
    val problem: AccountDeletionProblem? = null,
)

/** Deletion is resumable from the durable local journal, including after Auth revocation. */
class AccountDeletionController
internal constructor(
    private val transport: AccountDeletionTransport,
    private val profile: OwnProfileController,
    private val accountActions: AccountActionGate,
    private val scope: CoroutineScope,
) {
    constructor(
        transport: AccountDeletionTransport,
        profile: OwnProfileController,
        accountActions: AccountActionGate,
    ) : this(
        transport,
        profile,
        accountActions,
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
    )

    private val cell = StateCell(AccountDeletionState())
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (AccountDeletionState) -> Unit) = cell.observe(observer)

    private var closed = false
    private val account = transport.observeAccount { uid ->
        scope.launch {
            if (!closed)
                cell.set(
                    current.copy(uid = uid, deleted = if (uid != null) false else current.deleted)
                )
        }
    }
    private val local = profile.observe(::localChanged)

    init {
        localChanged(profile.current)
    }

    private fun localChanged(value: OwnProfileSyncState) {
        if (!closed) {
            cell.set(current.copy(pending = value.deletingAccount))
            if (value.initialized && value.deletingAccount && !current.busy) retry()
        }
    }

    fun deleteAccount(prepare: (String, (FriendsTransportError?) -> Unit) -> Unit) {
        val owner = current.uid ?: return
        if (profile.pendingDeletion != null) {
            retry()
            return
        }
        action {
            val error = awaitResult<FriendsTransportError?> { done -> prepare(owner, done) }
            if (error == FriendsTransportError.CANCELLED) return@action
            if (error != null) {
                cell.set(current.copy(problem = AccountDeletionProblem.AUTHENTICATION))
                return@action
            }
            check(current.uid == owner && profile.current.uid == owner)
            val receipt = requireNotNull(transport.secureKeyEntropy())
            check(receipt.length == 40 && receipt.all { it in "0123456789abcdef" })
            try {
                profile.prepareAccountDeletion(AccountDeletionRequest(owner, receipt))
            } catch (error: Exception) {
                cell.set(current.copy(problem = AccountDeletionProblem.LOCAL_STORAGE))
                throw error
            }
            performDeletion()
        }
    }

    fun retry() {
        if (profile.pendingDeletion == null) return
        action { performDeletion() }
    }

    private suspend fun performDeletion() {
        val request = requireNotNull(profile.pendingDeletion)
        // A failed disk write must never be followed by remote deletion, including on retry.
        try {
            profile.prepareAccountDeletion(request)
        } catch (error: Exception) {
            cell.set(current.copy(problem = AccountDeletionProblem.LOCAL_STORAGE))
            throw error
        }
        val result =
            awaitResult<Pair<String?, FriendsTransportError?>> { done ->
                transport.call(
                    "deleteAccount",
                    buildJsonObject {
                        put("owner", request.owner)
                        put("receipt", request.receipt)
                    }
                        .toString(),
                ) { value, error ->
                    done(value to error)
                }
            }
        check(
            result.second == null &&
                result.first?.let {
                    Json.parseToJsonElement(it).jsonObject["deleted"]?.jsonPrimitive?.boolean
                } == true
        )
        val error =
            awaitResult<FriendsTransportError?> {
                transport.signOutDeletedAccount(request.owner, it)
            }
        check(error == null)
        try {
            profile.finishAccountDeletion(request.owner)
        } catch (error: Exception) {
            cell.set(current.copy(problem = AccountDeletionProblem.LOCAL_STORAGE))
            throw error
        }
        cell.set(current.copy(pending = false, deleted = true))
    }

    private fun action(block: suspend () -> Unit) {
        if (closed || current.busy || !profile.current.initialized) return
        val lease = accountActions.acquire() ?: return
        cell.set(current.copy(busy = true, problem = null, deleted = false))
        scope
            .launch {
                try {
                    block()
                } catch (_: CancellationException) {} catch (_: Exception) {
                    if (!closed && current.problem == null)
                        cell.set(current.copy(problem = AccountDeletionProblem.CONNECTION))
                } finally {
                    if (!closed)
                        cell.set(
                            current.copy(busy = false, pending = profile.pendingDeletion != null)
                        )
                }
            }
            .invokeOnCompletion { accountActions.release(lease) }
    }

    private suspend fun <T> awaitResult(start: ((T) -> Unit) -> Unit): T =
        suspendCancellableCoroutine { continuation ->
            start { if (continuation.isActive) continuation.resume(it) }
        }

    fun close() {
        closed = true
        account.cancel()
        local.cancel()
        scope.cancel()
    }
}
