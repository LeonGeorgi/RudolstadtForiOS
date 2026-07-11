import Testing
@testable import Rudolstadt

struct RecommendationServiceTests {
    @Test
    func estimateEventDurationsUsesAtLeastOneHourWhenPossible() {
        let stage = TestFixtures.stage(id: 1, stageNumber: 1)
        let events = [
            TestFixtures.event(
                id: 101,
                dayInJuly: 3,
                timeAsString: "10:00",
                stage: stage,
                artist: TestFixtures.artist(id: 1)
            ),
            TestFixtures.event(
                id: 102,
                dayInJuly: 3,
                timeAsString: "11:00",
                stage: stage,
                artist: TestFixtures.artist(id: 2)
            ),
        ]

        let durations = RecommendationService().estimateEventDurations(
            events: events
        )

        #expect(durations[101] == 60)
        #expect(durations[102] == 60)
    }

    @Test
    func estimateEventDurationsEndsBeforeNextStageEventForShortGap() {
        let stage = TestFixtures.stage(id: 2, stageNumber: 2)
        let events = [
            TestFixtures.event(
                id: 103,
                dayInJuly: 3,
                timeAsString: "10:00",
                stage: stage,
                artist: TestFixtures.artist(id: 3)
            ),
            TestFixtures.event(
                id: 104,
                dayInJuly: 3,
                timeAsString: "10:45",
                stage: stage,
                artist: TestFixtures.artist(id: 4)
            ),
        ]

        let durations = RecommendationService().estimateEventDurations(
            events: events
        )

        #expect(durations[103] == 45)
        #expect(durations[104] == 60)
    }

    @Test
    func buildSnapshotReturnsNoRecommendationsWithoutPositiveRatings() {
        let festivalData = TestFixtures.festivalData(events: [
            TestFixtures.event(
                id: 201,
                dayInJuly: 3,
                timeAsString: "18:00",
                stage: TestFixtures.stage(id: 2),
                artist: TestFixtures.artist(id: 21)
            )
        ])

        let snapshot = RecommendationService().buildSnapshot(
            data: festivalData,
            savedEventIds: [],
            ratings: [:],
            now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        )

        #expect(snapshot.recommendedEventIds.isEmpty)
    }

    @Test
    func buildSnapshotDoesNotRecommendSavedArtistAgain() {
        let artist = TestFixtures.artist(id: 22)
        let stage = TestFixtures.stage(id: 3)
        let festivalData = TestFixtures.festivalData(events: [
            TestFixtures.event(
                id: 301,
                dayInJuly: 3,
                timeAsString: "18:00",
                stage: stage,
                artist: artist
            ),
            TestFixtures.event(
                id: 302,
                dayInJuly: 3,
                timeAsString: "20:00",
                stage: stage,
                artist: artist
            ),
        ])

        let snapshot = RecommendationService().buildSnapshot(
            data: festivalData,
            savedEventIds: [301],
            ratings: ["22": 3],
            now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        )

        #expect(snapshot.recommendedEventIds.isEmpty)
    }

    @Test
    func buildSnapshotKeepsSingleBestEventPerArtist() {
        let artist = TestFixtures.artist(id: 23)
        let stage = TestFixtures.stage(id: 4)
        let festivalData = TestFixtures.festivalData(events: [
            TestFixtures.event(
                id: 401,
                dayInJuly: 3,
                timeAsString: "18:00",
                stage: stage,
                artist: artist
            ),
            TestFixtures.event(
                id: 402,
                dayInJuly: 3,
                timeAsString: "20:00",
                stage: stage,
                artist: artist
            ),
        ])

        let snapshot = RecommendationService().buildSnapshot(
            data: festivalData,
            savedEventIds: [],
            ratings: ["23": 2],
            now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        )

        #expect(snapshot.recommendedEventIds == [401])
    }

    @Test
    func buildSnapshotChoosesHigherRatedEventWhenEventsConflict() {
        let stage = TestFixtures.stage(id: 5)
        let festivalData = TestFixtures.festivalData(events: [
            TestFixtures.event(
                id: 501,
                dayInJuly: 3,
                timeAsString: "18:00",
                stage: stage,
                artist: TestFixtures.artist(id: 24)
            ),
            TestFixtures.event(
                id: 502,
                dayInJuly: 3,
                timeAsString: "18:00",
                stage: stage,
                artist: TestFixtures.artist(id: 25)
            ),
        ])

        let snapshot = RecommendationService().buildSnapshot(
            data: festivalData,
            savedEventIds: [],
            ratings: ["24": 3, "25": 1],
            now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        )

        #expect(snapshot.recommendedEventIds == [501])
    }

    @Test
    func buildSnapshotIgnoresPastEvents() {
        let stage = TestFixtures.stage(id: 6)
        let festivalData = TestFixtures.festivalData(events: [
            TestFixtures.event(
                id: 601,
                dayInJuly: 3,
                timeAsString: "10:00",
                stage: stage,
                artist: TestFixtures.artist(id: 26)
            ),
            TestFixtures.event(
                id: 602,
                dayInJuly: 3,
                timeAsString: "18:00",
                stage: stage,
                artist: TestFixtures.artist(id: 27)
            ),
        ])

        let snapshot = RecommendationService().buildSnapshot(
            data: festivalData,
            savedEventIds: [],
            ratings: ["26": 3, "27": 3],
            now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        )

        #expect(snapshot.recommendedEventIds == [602])
    }

    @Test
    func buildSnapshotIsStableForUnchangedInputs() {
        let festivalData = TestFixtures.festivalData(events: [
            TestFixtures.event(
                id: 701,
                dayInJuly: 3,
                timeAsString: "18:00",
                stage: TestFixtures.stage(id: 7),
                artist: TestFixtures.artist(id: 28)
            )
        ])
        let service = RecommendationService()
        let now = TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)

        let first = service.buildSnapshot(
            data: festivalData,
            savedEventIds: [],
            ratings: ["28": 2],
            now: now
        )
        let second = service.buildSnapshot(
            data: festivalData,
            savedEventIds: [],
            ratings: ["28": 2],
            now: now
        )

        #expect(first == second)
    }
}
