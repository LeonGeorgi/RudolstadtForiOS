import Foundation

class ScheduleGenerator2 {
    private let scheduleArrivalBufferMinutes = 2

    init(
        allEvents: [Event],
        storedEventIds: [Int],
        allArtists: [Artist],
        artistRatings: [String: Int],
        eventDurations: [Int: Int]?
    ) {
        self.allEvents = allEvents
        self.storedEventIds = Set(storedEventIds)
        self.allArtists = allArtists
        var dict: [Int: Int] = [:]
        for (idAsString, rating) in artistRatings {
            guard let id = Int(idAsString) else {
                continue
            }
            dict[id] = rating
        }
        self.artistRatings = dict
        self.eventDurations = eventDurations
    }

    let allEvents: [Event]
    let storedEventIds: Set<Int>
    let allArtists: [Artist]
    let artistRatings: [Int: Int]
    let eventDurations: [Int: Int]?

    var artistEventCache: [Int: [Event]] = Dictionary()

    func generate() -> [Event] {
        let storedEvents = allEvents.filter { event in
            storedEventIds.contains(event.id)
        }
        .sorted(by: eventSortOrder)
        let storedEventIdsSet = Set(storedEvents.map { $0.id })
        let storedArtistIds = Set(storedEvents.map { $0.artist.id })

        let now = Date.now
        let interestingEvents = allEvents.filter { event in
            userIsInterestedInArtist(artist: event.artist)
                && !storedEventIdsSet.contains(event.id)
                && !storedArtistIds.contains(event.artist.id)
                && !intersects(events: storedEvents, current: event)
                && isEventInFuture(event: event, now: now)
        }
        .sorted(by: recommendationSortOrder)

        let interestingEventsByArtist = Dictionary(grouping: interestingEvents) { event in
            event.artist.id
        }

        var solution: [Event] = storedEvents
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

        // Deterministic initial fill: one best-fitting event per artist.
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

        // Deterministic local improvement:
        // allow replacement of non-stored items when score strictly improves.
        var improved = true
        while improved {
            improved = false
            for eventToAdd in interestingEvents {
                if solution.contains(where: { $0.id == eventToAdd.id }) {
                    continue
                }

                let removableConflicts = solution.filter { existingEvent in
                    !storedEventIdsSet.contains(existingEvent.id)
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

        let score = solution.reduce(0) { partial, event in
            partial + calculateScore(for: event)
        }
        print("Final score \(score)")
        return solution
    }

    private func isEventInFuture(event: Event, now: Date) -> Bool {
        event.date >= now  //|| true // uncomment for testing, don't foget to comment again after that
    }

    private func userIsInterestedInArtist(artist: Artist) -> Bool {
        (artistRatings[artist.id] ?? 0) > 0
    }

    func generateRecommendations() -> [Int] {
        generate().filter { event in
            !storedEventIds.contains(event.id)
        }
        .map { event in
            event.id
        }

    }

    func calculateScore(for event: Event) -> Int {
        let rating = (artistRatings[event.artist.id] ?? 0)
        return rating * rating
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

    func eventsFor(artist: Artist) -> [Event] {
        if let cachedEvents = artistEventCache[artist.id] {
            return cachedEvents
        } else {
            let events = allEvents.filter { event in
                event.artist.id == artist.id
            }
            artistEventCache[artist.id] = events
            return events
        }
    }

    func intersects(e1: Event, e2: Event) -> Bool {
        return e1.intersects(
            with: e2,
            event1Duration: eventDurations?[e1.id] ?? 60,
            event2Duration: eventDurations?[e2.id] ?? 60,
            maxAllowedMissedMinutes: 0,
            arrivalBufferMinutes: scheduleArrivalBufferMinutes
        )
    }

    func intersects(events: [Event], current: Event) -> Bool {
        events.contains { event in
            let collides = intersects(e1: event, e2: current)
            /*if collides {
                print("collides with \(event.shortWeekDay) \(event.timeAsString) \(event.artist.name)")
            }*/
            return collides
        }
    }
}
