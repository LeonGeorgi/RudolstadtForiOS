import Foundation

struct RecommendationSnapshot: Equatable, Sendable {
    let recommendedEventIds: [Int]
    let estimatedEventDurations: [Int: Int]
}

protocol RecommendationProviding: Sendable {
    func buildSnapshot(
        data: FestivalData,
        savedEventIds: [Int],
        ratings: [String: Int],
        now: Date
    ) -> RecommendationSnapshot
}

final class RecommendationService: RecommendationProviding {
    private let calendar: Calendar
    private let walkingDistanceMatrix: StageWalkingDistanceMatrix?

    init(
        calendar: Calendar = .current,
        walkingDistanceMatrix: StageWalkingDistanceMatrix? = nil
    ) {
        self.calendar = calendar
        self.walkingDistanceMatrix = walkingDistanceMatrix
    }

    func buildSnapshot(
        data: FestivalData,
        savedEventIds: [Int],
        ratings: [String: Int],
        now: Date = .now
    ) -> RecommendationSnapshot {
        let estimatedEventDurations = data.metadata == nil ? estimateEventDurations(events: data.events) : data.eventDurations
        if data.metadata != nil && data.features.automaticPlanning.value == nil {
            return RecommendationSnapshot(recommendedEventIds: [], estimatedEventDurations: estimatedEventDurations)
        }
        let planningTransfer: (@Sendable (FestivalPlaceID, FestivalPlaceID) -> StageTransferEstimate?)?
        if let provider = data.features.automaticPlanning.value {
            planningTransfer = { source, destination in
                provider.transfer(from: source, to: destination).map(StageTransferEstimate.init)
            }
        } else { planningTransfer = nil }
        let transitionEvaluator = ScheduleTransitionEvaluator(
            transferEstimator: StageTransferEstimator(
                stages: data.stages,
                matrix: walkingDistanceMatrix ?? data.walkingDistanceMatrix
            ),
            calendar: data.metadata?.calendar ?? calendar,
            transferProvider: planningTransfer
        )
        let generator = ScheduleRecommendationGenerator(
            allEvents: data.events,
            savedEventIds: savedEventIds,
            artistRatings: ratings,
            eventDurations: estimatedEventDurations,
            now: now,
            calendar: calendar,
            transitionEvaluator: transitionEvaluator,
            eligibleEventIDs: data.features.automaticPlanning.value?.eligibleEventIDs,
            requiresKnownTransfers: data.metadata != nil
        )

        return RecommendationSnapshot(
            recommendedEventIds: generator.generateRecommendedEventIds(),
            estimatedEventDurations: estimatedEventDurations
        )
    }

    func estimateEventDurations(events: [Event]) -> [Int: Int] {
        return Dictionary(uniqueKeysWithValues: FestivalDurationResolver.resolve(events).compactMap {
            event in event.duration.map { (event.id, $0.minutes) }
        })
    }
}

struct ScheduleEventSections {
    let scheduled: [Event]
    let unknownTime: [Event]
    let unknownDate: [Event]

    init(events: [Event], selectedDay: Int) {
        scheduled = events.filter { $0.startDate != nil && $0.festivalDay == selectedDay }
        unknownTime = events.filter {
            $0.startDate == nil && $0.knownDate != nil && $0.festivalDay == selectedDay
        }
        unknownDate = events.filter { $0.knownDate == nil }
    }

    init(events: [Event], selectedProgramDay: String?) {
        scheduled = events.filter { $0.startDate != nil && $0.programDay?.id == selectedProgramDay }
        unknownTime = events.filter { $0.startDate == nil && $0.knownDate != nil && $0.programDay?.id == selectedProgramDay }
        unknownDate = events.filter { $0.programDay == nil }
    }

    var unplaced: [Event] { (unknownTime + unknownDate).sorted(by: Event.precedes) }
}

struct SchedulePresenter {
    let festivalData: FestivalData
    let recommendationState: LoadingEntity<[Int]>
    let scheduleFilterType: ScheduleFilter
    let savedEventIds: Set<Int>
    let positiveRatedArtistIds: Set<Int>
    private let calendar: Calendar

    init(
        festivalData: FestivalData,
        recommendationState: LoadingEntity<[Int]>,
        scheduleFilterType: ScheduleFilter,
        savedEventIds: Set<Int>,
        positiveRatedArtistIds: Set<Int>,
        calendar: Calendar = .current
    ) {
        self.festivalData = festivalData
        self.recommendationState = recommendationState
        self.scheduleFilterType = scheduleFilterType
        self.savedEventIds = savedEventIds
        self.positiveRatedArtistIds = positiveRatedArtistIds
        self.calendar = calendar
    }

    var availableEventDays: [Int] {
        festivalDays(from: festivalData.events)
    }

    var shownEvents: LoadingEntity<[Event]> {
        mapShownEvents(from: festivalData.events)
    }

    private func mapShownEvents(from events: [Event]) -> LoadingEntity<[Event]> {
        switch scheduleFilterType {
        case .saved:
            return .success(events.filter { event in
                savedEventIds.contains(event.id)
            })
        case .interesting:
            return .success(events.filter { event in
                savedEventIds.contains(event.id)
                    || positiveRatedArtistIds.contains(event.artist.id)
            })
        case .all:
            return .success(events)
        case .optimal:
            switch recommendationState {
            case .loading:
                return .loading
            case .failure(let reason):
                return .failure(reason)
            case .success(let recommendedEventIds):
                let recommendedEventIdSet = Set(recommendedEventIds)
                return .success(events.filter { event in
                    savedEventIds.contains(event.id)
                        || recommendedEventIdSet.contains(event.id)
                })
            }
        }
    }

    private func festivalDays(from events: [Event]) -> [Int] {
        Set(events.lazy.map { event in
            event.festivalDay(calendar: calendar)
        }).sorted(by: <).filter { day in
            if day <= 0 {
                return false
            } else {
                return true
            }
        }
    }
}

final class ScheduleRecommendationGenerator {
    init(
        allEvents: [Event],
        savedEventIds: [Int],
        artistRatings: [String: Int],
        eventDurations: [Int: Int],
        now: Date,
        calendar: Calendar = .current,
        transitionEvaluator: ScheduleTransitionEvaluator,
        eligibleEventIDs: Set<Int>? = nil,
        requiresKnownTransfers: Bool = false
    ) {
        self.allEvents = allEvents.filter { event in
            eligibleEventIDs.map { $0.contains(event.id) } ?? event.hasCompleteMetadata
        }
        self.requiresKnownTransfers = requiresKnownTransfers
        self.savedEventIds = Set(savedEventIds)
        var normalizedRatings = [Int: Int]()
        for (idAsString, rating) in artistRatings {
            guard let id = Int(idAsString) else {
                continue
            }
            normalizedRatings[id] = rating
        }
        self.artistRatings = normalizedRatings
        self.eventDurations = eventDurations
        self.now = now
        self.calendar = calendar
        self.transitionEvaluator = transitionEvaluator
    }

    let requiresKnownTransfers: Bool
    let allEvents: [Event]
    let savedEventIds: Set<Int>
    let artistRatings: [Int: Int]
    let eventDurations: [Int: Int]
    let now: Date
    let calendar: Calendar
    let transitionEvaluator: ScheduleTransitionEvaluator

    func generateRecommendedSchedule() -> [Event] {
        guard !Task.isCancelled else { return [] }
        let savedEvents = allEvents.filter { event in
            savedEventIds.contains(event.id)
        }
        .sorted(by: eventSortOrder)
        let savedEventIdSet = Set(savedEvents.map { $0.id })
        let savedArtistIds = Set(savedEvents.map { $0.artist.id })

        let interestingEvents = allEvents.filter { event in
            userIsInterestedInArtist(artist: event.artist)
                && !savedEventIdSet.contains(event.id)
                && !savedArtistIds.contains(event.artist.id)
                && !intersects(events: savedEvents, current: event)
                && isEventInFuture(event: event)
        }
        .sorted(by: recommendationSortOrder)

        let interestingEventsByArtist = Dictionary(grouping: interestingEvents) { event in
            event.artist.id
        }

        var solution: [Event] = savedEvents
        let artistIdsByPriority = interestingEventsByArtist.keys.sorted {
            firstArtistId,
            secondArtistId in
            let firstRating = artistRatings[firstArtistId] ?? 0
            let secondRating = artistRatings[secondArtistId] ?? 0
            if firstRating == secondRating {
                return firstArtistId < secondArtistId
            }
            return firstRating > secondRating
        }

        for artistId in artistIdsByPriority {
            guard !Task.isCancelled else { return [] }
            let artistEvents = (interestingEventsByArtist[artistId] ?? [])
                .sorted(by: recommendationSortOrder)
            if let firstFeasibleEvent = artistEvents.first(where: { event in
                !intersects(events: solution, current: event)
            }) {
                solution.append(firstFeasibleEvent)
            }
        }
        solution.sort(by: eventSortOrder)

        var improved = true
        while improved {
            guard !Task.isCancelled else { return [] }
            improved = false
            for eventToAdd in interestingEvents {
                if solution.contains(where: { $0.id == eventToAdd.id }) {
                    continue
                }

                let removableConflicts = solution.filter { existingEvent in
                    !savedEventIdSet.contains(existingEvent.id)
                        && (existingEvent.artist.id == eventToAdd.artist.id
                            || intersects(e1: existingEvent, e2: eventToAdd))
                }

                let scoreToRemove = removableConflicts.reduce(0) { partial, event in
                    partial + calculateScore(for: event)
                }
                let scoreDiff = calculateScore(for: eventToAdd) - scoreToRemove
                if scoreDiff <= 0 {
                    continue
                }

                let removableIds = Set(removableConflicts.map { $0.id })
                let candidateSolutionWithoutConflicts = solution.filter { event in
                    !removableIds.contains(event.id)
                }
                if intersects(events: candidateSolutionWithoutConflicts, current: eventToAdd) {
                    continue
                }

                solution = candidateSolutionWithoutConflicts + [eventToAdd]
                solution.sort(by: eventSortOrder)
                improved = true
            }
        }

        return solution
    }

    func generateRecommendedEventIds() -> [Int] {
        generateRecommendedSchedule().filter { event in
            !savedEventIds.contains(event.id)
        }
        .map { event in
            event.id
        }
    }

    func calculateScore(for event: Event) -> Int {
        let rating = artistRatings[event.artist.id] ?? 0
        return rating * rating
    }

    private func isEventInFuture(event: Event) -> Bool {
        event.startDate.map { $0 >= now } ?? false
    }

    private func userIsInterestedInArtist(artist: Artist) -> Bool {
        (artistRatings[artist.id] ?? 0) > 0
    }

    private func eventSortOrder(lhs: Event, rhs: Event) -> Bool {
        let lhsFestivalDay = lhs.festivalDay(calendar: calendar)
        let rhsFestivalDay = rhs.festivalDay(calendar: calendar)
        if lhsFestivalDay != rhsFestivalDay {
            return lhsFestivalDay < rhsFestivalDay
        }
        let lhsStartTime = lhs.startTimeInMinutes(calendar: calendar)
        let rhsStartTime = rhs.startTimeInMinutes(calendar: calendar)
        if lhsStartTime != rhsStartTime {
            return lhsStartTime < rhsStartTime
        }
        return lhs.id < rhs.id
    }

    private func recommendationSortOrder(lhs: Event, rhs: Event) -> Bool {
        let lhsScore = calculateScore(for: lhs)
        let rhsScore = calculateScore(for: rhs)
        if lhsScore != rhsScore {
            return lhsScore > rhsScore
        }
        return eventSortOrder(lhs: lhs, rhs: rhs)
    }

    private func intersects(e1: Event, e2: Event) -> Bool {
        let assessment = transitionEvaluator.assess(
            first: e1,
            firstDurationMinutes: eventDurations[e1.id] ?? 60,
            second: e2,
            secondDurationMinutes: eventDurations[e2.id] ?? 60,
            policy: .recommendation
        )
        return assessment.isConflict || (requiresKnownTransfers && assessment.status == .unknown)
    }

    private func intersects(events: [Event], current: Event) -> Bool {
        events.contains { event in
            intersects(e1: event, e2: current)
        }
    }
}
