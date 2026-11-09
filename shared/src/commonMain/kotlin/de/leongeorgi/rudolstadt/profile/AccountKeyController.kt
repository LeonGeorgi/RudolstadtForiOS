package de.leongeorgi.rudolstadt.profile

import de.leongeorgi.rudolstadt.presentation.StateCell
import kotlin.coroutines.resume
import kotlinx.coroutines.*
import kotlinx.serialization.json.*

interface AccountKeyTransport {
    fun accountHasProvider(): Boolean

    fun observeAccount(changed: (String?) -> Unit): FriendsSubscription

    fun call(name: String, payload: String, completed: (String?, FriendsTransportError?) -> Unit)

    fun secureKeyEntropy(): String?

    fun signInCustomToken(
        token: String,
        expectedUID: String?,
        completed: (FriendsTransportError?) -> Unit,
    )
}

enum class AccountKeyError {
    CONNECTION,
    INVALID_KEY,
    RATE_LIMITED,
    CONFIGURATION,
    CONFLICT,
}

data class AccountKeyState(
    val uid: String? = null,
    val busy: Boolean = false,
    val loading: Boolean = false,
    val hasKey: Boolean = false,
    val isKeyAccount: Boolean = false,
    val version: Int? = null,
    val displayedKey: String? = null,
    val error: AccountKeyError? = null,
) {
    override fun toString() =
        "AccountKeyState(signedIn=${uid != null}, busy=$busy, loading=$loading, error=$error)"
}

/**
 * Owns key formatting, creation, idempotent retries, account binding and secret display lifetime.
 */
class AccountKeyController
internal constructor(
    private val transport: AccountKeyTransport,
    private val scope: CoroutineScope,
    private val accountActions: AccountActionGate = AccountActionGate(),
) {
    constructor(
        transport: AccountKeyTransport
    ) : this(transport, CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate))

    constructor(
        transport: AccountKeyTransport,
        accountActions: AccountActionGate,
    ) : this(
        transport,
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
        accountActions,
    )

    private val cell = StateCell(AccountKeyState())
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (AccountKeyState) -> Unit) = cell.observe(observer)

    private var generation = 0
    private var displayGeneration = 0
    private var closed = false
    private var pendingOwner: String? = null
    private var pendingVersion: Int? = null
    private var pendingKey: String? = null
    private var targetUID: String? = null
    private var targetDisplayGeneration = 0
    private var account: FriendsSubscription? = null

    init {
        account = transport.observeAccount { uid -> scope.launch { accountChanged(uid) } }
    }

    private fun accountChanged(uid: String?) {
        val standalone =
            uid != null && AccountKeys.isStandaloneAccount(uid) && !transport.accountHasProvider()
        if (closed || (uid == current.uid && standalone == current.isKeyAccount)) return
        generation++
        val created = standalone && uid == targetUID
        val createdKey = pendingKey.takeIf {
            created && displayGeneration == targetDisplayGeneration
        }
        cell.set(
            AccountKeyState(
                uid = uid,
                displayedKey = createdKey,
                hasKey = standalone,
                isKeyAccount = standalone,
                version = if (created) 1 else null,
            )
        )
        clearPending()
    }

    fun refresh() {
        val owner = current.uid ?: return
        if (closed || current.loading || current.busy || !current.isKeyAccount) return
        val expected = generation
        cell.set(current.copy(loading = true, error = null))
        scope.launch {
            try {
                val result = call("accountKeyStatus", buildJsonObject { put("owner", owner) })
                if (generation == expected && !closed)
                    cell.set(
                        current.copy(
                            loading = false,
                            hasKey = result.getValue("hasKey").jsonPrimitive.boolean,
                            isKeyAccount = result.getValue("eligible").jsonPrimitive.boolean,
                            version = result.getValue("version").jsonPrimitive.int,
                        )
                    )
            } catch (_: CancellationException) {} catch (error: Exception) {
                if (generation == expected && !closed)
                    cell.set(current.copy(loading = false, error = problem(error)))
            }
        }
    }

    fun createAccount() {
        if (current.uid != null) return
        action { expected, display ->
            val key = prepareKey(null, null)
            val result = call("createKeyAccount", buildJsonObject { put("key", key) })
            if (generation != expected || closed) return@action
            targetUID = result.getValue("uid").jsonPrimitive.content
            targetDisplayGeneration = display
            exchangeToken(result.getValue("token").jsonPrimitive.content)
            if (current.uid == targetUID && displayGeneration == display)
                cell.set(current.copy(displayedKey = key))
        }
    }

    fun signIn(value: String) {
        if (current.uid != null) return
        val key = AccountKeys.normalize(value)
        if (key == null) {
            if (!closed && !current.busy)
                cell.set(current.copy(error = AccountKeyError.INVALID_KEY))
            return
        }
        action { expected, _ ->
            clearPending()
            val result = call("signInWithAccountKey", buildJsonObject { put("key", key) })
            if (generation != expected || closed) return@action
            exchangeToken(result.getValue("token").jsonPrimitive.content)
        }
    }

    fun replaceKey() {
        val owner = current.uid ?: return
        if (!current.isKeyAccount) return
        action { expected, display ->
            val status = call("accountKeyStatus", buildJsonObject { put("owner", owner) })
            if (generation != expected || closed) return@action
            if (!status.getValue("eligible").jsonPrimitive.boolean) {
                clearPending()
                cell.set(current.copy(isKeyAccount = false, hasKey = false, version = null))
                return@action
            }
            val version = current.version ?: status.getValue("version").jsonPrimitive.int
            cell.set(current.copy(version = version))
            val key = prepareKey(owner, version)
            val result =
                call(
                    "replaceAccountKey",
                    buildJsonObject {
                        put("owner", owner)
                        put("key", key)
                        put("expectedVersion", version)
                    },
                )
            if (generation != expected || closed) return@action
            cell.set(
                current.copy(
                    hasKey = true,
                    version = result.getValue("version").jsonPrimitive.int,
                    displayedKey = key.takeIf { displayGeneration == display },
                )
            )
            clearPending()
        }
    }

    fun hideKey() {
        displayGeneration++
        if (!closed) cell.set(current.copy(displayedKey = null))
    }

    private fun prepareKey(owner: String?, version: Int?): String {
        if (pendingKey == null || pendingOwner != owner || pendingVersion != version) {
            pendingKey =
                transport.secureKeyEntropy()?.let(AccountKeys::fromEntropy)
                    ?: error("Secure entropy unavailable")
            pendingOwner = owner
            pendingVersion = version
        }
        return requireNotNull(pendingKey)
    }

    private fun clearPending() {
        pendingKey = null
        pendingOwner = null
        pendingVersion = null
        targetUID = null
    }

    private fun action(block: suspend (Int, Int) -> Unit) {
        if (closed || current.busy || current.loading) return
        val lease = accountActions.acquire() ?: return
        val expected = generation
        val display = ++displayGeneration
        cell.set(current.copy(busy = true, error = null, displayedKey = null))
        scope
            .launch {
                try {
                    block(expected, display)
                } catch (_: CancellationException) {} catch (error: Exception) {
                    if (generation == expected && !closed) {
                        val problem = problem(error)
                        cell.set(current.copy(error = problem))
                        if (problem == AccountKeyError.CONFLICT) {
                            clearPending()
                            cell.set(current.copy(version = null))
                        }
                    }
                } finally {
                    if (generation == expected && !closed) cell.set(current.copy(busy = false))
                }
            }
            .invokeOnCompletion { accountActions.release(lease) }
    }

    private class TransportFailure(val kind: FriendsTransportError?) :
        Exception("Account key request failed")

    private fun problem(error: Exception) =
        when ((error as? TransportFailure)?.kind) {
            FriendsTransportError.AUTH_CONFIGURATION -> AccountKeyError.CONFIGURATION
            FriendsTransportError.RATE_LIMITED -> AccountKeyError.RATE_LIMITED
            FriendsTransportError.UNAUTHENTICATED -> AccountKeyError.INVALID_KEY
            FriendsTransportError.CONFLICT -> AccountKeyError.CONFLICT
            else -> AccountKeyError.CONNECTION
        }

    private suspend fun call(name: String, payload: JsonObject): JsonObject {
        val result = awaitResult<String> { transport.call(name, payload.toString(), it) }
        return Json.parseToJsonElement(result).jsonObject
    }

    private suspend fun exchangeToken(token: String) {
        awaitResult<Unit> { done -> transport.signInCustomToken(token, null) { done(Unit, it) } }
    }

    private suspend fun <T : Any> awaitResult(
        start: ((T?, FriendsTransportError?) -> Unit) -> Unit
    ): T = suspendCancellableCoroutine { continuation ->
        start { value, error ->
            if (continuation.isActive) {
                if (error == FriendsTransportError.CANCELLED) continuation.cancel()
                else if (error != null || value == null)
                    continuation.resumeWith(Result.failure(TransportFailure(error)))
                else continuation.resume(value)
            }
        }
    }

    fun close() {
        if (closed) return
        closed = true
        generation++
        clearPending()
        account?.cancel()
        scope.cancel()
        cell.set(AccountKeyState())
    }
}
