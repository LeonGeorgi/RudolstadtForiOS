package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.profile.*
import kotlin.test.*
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import kotlinx.serialization.json.*

@OptIn(ExperimentalCoroutinesApi::class)
class AccountKeyControllerTests {
    private fun TestScope.controller(
        device: Device = Device(),
        gate: AccountActionGate = AccountActionGate(),
    ) =
        AccountKeyController(
                device,
                CoroutineScope(
                    backgroundScope.coroutineContext +
                        SupervisorJob(backgroundScope.coroutineContext[Job])
                ),
                gate,
            )
            .also { runCurrent() }

    @Test
    fun accountActionsAreExclusiveAcrossControllersAndCancellationReleasesTheGate() = runTest {
        val gate = AccountActionGate()
        val firstDevice = Device().apply { hold = true }
        val secondDevice = Device()
        val first = controller(firstDevice, gate)
        val second = controller(secondDevice, gate)
        first.createAccount()
        second.createAccount()
        runCurrent()
        assertEquals(1, firstDevice.calls.size)
        assertTrue(secondDevice.calls.isEmpty())
        first.close()
        runCurrent()
        second.createAccount()
        runCurrent()
        assertEquals("key_aaaaaaaaaaaaaaaaaaaaaaaa", second.current.uid)
        assertEquals(1, secondDevice.calls.size)
    }

    @Test
    fun keyFormatUsesAll160BitsAndAcceptsOnlyItsOwnVersionAndAlphabet() {
        val key = requireNotNull(AccountKeys.fromEntropy("ff".repeat(20)))
        assertEquals("FF1-" + List(8) { "ZZZZ" }.joinToString("-"), key)
        assertEquals(key, AccountKeys.normalize(key.lowercase().replace("-", " \n")))
        for (value in
            listOf(
                "FF2" + "Z".repeat(32),
                "FF1" + "I".repeat(32),
                "Z".repeat(32),
                key + "Z",
                "https://example.org/?key=$key",
            )) assertNull(AccountKeys.normalize(value))
        assertNull(AccountKeys.fromEntropy("0".repeat(39)))
        assertNull(AccountKeys.fromEntropy("g".repeat(40)))
    }

    @Test
    fun creatingAnAccountPreservesItsKeyAcrossTheExpectedAuthenticationCallback() = runTest {
        val device = Device()
        val controller = controller(device)
        controller.createAccount()
        runCurrent()
        assertEquals("key_aaaaaaaaaaaaaaaaaaaaaaaa", controller.current.uid)
        assertEquals(
            device.calls.single().payload.getValue("key").jsonPrimitive.content,
            controller.current.displayedKey,
        )
        assertEquals(1, controller.current.version)
        assertTrue(controller.current.hasKey)
        assertFalse(controller.current.toString().contains("FF1-"))
        controller.hideKey()
        assertNull(controller.current.displayedKey)
    }

    @Test
    fun anInterruptedCreationRetriesTheSameSecretInsteadOfCreatingAnotherAccount() = runTest {
        val device = Device().apply { error = FriendsTransportError.FAILED }
        val controller = controller(device)
        controller.createAccount()
        runCurrent()
        assertEquals(AccountKeyError.CONNECTION, controller.current.error)
        device.error = null
        controller.createAccount()
        runCurrent()
        assertEquals(device.calls[0].payload, device.calls[1].payload)
        assertEquals(1, device.entropyCount)
        assertEquals("key_aaaaaaaaaaaaaaaaaaaaaaaa", controller.current.uid)
    }

    @Test
    fun signingInNormalizesTheKeyAndDoesNotRevealItAfterwards() = runTest {
        val device = Device()
        val controller = controller(device)
        val key = requireNotNull(AccountKeys.fromEntropy("01".repeat(20)))
        controller.signIn(key.lowercase().replace("-", " "))
        runCurrent()
        assertEquals("key_bbbbbbbbbbbbbbbbbbbbbbbb", controller.current.uid)
        assertEquals(key, device.calls.single().payload.getValue("key").jsonPrimitive.content)
        assertNull(controller.current.displayedKey)
        assertEquals(0, device.entropyCount)
    }

    @Test
    fun malformedInputNeverReachesFirebase() = runTest {
        val device = Device()
        val controller = controller(device)
        controller.signIn("not an account key")
        runCurrent()
        assertEquals(AccountKeyError.INVALID_KEY, controller.current.error)
        assertTrue(device.calls.isEmpty())
        assertEquals(0, device.signIns)
    }

    @Test
    fun providerAccountsCannotCreateReplaceOrRefreshKeys() = runTest {
        for (device in
            listOf(
                Device("apple-user"),
                Device("google-user"),
                Device("email-user"),
                Device("key_bbbbbbbbbbbbbbbbbbbbbbbb").apply { provider = true },
            )) {
            val controller = controller(device)
            assertFalse(controller.current.isKeyAccount)
            controller.createAccount()
            controller.replaceKey()
            controller.refresh()
            runCurrent()
            assertTrue(device.calls.isEmpty())
            assertEquals(0, device.entropyCount)
            assertNull(controller.current.displayedKey)
        }
    }

    @Test
    fun standaloneAccountsCanReplaceTheirExistingKeyWithoutChangingIdentity() = runTest {
        val device = Device("key_bbbbbbbbbbbbbbbbbbbbbbbb")
        val controller = controller(device)
        assertTrue(controller.current.isKeyAccount)
        assertTrue(device.calls.isEmpty())
        controller.replaceKey()
        runCurrent()
        assertEquals(listOf("accountKeyStatus", "replaceAccountKey"), device.calls.map { it.name })
        assertEquals(1, device.calls.last().payload.getValue("expectedVersion").jsonPrimitive.int)
        assertEquals("key_bbbbbbbbbbbbbbbbbbbbbbbb", controller.current.uid)
        assertNotNull(controller.current.displayedKey)
        assertEquals(0, device.signIns)
    }

    @Test
    fun aServerSideEligibilityRejectionStopsReplacementBeforeGeneratingASecret() = runTest {
        val device = Device("key_bbbbbbbbbbbbbbbbbbbbbbbb").apply { eligible = false }
        val controller = controller(device)
        controller.replaceKey()
        runCurrent()
        assertFalse(controller.current.isKeyAccount)
        assertEquals(listOf("accountKeyStatus"), device.calls.map { it.name })
        assertEquals(0, device.entropyCount)
    }

    @Test
    fun staleReplacementRequiresRefreshingAndUsesANewSecretAfterAConflict() = runTest {
        val device = Device("key_bbbbbbbbbbbbbbbbbbbbbbbb")
        val controller = controller(device)
        device.errorFor = "replaceAccountKey"
        device.error = FriendsTransportError.CONFLICT
        controller.replaceKey()
        runCurrent()
        assertEquals(AccountKeyError.CONFLICT, controller.current.error)
        assertNull(controller.current.version)
        device.version = 4
        device.error = null
        controller.replaceKey()
        runCurrent()
        assertEquals(4, device.calls.last().payload.getValue("expectedVersion").jsonPrimitive.int)
        assertEquals(2, device.entropyCount)
        assertEquals(5, controller.current.version)
    }

    @Test
    fun aLateCreationResponseCannotSignOutOrRevealSecretsToAnotherAccount() = runTest {
        val device = Device().apply { hold = true }
        val controller = controller(device)
        controller.createAccount()
        runCurrent()
        controller.createAccount()
        runCurrent()
        assertEquals(1, device.calls.size)
        device.account("bob")
        runCurrent()
        device.calls.single().complete()
        runCurrent()
        assertEquals("bob", controller.current.uid)
        assertEquals(0, device.signIns)
        assertNull(controller.current.displayedKey)
    }

    @Test
    fun hidingSecretsWhileARequestIsPendingPreventsALateReveal() = runTest {
        val device = Device().apply { hold = true }
        val controller = controller(device)
        controller.createAccount()
        runCurrent()
        controller.hideKey()
        device.calls.single().complete()
        runCurrent()
        assertEquals("key_aaaaaaaaaaaaaaaaaaaaaaaa", controller.current.uid)
        assertNull(controller.current.displayedKey)
    }

    @Test
    fun errorsAreSpecificAndClosingCancelsAnyPendingTokenExchange() = runTest {
        val device = Device()
        val controller = controller(device)
        for ((failure, problem) in
            listOf(
                FriendsTransportError.AUTH_CONFIGURATION to AccountKeyError.CONFIGURATION,
                FriendsTransportError.RATE_LIMITED to AccountKeyError.RATE_LIMITED,
                FriendsTransportError.UNAUTHENTICATED to AccountKeyError.INVALID_KEY,
            )) {
            device.error = failure
            controller.createAccount()
            runCurrent()
            assertEquals(problem, controller.current.error)
            assertFalse(controller.current.busy)
        }
        device.error = null
        device.hold = true
        controller.createAccount()
        runCurrent()
        controller.close()
        device.calls.last().complete()
        runCurrent()
        assertEquals(AccountKeyState(), controller.current)
        assertEquals(0, device.signIns)
    }

    private class Call(val name: String, val payload: JsonObject, val done: () -> Unit) {
        fun complete() = done()
    }

    private class Device(var uid: String? = null) : AccountKeyTransport {
        lateinit var account: (String?) -> Unit
        val calls = mutableListOf<Call>()
        var entropyCount = 0
        var signIns = 0
        var hold = false
        var error: FriendsTransportError? = null
        var errorFor: String? = null
        var version = 1
        var provider = false
        var eligible = true

        override fun accountHasProvider() = provider

        override fun observeAccount(changed: (String?) -> Unit): FriendsSubscription {
            account = {
                uid = it
                changed(it)
            }
            changed(uid)
            return object : FriendsSubscription {
                override fun cancel() {}
            }
        }

        override fun secureKeyEntropy() = (++entropyCount).toString(16).padStart(40, '0')

        override fun signInCustomToken(
            token: String,
            expectedUID: String?,
            completed: (FriendsTransportError?) -> Unit,
        ) {
            assertEquals(expectedUID, uid)
            signIns++
            account(token)
            completed(null)
        }

        override fun call(
            name: String,
            payload: String,
            completed: (String?, FriendsTransportError?) -> Unit,
        ) {
            val body = Json.parseToJsonElement(payload).jsonObject
            val call =
                Call(name, body) {
                    if (error != null && (errorFor == null || errorFor == name))
                        completed(null, error)
                    else
                        completed(
                            when (name) {
                                "createKeyAccount" ->
                                    """{"uid":"key_aaaaaaaaaaaaaaaaaaaaaaaa","token":"key_aaaaaaaaaaaaaaaaaaaaaaaa"}"""
                                "signInWithAccountKey" ->
                                    """{"uid":"key_bbbbbbbbbbbbbbbbbbbbbbbb","token":"key_bbbbbbbbbbbbbbbbbbbbbbbb"}"""
                                "accountKeyStatus" ->
                                    """{"eligible":$eligible,"hasKey":${eligible && version > 0},"version":$version}"""
                                "replaceAccountKey" -> """{"version":${version + 1}}"""
                                else -> error("Unexpected operation")
                            },
                            null,
                        )
                }
            calls += call
            if (!hold) call.complete()
        }
    }
}
