import Foundation
import Testing
@testable import Rudolstadt

struct StageTransferEstimatorTests {
    @Test
    func sameStageNeedsNoWalkingData() {
        let location = PlanningTestFixtures.location(id: 1, northMeters: 0)
        let estimator = PlanningTestFixtures.estimator(
            locations: [location],
            matrix: .empty
        )

        let estimate = estimator.estimate(fromStageID: 1, toStageID: 1)

        #expect(estimate?.source == .sameStage)
        #expect(estimate?.distanceInMeters == 0)
        #expect(estimate?.walkingMinutes == 0)
    }

    @Test
    func knownRoutesWinAndUseConsistentCeiling() {
        let locations = (1...4).map { id in
            PlanningTestFixtures.location(id: id, northMeters: 0)
        }
        let matrix = StageWalkingDistanceMatrix(distancesByStageID: [
            1: [3: 80, 4: 81],
            2: [1: 79],
        ])
        let estimator = PlanningTestFixtures.estimator(
            locations: locations,
            matrix: matrix
        )

        let inverse = estimator.estimate(fromStageID: 1, toStageID: 2)
        let exactMinute = estimator.estimate(fromStageID: 1, toStageID: 3)
        let overMinute = estimator.estimate(fromStageID: 1, toStageID: 4)

        #expect(inverse?.source == .knownRoute)
        #expect(inverse?.walkingMinutes == 1)
        #expect(exactMinute?.walkingMinutes == 1)
        #expect(overMinute?.walkingMinutes == 2)
    }

    @Test
    func asymmetricMatrixUsesShorterValueInBothDirections() {
        let matrix = StageWalkingDistanceMatrix(distancesByStageID: [
            1: [2: 200],
            2: [1: 150],
        ])

        #expect(matrix.distanceInMeters(from: 1, to: 2) == 150)
        #expect(matrix.distanceInMeters(from: 2, to: 1) == 150)
    }

    @Test
    func partialMatrixUsesKnownShortestPath() {
        let locations = [
            PlanningTestFixtures.location(id: 1, northMeters: 0),
            PlanningTestFixtures.location(id: 2, northMeters: 80),
            PlanningTestFixtures.location(id: 3, northMeters: 160),
        ]
        let matrix = StageWalkingDistanceMatrix(distancesByStageID: [
            1: [2: 100],
            2: [3: 100],
        ])
        let estimator = PlanningTestFixtures.estimator(
            locations: locations,
            matrix: matrix
        )

        let estimate = estimator.estimate(fromStageID: 1, toStageID: 3)

        #expect(estimate?.source == .knownRoute)
        #expect(estimate?.distanceInMeters == 200)
        #expect(estimate?.walkingMinutes == 3)
    }

    @Test
    func removedStageIsNotUsedAsShortestPathIntermediate() {
        let locations = [
            PlanningTestFixtures.location(id: 1, northMeters: 0),
            PlanningTestFixtures.location(id: 3, northMeters: 160),
        ]
        let matrix = StageWalkingDistanceMatrix(distancesByStageID: [
            1: [2: 100],
            2: [3: 100],
        ])
        let estimator = PlanningTestFixtures.estimator(
            locations: locations,
            matrix: matrix
        )

        let estimate = estimator.estimate(fromStageID: 1, toStageID: 3)

        #expect(estimate?.source == .directCoordinateEstimate)
        #expect((estimate?.distanceInMeters ?? 0) > 239)
        #expect((estimate?.distanceInMeters ?? 300) < 241)
    }

    @Test
    func newStageFiveMetersFromKnownStageRoundsToOneMinute() {
        let locations = [
            PlanningTestFixtures.location(id: 1, northMeters: 0),
            PlanningTestFixtures.location(id: 2, northMeters: 500),
            PlanningTestFixtures.location(id: 99, northMeters: 5),
        ]
        let matrix = StageWalkingDistanceMatrix(
            distancesByStageID: [1: [2: 700]]
        )
        let estimator = PlanningTestFixtures.estimator(
            locations: locations,
            matrix: matrix
        )

        let estimate = estimator.estimate(fromStageID: 99, toStageID: 1)

        #expect(estimate?.source == .anchoredEstimate)
        #expect(estimate?.walkingMinutes == 1)
        #expect((estimate?.distanceInMeters ?? 0) > 7)
        #expect((estimate?.distanceInMeters ?? 100) < 8)
    }

    @Test
    func anchorConnectorCombinesWithKnownRoute() {
        let locations = [
            PlanningTestFixtures.location(id: 1, northMeters: 0),
            PlanningTestFixtures.location(id: 2, northMeters: 500),
            PlanningTestFixtures.location(id: 99, northMeters: 5),
        ]
        let matrix = StageWalkingDistanceMatrix(
            distancesByStageID: [1: [2: 700]]
        )
        let estimator = PlanningTestFixtures.estimator(
            locations: locations,
            matrix: matrix
        )

        let estimate = estimator.estimate(fromStageID: 99, toStageID: 2)

        #expect(estimate?.source == .anchoredEstimate)
        #expect((estimate?.distanceInMeters ?? 0) > 707)
        #expect((estimate?.distanceInMeters ?? 800) < 708)
        #expect(estimate?.walkingMinutes == 9)
    }

    @Test
    func multipleNearbyAnchorsCanBeatTheNearestAnchor() {
        let locations = [
            PlanningTestFixtures.location(id: 1, northMeters: 100),
            PlanningTestFixtures.location(id: 2, northMeters: 110),
            PlanningTestFixtures.location(id: 3, northMeters: 120),
            PlanningTestFixtures.location(id: 4, northMeters: 1_000),
            PlanningTestFixtures.location(id: 99, northMeters: 0),
        ]
        let matrix = StageWalkingDistanceMatrix(distancesByStageID: [
            1: [4: 1_200],
            2: [4: 900],
            3: [4: 1_000],
        ])
        let estimator = PlanningTestFixtures.estimator(
            locations: locations,
            matrix: matrix
        )

        let estimate = estimator.estimate(fromStageID: 99, toStageID: 4)

        #expect(estimate?.source == .anchoredEstimate)
        #expect((estimate?.distanceInMeters ?? 0) > 1_064)
        #expect((estimate?.distanceInMeters ?? 1_100) < 1_066)
    }

    @Test
    func knownEndpointCannotUseEstimatedAnchorShortcut() {
        let locations = [
            PlanningTestFixtures.location(id: 1, northMeters: 0),
            PlanningTestFixtures.location(id: 2, northMeters: 1_000),
            PlanningTestFixtures.location(id: 3, northMeters: 1_005),
            PlanningTestFixtures.location(id: 99, northMeters: 5),
        ]
        let matrix = StageWalkingDistanceMatrix(distancesByStageID: [
            1: [2: 900, 3: 1_100],
            2: [3: 700],
        ])
        let estimator = PlanningTestFixtures.estimator(
            locations: locations,
            matrix: matrix
        )

        let estimate = estimator.estimate(fromStageID: 99, toStageID: 3)

        #expect(estimate?.source == .anchoredEstimate)
        #expect((estimate?.distanceInMeters ?? 0) > 1_107)
        #expect((estimate?.distanceInMeters ?? 1_200) < 1_108)
    }

    @Test
    func directCandidateWinsForTwoAdjacentUnknownStages() {
        let locations = [
            PlanningTestFixtures.location(id: 1, northMeters: 0),
            PlanningTestFixtures.location(id: 2, northMeters: 1_000),
            PlanningTestFixtures.location(id: 91, northMeters: 10),
            PlanningTestFixtures.location(id: 92, northMeters: 15),
        ]
        let matrix = StageWalkingDistanceMatrix(
            distancesByStageID: [1: [2: 1_500]]
        )
        let estimator = PlanningTestFixtures.estimator(
            locations: locations,
            matrix: matrix
        )

        let estimate = estimator.estimate(fromStageID: 91, toStageID: 92)

        #expect(estimate?.source == .directCoordinateEstimate)
        #expect(estimate?.walkingMinutes == 1)
        #expect((estimate?.distanceInMeters ?? 100) < 8)
    }

    @Test
    func invalidCoordinatesProduceUnknownInsteadOfHugeDistance() {
        let estimator = PlanningTestFixtures.estimator(
            locations: [
                StageTransferLocation(stageID: 26, latitude: 0, longitude: 0),
                PlanningTestFixtures.location(id: 1, northMeters: 0),
            ],
            matrix: .empty
        )

        #expect(estimator.estimate(fromStageID: 26, toStageID: 1) == nil)
    }

    @Test
    func estimatedStagesNeverBecomeAnchors() {
        let locations = [
            PlanningTestFixtures.location(id: 1, northMeters: 0),
            PlanningTestFixtures.location(id: 2, northMeters: 100),
            PlanningTestFixtures.location(id: 99, northMeters: 290),
            PlanningTestFixtures.location(id: 100, northMeters: 580),
        ]
        let matrix = StageWalkingDistanceMatrix(
            distancesByStageID: [1: [2: 120]]
        )
        let estimator = PlanningTestFixtures.estimator(
            locations: locations,
            matrix: matrix
        )

        let estimate = estimator.estimate(fromStageID: 100, toStageID: 1)

        #expect(estimate?.source == .directCoordinateEstimate)
    }

    @Test
    func grosslyStaleMatrixRouteDegradesToEstimate() {
        let locations = [
            PlanningTestFixtures.location(id: 1, northMeters: 0),
            PlanningTestFixtures.location(id: 2, northMeters: 1_000),
        ]
        let matrix = StageWalkingDistanceMatrix(
            distancesByStageID: [1: [2: 10]]
        )
        let estimator = PlanningTestFixtures.estimator(
            locations: locations,
            matrix: matrix
        )

        let estimate = estimator.estimate(fromStageID: 1, toStageID: 2)

        #expect(estimate?.source == .directCoordinateEstimate)
        #expect((estimate?.distanceInMeters ?? 0) > 1_490)
    }

    @Test
    func malformedMatrixEntriesDoNotDiscardValidEntries() throws {
        let data = Data(
            #"{"1":{"2":79,"3":"bad","4":true,"5":null},"not-an-id":{"3":10},"2":"bad","3":{"4":-4}}"#.utf8
        )

        let matrix = try StageWalkingDistanceProvider.decodeMatrix(from: data)

        #expect(matrix.distanceInMeters(from: 1, to: 2) == 79)
        #expect(matrix.distanceInMeters(from: 1, to: 3) == nil)
        #expect(matrix.distanceInMeters(from: 1, to: 4) == nil)
        #expect(matrix.distanceInMeters(from: 3, to: 4) == nil)
    }

    @Test
    func pathologicalValuesProduceUnknownWithoutOverflowing() {
        let matrix = StageWalkingDistanceMatrix(
            distancesByStageID: [1: [2: .greatestFiniteMagnitude]]
        )
        #expect(!matrix.containsStage(id: 1))

        var policy = StageTransferPolicy()
        policy.walkingSpeedInMetersPerMinute = .leastNonzeroMagnitude
        let estimator = StageTransferEstimator(
            locations: [
                PlanningTestFixtures.location(id: 1, northMeters: 0),
                PlanningTestFixtures.location(id: 2, northMeters: 5),
            ],
            matrix: .empty,
            policy: policy
        )

        #expect(estimator.estimate(fromStageID: 1, toStageID: 2) == nil)
    }
}

struct ScheduleTransitionEvaluatorTests {
    @Test
    func timeOverlapIsAConflictEvenWhenTransferIsUnknown() {
        let firstStage = TestFixtures.stage(id: 1, latitude: 0, longitude: 0)
        let secondStage = TestFixtures.stage(id: 2, latitude: 0, longitude: 0)
        let evaluator = PlanningTestFixtures.transitionEvaluator(
            stages: [firstStage, secondStage],
            matrix: .empty
        )
        let first = PlanningTestFixtures.event(
            id: 1,
            time: "18:00",
            stage: firstStage
        )
        let second = PlanningTestFixtures.event(
            id: 2,
            time: "18:30",
            stage: secondStage
        )

        let assessment = evaluator.assess(
            first: first,
            firstDurationMinutes: 60,
            second: second,
            secondDurationMinutes: 60,
            policy: .recommendation
        )

        #expect(assessment.timeOverlapMinutes == 30)
        #expect(assessment.transfer == nil)
        #expect(assessment.status == .impossible)
        #expect(assessment.isConflict)
    }

    @Test
    func unknownTransferAloneDoesNotCreateConflict() {
        let firstStage = TestFixtures.stage(id: 1, latitude: 0, longitude: 0)
        let secondStage = TestFixtures.stage(id: 2, latitude: 0, longitude: 0)
        let evaluator = PlanningTestFixtures.transitionEvaluator(
            stages: [firstStage, secondStage],
            matrix: .empty
        )

        let assessment = evaluator.assess(
            first: PlanningTestFixtures.event(id: 1, time: "18:00", stage: firstStage),
            firstDurationMinutes: 60,
            second: PlanningTestFixtures.event(id: 2, time: "20:00", stage: secondStage),
            secondDurationMinutes: 60,
            policy: .recommendation
        )

        #expect(assessment.timeOverlapMinutes == 0)
        #expect(assessment.transfer == nil)
        #expect(assessment.status == .unknown)
        #expect(!assessment.isConflict)
    }

    @Test
    func estimatedTransferIsAdvisoryForRecommendations() {
        let firstStage = TestFixtures.stage(id: 1, latitude: 50, longitude: 11)
        let secondStage = TestFixtures.stage(id: 2, latitude: 50.005, longitude: 11)
        let evaluator = PlanningTestFixtures.transitionEvaluator(
            stages: [firstStage, secondStage],
            matrix: .empty
        )

        let assessment = evaluator.assess(
            first: PlanningTestFixtures.event(id: 1, time: "18:00", stage: firstStage),
            firstDurationMinutes: 60,
            second: PlanningTestFixtures.event(id: 2, time: "19:02", stage: secondStage),
            secondDurationMinutes: 60,
            policy: .recommendation
        )

        #expect(assessment.transfer?.source == .directCoordinateEstimate)
        #expect((assessment.projectedLatenessMinutes ?? 0) > 0)
        #expect(assessment.status == .unknown)
        #expect(!assessment.isConflict)
    }

    @Test
    func knownTransfersProduceComfortableTightAndImpossibleStatuses() {
        let firstStage = TestFixtures.stage(id: 1, latitude: 50, longitude: 11)
        let secondStage = TestFixtures.stage(id: 2, latitude: 50, longitude: 11)
        let evaluator = PlanningTestFixtures.transitionEvaluator(
            stages: [firstStage, secondStage],
            matrix: StageWalkingDistanceMatrix(
                distancesByStageID: [1: [2: 160]]
            )
        )
        let first = PlanningTestFixtures.event(id: 1, time: "18:00", stage: firstStage)

        let comfortable = evaluator.assess(
            first: first,
            firstDurationMinutes: 60,
            second: PlanningTestFixtures.event(id: 2, time: "19:15", stage: secondStage),
            secondDurationMinutes: 60,
            policy: .recommendation
        )
        let tight = evaluator.assess(
            first: first,
            firstDurationMinutes: 60,
            second: PlanningTestFixtures.event(id: 3, time: "19:09", stage: secondStage),
            secondDurationMinutes: 60,
            policy: .recommendation
        )
        let impossible = evaluator.assess(
            first: first,
            firstDurationMinutes: 60,
            second: PlanningTestFixtures.event(id: 4, time: "19:02", stage: secondStage),
            secondDurationMinutes: 60,
            policy: .recommendation
        )

        #expect(comfortable.status == .comfortable)
        #expect(tight.status == .tight)
        #expect(impossible.status == .impossible)
        #expect(impossible.projectedLatenessMinutes == 2)
    }

    @Test
    func overlapIsIndependentOfArgumentAndIdentifierOrder() {
        let stage = TestFixtures.stage(id: 1)
        let evaluator = PlanningTestFixtures.transitionEvaluator(
            stages: [stage],
            matrix: .empty
        )
        let shortHighID = PlanningTestFixtures.event(
            id: 100,
            time: "18:00",
            stage: stage
        )
        let longLowID = PlanningTestFixtures.event(
            id: 1,
            time: "18:00",
            stage: stage
        )

        let forward = evaluator.assess(
            first: longLowID,
            firstDurationMinutes: 60,
            second: shortHighID,
            secondDurationMinutes: 10,
            policy: .recommendation
        )
        let reverse = evaluator.assess(
            first: shortHighID,
            firstDurationMinutes: 10,
            second: longLowID,
            secondDurationMinutes: 60,
            policy: .recommendation
        )

        #expect(forward.timeOverlapMinutes == 10)
        #expect(reverse.timeOverlapMinutes == 10)
        #expect(forward.firstEventID == shortHighID.id)
        #expect(reverse.firstEventID == shortHighID.id)
    }

    @Test
    func midnightTransitionUsesRealDates() {
        let stage = TestFixtures.stage(id: 1)
        let evaluator = PlanningTestFixtures.transitionEvaluator(
            stages: [stage],
            matrix: .empty
        )
        let beforeMidnight = PlanningTestFixtures.event(
            id: 1,
            day: 3,
            time: "23:30",
            stage: stage
        )
        let afterMidnight = PlanningTestFixtures.event(
            id: 2,
            day: 4,
            time: "00:40",
            stage: stage
        )

        let assessment = evaluator.assess(
            first: beforeMidnight,
            firstDurationMinutes: 60,
            second: afterMidnight,
            secondDurationMinutes: 60,
            policy: .recommendation
        )

        #expect(assessment.timeOverlapMinutes == 0)
        #expect(assessment.availableTransferMinutes == 8)
        #expect(assessment.status == .comfortable)
    }

    @Test
    func fiveOClockStartsANewFestivalDay() {
        let stage = TestFixtures.stage(id: 1)
        let evaluator = PlanningTestFixtures.transitionEvaluator(
            stages: [stage],
            matrix: .empty
        )
        let earlyMorning = PlanningTestFixtures.event(
            id: 1,
            day: 4,
            time: "04:30",
            stage: stage
        )
        let newFestivalDay = PlanningTestFixtures.event(
            id: 2,
            day: 4,
            time: "05:00",
            stage: stage
        )

        let assessment = evaluator.assess(
            first: earlyMorning,
            firstDurationMinutes: 30,
            second: newFestivalDay,
            secondDurationMinutes: 60,
            policy: .recommendation
        )

        #expect(assessment.status == .notApplicable)
        #expect(assessment.availableTransferMinutes == nil)
        #expect(!assessment.isConflict)
    }
}

struct WatchScheduleProjectorTests {
    @Test
    func projectionUsesOnlySavedEventsFromCurrentFestivalDay() {
        let stage = TestFixtures.stage(id: 1)
        let ongoing = PlanningTestFixtures.event(id: 1, time: "18:00", stage: stage)
        let upcoming = PlanningTestFixtures.event(id: 2, time: "19:30", stage: stage)
        let unrelated = PlanningTestFixtures.event(id: 3, time: "20:00", stage: stage)
        let otherDay = PlanningTestFixtures.event(id: 4, day: 4, time: "20:00", stage: stage)
        let now = TestFixtures.date(dayInJuly: 3, hour: 18, minute: 30)
        let evaluator = PlanningTestFixtures.transitionEvaluator(
            stages: [stage],
            matrix: .empty
        )

        let projection = WatchScheduleProjector().project(
            events: [unrelated, otherDay, upcoming, ongoing],
            savedEventIDs: [ongoing.id, upcoming.id, otherDay.id],
            estimatedDurationsByEventID: [ongoing.id: 60, upcoming.id: 60],
            now: now,
            transitionEvaluator: evaluator
        )

        #expect(projection.generatedAt == now)
        #expect(projection.currentFestivalDay == 3)
        #expect(projection.ongoingEvents.map(\.id) == [ongoing.id])
        #expect(projection.upcomingEvents.map(\.id) == [upcoming.id])
        #expect(projection.endedEvents.isEmpty)
        #expect(projection.transitions.count == 1)
        #expect(projection.transitions.first?.assessment.transfer?.source == .sameStage)
    }

    @Test
    func eventEndingExactlyNowIsEnded() {
        let stage = TestFixtures.stage(id: 1)
        let ended = PlanningTestFixtures.event(id: 1, time: "17:30", stage: stage)
        let now = TestFixtures.date(dayInJuly: 3, hour: 18, minute: 30)
        let evaluator = PlanningTestFixtures.transitionEvaluator(
            stages: [stage],
            matrix: .empty
        )

        let projection = WatchScheduleProjector().project(
            events: [ended],
            savedEventIDs: [ended.id],
            estimatedDurationsByEventID: [ended.id: 60],
            now: now,
            transitionEvaluator: evaluator
        )

        #expect(projection.ongoingEvents.isEmpty)
        #expect(projection.upcomingEvents.isEmpty)
        #expect(projection.endedEvents.map(\.id) == [ended.id])
        #expect(projection.transitions.isEmpty)
    }

    @Test
    func emptySavedPlanStillReportsCurrentFestivalDay() {
        let stage = TestFixtures.stage(id: 1)
        let programEvent = PlanningTestFixtures.event(id: 1, time: "18:00", stage: stage)
        let evaluator = PlanningTestFixtures.transitionEvaluator(
            stages: [stage],
            matrix: .empty
        )

        let projection = WatchScheduleProjector().project(
            events: [programEvent],
            savedEventIDs: [],
            estimatedDurationsByEventID: [:],
            now: TestFixtures.date(dayInJuly: 3, hour: 18, minute: 30),
            transitionEvaluator: evaluator
        )

        #expect(projection.currentFestivalDay == 3)
        #expect(projection.ongoingEvents.isEmpty)
        #expect(projection.upcomingEvents.isEmpty)
        #expect(projection.endedEvents.isEmpty)
    }

    @Test
    func simultaneousStartsAreRetainedAndOverlap() {
        let stage = TestFixtures.stage(id: 1)
        let first = PlanningTestFixtures.event(id: 2, time: "19:30", stage: stage)
        let second = PlanningTestFixtures.event(id: 1, time: "19:30", stage: stage)
        let evaluator = PlanningTestFixtures.transitionEvaluator(
            stages: [stage],
            matrix: .empty
        )

        let projection = WatchScheduleProjector().project(
            events: [first, second],
            savedEventIDs: [first.id, second.id],
            estimatedDurationsByEventID: [:],
            now: TestFixtures.date(dayInJuly: 3, hour: 18, minute: 30),
            transitionEvaluator: evaluator
        )

        #expect(projection.upcomingEvents.map(\.id) == [second.id, first.id])
        #expect(projection.overlaps.count == 1)
        #expect(projection.overlaps.first?.overlapMinutes == 60)
    }

    @Test
    func projectionFindsNonAdjacentOverlapPairs() {
        let stage = TestFixtures.stage(id: 1)
        let longEvent = PlanningTestFixtures.event(id: 1, time: "18:00", stage: stage)
        let middleEvent = PlanningTestFixtures.event(id: 2, time: "18:30", stage: stage)
        let laterEvent = PlanningTestFixtures.event(id: 3, time: "19:30", stage: stage)
        let evaluator = PlanningTestFixtures.transitionEvaluator(
            stages: [stage],
            matrix: .empty
        )

        let projection = WatchScheduleProjector().project(
            events: [longEvent, middleEvent, laterEvent],
            savedEventIDs: [longEvent.id, middleEvent.id, laterEvent.id],
            estimatedDurationsByEventID: [
                longEvent.id: 180,
                middleEvent.id: 30,
                laterEvent.id: 30,
            ],
            now: TestFixtures.date(dayInJuly: 3, hour: 17, minute: 30),
            transitionEvaluator: evaluator
        )

        let overlapPairs = projection.overlaps.map { overlap in
            "\(overlap.firstEventID)-\(overlap.secondEventID)"
        }
        #expect(overlapPairs == ["1-2", "1-3"])
    }

    @Test
    func projectionKeepsBothLocalizedStageNames() {
        let stage = TestFixtures.stage(
            id: 1,
            germanName: "Große Bühne",
            englishName: "Main Stage"
        )
        let event = PlanningTestFixtures.event(id: 1, time: "19:30", stage: stage)
        let evaluator = PlanningTestFixtures.transitionEvaluator(
            stages: [stage],
            matrix: .empty
        )

        let projection = WatchScheduleProjector().project(
            events: [event],
            savedEventIDs: [event.id],
            estimatedDurationsByEventID: [:],
            now: TestFixtures.date(dayInJuly: 3, hour: 18, minute: 30),
            transitionEvaluator: evaluator
        )

        #expect(projection.upcomingEvents.first?.stageNameGerman == "Große Bühne")
        #expect(projection.upcomingEvents.first?.stageNameEnglish == "Main Stage")
    }

    @Test
    func projectionUsesBerlinTimeWithForeignDeviceCalendar() {
        var tokyoCalendar = Calendar(identifier: .gregorian)
        tokyoCalendar.locale = Locale(identifier: "en_US_POSIX")
        tokyoCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        let stage = TestFixtures.stage(id: 1)
        let event = PlanningTestFixtures.event(id: 1, time: "22:00", stage: stage)
        let evaluator = ScheduleTransitionEvaluator(
            transferEstimator: StageTransferEstimator(
                stages: [stage],
                matrix: .empty
            ),
            calendar: tokyoCalendar
        )
        let berlinNow = TestFixtures.date(
            dayInJuly: 3,
            hour: 22,
            minute: 30
        )

        let projection = WatchScheduleProjector().project(
            events: [event],
            savedEventIDs: [event.id],
            estimatedDurationsByEventID: [event.id: 60],
            now: berlinNow,
            transitionEvaluator: evaluator
        )

        #expect(evaluator.calendar.timeZone.identifier == "Europe/Berlin")
        #expect(projection.currentFestivalDay == 3)
        #expect(projection.ongoingEvents.map(\.id) == [event.id])
    }
}

struct RecommendationTransferResilienceTests {
    @Test
    func invalidGemeindesaalCoordinatesDoNotSuppressLaterRecommendation() {
        let gemeindesaal = TestFixtures.stage(
            id: 26,
            latitude: 0,
            longitude: 0
        )
        let otherStage = TestFixtures.stage(
            id: 50,
            latitude: 50.72,
            longitude: 11.34
        )
        let saved = PlanningTestFixtures.event(
            id: 1,
            time: "18:00",
            stage: gemeindesaal,
            artistID: 1
        )
        let candidate = PlanningTestFixtures.event(
            id: 2,
            time: "20:00",
            stage: otherStage,
            artistID: 2
        )
        let data = TestFixtures.festivalData(events: [saved, candidate])
        let service = RecommendationService(
            calendar: TestFixtures.festivalCalendar,
            walkingDistanceMatrix: .empty
        )

        let snapshot = service.buildSnapshot(
            data: data,
            savedEventIds: [saved.id],
            ratings: ["2": 3],
            now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        )

        #expect(snapshot.recommendedEventIds == [candidate.id])
    }
}

private enum PlanningTestFixtures {
    static func location(id: Int, northMeters: Double) -> StageTransferLocation {
        StageTransferLocation(
            stageID: id,
            latitude: 50 + northMeters / 111_195,
            longitude: 11
        )
    }

    static func estimator(
        locations: [StageTransferLocation],
        matrix: StageWalkingDistanceMatrix
    ) -> StageTransferEstimator {
        StageTransferEstimator(locations: locations, matrix: matrix)
    }

    static func transitionEvaluator(
        stages: [Stage],
        matrix: StageWalkingDistanceMatrix
    ) -> ScheduleTransitionEvaluator {
        ScheduleTransitionEvaluator(
            transferEstimator: StageTransferEstimator(
                stages: stages,
                matrix: matrix
            ),
            calendar: TestFixtures.festivalCalendar
        )
    }

    static func event(
        id: Int,
        day: Int = 3,
        time: String,
        stage: Stage,
        artistID: Int? = nil
    ) -> Event {
        TestFixtures.event(
            id: id,
            dayInJuly: day,
            timeAsString: time,
            stage: stage,
            artist: TestFixtures.artist(id: artistID ?? id)
        )
    }
}
