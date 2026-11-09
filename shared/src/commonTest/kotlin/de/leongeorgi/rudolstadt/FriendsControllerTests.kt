package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.profile.*
import kotlin.test.*
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import kotlinx.serialization.json.*

@OptIn(ExperimentalCoroutinesApi::class)
class FriendsControllerTests {
    private val owner =
        PersonalProfile(
            badgeName = "Alice",
            badgeHue = 30.0,
            savedEventIDs = listOf(42),
            artistPreferences = listOf(ArtistPreference(7, 3)),
            artistNotes = listOf(ArtistNote(7, "PRIVATE")),
        )
    private val invite = FriendInvite("a".repeat(43))
    private val all = FriendPermissions(true, true)
    private val none = FriendPermissions()
    private val bob = FriendIdentity("Bob", 210.0)

    private fun TestScope.controller(
        device: Device = Device(),
        edition: String = "rudolstadt-2026",
    ): FriendsController =
        FriendsController(
                edition,
                device,
                CoroutineScope(
                    backgroundScope.coroutineContext +
                        SupervisorJob(backgroundScope.coroutineContext[Job])
                ),
            )
            .also { runCurrent() }

    private fun TestScope.active(device: Device = Device()) =
        controller(device).also {
            it.syncProfile(owner, "alice", true)
            it.activate(owner)
            runCurrent()
        }

    @Test
    fun emailDeliveryOnlyChangesAfterSuccessfulSendsAndClearsOnSignIn() = runTest {
        val device = Device().apply { uid = null }
        val controller = controller(device)
        val address = "lea@example.com"
        controller.sendEmail("  $address  ")
        runCurrent()
        val first = EmailLinkDelivery(address, revision = 1, isResend = false)
        assertEquals(first, controller.current.emailDelivery)
        assertTrue(controller.current.emailSent)
        assertEquals(address, device.emailRecipient)

        device.errors["sendEmail"] = FriendsTransportError.FAILED
        controller.sendEmail("other@example.com")
        runCurrent()
        assertEquals(first, controller.current.emailDelivery)
        assertNotNull(controller.current.error)

        device.errors.remove("sendEmail")
        controller.sendEmail(address)
        runCurrent()
        assertEquals(
            EmailLinkDelivery(address, revision = 2, isResend = true),
            controller.current.emailDelivery,
        )

        val newAddress = "other@example.com"
        controller.sendEmail(newAddress)
        runCurrent()
        assertEquals(
            EmailLinkDelivery(newAddress, revision = 3, isResend = false),
            controller.current.emailDelivery,
        )

        val link = "https://${FriendsConfiguration.authDomain}/__/auth/action?oobCode=sample"
        assertTrue(controller.receive(link))
        controller.dismissEmailLink()
        assertNull(controller.current.loginLink)
        assertTrue(controller.current.emailSent)
        assertTrue(controller.receive(link))
        controller.finishEmail(newAddress, link)
        runCurrent()
        assertNull(controller.current.loginLink)
        assertFalse(controller.current.emailSent)
    }

    @Test
    fun identitiesAndFriendshipsLoadWithoutActivatingOrPublishingAFestival() = runTest {
        val device =
            Device().apply {
                identities["alice"] = FriendIdentity("Alice", 210.0)
                identities["bob"] = bob
                records = listOf(FriendshipRecord("bob"))
            }
        val first = controller(device)
        assertTrue(first.current.active)
        assertTrue(first.current.identityLoaded)
        assertEquals("Bob", first.current.connections.single().name)
        assertTrue(device.calls.isEmpty())
        first.close()
        val second = controller(device, "other-festival-2027")
        assertEquals("bob", second.current.connections.single().uid)
        assertEquals(2027, second.current.friends.single().year)
        assertTrue(device.calls.isEmpty())
    }

    @Test
    fun archiveUsesGlobalFriendsAndOnlyReadsDataFromTheSelectedYear() = runTest {
        val device =
            Device().apply {
                identities["bob"] = bob
                archiveCategories["rudolstadt-2024"] =
                    mapOf(
                        "savedEvents" to """{"savedEventIDs":[24]}""",
                        "ratings" to """{"artistPreferences":[{"artistID":7,"rating":2}]}""",
                    )
                archiveCategories["rudolstadt-2025"] = emptyMap()
            }
        val controller = active(device)
        device.emit(listOf(FriendshipRecord("bob", none, all)))
        runCurrent()
        val identity = device.watches.single { it.uid == "bob" && it.kind == "identity" }
        val live = device.watches.single { it.kind == "savedEvents" }

        controller.showArchive("rudolstadt-2025")
        runCurrent()
        assertEquals("Bob", controller.current.connections.single().name)
        val emptyArchive = controller.current.archiveFriends.single()
        assertEquals(2025, emptyArchive.year)
        assertTrue(emptyArchive.saved.isEmpty())
        assertTrue(emptyArchive.preferences.isEmpty())
        val late = device.watches.last { it.kind == "savedEvents" }

        controller.showArchive("rudolstadt-2024")
        assertTrue(controller.current.archiveFriends.isEmpty())
        late.changed("""{"savedEventIDs":[25]}""", null)
        runCurrent()
        assertTrue(late.cancelled)
        assertFalse(identity.cancelled)
        assertFalse(live.cancelled)
        assertEquals(listOf(42L), controller.current.friends.single().saved)
        assertEquals(listOf(24L), controller.current.archiveFriends.single().saved)
        assertEquals(
            listOf(ArtistPreference(7, 2)),
            controller.current.archiveFriends.single().preferences,
        )

        controller.syncProfile(owner.copy(savedEventIDs = listOf(99)), "alice", true)
        advanceTimeBy(600)
        runCurrent()
        val publications = device.calls.filter { it.name == "publishFriendProfile" }
        assertEquals(2, publications.size)
        assertEquals(
            "[99]",
            publications.last().body.getValue("profile").jsonObject["savedEventIDs"].toString(),
        )
        assertTrue(
            publications.all {
                it.body.getValue("edition").jsonPrimitive.content == "rudolstadt-2026"
            }
        )

        device.emit(listOf(FriendshipRecord("bob", none, FriendPermissions(false, true))))
        runCurrent()
        assertTrue(controller.current.friends.single().saved.isEmpty())
        assertTrue(controller.current.archiveFriends.single().saved.isEmpty())
        controller.showArchive(null)
        assertTrue(controller.current.archiveFriends.isEmpty())
        assertEquals("Bob", controller.current.connections.single().name)
    }

    @Test
    fun setupWaitsForTheCurrentAccountsIdentityLookup() = runTest {
        val device = Device().apply { deferIdentity = true }
        val controller = controller(device)
        val alice = device.watches.single()
        assertFalse(controller.current.identityLoaded)
        alice.changed(null, FriendsTransportError.FAILED)
        runCurrent()
        assertFalse(controller.current.identityLoaded)

        alice.changed(null, null)
        runCurrent()
        assertTrue(controller.current.identityLoaded)
        assertFalse(controller.current.active)

        device.account("bob")
        runCurrent()
        alice.changed(null, null)
        runCurrent()
        assertFalse(controller.current.identityLoaded)

        device.watches.last().changed(Json.encodeToString(bob), null)
        runCurrent()
        assertTrue(controller.current.identityLoaded)
        assertTrue(controller.current.active)
    }

    @Test
    fun setupPublishesOnlyAFreshAccountBoundProfileAndNeverPrivateNotes() = runTest {
        val device = Device()
        val controller = controller(device)
        controller.syncProfile(owner, "alice", false)
        controller.activate(owner)
        runCurrent()
        assertEquals(listOf("setFriendIdentity"), device.calls.map { it.name })
        assertEquals(
            30.0,
            device.calls
                .single()
                .body
                .getValue("identity")
                .jsonObject
                .getValue("hue")
                .jsonPrimitive
                .double,
        )
        controller.syncProfile(owner, "alice", true)
        advanceTimeBy(600)
        runCurrent()
        val published = device.calls.last().body
        assertEquals("rudolstadt-2026", published["edition"]?.jsonPrimitive?.content)
        assertEquals(2, published["protocol"]?.jsonPrimitive?.int)
        assertEquals("alice", published["owner"]?.jsonPrimitive?.content)
        assertFalse(published.toString().contains("PRIVATE"))
        assertFalse(published["profile"].toString().contains("name"))
        assertFalse(published["profile"].toString().contains("artistNotes"))
    }

    @Test
    fun publicationAlwaysSendsBothCategoriesEvenWhenEmpty() = runTest {
        val device = Device()
        val controller = controller(device)
        val emptyProfile = PersonalProfile(badgeName = "Alice")
        controller.syncProfile(emptyProfile, "alice", true)
        controller.activate(emptyProfile)
        runCurrent()

        fun publishedProfile() = device.calls.last { it.name == "publishFriendProfile" }
            .body.getValue("profile").jsonObject

        assertEquals(JsonArray(emptyList()), publishedProfile()["savedEventIDs"])
        assertEquals(JsonArray(emptyList()), publishedProfile()["artistPreferences"])

        controller.syncProfile(emptyProfile.copy(savedEventIDs = listOf(42)), "alice", true)
        advanceTimeBy(600)
        runCurrent()
        assertEquals(JsonArray(listOf(JsonPrimitive(42))), publishedProfile()["savedEventIDs"])
        assertEquals(JsonArray(emptyList()), publishedProfile()["artistPreferences"])

        controller.syncProfile(emptyProfile.copy(artistPreferences = owner.artistPreferences), "alice", true)
        advanceTimeBy(600)
        runCurrent()
        assertEquals(JsonArray(emptyList()), publishedProfile()["savedEventIDs"])
        assertEquals(1, publishedProfile().getValue("artistPreferences").jsonArray.size)
    }

    @Test
    fun aNewAccountCannotPublishTheOtherAccountsCachedProfile() = runTest {
        val device = Device().apply { identities["alice"] = FriendIdentity("Alice", 210.0) }
        val controller = controller(device)
        controller.syncProfile(owner, "bob", true)
        advanceTimeBy(2000)
        runCurrent()
        assertTrue(device.calls.isEmpty())
    }

    @Test
    fun publicationIsDebouncedSerializedAndIgnoresPrivateOnlyChanges() = runTest {
        val device = Device()
        val controller = active(device)
        device.calls.clear()
        controller.syncProfile(
            owner.copy(artistNotes = listOf(ArtistNote(7, "OTHER PRIVATE"))),
            "alice",
            true,
        )
        advanceTimeBy(1000)
        runCurrent()
        assertTrue(device.calls.isEmpty())
        controller.syncProfile(owner.copy(savedEventIDs = listOf(10)), "alice", true)
        advanceTimeBy(300)
        controller.syncProfile(owner.copy(savedEventIDs = listOf(11)), "alice", true)
        device.held += "publishFriendProfile"
        advanceTimeBy(300)
        runCurrent()
        assertEquals(1, device.calls.size)
        controller.syncProfile(owner.copy(savedEventIDs = listOf(12)), "alice", true)
        advanceTimeBy(1000)
        runCurrent()
        assertEquals(1, device.calls.size)
        device.held.clear()
        device.calls.last().complete()
        runCurrent()
        advanceTimeBy(600)
        runCurrent()
        assertEquals(2, device.calls.size)
        assertEquals(
            12,
            device.calls
                .last()
                .body["profile"]!!
                .jsonObject["savedEventIDs"]!!
                .jsonArray
                .single()
                .jsonPrimitive
                .int,
        )
    }

    @Test
    fun aProfileBecomingUnreadyWhileWaitingDoesNotPublishEmptyDataOrAnError() = runTest {
        val device = Device()
        val controller = active(device)
        device.calls.clear()
        controller.syncProfile(owner.copy(savedEventIDs = listOf(12)), "alice", true)
        controller.syncProfile(PersonalProfile(), "alice", false)
        advanceTimeBy(1000)
        runCurrent()
        assertTrue(device.calls.isEmpty())
        assertNull(controller.current.error)
    }

    @Test
    fun invitationsAlwaysShareRatingsAndSavedEventsButNeverNotesAcrossFestivals() = runTest {
        val device = Device()
        val controller = active(device)
        controller.createInvite()
        runCurrent()
        val created = device.calls.last().body
        assertNull(created["edition"])
        assertEquals(
            FriendPermissions(true, true, false),
            Json.decodeFromJsonElement<FriendPermissions>(created.getValue("sharing")),
        )
        assertEquals(invite.url, controller.current.ownInvite)
        assertTrue(controller.receive(invite.url))
        controller.previewInvite()
        runCurrent()
        assertEquals("Bob", controller.current.previewName)
        controller.acceptInvite()
        runCurrent()
        val accepted = device.calls.last().body
        assertNull(accepted["edition"])
        assertEquals(
            FriendPermissions(true, true, false),
            Json.decodeFromJsonElement<FriendPermissions>(accepted.getValue("sharing")),
        )
        assertNull(controller.current.invitation)
    }

    @Test
    fun anOldPreviewCannotOverwriteAReplacementInvitation() = runTest {
        val device = Device().apply { held += "previewFriendInvite" }
        val controller = active(device)
        controller.receive(invite.url)
        controller.previewInvite()
        runCurrent()
        val pending = device.calls.last()
        val replacement = FriendInvite("b".repeat(43))
        controller.receive(replacement.url)
        pending.complete()
        runCurrent()
        assertEquals(replacement, controller.current.invitation)
        assertNull(controller.current.previewName)
    }

    @Test
    fun onlyGrantedCategoriesAreObservedAndTheOtherChoiceStaysEmpty() = runTest {
        val device = Device().apply { identities["bob"] = bob }
        val controller = active(device)
        device.emit(listOf(FriendshipRecord("bob", all, FriendPermissions(true, false))))
        runCurrent()
        val categories = device.watches.filter { it.uid == "bob" && it.kind != "identity" }
        assertEquals(listOf("savedEvents"), categories.map { it.kind })
        assertEquals(listOf(42L), controller.current.friends.single().saved)
        assertTrue(controller.current.friends.single().preferences.isEmpty())
        assertEquals(all, controller.current.connections.single().sharing)
    }

    @Test
    fun revocationImmediatelyClearsValuesAndIgnoresLateCallbacksFromTheOldGrant() = runTest {
        val device = Device().apply { identities["bob"] = bob }
        val controller = active(device)
        device.emit(listOf(FriendshipRecord("bob", none, all)))
        runCurrent()
        val late = device.watches.last { it.uid == "bob" && it.kind == "savedEvents" }
        device.emit(listOf(FriendshipRecord("bob", none, FriendPermissions(false, true))))
        runCurrent()
        assertTrue(controller.current.friends.single().saved.isEmpty())
        assertTrue(late.cancelled)
        late.changed("""{"savedEventIDs":[999]}""", null)
        runCurrent()
        assertTrue(controller.current.friends.single().saved.isEmpty())
        assertEquals(
            listOf(ArtistPreference(7, 3)),
            controller.current.friends.single().preferences,
        )
    }

    @Test
    fun permissionLossReadsTheCurrentGlobalGrantToDistinguishNormalRevocation() = runTest {
        val device = Device().apply { identities["bob"] = bob }
        val controller = active(device)
        device.emit(listOf(FriendshipRecord("bob", none, all)))
        runCurrent()
        device.status = FriendshipRecord("bob", none, none)
        device.watches
            .last { it.kind == "ratings" }
            .changed(null, FriendsTransportError.PERMISSION_DENIED)
        runCurrent()
        assertNull(controller.current.error)
        assertEquals(1, controller.current.connections.size)
        assertTrue(controller.current.friends.single().preferences.isEmpty())
        device.status = null
        device.watches
            .last { it.uid == "bob" }
            .changed(null, FriendsTransportError.PERMISSION_DENIED)
        runCurrent()
        assertTrue(controller.current.connections.isEmpty())
        assertNull(controller.current.error)
    }

    @Test
    fun unexpectedOrUnverifiablePermissionFailuresRemainVisible() = runTest {
        val device = Device().apply { identities["bob"] = bob }
        val controller = active(device)
        val connection = FriendshipRecord("bob", none, all)
        device.emit(listOf(connection))
        runCurrent()
        device.status = connection
        device.watches
            .last { it.kind == "ratings" }
            .changed(null, FriendsTransportError.PERMISSION_DENIED)
        runCurrent()
        assertEquals(FriendsError.GENERAL, controller.current.error)
        assertEquals(1, controller.current.connections.size)
    }

    @Test
    fun changingOutgoingPermissionsDoesNotRestartOrWidenIncomingData() = runTest {
        val device = Device().apply { identities["bob"] = bob }
        val controller = active(device)
        device.emit(listOf(FriendshipRecord("bob", none, FriendPermissions(true, false))))
        runCurrent()
        val count = device.watches.size
        controller.setFriendSharing("bob", true, true)
        runCurrent()
        assertEquals(count, device.watches.size)
        assertEquals(all, controller.current.connections.single().sharing)
        assertEquals(
            FriendPermissions(true, false),
            controller.current.connections.single().receiving,
        )
        assertTrue(controller.current.friends.single().preferences.isEmpty())
    }

    @Test
    fun aLateOutgoingUpdateCannotRestoreAnIncomingGrantThatWasRevokedMeanwhile() = runTest {
        val device =
            Device().apply {
                identities["bob"] = bob
                held += "updateFriendSharing"
            }
        val controller = active(device)
        device.emit(listOf(FriendshipRecord("bob", none, all)))
        runCurrent()
        controller.setFriendSharing("bob", true, true)
        runCurrent()
        val response = device.calls.last()
        device.emit(listOf(FriendshipRecord("bob", all, none)))
        runCurrent()
        response.complete()
        runCurrent()
        assertEquals(none, controller.current.connections.single().receiving)
        assertTrue(controller.current.friends.single().saved.isEmpty())
    }

    @Test
    fun changingAccountsAndClosingInvalidateOldListenersAndPendingResponses() = runTest {
        val device =
            Device().apply {
                identities["bob"] = bob
                held += "createFriendInvite"
            }
        val controller = active(device)
        device.emit(listOf(FriendshipRecord("bob", none, all)))
        runCurrent()
        val old = device.watches.last()
        controller.createInvite()
        runCurrent()
        device.account("carol")
        runCurrent()
        old.changed("""{"savedEventIDs":[999]}""", null)
        device.calls.last().complete()
        runCurrent()
        assertEquals("carol", controller.current.uid)
        assertNull(controller.current.ownInvite)
        assertTrue(controller.current.connections.isEmpty())
        controller.close()
        device.emit(listOf(FriendshipRecord("bob")))
        runCurrent()
        assertEquals(FriendsState(), controller.current)
    }

    @Test
    fun failedPublicationCanBeRetriedWithoutPublishingTheWrongAccount() = runTest {
        val device = Device()
        val controller = active(device)
        device.errors["publishFriendProfile"] = FriendsTransportError.FAILED
        controller.syncProfile(owner.copy(savedEventIDs = listOf(12)), "alice", true)
        advanceTimeBy(600)
        runCurrent()
        assertEquals(FriendsError.PUBLISH, controller.current.error)
        device.errors.clear()
        controller.retryPublish()
        runCurrent()
        assertNull(controller.current.error)
        assertEquals("alice", device.calls.last().body.getValue("owner").jsonPrimitive.content)
    }

    @Test
    fun initialPublicationFailureKeepsTheIdentityActiveAndReportsAPublishError() = runTest {
        val device = Device()
        val controller = controller(device)
        device.errors["publishFriendProfile"] = FriendsTransportError.FAILED
        controller.syncProfile(owner, "alice", true)
        controller.activate(owner)
        runCurrent()
        assertTrue(controller.current.active)
        assertEquals(FriendsError.PUBLISH, controller.current.error)

        controller.retryPublish()
        runCurrent()
        assertEquals(FriendsError.PUBLISH, controller.current.error)

        device.errors.clear()
        controller.retryPublish()
        runCurrent()
        assertNull(controller.current.error)
    }

    @Test
    fun authenticationErrorsCancellationAndLateProviderResultsKeepTheirMeaning() = runTest {
        val device = Device()
        val controller = controller(device)
        for ((error, expected) in
            listOf(
                FriendsTransportError.AUTH_CONFIGURATION to FriendsError.AUTH_CONFIGURATION,
                FriendsTransportError.ACCOUNT_CONFLICT to FriendsError.ACCOUNT_CONFLICT,
                FriendsTransportError.FAILED to FriendsError.AUTHENTICATION,
            )) {
            controller.authenticate { it(error) }
            runCurrent()
            assertEquals(expected, controller.current.error)
        }
        controller.authenticate { it(FriendsTransportError.CANCELLED) }
        runCurrent()
        assertNull(controller.current.error)
        var pending: ((FriendsTransportError?) -> Unit)? = null
        controller.authenticate { pending = it }
        runCurrent()
        device.account("new-user")
        runCurrent()
        pending?.invoke(FriendsTransportError.FAILED)
        runCurrent()
        assertNull(controller.current.error)
        assertEquals("new-user", controller.current.uid)
    }

    @Test
    fun legacyNoteGrantsNeverSubscribeToOrExposeNotes() = runTest {
        val device = Device().apply { identities["bob"] = bob }
        val controller = active(device)
        device.emit(listOf(FriendshipRecord("bob", all, FriendPermissions(true, true, true))))
        runCurrent()
        assertEquals(
            listOf("identity", "savedEvents", "ratings"),
            device.watches.filter { it.uid == "bob" && !it.cancelled }.map { it.kind },
        )
        assertTrue(controller.current.connections.single().notes.isEmpty())
        assertEquals(listOf(42L), controller.current.friends.single().saved)
        assertEquals(
            listOf(ArtistPreference(7, 3)),
            controller.current.friends.single().preferences,
        )
        device.emit(listOf(FriendshipRecord("bob", all, FriendPermissions(notes = true))))
        runCurrent()
        assertTrue(controller.current.connections.single().notes.isEmpty())
        assertTrue(controller.current.friends.single().saved.isEmpty())
        assertTrue(controller.current.friends.single().preferences.isEmpty())
        assertTrue(device.watches.none { it.kind == "notes" })
    }

    private class Watch(
        val uid: String,
        val kind: String,
        val changed: (String?, FriendsTransportError?) -> Unit,
    ) : FriendsSubscription {
        var cancelled = false

        override fun cancel() {
            cancelled = true
        }
    }

    private class Call(val name: String, val body: JsonObject, val response: () -> Unit) {
        fun complete() = response()
    }

    private class Device : FriendsTransport {
        var uid: String? = "alice"
        lateinit var account: (String?) -> Unit
        val identities = mutableMapOf<String, FriendIdentity>()
        val archiveCategories = mutableMapOf<String, Map<String, String>>()
        val watches = mutableListOf<Watch>()
        val calls = mutableListOf<Call>()
        val errors = mutableMapOf<String, FriendsTransportError>()
        val held = mutableSetOf<String>()
        var deferIdentity = false
        var records = emptyList<FriendshipRecord>()
        var membership: ((String?, FriendsTransportError?) -> Unit)? = null
        var status: FriendshipRecord? = null
        var emailRecipient: String? = null

        fun emit(values: List<FriendshipRecord>) {
            records = values
            membership?.invoke(Json.encodeToString(values), null)
        }

        override fun observeAccount(changed: (String?) -> Unit): FriendsSubscription {
            account = {
                uid = it
                records = emptyList()
                changed(it)
            }
            changed(uid)
            return object : FriendsSubscription {
                override fun cancel() {}
            }
        }

        override fun observeMemberships(
            owner: String,
            changed: (String?, FriendsTransportError?) -> Unit,
        ): FriendsSubscription {
            membership = changed
            changed(Json.encodeToString(records), null)
            return object : FriendsSubscription {
                override fun cancel() {
                    if (membership === changed) membership = null
                }
            }
        }

        override fun observeIdentity(
            uid: String,
            changed: (String?, FriendsTransportError?) -> Unit,
        ): FriendsSubscription {
            val watch = Watch(uid, "identity", changed)
            watches += watch
            if (!deferIdentity) changed(identities[uid]?.let { Json.encodeToString(it) }, null)
            return watch
        }

        override fun observeCategory(
            edition: String,
            uid: String,
            category: String,
            changed: (String?, FriendsTransportError?) -> Unit,
        ): FriendsSubscription {
            val watch = Watch(uid, category, changed)
            watches += watch
            changed(
                if (edition in archiveCategories) archiveCategories.getValue(edition)[category]
                else
                    when (category) {
                        "savedEvents" -> """{"savedEventIDs":[42]}"""
                        "notes" ->
                            OwnProfileData.encodeRecords(
                                listOf(
                                    OwnProfileRecord(
                                        "note:7",
                                        ProfileVersion(10.0, "shared-current"),
                                        ProfileRecordValue(
                                            "note",
                                            7,
                                            noteText = "SHARED CURRENT NOTE",
                                        ),
                                    )
                                )
                            )
                        else -> """{"artistPreferences":[{"artistID":7,"rating":3}]}"""
                    },
                null,
            )
            return watch
        }

        override fun call(
            name: String,
            payload: String,
            completed: (String?, FriendsTransportError?) -> Unit,
        ) {
            val body = Json.parseToJsonElement(payload).jsonObject
            val response =
                when (name) {
                    "setFriendIdentity" -> {
                        val value = body.getValue("identity")
                        identities[uid!!] = Json.decodeFromJsonElement(value)
                        """{"identity":$value}"""
                    }
                    "createFriendInvite" -> """{"token":"${"a".repeat(43)}"}"""
                    "previewFriendInvite" ->
                        """{"name":"Bob","sharing":{"savedEvents":true,"ratings":true}}"""
                    "friendConnectionStatus" -> buildJsonObject {
                            put(
                                "connection",
                                status?.let { Json.encodeToJsonElement(it) } ?: JsonNull,
                            )
                        }
                            .toString()
                    "updateFriendSharing" -> buildJsonObject {
                            put(
                                "connection",
                                Json.encodeToJsonElement(
                                    FriendshipRecord(
                                        body.getValue("uid").jsonPrimitive.content,
                                        Json.decodeFromJsonElement(body.getValue("sharing")),
                                        records.firstOrNull()?.receiving ?: FriendPermissions(),
                                    )
                                ),
                            )
                        }
                            .toString()
                    else -> "{}"
                }
            val call =
                Call(name, body) {
                    completed(if (errors[name] == null) response else null, errors[name])
                }
            calls += call
            if (name !in held) call.complete()
        }

        override fun isEmailLink(value: String) = value.contains("oobCode=")

        override fun sendEmail(email: String, completed: (FriendsTransportError?) -> Unit) {
            emailRecipient = email
            completed(errors["sendEmail"])
        }

        override fun finishEmail(
            email: String,
            link: String,
            completed: (FriendsTransportError?) -> Unit,
        ) = completed(null)

        override fun signOut(completed: (FriendsTransportError?) -> Unit) {
            account(null)
            completed(null)
        }
    }
}
