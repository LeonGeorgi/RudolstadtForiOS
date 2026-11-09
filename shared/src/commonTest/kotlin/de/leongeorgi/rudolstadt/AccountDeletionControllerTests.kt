package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.profile.*
import kotlin.test.*
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import kotlinx.serialization.json.*

@OptIn(ExperimentalCoroutinesApi::class)
class AccountDeletionControllerTests {
    private val original =
        PersonalProfile(
            badgeName = "Alice",
            savedEventIDs = listOf(42),
            artistNotes = listOf(ArtistNote(7, "PRIVATE NOTE")),
        )

    private fun TestScope.scope() =
        CoroutineScope(
            backgroundScope.coroutineContext + SupervisorJob(backgroundScope.coroutineContext[Job])
        )

    private fun TestScope.profile(device: Device) =
        OwnProfileController("rudolstadt-2026", device, scope(), { 10.0 }, { "change" }, 600).also {
            runCurrent()
        }

    private fun TestScope.deletion(device: Device, profile: OwnProfileController) =
        AccountDeletionController(device, profile, AccountActionGate(), scope()).also {
            runCurrent()
        }

    private fun AccountDeletionController.confirm() = deleteAccount { _, completed ->
        completed(null)
    }

    @Test
    fun deletionKeepsTheSyncedProfileAndOfflineEditsLocallyAcrossRestart() = runTest {
        val device = Device(original)
        val profile = profile(device)
        profile.mutate(ProfileMutation("setArtistNote", 7, text = "UNSENT PRIVATE EDIT"))
        runCurrent()
        val expected = profile.current.profile
        val deletion = deletion(device, profile)
        deletion.confirm()
        runCurrent()
        assertTrue(deletion.current.deleted)
        assertNull(profile.current.uid)
        assertEquals(OwnProfilePhase.LOCAL, profile.current.phase)
        assertEquals(expected, profile.current.profile)
        val journal = OwnProfileData.decodeJournal(requireNotNull(device.disk))
        assertFalse("alice" in journal.accounts)
        assertTrue("alice" in journal.detachedOwners)
        assertNull(journal.pendingDeletion)
        assertFalse(device.calls.single().contains("PRIVATE"))
        val writes = device.writes
        advanceTimeBy(5000)
        runCurrent()
        assertEquals(writes, device.writes)
        deletion.close()
        profile.close()
        val restored = profile(device)
        assertEquals(expected, restored.current.profile)
        assertEquals(OwnProfilePhase.LOCAL, restored.current.phase)
        device.account("alice")
        runCurrent()
        assertNull(restored.current.uid)
        assertEquals(writes, device.writes)
    }

    @Test
    fun diskFailureBlocksRemoteDeletionAndRetryMustPersistFirst() = runTest {
        val device = Device(original)
        val profile = profile(device)
        val deletion = deletion(device, profile)
        device.storageFailure = true
        deletion.confirm()
        runCurrent()
        assertEquals(AccountDeletionProblem.LOCAL_STORAGE, deletion.current.problem)
        assertTrue(device.calls.isEmpty())
        deletion.retry()
        runCurrent()
        assertTrue(device.calls.isEmpty())
        assertEquals(original.artistNotes, profile.current.profile.artistNotes)
        device.storageFailure = false
        deletion.retry()
        runCurrent()
        assertTrue(deletion.current.deleted)
        assertEquals(original.artistNotes, profile.current.profile.artistNotes)
    }

    @Test
    fun lostResponseResumesTheSameAuthorizedRequestAfterProcessRestartAndSignOut() = runTest {
        val device = Device(original).apply { failDeletion = true }
        var profile = profile(device)
        var deletion = deletion(device, profile)
        deletion.confirm()
        runCurrent()
        assertTrue(deletion.current.pending)
        assertEquals(AccountDeletionProblem.CONNECTION, deletion.current.problem)
        assertNotNull(OwnProfileData.decodeJournal(requireNotNull(device.disk)).pendingDeletion)
        val payload = device.calls.single()
        deletion.close()
        profile.close()
        device.uid = null
        device.failDeletion = false
        profile = profile(device)
        deletion = deletion(device, profile)
        assertEquals(payload, device.calls.last())
        assertTrue(deletion.current.deleted)
        assertEquals(original.artistNotes, profile.current.profile.artistNotes)
        assertEquals(OwnProfilePhase.LOCAL, profile.current.phase)
    }

    @Test
    fun aFinalDiskFailureRetainsTheDurableReceiptAndCanFinishAfterSignOut() = runTest {
        val device = Device(original).apply { failFinalSave = true }
        val profile = profile(device)
        val deletion = deletion(device, profile)
        deletion.confirm()
        runCurrent()
        assertNull(device.uid)
        assertTrue(deletion.current.pending)
        assertEquals(AccountDeletionProblem.LOCAL_STORAGE, deletion.current.problem)
        assertNotNull(profile.pendingDeletion)
        device.failFinalSave = false
        device.storageFailure = false
        deletion.retry()
        runCurrent()
        assertTrue(deletion.current.deleted)
        assertEquals(original.artistNotes, profile.current.profile.artistNotes)
        assertNull(OwnProfileData.decodeJournal(requireNotNull(device.disk)).pendingDeletion)
    }

    @Test
    fun aConcurrentAccountChangeDoesNotCopyTheRetainedNotesIntoTheOtherAccount() = runTest {
        val device = Device(original).apply { holdDeletion = true }
        val profile = profile(device)
        val deletion = deletion(device, profile)
        deletion.confirm()
        runCurrent()
        device.account("bob")
        runCurrent()
        device.pendingResponse?.invoke("""{"deleted":true}""", null)
        runCurrent()
        assertEquals("bob", device.uid)
        assertEquals("bob", profile.current.uid)
        assertTrue(profile.current.profile.artistNotes.isEmpty())
        val journal = OwnProfileData.decodeJournal(requireNotNull(device.disk))
        assertEquals(
            original.artistNotes,
            OwnProfileData.profile(journal.anonymous.records).artistNotes,
        )
        assertTrue(journal.replica("bob").queued.isEmpty())
    }

    @Test
    fun cancellingNativeConfirmationLeavesTheAccountAndSyncUntouched() = runTest {
        val device = Device(original)
        val profile = profile(device)
        val deletion = deletion(device, profile)
        deletion.deleteAccount { _, completed -> completed(FriendsTransportError.CANCELLED) }
        runCurrent()
        assertEquals("alice", profile.current.uid)
        assertNull(profile.pendingDeletion)
        assertFalse(deletion.current.busy)
        assertTrue(device.calls.isEmpty())
    }

    @Test
    fun permissionFailureConfirmsRemoteDeletionBeforeKeepingTheLocalReplica() = runTest {
        val device = Device(original)
        val profile = profile(device)
        device.deletedOnServer = true
        device.recordListener?.invoke(null, true, FriendsTransportError.PERMISSION_DENIED)
        runCurrent()
        assertNull(profile.current.uid)
        assertNull(device.uid)
        assertEquals(original.artistNotes, profile.current.profile.artistNotes)
        assertEquals(OwnProfilePhase.LOCAL, profile.current.phase)
        assertTrue(
            "alice" in OwnProfileData.decodeJournal(requireNotNull(device.disk)).detachedOwners
        )
    }

    @Test
    fun aTemporaryPermissionErrorDoesNotDetachOrDiscardTheProfile() = runTest {
        val device = Device(original)
        val profile = profile(device)
        device.recordListener?.invoke(null, true, FriendsTransportError.PERMISSION_DENIED)
        runCurrent()
        assertEquals("alice", profile.current.uid)
        assertEquals(OwnProfileProblem.CONNECTION, profile.current.problem)
        assertEquals(original.artistNotes, profile.current.profile.artistNotes)
        assertTrue(
            OwnProfileData.decodeJournal(requireNotNull(device.disk)).detachedOwners.isEmpty()
        )
    }

    @Test
    fun lateResponsesAfterClosingCannotSignOutOrChangeAnotherAccount() = runTest {
        val device = Device(original).apply { holdDeletion = true }
        val profile = profile(device)
        val deletion = deletion(device, profile)
        deletion.confirm()
        runCurrent()
        deletion.close()
        device.account("bob")
        runCurrent()
        device.pendingResponse?.invoke("""{"deleted":true}""", null)
        runCurrent()
        assertEquals("bob", device.uid)
        assertEquals(0, device.signOuts)
        assertEquals(original.artistNotes, profile.current.profile.artistNotes)
    }

    private class Device(val initial: PersonalProfile) :
        OwnProfileTransport, AccountDeletionTransport {
        var uid: String? = "alice"
        var disk: String? = null
        var storageFailure = false
        var failFinalSave = false
        var failDeletion = false
        var holdDeletion = false
        var deletedOnServer = false
        var writes = 0
        var signOuts = 0
        val calls = mutableListOf<String>()
        private val observers = mutableListOf<(String?) -> Unit>()
        var recordListener: ((String?, Boolean, FriendsTransportError?) -> Unit)? = null
        var pendingResponse: ((String?, FriendsTransportError?) -> Unit)? = null

        fun account(owner: String?) {
            uid = owner
            observers.toList().forEach { it(owner) }
        }

        override fun observeAccount(changed: (String?) -> Unit): FriendsSubscription {
            observers += changed
            changed(uid)
            return object : FriendsSubscription {
                override fun cancel() {
                    observers -= changed
                }
            }
        }

        override fun loadLocal(completed: (String?, FriendsTransportError?) -> Unit) =
            completed(OwnProfileData.encodeLocal(disk, initial, emptyList()), null)

        override fun saveLocal(
            journal: String,
            profile: String,
            completed: (FriendsTransportError?) -> Unit,
        ) {
            if (storageFailure) completed(FriendsTransportError.FAILED)
            else {
                disk = journal
                completed(null)
            }
        }

        override fun observeRecords(
            edition: String,
            owner: String,
            changed: (String?, Boolean, FriendsTransportError?) -> Unit,
        ): FriendsSubscription {
            recordListener = changed
            changed("[]", true, null)
            return object : FriendsSubscription {
                override fun cancel() {
                    if (recordListener === changed) recordListener = null
                }
            }
        }

        override fun syncRecords(
            payload: String,
            completed: (String?, FriendsTransportError?) -> Unit,
        ) {
            writes++
            val records = Json.parseToJsonElement(payload).jsonObject.getValue("records")
            completed("""{"records":$records}""", null)
        }

        override fun secureKeyEntropy() = "ab".repeat(20)

        override fun signOutDeletedAccount(
            owner: String,
            completed: (FriendsTransportError?) -> Unit,
        ) {
            if (uid == owner) {
                signOuts++
                if (failFinalSave) storageFailure = true
                account(null)
            }
            completed(null)
        }

        override fun checkAccountDeleted(owner: String, completed: (Boolean) -> Unit) =
            completed(deletedOnServer)

        override fun call(
            name: String,
            payload: String,
            completed: (String?, FriendsTransportError?) -> Unit,
        ) {
            assertEquals("deleteAccount", name)
            assertNotNull(
                OwnProfileData.decodeJournal(requireNotNull(disk)).pendingDeletion,
                "Must persist before calling Firebase",
            )
            calls += payload
            if (holdDeletion) pendingResponse = completed
            else if (failDeletion) completed(null, FriendsTransportError.FAILED)
            else completed("""{"deleted":true}""", null)
        }
    }
}
