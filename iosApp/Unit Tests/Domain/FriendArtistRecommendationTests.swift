#if os(iOS)
    import Testing
    @testable import Rudolstadt

    struct FriendProfileContentTests {
        @Test
        func sharedSavesMatchTheOccurrenceAndDiscoveriesContainTheRemainingSaves() {
            let artist = TestFixtures.artist(id: 61)
            let stage = TestFixtures.stage(id: 20)
            let first = TestFixtures.event(
                id: 1201, dayInJuly: 3, timeAsString: "18:00", stage: stage, artist: artist)
            let second = TestFixtures.event(
                id: 1202, dayInJuly: 3, timeAsString: "20:00", stage: stage, artist: artist)
            let third = TestFixtures.event(
                id: 1203, dayInJuly: 4, timeAsString: "18:00", stage: stage, artist: artist)
            let program = TestFixtures.festivalData(events: [third, second, first])
            let friend = TestFixtures.sharedFestivalProfile(savedEventIDs: [third.id, second.id, first.id, 9999])

            let content = FriendProfileContent(
                profile: friend, festivalData: program, ownSavedEventIDs: [second.id])

            #expect(content.shared.map(\.id) == [second.id])
            #expect(content.discoveries.map(\.id) == [first.id, third.id])
            #expect(content.saved.map(\.id) == [first.id, second.id, third.id])
        }

        @Test
        func discoveryRatingsAddPositiveRecommendationsForNewArtistsWithoutDuplicatingConcerts() {
            let discoverable = TestFixtures.artist(id: 71)
            let previouslySaved = TestFixtures.artist(id: 72)
            let previouslyRated = TestFixtures.artist(id: 73)
            let alreadySuggested = TestFixtures.artist(id: 74)
            let marked = TestFixtures.artist(id: 75)
            let artists = [discoverable, previouslySaved, previouslyRated, alreadySuggested, marked]
            let stage = TestFixtures.stage(id: 20)
            let events = artists.map { artist in
                TestFixtures.event(
                    id: artist.id + 1400, dayInJuly: 3, timeAsString: "18:00", stage: stage, artist: artist)
            }
            let ownSavedEvent = events[1]
            let friendSavedEvent = events[3]
            let preferences = artists.map { artist in
                FestivalArtistPreference(artistID: artist.id, rating: artist.id == marked.id ? -1 : 3, iconName: nil)
            }
            let friend = TestFixtures.sharedFestivalProfile(
                savedEventIDs: [friendSavedEvent.id], artistPreferences: preferences)

            let content = FriendProfileContent(
                profile: friend, festivalData: TestFixtures.festivalData(events: events),
                ownSavedEventIDs: [ownSavedEvent.id], ownRatings: [String(previouslyRated.id): -1])

            #expect(content.discoveryRatings.map(\.id) == [discoverable.id])
            #expect(content.discoveries.map(\.id) == [friendSavedEvent.id])
            #expect(content.ratings.count == artists.count)
        }

        @Test
        func profileFromAnotherEditionDoesNotMatchReusedProgramIDs() {
            let event = Event.example
            let program = TestFixtures.festivalData(events: [event])
            let friend = TestFixtures.sharedFestivalProfile(
                savedEventIDs: [event.id],
                artistPreferences: [.init(artistID: event.artist.id, rating: 3, iconName: nil)],
                festivalYear: program.festivalYear - 1)

            let content = FriendProfileContent(
                profile: friend, festivalData: program, ownSavedEventIDs: [event.id])

            #expect(content.saved.isEmpty)
            #expect(content.ratings.isEmpty)
            #expect(!content.hasDiscoveries)
        }
    }

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
