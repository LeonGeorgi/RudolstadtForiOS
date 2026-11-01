package de.leongeorgi.rudolstadt.discovery

import de.leongeorgi.rudolstadt.festival.ProgramArtist

/** Reusable artist lookup, group filtering and ordering; hosts supply Unicode folding/collation. */
class ProgramArtistIndex(artists: List<ProgramArtist>, fold: (String) -> String) {
    private data class Entry(val artist: DiscoveryArtist, val groups: Map<String, Set<String>>)

    private val byID = artists.asReversed().associateBy { it.artistID }
    private val entries =
        artists
            .filter { !it.hiddenFromArtistList }
            .map {
                Entry(
                    DiscoveryArtist(
                        it.artistID,
                        it.name,
                        fold(it.name),
                        it.hiddenFromArtistList,
                        it.isMetadataAvailable,
                    ),
                    it.groups.mapValues { (_, values) -> values.toSet() },
                )
            }

    fun matching(
        favoritesOnly: Boolean,
        ratings: Map<String, Int>,
        search: String,
        groups: Map<String, String>,
        collation: TextCollation? = null,
    ): List<ProgramArtist> {
        val candidates = entries.filter { entry ->
            groups.all { (group, selected) -> selected in entry.groups[group].orEmpty() }
        }
        return Discovery.artistOverview(
                candidates.map { it.artist },
                favoritesOnly,
                ratings
                    .mapNotNull { (id, value) -> id.toLongOrNull()?.let { it to value } }
                    .toMap(),
                search,
                collation,
            )
            .mapNotNull { byID[it] }
    }
}
