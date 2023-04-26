import Foundation

class ScheduleGenerator2 {

    init(allEvents: [Event], storedEventIds: [Int], allArtists: [Artist], artistRatings: Dictionary<String, Int>) {
        self.allEvents = allEvents
        self.storedEventIds = Set(storedEventIds)
        self.allArtists = allArtists
        var dict: [Int: Int] = [:]
        for (idAsString, rating) in artistRatings {
            dict[Int(idAsString)!] = rating
        }
        self.artistRatings = dict
    }

    let allEvents: [Event]
    let storedEventIds: Set<Int>
    let allArtists: [Artist]
    let artistRatings: [Int: Int]

    var artistEventCache: Dictionary<Int, [Event]> = Dictionary()


    func generate() -> [Event] {
        let storedEvents = allEvents.filter { event in
            storedEventIds.contains(event.id)
        }
        let now = Date.now
        let interestingEvents = allEvents.filter { event in
            userIsInterestedInArtist(artist: event.artist) &&
                    !intersects(events: storedEvents, current: event) &&
                    isEventInFuture(event: event, now: now)
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
                solutionEvent.artist.id == event.artist.id || solutionEvent.intersects(with: event)
            }) {
                solution.append(event)
            }
        }

        // Calculate solution score
        var score = 0
        for event in solution {
            score += calculateScore(for: event)
        }
        let iterations = max(200, min(interestingEvents.count * 10, 1000))
        print("Iterations: \(iterations)")
        print("Initial score \(score)")
        let solutionArtistIds = Set(solution.map {
            $0.artist.id
        })
        var remainingArtistIds = Set(interestingArtistIds.filter { artistId in
            !solutionArtistIds.contains(artistId)
        })

        for t in 0..<iterations {
            let eventsOfRemainingArtists = interestingEvents.filter { event in
                remainingArtistIds.contains(event.artist.id)
            }

            // Choose one event of an artist who does not occur in the schedule yet
            guard let eventToAdd: Event = eventsOfRemainingArtists.randomElement() else {
                print("Optimal solution found")
                break
            }

            // Calculate which events intersect with the new event
            let eventsToRemove: Array<Event> = solution.filter {
                $0.intersects(with: eventToAdd)
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
                let probability = Float(iterations - t) / Float(iterations * 10) * Float(17 + scoreDiff) / 17.0
                if Float.random(in: 0.0..<1.0) < probability {
                    print("\(oldScore) -> \(newScore)")
                    replace = true
                }
            }

            if replace {
                // Do the actual replacement
                for event in eventsToRemove {
                    if let index = solution.firstIndex(where: { $0.id == event.id }) {
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
        print("Final score \(score)")
        return solution
        /*solution.sort { event, event2 in
            event.festivalDay < event2.festivalDay || event.startTimeInMinutes < event2.startTimeInMinutes
        }
        return solution*/

        /*for event in finalEvents {
            print((event.shortWeekDay, event.timeAsString, event.artist.name))
        }*/
        /*return finalEvents.sorted { event, event2 in
            event.startTimeInMinutes < event2.startTimeInMinutes
        }*/
    }

    private func isEventInFuture(event: Event, now: Date) -> Bool {
        event.date >= now //|| true // uncomment for testing, don't foget to comment again after that
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

    func intersects(events: [Event], current: Event) -> Bool {
        events.contains { event in
            let collides = event.intersects(with: current)
            /*if collides {
                print("collides with \(event.shortWeekDay) \(event.timeAsString) \(event.artist.name)")
            }*/
            return collides
        }
    }
}
