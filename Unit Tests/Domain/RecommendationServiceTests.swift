import Foundation
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

        let durations = makeService().estimateEventDurations(
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

        let durations = makeService().estimateEventDurations(
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

        let snapshot = makeService().buildSnapshot(
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

        let snapshot = makeService().buildSnapshot(
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

        let snapshot = makeService().buildSnapshot(
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

        let snapshot = makeService().buildSnapshot(
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

        let snapshot = makeService().buildSnapshot(
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
        let service = makeService()
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

    @Test
    func recommendationOrderDoesNotDependOnInputOrder() {
        let events = [
            TestFixtures.event(
                id: 711,
                dayInJuly: 3,
                timeAsString: "20:00",
                stage: TestFixtures.stage(id: 71),
                artist: TestFixtures.artist(id: 72)
            ),
            TestFixtures.event(
                id: 712,
                dayInJuly: 3,
                timeAsString: "18:00",
                stage: TestFixtures.stage(id: 72),
                artist: TestFixtures.artist(id: 71)
            ),
        ]
        let now = TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)

        let forward = makeService().buildSnapshot(
            data: TestFixtures.festivalData(events: events),
            savedEventIds: [],
            ratings: ["71": 2, "72": 2],
            now: now
        )
        let reversed = makeService().buildSnapshot(
            data: TestFixtures.festivalData(events: events.reversed()),
            savedEventIds: [],
            ratings: ["71": 2, "72": 2],
            now: now
        )

        #expect(forward == reversed)
        #expect(forward.recommendedEventIds == [712, 711])
    }

    @Test
    func recommendedScheduleAlwaysKeepsSavedEvents() {
        let stage = TestFixtures.stage(id: 8)
        let savedPastEvent = TestFixtures.event(
            id: 801,
            dayInJuly: 3,
            timeAsString: "10:00",
            stage: stage,
            artist: TestFixtures.artist(id: 31)
        )
        let savedConflictingEvent = TestFixtures.event(
            id: 802,
            dayInJuly: 3,
            timeAsString: "10:15",
            stage: stage,
            artist: TestFixtures.artist(id: 32)
        )
        let generator = ScheduleRecommendationGenerator(
            allEvents: [savedPastEvent, savedConflictingEvent],
            savedEventIds: [801, 802],
            artistRatings: [:],
            eventDurations: [801: 60, 802: 60],
            now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0),
            calendar: TestFixtures.festivalCalendar
        )

        #expect(generator.generateRecommendedSchedule().map(\.id) == [801, 802])
        #expect(generator.generateRecommendedEventIds().isEmpty)
    }

    @Test
    func recommendationsTreatAfterMidnightEventsAsPartOfPreviousFestivalDay() {
        let stage = TestFixtures.stage(id: 9)
        let beforeMidnight = TestFixtures.event(
            id: 901,
            dayInJuly: 3,
            timeAsString: "23:30",
            stage: stage,
            artist: TestFixtures.artist(id: 33)
        )
        let afterMidnight = TestFixtures.event(
            id: 902,
            dayInJuly: 4,
            timeAsString: "00:30",
            stage: stage,
            artist: TestFixtures.artist(id: 34)
        )
        let snapshot = makeService().buildSnapshot(
            data: TestFixtures.festivalData(events: [afterMidnight, beforeMidnight]),
            savedEventIds: [901],
            ratings: ["34": 3],
            now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        )

        #expect(beforeMidnight.festivalDay(calendar: TestFixtures.festivalCalendar) == 3)
        #expect(afterMidnight.festivalDay(calendar: TestFixtures.festivalCalendar) == 3)
        #expect(snapshot.recommendedEventIds.isEmpty)
    }

    @Test
    func recommendationsAccountForWalkingTimeAndArrivalBuffer() {
        let artist = TestFixtures.artist(id: 35)
        let savedEvent = TestFixtures.event(
            id: 1001,
            dayInJuly: 3,
            timeAsString: "18:00",
            stage: TestFixtures.stage(id: 10),
            artist: TestFixtures.artist(id: 36)
        )
        let sameStageCandidate = TestFixtures.event(
            id: 1002,
            dayInJuly: 3,
            timeAsString: "19:02",
            stage: savedEvent.stage,
            artist: artist
        )
        let otherStageCandidate = TestFixtures.event(
            id: 1003,
            dayInJuly: 3,
            timeAsString: "19:02",
            stage: TestFixtures.stage(id: 11),
            artist: artist
        )

        let sameStageSnapshot = makeService().buildSnapshot(
            data: TestFixtures.festivalData(events: [savedEvent, sameStageCandidate]),
            savedEventIds: [savedEvent.id],
            ratings: ["35": 3],
            now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        )
        let otherStageSnapshot = makeService().buildSnapshot(
            data: TestFixtures.festivalData(events: [savedEvent, otherStageCandidate]),
            savedEventIds: [savedEvent.id],
            ratings: ["35": 3],
            now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        )

        #expect(sameStageSnapshot.recommendedEventIds == [sameStageCandidate.id])
        #expect(otherStageSnapshot.recommendedEventIds.isEmpty)
    }

    @Test
    func estimateEventDurationsCoversGapBoundaries() {
        let cases = [
            (gapMinutes: 20, expectedDuration: 20),
            (gapMinutes: 45, expectedDuration: 45),
            (gapMinutes: 60, expectedDuration: 60),
            (gapMinutes: 120, expectedDuration: 60),
            (gapMinutes: 180, expectedDuration: 90),
            (gapMinutes: 360, expectedDuration: 60),
        ]

        for (index, testCase) in cases.enumerated() {
            let stage = TestFixtures.stage(id: 20 + index)
            let start = TestFixtures.event(
                id: 1100 + index * 2,
                dayInJuly: 3,
                timeAsString: "10:00",
                stage: stage,
                artist: TestFixtures.artist(id: 100 + index * 2)
            )
            let nextMinutes = 10 * 60 + testCase.gapMinutes
            let nextTime = String(
                format: "%02d:%02d",
                nextMinutes / 60,
                nextMinutes % 60
            )
            let next = TestFixtures.event(
                id: start.id + 1,
                dayInJuly: 3,
                timeAsString: nextTime,
                stage: stage,
                artist: TestFixtures.artist(id: 101 + index * 2)
            )

            let durations = makeService().estimateEventDurations(events: [next, start])

            #expect(
                durations[start.id] == testCase.expectedDuration,
                "Unexpected duration for a \(testCase.gapMinutes)-minute gap"
            )
        }
    }

    @Test
    func seededSchedulesPreserveRecommendationInvariants() {
        for seed in [7, 42, 2_026] {
            var generator = SeededGenerator(seed: UInt64(seed))
            let events = (0..<80).map { index in
                let artistID = generator.nextInt(upperBound: 30) + 1
                let day = generator.nextInt(upperBound: 4) + 3
                let minuteSlot = generator.nextInt(upperBound: 28)
                let minutes = 10 * 60 + minuteSlot * 30
                return TestFixtures.event(
                    id: seed * 1_000 + index,
                    dayInJuly: day,
                    timeAsString: String(format: "%02d:%02d", minutes / 60, minutes % 60),
                    stage: TestFixtures.stage(id: generator.nextInt(upperBound: 8) + 40),
                    artist: TestFixtures.artist(id: artistID)
                )
            }
            let ratings = Dictionary(uniqueKeysWithValues: (1...30).map { artistID in
                (String(artistID), generator.nextInt(upperBound: 3) + 1)
            })
            let service = makeService()
            let now = TestFixtures.date(dayInJuly: 3, hour: 9, minute: 0)
            let snapshot = service.buildSnapshot(
                data: TestFixtures.festivalData(events: events),
                savedEventIds: [],
                ratings: ratings,
                now: now
            )
            let recommendedEvents = snapshot.recommendedEventIds.compactMap { id in
                events.first(where: { $0.id == id })
            }

            #expect(recommendedEvents.count == snapshot.recommendedEventIds.count)
            #expect(Set(recommendedEvents.map(\.artist.id)).count == recommendedEvents.count)
            #expect(recommendedEvents.allSatisfy { event in
                event.date(calendar: TestFixtures.festivalCalendar) >= now
            })
            for firstIndex in recommendedEvents.indices {
                for secondIndex in recommendedEvents.indices where secondIndex > firstIndex {
                    let first = recommendedEvents[firstIndex]
                    let second = recommendedEvents[secondIndex]
                    #expect(!first.intersects(
                        with: second,
                        event1Duration: snapshot.estimatedEventDurations[first.id] ?? 60,
                        event2Duration: snapshot.estimatedEventDurations[second.id] ?? 60,
                        maxAllowedMissedMinutes: 0,
                        arrivalBufferMinutes: 2,
                        calendar: TestFixtures.festivalCalendar
                    ))
                }
            }
        }
    }

    private func makeService() -> RecommendationService {
        RecommendationService(calendar: TestFixtures.festivalCalendar)
    }
}

private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextInt(upperBound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int(state % UInt64(upperBound))
    }
}
