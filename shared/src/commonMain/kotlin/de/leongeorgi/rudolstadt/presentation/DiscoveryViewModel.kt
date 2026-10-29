package de.leongeorgi.rudolstadt.presentation

data class DiscoveryState(
    val artistType: String? = null,
    val browseGenre: String? = null,
    val groups: Map<String, String> = emptyMap(),
    val search: String = "",
    val favoritesOnly: Boolean = false,
) {
    val hasActiveFilters
        get() = artistType != null || browseGenre != null || groups.isNotEmpty()
}

class DiscoveryViewModel {
    private val cell = StateCell(DiscoveryState())
    val state
        get() = cell.flow

    val current
        get() = cell.current

    fun observe(observer: (DiscoveryState) -> Unit) = cell.observe(observer)

    fun selectType(value: String?) {
        cell.set(current.copy(artistType = value))
    }

    fun selectGenre(value: String?) {
        cell.set(current.copy(browseGenre = value))
    }

    fun selectGroups(value: Map<String, String>) {
        cell.set(current.copy(groups = value.toMap()))
    }

    fun search(value: String) {
        cell.set(current.copy(search = value))
    }

    fun favoritesOnly(value: Boolean) {
        cell.set(current.copy(favoritesOnly = value))
    }

    fun clearFilters() {
        cell.set(current.copy(artistType = null, browseGenre = null, groups = emptyMap()))
    }

    fun availableGenres(ids: Set<String>) {
        if (current.browseGenre != null && current.browseGenre !in ids) selectGenre(null)
    }
}
