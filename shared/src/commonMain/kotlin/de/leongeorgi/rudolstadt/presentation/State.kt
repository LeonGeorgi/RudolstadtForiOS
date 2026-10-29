package de.leongeorgi.rudolstadt.presentation

import kotlin.concurrent.atomics.AtomicReference
import kotlin.concurrent.atomics.ExperimentalAtomicApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Mutations and native observers run on the owning UI thread. Flow collection is thread-safe. */
@OptIn(ExperimentalAtomicApi::class)
internal class StateCell<S : Any>(initial: S) {
    private val mutable = MutableStateFlow(initial)
    val flow: StateFlow<S> = mutable.asStateFlow()
    val current: S
        get() = mutable.value

    private var sequence = 0L
    // A Swift owner's deinit may cancel its observation outside the UI thread.
    private val observers = AtomicReference<Map<Long, (S) -> Unit>>(emptyMap())

    fun set(value: S) {
        if (value == current) return
        mutable.value = value
        observers.load().values.forEach { it(value) }
    }

    fun observe(observer: (S) -> Unit): StateSubscription {
        val id = ++sequence
        updateObservers { it + (id to observer) }
        return StateSubscription { updateObservers { it - id } }
    }

    private fun updateObservers(transform: (Map<Long, (S) -> Unit>) -> Map<Long, (S) -> Unit>) {
        while (true) {
            val previous = observers.load()
            if (observers.compareAndSet(previous, transform(previous))) return
        }
    }
}

/** Cancelled by the platform view's owner. Observing never schedules a launch-time task. */
@OptIn(ExperimentalAtomicApi::class)
class StateSubscription internal constructor(dispose: () -> Unit) {
    private val dispose = AtomicReference<(() -> Unit)?>(dispose)

    fun cancel() {
        dispose.exchange(null)?.invoke()
    }
}

enum class LoadPhase {
    LOADING,
    READY,
    FAILED,
}

data class AppFailure(val reason: String, val owner: String, val httpStatus: Int? = null)
