import Foundation

class ScheduleGenerator2 {

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
            dict[Int(idAsString)!] = rating
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
        let now = Date.now
        let interestingEvents = allEvents.filter { event in
            userIsInterestedInArtist(artist: event.artist)
                && !intersects(events: storedEvents, current: event)
                && isEventInFuture(event: event, now: now)
        }

        let interestingArtistIds = allArtists.filter { artist in
            userIsInterestedInArtist(artist: artist)
        }
        .map { artist in
            artist.id
        }

        // Generate start solution
        var solution: [Event] = storedEvents
        for event in interestingEvents.shuffled() {
            if !solution.contains(where: { (solutionEvent: Event) in
                solutionEvent.artist.id == event.artist.id
                    || intersects(e1: solutionEvent, e2: event)
            }) {
                solution.append(event)
            }
        }

        // Calculate solution score
        var score = 0
        for event in solution {
            score += calculateScore(for: event)
        }
        let iterations = max(200, min(interestingEvents.count * 20, 1000))
        print("Calculating recommendations in \(iterations) iterations")
        let optimalScore = interestingArtistIds.map { artistId in
            let rating = (artistRatings[artistId] ?? 0)
            return rating * rating
        }.reduce(0, +)
        print("Initial score: \(score); Best possible score: \(optimalScore)")
        let solutionArtistIds = Set(
            solution.map {
                $0.artist.id
            }
        )
        var remainingArtistIds = Set(
            interestingArtistIds.filter { artistId in
                !solutionArtistIds.contains(artistId)
            }
        )

        var bestSolutionSoFar: [Event] = []
        var bestSolutionScore: Int = 0

        for t in 0..<iterations {
            let eventsOfRemainingArtists = interestingEvents.filter { event in
                remainingArtistIds.contains(event.artist.id)
            }

            // Choose one event of an artist who does not occur in the schedule yet
            guard
                let eventToAdd: Event = eventsOfRemainingArtists.randomElement()
            else {
                print("Optimal solution found")
                break
            }

            // Calculate which events intersect with the new event
            let eventsToRemove: [Event] = solution.filter {
                intersects(e1: $0, e2: eventToAdd)
            }

            // Calculate if the replacement should be carried out

            var replace: Bool = false

            var scoreDiff = calculateScore(for: eventToAdd)
            for event in eventsToRemove {
                scoreDiff -= calculateScore(for: event)
            }

            let oldScore = score
            let newScore = oldScore + scoreDiff

            if newScore >= oldScore {
                // New solution is not worse than the old one
                replace = true
            } else {
                // Select with decreasing probability
                let probability =
                    Float(iterations - t) / Float(iterations * 10)
                    * Float(17 + scoreDiff) / 17.0
                if Float.random(in: 0.0..<1.0) < probability {
                    //print("\(oldScore) -> \(newScore)")
                    replace = true
                }
            }

            if replace {
                // Backup old solution, if score was higher
                if oldScore > newScore {
                    bestSolutionSoFar = solution
                    bestSolutionScore = oldScore
                }

                // Do the actual replacement
                for event in eventsToRemove {
                    if let index = solution.firstIndex(where: {
                        $0.id == event.id
                    }) {
                        solution.remove(at: index)
                        // solutionArtistIds.remove(event.artist.id)
                        remainingArtistIds.insert(event.artist.id)
                    }
                }
                solution.append(eventToAdd)
                // solutionArtistIds.insert(newEvent.artist.id)
                remainingArtistIds.remove(eventToAdd.artist.id)

                score = newScore
            }
        }
        score = 0
        for event in solution {
            score += calculateScore(for: event)
        }
        if bestSolutionScore > score {
            print("Selected backup solution, because it was better")
            solution = bestSolutionSoFar
            score = bestSolutionScore
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
            event2Duration: eventDurations?[e2.id] ?? 60
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
