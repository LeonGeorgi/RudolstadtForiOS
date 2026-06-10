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
    func buildSnapshot(
        data: FestivalData,
        savedEventIds: [Int],
        ratings: [String: Int],
        now: Date = .now
    ) -> RecommendationSnapshot {
        let estimatedEventDurations = estimateEventDurations(events: data.events)
        let generator = ScheduleRecommendationGenerator(
            allEvents: data.events,
            savedEventIds: savedEventIds,
            artistRatings: ratings,
            eventDurations: estimatedEventDurations,
            now: now
        )

        return RecommendationSnapshot(
            recommendedEventIds: generator.generateRecommendedEventIds(),
            estimatedEventDurations: estimatedEventDurations
        )
    }

    func estimateEventDurations(events: [Event]) -> [Int: Int] {
        let reversedEvents = events.sorted { e1, e2 in
            e1.date > e2.date
        }
        let reversedEventsByStage = Dictionary(grouping: reversedEvents) { event in
            event.stage.id
        }
        var eventDurations = [Int: Int]()

        for (_, reversedEventsForStage) in reversedEventsByStage {
            var subsequentEvent: Event? = nil
            for currentEvent in reversedEventsForStage {
                var length = 60
                if let subsequentEvent {
                    let minutesUntilNextEvent =
                        subsequentEvent.date.timeIntervalSince(currentEvent.date) / 60
                    var estimatedLength = length
                    let minutesUntilNextEventRoundedDown =
                        floor(minutesUntilNextEvent / 30.0) * 30
                    if minutesUntilNextEventRoundedDown < 30 {
                        estimatedLength = Int(minutesUntilNextEvent)
                    } else if minutesUntilNextEventRoundedDown < 60 {
                        estimatedLength = Int(minutesUntilNextEventRoundedDown)
                    } else {
                        let halfWayTimeInterval =
                            floor((minutesUntilNextEvent / 2) / 30.0) * 30
                        if halfWayTimeInterval < 30 {
                            estimatedLength = Int(halfWayTimeInterval)
                        } else if halfWayTimeInterval <= 90 {
                            estimatedLength = Int(halfWayTimeInterval)
                        } else if minutesUntilNextEvent > 300 {
                            estimatedLength = 60
                        } else {
                            estimatedLength = 90
                        }
                    }
                    if minutesUntilNextEvent < 60 {
                        length = Int(minutesUntilNextEvent)
                    } else {
                        length = max(60, estimatedLength)
                    }
                }
                eventDurations[currentEvent.id] = length
                subsequentEvent = currentEvent
            }
        }

        return eventDurations
    }
}

struct SchedulePresenter {
    let festivalData: FestivalData
    let recommendationState: LoadingEntity<[Int]>
    let scheduleFilterType: ScheduleFilter
    let savedEventIds: Set<Int>
    let positiveRatedArtistIds: Set<Int>

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
            event.festivalDay
        }).sorted(by: <).filter { day in
            if DataStore.year == 2023 && day < 6 {
                return false
            } else {
                return true
            }
        }
    }
}

final class ScheduleRecommendationGenerator {
    private let arrivalBufferMinutes = 2

    init(
        allEvents: [Event],
        savedEventIds: [Int],
        artistRatings: [String: Int],
        eventDurations: [Int: Int],
        now: Date
    ) {
        self.allEvents = allEvents
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
    }

    let allEvents: [Event]
    let savedEventIds: Set<Int>
    let artistRatings: [Int: Int]
    let eventDurations: [Int: Int]
    let now: Date

    func generateRecommendedSchedule() -> [Event] {
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
        event.date >= now
    }

    private func userIsInterestedInArtist(artist: Artist) -> Bool {
        (artistRatings[artist.id] ?? 0) > 0
    }

    private func eventSortOrder(lhs: Event, rhs: Event) -> Bool {
        if lhs.festivalDay != rhs.festivalDay {
            return lhs.festivalDay < rhs.festivalDay
        }
        if lhs.startTimeInMinutes != rhs.startTimeInMinutes {
            return lhs.startTimeInMinutes < rhs.startTimeInMinutes
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
        e1.intersects(
            with: e2,
            event1Duration: eventDurations[e1.id] ?? 60,
            event2Duration: eventDurations[e2.id] ?? 60,
            maxAllowedMissedMinutes: 0,
            arrivalBufferMinutes: arrivalBufferMinutes
        )
    }

    private func intersects(events: [Event], current: Event) -> Bool {
        events.contains { event in
            intersects(e1: event, e2: current)
        }
    }
}
