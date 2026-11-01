package de.leongeorgi.rudolstadt.presentation

data class SchedulePreferencesState(val codes: Map<String, Int> = emptyMap())

class SchedulePreferencesViewModel {
    private val cell = StateCell(SchedulePreferencesState())
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (SchedulePreferencesState) -> Unit) = cell.observe(observer)

    fun restore(scope: String, code: Int) {
        if (current.codes[scope] != code)
            cell.set(current.copy(codes = current.codes + (scope to code)))
    }

    fun storedCode(scope: String): Int = current.codes[scope] ?: 0

    fun name(code: Int): String =
        when (code) {
            1 -> "interesting"
            2 -> "optimal"
            3 -> "saved"
            else -> "all"
        }

    fun codeForName(name: String): Int =
        when (name) {
            "interesting" -> 1
            "optimal" -> 2
            "saved" -> 3
            else -> 0
        }

    fun select(scope: String, name: String): Int = codeForName(name).also { restore(scope, it) }
}
