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

            let context = FriendRecommendationContext(
                artists: [ratedArtist, unratedArtist], events: events)
            let recommendations = context.recommendations(
                friendProfiles: [friendProfile], savedEventIDs: [],
                ratings: [String(ratedArtist.id): -1])

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

            let context = FriendRecommendationContext(
                artists: [savedArtist, unsavedArtist], events: events)
            let recommendations = context.recommendations(
                friendProfiles: [friendProfile], savedEventIDs: [1301], ratings: [:])

            #expect(recommendations.map(\.artist.id) == [unsavedArtist.id])
        }
        @Test
        func reusedProgramContextReflectsCurrentProfileAndFriendData() {
            let artist = TestFixtures.artist(id: 71)
            let event = TestFixtures.event(
                id: 1401, dayInJuly: 3, timeAsString: "18:00",
                stage: TestFixtures.stage(id: 1), artist: artist)
            let context = FriendRecommendationContext(artists: [artist], events: [event])
            let friend = TestFixtures.sharedFestivalProfile(savedEventIDs: [event.id])
            #expect(
                context.recommendations(friendProfiles: [friend], savedEventIDs: [], ratings: [:])
                    .map(\.id) == [artist.id])
            #expect(
                context.recommendations(
                    friendProfiles: [friend], savedEventIDs: [event.id], ratings: [:]
                ).isEmpty)
            #expect(
                context.recommendations(friendProfiles: [], savedEventIDs: [], ratings: [:]).isEmpty
            )
            #expect(
                context.recommendations(friendProfiles: [friend], savedEventIDs: [], ratings: [:])
                    .first?.artist === artist)
        }

    }
#endif
