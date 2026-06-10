#if os(iOS)
import Foundation

func sortedFriendProfiles(_ profiles: [SharedFestivalProfile]) -> [SharedFestivalProfile] {
    profiles.sorted { lhs, rhs in
        lhs.badge.displayName.localizedCaseInsensitiveCompare(rhs.badge.displayName)
            == .orderedAscending
    }
}

func friendProfilesSavingEvent(
    _ event: Event,
    from profiles: [SharedFestivalProfile]
) -> [SharedFestivalProfile] {
    profiles.filter { friendProfile in
        friendProfile.savedEventIDs.contains(event.id)
    }
}

func compareFriendsEventsByTime(_ lhs: Event, _ rhs: Event) -> Bool {
    if lhs.festivalDay != rhs.festivalDay {
        return lhs.festivalDay < rhs.festivalDay
    }
    if lhs.startTimeInMinutes != rhs.startTimeInMinutes {
        return lhs.startTimeInMinutes < rhs.startTimeInMinutes
    }
    return lhs.artist.formattedName.localizedCaseInsensitiveCompare(rhs.artist.formattedName)
        == .orderedAscending
}

func friendArtistRecommendations(
    friendProfiles: [SharedFestivalProfile],
    artists: [Artist],
    events: [Event],
    excludedArtistIDs: Set<Int> = []
) -> [FriendArtistRecommendation] {
    let artistsByID = Dictionary(uniqueKeysWithValues: artists.map { artist in
        (artist.id, artist)
    })
    let eventsByArtistID = Dictionary(grouping: events, by: { event in
        event.artist.id
    })

    let contributionsByArtistID = friendProfiles.reduce(
        into: [Int: [FriendArtistRecommendation.Contribution]]()
    ) { partialResult, friendProfile in
        let savedEventIDs = Set(friendProfile.savedEventIDs)
        let savedEventsByArtistID = eventsByArtistID.compactMapValues { artistEvents in
            artistEvents
                .filter { event in
                    savedEventIDs.contains(event.id)
                }
                .sorted(by: compareFriendsEventsByTime)
                .first
        }
        let preferencesByArtistID = friendProfile.artistPreferences.reduce(
            into: [Int: FestivalArtistPreference]()
        ) { partialResult, preference in
            partialResult[preference.artistID] = preference
        }
        let artistIDs = Set(savedEventsByArtistID.keys).union(preferencesByArtistID.keys)

        for artistID in artistIDs {
            guard !excludedArtistIDs.contains(artistID) else {
                continue
            }

            var candidateContributions = [FriendArtistRecommendation.Contribution]()

            if let event = savedEventsByArtistID[artistID] {
                candidateContributions.append(
                    FriendArtistRecommendation.Contribution(
                        profileID: friendProfile.id,
                        badge: friendProfile.badge,
                        kind: .savedEvent(event),
                        score: FriendArtistRecommendationScore.savedEvent
                    )
                )
            }

            if let preference = preferencesByArtistID[artistID],
               preference.rating > 0 {
                candidateContributions.append(
                    FriendArtistRecommendation.Contribution(
                        profileID: friendProfile.id,
                        badge: friendProfile.badge,
                        kind: .rating(preference),
                        score: FriendArtistRecommendationScore.rating(preference.rating)
                    )
                )
            }

            if let bestContribution = candidateContributions.max(by: { lhs, rhs in
                lhs.score < rhs.score
            }) {
                partialResult[artistID, default: []].append(bestContribution)
            }
        }
    }

    return contributionsByArtistID.compactMap { artistID, contributions in
        guard let artist = artistsByID[artistID], !contributions.isEmpty else {
            return nil
        }
        let sortedContributions = contributions.sorted(by: compareFriendContributions)
        let score = sortedContributions.reduce(0) { total, contribution in
            total + contribution.score
        }

        return FriendArtistRecommendation(
            artist: artist,
            contributions: sortedContributions,
            score: score
        )
    }
    .sorted { lhs, rhs in
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        if lhs.contributions.count != rhs.contributions.count {
            return lhs.contributions.count > rhs.contributions.count
        }
        return lhs.artist.formattedName.localizedCaseInsensitiveCompare(rhs.artist.formattedName)
            == .orderedAscending
    }
}

func friendRecommendationExcludedArtistIDs(
    savedEventIDs: [Int],
    ratings: [String: Int],
    events: [Event]
) -> Set<Int> {
    let savedEventIDSet = Set(savedEventIDs)
    let savedArtistIDs = events.reduce(into: Set<Int>()) { partialResult, event in
        if savedEventIDSet.contains(event.id) {
            partialResult.insert(event.artist.id)
        }
    }
    let ratedArtistIDs = ratings.compactMap { artistID, rating -> Int? in
        guard rating != 0 else {
            return nil
        }
        return Int(artistID)
    }
    return savedArtistIDs.union(ratedArtistIDs)
}

private func compareFriendContributions(
    _ lhs: FriendArtistRecommendation.Contribution,
    _ rhs: FriendArtistRecommendation.Contribution
) -> Bool {
    if lhs.score != rhs.score {
        return lhs.score > rhs.score
    }
    if lhs.badge.displayName != rhs.badge.displayName {
        return lhs.badge.displayName.localizedCaseInsensitiveCompare(rhs.badge.displayName)
            == .orderedAscending
    }
    return lhs.id < rhs.id
}

private enum FriendArtistRecommendationScore {
    static let savedEvent = 16

    static func rating(_ rating: Int) -> Int {
        rating * rating
    }
}

struct FriendArtistRecommendation: Identifiable {
    struct Contribution: Identifiable {
        enum Kind {
            case savedEvent(Event)
            case rating(FestivalArtistPreference)
        }

        let profileID: String
        let badge: FestivalProfileBadge
        let kind: Kind
        let score: Int

        var id: String {
            switch kind {
            case .savedEvent(let event):
                return "\(profileID)-saved-\(event.id)"
            case .rating(let preference):
                return "\(profileID)-rating-\(preference.artistID)"
            }
        }
    }

    let artist: Artist
    let contributions: [Contribution]
    let score: Int

    var id: Int {
        artist.id
    }

    var highlightedEventID: Int? {
        contributions.compactMap { contribution in
            if case .savedEvent(let event) = contribution.kind {
                return event.id
            }
            return nil
        }
        .first
    }
}
#endif
