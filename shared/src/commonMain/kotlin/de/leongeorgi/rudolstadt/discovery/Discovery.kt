package de.leongeorgi.rudolstadt.discovery

import de.leongeorgi.rudolstadt.festival.ProgramEvent
import de.leongeorgi.rudolstadt.festival.ProgramOccurrence
import de.leongeorgi.rudolstadt.profile.ArtistPreference
import kotlinx.serialization.Serializable

@Serializable
data class DiscoveryArtist(
    val id: Long,
    val name: String,
    val normalizedName: String = name,
    val hidden: Boolean = false,
    val isMetadataAvailable: Boolean = true,
)

@Serializable
data class FriendProfile(
    val id: String,
    val displayName: String,
    val savedEventIDs: List<Long>,
    val artistPreferences: List<ArtistPreference>,
)

@Serializable
data class FriendContribution(
    val profileID: String,
    val artistID: Long,
    val eventID: Long? = null,
    val rating: Int? = null,
    val score: Int,
) {
    val id
        get() = if (eventID != null) "$profileID-saved-$eventID" else "$profileID-rating-$artistID"
}

@Serializable
data class FriendRecommendation(
    val artistID: Long,
    val contributions: List<FriendContribution>,
    val score: Int,
)

/** Host-supplied locale collation, keeping each platform's exact display ordering. */
interface TextCollation {
    fun compare(a: String, b: String): Int
}

object Discovery {
    fun artistOverview(
        artists: List<DiscoveryArtist>,
        favoritesOnly: Boolean,
        ratings: Map<Long, Int>,
        search: String,
        collation: TextCollation? = null,
    ): List<Long> =
        artists
            .filter {
                (!favoritesOnly || (ratings[it.id] ?: 0) > 0) &&
                    (search.isEmpty() || it.normalizedName.contains(search))
            }
            .sortedWith(
                Comparator<DiscoveryArtist> { a, b ->
                    val name =
                        collation?.compare(a.normalizedName, b.normalizedName)
                            ?: a.normalizedName.compareTo(b.normalizedName)
                    if (name != 0) name
                    else if (favoritesOnly) (ratings[b.id] ?: 0).compareTo(ratings[a.id] ?: 0)
                    else 0
                }
            )
            .map { it.id }

    fun similarArtists(
        artistID: Long,
        ranked: List<Long>,
        artists: List<DiscoveryArtist>,
        catalogYear: Int,
        year: Int,
        limit: Int,
    ): List<Long> {
        if (catalogYear != year || limit <= 0) return emptyList()
        val available = artists.filter { !it.hidden && it.id != artistID }.map { it.id }.toSet()
        return ranked.filter { it in available }.take(limit)
    }

    fun excludedArtists(
        savedEventIDs: Set<Long>,
        ratings: Map<Long, Int>,
        events: List<ProgramEvent>,
    ): Set<Long> =
        events.filter { it.id in savedEventIDs }.map { it.artistID }.toSet() +
            ratings.filterValues { it != 0 }.keys

    fun friendRecommendations(
        profiles: List<FriendProfile>,
        artists: List<DiscoveryArtist>,
        events: List<ProgramEvent>,
        excluded: Set<Long>,
        collation: TextCollation? = null,
    ): List<FriendRecommendation> {
        val artistsByID = artists.associateBy { it.id }
        val profilesByID = profiles.associateBy { it.id }
        val eventsByArtist = events.filter { it.eligible }.groupBy { it.artistID }
        val contributions = mutableMapOf<Long, MutableList<FriendContribution>>()
        profiles.forEach { profile ->
            val saved =
                eventsByArtist
                    .mapNotNull { (artist, events) ->
                        events
                            .filter { it.id in profile.savedEventIDs }
                            .minWithOrNull(
                                compareBy<ProgramEvent> { it.dayNumber }.thenBy { it.startMinutes }
                            )
                            ?.let { artist to it }
                    }
                    .toMap()
            val ratings = profile.artistPreferences.associateBy { it.artistID }
            (saved.keys + ratings.keys)
                .filter { it !in excluded }
                .forEach { artist ->
                    val savedContribution =
                        saved[artist]?.let {
                            FriendContribution(profile.id, artist, eventID = it.id, score = 16)
                        }
                    val ratedContribution =
                        ratings[artist]
                            ?.takeIf { it.rating > 0 }
                            ?.let {
                                FriendContribution(
                                    profile.id,
                                    artist,
                                    rating = it.rating,
                                    score = it.rating * it.rating,
                                )
                            }
                    val contribution =
                        listOfNotNull(savedContribution, ratedContribution).maxByOrNull { it.score }
                    if (contribution != null)
                        contributions.getOrPut(artist) { mutableListOf() }.add(contribution)
                }
        }
        fun compareNames(a: String, b: String) =
            collation?.compare(a, b) ?: a.lowercase().compareTo(b.lowercase())
        val contributionOrder =
            Comparator<FriendContribution> { a, b ->
                val score = b.score.compareTo(a.score)
                val nameA = profilesByID[a.profileID]?.displayName.orEmpty()
                val nameB = profilesByID[b.profileID]?.displayName.orEmpty()
                if (score != 0) score
                else if (nameA != nameB) compareNames(nameA, nameB) else a.id.compareTo(b.id)
            }
        return contributions
            .mapNotNull { (artist, values) ->
                if (artistsByID[artist]?.isMetadataAvailable != true) null
                else
                    FriendRecommendation(
                        artist,
                        values.sortedWith(contributionOrder),
                        values.sumOf { it.score },
                    )
            }
            .sortedWith(
                Comparator { a, b ->
                    b.score.compareTo(a.score).takeIf { it != 0 }
                        ?: b.contributions.size.compareTo(a.contributions.size).takeIf { it != 0 }
                        ?: compareNames(
                            artistsByID[a.artistID]?.name.orEmpty(),
                            artistsByID[b.artistID]?.name.orEmpty(),
                        )
                }
            )
    }
}

@Serializable
data class DiscoveryRequest(
    val artists: List<DiscoveryArtist>,
    val profiles: List<FriendProfile> = emptyList(),
    val events: List<ProgramEvent> = emptyList(),
    val excluded: Set<Long> = emptySet(),
    val ratings: Map<Long, Int> = emptyMap(),
    val savedEventIDs: Set<Long> = emptySet(),
    val favoritesOnly: Boolean = false,
    val search: String = "",
)

object ScheduleFilter {
    fun occurrences(
        events: List<ProgramOccurrence>,
        filter: String,
        saved: Set<Long>,
        positiveArtists: Set<Long>,
        recommended: Set<Long>,
    ): List<ProgramOccurrence> = events.filter {
        includes(it.eventID, it.artist.artistID, filter, saved, positiveArtists, recommended)
    }

    fun eventIDs(
        events: List<ProgramEvent>,
        filter: String,
        saved: Set<Long>,
        positiveArtists: Set<Long>,
        recommended: Set<Long>,
    ): List<Long> =
        events
            .filter {
                includes(it.id, it.artistID, filter, saved, positiveArtists, recommended)
            }
            .map { it.id }

    private fun includes(
        id: Long,
        artistID: Long,
        filter: String,
        saved: Set<Long>,
        positiveArtists: Set<Long>,
        recommended: Set<Long>,
    ): Boolean =
        when (filter) {
            "saved" -> id in saved
            "interesting" -> id in saved || artistID in positiveArtists
            "optimal" -> id in saved || id in recommended
            else -> true
        }
}
