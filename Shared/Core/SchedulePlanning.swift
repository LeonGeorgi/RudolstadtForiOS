import Foundation

enum ScheduleTransitionStatus: Equatable, Sendable {
    case notApplicable
    case comfortable
    case tight
    case impossible
    case unknown
}

struct ScheduleTransitionPolicy: Equatable, Sendable {
    var arrivalBufferMinutes: Int
    var maximumMissedMinutes: Int
    var tightTransitionThresholdMinutes: Int
    var estimatedTransfersCanBlock: Bool

    static let recommendation = ScheduleTransitionPolicy(
        arrivalBufferMinutes: 2,
        maximumMissedMinutes: 0,
        tightTransitionThresholdMinutes: 5,
        estimatedTransfersCanBlock: false
    )

    static let savedEventWarning = ScheduleTransitionPolicy(
        arrivalBufferMinutes: 0,
        maximumMissedMinutes: 5,
        tightTransitionThresholdMinutes: 5,
        estimatedTransfersCanBlock: true
    )
}

struct ScheduleTransitionAssessment: Equatable, Sendable {
    let firstEventID: Int
    let secondEventID: Int
    let timeOverlapMinutes: Int
    let availableTransferMinutes: Int?
    let transfer: StageTransferEstimate?
    let projectedLatenessMinutes: Int?
    let status: ScheduleTransitionStatus

    var isConflict: Bool {
        status == .impossible
    }
}

struct ScheduleTransitionEvaluator: Sendable {
    let transferEstimator: StageTransferEstimator
    let transferProvider: (@Sendable (FestivalPlaceID, FestivalPlaceID) -> StageTransferEstimate?)?
    let calendar: Calendar

    init(
        transferEstimator: StageTransferEstimator,
        calendar: Calendar = .current,
        transferProvider: (@Sendable (FestivalPlaceID, FestivalPlaceID) -> StageTransferEstimate?)? = nil
    ) {
        self.transferProvider = transferProvider
        self.transferEstimator = transferEstimator
        self.calendar = calendar
    }

    func assess(
        first firstEvent: Event,
        firstDurationMinutes: Int,
        second secondEvent: Event,
        secondDurationMinutes: Int,
        policy: ScheduleTransitionPolicy
    ) -> ScheduleTransitionAssessment {
        let orderedEvents = order(
            firstEvent: firstEvent,
            firstDurationMinutes: firstDurationMinutes,
            secondEvent: secondEvent,
            secondDurationMinutes: secondDurationMinutes
        )

        guard let firstStart = orderedEvents.first.event.startDate,
            let secondStart = orderedEvents.second.event.startDate
        else {
            return ScheduleTransitionAssessment(
                firstEventID: firstEvent.id,
                secondEventID: secondEvent.id, timeOverlapMinutes: 0,
                availableTransferMinutes: nil, transfer: nil, projectedLatenessMinutes: nil,
                status: .unknown)
        }

        guard (orderedEvents.first.event.programDay?.id ?? String(orderedEvents.first.event.festivalDay(calendar: calendar)))
                == (orderedEvents.second.event.programDay?.id ?? String(orderedEvents.second.event.festivalDay(calendar: calendar)))
        else {
            return ScheduleTransitionAssessment(
                firstEventID: orderedEvents.first.event.id,
                secondEventID: orderedEvents.second.event.id,
                timeOverlapMinutes: 0,
                availableTransferMinutes: nil,
                transfer: nil,
                projectedLatenessMinutes: nil,
                status: .notApplicable
            )
        }

        let firstEnd = firstStart.addingTimeInterval(
            TimeInterval(max(0, orderedEvents.first.durationMinutes)) * 60
        )
        let secondEnd = secondStart.addingTimeInterval(
            TimeInterval(max(0, orderedEvents.second.durationMinutes)) * 60
        )
        let overlapSeconds = max(
            0,
            min(firstEnd, secondEnd).timeIntervalSince(max(firstStart, secondStart))
        )
        let timeOverlapMinutes = Int(ceil(overlapSeconds / 60))
        let availableSeconds = secondStart.timeIntervalSince(firstEnd)
            - TimeInterval(max(0, policy.arrivalBufferMinutes)) * 60
        let availableTransferMinutes = Int(floor(availableSeconds / 60))
        let transfer: StageTransferEstimate?
        if let transferProvider {
            transfer = transferProvider(orderedEvents.first.event.stage.id, orderedEvents.second.event.stage.id)
        } else {
            transfer = transferEstimator.estimate(from: orderedEvents.first.event.stage, to: orderedEvents.second.event.stage)
        }
        let projectedLatenessMinutes = transfer.map { estimate in
            max(0, estimate.walkingMinutes - availableTransferMinutes)
        }
        let maximumMissedMinutes = max(0, policy.maximumMissedMinutes)

        let status: ScheduleTransitionStatus
        if timeOverlapMinutes > maximumMissedMinutes {
            status = .impossible
        } else if let transfer, let projectedLatenessMinutes {
            if projectedLatenessMinutes > maximumMissedMinutes {
                status = transfer.source.isEstimated
                    && !policy.estimatedTransfersCanBlock
                    ? .unknown
                    : .impossible
            } else {
                let remainingMinutes =
                    availableTransferMinutes - transfer.walkingMinutes
                status = remainingMinutes
                    <= max(0, policy.tightTransitionThresholdMinutes)
                    ? .tight
                    : .comfortable
            }
        } else {
            status = .unknown
        }

        return ScheduleTransitionAssessment(
            firstEventID: orderedEvents.first.event.id,
            secondEventID: orderedEvents.second.event.id,
            timeOverlapMinutes: timeOverlapMinutes,
            availableTransferMinutes: availableTransferMinutes,
            transfer: transfer,
            projectedLatenessMinutes: projectedLatenessMinutes,
            status: status
        )
    }

    private func order(
        firstEvent: Event,
        firstDurationMinutes: Int,
        secondEvent: Event,
        secondDurationMinutes: Int
    ) -> (
        first: (event: Event, durationMinutes: Int),
        second: (event: Event, durationMinutes: Int)
    ) {
        if precedes(
            firstEvent,
            durationMinutes: firstDurationMinutes,
            secondEvent,
            durationMinutes: secondDurationMinutes
        ) {
            return (
                (firstEvent, firstDurationMinutes),
                (secondEvent, secondDurationMinutes)
            )
        }
        return (
            (secondEvent, secondDurationMinutes),
            (firstEvent, firstDurationMinutes)
        )
    }

    private func precedes(
        _ firstEvent: Event,
        durationMinutes firstDurationMinutes: Int,
        _ secondEvent: Event,
        durationMinutes secondDurationMinutes: Int
    ) -> Bool {
        guard let firstDate = firstEvent.startDate, let secondDate = secondEvent.startDate else {
            return Event.precedes(firstEvent, secondEvent)
        }
        if firstDate != secondDate {
            return firstDate < secondDate
        }

        let firstEnd = firstDate.addingTimeInterval(
            TimeInterval(max(0, firstDurationMinutes)) * 60
        )
        let secondEnd = secondDate.addingTimeInterval(
            TimeInterval(max(0, secondDurationMinutes)) * 60
        )
        if firstEnd != secondEnd {
            return firstEnd < secondEnd
        }
        return firstEvent.id < secondEvent.id
    }
}

struct WatchScheduleEventProjection: Equatable, Sendable, Identifiable {
    let id: Int
    let artistID: Int
    let artistName: String
    let stageID: FestivalPlaceID
    let stageNameGerman: String
    let stageNameEnglish: String
    let startDate: Date
    let endDate: Date
}

struct WatchScheduleTransitionProjection: Equatable, Sendable {
    let fromEventID: Int
    let toEventID: Int
    let assessment: ScheduleTransitionAssessment
}

struct WatchScheduleOverlapProjection: Equatable, Sendable {
    let firstEventID: Int
    let secondEventID: Int
    let overlapMinutes: Int
}

struct WatchScheduleProjection: Equatable, Sendable {
    let generatedAt: Date
    let currentFestivalDay: Int?
    let ongoingEvents: [WatchScheduleEventProjection]
    let upcomingEvents: [WatchScheduleEventProjection]
    let endedEvents: [WatchScheduleEventProjection]
    let transitions: [WatchScheduleTransitionProjection]
    let overlaps: [WatchScheduleOverlapProjection]
}

struct WatchScheduleProjector: Sendable {
    let defaultDurationMinutes: Int
    let transitionPolicy: ScheduleTransitionPolicy

    init(
        defaultDurationMinutes: Int = 60,
        transitionPolicy: ScheduleTransitionPolicy = .savedEventWarning
    ) {
        self.defaultDurationMinutes = defaultDurationMinutes
        self.transitionPolicy = transitionPolicy
    }

    func project(
        events: [Event],
        savedEventIDs: Set<Int>,
        estimatedDurationsByEventID: [Int: Int],
        now: Date,
        transitionEvaluator: ScheduleTransitionEvaluator
    ) -> WatchScheduleProjection {
        let calendar = transitionEvaluator.calendar
        let eventDays = Array(Set(events.map { event in
            event.festivalDay(calendar: calendar)
        }))
        let currentFestivalDay = FestivalDateUtilities.getCurrentFestivalDay(
            eventDays: eventDays,
            now: now,
            calendar: calendar
        )

        guard let currentFestivalDay else {
            return WatchScheduleProjection(
                generatedAt: now,
                currentFestivalDay: nil,
                ongoingEvents: [],
                upcomingEvents: [],
                endedEvents: [],
                transitions: [],
                overlaps: []
            )
        }

        let planEvents = events.filter { event in
            event.startDate != nil && savedEventIDs.contains(event.id)
                && event.festivalDay(calendar: calendar) == currentFestivalDay
        }
        .sorted { first, second in
            eventPrecedes(
                first,
                second,
                durationsByEventID: estimatedDurationsByEventID,
                calendar: calendar
            )
        }
        let projections = planEvents.compactMap { event in
            makeEventProjection(
                event: event,
                durationMinutes: duration(
                    for: event,
                    durationsByEventID: estimatedDurationsByEventID
                ),
                calendar: calendar
            )
        }
        let activePlanEvents = planEvents.filter { event in
            event.endDate(
                durationInMinutes: duration(
                    for: event,
                    durationsByEventID: estimatedDurationsByEventID)
            ).map { $0 > now } ?? false
        }
        let transitions = zip(activePlanEvents, activePlanEvents.dropFirst()).map {
            firstEvent,
            secondEvent in
            let assessment = transitionEvaluator.assess(
                first: firstEvent,
                firstDurationMinutes: duration(
                    for: firstEvent,
                    durationsByEventID: estimatedDurationsByEventID
                ),
                second: secondEvent,
                secondDurationMinutes: duration(
                    for: secondEvent,
                    durationsByEventID: estimatedDurationsByEventID
                ),
                policy: transitionPolicy
            )
            return WatchScheduleTransitionProjection(
                fromEventID: assessment.firstEventID,
                toEventID: assessment.secondEventID,
                assessment: assessment
            )
        }

        var overlaps = [WatchScheduleOverlapProjection]()
        for firstIndex in planEvents.indices {
            for secondIndex in planEvents.indices where secondIndex > firstIndex {
                let firstEvent = planEvents[firstIndex]
                let secondEvent = planEvents[secondIndex]
                let assessment = transitionEvaluator.assess(
                    first: firstEvent,
                    firstDurationMinutes: duration(
                        for: firstEvent,
                        durationsByEventID: estimatedDurationsByEventID
                    ),
                    second: secondEvent,
                    secondDurationMinutes: duration(
                        for: secondEvent,
                        durationsByEventID: estimatedDurationsByEventID
                    ),
                    policy: transitionPolicy
                )
                if assessment.timeOverlapMinutes > 0 {
                    overlaps.append(WatchScheduleOverlapProjection(
                        firstEventID: assessment.firstEventID,
                        secondEventID: assessment.secondEventID,
                        overlapMinutes: assessment.timeOverlapMinutes
                    ))
                }
            }
        }

        return WatchScheduleProjection(
            generatedAt: now,
            currentFestivalDay: currentFestivalDay,
            ongoingEvents: projections.filter { projection in
                projection.startDate <= now && projection.endDate > now
            },
            upcomingEvents: projections.filter { projection in
                projection.startDate > now
            },
            endedEvents: projections.filter { projection in
                projection.endDate <= now
            },
            transitions: transitions,
            overlaps: overlaps
        )
    }

    private func duration(
        for event: Event,
        durationsByEventID: [Int: Int]
    ) -> Int {
        max(0, durationsByEventID[event.id] ?? defaultDurationMinutes)
    }

    private func eventPrecedes(
        _ firstEvent: Event,
        _ secondEvent: Event,
        durationsByEventID: [Int: Int],
        calendar: Calendar
    ) -> Bool {
        guard let firstDate = firstEvent.startDate, let secondDate = secondEvent.startDate else {
            return Event.precedes(firstEvent, secondEvent)
        }
        if firstDate != secondDate {
            return firstDate < secondDate
        }

        let firstEnd = firstEvent.endDate(
            durationInMinutes: duration(
                for: firstEvent,
                durationsByEventID: durationsByEventID
            ),
            calendar: calendar
        )
        let secondEnd = secondEvent.endDate(
            durationInMinutes: duration(
                for: secondEvent,
                durationsByEventID: durationsByEventID
            ),
            calendar: calendar
        )
        if let firstEnd, let secondEnd, firstEnd != secondEnd { return firstEnd < secondEnd }
        return firstEvent.id < secondEvent.id
    }

    private func makeEventProjection(
        event: Event,
        durationMinutes: Int,
        calendar: Calendar
    ) -> WatchScheduleEventProjection? {
        guard let start = event.startDate,
            let end = event.endDate(durationInMinutes: durationMinutes)
        else { return nil }
        return WatchScheduleEventProjection(
            id: event.id,
            artistID: event.artist.id,
            artistName: event.artist.name,
            stageID: event.stage.id,
            stageNameGerman: event.stage.germanName,
            stageNameEnglish: event.stage.englishName,
            startDate: start,
            endDate: end
        )
    }
}
