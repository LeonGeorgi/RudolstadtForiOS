package de.leongeorgi.rudolstadt.profile

/** JSON exists only at this SDK boundary. Credentials and SDK objects stay on the platform. */
interface FriendsTransport {
    fun observeAccount(changed: (String?) -> Unit): FriendsSubscription

    fun call(name: String, payload: String, completed: (String?, FriendsTransportError?) -> Unit)

    fun observeMemberships(
        owner: String,
        changed: (String?, FriendsTransportError?) -> Unit,
    ): FriendsSubscription

    /** For the signed-in user, report absence only after a server snapshot confirms it. */
    fun observeIdentity(
        uid: String,
        changed: (String?, FriendsTransportError?) -> Unit,
    ): FriendsSubscription

    fun observeCategory(
        edition: String,
        uid: String,
        category: String,
        changed: (String?, FriendsTransportError?) -> Unit,
    ): FriendsSubscription

    fun isEmailLink(value: String): Boolean

    fun sendEmail(email: String, completed: (FriendsTransportError?) -> Unit)

    fun finishEmail(email: String, link: String, completed: (FriendsTransportError?) -> Unit)

    fun signOut(completed: (FriendsTransportError?) -> Unit)
}

interface FriendsSubscription {
    fun cancel()
}

enum class FriendsTransportError {
    FAILED,
    PERMISSION_DENIED,
    CANCELLED,
    AUTH_CONFIGURATION,
    ACCOUNT_CONFLICT,
    RATE_LIMITED,
    UNAUTHENTICATED,
    CONFLICT,
}

object FriendsConfiguration {
    const val region = "europe-west3"
    const val authDomain = "auth.festival.leongeorgi.de"
    const val emailContinueURL = "https://festival.leongeorgi.de/rudolstadt/friends-login"
    const val iosBundleID = "de.leongeorgi.RudolstadtForiOS"
    const val androidPackage = "de.leongeorgi.rudolstadt.android"
}
