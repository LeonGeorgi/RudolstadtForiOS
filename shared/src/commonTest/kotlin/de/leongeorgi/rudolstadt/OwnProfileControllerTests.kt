package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.profile.*
import kotlin.test.*
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import kotlinx.serialization.json.*

@OptIn(ExperimentalCoroutinesApi::class)
class OwnProfileControllerTests {
    private val edition = "rudolstadt-2026"
    private val original =
        PersonalProfile(
            badgeName = "Alice",
            savedEventIDs = listOf(10),
            artistPreferences = listOf(ArtistPreference(7, 3)),
            artistNotes = listOf(ArtistNote(7, "PRIVATE ORIGINAL")),
        )

    private fun TestScope.controller(
        transport: Device,
        sendDelay: Long = 0,
        archiveSharing: Boolean = false,
    ): OwnProfileController {
        var sequence = 0
        return OwnProfileController(
                if (archiveSharing) "rudolstadt-2025" else edition,
                transport,
                CoroutineScope(
                    backgroundScope.coroutineContext +
                        SupervisorJob(backgroundScope.coroutineContext[Job])
                ),
                { 1700000000.0 + testScheduler.currentTime / 1000.0 },
                { transport.name + ":" + ++sequence },
                sendDelay,
                archiveSharing,
            )
            .also { runCurrent() }
    }

    @Test
    fun archiveKeepsExistingLocalDataAndSendsOnlyNewEditsAfterLoadingSharedData() = runTest {
        val server = Server()
        val device = Device("phone", server, original)
        device.archiveFallback =
            listOf(
                OwnProfileRecord(
                    "event:50",
                    ProfileVersion(-99_999_999_999_999.0, "archive-shared-fallback"),
                    ProfileRecordValue("event", 50, isSaved = true),
                )
            )
        device.holdWrites = true
        val controller = controller(device, archiveSharing = true)
        controller.mutate(ProfileMutation("setArtistRating", 12, 2))
        runCurrent()
        assertEquals(1, controller.current.pendingCount)
        assertEquals(0, server.writes)
        assertEquals(listOf(0), device.batchSizes)

        device.holdWrites = false
        device.pendingWrites.single()()
        runCurrent()
        assertEquals(OwnProfilePhase.READY, controller.current.phase)
        assertEquals(listOf(10L, 50L), controller.current.profile.savedEventIDs)
        assertEquals(original.artistNotes, controller.current.profile.artistNotes)
        assertEquals(listOf("rating:12"), server.values.getValue("alice").map { it.key })

        controller.mutate(ProfileMutation("toggleSavedEvent", 50))
        runCurrent()
        assertEquals(listOf(10L), controller.current.profile.savedEventIDs)
        val removed = server.values.getValue("alice").single { it.key == "event:50" }
        assertFalse(requireNotNull(removed.value).isSaved)
        assertEquals(listOf(0, 1, 1), device.batchSizes)
    }

    private fun note(value: String, date: Double = 20.0, id: String = "cloud-note") =
        OwnProfileRecord(
            "note:7",
            ProfileVersion(date, id),
            ProfileRecordValue("note", 7, noteText = value),
        )

    @Test
    fun importsLocalDataIncludingPrivateNotesAndRetainsAnImmutableBackup() = runTest {
        val server = Server()
        val device = Device("phone", server, original)
        val controller = controller(device)
        assertEquals(OwnProfilePhase.READY, controller.current.phase)
        assertEquals(listOf(10L), controller.current.profile.savedEventIDs)
        assertEquals("PRIVATE ORIGINAL", controller.current.profile.artistNotes.single().noteText)
        assertTrue(controller.current.migrationComplete)
        assertTrue(server.noteHistory.any { it.value?.noteText == "PRIVATE ORIGINAL" })
        val journal = OwnProfileData.decodeJournal(requireNotNull(device.disk))
        assertTrue(journal.legacyBackup.any { it.value?.noteText == "PRIVATE ORIGINAL" })
    }

    @Test
    fun initialImportIsOnlyCompleteAfterTheServerAcknowledgesItsDurableQueue() = runTest {
        val device = Device("phone", Server(), original)
        device.holdWrites = true
        val controller = controller(device)
        assertFalse(controller.current.migrationComplete)
        assertTrue(controller.current.pendingCount > 0)
        assertEquals(original.artistNotes, controller.current.profile.artistNotes)
        assertNotNull(device.disk)
        device.pendingWrites.single()()
        runCurrent()
        assertTrue(controller.current.migrationComplete)
        assertEquals(OwnProfilePhase.READY, controller.current.phase)
    }

    @Test
    fun retryAfterTheInitialDiskFailureStillBindsAndImportsTheLocalProfile() = runTest {
        val device = Device("phone", Server(), original)
        device.storageFailure = true
        val controller = controller(device)
        assertEquals(OwnProfileProblem.LOCAL_STORAGE, controller.current.problem)
        assertEquals(0, device.server.writes)
        device.storageFailure = false
        controller.retry()
        runCurrent()
        assertEquals("alice", controller.current.uid)
        assertEquals(OwnProfilePhase.READY, controller.current.phase)
        assertEquals("PRIVATE ORIGINAL", controller.current.profile.artistNotes.single().noteText)
        assertTrue(controller.current.migrationComplete)
    }

    @Test
    fun storageFailureNeverResetsOrUploadsExistingDataAndRetrySavesThePendingEdit() = runTest {
        val server = Server()
        val device = Device("phone", server, original)
        val controller = controller(device)
        val stored = device.disk
        val writes = server.writes
        device.storageFailure = true
        controller.mutate(ProfileMutation("setArtistNote", 7, text = "UNSAVED PRIVATE"))
        runCurrent()
        assertEquals(OwnProfileProblem.LOCAL_STORAGE, controller.current.problem)
        assertEquals(stored, device.disk)
        assertEquals(writes, server.writes)
        assertEquals("UNSAVED PRIVATE", controller.current.profile.artistNotes.single().noteText)
        device.storageFailure = false
        controller.retry()
        runCurrent()
        assertEquals(OwnProfilePhase.READY, controller.current.phase)
        assertEquals(
            "UNSAVED PRIVATE",
            server.values.getValue("alice").first { it.key == "note:7" }.value?.noteText,
        )
    }

    @Test
    fun offlineQueueSurvivesRestartAndIndependentEditsOnTwoDevicesMerge() = runTest {
        val server = Server()
        val one = Device("one", server, original)
        var first = controller(one)
        one.connected = false
        first.mutate(ProfileMutation("toggleSavedEvent", 22))
        runCurrent()
        assertTrue(first.current.pendingCount > 0)
        first.close()
        val two = Device("two", server)
        val second = controller(two)
        second.mutate(ProfileMutation("setArtistNote", 8, text = "OTHER DEVICE NOTE"))
        runCurrent()
        one.connected = true
        first = controller(one)
        assertEquals(OwnProfilePhase.READY, first.current.phase)
        assertEquals(listOf(10L, 22L), first.current.profile.savedEventIDs)
        assertTrue(
            first.current.profile.artistNotes.any {
                it.artistID == 8L && it.noteText == "OTHER DEVICE NOTE"
            }
        )
        assertEquals(first.current.profile, second.current.profile)
    }

    @Test
    fun deletionTombstonesPreventStaleDevicesFromResurrectingNotesAndSavedEvents() = runTest {
        val server = Server()
        val one = Device("one", server, original)
        val first = controller(one)
        val stale = Device("stale", server, original)
        stale.connected = false
        val second = controller(stale)
        first.mutate(ProfileMutation("setArtistNote", 7, text = ""))
        first.mutate(ProfileMutation("toggleSavedEvent", 10))
        runCurrent()
        stale.connected = true
        second.retry()
        runCurrent()
        assertTrue(second.current.profile.artistNotes.isEmpty())
        assertTrue(second.current.profile.savedEventIDs.isEmpty())
        assertTrue(server.values.getValue("alice").first { it.key == "note:7" }.value!!.isDeleted)
        assertTrue(server.noteHistory.any { it.value?.noteText == "PRIVATE ORIGINAL" })
    }

    @Test
    fun accountSwitchNeverCopiesPrivateDataToAnotherAccountAndReturningRestoresIt() = runTest {
        val server = Server()
        val device = Device("phone", server, original)
        val controller = controller(device)
        controller.mutate(ProfileMutation("setArtistNote", 7, text = "ALICE ONLY"))
        runCurrent()
        val oldListener = server.listeners.last()
        device.account("bob")
        runCurrent()
        assertEquals("bob", controller.current.uid)
        assertTrue(controller.current.profile.artistNotes.isEmpty())
        assertTrue(server.values["bob"].orEmpty().isEmpty())
        oldListener.callback(
            OwnProfileData.encodeRecords(listOf(note("LATE ALICE", 9e9))),
            true,
            null,
        )
        runCurrent()
        assertTrue(controller.current.profile.artistNotes.isEmpty())
        controller.mutate(ProfileMutation("setArtistNote", 9, text = "BOB ONLY"))
        runCurrent()
        device.account("alice")
        runCurrent()
        assertEquals("ALICE ONLY", controller.current.profile.artistNotes.single().noteText)
        assertFalse(server.values.getValue("alice").any { it.value?.noteText == "BOB ONLY" })
        device.account("bob")
        runCurrent()
        assertEquals("BOB ONLY", controller.current.profile.artistNotes.single().noteText)
    }

    @Test
    fun anEmptyNewDeviceDoesNotOverwriteTheExistingBadge() = runTest {
        val server = Server()
        val first = controller(Device("one", server, original))
        val second = controller(Device("two", server))
        assertEquals("Alice", first.current.profile.badgeName)
        assertEquals("Alice", second.current.profile.badgeName)
    }

    @Test
    fun inFlightAcknowledgementDoesNotEraseANewerLocalEditOrAChangeOnAnotherAccount() = runTest {
        val server = Server()
        val device = Device("phone", server, original)
        val controller = controller(device)
        device.holdWrites = true
        controller.mutate(ProfileMutation("setArtistNote", 7, text = "FIRST"))
        runCurrent()
        val firstRequest = device.pendingWrites.single()
        controller.mutate(ProfileMutation("setArtistNote", 7, text = "SECOND"))
        runCurrent()
        firstRequest()
        runCurrent()
        assertEquals("SECOND", controller.current.profile.artistNotes.single().noteText)
        device.pendingWrites.last()()
        runCurrent()
        assertEquals(
            "SECOND",
            server.values.getValue("alice").first { it.key == "note:7" }.value?.noteText,
        )
        controller.mutate(ProfileMutation("setArtistNote", 7, text = "ALICE LATE"))
        runCurrent()
        val delayed = device.pendingWrites.last()
        device.account("bob")
        runCurrent()
        delayed()
        runCurrent()
        assertEquals("bob", controller.current.uid)
        assertTrue(controller.current.profile.artistNotes.isEmpty())
    }

    @Test
    fun locallyStoredDeletionVersionsRemainTombstonesDuringImport() = runTest {
        val server = Server()
        server.sync("alice", listOf(note("OLD REMOTE NOTE", 1.0)))
        val device = Device("phone", server, original.copy(artistNotes = emptyList()))
        device.localChanges =
            listOf(
                ProfileRecordChange(
                    "note:7",
                    ProfileRecordValue("note", 7, noteText = ""),
                    ProfileVersion(20.0, "local-deletion"),
                )
            )
        val controller = controller(device)
        assertTrue(controller.current.profile.artistNotes.isEmpty())
        assertEquals(listOf(10L), controller.current.profile.savedEventIDs)
        assertTrue(server.noteHistory.any { it.value?.noteText == "OLD REMOTE NOTE" })
    }

    @Test
    fun networkFailureRetriesWithBackoffWithoutDroppingTheDurableQueue() = runTest {
        val server = Server()
        val device = Device("phone", server, original)
        val controller = controller(device)
        device.connected = false
        controller.mutate(ProfileMutation("setArtistNote", 7, text = "RETRY PRIVATE"))
        runCurrent()
        assertEquals(OwnProfileProblem.CONNECTION, controller.current.problem)
        assertEquals(1, device.server.writes)
        device.connected = true
        advanceTimeBy(1000)
        runCurrent()
        assertEquals(OwnProfilePhase.READY, controller.current.phase)
        assertEquals(
            "RETRY PRIVATE",
            server.values.getValue("alice").first { it.key == "note:7" }.value?.noteText,
        )
    }

    @Test
    fun aLostResponseAfterServerCommitIsSafelyRetried() = runTest {
        val device = Device("phone", Server(), original)
        device.failAfterWrite = true
        val controller = controller(device)
        assertFalse(controller.current.migrationComplete)
        assertTrue(controller.current.pendingCount > 0)
        assertEquals(OwnProfileProblem.CONNECTION, controller.current.problem)
        assertEquals(1, device.server.writes)
        device.failAfterWrite = false
        controller.retry()
        runCurrent()
        assertEquals(OwnProfilePhase.READY, controller.current.phase)
        assertEquals(original.artistNotes, controller.current.profile.artistNotes)
        assertTrue(controller.current.migrationComplete)
    }

    @Test
    fun corruptLocalJournalDoesNotFallBackToAnEmptyProfile() = runTest {
        val device = Device("phone", Server(), original)
        device.disk = "not json"
        val controller = controller(device)
        assertEquals(OwnProfileProblem.LOCAL_STORAGE, controller.current.problem)
        assertFalse(controller.current.initialized)
        assertEquals("not json", device.disk)
        assertEquals(0, device.server.writes)
    }

    @Test
    fun largeMultilineNotesAndLongOfflineQueuesAreTransferredInBoundedBatches() = runTest {
        val text = "Private line 😀\n".repeat(10000)
        val server = Server()
        val device =
            Device("phone", server, original.copy(artistNotes = listOf(ArtistNote(7, text))))
        device.connected = false
        val controller = controller(device)
        for (id in 100L..230L) controller.mutate(ProfileMutation("toggleSavedEvent", id))
        runCurrent()
        device.connected = true
        controller.retry()
        runCurrent()
        assertEquals(OwnProfilePhase.READY, controller.current.phase)
        assertEquals(text, controller.current.profile.artistNotes.single().noteText)
        assertTrue(device.batchSizes.all { it <= 50 })
        assertEquals(132, controller.current.profile.savedEventIDs.size)
    }

    @Test
    fun typingIsPersistedImmediatelyButOnlyTheFinalDraftIsUploadedAfterTheDelay() = runTest {
        val server = Server()
        val device = Device("phone", server, original)
        val controller = controller(device, 600)
        val writes = server.writes
        for (text in listOf("F", "FI", "FINAL NOTE")) {
            controller.mutate(ProfileMutation("setArtistNote", 7, text = text))
            runCurrent()
            advanceTimeBy(100)
        }
        assertEquals(writes, server.writes)
        assertEquals(
            "FINAL NOTE",
            OwnProfileData.profile(
                    OwnProfileData.decodeJournal(requireNotNull(device.disk)).replica().records
                )
                .artistNotes
                .single()
                .noteText,
        )
        advanceTimeBy(600)
        runCurrent()
        assertEquals(writes + 1, server.writes)
        assertFalse(server.noteHistory.any { it.value?.noteText in listOf("F", "FI") })
        assertEquals("FINAL NOTE", controller.current.profile.artistNotes.single().noteText)
    }

    private class Subscription : FriendsSubscription {
        var cancelled = false

        override fun cancel() {
            cancelled = true
        }
    }

    private class Listener(
        val owner: String,
        val online: () -> Boolean,
        val callback: (String?, Boolean, FriendsTransportError?) -> Unit,
    ) {
        val subscription = Subscription()
    }

    private class Server {
        val values = mutableMapOf<String, List<OwnProfileRecord>>()
        val noteHistory = mutableListOf<OwnProfileRecord>()
        val listeners = mutableListOf<Listener>()
        var writes = 0

        fun sync(owner: String, input: List<OwnProfileRecord>): String {
            writes++
            noteHistory += input.filter {
                it.value?.kind == "note" && it.value.noteText.isNotEmpty()
            }
            values[owner] = OwnProfileData.merge(values[owner].orEmpty(), input)
            for (listener in
                listeners.filter {
                    it.owner == owner && it.online() && !it.subscription.cancelled
                }) listener.callback(
                OwnProfileData.encodeRecords(values.getValue(owner)),
                true,
                null,
            )
            return buildJsonObject {
                put(
                    "records",
                    Json.parseToJsonElement(
                        OwnProfileData.encodeRecords(
                            values.getValue(owner).filter { record ->
                                input.any { it.key == record.key }
                            }
                        )
                    ),
                )
            }
                .toString()
        }
    }

    private class Device(
        val name: String,
        val server: Server,
        private val initial: PersonalProfile = PersonalProfile(),
    ) : OwnProfileTransport {
        var disk: String? = null
        var owner = "alice"
        lateinit var account: (String?) -> Unit
        var connected = true
        var storageFailure = false
        var localChanges: List<ProfileRecordChange> = emptyList()
        var failAfterWrite = false
        var holdWrites = false
        var archiveFallback = emptyList<OwnProfileRecord>()
        val pendingWrites = mutableListOf<() -> Unit>()
        val batchSizes = mutableListOf<Int>()

        override fun observeAccount(changed: (String?) -> Unit): FriendsSubscription {
            account = {
                owner = it ?: ""
                changed(it)
            }
            changed(owner.ifEmpty { null })
            return Subscription()
        }

        override fun loadLocal(completed: (String?, FriendsTransportError?) -> Unit) {
            try {
                completed(OwnProfileData.encodeLocal(disk, initial, localChanges), null)
            } catch (_: Exception) {
                completed(null, FriendsTransportError.FAILED)
            }
        }

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
            val listener = Listener(owner, { connected }, changed)
            server.listeners += listener
            changed(OwnProfileData.encodeRecords(server.values[owner].orEmpty()), connected, null)
            return listener.subscription
        }

        override fun syncRecords(
            payload: String,
            completed: (String?, FriendsTransportError?) -> Unit,
        ) {
            val data = Json.parseToJsonElement(payload).jsonObject
            val input = OwnProfileData.decodeRecords(data.getValue("records").toString())
            val archiveSharing = data["archiveSharing"]?.jsonPrimitive?.boolean == true
            batchSizes += input.size
            val requestedOwner = owner
            val payloadOwner = data.getValue("owner").jsonPrimitive.content
            val execute = {
                if (!connected || requestedOwner != payloadOwner)
                    completed(null, FriendsTransportError.FAILED)
                else {
                    val result =
                        if (archiveSharing) {
                            assertEquals("rudolstadt-2025", data.getValue("edition").jsonPrimitive.content)
                            val records =
                                if (input.isEmpty()) {
                                    Json.parseToJsonElement(OwnProfileData.encodeRecords(archiveFallback))
                                } else {
                                    Json.parseToJsonElement(server.sync(requestedOwner, input)).jsonObject.getValue("records")
                                }
                            buildJsonObject {
                                put("archiveSharing", true)
                                put("records", records)
                            }.toString()
                        } else server.sync(requestedOwner, input)
                    if (failAfterWrite) completed(null, FriendsTransportError.FAILED)
                    else completed(result, null)
                }
            }
            if (holdWrites) pendingWrites += execute else execute()
        }
    }
}
