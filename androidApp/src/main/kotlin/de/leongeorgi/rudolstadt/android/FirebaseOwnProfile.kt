package de.leongeorgi.rudolstadt.android

import android.content.Context
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreException
import com.google.firebase.firestore.MetadataChanges
import de.leongeorgi.rudolstadt.android.data.*
import de.leongeorgi.rudolstadt.profile.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.first
import kotlinx.serialization.json.Json
import org.json.JSONArray

/** Only Firebase, DataStore and JSON boundaries; replica and migration rules are shared. */
internal class FirebaseOwnProfile(
    context: Context,
    private val account: FirebaseFriends,
    private val ioScope: CoroutineScope,
    edition: Edition = Edition.current,
) : OwnProfileTransport {
    private val store = context.localSettings
    private val editionKey = edition.key
    val controller = OwnProfileController(editionKey, this, archiveSharing = edition.archive)

    fun close() = controller.close()

    override fun checkAccountDeleted(owner: String, completed: (Boolean) -> Unit) {
        account.call(
            "accountDeletionStatus",
            org.json.JSONObject(mapOf("owner" to owner)).toString(),
        ) { result, error ->
            completed(
                error == null &&
                    result?.let { org.json.JSONObject(it).optBoolean("deleted") } == true
            )
        }
    }

    override fun signOutDeletedAccount(owner: String, completed: (FriendsTransportError?) -> Unit) =
        account.signOutDeletedAccount(owner, completed)

    override fun observeAccount(changed: (String?) -> Unit): FriendsSubscription {
        if (account.configured) return account.observeAccount(changed)
        changed(null)
        return object : FriendsSubscription {
            override fun cancel() {}
        }
    }

    override fun loadLocal(completed: (String?, FriendsTransportError?) -> Unit) {
        ioScope.launch {
            try {
                val settings = store.data.first()
                completed(
                    OwnProfileData.encodeLocal(
                        settings.ownProfileSync[editionKey],
                        settings.profile(editionKey),
                        emptyList(),
                    ),
                    null,
                )
            } catch (cancelled: CancellationException) {
                completed(null, FriendsTransportError.CANCELLED)
                throw cancelled
            } catch (_: Exception) {
                completed(null, FriendsTransportError.FAILED)
            }
        }
    }

    override fun saveLocal(
        journal: String,
        profile: String,
        completed: (FriendsTransportError?) -> Unit,
    ) {
        ioScope.launch {
            try {
                val value = Json.decodeFromString<PersonalProfile>(profile)
                store.updateData {
                    it.copy(
                        ownProfileSync = it.ownProfileSync + (editionKey to journal),
                        profiles = it.profiles + (editionKey to value),
                    )
                }
                completed(null)
            } catch (cancelled: CancellationException) {
                completed(FriendsTransportError.CANCELLED)
                throw cancelled
            } catch (_: Exception) {
                completed(FriendsTransportError.FAILED)
            }
        }
    }

    override fun observeRecords(
        edition: String,
        owner: String,
        changed: (String?, Boolean, FriendsTransportError?) -> Unit,
    ): FriendsSubscription {
        val registration =
            FirebaseFirestore.getInstance()
                .collection("users")
                .document(owner)
                .collection("profileEditions")
                .document(edition)
                .collection("records")
                .addSnapshotListener(MetadataChanges.INCLUDE) { snapshot, error ->
                    if (error != null || snapshot == null)
                        changed(
                            null,
                            false,
                            if (
                                (error as? FirebaseFirestoreException)?.code ==
                                    FirebaseFirestoreException.Code.PERMISSION_DENIED
                            )
                                FriendsTransportError.PERMISSION_DENIED
                            else FriendsTransportError.FAILED,
                        )
                    else {
                        val json =
                            try {
                                JSONArray(snapshot.documents.map { it.data }).toString()
                            } catch (_: Exception) {
                                null
                            }
                        changed(
                            json,
                            !snapshot.metadata.isFromCache,
                            if (json == null) FriendsTransportError.FAILED else null,
                        )
                    }
                }
        return object : FriendsSubscription {
            override fun cancel() = registration.remove()
        }
    }

    override fun syncRecords(
        payload: String,
        completed: (String?, FriendsTransportError?) -> Unit,
    ) = account.call("syncOwnProfile", payload, completed)
}
