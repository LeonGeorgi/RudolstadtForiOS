#if os(iOS)
import Testing
@testable import Rudolstadt

struct FriendArtistRecommendationTests {
    @Test
    func recommendationsExcludeOwnRatedArtists() {
        let stage = TestFixtures.stage(id: 20)
        let ratedArtist = TestFixtures.artist(id: 61)
        let unratedArtist = TestFixtures.artist(id: 62)
        let events = [
            TestFixtures.event(
                id: 1201,
                dayInJuly: 3,
                timeAsString: "18:00",
                stage: stage,
                artist: ratedArtist
            ),
            TestFixtures.event(
                id: 1202,
                dayInJuly: 3,
                timeAsString: "20:00",
                stage: stage,
                artist: unratedArtist
            ),
        ]
        let friendProfile = TestFixtures.sharedFestivalProfile(
            artistPreferences: [
                FestivalArtistPreference(
                    artistID: ratedArtist.id,
                    rating: 3,
                    iconName: nil
                ),
                FestivalArtistPreference(
                    artistID: unratedArtist.id,
                    rating: 2,
                    iconName: nil
                ),
            ]
        )

        let recommendations = friendArtistRecommendations(
            friendProfiles: [friendProfile],
            artists: [ratedArtist, unratedArtist],
            events: events,
            excludedArtistIDs: friendRecommendationExcludedArtistIDs(
                savedEventIDs: [],
                ratings: [String(ratedArtist.id): -1],
                events: events
            )
        )

        #expect(recommendations.map(\.artist.id) == [unratedArtist.id])
    }

    @Test
    func recommendationsExcludeArtistsWithOwnSavedEvents() {
        let stage = TestFixtures.stage(id: 21)
        let savedArtist = TestFixtures.artist(id: 63)
        let unsavedArtist = TestFixtures.artist(id: 64)
        let events = [
            TestFixtures.event(
                id: 1301,
                dayInJuly: 3,
                timeAsString: "18:00",
                stage: stage,
                artist: savedArtist
            ),
            TestFixtures.event(
                id: 1302,
                dayInJuly: 3,
                timeAsString: "19:00",
                stage: stage,
                artist: savedArtist
            ),
            TestFixtures.event(
                id: 1303,
                dayInJuly: 3,
                timeAsString: "20:00",
                stage: stage,
                artist: unsavedArtist
            ),
        ]
        let friendProfile = TestFixtures.sharedFestivalProfile(
            savedEventIDs: [1302, 1303]
        )

        let recommendations = friendArtistRecommendations(
            friendProfiles: [friendProfile],
            artists: [savedArtist, unsavedArtist],
            events: events,
            excludedArtistIDs: friendRecommendationExcludedArtistIDs(
                savedEventIDs: [1301],
                ratings: [:],
                events: events
            )
        )

        #expect(recommendations.map(\.artist.id) == [unsavedArtist.id])
    }
}
#endif
