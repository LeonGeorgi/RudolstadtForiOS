#if os(iOS)
    import Foundation
    import RudolstadtCore

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
            friendProfile.saved.contains { $0.intValue == event.id }
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

    struct FriendRecommendationContext {
        private let artists: [CoreDiscoveryArtist]
        private let events: [ProgramEvent]
        private let byArtist: [Int: Artist]
        private let byEvent: [Int: Event]

        init(artists: [Artist], events: [Event], locale: Locale = .current) {
            self.artists = artists.map { CoreDiscoveryArtist($0, locale: locale) }
            self.events = events.map { CoreEvent($0).core }
            byArtist = Dictionary(
                artists.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            byEvent = Dictionary(
                events.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }

        private func excludedArtistIDs(savedEventIDs: [Int], ratings: [String: Int]) -> Set<Int> {
            let values = Dictionary(
                ratings.compactMap { key, value in Int(key).map { ($0, value) } },
                uniquingKeysWith: { _, last in last })
            let request = DiscoveryRequest(
                artists: [], profiles: [], events: events, excluded: [],
                ratings: KotlinCore.ratings(values),
                savedEventIDs: Set(KotlinCore.ids(savedEventIDs)),
                favoritesOnly: false, search: "")
            return Set(KotlinCore.bridge.excludedArtists(request: request).map(\.intValue))
        }

        func recommendations(
            friendProfiles: [SharedFestivalProfile], savedEventIDs: [Int], ratings: [String: Int]
        ) -> [FriendArtistRecommendation] {
            recommendations(
                friendProfiles: friendProfiles,
                excludedArtistIDs: excludedArtistIDs(savedEventIDs: savedEventIDs, ratings: ratings)
            )
        }

        private func recommendations(
            friendProfiles: [SharedFestivalProfile], excludedArtistIDs: Set<Int> = []
        ) -> [FriendArtistRecommendation] {
            let request = DiscoveryRequest(
                artists: artists, profiles: friendProfiles.map(CoreFriendProfile.init),
                events: events,
                excluded: Set(KotlinCore.ids(excludedArtistIDs)), ratings: [:], savedEventIDs: [],
                favoritesOnly: false, search: "")
            let recommendations = KotlinCore.friends(request)
            let byProfile = Dictionary(
                friendProfiles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            return recommendations.compactMap { recommendation in
                guard let artist = byArtist[Int(recommendation.artistID)] else { return nil }
                let contributions = recommendation.contributions.compactMap {
                    value -> FriendArtistRecommendation.Contribution? in
                    guard let profile = byProfile[value.profileID] else { return nil }
                    let kind: FriendArtistRecommendation.Contribution.Kind
                    if let id = value.eventID, let event = byEvent[id.intValue] {
                        kind = .savedEvent(event)
                    } else if let preference = profile.preferences.last(where: {
                        $0.artistID == value.artistID
                    }) {
                        kind = .rating(preference.native)
                    } else {
                        return nil
                    }
                    return FriendArtistRecommendation.Contribution(
                        profileID: profile.id, badge: profile.badge, kind: kind,
                        score: Int(value.score)
                    )
                }
                return FriendArtistRecommendation(
                    artist: artist, contributions: contributions, score: Int(recommendation.score))
            }
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
