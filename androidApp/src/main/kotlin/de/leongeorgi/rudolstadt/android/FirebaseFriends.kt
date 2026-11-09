package de.leongeorgi.rudolstadt.android

import android.app.Activity
import android.content.Context
import android.os.CancellationSignal
import androidx.core.content.ContextCompat
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.gms.tasks.Task
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.ActionCodeSettings
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseAuthException
import com.google.firebase.auth.FirebaseAuthUserCollisionException
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.auth.OAuthCredential
import com.google.firebase.auth.OAuthProvider
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreException
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.MetadataChanges
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.functions.FirebaseFunctionsException
import de.leongeorgi.rudolstadt.android.data.Edition
import de.leongeorgi.rudolstadt.profile.*
import java.security.SecureRandom
import org.json.JSONObject

/** Android SDK adapter. Workflow and all observable state belong to FriendsController. */
internal class FirebaseFriends(context: Context) :
    FriendsTransport, AccountKeyTransport, AccountDeletionTransport {
    private val applicationContext = context.applicationContext
    private val credentials = CredentialManager.create(applicationContext)
    private val executor = ContextCompat.getMainExecutor(applicationContext)
    private var googleRequest: CancellationSignal? = null
    val configured = FirebaseApp.getApps(context).isNotEmpty()
    val accountEmail: String?
        get() = if (configured) auth.currentUser?.email else null

    val hasAccountProvider: Boolean
        get() =
            configured &&
                auth.currentUser?.providerData?.any {
                    it.providerId in setOf("apple.com", "google.com", "password")
                } == true

    private val auth
        get() = FirebaseAuth.getInstance()

    private val database
        get() = FirebaseFirestore.getInstance()

    private val deletionRequests by lazy {
        FirebaseApp.getApps(applicationContext).firstOrNull { it.name == "AccountDeletionRequests" }
            ?: FirebaseApp.initializeApp(
                applicationContext,
                FirebaseApp.getInstance().options,
                "AccountDeletionRequests",
            )
    }

    val accountActions = AccountActionGate()
    val controller = FriendsController(Edition.current.friendsEdition, this, accountActions)
    val keys = AccountKeyController(this, accountActions)

    override fun accountHasProvider(): Boolean =
        auth.currentUser?.let { user ->
            user.email != null ||
                user.phoneNumber != null ||
                user.providerData.any { it.providerId != "firebase" }
        } ?: false

    fun close() {
        googleRequest?.cancel()
        keys.close()
        controller.close()
    }

    override fun secureKeyEntropy(): String =
        ByteArray(20)
            .also { SecureRandom().nextBytes(it) }
            .joinToString("") { "%02x".format(it.toInt() and 255) }

    fun prepareAccountDeletion(
        activity: Activity,
        owner: String,
        completed: (FriendsTransportError?) -> Unit,
    ) {
        val user = auth.currentUser
        if (user?.uid != owner) {
            completed(FriendsTransportError.CANCELLED)
            return
        }
        if (user.providerData.none { it.providerId == "apple.com" }) {
            completed(null)
            return
        }
        user
            .startActivityForReauthenticateWithProvider(
                activity,
                OAuthProvider.newBuilder("apple.com").build(),
            )
            .complete { result, error ->
                if (error != null) completed(error)
                else {
                    val token = (result?.credential as? OAuthCredential)?.accessToken
                    if (token == null || auth.currentUser?.uid != owner)
                        completed(FriendsTransportError.FAILED)
                    else auth.revokeAccessToken(token).complete { _, failure -> completed(failure) }
                }
            }
    }

    override fun signOutDeletedAccount(owner: String, completed: (FriendsTransportError?) -> Unit) {
        if (auth.currentUser?.uid == owner) signOut(completed) else completed(null)
    }

    override fun signInCustomToken(
        token: String,
        expectedUID: String?,
        completed: (FriendsTransportError?) -> Unit,
    ) {
        if (!configured || auth.currentUser?.uid != expectedUID) {
            completed(FriendsTransportError.CANCELLED)
            return
        }
        auth.signInWithCustomToken(token).complete { _, error -> completed(error) }
    }

    fun signInGoogle(activity: Activity) = controller.authenticate { completed ->
        // This resource exists only after Google is enabled and the SDK config is refreshed.
        val resource =
            applicationContext.resources.getIdentifier(
                "default_web_client_id",
                "string",
                applicationContext.packageName,
            )
        val clientID = if (resource == 0) "" else applicationContext.getString(resource)
        if (!configured || clientID.isBlank()) {
            completed(FriendsTransportError.AUTH_CONFIGURATION)
            return@authenticate
        }
        val cancellation = CancellationSignal()
        googleRequest = cancellation
        val request =
            GetCredentialRequest.Builder()
                .addCredentialOption(GetSignInWithGoogleOption.Builder(clientID).build())
                .build()
        credentials.getCredentialAsync(
            activity,
            request,
            cancellation,
            executor,
            object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                override fun onResult(result: GetCredentialResponse) {
                    googleRequest = null
                    if (cancellation.isCanceled) {
                        completed(FriendsTransportError.CANCELLED)
                        return
                    }
                    try {
                        val value = result.credential
                        require(
                            value is CustomCredential &&
                                value.type ==
                                    GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                        )
                        val token = GoogleIdTokenCredential.createFrom(value.data).idToken
                        auth
                            .signInWithCredential(GoogleAuthProvider.getCredential(token, null))
                            .complete { _, error -> completed(error) }
                    } catch (_: Exception) {
                        completed(FriendsTransportError.FAILED)
                    }
                }

                override fun onError(e: GetCredentialException) {
                    googleRequest = null
                    completed(
                        if (e is GetCredentialCancellationException) FriendsTransportError.CANCELLED
                        else FriendsTransportError.FAILED
                    )
                }
            },
        )
    }

    fun signInApple(activity: Activity) = controller.authenticate { completed ->
        val task =
            auth.pendingAuthResult
                ?: auth.startActivityForSignInWithProvider(
                    activity,
                    OAuthProvider.newBuilder("apple.com").build(),
                )
        task.complete { _, error -> completed(error) }
    }

    override fun observeAccount(changed: (String?) -> Unit): FriendsSubscription {
        if (!configured)
            return object : FriendsSubscription {
                override fun cancel() {}
            }
        val listener = FirebaseAuth.AuthStateListener { changed(it.currentUser?.uid) }
        auth.addAuthStateListener(listener)
        return object : FriendsSubscription {
            override fun cancel() = auth.removeAuthStateListener(listener)
        }
    }

    override fun call(
        name: String,
        payload: String,
        completed: (String?, FriendsTransportError?) -> Unit,
    ) {
        call(name, payload, name == "accountDeletionStatus", completed)
    }

    private fun call(
        name: String,
        payload: String,
        publicRequest: Boolean,
        completed: (String?, FriendsTransportError?) -> Unit,
    ) {
        try {
            FirebaseFunctions.getInstance(
                    if (publicRequest) deletionRequests else FirebaseApp.getInstance(),
                    FriendsConfiguration.region,
                )
                .getHttpsCallable(name)
                .call(JSONObject(payload).toMap())
                .complete { result, error ->
                    if (error != null && name == "deleteAccount" && !publicRequest)
                        call(name, payload, true, completed)
                    else if (error != null) completed(null, error)
                    else {
                        val json =
                            try {
                                JSONObject(result?.data as Map<*, *>).toString()
                            } catch (_: Exception) {
                                null
                            }
                        completed(json, if (json == null) FriendsTransportError.FAILED else null)
                    }
                }
        } catch (_: Exception) {
            completed(null, FriendsTransportError.FAILED)
        }
    }

    override fun observeMemberships(
        owner: String,
        changed: (String?, FriendsTransportError?) -> Unit,
    ): FriendsSubscription =
        database
            .collection("friendships")
            .document(owner)
            .collection("friends")
            .addSnapshotListener { snapshot, error ->
                changed(
                    snapshot?.documents?.let {
                        org.json.JSONArray(it.map { doc -> doc.data }).toString()
                    },
                    error?.transportError(),
                )
            }
            .subscription()

    override fun observeIdentity(
        uid: String,
        changed: (String?, FriendsTransportError?) -> Unit,
    ): FriendsSubscription =
        observeDocument(
            database.collection("friendIdentities").document(uid),
            changed,
            waitForServerIfMissing = uid == auth.currentUser?.uid,
        )

    override fun observeCategory(
        edition: String,
        uid: String,
        category: String,
        changed: (String?, FriendsTransportError?) -> Unit,
    ): FriendsSubscription {
        if (category == "notes")
            return database
                .collection("users")
                .document(uid)
                .collection("profileEditions")
                .document(edition)
                .collection("records")
                .whereEqualTo("value.kind", "note")
                .addSnapshotListener { snapshot, error ->
                    changed(
                        snapshot?.documents?.let {
                            org.json.JSONArray(it.map { document -> document.data }).toString()
                        },
                        error?.transportError(),
                    )
                }
                .subscription()
        return observeDocument(
            database
                .collection("friendProfileEditions")
                .document(edition)
                .collection("profiles")
                .document(uid)
                .collection("categories")
                .document(category),
            changed,
        )
    }

    private fun observeDocument(
        document: com.google.firebase.firestore.DocumentReference,
        changed: (String?, FriendsTransportError?) -> Unit,
        waitForServerIfMissing: Boolean = false,
    ): FriendsSubscription =
        document
            .addSnapshotListener(
                if (waitForServerIfMissing) MetadataChanges.INCLUDE else MetadataChanges.EXCLUDE
            ) { snapshot, error ->
                if (waitForServerIfMissing && snapshot?.metadata?.isFromCache == true && !snapshot.exists()) {
                    return@addSnapshotListener
                }
                changed(snapshot?.data?.let { JSONObject(it).toString() }, error?.transportError())
            }
            .subscription()

    override fun isEmailLink(value: String) = configured && auth.isSignInWithEmailLink(value)

    override fun sendEmail(email: String, completed: (FriendsTransportError?) -> Unit) {
        val settings =
            ActionCodeSettings.newBuilder()
                .setUrl(FriendsConfiguration.emailContinueURL)
                .setHandleCodeInApp(true)
                .setIOSBundleId(FriendsConfiguration.iosBundleID)
                .setAndroidPackageName(FriendsConfiguration.androidPackage, false, null)
                .setLinkDomain(FriendsConfiguration.authDomain)
                .build()
        auth.sendSignInLinkToEmail(email, settings).complete { _, error -> completed(error) }
    }

    override fun finishEmail(
        email: String,
        link: String,
        completed: (FriendsTransportError?) -> Unit,
    ) {
        auth.signInWithEmailLink(email, link).complete { _, error -> completed(error) }
    }

    override fun signOut(completed: (FriendsTransportError?) -> Unit) {
        try {
            auth.signOut()
            credentials.clearCredentialStateAsync(
                ClearCredentialStateRequest(),
                null,
                executor,
                object : CredentialManagerCallback<Void?, ClearCredentialException> {
                    override fun onResult(result: Void?) {
                        completed(null)
                    }

                    // Firebase is already signed out; provider cleanup must not restore a session.
                    override fun onError(e: ClearCredentialException) {
                        completed(null)
                    }
                },
            )
        } catch (_: Exception) {
            completed(FriendsTransportError.FAILED)
        }
    }
}

private fun ListenerRegistration.subscription() =
    object : FriendsSubscription {
        override fun cancel() = remove()
    }

private fun Exception.transportError() =
    if (
        this is FirebaseFunctionsException &&
            (details as? Map<*, *>)?.get("reason") == "key-auth-configuration"
    )
        FriendsTransportError.AUTH_CONFIGURATION
    else if (
        this is FirebaseFunctionsException &&
            code == FirebaseFunctionsException.Code.RESOURCE_EXHAUSTED
    )
        FriendsTransportError.RATE_LIMITED
    else if (
        this is FirebaseFunctionsException &&
            code == FirebaseFunctionsException.Code.UNAUTHENTICATED
    )
        FriendsTransportError.UNAUTHENTICATED
    else if (
        this is FirebaseFunctionsException &&
            code == FirebaseFunctionsException.Code.FAILED_PRECONDITION
    )
        FriendsTransportError.CONFLICT
    else if (this is FirebaseAuthUserCollisionException) FriendsTransportError.ACCOUNT_CONFLICT
    else if (
        this is FirebaseAuthException &&
            errorCode in listOf("ERROR_OPERATION_NOT_ALLOWED", "ERROR_INVALID_OAUTH_CLIENT_ID")
    )
        FriendsTransportError.AUTH_CONFIGURATION
    else if (
        this is FirebaseFirestoreException &&
            code == FirebaseFirestoreException.Code.PERMISSION_DENIED
    )
        FriendsTransportError.PERMISSION_DENIED
    else FriendsTransportError.FAILED

private fun <T> Task<T>.complete(completed: (T?, FriendsTransportError?) -> Unit) {
    addOnSuccessListener { completed(it, null) }
    addOnFailureListener { completed(null, it.transportError()) }
    addOnCanceledListener { completed(null, FriendsTransportError.CANCELLED) }
}

// Convert only at the SDK boundary; the shared controller owns the payload schema.
private fun JSONObject.toMap(): Map<String, Any?> =
    keys().asSequence().associateWith { key ->
        when (val value = get(key)) {
            JSONObject.NULL -> null
            is JSONObject -> value.toMap()
            is org.json.JSONArray -> value.toList()
            else -> value
        }
    }

private fun org.json.JSONArray.toList(): List<Any?> =
    (0 until length()).map { index ->
        when (val value = get(index)) {
            JSONObject.NULL -> null
            is JSONObject -> value.toMap()
            is org.json.JSONArray -> value.toList()
            else -> value
        }
    }

internal val FriendsError.androidString: Int
    get() =
        when (this) {
            FriendsError.GENERAL -> R.string.firebase_friends_error
            FriendsError.PUBLISH -> R.string.firebase_friends_publish_error
            FriendsError.INVALID_LINK -> R.string.firebase_friends_invalid_link
            FriendsError.AUTHENTICATION -> R.string.firebase_friends_auth_error
            FriendsError.AUTH_CONFIGURATION -> R.string.firebase_friends_auth_configuration
            FriendsError.ACCOUNT_CONFLICT -> R.string.firebase_friends_account_conflict
        }
