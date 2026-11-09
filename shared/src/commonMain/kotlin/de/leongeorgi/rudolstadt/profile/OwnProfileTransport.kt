package de.leongeorgi.rudolstadt.profile

/** Native SDK, durable local storage and local-data import boundaries. */
interface OwnProfileTransport {
    fun checkAccountDeleted(owner: String, completed: (Boolean) -> Unit) {
        completed(false)
    }

    fun signOutDeletedAccount(owner: String, completed: (FriendsTransportError?) -> Unit) {
        completed(null)
    }

    fun observeAccount(changed: (String?) -> Unit): FriendsSubscription

    fun loadLocal(completed: (String?, FriendsTransportError?) -> Unit)

    fun saveLocal(journal: String, profile: String, completed: (FriendsTransportError?) -> Unit)

    fun observeRecords(
        edition: String,
        owner: String,
        changed: (String?, Boolean, FriendsTransportError?) -> Unit,
    ): FriendsSubscription

    fun syncRecords(payload: String, completed: (String?, FriendsTransportError?) -> Unit)
}
