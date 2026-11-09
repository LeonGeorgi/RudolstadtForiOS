package de.leongeorgi.rudolstadt.profile

/** Shared by the account controllers on their owning UI scope. */
class AccountActionGate {
    private var owner: Any? = null

    internal fun acquire(): Any? {
        if (owner != null) return null
        return Any().also { owner = it }
    }

    internal fun release(lease: Any) {
        if (owner === lease) owner = null
    }
}
